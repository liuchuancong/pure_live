class WebDAVConfig {
  final String name;
  final String address;
  final String username;
  final String password;

  const WebDAVConfig({required this.name, required this.address, required this.username, required this.password});

  String get fullUrl => address;

  /// Validate a directory base URL without making a connection or changing the
  /// persisted representation. The client appends child paths to this string,
  /// so query/fragment bases do not describe the requested child directory.
  static bool isValidAddress(String address) {
    final value = address.trim();
    if (value.isEmpty || RegExp(r'[\x00-\x1f\x7f\\]').hasMatch(value)) return false;
    // Uri normalizes an empty user-info marker away; inspect it before parsing.
    if (RegExp(r'^https?://[^/?#]*@', caseSensitive: false).hasMatch(value)) return false;
    try {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.authority.contains('@') ||
          uri.hasQuery ||
          uri.hasFragment) {
        return false;
      }
      final host = Uri.decodeComponent(uri.host);
      return !RegExp(r'[\s/\\?#@]').hasMatch(host) && uri.port > 0 && uri.port <= 65535;
    } on FormatException {
      return false;
    }
  }

  factory WebDAVConfig.fromJson(Map<String, dynamic> json) {
    return WebDAVConfig(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'address': address, 'username': username, 'password': password};
  }
}
