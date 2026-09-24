import hashlib
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_ffmpeg_native as native


class VerifyFFmpegNativeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / 'bundle.zip'
        self.archive.write_bytes(b'pinned archive')
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def test_android_requires_packaged_version(self):
        apk = self.root / 'app.apk'
        with zipfile.ZipFile(apk, 'w') as bundle:
            bundle.writestr('lib/arm64-v8a/libffmpegkit.so', b'FFmpeg version n9.0.2')
        with mock.patch.dict(native.ARCHIVES, {'android': (self.archive.name, self.digest)}):
            self.assertEqual(native.verify('android', apk, self.archive)['version'], 'n9.0.2')
            with zipfile.ZipFile(apk, 'w') as bundle:
                bundle.writestr('lib/arm64-v8a/libffmpegkit.so', b'FFmpeg version n9.0.1')
            with self.assertRaisesRegex(ValueError, 'does not contain n9.0.2'):
                native.verify('android', apk, self.archive)

    def test_windows_rejects_wrong_dll_digest(self):
        dll = self.root / 'libffmpegkit.dll'
        dll.write_bytes(b'FFmpeg version n9.0.2')
        with mock.patch.dict(native.ARCHIVES, {'windows': (self.archive.name, self.digest)}):
            with self.assertRaisesRegex(ValueError, 'DLL hash differs'):
                native.verify('windows', dll, self.archive)

    def test_linux_rejects_newer_glibc(self):
        so = self.root / 'libffmpegkit.so'
        elf = bytearray(b'\x7fELF\x02' + b'\x00' * 32)
        elf[18:20] = (62).to_bytes(2, 'little')
        so.write_bytes(elf + b'FFmpeg version n9.0.2 GLIBC_2.43')
        with mock.patch.dict(native.ARCHIVES, {'linux': (self.archive.name, self.digest)}):
            with self.assertRaisesRegex(ValueError, 'glibc baseline'):
                native.verify('linux', so, self.archive)
            so.write_bytes(elf + b'FFmpeg version n9.0.2 GLIBC_2.38')
            self.assertEqual(native.verify('linux', so, self.archive)['version'], 'n9.0.2')
            self.assertEqual(native.verify('linux', self.root, self.archive)['version'], 'n9.0.2')

    def test_rejects_replaced_hook_archive(self):
        dll = self.root / 'libffmpegkit.dll'
        dll.write_bytes(b'FFmpeg version n9.0.2')
        with self.assertRaisesRegex(ValueError, 'archive SHA-256 differs'):
            native.verify('windows', dll, self.archive)

    def test_stages_verified_linux_runtime_in_portable_bundle(self):
        elf = bytearray(b'\x7fELF\x02' + b'\x00' * 32)
        elf[18:20] = (62).to_bytes(2, 'little')
        payload = bytes(elf) + b'FFmpeg version n9.0.2 GLIBC_2.38'
        with zipfile.ZipFile(self.archive, 'w') as package:
            package.writestr(native.LINUX_LIBRARY_ENTRY, payload)
        pinned = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        bundle = self.root / 'bundle'
        bundle.mkdir()
        with mock.patch.dict(native.ARCHIVES, {'linux': (self.archive.name, pinned)}):
            staged = native.stage_linux_runtime(bundle, self.archive)
            self.assertEqual(staged.read_bytes(), payload)
            self.assertEqual(native.verify('linux', bundle, self.archive)['version'], 'n9.0.2')


if __name__ == '__main__':
    unittest.main()
