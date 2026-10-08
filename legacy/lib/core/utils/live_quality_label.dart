import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/core/models/live_play_quality.dart';

/// Converts platform SDK quality codes into stable labels without changing the
/// opaque identifier used to request that stream. The wording a user sees comes
/// from [qualityDisplayName], which maps these labels onto the locale bundles.
class LiveQualityLabel {
  const LiveQualityLabel._();

  static String normalize({
    required String platform,
    required String rawLabel,
    Object? id,
    int? bitrate,
    String? resolution,
  }) {
    final raw = rawLabel.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (_containsCjk(raw)) return raw;

    final token = _token(raw.isNotEmpty ? raw : id?.toString() ?? '');
    final platformToken = platform.trim().toLowerCase();
    final mapped = switch (platformToken) {
      'bilibili' => _bilibili(token, id),
      'douyin' => _douyin(token),
      'douyu' || 'huya' || 'kuaishou' || 'cc' || 'yy' => _generic(token),
      'soop' => _soop(token),
      'twitch' => _twitch(raw, token),
      'iptv' => token == 'default' ? '默认' : null,
      _ => _generic(token),
    };
    if (mapped != null) return mapped;

    final resolutionLabel = _resolutionLabel(resolution);
    if (resolutionLabel != null) return resolutionLabel;
    if (raw.isNotEmpty) return raw;
    if (bitrate != null && bitrate > 0) return _bitrateLabel(bitrate);
    final idText = id?.toString().trim() ?? '';
    return idText.isEmpty ? '默认' : '$liveQualityIdPrefix$idText';
  }

  static String? _bilibili(String token, Object? id) {
    final qn = int.tryParse(id?.toString() ?? token);
    return switch (qn) {
      30000 => '杜比',
      20000 => '4K',
      10000 => '原画',
      400 => '蓝光',
      250 => '超清',
      150 => '高清',
      80 => '流畅',
      _ => _generic(token),
    };
  }

  static String? _douyin(String token) => switch (token) {
    'origin' || 'origion' || 'original' || 'source' => '原画',
    'fullhd' || 'fullhd1' || 'uhd' || 'uhd1' || 'blue' || 'bluray' || 'blueray' => '蓝光',
    'fhd' || 'hd' || 'hd1' => '超清',
    'sd' || 'sd2' => '高清',
    'ld' || 'sd1' => '标清',
    'md' => '流畅',
    'auto' => '自动',
    _ => _generic(token),
  };

  static String? _soop(String token) => switch (token) {
    'original' || 'origin' || 'source' => '原画',
    'master' || 'uhd' => '蓝光',
    'fullhd' || 'fhd' => '超清',
    'hd' => '高清',
    'sd' || 'normal' => '标清',
    'low' || 'ld' => '流畅',
    'auto' => '自动',
    _ => _generic(token),
  };

  static String? _generic(String token) => switch (token) {
    'original' || 'origin' || 'origion' || 'source' => '原画',
    'blue' || 'bluray' || 'blueray' => '蓝光',
    'uhd' || 'super' || 'superhd' || 'fullhd' || 'fhd' => '超清',
    'hd' || 'high' => '高清',
    'sd' || 'standard' || 'medium' => '标清',
    'low' || 'ld' || 'smooth' || 'fluent' => '流畅',
    'auto' => '自动',
    'default' => '默认',
    _ => null,
  };

  static String? _twitch(String raw, String token) {
    final source = token.contains('source');
    final match = RegExp(r'(\d{3,4})p(?:\s*(\d{2,3}))?', caseSensitive: false).firstMatch(raw);
    if (match != null) {
      final fps = match.group(2) ?? '';
      return '${match.group(1)}P$fps${source ? liveQualitySourceSuffix : ''}';
    }
    return source ? '原画' : _generic(token);
  }

  static String _token(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static bool _containsCjk(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);

  static String? _resolutionLabel(String? value) {
    final match = RegExp(r'(\d{3,5})\s*[x×]\s*(\d{3,5})', caseSensitive: false).firstMatch(value ?? '');
    if (match == null) return null;
    final width = int.tryParse(match.group(1) ?? '') ?? 0;
    final height = int.tryParse(match.group(2) ?? '') ?? 0;
    final shortSide = width < height ? width : height;
    if (shortSide >= 2160) return '4K';
    if (shortSide >= 1440) return '2K 超清';
    if (shortSide >= 1080) return '1080P 高清';
    if (shortSide >= 720) return '720P 清晰';
    if (shortSide >= 480) return '480P 流畅';
    if (shortSide >= 360) return '360P 极速';
    return '${shortSide}P';
  }

  static String _bitrateLabel(int bitsPerSecond) {
    if (bitsPerSecond >= 1000000) {
      final mbps = bitsPerSecond / 1000000;
      return '${mbps.toStringAsFixed(mbps == mbps.roundToDouble() ? 0 : 1)} Mbps';
    }
    return '${(bitsPerSecond / 1000).round()} Kbps';
  }
}

/// The twitch source marker [LiveQualityLabel.normalize] appends to a measured
/// resolution, kept as one constant because the display layer replaces it.
const String liveQualitySourceSuffix = '（原画）';

/// Locale rows for the two generated labels; named so the bundle test can
/// require them without duplicating the strings.
const String liveQualityIdKey = 'live_quality_id';
const String liveQualitySourceSuffixKey = 'live_quality_source_suffix';
const String liveQualityIdPrefix = '清晰度 ';

/// The fixed vocabulary the normalizer answers with, mapped to its locale row.
///
/// The internal label stays as it is on purpose: `LivePlayQuality.selectionId`
/// falls back to it when a platform gives no explicit id, and the recorder's
/// stored preference and its saved task records compare against it. A label
/// that changed with the interface language would therefore break quality
/// matching and history written under another locale, so only this display
/// mapping is localized - the same split `PlayerConsts.resolutionLabelKeys`
/// uses for the stored 原画/蓝光4M values. Exposed because the test that keeps
/// the locale rows in step with the normalizer needs to enumerate it.
const Map<String, String> liveQualityDisplayKeys = <String, String>{
  '原画': 'live_quality_original',
  '蓝光': 'live_quality_blu_ray',
  '超清': 'live_quality_super_hd',
  '高清': 'live_quality_hd',
  '标清': 'live_quality_sd',
  '流畅': 'live_quality_smooth',
  '自动': 'live_quality_auto',
  '默认': 'live_quality_default',
  '杜比': 'live_quality_dolby',
  '2K 超清': 'live_quality_2k',
  '1080P 高清': 'live_quality_1080p',
  '720P 清晰': 'live_quality_720p',
  '480P 流畅': 'live_quality_480p',
  '360P 极速': 'live_quality_360p',
};

/// [label] as the current locale spells it; anything the normalizer did not
/// produce (a bitrate, a raw site name) is already display text and passes
/// through untouched.
String qualityDisplayName(String label) {
  final key = liveQualityDisplayKeys[label];
  if (key != null) return i18nOr(key, label);
  final idText = label.startsWith(liveQualityIdPrefix) ? label.substring(liveQualityIdPrefix.length) : null;
  if (idText != null) {
    return i18nOr(liveQualityIdKey, label, args: <String, String>{'id': idText});
  }
  if (label.contains(liveQualitySourceSuffix)) {
    return label.replaceAll(liveQualitySourceSuffix, i18nOr(liveQualitySourceSuffixKey, liveQualitySourceSuffix));
  }
  return label;
}

extension PlayQualityLabel on LivePlayQuality {
  String get playbackLabel => isPlaybackUnconfirmed
      ? i18nOr('quality_playback_unconfirmed', 'Unconfirmed · $quality', args: {'quality': qualityDisplayName(quality)})
      : qualityDisplayName(quality);
}
