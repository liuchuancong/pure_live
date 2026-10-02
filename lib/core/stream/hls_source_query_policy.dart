/// Explicit query-token propagation for one selected HLS source.
///
/// Normal URI resolution does not inherit a manifest's query. Some providers
/// (the observed TTing/FLEX NCP player) explicitly add its token to child
/// requests. Opt in only after verifying that provider contract; this is not a
/// global HLS rule, an authentication refresh mechanism or a URL allow-list.
class HlsSourceQueryPolicy {
  HlsSourceQueryPolicy._(this._source, this._directory, this._tokenPair);

  /// Copies only the single `token` parameter, preserving its wire encoding.
  /// HTTP is supported for explicit local fixtures; platform adapters remain
  /// responsible for validating their production HTTPS source contracts.
  factory HlsSourceQueryPolicy.fromSource(Uri source) {
    try {
      return _fromSource(source);
    } on FormatException {
      // URI decoders may include their input in errors. Never expose a source
      // signature through a policy-construction diagnostic.
      throw const FormatException('Invalid or ambiguous HLS token source');
    }
  }

  static HlsSourceQueryPolicy _fromSource(Uri source) {
    if (!_eligible(source) || source.hasFragment || source.toString().length > 16384) {
      throw const FormatException('Invalid HLS token source');
    }
    final parts = source.pathSegments;
    if (parts.isEmpty || parts.last.isEmpty) throw const FormatException('Missing HLS source path');
    final tokens = source.queryParametersAll['token'];
    if (tokens == null || tokens.length != 1 || tokens.single.isEmpty || _control.hasMatch(tokens.single)) {
      throw const FormatException('Expected one nonempty HLS source token');
    }
    final tokenPair = source.query
        .split('&')
        .singleWhere((pair) => Uri.decodeQueryComponent(pair.split('=').first) == 'token');
    return HlsSourceQueryPolicy._(source, List.unmodifiable(parts.take(parts.length - 1)), tokenPair);
  }

  static final RegExp _control = RegExp(r'[\x00-\x20\x7f]');
  final Uri _source;
  final List<String> _directory;
  final String _tokenPair;

  /// Prevents a policy created for an old selection from being used for a new
  /// source, including another quality/path or a freshly signed root URL.
  bool matchesSource(Uri source) => source == _source;

  Uri apply(Uri target) {
    try {
      return _apply(target);
    } on FormatException {
      // Malformed target encoding grants no token propagation capability.
      return target;
    }
  }

  Uri _apply(Uri target) {
    if (!_eligible(target) ||
        target.scheme != _source.scheme ||
        target.host != _source.host ||
        target.port != _source.port) {
      return target;
    }
    final parts = target.pathSegments;
    if (parts.length <= _directory.length) return target;
    for (var i = 0; i < _directory.length; i++) {
      if (parts[i] != _directory[i]) return target;
    }
    // An explicit child token, even empty or repeated, belongs to that URL.
    // Never overwrite it or rebuild other signed/duplicate query parameters.
    if (target.queryParametersAll.containsKey('token')) return target;
    final query = target.query.isEmpty ? _tokenPair : '${target.query}&$_tokenPair';
    return target.replace(query: query);
  }

  static bool _eligible(Uri uri) {
    if (!const {'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    // Reject ambiguous decoded paths rather than guessing a CDN's handling of
    // encoded traversal, separators or controls. Standard relative paths are
    // resolved by the caller before this policy is applied.
    return uri.pathSegments.every(
      (part) => part != '.' && part != '..' && !part.contains('/') && !part.contains('\\') && !_control.hasMatch(part),
    );
  }
}
