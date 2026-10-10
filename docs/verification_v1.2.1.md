# v1.2.1 verification - 2026-10-04

This update sets the initial interface to English and adds an English introduction.

| Check | Result |
|---|---|
| GUI support tests, including English default and explicit Chinese | 11/11 passed |
| Standalone entry tests and English report export | 2/2 passed |
| MATLAB Compiler build and Windows packaging | Completed, version 1.2.1 |
| Actual compiled executable: --gui-smoke | Exit code 0; English PDF created |
| Introduction source tasks | Base, six-case sweep, geometry and synthetic telemetry completed |
| Video | 1920 x 1080, 20 frames/s, 325.35 seconds, H.264/AAC |
| Video review | Full decode; 24 sampled frames; audio levels and duration checked |

The English and Chinese modes remain selectable, and saved projects retain their language. Six built-in projects were regenerated in English. The pre-update 1.2.0 source archive was saved before editing.

The compiled smoke check was performed on this Windows installation, which already has MATLAB/Runtime components. It is not a new clean-machine portability test. This presentation update does not change the thermal solver or establish new physical validation. The video uses real GUI captures and reports with English synthetic narration, and labels the synthetic telemetry and calibration-configuration scope. The geometry-panel refresh limitation is explicitly explained in the video.

Local source test records and compiled smoke results are retained in results. Video verification and its reproducible scripts are in tutorial/english_intro_v1_2_1.
