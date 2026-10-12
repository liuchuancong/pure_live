import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_sites/src/models/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/quality_label/quality_label.dart';

part 'live_play_url_resolution.freezed.dart';

/// What a site answered when asked to resolve play URLs for a room.
///
/// The distinction this type exists for: the quality the caller **asked for**
/// and the quality the site **confirmed** are different facts, and playback
/// needs both. A site may answer a request for 蓝光 with 超清 (the requested
/// level is not offered for this room, or is login-gated), and a player that
/// records "the user is watching 蓝光" then shows the wrong label forever —
/// or, worse, re-requests 蓝光 on every recovery and gets 超清 again.
///
/// [lines] are the resolved, self-describing lines (URL, headers, lease,
/// codec, size) exactly as the site returned them, in its own order: the
/// fallback ladder tries line 1 first.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LivePlayUrlResolution with _$LivePlayUrlResolution {
  /// A resolution result.
  const factory LivePlayUrlResolution({
    /// The quality the caller requested, when it named one.
    QualityLabel? requested,

    /// The quality the site actually served; null when the site does not say
    /// (the lines are then the only truth).
    QualityLabel? confirmed,

    /// The resolved lines, best first.
    @Default(<LivePlayLine>[]) List<LivePlayLine> lines,

    /// The site's own note about the answer, when it gives one (a login hint,
    /// a region notice). Shown as-is; never parsed.
    String? notice,
  }) = _LivePlayUrlResolution;

  /// A resolution of [lines] for the requested quality, with no confirmation.
  factory LivePlayUrlResolution.of(List<LivePlayLine> lines, {QualityLabel? requested}) =>
      LivePlayUrlResolution(requested: requested, lines: lines);
}

/// The resolution's derived facts.
extension LivePlayUrlResolutionX on LivePlayUrlResolution {
  /// Whether there is anything to play.
  bool get isPlayable => lines.isNotEmpty;

  /// Whether the site served a different quality than the one requested.
  ///
  /// The UI uses this to say "playing 超清 instead of 蓝光" rather than
  /// silently labelling the stream with a level it is not.
  bool get degraded {
    final asked = requested;
    final got = confirmed;
    return asked != null && got != null && !asked.sameAs(got);
  }
}
