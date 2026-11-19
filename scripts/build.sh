#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ ${1:-} =~ ^[0-9a-f]{40}$ && ${2:-} =~ ^[0-9a-f]{40}$ ]] || { echo 'Supply BtbN and FFmpeg commit SHAs' >&2; exit 2; }
[[ ! -e "$root/work" && ! -e "$root/dist" ]] || { echo 'Use a clean checkout (work/ or dist/ already exists)' >&2; exit 2; }
mkdir -p "$root/work" "$root/dist" "$root/.cache/downloads"
started=$SECONDS
mark() { printf "[timing] %s: %ss elapsed\n" "$1" "$((SECONDS - started))"; }
git clone --filter=blob:none --no-checkout https://github.com/BtbN/FFmpeg-Builds.git "$root/work/builder"
cd "$root/work/builder"
git checkout --detach "$1"
cp "$root/scripts/minimal.sh" addins/demodesk.sh
# Keep upstream dependency recipes and their transitive toolchain dependencies.
cat > scripts.d/zz-final.sh <<'EOF'
SCRIPT_SKIP=1
ffbuild_depends() { printf '%s\n' x264 x265 svtav1 dav1d ffnvcodec amf; }
ffbuild_enabled() { return 0; }
ffbuild_dockerfinal() { return 0; }
EOF
export GITHUB_REPOSITORY=btbn/ffmpeg-builds
bash generate.sh win64 gpl-shared demodesk
docker pull ghcr.io/btbn/ffmpeg-builds/base-win64:latest
docker pull ghcr.io/btbn/ffmpeg-builds/base:latest
base=$(docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/btbn/ffmpeg-builds/base-win64:latest)
download_base=$(docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/btbn/ffmpeg-builds/base:latest)
sed -i "s|ghcr.io/btbn/ffmpeg-builds/base-win64:latest|$base|g" Dockerfile
mkdir -p .cache/downloads
mark "builder sources and base images"
# Fetch exactly the stages selected by generate.sh; preserve these source archives.
sed -n 's/^ENV SELF="\([^"]*\)".*/\1/p' Dockerfile | sort -u > selected-stages.txt
while IFS= read -r stage; do
    docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/recipes" -v "$root/.cache/downloads:/downloads" -w /recipes "$download_base" bash -euo pipefail -c '
        source util/dl_functions.sh
        source "$1"
        command=$(ffbuild_dockerdl)
        [[ -n "$command" ]] || exit 0
        hash=$(sha256sum <<< "$command" | cut -d" " -f1)
        name=$(basename "$1" .sh)
        # Include download helpers and base image as well as the upstream command.
        namespace=$(cat util/dl_functions.sh; printf "%s" "$2")
        namespace=$(sha256sum <<< "$namespace" | cut -d" " -f1)
        archive="${name}_${hash}.tar.xz"
        cached="/downloads/${namespace}_${archive}"
        if [[ -f "$cached" ]]; then
            echo "Source cache hit: $name"
            cp "$cached" "/recipes/.cache/downloads/$archive"
            exit 0
        fi
        echo "Source cache miss: $name"
        temp=$(mktemp -d)
        cd "$temp"
        eval "$command"
        tar -I "xz -T2" -cf "$cached.partial" .
        mv "$cached.partial" "$cached"
        cp "$cached" "/recipes/.cache/downloads/$archive"
    ' bash "$stage" "$download_base"
done < selected-stages.txt
mark "dependency sources"
cache_args=()
if [[ -f "$root/.cache/buildkit/index.json" ]]; then
    cache_args+=(--cache-from "type=local,src=$root/.cache/buildkit")
fi
next_cache=$(mktemp -d "$root/.cache/buildkit-next.XXXXXX")
docker buildx build --load --tag demodesk-ffmpeg-builder "${cache_args[@]}" \
    --cache-to "type=local,dest=$next_cache,mode=max" .
test -s "$next_cache/index.json"
# Replace only our cache after a successful export, avoiding unbounded old layers.
rm -rf -- "$root/.cache/buildkit"
mv "$next_cache" "$root/.cache/buildkit"
mark "dependency build and cache export"
# Keep commit history and tags for the N-* version, but skip historical blobs.
git clone --filter=blob:none --no-checkout https://github.com/FFmpeg/FFmpeg.git "$root/work/ffmpeg"
git -C "$root/work/ffmpeg" checkout --detach "$2"
mark "FFmpeg sources"
for variant in nvidia amd; do
    case "$variant" in
        nvidia)
            variant_flags='--disable-amf --disable-d3d11va --disable-encoder=h264_amf,hevc_amf,av1_amf'
            ;;
        amd)
            variant_flags='--disable-nvenc --disable-ffnvcodec --disable-encoder=h264_nvenc,hevc_nvenc,av1_nvenc'
            ;;
    esac
    mark "FFmpeg configure ($variant)"
    docker run --rm -u "$(id -u):$(id -g)" -v "$root/work:/work" -w /work/ffmpeg demodesk-ffmpeg-builder bash -euo pipefail -c "
        make distclean >/dev/null 2>&1 || true
        ./configure --prefix=/work/package-$variant --pkg-config-flags=--static \$FFBUILD_TARGET_FLAGS \$FF_CONFIGURE $variant_flags \\
            --extra-cflags=\"\$FF_CFLAGS\" --extra-cxxflags=\"\$FF_CXXFLAGS\" --extra-libs=\"\$FF_LIBS\" \\
            --extra-ldflags=\"\$FF_LDFLAGS\" --extra-ldexeflags=\"\$FF_LDEXEFLAGS\" \\
            --cc=\"\$CC\" --cxx=\"\$CXX\" --ar=\"\$AR\" --ranlib=\"\$RANLIB\" --nm=\"\$NM\"
        make -j\"\$(nproc)\"
        make install
    "
    mark "FFmpeg compile ($variant)"
    runtime="$root/work/runtime-$variant"
    mkdir -p "$runtime/bin"
    cp "$root/work/package-$variant/bin/ffmpeg.exe" "$root/work/package-$variant/bin/ffprobe.exe" "$runtime/bin/"
    cp "$root/work/package-$variant/bin/"*.dll "$runtime/bin/"
    cp "$root/work/ffmpeg/COPYING.GPLv3" "$runtime/LICENSE.txt"
    printf 'Variant: %s\nBtbN: %s\nFFmpeg: %s\nBase: %s\nDownload base: %s\n' "$variant" "$1" "$2" "$base" "$download_base" > "$runtime/build-info.txt"
    cp "$root/work/ffmpeg/ffbuild/config.mak" "$runtime/"
    cp "$root/README.md" "$runtime/"
done
mkdir -p "$root/work/sources"
git -C "$root/work/ffmpeg" archive HEAD | xz -T2 > "$root/work/sources/ffmpeg.tar.xz"
cp .cache/downloads/*.tar.xz "$root/work/sources/"
tar --exclude=.git --exclude=.cache -cJf "$root/work/sources/build-recipes.tar.xz" .
cp -r "$root/scripts" "$root/work/sources/"
cp "$root/README.md" "$root/LICENSE" "$root/work/sources/"
(cd "$root/work/runtime-nvidia" && zip -9 -r "$root/dist/cs-demodesk-ffmpeg-win64-gpl-shared.zip" .)
(cd "$root/work/runtime-amd" && zip -9 -r "$root/dist/cs-demodesk-ffmpeg-win64-gpl-shared-amd.zip" .)
tar -C "$root/work/sources" -cJf "$root/dist/sources.tar.xz" .
(cd "$root/dist" && sha256sum *.zip *.tar.xz > SHA256SUMS)

mark "packaging complete"
