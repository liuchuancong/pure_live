import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:pinyindart/pinyindart.dart';

/// What one recording's directory and file names are.
///
/// A recording has three names and they must not collapse into one:
///
/// - the **capture name** is what FFmpeg opens and writes. It is pure ASCII —
///   [taskId] — because the muxer's own path handling is where a Chinese room
///   title breaks first: the segment template repeats the prefix, and a Windows
///   build opens paths through the local code page, so a long non-ASCII path
///   fails with an error that says nothing about either. A session lost to the
///   length of a title is not a cosmetic problem.
/// - the **session directory** is how a folder of hundreds of files stays
///   findable: `<root>/<platform>/<anchor>/<YYYY-MM-DD>`. Its anchor component is
///   ASCII too, for the same reason, chosen by [AnchorDirectoryStyle].
/// - the **display name** is the Chinese file name the viewer reads
///   ([displayNameFor]). It is applied only after the merge, by this package's
///   file layer, which handles Unicode paths. Renaming is not part of capturing:
///   a rename that fails leaves a playable ASCII file plus the recorded intent to
///   try again, never a lost recording.
final class RecordPaths {
  /// Creates the paths for one task.
  const new({
    required this.rootDirectory,
    required this.platformSlug,
    required this.anchorSlug,
    required this.day,
    required this.taskId,
  });

  /// Root every recording lives under.
  final String rootDirectory;

  /// ASCII platform component (`douyin`, `bilibili`).
  final String platformSlug;

  /// ASCII anchor component (pinyin, or the room id when there is no pinyin).
  final String anchorSlug;

  /// Day component, `YYYY-MM-DD`, taken from when the recording started rather
  /// than from today, so a session that crosses midnight stays in one directory.
  final String day;

  /// ASCII capture identifier and file prefix. Never derived from a title.
  final String taskId;

  /// `<root>/<platform>/<anchor>/<day>`: everything this task writes lives here.
  String get sessionDirectory => p.joinAll(<String>[rootDirectory, platformSlug, anchorSlug, day]);

  /// The prefix FFmpeg is handed, identical to [taskId].
  String get capturePrefix => taskId;

  /// The merged file under its capture name, as the join step writes it.
  String get asciiMergedPath => p.join(sessionDirectory, '$taskId.combined.mp4');

  /// The file name the viewer is meant to see: the anchor's own name, the day and
  /// time, and the room title when there was one.
  ///
  /// Only characters a filesystem cannot accept are replaced; the script of the
  /// name survives, because this path is never opened by FFmpeg.
  String displayNameFor({String? anchorName, String? roomTitle, DateTime? startedAt, String extension = 'mp4'}) {
    final anchor = safePathComponent(anchorName == null || anchorName.isEmpty ? anchorSlug : anchorName);
    final title = roomTitle == null || roomTitle.trim().isEmpty ? '' : '_${safePathComponent(roomTitle, maxRunes: 40)}';
    final moment = startedAt == null ? day : '${day}_${_two(startedAt.hour)}${_two(startedAt.minute)}';

    return '${anchor}_$moment$title.$extension';
  }

  /// [sessionDirectory] joined with [displayNameFor].
  String displayPathFor({String? anchorName, String? roomTitle, DateTime? startedAt, String extension = 'mp4'}) {
    return p.join(
      sessionDirectory,
      displayNameFor(anchorName: anchorName, roomTitle: roomTitle, startedAt: startedAt, extension: extension),
    );
  }

  @override
  String toString() => 'RecordPaths(${p.join(platformSlug, anchorSlug, day, taskId)})';
}

/// How the anchor directory component is produced.
enum AnchorDirectoryStyle {
  /// Toneless lower-case pinyin of the anchor name (`zhubo8891`), which stays
  /// searchable against a Chinese UI; falls back to the room id when a name has
  /// no pinyin at all.
  pinyin,

  /// The room id alone: the safest component, and what a host whose server does
  /// its own naming should use.
  identifier,
}

/// Builds [RecordPaths] for tasks under one root directory.
final class RecordNaming {
  /// Creates the naming layer. Not const: [anchorDirectoryStyle] is edited
  /// live by the recorder settings.
  new({required this.rootDirectory, this.anchorDirectoryStyle = AnchorDirectoryStyle.pinyin});

  /// Root every recording lives under.
  final String rootDirectory;

  /// Which ASCII form the anchor directory takes. Mutable: the recorder
  /// settings' 拼音命名 edit reaches the next created task without re-opening
  /// the runtime, which would stop the recordings already running.
  AnchorDirectoryStyle anchorDirectoryStyle;

  static final Random _entropy = Random.secure();

  /// A capture identifier: `rec_` plus twelve hexadecimal characters.
  ///
  /// Random rather than sequential because two runs of the same app — a phone
  /// restarted after a crash, a second machine on one shared directory — must not
  /// produce the same prefix and write one recording into another's segments.
  static String newTaskId([Random? random]) {
    final source = random ?? _entropy;
    final buffer = StringBuffer('rec_');

    for (var part = 0; part < 3; part++) {
      buffer.write(source.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'));
    }

    return buffer.toString();
  }

  /// The paths for a task capturing [taskId] of the room described by
  /// [platformId], [anchorName] and [roomId], started at [startedAt].
  RecordPaths paths({
    required String taskId,
    required String platformId,
    required String anchorName,
    required String roomId,
    required DateTime startedAt,
  }) {
    final anchor = switch (anchorDirectoryStyle) {
      AnchorDirectoryStyle.pinyin => _pinyinOr(anchorName, fallback: roomId),
      AnchorDirectoryStyle.identifier => safePathComponent(roomId, asciiOnly: true, maxRunes: 40),
    };

    return RecordPaths(
      rootDirectory: rootDirectory,
      platformSlug: safePathComponent(platformId, asciiOnly: true, maxRunes: 32),
      anchorSlug: anchor,
      day: dayLabel(startedAt),
      taskId: taskId,
    );
  }

  /// `YYYY-MM-DD`, the session directory's day component.
  static String dayLabel(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-${_two(time.month)}-${_two(time.day)}';

  String _pinyinOr(String text, {required String fallback}) {
    final pinyin = safePinyinComponent(text);

    // A name with no letters in it (an emoji-only nickname, a pure-symbol room)
    // converts to nothing, and an empty directory component is worse than a
    // numeric one.
    if (pinyin == 'unknown') {
      return safePathComponent(fallback, asciiOnly: true, maxRunes: 40);
    }

    return pinyin;
  }
}

/// Characters a name component may not carry.
///
/// Dots are in here deliberately: a component built from an untrusted label never
/// needs one (the extension is added outside this function), and keeping them
/// invites `..`, a leading dot (a hidden entry on some platforms) and a trailing
/// one, which Windows refuses outright.
final RegExp _invalidComponentChars = RegExp(r'[\x00-\x1F<>:"/\\|?*.。，、？！~～·＆#]');
final RegExp _windowsReservedName = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$', caseSensitive: false);

/// One portable path component from an untrusted label.
///
/// Separators and reserved characters become `_`, trailing dots and spaces go, a
/// Windows device name gets a `_` prefix, and the result is capped at [maxRunes]
/// *runes* — cutting code units would leave a surrogate pair that no longer
/// compares equal to itself. Empty results are `unknown`, never `''`: an empty
/// component silently reparents the whole path.
String safePathComponent(String text, {bool asciiOnly = false, int maxRunes = 80}) {
  if (maxRunes < 1) {
    return 'unknown';
  }

  var value = text.trim().replaceAll(_invalidComponentChars, '_').replaceAll(RegExp(r'\s+'), '_');
  if (asciiOnly) {
    value = value.replaceAll(RegExp('[^a-zA-Z0-9_]'), '');
  }
  value = value.replaceAll(RegExp('_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');

  if (value.isEmpty || value.replaceAll('_', '').isEmpty || value == '.' || value == '..') {
    return 'unknown';
  }

  final runes = value.runes.toList(growable: false);
  if (runes.length > maxRunes) {
    value = String.fromCharCodes(runes.take(maxRunes)).replaceAll(RegExp(r'_+$'), '');
  }
  if (_windowsReservedName.hasMatch(value)) {
    value = '_$value';
  }

  return value;
}

/// [text] as a toneless lower-case ASCII component.
String safePinyinComponent(String text) {
  if (text.trim().isEmpty) {
    return 'unknown';
  }

  return safePathComponent(getPinyin(text, withTone: false, separator: ''), asciiOnly: true).toLowerCase();
}

String _two(int value) => value.toString().padLeft(2, '0');
