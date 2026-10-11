// Module: lib/src/models/media/lyric_document.dart
// Purpose: Lyric text one item carries, in the source's own format.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (`LyricCapability`).
//
// Delivered as **text, not a parsed line list**, on purpose: LRC parsing already has owners (`ui/lyric` renders
// it, `features/music` displays it) and the source's format varies - lx scripts hand back raw LRC, bilibili
// returns a JSON line array, some sites return untimed plain text. A `List<LyricLine>` field would force every
// provider to parse and every consumer to trust that parse, and the timestamp-free case would have nowhere to
// go. So the contract says "here is the text, and whether it is timed".

import 'package:equatable/equatable.dart';

import '../../support/json.dart';
import '../content/content_ref/content_ref.dart';

/// Lyric text for one item.
final class LyricDocument extends Equatable {
  const LyricDocument({
    required this.ref,
    required this.text,
    this.translatedText,
    this.isSynced = true,
    this.language,
    this.sourceLabel,
    this.extra = const <String, Object?>{},
  });

  factory LyricDocument.fromJson(Map<String, Object?> json) => LyricDocument(
    ref: ContentRef.fromJson(asObjectMap(json['ref'])),
    text: json['text'] is String ? json['text']! as String : '',
    translatedText: json['translatedText'] is String ? json['translatedText']! as String : null,
    isSynced: json['isSynced'] as bool? ?? true,
    language: json['language'] is String ? json['language']! as String : null,
    sourceLabel: json['sourceLabel'] is String ? json['sourceLabel']! as String : null,
    extra: asObjectMap(json['extra']),
  );

  final ContentRef ref;

  /// The body as the source wrote it. Empty means "there is no lyric", which is a normal answer for an
  /// instrumental track and not a failure - the distinction the lyric panel needs.
  final String text;

  /// A second language when the source serves one. Kept beside rather than interleaved: a translation merged
  /// into one string cannot be split back reliably, and a panel that shows one line per timestamp has to choose
  /// which language it is aligned to.
  final String? translatedText;

  /// False when the text carries no timestamps. A surface must then stop scrolling with the audio instead of
  /// waiting for a line that never arrives.
  final bool isSynced;

  final String? language;

  /// Which lyric provider served it, when the platform says ("网易英译" rows and user uploads differ about
  /// timing, and a user wants to know which one they are looking at).
  final String? sourceLabel;
  final Map<String, Object?> extra;

  bool get isEmpty => text.trim().isEmpty;

  bool get hasTranslation => translatedText?.trim().isNotEmpty == true;

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref.toJson(),
    'text': text,
    if (translatedText != null) 'translatedText': translatedText,
    if (!isSynced) 'isSynced': false,
    if (language != null) 'language': language,
    if (sourceLabel != null) 'sourceLabel': sourceLabel,
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  List<Object?> get props => <Object?>[ref, text, translatedText, isSynced, language, sourceLabel];
}
