# CS DemoDesk FFmpeg

A minimal Windows x64 FFmpeg build that retains only the libraries and media-processing features needed by [CS DemoDesk](https://github.com/noih/cs-demodesk).

## Included

- `ffmpeg.exe`, `ffprobe.exe`, and their shared DLLs.
- H.264, H.265, and AV1 encoding with x264, x265, SVT-AV1, and NVIDIA NVENC.
- Video decoding, AAC/PCM audio, MP4 output, raw video capture, clip concatenation, scaling, frame-rate conversion, and two-pass encoding.

Unused codecs, network protocols, playback tools, and development headers are excluded from the runtime package. CPU optimizations and 10-bit support are retained; this project does not change DemoDesk's encoding presets.

## Download

Download `cs-demodesk-ffmpeg-win64-gpl-shared.zip` from [Releases](https://github.com/noih/cs-demodesk-ffmpeg/releases). Keep the DLLs beside both executables. Verify the archive against `SHA256SUMS`.

Releases become available after the workflow has been pushed to the default branch and its first build passes. DemoDesk's download URL should only be switched after the package passes integration tests.

## Updates and validation

GitHub Actions checks [BtbN Releases](https://github.com/BtbN/FFmpeg-Builds/releases) every hour, at minute 23. A new dated autobuild triggers a build using that release's build-recipe revision and the FFmpeg revision identified by its Windows asset. The rolling `latest` tag is not treated as a version. An unchanged release is skipped; failed builds are retried at the next check. API failures stop the check instead of triggering a build.

Pushes do not trigger builds. Use manual dispatch to check and build immediately; otherwise the next hourly check picks up upstream releases and local build changes. Publication only happens after Windows tests pass. Scheduled runs may be delayed by GitHub; this is polling, not an immediate upstream webhook.

Each build records its source revisions and base-image digests, uses a reduced dependency graph, and tests the resulting Windows binaries before publishing. Tests cover CPU encoding, decoding, audio, concatenation, raw video input, and two-pass encoding. NVIDIA encoder availability is checked, but actual NVENC encoding requires a compatible GPU and driver; GitHub-hosted runners do not validate that hardware path.

Failed builds do not replace the last successful release. GitHub may disable scheduled workflows in inactive public repositories; manual dispatch remains available.

## Build locally

On Linux with Bash, Git, Python 3, Docker, and ZIP installed:

```sh
bash scripts/build.sh <BtbN-commit-SHA> <FFmpeg-commit-SHA>
```

On Windows, validate the extracted package:

```powershell
./scripts/smoke.ps1 -Bin ./package/bin
```

Artifacts are written to `dist/`. This is a specialized build, not a general-purpose FFmpeg distribution.

## Sources and licenses

The build uses GPL-enabled FFmpeg with x264 and x265. Each release includes the FFmpeg license, exact dependency source archives (including their licenses), FFmpeg source, and the build recipes. Consult those files for each component's terms. Build infrastructure is adapted from BtbN/FFmpeg-Builds; upstream notices are retained in the source bundle.
