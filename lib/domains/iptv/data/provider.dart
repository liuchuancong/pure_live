import 'package:equatable/equatable.dart';

class Provider extends Equatable {
  /// Unique provider id
  final String id;

  /// Display name
  final String name;

  /// Provider type
  final ProviderType type;

  /// Playlist source
  /// Examples:
  /// - /storage/emulated/0/iptv/test.m3u
  /// - /data/user/0/app/cache/hot.m3u
  /// - https://example.com/live.m3u
  /// - xtream api endpoint
  final String source;

  /// Whether this provider is builtin
  /// Examples:
  /// - 热门
  final bool builtin;

  /// Whether provider is enabled
  final bool enabled;

  /// Optional EPG url
  final String? epgUrl;

  /// Optional provider logo
  final String? logo;

  /// Last update time
  final DateTime? lastUpdated;

  /// Last successful sync
  final DateTime? lastSynced;

  /// User-Agent override
  final String? userAgent;

  /// Extra headers
  final Map<String, String>? headers;

  /// Total channels after parsing
  final int? channelCount;

  const Provider({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    this.builtin = false,
    this.enabled = true,
    this.epgUrl,
    this.logo,
    this.lastUpdated,
    this.lastSynced,
    this.userAgent,
    this.headers,
    this.channelCount,
  });

  bool get isRemote => source.startsWith('http://') || source.startsWith('https://');

  bool get isLocal => !isRemote;

  bool get hasEpg => epgUrl != null && epgUrl!.isNotEmpty;

  Provider copyWith({
    String? id,
    String? name,
    ProviderType? type,
    String? source,
    bool? builtin,
    bool? enabled,
    String? epgUrl,
    String? logo,
    DateTime? lastUpdated,
    DateTime? lastSynced,
    String? userAgent,
    Map<String, String>? headers,
    int? channelCount,
  }) {
    return Provider(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      source: source ?? this.source,
      builtin: builtin ?? this.builtin,
      enabled: enabled ?? this.enabled,
      epgUrl: epgUrl ?? this.epgUrl,
      logo: logo ?? this.logo,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastSynced: lastSynced ?? this.lastSynced,
      userAgent: userAgent ?? this.userAgent,
      headers: headers ?? this.headers,
      channelCount: channelCount ?? this.channelCount,
    );
  }

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json['id'],
      name: json['name'],
      type: ProviderType.values.firstWhere((e) => e.name == json['type']),
      source: json['source'],
      builtin: json['builtin'] ?? false,
      enabled: json['enabled'] ?? true,
      epgUrl: json['epgUrl'],
      logo: json['logo'],
      lastUpdated: json['lastUpdated'] != null ? DateTime.tryParse(json['lastUpdated']) : null,
      lastSynced: json['lastSynced'] != null ? DateTime.tryParse(json['lastSynced']) : null,
      userAgent: json['userAgent'],
      headers: json['headers'] != null ? Map<String, String>.from(json['headers']) : null,
      channelCount: json['channelCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'source': source,
      'builtin': builtin,
      'enabled': enabled,
      'epgUrl': epgUrl,
      'logo': logo,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'lastSynced': lastSynced?.toIso8601String(),
      'userAgent': userAgent,
      'headers': headers,
      'channelCount': channelCount,
    };
  }

  @override
  List<Object?> get props => [id];
}

enum ProviderType { txt, m3u, xtream, localFile, remoteUrl }
