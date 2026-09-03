/// Normalizes image links returned by the supported live platforms.
///
/// Several APIs still return protocol-relative CDN links (`//...`) while some
/// IPTV lists contain a host without a scheme. Flutter's network image loader
/// requires an absolute HTTP(S) URI.
String normalizeNetworkImageUrl(String? source) {
  var value = source?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'null') return '';

  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.isEmpty) return '';
  if (value.startsWith('//')) return 'https:$value';

  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
    return value;
  }
  if (!value.contains(' ') && RegExp(r'^[\w.-]+\.[a-zA-Z]{2,}([/:?#]|$)').hasMatch(value)) {
    return 'https://$value';
  }
  return '';
}

/// Headers required by image CDNs that validate the request origin.
///
/// Keep this host-scoped: forwarding a platform referer to unrelated image
/// hosts would be both unnecessary and harmful to cache sharing.
Map<String, String>? networkImageHeaders(String source) {
  final uri = Uri.tryParse(source);
  final host = uri?.host.toLowerCase() ?? '';
  if (host == 'hdslb.com' || host.endsWith('.hdslb.com')) {
    return const {
      'Referer': 'https://live.bilibili.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    };
  }
  return {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
  };
}
