import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:media_core/media_core.dart' show EngineOption;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MpvPlatformProfile;
import 'package:pure_live/app/preferences/app_preferences.dart';

/// The mpv tuning, ported from the reference's mpv option set and backed by
/// media_core's engine-option channel (`PlayerAdapter.applyEngineOptions` /
/// the adapter's `beforeOpen` hook).
///
/// Two delivery paths, matching what mpv itself allows:
/// - **native options** (vo/ao/hwdec/deinterlace/scale/interpolation/cache)
///   are written to the player before a source opens — mpv consumes the
///   output drivers at engine birth, so these take effect on the next
///   stream (or the current one's resume).
/// - **live options** are the subset mpv accepts on a running engine
///   (`hwdec`, `deinterlace`, `interpolation`, `scale`, `cache`,
///   `cache-secs`); a settings edit lands on the open room through
///   `adapter.applyEngineOptions` without a replay.
abstract final class MpvTuning {
  /// The stored answer meaning "let the engine/platform decide" for every
  /// picker on the tuning page.
  static const String auto = 'auto';

  /// The scale filters the reference offers on a desktop; `auto` keeps mpv's
  /// own default (bicubic-ish bilinear depending on the profile).
  static const List<String> scaleFilters = [
    auto,
    'bilinear',
    'bicubic',
    'lanczos',
    'lanczos3',
    'neighbor',
    'spline16',
    'spline36',
    'mitchell',
    'gaussian',
  ];

  /// The deinterlace answers, the reference's `no/auto/yes`.
  static const List<String> deinterlaceValues = [auto, 'no', 'yes'];

  /// The picker entries for the audio output driver.
  static Map<String, String> audioOutputs(TargetPlatform platform) =>
      MpvPlatformProfile.audioOutputDriversForPlatform(platform);

  /// The picker entries for the hardware decoder.
  static Map<String, String> hardwareDecoders(TargetPlatform platform) =>
      MpvPlatformProfile.hardwareDecodersForPlatform(platform);

  /// The raw mpv properties to write before each open.
  static Map<String, String> nativeOptions(
    AppPreferences preferences, {
    required TargetPlatform platform,
    required bool isDesktop,
  }) {
    final options = <String, String>{};
    // ao only when the user opted into custom output: the media_kit adapter's
    // own defaults are what an untouched app ran with before.
    //
    // `vo` is never written. media_kit feeds its Flutter surface from mpv's
    // `libmpv` video output, and any other output — including mpv's own
    // `auto` — leaves the embedded widget with no frames at all: a black
    // picture while the audio keeps running.
    if (preferences.customPlayerOutput) {
      final ao = MpvPlatformProfile.normalizeAudioOutputDriverForPlatform(preferences.audioOutputDriver, platform);
      if (ao.isNotEmpty) {
        options['ao'] = ao;
      }
    }
    options['hwdec'] = MpvPlatformProfile.normalizeHardwareDecoderForPlatform(preferences.hardwareDecoder, platform);
    if (preferences.deinterlace != auto) {
      options['deinterlace'] = preferences.deinterlace;
    }
    // The reference keeps interpolation and the scaler desktop-only — a
    // phone's GPU path does not take the frame-blend cost.
    if (isDesktop) {
      options['interpolation'] = preferences.frameInterpolation ? 'yes' : 'no';
      if (preferences.scaler != auto) {
        options['scale'] = preferences.scaler;
      }
    }
    if (preferences.streamCacheSeconds > 0) {
      options['cache'] = 'yes';
      options['cache-secs'] = '${preferences.streamCacheSeconds}';
    }
    // 播放器代理: the stream itself is pulled through http(s) proxies mpv
    // speaks — both spellings, because a live room hands out either scheme.
    if (preferences.playerProxyEnabled) {
      final proxy = 'http://${preferences.playerProxyHost}:${preferences.playerProxyPort}';
      options['proxy'] = proxy;
      options['https-proxy'] = proxy;
    }
    return options;
  }

  /// The options a running mpv takes without a replay.
  static List<EngineOption> liveOptions(AppPreferences preferences, {required bool isDesktop}) {
    final options = <EngineOption>[EngineOption('deinterlace', preferences.deinterlace)];
    if (isDesktop) {
      options.add(EngineOption('interpolation', preferences.frameInterpolation ? 'yes' : 'no'));
      if (preferences.scaler != auto) {
        options.add(EngineOption('scale', preferences.scaler));
      }
    }
    if (preferences.streamCacheSeconds > 0) {
      options
        ..add(const EngineOption('cache', 'yes'))
        ..add(EngineOption('cache-secs', '${preferences.streamCacheSeconds}'));
    }
    return options;
  }

  /// The tuning answers that change only at the next open — the comparison a
  /// settings edit uses to decide between a live apply and a note.
  static bool nextOpenOnlyChanged(AppPreferences previous, AppPreferences next) =>
      previous.customPlayerOutput != next.customPlayerOutput ||
      previous.audioOutputDriver != next.audioOutputDriver ||
      previous.hardwareDecoder != next.hardwareDecoder ||
      previous.playerProxyEnabled != next.playerProxyEnabled ||
      previous.playerProxyHost != next.playerProxyHost ||
      previous.playerProxyPort != next.playerProxyPort;
}
