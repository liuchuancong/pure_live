import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/domains/live/data/stream/flv_splice_relay.dart';

enum MultiviewLayout {
  single,

  dual,

  quad,

  focus;

  int get capacity => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad || MultiviewLayout.focus => 4,
  };

  int get columns => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad || MultiviewLayout.focus => 2,
  };

  int get rows => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 1,
    MultiviewLayout.quad || MultiviewLayout.focus => 2,
  };
}

enum MultiviewCellStatus {
  empty,

  resolving,

  playing,

  offline,

  error,
}

/// Whether a picker selection may replace this cell without first asking the
/// user to stop an active decoder. Offline and failed cells retain room/error
/// context for display, but are still vacant from a playback-resource point of
/// view.
bool isMultiviewCellAssignable(MultiviewCellStatus status) {
  return status == MultiviewCellStatus.empty ||
      status == MultiviewCellStatus.offline ||
      status == MultiviewCellStatus.error;
}

/// Strict room lookup reported an authoritative non-playable state.
///
/// The resolver uses this typed signal so the controller can distinguish a
/// normal offline room from transport, parser and player failures without
/// parsing localized exception strings.
class MultiviewRoomOffline implements Exception {
  const MultiviewRoomOffline(this.room);

  final LiveRoom room;

  @override
  String toString() => 'MultiviewRoomOffline(${room.identityKey}, ${room.effectiveLiveStatus.name})';
}

enum MultiviewCellErrorKind {
  resolveFailure,

  startFailure,
}

typedef MultiviewQualityLoader = Future<MultiviewStreamSource> Function(LivePlayQuality quality);

/// An expiring line (Douyu anonymous original quality) and how to renew it.
class MultiviewSourceLease {
  const MultiviewSourceLease({required this.refreshAt, required this.renew});

  final DateTime refreshAt;
  final FlvSourceRenewer renew;
}

/// The lease of one line URL, or null when the line needs none.
typedef MultiviewLeaseLookup = MultiviewSourceLease? Function(String url);

class MultiviewStreamSource {
  const MultiviewStreamSource({
    required this.url,
    required this.headers,
    this.detail,
    this.qualities = const <LivePlayQuality>[],
    this.qualityIndex = 0,
    this.qualityLoader,
    this.lines = const <String>[],
    this.lineIndex = 0,
    this.sourceQueryPolicies = const <String, HlsSourceQueryPolicy>{},
    this.leaseFor,
  }) : ownedSource = null;

  const MultiviewStreamSource.owned({
    required OwnedPlaybackSource source,
    this.detail,
    this.qualities = const <LivePlayQuality>[],
    this.qualityIndex = 0,
    this.qualityLoader,
  }) : ownedSource = source,
       url = '',
       headers = const {},
       lines = const [],
       lineIndex = 0,
       sourceQueryPolicies = const {},
       leaseFor = null;

  /// Room detail fetched while resolving this source; carries the danmaku
  /// ticket so the chat session needs no second detail request.
  final LiveRoom? detail;

  /// A public factory; the private URI stays inside the per-cell transport.
  final OwnedPlaybackSource? ownedSource;
  int get lineCount => ownedSource == null ? lines.length : 1;

  final String url;

  final Map<String, String> headers;

  final List<LivePlayQuality> qualities;

  final int qualityIndex;

  final MultiviewQualityLoader? qualityLoader;

  final List<String> lines;

  final int lineIndex;

  final Map<String, HlsSourceQueryPolicy> sourceQueryPolicies;

  /// Leases of expiring lines; the cell relay renews them without a reopen.
  final MultiviewLeaseLookup? leaseFor;
}

class MultiviewCellState {
  const MultiviewCellState({
    required this.index,
    this.room,
    this.status = MultiviewCellStatus.empty,
    this.errorKind,
    this.errorDetail,
    this.videoController,
    this.qualities = const <LivePlayQuality>[],
    this.qualityIndex = 0,
    this.qualityLoader,
    this.headers = const <String, String>{},
    this.lines = const <String>[],
    this.lineIndex = 0,
    this.sourceQueryPolicies = const <String, HlsSourceQueryPolicy>{},
    this.ownedSource,
  });

  final int index;

  final LiveRoom? room;

  final MultiviewCellStatus status;

  final MultiviewCellErrorKind? errorKind;

  final String? errorDetail;

  final VideoController? videoController;

  final List<LivePlayQuality> qualities;

  final int qualityIndex;

  final MultiviewQualityLoader? qualityLoader;

  final Map<String, String> headers;

  final List<String> lines;

  final int lineIndex;

  final Map<String, HlsSourceQueryPolicy> sourceQueryPolicies;

  final OwnedPlaybackSource? ownedSource;
  int get lineCount => ownedSource == null ? lines.length : 1;

  factory MultiviewCellState.empty(int index) => MultiviewCellState(index: index);

  MultiviewCellState copyWith({
    LiveRoom? room,
    bool clearRoom = false,
    MultiviewCellStatus? status,
    MultiviewCellErrorKind? errorKind,
    String? errorDetail,
    bool clearError = false,
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualities,
    int? qualityIndex,
    MultiviewQualityLoader? qualityLoader,
    bool clearQuality = false,
    Map<String, String>? headers,
    List<String>? lines,
    int? lineIndex,
    Map<String, HlsSourceQueryPolicy>? sourceQueryPolicies,
    OwnedPlaybackSource? ownedSource,
    bool clearOwnedSource = false,
  }) {
    return MultiviewCellState(
      index: index,
      ownedSource: clearQuality || clearOwnedSource ? null : ownedSource ?? (lines == null ? this.ownedSource : null),
      room: clearRoom ? null : (room ?? this.room),
      status: status ?? this.status,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      videoController: clearVideoController ? null : (videoController ?? this.videoController),
      qualities: clearQuality ? const <LivePlayQuality>[] : (qualities ?? this.qualities),
      qualityIndex: clearQuality ? 0 : (qualityIndex ?? this.qualityIndex),
      qualityLoader: clearQuality ? null : (qualityLoader ?? this.qualityLoader),
      headers: clearQuality ? const <String, String>{} : (headers ?? this.headers),
      lines: clearQuality ? const <String>[] : (lines ?? this.lines),
      lineIndex: clearQuality ? 0 : (lineIndex ?? this.lineIndex),
      sourceQueryPolicies: Map.unmodifiable(
        clearQuality
            ? <String, HlsSourceQueryPolicy>{}
            : (sourceQueryPolicies ?? (lines == null ? this.sourceQueryPolicies : <String, HlsSourceQueryPolicy>{})),
      ),
    );
  }
}
