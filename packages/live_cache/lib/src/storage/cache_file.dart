import 'dart:io';
import 'dart:typed_data';

import 'package:live_cache/src/models/cache_failure.dart';
import 'package:path/path.dart' as p;

/// Whether [bytes] begin with a signature the image pipeline accepts.
///
/// A server that answers 200 with an HTML error page must not leave a file
/// that every later decode blames on the cache.
bool looksLikeImage(Uint8List bytes) {
  if (bytes.length < 12) {
    return false;
  }
  bool startsWith(List<int> magic) {
    if (bytes.length < magic.length) {
      return false;
    }
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) {
        return false;
      }
    }
    return true;
  }

  // JPEG.
  if (startsWith(const [0xFF, 0xD8, 0xFF])) {
    return true;
  }
  // PNG.
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return true;
  }
  // GIF87a / GIF89a.
  if (startsWith(const [0x47, 0x49, 0x46, 0x38])) {
    return true;
  }
  // WebP: RIFF....WEBP.
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  // BMP.
  if (startsWith(const [0x42, 0x4D])) {
    return true;
  }
  // ICO / CUR.
  if (startsWith(const [0x00, 0x00, 0x01, 0x00]) || startsWith(const [0x00, 0x00, 0x02, 0x00])) {
    return true;
  }
  // TIFF.
  if (startsWith(const [0x49, 0x49, 0x2A, 0x00]) || startsWith(const [0x4D, 0x4D, 0x00, 0x2A])) {
    return true;
  }
  // JPEG XL codestream or container.
  if (startsWith(const [0xFF, 0x0A]) || startsWith(const [0x00, 0x00, 0x00, 0x0C, 0x4A, 0x58, 0x4C, 0x20])) {
    return true;
  }
  // HEIF/AVIF family: ftyp at offset 4 and a still-image brand at offset 8.
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    const brands = {'avif', 'avis', 'heic', 'heix', 'hevc', 'mif1', 'msf1'};
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brands.contains(brand)) {
      return true;
    }
  }
  return false;
}

/// Writes [bytes] to [target] through a temporary file and a rename.
///
/// A crash between the write and the rename leaves a `.part` file in
/// [temporaryDirectory], never a half-written image under the real name.
/// A failed write is reported as a [CacheFailure] the caller may ignore.
Future<void> writeBytesAtomically({
  required File target,
  required Uint8List bytes,
  required Directory temporaryDirectory,
}) async {
  File? scratch;
  try {
    await target.parent.create(recursive: true);
    await temporaryDirectory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    scratch = File(p.join(temporaryDirectory.path, '${p.basename(target.path)}.$stamp.part'));
    final handle = await scratch.open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await target.exists()) {
      await target.delete();
    }
    await scratch.rename(target.path);
    scratch = null;
  } on FileSystemException catch (error) {
    throw _failureFor(error);
  } finally {
    if (scratch != null) {
      try {
        if (await scratch.exists()) {
          await scratch.delete();
        }
      } on FileSystemException {
        // A leftover part file is removed by the next startup sweep.
      }
    }
  }
}

/// Deletes [file], treating an absent or locked file as a normal outcome.
///
/// Windows keeps a file the engine is still reading locked; the caller
/// records the miss and tries again on the next cleanup.
Future<bool> deleteFileQuietly(File file) async {
  try {
    if (!await file.exists()) {
      return false;
    }
    await file.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

CacheFailure _failureFor(FileSystemException error) {
  final message = error.message.toLowerCase();
  final osError = error.osError?.message.toLowerCase() ?? '';
  final text = '$message $osError';
  if (text.contains('space') || text.contains('disk full') || text.contains('no space')) {
    return CacheFailure(CacheFailureKind.diskFull, message: error.message, cause: error);
  }
  if (text.contains('denied') || text.contains('permission') || text.contains('read-only')) {
    return CacheFailure(CacheFailureKind.permission, message: error.message, cause: error);
  }
  return CacheFailure(CacheFailureKind.unknown, message: error.message, cause: error);
}
