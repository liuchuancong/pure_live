import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_play_line.freezed.dart';

/// One playable line: self-describing, so the player needs no per-platform
/// code.
///
/// [format] is required — a line whose container is unknown reports
/// `LiveStreamFormat.other`, it never leaves the field null. [formatSource]
/// says whether the platform declared that format or it was inferred from the
/// URL; an inferred format must stay overridable by first-byte probing.
@freezed
abstract class LivePlayLine with _$LivePlayLine {
  /// Creates a LivePlayLine with already-normalized fields.
  const factory LivePlayLine({
    required String url,
    required LiveStreamFormat format,
    required LivePlayFormatSource formatSource,
    @Default({}) Map<String, String> headers,
    LiveStreamCodec? codec,
    String? lineLabel,
    LivePlayLease? lease,
    @Default(PlayGeometry()) PlayGeometry geometry,
  }) = _LivePlayLine;
}

/// Declared-geometry accessor for [LivePlayLine].
///
/// A separate extension because freezed cannot implement a private
/// generative constructor next to required factory parameters.
extension LivePlayLineGeometry on LivePlayLine {
  /// The declared aspect ratio from [geometry], or null when undeclared.
  double? get declaredAspectRatio => geometry.declaredAspectRatio;
}
