# CS DemoDesk FFmpeg

A minimal Windows x64 FFmpeg package for [CS DemoDesk](https://github.com/noih/cs-demodesk), retaining only the libraries and media-processing features the app needs.

Includes separate `ffmpeg` and `ffprobe` packages for CPU encoding or one GPU vendor at a time. The NVIDIA package uses NVENC; the AMD package uses AMF through the Windows D3D11 device path. Both packages include the video and audio processing required for recording and exporting clips.

The release contains the original `cs-demodesk-ffmpeg-win64-gpl-shared.zip` NVIDIA package and a new `cs-demodesk-ffmpeg-win64-gpl-shared-amd.zip` AMD package. Each package excludes the other vendor's GPU encoders. AMD AMF encoding requires a compatible AMD display driver; AV1 is only available on supported AMD GPU generations. GPU availability is not required for the binaries to load; the smoke test checks component isolation and CPU operation, not that a GPU is attached.

Based on [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds), with unused components removed to reduce download size.

Packages, source archives, and license information are available in [Releases](https://github.com/noih/cs-demodesk-ffmpeg/releases).

## License

The build scripts and configuration in this repository are licensed under the
[MIT License](https://github.com/noih/cs-demodesk-ffmpeg/blob/main/LICENSE). BtbN/FFmpeg-Builds is also MIT-licensed; its copyright
and permission notice are retained in our LICENSE and in the archived upstream
build recipes.

This MIT license does not relicense FFmpeg or its dependencies. The Windows
`gpl-shared` package includes the GNU GPLv3 text as `LICENSE.txt`; FFmpeg and
third-party components retain their respective licenses.

The accompanying `sources.tar.xz` contains FFmpeg and dependency source archives,
upstream build recipes, and this repository's scripts, README, and LICENSE.
