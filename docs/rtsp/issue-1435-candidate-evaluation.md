# Issue 1435 RTSP candidate evaluation

## Candidate

- Source fork: [gysmo38/Xiaomi-Dafang-Hacks](https://github.com/gysmo38/Xiaomi-Dafang-Hacks)
- Source commit: `652365dd167612946cd951d8f00ebbb172b4906d` (2020-06-21)
- Binary: `firmware_mod/bin/v4l2rtspserver-master`
- SHA-256: `17651dc755877e96254e9012cacc560734a7e5c76fe07614a854f185b52a3a68`
- ELF: 32-bit MIPS32 rel2, interpreter `/lib/ld-uClibc.so.0`
- Dynamic dependencies match the repository binary, including `libliveMedia.so`; no extra library directory is needed.
- Candidate binary is 3,933,936 bytes; current repository binary is 4,040,340 bytes with SHA-256 `11c7f4b6594164854210414bbde3d9db9aad380330bdfd9302bd17adfa74838d`.

The candidate ran `-h` on the camera using the installed libraries. Its server also initialized the jxf22 sensor and H.264 encoder at 1280x720. The candidate was linked against the camera's existing Live555 2020.05.15 library; the fork's Live555 library is older, so it was not substituted.

## Frame check

Both servers were tested locally on loopback at 1280x720, H.264, 25 fps, using the camera's `avconv` to request one decoded frame. Stock produced a non-empty frame and exited successfully. The candidate delivered SPS/PPS and IDR data, but `avconv` decoded no picture before timeout. Stock RTSP was restored after each test; recording was idle.

Decision: keep stock as the default and do not bundle this candidate as a selectable camera binary. The controller's opt-in selector remains available for a future candidate that passes the same frame check. The tested binary was removed from the camera after the comparison.
