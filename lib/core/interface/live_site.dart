import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

/// The stream URLs returned for one requested quality together with the
/// quality that the platform actually applied.
///
/// Some platforms advertise a quality in `accept_qn` but silently downgrade
/// anonymous requests. Returning only the URLs made the UI commit the tapped
/// label even though the media source was still a lower quality.
///
/// Adapters that can inspect the response should set [appliedQualityData]
/// to the server's actual stable quality identifier.
///
/// The default implementation keeps the requested
/// [LivePlayQuality.selectionId] for platforms whose URL response has no
/// separate acknowledgement.
class LivePlayUrlResolution {
  const LivePlayUrlResolution({required this.urls, this.appliedQualityData});

  final List<String> urls;
  final Object? appliedQualityData;
}

/// Removes blank and duplicate lines while preserving platform priority.
///
/// Scheme validation remains adapter-specific because imported IPTV sources
/// may legitimately use non-HTTP protocols.
List<String> normalizeResolvedPlayUrls(Iterable<String> urls) {
  final result = <String>[];
  final seen = <String>{};

  for (final rawUrl in urls) {
    final url = rawUrl.trim();

    if (url.isNotEmpty && seen.add(url)) {
      result.add(url);
    }
  }

  return List<String>.unmodifiable(result);
}

/// Optional capability for platforms whose play API reports the quality that
/// was actually applied.
///
/// Use `resolvePlayUrlsRaw` intentionally here because `resolvePlayUrls` is
/// the unified extension API exposed by [LiveSite].
///
/// Most adapters can continue using [LiveSite.getPlayUrls].
/// Bilibili can implement this contract because guest requests may be
/// downgraded even when a higher `qn` was requested.
abstract interface class LivePlayUrlResolver {
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality});
}

class LiveSite {
  String id = "";
  String name = "";

  LiveDanmaku getDanmaku() {
    throw UnimplementedError();
  }

  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    return Future.value(<LiveCategory>[]);
  }

  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveAnchorItem>[]);
  }

  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    return Future.value(
      LiveRoom(
        cover: '',
        watching: '0',
        roomId: '',
        status: false,
        platform: platform,
        liveStatus: LiveStatus.offline,
        title: '',
        link: '',
        avatar: '',
        nick: '',
        isRecord: false,
      ),
    );
  }

  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    return Future.value(<LivePlayQuality>[]);
  }

  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return Future.value(<String>[]);
  }

  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    return Future.value(false);
  }

  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    return Future.value([]);
  }
}

/// Unified playback URL resolution.
///
/// Capability-aware adapters can return the quality actually applied by
/// the server through [LivePlayUrlResolver.resolvePlayUrlsRaw].
///
/// Other adapters continue using [LiveSite.getPlayUrls] and assume that
/// the requested quality was applied.
extension LiveSitePlayUrlResolution on LiveSite {
  Future<LivePlayUrlResolution> resolvePlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final site = this;

    if (site is LivePlayUrlResolver) {
      final resolver = site as LivePlayUrlResolver;

      final resolution = await resolver.resolvePlayUrlsRaw(detail: detail, quality: quality);

      return LivePlayUrlResolution(
        urls: normalizeResolvedPlayUrls(resolution.urls),
        appliedQualityData: resolution.appliedQualityData,
      );
    }

    return LivePlayUrlResolution(
      urls: normalizeResolvedPlayUrls(await getPlayUrls(detail: detail, quality: quality)),
      appliedQualityData: quality.selectionId,
    );
  }
}

/// Optional fast metadata path used by favourites/background verification.
///
/// Entering a room needs playback URLs, signing material and chat credentials;
/// refreshing a card needs only status/title/cover/audience metadata.
///
/// Keeping this as a separate capability lets platforms skip those extra
/// calls without changing the full room-entry contract for every site
/// implementation.
abstract interface class LiveSiteRoomRefresher {
  Future<LiveRoom> getRoomDetailForRefresh({required String roomId, required String platform});
}

/// Strict, playback-complete room lookup used before a recording starts.
///
/// The ordinary [LiveSite.getRoomDetail] contract is UI-oriented. Several
/// adapters deliberately turn transport/shape errors into an offline-looking
/// fallback room so an already mounted player can keep its last metadata.
/// That behaviour is useful for presentation, but it is unsafe for recording:
/// one temporary metadata error was interpreted as an authoritative offline
/// state and the recorder stopped before it ever asked for a stream URL.
///
/// [LiveSiteRoomRefresher] is not a substitute for this capability. Refresh
/// implementations may intentionally omit signed playback descriptors to keep
/// favourite-card refreshes cheap. Implementations of this interface must:
///
/// * propagate transport and response-shape failures;
/// * return an explicit offline/banned room only when the platform said so;
/// * retain every field required by [LiveSite.getPlayQualites].
abstract interface class LiveSiteRecordRoomResolver {
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform});
}
