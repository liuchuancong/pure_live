import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/locale_helper.dart';

/// Localized active-stream evidence, never used as a request/cursor identity.
extension PlayQualityLabel on LivePlayQuality {
  String get playbackLabel => isPlaybackUnconfirmed
      ? i18nOr('quality_playback_unconfirmed', 'Unconfirmed · $quality', args: {'quality': quality})
      : quality;
}
