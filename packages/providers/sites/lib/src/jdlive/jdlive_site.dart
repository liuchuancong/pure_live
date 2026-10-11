// Module: lib/src/jdlive/jdlive_site.dart
// Purpose: The JD live source: the count-cursored featured directory, the room's two containers, and the
// playlist-verified play path.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained JD line (origin/master
// lib/shared/platforms/jdlive/jd_live_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: jdlive_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// Two readings differ from v1 on purpose, and both are the site's own evidence:
//   * **hls and flv are lines of one profile, not two qualities**. The room answer is refused when the two
//     addresses name different streams, which is the site saying they are the same stream in two containers. v1's
//     menu listed them as two qualities, so a viewer could "choose 1080p twice" and the second choice differed only
//     by file extension.
//   * **no keyword search is declared**. The v1 search walked the featured directory and filtered the rows it had
//     seen - which reports "nobody by that name" for the much larger set this list never covered. Opening a pasted
//     live link is the resolve path's job (`jdliveRoomFromUri`), and that is what this surface honestly can do.
//
// The play path reads the master playlist before handing out its address (one extra request). The grant is a
// directory rather than a file, and a playlist that points outside this stream is not this broadcast.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'jdlive_api.dart';

/// The JD live source. One [NetworkClient] for the process the source lives in.
final class JdliveSource
    implements
        FeedCapability,
        BrowseCapability,
        ResolveCapability,
        QualityCapability,
        LineCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  JdliveSource({NetworkClient? client, Clock? clock})
    : _api = JdApi(client: client, clock: clock),
      _clock = clock ?? systemClock;

  final JdApi _api;
  final Clock _clock;

  /// The one profile. The site ships one encode in two containers and names neither, so the menu says "原画" only
  /// in the sense that there is nothing below it to choose.
  static const String _profile = 'origin';

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async => _page(page);

  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[
    ContentCategory(id: jdliveFeaturedCategory, name: '精选'),
  ];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isNotEmpty && category != jdliveFeaturedCategory) {
      // async on purpose: an unknown listing reaches the caller as a Future error, not a synchronous throw.
      throw JdFailure('jdlive publishes one featured directory; "$category" is not it');
    }
    return _page(query.page);
  }

  Future<PageResult<ContentSummary>> _page(PageRequest request) async {
    if (request.page > 1 && (request.cursor ?? '').isEmpty) {
      throw const JdFailure('a jdlive page past the first needs the cursor the previous answer gave');
    }
    final result = await _api.directory(cursor: request.cursor);
    for (final room in result.rooms) {
      _remembered[room.liveId] = room;
      while (_remembered.length > 200) {
        _remembered.remove(_remembered.keys.first);
      }
    }
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in result.rooms) room.toLiveRoom().summary],
      page: request.page,
      pageSize: jdlivePageSize,
      hasMore: result.hasMore,
      mode: PageMode.cursor,
      nextCursor: result.cursor,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    // One read, and the count of containers comes out of the same answer rather than a second call.
    final room = await _api.room(ref.contentId);
    final filled = room.filledBy(_remembered[room.liveId]);
    _remembered[room.liveId] = filled;
    final live = filled.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      metadata: <String, Object?>{
        'state': room.state.name,
        if (room.statusCode != null) 'status': room.statusCode,
        'containers': room.addresses.length,
      },
    );
  }

  /// The cards this source has listed, so a room answer that names no anchor keeps what the grid showed.
  /// Bounded, because a process that scrolls forever should not grow a map without limit.
  final Map<String, JdRoom> _remembered = <String, JdRoom>{};

  @override
  Future<LiveRoom> room(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final filled = room.filledBy(_remembered[room.liveId]);
    _remembered[room.liveId] = filled;
    return filled.toLiveRoom();
  }

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // No media, no playlist fetch: the room answer's own state field is the whole question.
    final room = await _api.room(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: switch (room.state) {
        JdState.live => LiveRoomState.live,
        JdState.preview => LiveRoomState.notStarted,
        JdState.offline || JdState.replay => LiveRoomState.ended,
        JdState.paused || JdState.unknown => LiveRoomState.unknown,
      },
      viewers: room.totalViews,
      anchorName: room.nick.isEmpty ? null : room.nick,
    );
  }

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    if (room.addresses.isEmpty) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      StreamOption(
        id: _profile,
        kind: StreamOptionKind.quality,
        isDefault: true,
        available: true,
        requiresAuth: room.appOnly,
      ),
    ];
  }

  /// The containers of that one profile, in the site's own order: hls first, flv second.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final addresses = room.addresses;
    return <StreamOption>[
      for (var index = 0; index < addresses.length; index++)
        StreamOption(
          id: '${index + 1}',
          kind: StreamOptionKind.line,
          // The site names its containers nothing, so the label is the extension it actually shipped with.
          label: addresses[index] == room.hls ? 'hls' : 'flv',
          isDefault: index == 0,
        ),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    if (quality != null && quality.id.trim() != _profile) {
      throw StateError('jdlive serves one profile; quality "${quality.id}" does not exist');
    }
    final room = await _api.room(ref.contentId);
    if (room.appOnly) {
      throw StateError('jdlive live ${room.liveId} is served only inside the JD app (the site marks it secret)');
    }
    if (room.state != JdState.live) {
      throw StateError(switch (room.state) {
        JdState.preview => 'jdlive live ${room.liveId} has not started',
        JdState.replay => 'jdlive live ${room.liveId} is a replay and this path plays live streams',
        JdState.offline => 'jdlive live ${room.liveId} is not broadcasting',
        JdState.paused => 'jdlive live ${room.liveId} is paused right now',
        JdState.unknown => 'jdlive live ${room.liveId} did not state its status',
        JdState.live => 'jdlive live ${room.liveId} is not broadcasting',
      });
    }
    final addresses = room.addresses;
    if (addresses.isEmpty) {
      throw StateError('jdlive live ${room.liveId} is on air but shipped no address we are willing to open');
    }
    final index = _lineIndex(line, addresses.length);
    final uri = addresses[index];
    final container = uri == room.hls ? 'm3u8' : 'flv';
    // Only the hls grant is verified, and only when it is the container being opened: it costs a request, and a
    // refusal then means the grant was bad rather than that the broadcast stopped.
    if (container == 'm3u8') {
      await _api.validateHls(room);
    }
    return MediaTicket(
      id: '$jdliveSourceId/${room.liveId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: container == 'm3u8' ? MediaProtocol.hls : MediaProtocol.https,
      createdAt: _clock().toUtc(),
      headers: jdliveMediaHeaders(room.liveId),
      // The gateway states no lease length; the grant is re-read on the next play rather than prefetched on a
      // guessed schedule.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: jdliveSourceId, contentId: room.liveId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{'container': container, 'jdlive.quality': _profile, 'jdlive.line': index + 1},
      ),
    );
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError('jdlive serves $available container(s) for this stream; line "${line.id}" is not one of them');
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$jdliveSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('jdlive ticket ${expired.id} does not name a live');
    }
    final extra = expired.metadata.extra;
    return resolve(
      // The gateway re-issues the address per call and the playlist is re-verified with it, so a refresh is a new
      // read rather than a reuse of the grant that just expired.
      ContentRef(sourceId: jdliveSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      line: extra['jdlive.line'] == null ? null : SelectionRef('${extra['jdlive.line']}'),
    );
  }
}
