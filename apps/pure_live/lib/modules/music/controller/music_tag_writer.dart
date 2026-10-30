import 'dart:convert' show utf8;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:media_core_audio/media_core_audio.dart' as audio;

/// The changed parts of a song's tags — the write half of the reference's
/// 编辑歌曲标签.
///
/// A null field leaves what the file already carries alone; an explicit empty
/// [picture] removes the embedded one.
final class MusicTagWrite {
  /// What should change about the tags.
  const MusicTagWrite({this.title, this.artist, this.album, this.lyric, this.picture});

  final String? title;
  final String? artist;
  final String? album;
  final String? lyric;

  /// The new cover bytes, or an empty list to remove the embedded cover.
  final Uint8List? picture;
}

/// Writes [tags] back into the audio file at [path].
///
/// Fields the caller left null keep the file's own values, so an edit of one
/// line never wipes the rest — the current tags are read back and merged
/// before anything is rebuilt. mp3 is rewritten as an ID3v2.3 tag ahead of the
/// audio (with the v1 tail refreshed when there is one), flac through its
/// Vorbis-comment and picture blocks; any other format throws
/// [UnsupportedError], the dialog words that as an unsupported-format toast.
Future<void> writeAudioTags(String path, MusicTagWrite tags) async {
  final file = File(path);
  final current = await const audio.AudioTagReader().read(file);
  final title = _merged(tags.title, current.title);
  final artist = _merged(tags.artist, current.artist);
  final album = _merged(tags.album, current.album);
  final lyric = _merged(tags.lyric, current.lyric);
  final picture = tags.picture == null ? current.picture?.bytes : (tags.picture!.isEmpty ? null : tags.picture);
  if (title == null && artist == null && album == null && lyric == null && picture == null) return;

  switch (_extensionOf(path)) {
    case 'mp3':
      await _writeMp3(file, title, artist, album, lyric, picture);
    case 'flac':
      await _writeFlac(file, title, artist, album, lyric, picture);
    default:
      throw UnsupportedError('tag writing is not supported for .$_extensionOf(path)');
  }
}

String? _merged(String? requested, String? current) {
  if (requested != null) return requested.isEmpty ? null : requested;
  final value = current?.trim() ?? '';
  return value.isEmpty ? null : value;
}

String _extensionOf(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
}

String _mimeOf(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
  if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'image/png';
  }
  return 'application/octet-stream';
}

// -----------------------------------------------------------------------------
// mp3 / ID3v2.3
// -----------------------------------------------------------------------------

Future<void> _writeMp3(File file, String? title, String? artist, String? album, String? lyric, Uint8List? picture) async {
  final bytes = await file.readAsBytes();
  var body = bytes;

  // The old tag is dropped whole — a fresh one is built in its place.
  if (bytes.length > 10 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
    final end = (10 + _syncsafe(bytes, 6) + (bytes[5] & 0x10 != 0 ? 10 : 0)).clamp(0, bytes.length);
    body = Uint8List.sublistView(bytes, end);
  }

  // The v1 tail is refreshed in place rather than dropped: files that carried
  // one keep one.
  Uint8List? v1;
  if (body.length >= 128 && body[body.length - 128] == 0x54 && body[body.length - 127] == 0x41 && body[body.length - 126] == 0x47) {
    v1 = Uint8List.sublistView(body, body.length - 128);
    body = Uint8List.sublistView(body, 0, body.length - 128);
  }

  final frames = BytesBuilder();
  void text(String id, String? value) {
    if (value == null) return;
    frames.add(_frame(id, [0x01, ..._utf16(value)]));
  }

  text('TIT2', title);
  text('TPE1', artist);
  text('TALB', album);
  if (lyric != null) {
    frames.add(_frame('USLT', [0x01, 0x65, 0x6E, 0x67, ..._utf16(''), ..._utf16Body(lyric)]));
  }
  if (picture != null) {
    final mime = _mimeOf(picture);
    frames.add(_frame('APIC', [0x01, ...mime.codeUnits, 0x00, 0x03, ..._utf16(''), ...picture]));
  }

  final content = frames.takeBytes();
  final out = BytesBuilder()
    ..add([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, ..._syncsafeBytes(content.length)])
    ..add(content)
    ..add(body)
    ..add(v1 == null ? const <int>[] : _refreshV1(v1, title, artist, album));

  await file.writeAsBytes(out.takeBytes(), flush: true);
}

Uint8List _refreshV1(Uint8List old, String? title, String? artist, String? album) {
  final tail = Uint8List.fromList(old);
  void field(int start, String? value) {
    if (value == null) return;
    final encoded = utf8.encode(value);
    for (var index = 0; index < 30; index++) {
      tail[start + index] = index < encoded.length ? encoded[index] : 0x00;
    }
  }

  field(3, title);
  field(33, artist);
  field(63, album);
  return tail;
}

List<int> _frame(String id, List<int> content) => [
  ...id.codeUnits,
  (content.length >> 24) & 0xFF,
  (content.length >> 16) & 0xFF,
  (content.length >> 8) & 0xFF,
  content.length & 0xFF,
  0x00,
  0x00,
  ...content,
];

/// UTF-16LE with a BOM and the double-zero terminator ID3 text expects.
List<int> _utf16(String text) => [..._utf16Body(text), 0x00, 0x00];

/// UTF-16LE with a BOM but no terminator — the USLT lyric runs to the frame's
/// end, where a terminator would decode back as a trailing NUL.
List<int> _utf16Body(String text) => [
  0xFF,
  0xFE,
  for (final unit in text.codeUnits) ...[unit & 0xFF, (unit >> 8) & 0xFF],
];

int _syncsafe(Uint8List bytes, int offset) =>
    ((bytes[offset] & 0x7F) << 21) | ((bytes[offset + 1] & 0x7F) << 14) | ((bytes[offset + 2] & 0x7F) << 7) | (bytes[offset + 3] & 0x7F);

List<int> _syncsafeBytes(int value) => [(value >> 21) & 0x7F, (value >> 14) & 0x7F, (value >> 7) & 0x7F, value & 0x7F];

// -----------------------------------------------------------------------------
// flac / Vorbis comment + picture block
// -----------------------------------------------------------------------------

Future<void> _writeFlac(File file, String? title, String? artist, String? album, String? lyric, Uint8List? picture) async {
  final bytes = await file.readAsBytes();
  if (bytes.length < 8 || bytes[0] != 0x66 || bytes[1] != 0x4C || bytes[2] != 0x61 || bytes[3] != 0x43) {
    throw const FormatException('not a flac stream');
  }

  final textChanged = title != null || artist != null || album != null || lyric != null;
  final blocks = <(int, Uint8List)>[];
  var offset = 4;
  var sawComment = false;
  var sawPicture = false;
  var audioStart = bytes.length;
  var guard = 0;

  while (offset + 4 <= bytes.length && guard++ < 256) {
    final last = bytes[offset] & 0x80 != 0;
    final type = bytes[offset] & 0x7F;
    final size = (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
    final start = offset + 4;
    if (start + size > bytes.length) break;
    audioStart = start + size;

    if (type == 4) {
      sawComment = true;
      blocks.add((4, textChanged ? _vorbisComment(title, artist, album, lyric) : Uint8List.sublistView(bytes, start, start + size)));
    } else if (type == 6) {
      sawPicture = true;
      if (picture != null) blocks.add((6, _flacPicture(picture)));
    } else {
      blocks.add((type, Uint8List.sublistView(bytes, start, start + size)));
    }

    offset = start + size;
    if (last) break;
  }

  if (textChanged && !sawComment) blocks.add((4, _vorbisComment(title, artist, album, lyric)));
  if (picture != null && !sawPicture) blocks.add((6, _flacPicture(picture)));

  // The `last` flag belongs to whatever block now stands last.
  final out = BytesBuilder()..add([0x66, 0x4C, 0x61, 0x43]);
  for (final (index, (type, content)) in blocks.indexed) {
    final last = index == blocks.length - 1;
    out
      ..add([(last ? 0x80 : 0x00) | (type & 0x7F), (content.length >> 16) & 0xFF, (content.length >> 8) & 0xFF, content.length & 0xFF])
      ..add(content);
  }
  out.add(Uint8List.sublistView(bytes, audioStart));
  await file.writeAsBytes(out.takeBytes(), flush: true);
}

Uint8List _vorbisComment(String? title, String? artist, String? album, String? lyric) {
  final vendor = utf8.encode('pure_live');
  final entries = [
    for (final (key, value) in [('TITLE', title), ('ARTIST', artist), ('ALBUM', album), ('LYRICS', lyric)])
      if (value != null) utf8.encode('$key=$value'),
  ];
  final out = BytesBuilder()
    ..add(_le32(vendor.length))
    ..add(vendor)
    ..add(_le32(entries.length));
  for (final entry in entries) {
    out..add(_le32(entry.length))..add(entry);
  }
  return out.takeBytes();
}

Uint8List _flacPicture(Uint8List bytes) {
  final mime = _mimeOf(bytes);
  final out = BytesBuilder()
    ..add(_be32(3)) // front cover
    ..add(_be32(mime.length))
    ..add(mime.codeUnits)
    ..add(_be32(0)) // no description
    ..add(_be32(0))
    ..add(_be32(0))
    ..add(_be32(0))
    ..add(_be32(0))
    ..add(_be32(bytes.length))
    ..add(bytes);
  return out.takeBytes();
}

List<int> _le32(int value) => [value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF];

List<int> _be32(int value) => [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
