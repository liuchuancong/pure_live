#!/usr/bin/env bash
#
# Seed the ffmpeg_kit_extended_flutter Native Assets cache for a Linux build.
#
# Why this exists: three of the four platforms already seed this cache with a
# *pinned* archive before Flutter runs (Windows and Android through
# tool/prefetch_android_native.ps1 and tool/prefetch_windows_native.ps1). Linux
# did not. The hook would then fetch whatever archive its own default points at —
# a different builder release than the one `tool/verify_ffmpeg_native.py` pins —
# and the build ended at:
#
#   ValueError: Linux FFmpeg hook archive SHA-256 differs from pinned n9.0.2 asset
#
# because the release step verifies (and stages) exactly
# .dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/ffmpeg_kit_cache/linux/bundle-base-linux-x86_64-shared-lgpl.zip
# against the SHA-256 recorded in that script.
#
# Responsibilities:
#
# - download the pinned Linux archive and refuse it unless the hash matches
# - place it exactly where the hook looks, so the hook never downloads
#
# It does not:
#
# - extract anything (the hook does)
# - decide which variant to use (the pinned hash in verify_ffmpeg_native.py does)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

archive_name='bundle-base-linux-x86_64-shared-lgpl.zip'
url='https://github.com/wzgrx/pure_live/releases/download/native-ffmpeg-9.0.2-b1/bundle-base-linux-x86_64-shared-lgpl.zip'
sha256='d6003c3feb2bdcdccd0d4ad5e7b76fa8e8951430c6a22c1db7be5e13da19403d'

cache_dir="$repo_root/.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/ffmpeg_kit_cache/linux"
target="$cache_dir/$archive_name"
scratch="$(mktemp -d)"
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT

verify() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  printf '%s  %s\n' "$sha256" "$file" | sha256sum --check --strict --quiet
}

mkdir -p "$cache_dir"

if verify "$target"; then
  echo "Verified $archive_name (already cached)"
  exit 0
fi

# A cached archive that fails the hash is either a partial download or another
# builder's build; neither is usable, and leaving it in place would make the hook
# silently reuse it.
if [[ -e "$target" ]]; then
  mv "$target" "$target.invalid-$(date -u +%Y%m%dT%H%M%SZ)"
fi

echo "Fetching $archive_name..."
curl --fail --location --retry 6 --retry-all-errors --retry-delay 2 \
  --connect-timeout 30 --max-time 900 --continue-at - \
  --output "$scratch/$archive_name" "$url"

if ! verify "$scratch/$archive_name"; then
  echo "error: $archive_name does not match the pinned SHA-256." >&2
  echo "  expected $sha256" >&2
  echo "  actual   $(sha256sum "$scratch/$archive_name" | cut -d' ' -f1)" >&2
  exit 1
fi

mv "$scratch/$archive_name" "$target"
echo "Verified $archive_name -> $target"
