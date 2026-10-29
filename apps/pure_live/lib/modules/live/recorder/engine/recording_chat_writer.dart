import 'dart:convert' show utf8;
import 'dart:io';

import 'package:live_sites/live_sites.dart' show LiveMessage, LiveMessageColor;
import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuColor;
import 'package:pure_live/shared/danmaku/danmaku.dart'
    show BilibiliDanmakuXml, DanmakuEntry, DanmakuFormat, SrtDanmaku, TextDanmaku;

/// Writes one recording session's live chat beside its video, in every format
/// the viewer chose in Settings → 弹幕 → 弹幕文件.
///
/// XML, SRT and TXT append only the new lines, so a long recording never
/// rewrites what it already wrote; ASS and JSON are single documents and are
/// rewritten on a slower cadence (and on close), which keeps a live take
/// readable without rewriting a large file every flush.
///
/// Times are seconds from the moment the recorded video began —
/// so a player loads the file against the video with no offset.
final class RecordChatWriter {
  RecordChatWriter._(this._base, this._startedAt, this._formats);

  /// Creates the sidecar files for a take whose path (without extension) is
  /// [base], and writes their headers.
  static Future<RecordChatWriter> open(
    String base, {
    required DateTime startedAt,
    required Iterable<DanmakuFormat> formats,
  }) async {
    final chosen = formats.toSet();
    if (chosen.isEmpty) chosen.add(DanmakuFormat.xml);
    final writer = RecordChatWriter._(base, startedAt, chosen);
    await writer._openFiles();
    return writer;
  }

  /// How often the whole-document formats (ASS, JSON) are rewritten while a
  /// take runs; every other flush appends to the rest.
  static const Duration _fullRewriteEvery = Duration(seconds: 30);

  /// The ASS header a take's sidecar starts with.
  static const String _assHeader =
      '[Script Info]\n'
      'Title: pure_live recording\n'
      'ScriptType: v4.00+\n'
      'WrapStyle: 2\n'
      'PlayResX: 1920\n'
      'PlayResY: 1080\n'
      'ScaledBorderAndShadow: yes\n'
      '\n'
      '[V4+ Styles]\n'
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, '
      'Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, '
      'Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n'
      'Style: Danmaku,Microsoft YaHei,40,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,0,7,0,0,0,1\n'
      '\n'
      '[Events]\n'
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n';

  /// The take's path without an extension; each format appends its own.
  final String _base;

  final DateTime _startedAt;
  final Set<DanmakuFormat> _formats;

  final Map<DanmakuFormat, RandomAccessFile> _handles = {};
  final Map<DanmakuFormat, int> _ends = {};
  final List<DanmakuEntry> _entries = [];
  int _flushed = 0;
  int _srtIndex = 1;
  DateTime? _lastFullWrite;
  bool _closed = false;
  Future<void>? _writing;

  /// The path of the XML sidecar, the one every player reads.
  String get xmlPath => '$_base.${DanmakuFormat.xml.extension}';

  /// Chat entries added.
  int get count => _entries.length;

  /// Adds [message] received at [receivedAt]; written at the next [flush].
  /// Only chat messages are recorded (the reference saves chat, not gifts).
  void add(LiveMessage message, {required DateTime receivedAt}) {
    if (_closed) return;
    final text = message.text.trim();
    if (text.isEmpty) return;
    final offset = receivedAt.difference(_startedAt);
    final sender = message.sender;
    final user = sender == null ? '' : (sender.userName.isEmpty ? sender.userId : sender.userName);
    final color = message.color ?? LiveMessageColor.white;
    _entries.add(
      DanmakuEntry(
        time: offset.isNegative ? Duration.zero : offset,
        text: text,
        color: DanmakuColor(color.r, color.g, color.b),
        user: user,
      ),
    );
  }

  Future<void> _openFiles() async {
    for (final format in _formats) {
      final file = File('$_base.${format.extension}');
      final handle = await file.open(mode: FileMode.write);
      try {
        final header = switch (format) {
          DanmakuFormat.xml => _xmlHeader,
          DanmakuFormat.ass => _assHeader,
          DanmakuFormat.json || DanmakuFormat.srt || DanmakuFormat.txt => '',
        };
        final bytes = utf8.encode(format == DanmakuFormat.xml ? '$header$_xmlClosing' : header);
        await handle.writeFrom(bytes);
        _ends[format] = format == DanmakuFormat.xml ? header.length : bytes.length;
        _handles[format] = handle;
      } on Object {
        await handle.close();
        rethrow;
      }
    }
  }

  /// Writes the entries added since the last flush.
  Future<void> flush({bool force = false}) async {
    if (_closed || (_entries.length == _flushed && !force)) return;
    while (_writing != null) {
      await _writing;
    }
    final write = _writePending(force: force);
    _writing = write;
    try {
      await write;
    } finally {
      _writing = null;
    }
  }

  Future<void> _writePending({required bool force}) async {
    final fresh = _entries.sublist(_flushed);
    final now = DateTime.now();
    final full = force || _lastFullWrite == null || now.difference(_lastFullWrite!) >= _fullRewriteEvery;
    for (final format in _formats) {
      final handle = _handles[format];
      if (handle == null) continue;
      switch (format) {
        case DanmakuFormat.xml:
          final body = StringBuffer();
          for (final entry in fresh) {
            body.write(BilibiliDanmakuXml.encodeEntry(entry));
          }
          final bytes = utf8.encode(body.toString());
          await handle.setPosition(_ends[format]!);
          await handle.writeFrom(bytes);
          _ends[format] = _ends[format]! + bytes.length;
          await handle.writeFrom(utf8.encode(_xmlClosing));
          await handle.flush();
        case DanmakuFormat.srt:
          final body = StringBuffer();
          for (final entry in fresh) {
            body.write(SrtDanmaku.cue(entry, _srtIndex++));
          }
          await _append(handle, format, body.toString());
        case DanmakuFormat.txt:
          final body = StringBuffer();
          for (final entry in fresh) {
            body.write(TextDanmaku.line(entry));
          }
          await _append(handle, format, body.toString());
        case DanmakuFormat.ass:
          if (full) await _rewrite(handle, format, DanmakuFormat.ass.encode(_entries));
        case DanmakuFormat.json:
          if (full) await _rewrite(handle, format, DanmakuFormat.json.encode(_entries));
      }
    }
    _flushed = _entries.length;
    if (full) _lastFullWrite = now;
  }

  Future<void> _append(RandomAccessFile handle, DanmakuFormat format, String body) async {
    if (body.isEmpty) return;
    final bytes = utf8.encode(body);
    await handle.setPosition(_ends[format]!);
    await handle.writeFrom(bytes);
    _ends[format] = _ends[format]! + bytes.length;
    await handle.flush();
  }

  Future<void> _rewrite(RandomAccessFile handle, DanmakuFormat format, String body) async {
    final bytes = utf8.encode(body);
    await handle.truncate(0);
    await handle.setPosition(0);
    await handle.writeFrom(bytes);
    await handle.flush();
    _ends[format] = bytes.length;
  }

  /// Flushes everything and closes every file.
  Future<void> close() async {
    if (_closed) return;
    try {
      await flush(force: true);
    } finally {
      _closed = true;
      for (final handle in _handles.values) {
        await handle.close();
      }
      _handles.clear();
    }
  }

  static const String _xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>\n<i>\n<chatserver>pure_live</chatserver>\n';
  static const String _xmlClosing = '</i>\n';
}
