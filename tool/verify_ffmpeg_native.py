"""Verify pinned FFmpeg 9.0.2 hook downloads and packaged native libraries."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
CACHE = REPO / '.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/ffmpeg_kit_cache'
ARCHIVES = {
    'android': ('bundle-base-shared-lgpl-release.aar', 'c6c9b1ff7be756b0fb587f98e05972ca4dae97e8275c22961b443b4fd5f49bf7'),
    'windows': ('bundle-base-windows-x86_64-shared-lgpl.zip', 'e61684a91f7471ba00f1d5b36a24e93ab602ef72bd57000d94990e7e0c5dfe3a'),
    'linux': ('bundle-base-linux-x86_64-shared-lgpl.zip', 'd6003c3feb2bdcdccd0d4ad5e7b76fa8e8951430c6a22c1db7be5e13da19403d'),
}
WINDOWS_DLL_SHA256 = '302d978048f389dbb07f01c1a34a4988a92d1e3ebf0e960e2dd8314f83632b34'
VERSION = b'n9.0.2'


def digest(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(platform: str, artifact: Path, cache_archive: Path | None = None, abi: str = 'arm64-v8a') -> dict[str, str]:
    name, expected = ARCHIVES[platform]
    archive = cache_archive or CACHE / platform / name
    if digest(archive) != expected:
        raise ValueError(f'{platform} FFmpeg hook archive SHA-256 differs from pinned n9.0.2 asset: {archive}')

    if platform == 'android':
        with zipfile.ZipFile(artifact) as apk:
            library = apk.read(f'lib/{abi}/libffmpegkit.so')
    else:
        library = artifact.read_bytes()
    if VERSION not in library:
        raise ValueError(f'{platform} packaged FFmpeg library does not contain n9.0.2: {artifact}')

    if platform == 'windows' and digest(artifact) != WINDOWS_DLL_SHA256:
        raise ValueError(f'Windows FFmpeg DLL hash differs from pinned bundle: {artifact}')
    if platform == 'linux':
        if library[:5] != b'\x7fELF\x02' or int.from_bytes(library[18:20], 'little') != 62:
            raise ValueError(f'Linux FFmpeg library is not an x86_64 ELF: {artifact}')
        glibc_versions = [tuple(map(int, version)) for version in re.findall(rb'GLIBC_(\d+)\.(\d+)', library)]
        if not glibc_versions or max(glibc_versions) > (2, 39):
            raise ValueError(f'Linux FFmpeg library exceeds Ubuntu 24.04 glibc baseline: {artifact}')

    return {'platform': platform, 'version': VERSION.decode(), 'archive_sha256': expected, 'library_sha256': hashlib.sha256(library).hexdigest()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=ARCHIVES)
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--cache-archive', type=Path)
    parser.add_argument('--abi', choices=('arm64-v8a', 'armeabi-v7a', 'x86_64'), default='arm64-v8a')
    args = parser.parse_args()
    try:
        print(verify(args.platform, args.artifact, args.cache_archive, args.abi))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f'FFmpeg native verification failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
