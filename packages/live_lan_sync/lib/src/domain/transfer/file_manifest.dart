import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;

/// What a file is, exchanged before any byte of it moves (spec §13.2).
///
/// The sender computes it in one pass over the file: the whole-file
/// SHA-256 and one SHA-256 per chunk. The receiver checks every chunk
/// against its listed hash as it lands — so a file that changes while it is
/// being sent, or a chunk damaged on disk between sessions, is caught at
/// once — and the assembled file against the whole hash before anything is
/// committed.
///
/// [fileName] is display metadata only: a receiver never builds a path from
/// it. Its file adapter decides where a file lands.
final class FileManifest {
  /// A file's description.
  const new({
    required this.fileId,
    required this.category,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.sha256,
    required this.chunkSize,
    required this.chunkSha256,
    this.schemaVersion = 1,
  });

  /// Restores and validates a manifest from the wire.
  ///
  /// Throws a [LanSyncError] with `dataValidation` for anything inconsistent:
  /// a hash that is not SHA-256 hex, a chunk size outside 64 KiB–16 MiB, a
  /// chunk list that does not cover the size, or empty identifiers.
  factory fromJson(Map<String, Object?> json) {
    String text(String key, {int max = 256}) => switch (json[key]) {
      final String value when value.isNotEmpty && value.length <= max => value,
      _ => throw _invalid('The file field "$key" is missing or malformed.'),
    };
    int number(String key) => switch (json[key]) {
      final num value when value >= 0 && value == value.toInt() => value.toInt(),
      _ => throw _invalid('The file field "$key" is missing or malformed.'),
    };
    final size = number('size');
    final chunkSize = number('chunkSize');
    if (chunkSize < minChunkSize || chunkSize > maxChunkSize) {
      throw _invalid('The chunk size must be between 64 KiB and 16 MiB.');
    }
    final hashes = switch (json['chunkSha256']) {
      final List<Object?> list => [for (final item in list) _hash(item)],
      null => const <String>[],
      _ => throw _invalid('The chunk hashes are malformed.'),
    };
    final manifest = FileManifest(
      fileId: text('fileId'),
      category: text('category', max: 64),
      fileName: sanitizeFileName(json['fileName'] is String ? json['fileName']! as String : ''),
      mimeType: switch (json['mimeType']) {
        final String value when value.length <= 128 => value,
        _ => 'application/octet-stream',
      },
      size: size,
      sha256: _hash(json['sha256']),
      chunkSize: chunkSize,
      chunkSha256: hashes,
      schemaVersion: switch (json['schemaVersion']) {
        final num value => value.toInt(),
        _ => 1,
      },
    );
    if (hashes.isNotEmpty && hashes.length != manifest.totalChunks) {
      throw _invalid('The chunk hashes do not cover the file.');
    }
    if (json['totalChunks'] case final num declared when declared.toInt() != manifest.totalChunks) {
      throw _invalid('The chunk count does not match the size.');
    }
    return manifest;
  }

  /// The smallest chunk the protocol moves.
  static const int minChunkSize = 64 * 1024;

  /// The largest chunk the protocol moves.
  static const int maxChunkSize = 16 * 1024 * 1024;

  /// The file's stable id within its category, the business side's handle.
  final String fileId;

  /// The file adapter category, e.g. `font` or `wallpaper`.
  final String category;

  /// The sender's file name, sanitized; display only.
  final String fileName;

  /// The declared MIME type; the receiving adapter verifies content itself.
  final String mimeType;

  /// The exact size in bytes.
  final int size;

  /// The lowercase hex SHA-256 of the whole file.
  final String sha256;

  /// The size of every chunk but the last.
  final int chunkSize;

  /// The lowercase hex SHA-256 of each chunk, in order; empty when the
  /// sender did not hash chunks.
  final List<String> chunkSha256;

  /// The manifest format version.
  final int schemaVersion;

  /// How many chunks carry the file; 0 for an empty file.
  int get totalChunks => size == 0 ? 0 : (size + chunkSize - 1) ~/ chunkSize;

  /// The byte length of chunk [index].
  int chunkLength(int index) => index < totalChunks - 1 ? chunkSize : size - chunkSize * (totalChunks - 1);

  /// The wire form.
  Map<String, Object?> toJson() => <String, Object?>{
    'fileId': fileId,
    'category': category,
    'fileName': fileName,
    'mimeType': mimeType,
    'size': size,
    'sha256': sha256,
    'chunkSize': chunkSize,
    'totalChunks': totalChunks,
    'chunkSha256': chunkSha256,
    'schemaVersion': schemaVersion,
  };

  /// A file name safe to show and, if an adapter chooses, to use as one
  /// path segment: no directories, no `..`, no control or reserved
  /// characters, no Windows device names, at most 120 characters.
  static String sanitizeFileName(String name) {
    var base = name.split(RegExp(r'[/\\]')).last;
    base = base.replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*]'), '_').trim();
    base = base.replaceAll(RegExp(r'^\.+'), '').replaceAll(RegExp(r'[. ]+$'), '');
    if (base.length > 120) {
      final dot = base.lastIndexOf('.');
      final extension = dot > 0 && base.length - dot <= 16 ? base.substring(dot) : '';
      base = base.substring(0, 120 - extension.length) + extension;
    }
    final stem = base.split('.').first.toUpperCase();
    const reserved = {'CON', 'PRN', 'AUX', 'NUL'};
    if (reserved.contains(stem) || RegExp(r'^(COM|LPT)[0-9]$').hasMatch(stem)) {
      base = '_$base';
    }
    return base.isEmpty ? 'file' : base;
  }

  static String _hash(Object? value) => switch (value) {
    final String hex when RegExp(r'^[0-9a-f]{64}$').hasMatch(hex) => hex,
    _ => throw _invalid('A file hash is not a lowercase SHA-256.'),
  };

  @override
  String toString() => 'FileManifest($category/$fileId, $size bytes, $totalChunks chunks)';
}

LanSyncError _invalid(String message) =>
    LanSyncError(category: LanSyncErrorCategory.dataValidation, code: 'file_manifest_invalid', message: message);
