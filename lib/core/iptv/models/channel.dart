import 'package:equatable/equatable.dart';

/// A channel from an IPTV playlist (M3U/M3U+ or Xtream Codes).
class Channel extends Equatable {
  final String id;
  final String providerId;
  final String name;
  final String? tvgId;
  final String? tvgName;
  final String? tvgLogo;
  final String? groupTitle;
  final String? epgChannelId;
  final int? channelNumber;
  final String streamUrl;
  final StreamType streamType;
  final bool isFavorite;

  const Channel({
    required this.id,
    required this.providerId,
    required this.name,
    this.tvgId,
    this.tvgName,
    this.tvgLogo,
    this.groupTitle,
    this.epgChannelId,
    this.channelNumber,
    required this.streamUrl,
    this.streamType = StreamType.live,
    this.isFavorite = false,
  });

  /// The best display name available.
  String get displayName => tvgName ?? name;

  Channel copyWith({
    String? epgChannelId,
    bool? isFavorite,
    int? channelNumber,
  }) {
    return Channel(
      id: id,
      providerId: providerId,
      name: name,
      tvgId: tvgId,
      tvgName: tvgName,
      tvgLogo: tvgLogo,
      groupTitle: groupTitle,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      channelNumber: channelNumber ?? this.channelNumber,
      streamUrl: streamUrl,
      streamType: streamType,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [id, providerId];
}

enum StreamType { live, vod, series }

/// An IPTV service provider configuration.
class Provider extends Equatable {
  final String id;
  final String name;
  final ProviderType type;
  final String url;
  final String? username;
  final String? password;
  final bool enabled;
  final DateTime? lastRefresh;
  final int channelCount;
  final ProviderStatus status;

  const Provider({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.username,
    this.password,
    this.enabled = true,
    this.lastRefresh,
    this.channelCount = 0,
    this.status = ProviderStatus.unknown,
  });

  @override
  List<Object?> get props => [id];
}

enum ProviderType { m3u, m3uPlus, xtreamCodes }
enum ProviderStatus { unknown, online, offline, error }

/// A unified channel that aggregates streams from multiple providers.
/// Used for cross-provider failover.
class UnifiedChannel extends Equatable {
  final String id;
  final String displayName;
  final String? epgChannelId;
  final String? logoUrl;
  final int? channelNumber;
  final List<StreamSource> sources;

  const UnifiedChannel({
    required this.id,
    required this.displayName,
    this.epgChannelId,
    this.logoUrl,
    this.channelNumber,
    this.sources = const [],
  });

  /// Whether this channel has backup streams for failover.
  bool get hasFailoverSources => sources.length > 1;

  /// The primary (highest priority) stream source.
  StreamSource? get primarySource =>
      sources.isNotEmpty ? sources.first : null;

  @override
  List<Object?> get props => [id];
}

/// A specific stream URL from a specific provider.
class StreamSource extends Equatable {
  final String providerId;
  final String providerChannelId;
  final String streamUrl;
  final int priority;
  final StreamHealth lastKnownHealth;
  final DateTime? lastProbeTime;

  const StreamSource({
    required this.providerId,
    required this.providerChannelId,
    required this.streamUrl,
    this.priority = 0,
    this.lastKnownHealth = StreamHealth.unknown,
    this.lastProbeTime,
  });

  @override
  List<Object?> get props => [providerId, providerChannelId];
}

enum StreamHealth { unknown, healthy, degraded, down }
