abstract final class Fc2Link {
  static final RegExp _channelId = RegExp(r'^[1-9]\d{0,11}$');
  static const Set<String> _locales = {'en', 'es', 'de', 'fr', 'id', 'ja', 'ko', 'pt', 'ru', 'th', 'tw', 'vi', 'zh'};

  static String channelUrl(String raw) => 'https://live.fc2.com/${requireChannelId(raw)}/';

  static String requireChannelId(String raw) {
    final result = parseChannelId(raw);
    if (result == null) throw const FormatException('Invalid FC2 Live channel identity');
    return result;
  }

  static String? parseChannelId(String raw) {
    final input = raw.trim();
    if (_valid(input)) return input;
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'live.fc2.com' ||
        uri.hasFragment) {
      return null;
    }
    late final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    if (segments.length == 1 && _valid(segments.single)) return segments.single;
    if (segments.length == 2 && _locales.contains(segments.first.toLowerCase()) && _valid(segments.last)) {
      return segments.last;
    }
    return null;
  }

  static bool _valid(String value) => _channelId.hasMatch(value);
}
