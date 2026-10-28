# CS DemoDesk FFmpeg

A minimal Windows x64 FFmpeg package for [CS DemoDesk](https://github.com/noih/cs-demodesk), retaining only the libraries and media-processing features the app needs.

Includes `ffmpeg`, `ffprobe`, and shared libraries for H.264, H.265, and AV1 encoding on CPU or compatible NVIDIA GPUs, plus the video and audio processing required for recording and exporting clips.

Based on [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds), with unused components removed to reduce download size.

Packages, source archives, and license information are available in [Releases](https://github.com/noih/cs-demodesk-ffmpeg/releases).

## License

The build scripts and configuration in this repository are licensed under the
[MIT License](https://github.com/noih/cs-demodesk-ffmpeg/blob/main/LICENSE). BtbN/FFmpeg-Builds is also MIT-licensed; its copyright
and permission notice are retained in our LICENSE and in the archived upstream
build recipes.

This MIT license does not relicense FFmpeg or its dependencies. The Windows
`gpl-shared` package includes the GNU GPLv3 text as `LICENSE.txt`; FFmpeg and
third-party components retain their respective licenses. The runtime archive
also includes this repository's MIT license as `BUILD-LICENSE.txt`.

The accompanying `sources.tar.xz` contains FFmpeg and dependency source archives,
upstream build recipes, and this repository's scripts, README, and LICENSE.
