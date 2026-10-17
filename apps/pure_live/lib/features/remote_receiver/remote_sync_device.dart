import 'package:pure_live/features/remote_receiver/remote_sync_protocol.dart';

// The factory keeps the class name (`RemoteSyncDevice.fromJson`), which the
// shorthand cannot spell.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One sync-capable device seen on the LAN, ported from the 3.x
/// `remote_sync_device.dart`.
final class RemoteSyncDevice {
  /// A discovered device.
  const new({
    required this.id,
    required this.name,
    required this.platform,
    required this.version,
    required this.ip,
    required this.port,
    required this.lastSeen,
    required this.bonsoirName,
  });

  /// Restores a device from a discovery packet (or a stored record).
  factory RemoteSyncDevice.fromJson(Map<String, dynamic> json) {
    return RemoteSyncDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'PureLive',
      platform: json['platform']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? RemoteSyncProtocol.defaultHttpPort,
      lastSeen: DateTime.now(),
      bonsoirName: json['bonsoirName']?.toString(),
    );
  }

  /// The device's stable sync identity.
  final String id;

  /// The device's display name.
  final String name;

  /// The operating system the device runs.
  final String platform;

  /// The app version the device advertises.
  final String version;

  /// The LAN address the device's sync server answers on.
  final String ip;

  /// The port the device's sync server answers on.
  final int port;

  /// When the device was last announced; stale entries are dropped.
  final DateTime lastSeen;

  /// The mDNS service name the device was announced under, when discovery
  /// ran over mDNS (the 3.x shape); UDP discovery leaves it null.
  final String? bonsoirName;

  /// A copy with the given fields replaced.
  RemoteSyncDevice copyWith({
    String? id,
    String? name,
    String? platform,
    String? version,
    String? ip,
    int? port,
    DateTime? lastSeen,
    String? bonsoirName,
  }) {
    return RemoteSyncDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      version: version ?? this.version,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      bonsoirName: bonsoirName ?? this.bonsoirName,
    );
  }

  /// The `ip:port` endpoint string.
  String get address => '$ip:$port';
}
