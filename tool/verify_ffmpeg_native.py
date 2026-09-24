"""Verify pinned FFmpeg 9.0.2 hook downloads and packaged native libraries."""

from __future__ import annotations

import argparse
import hashlib
import re
import struct
import sys
import zipfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
CACHE = REPO / '.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/ffmpeg_kit_cache'
ARCHIVES = {
    'android': ('bundle-base-shared-lgpl-release.aar', 'c6c9b1ff7be756b0fb587f98e05972ca4dae97e8275c22961b443b4fd5f49bf7'),
    'windows': ('bundle-base-windows-x86_64-shared-lgpl.zip', 'e61684a91f7471ba00f1d5b36a24e93ab602ef72bd57000d94990e7e0c5dfe3a'),
    'linux': ('bundle-base-linux-x86_64-shared-lgpl.zip', 'd6003c3feb2bdcdccd0d4ad5e7b76fa8e8951430c6a22c1db7be5e13da19403d'),
    'macos': ('bundle-base-macos-universal-lgpl.xcframework.zip', '9977fc0d3de38af4830c54f536146b2595843d7a45850c50c6205ffb56ca899a'),
    'ios': ('bundle-base-ios-universal-lgpl.xcframework.zip', 'f1758956e81d938bedf39e796dc99a3b34951cffcc681ab52e241d47b0c93aa4'),
}
WINDOWS_DLL_SHA256 = '302d978048f389dbb07f01c1a34a4988a92d1e3ebf0e960e2dd8314f83632b34'
VERSION = b'n9.0.2'
LINUX_LIBRARY_ENTRY = 'bundle-base-linux-x86_64-shared-lgpl/lib/libffmpegkit.so'


def digest(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def stage_linux_runtime(bundle: Path, archive: Path) -> Path:
    """Place the verified hook archive's runtime in the portable Linux bundle.

    Flutter's Linux Native Assets hook can resolve a CodeAsset without copying
    its ELF into the release bundle. Dart FFI also opens this library by name,
    so release packaging must include it beside the other plugin libraries.
    """
    if not bundle.is_dir():
        raise ValueError(f'Linux release bundle is missing: {bundle}')
    if digest(archive) != ARCHIVES['linux'][1]:
        raise ValueError(f'Linux FFmpeg hook archive SHA-256 differs from pinned n9.0.2 asset: {archive}')
    with zipfile.ZipFile(archive) as package:
        library = package.read(LINUX_LIBRARY_ENTRY)
    target = bundle / 'lib/libffmpegkit.so'
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f'{target.name}.tmp')
    temporary.write_bytes(library)
    temporary.replace(target)
    return target


def macho_architectures(binary: bytes) -> set[int]:
    """Return Mach-O CPU types from thin or universal executables."""
    if len(binary) < 8:
        raise ValueError('Apple FFmpeg Mach-O header is incomplete')
    magic = binary[:4]
    if magic == b'\xcf\xfa\xed\xfe':
        return {struct.unpack_from('<I', binary, 4)[0]}
    if magic not in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
        raise ValueError(f'Apple FFmpeg binary has unexpected Mach-O magic: {magic.hex()}')
    count = struct.unpack_from('>I', binary, 4)[0]
    stride = 20 if magic == b'\xca\xfe\xba\xbe' else 32
    if count < 1 or len(binary) < 8 + count * stride:
        raise ValueError('Apple FFmpeg universal Mach-O header is incomplete')
    return {struct.unpack_from('>I', binary, 8 + index * stride)[0] for index in range(count)}


def verify(platform: str, artifact: Path, cache_archive: Path | None = None, abi: str = 'arm64-v8a') -> dict[str, str]:
    name, expected = ARCHIVES[platform]
    archive = cache_archive or CACHE / platform / name
    if digest(archive) != expected:
        raise ValueError(f'{platform} FFmpeg hook archive SHA-256 differs from pinned n9.0.2 asset: {archive}')

    if platform == 'linux' and artifact.is_dir():
        candidates = list(artifact.rglob('libffmpegkit.so'))
        if len(candidates) != 1:
            raise ValueError(f'Expected one packaged Linux FFmpeg library under {artifact}, found {len(candidates)}')
        artifact = candidates[0]
    if platform in ('macos', 'ios') and artifact.is_dir():
        candidates = [path for path in artifact.rglob('ffmpegkit') if path.parent.name == 'ffmpegkit.framework' and path.is_file()]
        if len(candidates) != 1:
            raise ValueError(f'Expected one packaged {platform} FFmpeg framework binary under {artifact}, found {len(candidates)}')
        artifact = candidates[0]

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
    if platform == 'macos':
        if macho_architectures(library) != {0x01000007, 0x0100000C}:
            raise ValueError(f'macOS FFmpeg library lacks x86_64 and arm64 slices: {artifact}')
    if platform == 'ios':
        architectures = macho_architectures(library)
        if architectures != {0x0100000C}:
            raise ValueError(f'iOS FFmpeg library is not arm64 Mach-O ({architectures}): {artifact}')

    return {'platform': platform, 'version': VERSION.decode(), 'archive_sha256': expected, 'library_sha256': hashlib.sha256(library).hexdigest()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=ARCHIVES)
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--cache-archive', type=Path)
    parser.add_argument('--abi', choices=('arm64-v8a', 'armeabi-v7a', 'x86_64'), default='arm64-v8a')
    parser.add_argument('--stage-linux', action='store_true', help='copy verified ELF from hook ZIP into Linux release bundle')
    args = parser.parse_args()
    try:
        if args.stage_linux:
            if args.platform != 'linux':
                raise ValueError('--stage-linux requires the linux platform')
            stage_linux_runtime(args.artifact, args.cache_archive or CACHE / 'linux' / ARCHIVES['linux'][0])
        print(verify(args.platform, args.artifact, args.cache_archive, args.abi))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f'FFmpeg native verification failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
