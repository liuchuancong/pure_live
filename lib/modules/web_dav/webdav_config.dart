class WebDAVConfig {
  final String name;
  final String address;
  final String username;
  final String password;

  const WebDAVConfig({
    required this.name,
    required this.address,
    required this.username,
    required this.password,
  });

  String get fullUrl => address;

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
