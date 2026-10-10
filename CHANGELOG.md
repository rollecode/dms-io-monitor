# Changelog

### 1.1.1: 2026-10-10

* Fix polling and theme colour from review [#687](https://github.com/AvengeMedia/dms-plugin-registry/issues/687)
* Hide kill button on session processes

### 1.1.0: 2026-07-26

* Read system totals from `/proc/vmstat`, which counts block I/O in the VM layer: the widget now reports real throughput on machines whose udev rules switch off per-device accounting, with no configuration
* Measure the sampling window instead of assuming it, so scanning a few hundred process files no longer makes every rate read low
* Warm the popout list in the background so it paints instantly instead of filling in a second after opening

### 1.0.0: 2026-07-26

* Initial release: live disk read and write throughput as an animated progress bar in the DankBar
* Popout pins read, write and the busiest disk, then lists each disk and per-process I/O with kill icons
* Falls back to summing per-process I/O when the kernel is not accounting block I/O, marking those rows so the source is never a guess
