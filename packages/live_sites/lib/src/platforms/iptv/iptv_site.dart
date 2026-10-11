import 'package:live_sites/live_sites.dart';

/// One IPTV channel as the site layer sees it.
final class IptvChannel {
  /// A channel entry.
  const new({
    required this.id,
    required this.name,
    required this.url,
    this.group,
    this.headers = const {},
    this.epgChannelId,
    this.favorite = false,
  });

  /// Stable channel id.
  final String id;

  /// Display name.
  final String name;

  /// The stream URL.
  final String url;

  /// Playlist group.
  final String? group;

  /// Request headers the playlist declared.
  final Map<String, String> headers;

  /// The EPG channel id (tvg-id), when the playlist declared one.
  final String? epgChannelId;

  /// Whether the user favourited the channel.
  final bool favorite;
}

/// The channel data source the IPTV site reads.
///
/// The site layer does not parse playlists; the live_iptv package owns
/// M3U/TXT/EPG parsing and the channel library and implements this seam.
abstract interface class IptvChannelSource {
  /// Every channel of the current library.
  List<IptvChannel> get channels;

  /// The channel for [id], or null.
  IptvChannel? channelById(String id);
}

/// The IPTV "site": channels of an injected [IptvChannelSource] exposed
/// through the ordinary [LiveSite] contract, so the rest of the app plays
/// them like any other room.
final class IptvSite with SiteRoomGuard implements LiveSite {
  /// A site over [source].
  new({required this.source});

  /// The channel data source (the live_iptv library).
  final IptvChannelSource source;

  @override
  String get siteId => SiteIds.iptv;

  @override
  String get id => SiteIds.iptv;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.iptv, displayName: 'IPTV');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    final rooms = [for (final channel in source.channels) _room(channel)];
    final start = (page - 1) * 60;
    if (start >= rooms.length) {
      return const LivePage<LiveRoom>(items: []);
    }
    final end = start + 60 < rooms.length ? start + 60 : rooms.length;
    return LivePage<LiveRoom>(items: rooms.sublist(start, end), hasMore: end < rooms.length, nextPage: page + 1);
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    final rooms = [
      for (final channel in source.channels)
        if (channel.group == area.name) _room(channel),
    ];
    final start = (page - 1) * 60;
    if (start >= rooms.length) {
      return const LivePage<LiveRoom>(items: []);
    }
    final end = start + 60 < rooms.length ? start + 60 : rooms.length;
    return LivePage<LiveRoom>(items: rooms.sublist(start, end), hasMore: end < rooms.length, nextPage: page + 1);
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final lowered = keyword.trim().toLowerCase();
    final rooms = [
      for (final channel in source.channels)
        if (lowered.isEmpty || channel.name.toLowerCase().contains(lowered)) _room(channel),
    ];
    final start = (page - 1) * 60;
    if (start >= rooms.length) {
      return const LivePage<LiveRoom>(items: []);
    }
    final end = start + 60 < rooms.length ? start + 60 : rooms.length;
    return LivePage<LiveRoom>(items: rooms.sublist(start, end), hasMore: end < rooms.length, nextPage: page + 1);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final channel = source.channelById(room.roomId);
    if (channel == null) {
      throw SiteNotFoundError('iptv: no channel ${room.roomId}');
    }
    return room.mergeFrom(_room(channel, withData: true));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: '原画')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final channel = source.channelById(room.roomId);
    if (channel == null) {
      throw SiteNotFoundError('iptv: no channel ${room.roomId}');
    }
    return [
      LivePlayLine(
        url: channel.url,
        headers: channel.headers,
        format: channel.url.contains('.m3u8') ? StreamFormat.hls : StreamFormat.other,
        lineId: 'channel',
      ),
    ];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final channel = source.channelById(room.roomId);
    if (channel == null) {
      throw SiteNotFoundError('iptv: no channel ${room.roomId}');
    }
    return room.mergeFrom(_room(channel));
  }

  /// The room of [channel]; [withData] carries the channel for play.
  LiveRoom _room(IptvChannel channel, {bool withData = false}) => LiveRoom(
    platform: SiteIds.iptv,
    roomId: channel.id,
    title: channel.name,
    nick: channel.group ?? '',
    status: LiveStatus.live,
    tagIds: channel.favorite ? const ['favorite'] : const [],
    data: withData ? channel : null,
  );
}
