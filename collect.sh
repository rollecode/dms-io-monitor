#!/bin/sh
# Emits TYPE<TAB>PCT<TAB>PID<TAB>NAME<TAB>DETAIL<TAB>UNIT<TAB>DISPLAY per line.
# F = pinned accent (Read, Write, Busiest disk), S = per-disk, P = process.
# PCT drives the bar, DISPLAY is the text shown. Rates need two samples, so
# everything is measured across one 0.5 s window.
#
# Per-process figures come from /proc/<pid>/io read_bytes/write_bytes, which
# count real block-device traffic, not page-cache hits. Processes owned by
# other users are unreadable without privileges and are silently skipped.

detail_for() {
  _pid=$1
  _comm=$2
  _cmd=$(tr '\0' '\n' < "/proc/$_pid/cmdline" 2>/dev/null)
  [ -z "$_cmd" ] && return

  _t=$(printf '%s\n' "$_cmd" | sed -n 's/^--type=//p' | head -1)
  if [ -n "$_t" ]; then
    printf '%s' "$_t"
    return
  fi

  case "$_comm" in
    fossilize*)
      printf 'steam'
      ;;
    python*|node|bun|ruby|perl|java)
      _s=$(printf '%s\n' "$_cmd" | sed -n '2,$p' | grep -v '^-' | head -1)
      [ -n "$_s" ] && printf '%s' "$(basename "$_s")"
      ;;
    claude|bash|sh|zsh|fish|nvim|vim|git)
      _c=$(readlink "/proc/$_pid/cwd" 2>/dev/null)
      [ -n "$_c" ] && printf '%s' "$(basename "$_c")"
      ;;
    WebKitWebProcess|*WebProcess)
      _ppid=$(awk '{print $4}' "/proc/$_pid/stat" 2>/dev/null)
      _p=$(cat "/proc/$_ppid/comm" 2>/dev/null)
      [ -n "$_p" ] && printf 'via %s' "$_p"
      ;;
  esac
}

FS=${1:-0}
case "$FS" in (*[!0-9]*|"") FS=0;; esac
[ "$FS" -gt 0 ] || FS=200            # MB/s that counts as a full bar
SCALE=$((FS * 1048576))

# Whole disks only: partitions, loop, zram and dm-* would double-count.
disk_snap() {
  awk '$3 ~ /^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|hd[a-z]+|mmcblk[0-9]+)$/ {
    print $3, $6 * 512, $10 * 512, $13
  }' /proc/diskstats
}

proc_snap() {
  for f in /proc/[0-9]*/io; do
    [ -r "$f" ] || continue
    pid=${f#/proc/}; pid=${pid%/io}
    # The readable bit lies here: /proc/<pid>/io needs ptrace access, so a
    # foreign-owned process fails at read time. Drop those quietly.
    awk -v p="$pid" '/^read_bytes:/{r=$2} /^write_bytes:/{w=$2} END{if (r+w > 0) print p, r, w}' "$f" 2>/dev/null
  done
}

# System-wide totals come from /proc/vmstat, which counts block I/O in the
# VM layer and therefore works on every machine, including ones whose udev
# rules switch off per-device accounting (queue/iostats = 0).
vm_snap() { awk '/^pgpgin /{i=$2} /^pgpgout /{o=$2} END{print i, o}' /proc/vmstat; }

# Identical ordering in both batches, so every pair is separated by the same
# interval. Scanning a few hundred /proc files takes real time, so the window
# is measured rather than assumed.
T1=$(date +%s%N)
P1=$(proc_snap); V1=$(vm_snap); D1=$(disk_snap)
sleep 0.5
T2=$(date +%s%N)
P2=$(proc_snap); V2=$(vm_snap); D2=$(disk_snap)
ELAPSED=$(awk -v a="$T1" -v b="$T2" 'BEGIN{e=(b-a)/1000000000; print (e > 0.05 ? e : 0.5)}')

{
  printf 'VA %s\n' "$V1"
  printf 'VB %s\n' "$V2"
  printf '%s\n' "$D1" | sed 's/^/DA /'
  printf '%s\n' "$D2" | sed 's/^/DB /'
  printf '%s\n' "$P1" | sed 's/^/PA /'
  printf '%s\n' "$P2" | sed 's/^/PB /'
} | awk -v scale="$SCALE" -v fs="$FS" -v el="$ELAPSED" '
function human(b,   u, i) {
  if (b < 1024) return sprintf("%d B/s", b)
  split("K M G T", u, " ")
  i = 1
  b = b / 1024
  while (b >= 1024 && i < 4) { b = b / 1024; i++ }
  return (b < 10 ? sprintf("%.1f %sB/s", b, u[i]) : sprintf("%d %sB/s", b, u[i]))
}
function pct(rate) { return rate * 100 / scale }
$1=="VA"{ vr1=$2 * 1024; vw1=$3 * 1024 }
$1=="VB"{ vr2=$2 * 1024; vw2=$3 * 1024 }
$1=="DA"{ dr1[$2]=$3; dw1[$2]=$4; dt1[$2]=$5 }
$1=="DB"{ dr2[$2]=$3; dw2[$2]=$4; dt2[$2]=$5 }
$1=="PA"{ pr1[$2]=$3; pw1[$2]=$4 }
$1=="PB"{ pr2[$2]=$3; pw2[$2]=$4 }
END{
  # Measured window -> per-second rates.
  totR = 0; totW = 0; busiest = 0
  for (d in dr2) {
    r = (dr2[d] - dr1[d]) / el
    w = (dw2[d] - dw1[d]) / el
    if (r < 0) r = 0; if (w < 0) w = 0
    if (r + w > 0) diskMoved = 1
    # Field 13 is milliseconds with I/O in flight: 500 ms of a 500 ms window
    # means the queue was never empty, which is the saturation signal.
    busy = (dt2[d] - dt1[d]) / 5
    if (busy > 100) busy = 100
    if (busy < 0) busy = 0
    if (busiestName == "" || busy > busiest) { busiest = busy; busiestName = d }
    if (r + w > 0) printf "S\t%d\t-\t%s\t%d%% of %d MB/s\t\t%s\n", pct(r+w), d, pct(r+w), fs, human(r+w)
  }

  # Per-process totals first: they double as a fallback when the kernel is
  # not accounting block I/O (queue/iostats = 0 leaves diskstats frozen).
  procR = 0; procW = 0
  for (p in pr2) {
    if (!(p in pr1)) continue
    pr[p] = (pr2[p] - pr1[p]) / el
    pw[p] = (pw2[p] - pw1[p]) / el
    if (pr[p] < 0) pr[p] = 0
    if (pw[p] < 0) pw[p] = 0
    procR += pr[p]; procW += pw[p]
  }

  totR = (vr2 - vr1) / el
  totW = (vw2 - vw1) / el
  if (totR < 0) totR = 0
  if (totW < 0) totW = 0

  printf "F\t%d\t-\tRead\t%d%% of %d MB/s\t\t%s\n",  pct(totR), pct(totR), fs, human(totR)
  printf "F\t%d\t-\tWrite\t%d%% of %d MB/s\t\t%s\n", pct(totW), pct(totW), fs, human(totW)
  if (diskMoved) printf "F\t%d\t-\tBusiest disk\t%s\t\t%d%%\n", busiest, busiestName, busiest

  for (p in pr) {
    if (pr[p] + pw[p] > 0) printf "P|%d|%s|%s\n", pct(pr[p] + pw[p]), p, human(pr[p] + pw[p])
  }
  printf "T\t100\t-\tscale\t\t\t\n"
}' | while IFS= read -r line; do
  case "$line" in
    P\|*)
      IFS='|' read -r _ val pid display <<EOF2
$line
EOF2
      c=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
      [ -z "$c" ] || printf 'P\t%s\t%s\t%s\t%s\t\t%s\n' "$val" "$pid" "$c" "$(detail_for "$pid" "$c")" "$display"
      ;;
    *) printf '%s\n' "$line" ;;
  esac
done
