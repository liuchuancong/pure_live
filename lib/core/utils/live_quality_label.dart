/// Converts platform SDK quality codes into stable user-facing Chinese labels
/// without changing the opaque identifier used to request that stream.
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
    return idText.isEmpty ? '默认' : '清晰度 $idText';
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
      return '${match.group(1)}P$fps${source ? '（原画）' : ''}';
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
