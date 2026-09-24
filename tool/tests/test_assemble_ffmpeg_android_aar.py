import struct
import sys
import tempfile
import unittest
from pathlib import Path
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from assemble_ffmpeg_android_aar import ABIS, METADATA, assemble


def fake_elf(abi: str, *, alignment: int = 0x4000, version: str = "n9.0.2") -> bytes:
    elf_class, machine = ABIS[abi]
    data = bytearray(256)
    data[:6] = bytes((0x7F, 0x45, 0x4C, 0x46, elf_class, 1))
    struct.pack_into("<H", data, 18, machine)
    if elf_class == 2:
        struct.pack_into("<Q", data, 32, 64)
        struct.pack_into("<HH", data, 54, 56, 1)
        struct.pack_into("<I", data, 64, 1)
        struct.pack_into("<Q", data, 64 + 48, alignment)
    else:
        struct.pack_into("<I", data, 28, 64)
        struct.pack_into("<HH", data, 42, 32, 1)
        struct.pack_into("<I", data, 64, 1)
        struct.pack_into("<I", data, 64 + 28, alignment)
    data.extend(f"FFmpeg version {version}".encode("ascii"))
    return bytes(data)


def write_aar(path: Path, abi: str, *, alignment: int = 0x4000, version: str = "n9.0.2", manifest: bytes = b"same") -> None:
    with zipfile.ZipFile(path, "w") as archive:
        for name in METADATA:
            archive.writestr(name, manifest if name == "AndroidManifest.xml" else b"same")
        archive.writestr(f"jni/{abi}/libffmpegkit.so", fake_elf(abi, alignment=alignment, version=version))


class AssembleFFmpegAndroidAarTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.inputs = {abi: self.root / f"{abi}.aar" for abi in ABIS}
        for abi, path in self.inputs.items():
            write_aar(path, abi)

    def test_combines_three_verified_abis(self) -> None:
        output = self.root / "merged.aar"
        hashes = assemble(self.inputs, output, "n9.0.2")
        self.assertEqual(set(hashes), {"aar", *ABIS})
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(archive.testzip(), None)
            self.assertEqual(
                sorted(name for name in archive.namelist() if name.endswith(".so")),
                sorted(f"jni/{abi}/libffmpegkit.so" for abi in ABIS),
            )

    def test_rejects_old_ffmpeg_and_4kb_alignment(self) -> None:
        write_aar(self.inputs["x86_64"], "x86_64", version="n9.0.1")
        with self.assertRaisesRegex(ValueError, "version marker"):
            assemble(self.inputs, self.root / "old.aar", "n9.0.2")
        write_aar(self.inputs["x86_64"], "x86_64", alignment=0x1000)
        with self.assertRaisesRegex(ValueError, "below 16 KB"):
            assemble(self.inputs, self.root / "unaligned.aar", "n9.0.2")

    def test_accepts_ndk_armv7_four_kb_alignment(self) -> None:
        write_aar(self.inputs["armeabi-v7a"], "armeabi-v7a", alignment=0x1000)
        hashes = assemble(self.inputs, self.root / "armv7.aar", "n9.0.2")
        self.assertIn("armeabi-v7a", hashes)

    def test_rejects_mismatched_wrapper_metadata(self) -> None:
        write_aar(self.inputs["armeabi-v7a"], "armeabi-v7a", manifest=b"different")
        with self.assertRaisesRegex(ValueError, "metadata differs"):
            assemble(self.inputs, self.root / "mismatched.aar", "n9.0.2")


if __name__ == "__main__":
    unittest.main()
