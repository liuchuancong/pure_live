import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller.dart';

/// Resolves the route-scoped video controller for a partial player-state update.
///
/// Most updates only change quality, line or audio presentation and must retain
/// the active controller. Clearing it is deliberately explicit so a nullable
/// optional argument can never turn an unrelated update into a loading screen.
T? resolveVideoControllerUpdate<T>({required T? current, T? next, bool clear = false}) {
  if (clear) return null;
  return next ?? current;
}

@immutable
class PlayerState {
  static const Object _notProvided = Object();
  final VideoController? videoController;
  final List<LivePlayQuality> qualites;
  final int currentQuality;
  final List<String> playUrls;
  final OwnedPlaybackSource? ownedSource;
  int get lineCount => ownedSource == null ? playUrls.length : 1;
  bool get hasPlaybackSource => lineCount > 0;
  final Map<String, HlsSourceQueryPolicy> sourceQueryPolicies;
  final int currentLineIndex;
  final bool isCurrentRoomAudioOnly;
  final bool hasUseDefaultResolution;

  const PlayerState({
    this.videoController,
    this.qualites = const [],
    this.currentQuality = 0,
    this.playUrls = const [],
    this.ownedSource,
    this.sourceQueryPolicies = const {},
    this.currentLineIndex = 0,
    this.isCurrentRoomAudioOnly = false,
    this.hasUseDefaultResolution = false,
  });

  LivePlayQuality get qualitySafe {
    if (qualites.isEmpty) {
      return LivePlayQuality(quality: '原画');
    }
    final i = currentQuality;
    if (i < 0 || i >= qualites.length) return qualites.first;
    return qualites[i];
  }

  String get playUrlSafe {
    if (ownedSource != null || playUrls.isEmpty) return '';
    final i = currentLineIndex;
    if (i < 0 || i >= playUrls.length) return playUrls.first;
    return playUrls[i];
  }

  PlayerState copyWith({
    Object? videoController = _notProvided,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    OwnedPlaybackSource? ownedSource,
    bool clearOwnedSource = false,
    Map<String, HlsSourceQueryPolicy>? sourceQueryPolicies,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  }) {
    return PlayerState(
      videoController: identical(videoController, _notProvided)
          ? this.videoController
          : videoController as VideoController?,
      qualites: qualites ?? this.qualites,
      currentQuality: currentQuality ?? this.currentQuality,
      playUrls: playUrls ?? this.playUrls,
      ownedSource: clearOwnedSource ? null : ownedSource ?? (playUrls == null ? this.ownedSource : null),
      // Replacing URLs without an explicit capability is a legacy/direct
      // source. Never carry a previous resolver's policy into that cohort.
      sourceQueryPolicies: Map<String, HlsSourceQueryPolicy>.unmodifiable(
        sourceQueryPolicies ?? (playUrls == null ? this.sourceQueryPolicies : const {}),
      ),
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      isCurrentRoomAudioOnly: isCurrentRoomAudioOnly ?? this.isCurrentRoomAudioOnly,
      hasUseDefaultResolution: hasUseDefaultResolution ?? this.hasUseDefaultResolution,
    );
  }

  @override
  String toString() {
    return 'PlayerState(\n'
        '  videoController: ${videoController != null ? "exists" : "null"},\n'
        '  qualites: ${qualites.length} items,\n'
        '  currentQuality: $currentQuality,\n'
        '  playUrls: ${playUrls.length} items,\n'
        '  currentLineIndex: $currentLineIndex,\n'
        '  isCurrentRoomAudioOnly: $isCurrentRoomAudioOnly,\n'
        '  hasUseDefaultResolution: $hasUseDefaultResolution,\n'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerState &&
        other.videoController == videoController &&
        listEquals(other.qualites, qualites) &&
        other.currentQuality == currentQuality &&
        listEquals(other.playUrls, playUrls) &&
        other.ownedSource == ownedSource &&
        mapEquals(other.sourceQueryPolicies, sourceQueryPolicies) &&
        other.currentLineIndex == currentLineIndex &&
        other.isCurrentRoomAudioOnly == isCurrentRoomAudioOnly &&
        other.hasUseDefaultResolution == hasUseDefaultResolution;
  }

  @override
  int get hashCode => Object.hash(
    videoController,
    Object.hashAll(qualites),
    currentQuality,
    Object.hashAll(playUrls),
    ownedSource,
    Object.hashAllUnordered(sourceQueryPolicies.entries.map((entry) => Object.hash(entry.key, entry.value))),
    currentLineIndex,
    isCurrentRoomAudioOnly,
    hasUseDefaultResolution,
  );
}

/// 一次房间数据重载的原因。
enum ReloadDataType { refresh, changeLine, changeQuality }
