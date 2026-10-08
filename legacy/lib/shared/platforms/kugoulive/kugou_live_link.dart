abstract final class KugouLiveLink {
  static final RegExp _roomId = RegExp(r'^[1-9]\d{2,10}$');
  static const Set<String> _hosts = {'fanxing.kugou.com', 'mfanxing.kugou.com'};

  static String watchUrl(String raw) => 'https://fanxing.kugou.com/${requireRoomId(raw)}';

  static String requireRoomId(String raw) {
    final value = parseRoomId(raw);
    if (value == null) throw const FormatException('Invalid Kugou Live room identity');
    return value;
  }

  static String? parseRoomId(String raw) {
    final value = raw.trim();
    if (_roomId.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        !_hosts.contains(uri.host.toLowerCase()) ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    if (segments.length == 1 && _roomId.hasMatch(segments.single)) return segments.single;
    final queryId = uri.queryParameters['roomId']?.trim();
    return segments.isEmpty && queryId != null && _roomId.hasMatch(queryId) ? queryId : null;
  }
}
