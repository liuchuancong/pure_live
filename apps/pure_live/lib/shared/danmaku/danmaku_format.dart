import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/danmaku/danmaku_entry.dart';
import 'package:pure_live/shared/danmaku/formats/formats.dart';

/// The file formats a saved danmaku set can take.
///
/// Every format writes the same [DanmakuEntry] list; XML, JSON and TXT also
/// read back, so a file this app saved (or one fetched from the platform) can
/// be loaded again. ASS and SRT are write-only: they are for players and
/// editors, not for this app to parse.
enum DanmakuFormat {
  /// The Bilibili XML a live recording writes and a player overlays.
  xml('xml', 'xml', readable: true),

  /// The Bilibili segment JSON.
  json('json', 'json', readable: true),

  /// An ASS subtitle script with moving lanes.
  ass('ass', 'ass'),

  /// Plain SRT subtitles, one cue per line.
  srt('srt', 'srt'),

  /// A plain-text listing with `[mm:ss.cc]` timestamps.
  txt('txt', 'txt', readable: true);

  DanmakuFormat(this.id, this.extension, {this.readable = false});

  /// The value the preference and the settings UI keep.
  final String id;

  /// The file extension, dot-free.
  final String extension;

  /// Whether [decode] can read this format back.
  final bool readable;

  /// The format's name in the viewer's language.
  String label(Translations t) => switch (this) {
    DanmakuFormat.xml => t.settings.danmakuFormatXml,
    DanmakuFormat.json => t.settings.danmakuFormatJson,
    DanmakuFormat.ass => t.settings.danmakuFormatAss,
    DanmakuFormat.srt => t.settings.danmakuFormatSrt,
    DanmakuFormat.txt => t.settings.danmakuFormatTxt,
  };

  /// Writes [entries] in this format.
  String encode(Iterable<DanmakuEntry> entries) => switch (this) {
    DanmakuFormat.xml => BilibiliDanmakuXml.encode(entries),
    DanmakuFormat.json => BilibiliDanmakuJson.encode(entries),
    DanmakuFormat.ass => AssDanmaku.encode(entries),
    DanmakuFormat.srt => SrtDanmaku.encode(entries),
    DanmakuFormat.txt => TextDanmaku.encode(entries),
  };

  /// Reads [source] back; empty when this format cannot be read.
  List<DanmakuEntry> decode(String source) => switch (this) {
    DanmakuFormat.xml => BilibiliDanmakuXml.decode(source),
    DanmakuFormat.json => BilibiliDanmakuJson.decode(source),
    DanmakuFormat.txt => TextDanmaku.decode(source),
    DanmakuFormat.ass || DanmakuFormat.srt => const [],
  };

  /// The format [id] names, or null.
  static DanmakuFormat? byId(String id) {
    for (final format in values) {
      if (format.id == id) return format;
    }
    return null;
  }
}
