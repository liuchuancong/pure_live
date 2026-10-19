import 'package:flutter/foundation.dart' show immutable;

/// The runtime credentials of one WebDAV server: the stored `WebDavServer`
/// entry with the vault's password merged in — what `WebDavService` speaks
/// through. The password never sits in the settings document (the v1 shape
/// did; the store migrates it out).
@immutable
final class WebDavConfig {
  /// A WebDAV configuration.
  const new({
    required this.address,
    required this.username,
    required this.password,
    this.name = '',
    this.directory = '',
  });

  /// Reads a configuration from JSON. A stored address that is not a usable
  /// URL is kept as it is — the form asks for a fix, and nothing requests
  /// with a config before [isComplete] says it may.
  factory fromJson(Map<String, Object?> json) => WebDavConfig(
    name: json['name']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    password: json['password']?.toString() ?? '',
    directory: json['directory']?.toString() ?? '',
  );

  /// The label of the server this belongs to (the vault key of [password]).
  final String name;

  /// The server's base URL, e.g. `https://dav.jianguoyun.com/dav/`.
  final String address;

  /// The account name the server authenticates.
  final String username;

  /// The password (for Jianguoyun, an app password) sent as Basic auth.
  final String password;

  /// A sub-directory the backups are stored in, relative to the address;
  /// empty means the address' own root.
  final String directory;

  /// Whether every field this config needs to connect is present.
  bool get isComplete =>
      address.trim().isNotEmpty && username.trim().isNotEmpty && password.isNotEmpty && isValidAddress(address);

  /// Writes this configuration to JSON.
  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'username': username,
    'password': password,
    'directory': directory,
  };

  /// Returns a copy with the given fields replaced.
  WebDavConfig copyWith({String? name, String? address, String? username, String? password, String? directory}) => WebDavConfig(
    name: name ?? this.name,
    address: address ?? this.address,
    username: username ?? this.username,
    password: password ?? this.password,
    directory: directory ?? this.directory,
  );

  /// Validates a directory base URL without making a connection or changing
  /// the persisted representation. The client appends child paths to this
  /// string, so query/fragment bases do not describe the requested child
  /// directory.
  static bool isValidAddress(String address) {
    final value = address.trim();
    if (value.isEmpty || RegExp(r'[\x00-\x1f\x7f\\]').hasMatch(value)) {
      return false;
    }
    // Uri normalizes an empty user-info marker away; inspect it before
    // parsing.
    if (RegExp('^https?://[^/?#]*@', caseSensitive: false).hasMatch(value)) {
      return false;
    }
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

  @override
  bool operator ==(Object other) =>
      other is WebDavConfig &&
      other.name == name &&
      other.address == address &&
      other.username == username &&
      other.password == password &&
      other.directory == directory;

  @override
  int get hashCode => Object.hash(name, address, username, password, directory);
}
