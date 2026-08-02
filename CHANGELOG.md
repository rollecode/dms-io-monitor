# Changelog

### 1.2.0: 2026-08-02

* Render in vertical bars: the icon, chart and percentage stack in a column, and the label is dropped because a bar one icon wide has no room for it
* Five chart styles instead of the one fixed progress bar — horizontal bar, vertical bar, gauge, donut and pie — plus a thickness control for the two bar styles, and *none* for a text-only pill
* Choose the icon, from a list of disk and transfer symbols or any Material Symbols name you type in. The default is now `hard_disk` rather than `swap_vert`
* Put the icon inside the gauge, donut and pie instead of beside them. Those charts grow to make room for it, up to the thickness of the bar, and the ring thins out so the hole is worth having. The pie has no hole to use, so the icon there sits on a faint disc of the surface colour — mid-sweep it would otherwise straddle fill and track, where no single colour reads on both
* Toggles for the icon and the percentage, so every part of the pill can be turned off independently
* Stop sampling `/proc` while the bar is hidden, and reseed the counters on the way back so the first sample after a pause is not reported as a spike

### 1.1.0: 2026-07-26

* Read system totals from `/proc/vmstat`, which counts block I/O in the VM layer: the widget now reports real throughput on machines whose udev rules switch off per-device accounting, with no configuration
* Measure the sampling window instead of assuming it, so scanning a few hundred process files no longer makes every rate read low
* Warm the popout list in the background so it paints instantly instead of filling in a second after opening

### 1.0.0: 2026-07-26

* Initial release: live disk read and write throughput as an animated progress bar in the DankBar
* Popout pins read, write and the busiest disk, then lists each disk and per-process I/O with kill icons
* Falls back to summing per-process I/O when the kernel is not accounting block I/O, marking those rows so the source is never a guess
