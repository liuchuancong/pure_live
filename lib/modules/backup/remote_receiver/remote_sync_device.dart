class RemoteSyncDevice {
  final String id;
  final String name;
  final String platform;
  final String version;
  final String ip;
  final int port;
  final DateTime lastSeen;

  const RemoteSyncDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.version,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });

  factory RemoteSyncDevice.fromJson(Map<String, dynamic> json) {
    return RemoteSyncDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'PureLive',
      platform: json['platform']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 39888,
      lastSeen: DateTime.now(),
    );
  }

  RemoteSyncDevice copyWith({
    String? id,
    String? name,
    String? platform,
    String? version,
    String? ip,
    int? port,
    DateTime? lastSeen,
  }) {
    return RemoteSyncDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      version: version ?? this.version,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  String get address => '$ip:$port';
}
