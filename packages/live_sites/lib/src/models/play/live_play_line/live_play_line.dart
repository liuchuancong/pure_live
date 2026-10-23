// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';

part 'live_play_line.g.dart';

/// One playable line: self-describing, so the player needs no per-platform
/// code.
///
/// [format] is required — a line whose container is unknown reports
/// `LiveStreamFormat.other`, it never leaves the field null. [formatSource]
/// says whether the platform declared that format or it was inferred from the
/// URL; an inferred format must stay overridable by first-byte probing.
abstract class LivePlayLine implements Built<LivePlayLine, LivePlayLineBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LivePlayLine([void Function(LivePlayLineBuilder)? updates]) = _$LivePlayLine;

  /// Creates a LivePlayLine with already-normalized fields.
  factory LivePlayLine.of({
    required String url,
    required LiveStreamFormat format,
    required LivePlayFormatSource formatSource,
    Map<String, String> headers = const {},
    LiveStreamCodec? codec,
    String? lineLabel,
    LivePlayLease? lease,
    PlayGeometry? geometry,
    bool singleUse = false,
  }) => LivePlayLine(
    (b) => b
      ..url = url
      ..format = format
      ..formatSource = formatSource
      ..headers.replace(headers)
      ..codec = codec
      ..lineLabel = lineLabel
      ..lease = lease?.toBuilder()
      ..geometry.replace(geometry ?? PlayGeometry())
      ..singleUse = singleUse,
  );

  LivePlayLine._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LivePlayLineBuilder b) => b
    ..geometry.replace(PlayGeometry())
    ..singleUse = false;

  /// The playable address.
  String get url;

  /// The stream's container format.
  LiveStreamFormat get format;

  /// Whether the platform declared [format] or it was inferred.
  LivePlayFormatSource get formatSource;

  /// The request headers the address requires.
  BuiltMap<String, String> get headers;

  /// The stream's codec, when known.
  LiveStreamCodec? get codec;

  /// The platform's label for the line, when it has one.
  String? get lineLabel;

  /// The URL's short-lived lifetime, when it has one.
  LivePlayLease? get lease;

  /// The geometry the platform declared.
  PlayGeometry get geometry;

  /// Whether this URL starts playback only once: re-opening the same
  /// address fails even before its lease expires, and the player must
  /// re-resolve instead of replaying it. Long-lived, re-openable lines
  /// stay false.
  bool get singleUse;
}

/// Declared-geometry accessor for [LivePlayLine].
extension LivePlayLineGeometry on LivePlayLine {
  /// The declared aspect ratio from [geometry], or null when undeclared.
  double? get declaredAspectRatio => geometry.declaredAspectRatio;
}
