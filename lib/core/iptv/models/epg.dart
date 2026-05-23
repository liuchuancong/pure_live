import 'package:equatable/equatable.dart';

/// A channel from an EPG source (e.g. epg.best XMLTV feed).
class EpgChannel extends Equatable {
  final String id;
  final String sourceId;
  final List<String> displayNames;
  final String? iconUrl;
  final String? number;

  const EpgChannel({required this.id, required this.sourceId, this.displayNames = const [], this.iconUrl, this.number});

  String get primaryName => displayNames.isNotEmpty ? displayNames.first : id;

  @override
  List<Object?> get props => [id, sourceId];
}

/// A programme entry from an EPG source.
class EpgProgramme extends Equatable {
  final String channelId;
  final String sourceId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? subtitle;
  final String? description;
  final String? category;
  final String? iconUrl;
  final String? episodeNum;
  final String? rating;
  final bool isNew;

  const EpgProgramme({
    required this.channelId,
    required this.sourceId,
    required this.start,
    required this.stop,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
    this.iconUrl,
    this.episodeNum,
    this.rating,
    this.isNew = false,
  });

  bool get isCurrentlyAiring {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(stop);
  }

  Duration get duration => stop.difference(start);

  @override
  List<Object?> get props => [channelId, sourceId, start, stop, title];
}

/// An EPG data source configuration.
class EpgSource extends Equatable {
  final String id;
  final String name;
  final String url;
  final EpgSourceType type;
  final DateTime? lastRefresh;
  final Duration refreshInterval;
  final bool enabled;
  final int channelCount;

  const EpgSource({
    required this.id,
    required this.name,
    required this.url,
    this.type = EpgSourceType.xmltv,
    this.lastRefresh,
    this.refreshInterval = const Duration(hours: 12),
    this.enabled = true,
    this.channelCount = 0,
  });

  bool get isStale {
    if (lastRefresh == null) return true;
    return DateTime.now().difference(lastRefresh!) > refreshInterval;
  }

  @override
  List<Object?> get props => [id];
}

enum EpgSourceType { xmltv, xtream }

/// A mapping between a provider's channel and an EPG channel.
class EpgMapping extends Equatable {
  final String playlistChannelId;
  final String providerId;
  final String? epgChannelId;
  final String? epgSourceId;
  final double confidence;
  final MappingSource source;
  final bool locked;
  final DateTime? updatedAt;

  const EpgMapping({
    required this.playlistChannelId,
    required this.providerId,
    this.epgChannelId,
    this.epgSourceId,
    this.confidence = 0,
    this.source = MappingSource.auto,
    this.locked = false,
    this.updatedAt,
  });

  bool get isMapped => epgChannelId != null && epgChannelId!.isNotEmpty;

  MappingStatus get status {
    if (!isMapped) return MappingStatus.unmapped;
    if (source == MappingSource.suggested) return MappingStatus.suggested;
    return MappingStatus.mapped;
  }

  EpgMapping copyWith({
    String? epgChannelId,
    String? epgSourceId,
    double? confidence,
    MappingSource? source,
    bool? locked,
    DateTime? updatedAt,
  }) {
    return EpgMapping(
      playlistChannelId: playlistChannelId,
      providerId: providerId,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      epgSourceId: epgSourceId ?? this.epgSourceId,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      locked: locked ?? this.locked,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [playlistChannelId, providerId];
}

enum MappingSource { auto, manual, suggested, imported }

enum MappingStatus { mapped, suggested, unmapped }

/// Result of an auto-mapping attempt for a single channel.
class MappingCandidate {
  final String epgChannelId;
  final String epgSourceId;
  final String epgDisplayName;
  final double confidence;
  final List<String> matchReasons;

  const MappingCandidate({
    required this.epgChannelId,
    required this.epgSourceId,
    required this.epgDisplayName,
    required this.confidence,
    this.matchReasons = const [],
  });
}

/// Stats from an auto-mapping run.
class MappingStats {
  final int totalChannels;
  final int mapped;
  final int suggested;
  final int unmapped;
  final Duration elapsed;

  const MappingStats({
    required this.totalChannels,
    required this.mapped,
    required this.suggested,
    required this.unmapped,
    required this.elapsed,
  });

  double get mappedPercent => totalChannels > 0 ? mapped / totalChannels * 100 : 0;
  double get suggestedPercent => totalChannels > 0 ? suggested / totalChannels * 100 : 0;
  double get unmappedPercent => totalChannels > 0 ? unmapped / totalChannels * 100 : 0;
}
