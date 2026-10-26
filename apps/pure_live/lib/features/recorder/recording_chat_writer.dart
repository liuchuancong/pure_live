import 'dart:convert';
import 'dart:io';

import 'package:live_sites/live_sites.dart' show LiveMessage, LiveMessageColor;

/// Writes one recording session's live chat beside its video as the Bilibili
/// danmaku XML (`<d p="time,mode,size,color,unix,pool,user,row">text</d>`)
/// that DanmakuFactory, PotPlayer and the biliup/blrec tools read.
///
/// The file is kept complete after every [flush]: the closing `</i>` is
/// rewritten behind the new entries, so a killed process leaves a readable
/// file instead of an unterminated one. Entry times are seconds from the
/// recording's own start.
final class RecordChatWriter {
  RecordChatWriter._(this.file, this._handle, this._startedAt, this._end);

  /// Creates [file] and writes the header; times are seconds from
  /// [startedAt] (the moment the recorded video began).
  static Future<RecordChatWriter> open(File file, {required DateTime startedAt}) async {
    final handle = await file.open(mode: FileMode.write);
    try {
      await handle.writeFrom(utf8.encode('$_header$_closing'));
      return RecordChatWriter._(file, handle, startedAt, _header.length);
    } on Object {
      await handle.close();
      rethrow;
    }
  }

  static const String _header = '<?xml version="1.0" encoding="UTF-8"?>\n<i>\n<chatserver>pure_live</chatserver>\n';
  static const String _closing = '</i>\n';

  /// The file the chat is written to.
  final File file;

  final RandomAccessFile _handle;
  final DateTime _startedAt;
  final StringBuffer _pending = StringBuffer();
  int _end;
  int _count = 0;
  bool _closed = false;
  Future<void>? _writing;

  /// Chat entries added.
  int get count => _count;

  /// Adds [message] received at [receivedAt]; written at the next [flush].
  /// Only chat messages are recorded (the reference's switch saves chat,
  /// not gifts, unless its own gift option is on).
  void add(LiveMessage message, {required DateTime receivedAt}) {
    if (_closed) return;
    final text = escape(message.text);
    if (text.isEmpty) return;
    final offset = receivedAt.difference(_startedAt).inMilliseconds / 1000.0;
    final seconds = offset < 0 ? 0.0 : offset;
    final color = _colorOf(message.color);
    final sender = message.sender;
    final userKey = sender == null || sender.userId.isEmpty ? sender?.userName ?? '' : sender.userId;
    final user = userKey.hashCode.toUnsigned(32);
    final unix = (message.sentAt ?? receivedAt).millisecondsSinceEpoch ~/ 1000;
    _pending.write(
      '<d p="${seconds.toStringAsFixed(3)},1,25,$color,$unix,0,${user.toRadixString(16)},0" '
      'user="${escape(sender?.userName ?? '')}">$text</d>\n',
    );
    _count++;
  }

  static int _colorOf(LiveMessageColor? color) {
    final value = color ?? LiveMessageColor.white;
    return (value.r << 16) | (value.g << 8) | value.b;
  }

  /// Writes the pending entries followed by the closing tag.
  Future<void> flush() async {
    if (_closed) return;
    while (_writing != null) {
      await _writing;
    }
    if (_pending.isEmpty) return;
    final bytes = utf8.encode(_pending.toString());
    _pending.clear();
    final write = () async {
      await _handle.setPosition(_end);
      await _handle.writeFrom(bytes);
      _end += bytes.length;
      await _handle.writeFrom(utf8.encode(_closing));
      await _handle.flush();
    }();
    _writing = write;
    try {
      await write;
    } finally {
      _writing = null;
    }
  }

  /// Flushes everything and closes the file.
  Future<void> close() async {
    if (_closed) return;
    try {
      await flush();
    } finally {
      _closed = true;
      await _handle.close();
    }
  }

  /// XML-escapes [value] and drops characters XML 1.0 cannot carry.
  static String escape(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final allowed =
          rune == 0x9 ||
          rune == 0xA ||
          rune == 0xD ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          rune >= 0x10000;
      if (!allowed) continue;
      buffer.write(switch (rune) {
        0x26 => '&amp;',
        0x3C => '&lt;',
        0x3E => '&gt;',
        0x22 => '&quot;',
        0x27 => '&apos;',
        _ => String.fromCharCode(rune),
      });
    }
    return buffer.toString().trim();
  }
}
