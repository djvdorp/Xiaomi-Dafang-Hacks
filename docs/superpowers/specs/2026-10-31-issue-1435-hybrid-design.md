# Issue 1435 Hybrid Recovery Design

## Intent

Make the Xiaomi Dafang usable as a security camera when its RTSP video path
stalls as described in issue #1435. The change must let us test a newer Wi-Fi
driver and a newer RTSP stack without making the camera unrecoverable.

## Goals

- Build or obtain a candidate `8189es.ko` compatible with the camera's exact
  Linux `3.10.14` MIPS kernel and SDIO wiring.
- Test the newer `v4l2rtspserver`/live555 lineage used by the `gysmo38` fork.
- Keep the stock driver and RTSP binary as immediate fallbacks.
- Make RTSP video-stall recovery automatic, so one stall does not require a
  manual reboot.
- Verify each candidate on the real camera with decoded video and kernel-log
  checks before selecting it as the default.

## Non-goals

- Replacing the camera kernel or ISP modules.
- Switching from RTSP to another transport.
- Blindly installing a generic `8189es` binary from another SoC or kernel.
- Reworking unrelated Wi-Fi, audio, motion, or web UI behavior.

## Constraints and anti-goals

- The camera runs Linux `3.10.14 #21 PREEMPT`, MIPS, with stock
  `8189es v4.3.18.3_20185.20161116`.
- The driver candidate must be built against the matching kernel tree and
  toolchain, or it is rejected.
- A candidate binary is staged under a distinct filename first; active files
  are backed up before any switch.
- Failure must fall back to the stock driver/binary and preserve SSH access.
- No credentials or RTSP URLs are committed to the repository.

## Approaches considered

1. Driver-only: direct root-cause attempt, but does not protect the camera if
   RTSP still wedges and carries the highest brick risk.
2. RTSP-only: smallest and safest operational fix, but leaves the suspected
   Wi-Fi/kernel interaction untouched.
3. Hybrid: stage a compatible newer driver and RTSP binary independently,
   add a small RTSP health/restart path, and enable candidates only after
   real-camera verification. This is the selected approach because it tests
   both likely layers while keeping rollback simple.

## Design

`firmware_mod/run.sh` will prefer an optional SD-card `8189es.ko` only when
configured and fall back to the stock `/driver/8189es.ko` if insertion fails.
The candidate remains a separate artifact until it passes load, association,
and stream tests.

`firmware_mod/controlscripts/rtsp` will use a configurable RTSP executable,
defaulting to the current binary. The newer MIPS/uClibc candidate and any
required live555 libraries will be staged under separate names. The script
will record the selected binary and driver mode in its log.

The RTSP control script will gain a bounded video-health recovery loop using
the existing local camera tools. It will restart only the RTSP process after a
confirmed video stall, with a cooldown and retry limit; it will not reboot the
camera or touch Wi-Fi automatically.

## Verification

- Static: shell syntax checks, configuration/default checks, binary
  architecture/interpreter checks, and driver module metadata checks.
- Driver: compile against the exact `3.10.14` kernel headers, then stage and
  load without replacing the stock module; verify Wi-Fi association and zero
  new scheduler/SDIO errors.
- RTSP: run stock and candidate binaries at `1280x720` and `960x540`, decode
  frames for at least 10 minutes per combination, and record time-to-stall.
- Recovery: induce or wait for a stall, verify the process restarts and video
  resumes without rebooting, then verify the retry limit prevents a restart
  loop.

## Open implementation calls

- Exact driver source commit and build flags will be selected only after the
  compatibility build succeeds.
- The RTSP candidate will be enabled only if its required libraries match the
  camera's MIPS/uClibc runtime; otherwise the recovery logic ships alone.
- The default remains stock until candidate measurements beat the current
  baseline.
