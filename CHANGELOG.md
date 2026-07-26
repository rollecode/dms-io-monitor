# Changelog

### 1.0.0: 2026-07-26

* Initial release: live disk read and write throughput as an animated progress bar in the DankBar
* Popout pins read, write and the busiest disk, then lists each disk and per-process I/O with kill icons
* Falls back to summing per-process I/O when the kernel is not accounting block I/O, marking those rows so the source is never a guess
