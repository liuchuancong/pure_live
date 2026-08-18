/// Normalizes image links returned by the supported live platforms.
///
/// Several APIs still return protocol-relative CDN links (`//...`) while some
/// IPTV lists contain a host without a scheme. Flutter's network image loader
/// requires an absolute HTTP(S) URI.
String normalizeNetworkImageUrl(String? source) {
  var value = source?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'null') return '';

  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.isEmpty) return '';
  if (value.startsWith('//')) return 'https:$value';

  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) return value;
  if (!value.contains(' ') && RegExp(r'^[\w.-]+\.[a-zA-Z]{2,}([/:?#]|$)').hasMatch(value)) {
    return 'https://$value';
  }
  return '';
}
