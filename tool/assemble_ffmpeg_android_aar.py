"""Combine three FFmpeg-Kit builder AARs without changing their native code.

Each upstream builder invocation publishes one Android ABI. This step verifies
the ELF identity, FFmpeg version, page alignment, and common AAR metadata before
packaging the three libraries for the Flutter Native Assets hook.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path, PurePosixPath
import struct
import zipfile


ABIS = {"arm64-v8a": (2, 183), "armeabi-v7a": (1, 40), "x86_64": (2, 62)}
METADATA = (
    "R.txt",
    "AndroidManifest.xml",
    "classes.jar",
    "META-INF/com/android/build/gradle/aar-metadata.properties",
)
MIN_LOAD_ALIGNMENT = 0x4000


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_elf(data: bytes, abi: str, version: str) -> None:
    elf_class, machine = ABIS[abi]
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[4] != elf_class or data[5] != 1:
        raise ValueError(f"{abi}: expected little-endian ELF class {elf_class}")
    if struct.unpack_from("<H", data, 18)[0] != machine:
        raise ValueError(f"{abi}: ELF machine does not match ABI")
    if f"FFmpeg version {version}".encode("ascii") not in data:
        raise ValueError(f"{abi}: FFmpeg version marker {version} is absent")

    if elf_class == 2:
        offset = struct.unpack_from("<Q", data, 32)[0]
        entry_size, count = struct.unpack_from("<HH", data, 54)
        alignment_offset = 48
    else:
        offset = struct.unpack_from("<I", data, 28)[0]
        entry_size, count = struct.unpack_from("<HH", data, 42)
        alignment_offset = 28
    if count == 0 or entry_size < alignment_offset + (8 if elf_class == 2 else 4):
        raise ValueError(f"{abi}: invalid ELF program header table")
    if offset + entry_size * count > len(data):
        raise ValueError(f"{abi}: truncated ELF program header table")
    load_count = 0
    for index in range(count):
        header = offset + index * entry_size
        if struct.unpack_from("<I", data, header)[0] != 1:
            continue
        load_count += 1
        alignment = struct.unpack_from("<Q" if elf_class == 2 else "<I", data, header + alignment_offset)[0]
        if alignment < MIN_LOAD_ALIGNMENT:
            raise ValueError(f"{abi}: PT_LOAD alignment {alignment:#x} is below 16 KB")
    if load_count == 0:
        raise ValueError(f"{abi}: ELF has no PT_LOAD segment")


def read_aar(path: Path, abi: str, version: str) -> tuple[dict[str, bytes], bytes]:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError(f"{path}: duplicate archive entries")
        for name in names:
            item = PurePosixPath(name)
            if item.is_absolute() or ".." in item.parts or "\\" in name:
                raise ValueError(f"{path}: unsafe archive entry {name}")
        metadata = {name: archive.read(name) for name in METADATA}
        library_name = f"jni/{abi}/libffmpegkit.so"
        libraries = [name for name in names if name.startswith("jni/") and name.endswith(".so")]
        if libraries != [library_name]:
            raise ValueError(f"{path}: expected only {library_name}, found {libraries}")
        library = archive.read(library_name)
    validate_elf(library, abi, version)
    return metadata, library


def assemble(inputs: dict[str, Path], output: Path, version: str) -> dict[str, str]:
    if set(inputs) != set(ABIS):
        raise ValueError(f"expected ABIs: {', '.join(ABIS)}")
    if output.exists():
        raise FileExistsError(output)
    metadata: dict[str, bytes] | None = None
    libraries: dict[str, bytes] = {}
    for abi in ABIS:
        current_metadata, library = read_aar(inputs[abi], abi, version)
        if metadata is not None and current_metadata != metadata:
            raise ValueError(f"{abi}: AAR metadata differs from arm64-v8a")
        metadata = current_metadata
        libraries[abi] = library

    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name(f"{output.name}.partial")
    if staging.exists():
        raise FileExistsError(staging)
    try:
        with zipfile.ZipFile(staging, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9, allowZip64=True) as archive:
            payloads = list(metadata.items()) + [(f"jni/{abi}/libffmpegkit.so", libraries[abi]) for abi in ABIS]
            for name, data in payloads:
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
        with zipfile.ZipFile(staging) as archive:
            if archive.testzip() is not None:
                raise ValueError("merged AAR CRC check failed")
        staging.replace(output)
    except Exception:
        staging.unlink(missing_ok=True)
        raise
    return {"aar": sha256(output.read_bytes()), **{abi: sha256(libraries[abi]) for abi in ABIS}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for abi in ABIS:
        parser.add_argument(f"--{abi}", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", default="n9.0.2")
    args = parser.parse_args()
    inputs = {abi: getattr(args, abi.replace("-", "_")) for abi in ABIS}
    for label, digest in assemble(inputs, args.output, args.version).items():
        print(f"{label}: {digest}")


if __name__ == "__main__":
    main()
