import 'package:live_sites/live_sites.dart';

/// One playable address of a channel.
///
/// A channel of a real list usually has several; the source hands them over
/// already ranked, best first, so the site has nothing to decide beyond
/// which one the user asked for.
final class IptvLine {
  /// A line.
  const new({required this.url, this.headers = const {}, this.lineId});

  /// The stream URL.
  final String url;

  /// Request headers this address needs.
  final Map<String, String> headers;

  /// What the source calls this line, when it has a name for it.
  final String? lineId;
}

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
    this.number,
    this.lines = const [],
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

  /// The number the viewer types to reach this channel, null when it has
  /// none. A channel's number is a fact about the viewer's habit rather than
  /// about the stream, which is why it travels with the room instead of
  /// being re-derived from the list order on every screen.
  final int? number;

  /// The channel's addresses, best first; empty when the source has nothing
  /// better to say than [url].
  final List<IptvLine> lines;

  /// The addresses to try, in order: the ranked lines when the source named
  /// any, the channel's own URL otherwise.
  List<IptvLine> get playableLines => lines.isEmpty ? [IptvLine(url: url, headers: headers, lineId: 'channel')] : lines;
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
final class IptvSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability {
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
    // Every address the channel has, in the order the source ranks them:
    // an IPTV list is a set of mirrors of one stream, and handing the
    // player only the first turns a dead mirror into a black screen when
    // the next one would have played.
    return [
      for (final (index, line) in channel.playableLines.indexed)
        LivePlayLine(
          url: line.url,
          headers: line.headers,
          format: formatOfUrl(line.url),
          lineId: line.lineId ?? 'line-${index + 1}',
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

/// The wire format an IPTV address carries.
///
/// Judged from the address, because that is all a playlist says: `.m3u8` is
/// HLS, a `.flv` or a `.live.flv` is HTTP-FLV, and a bare host or a `.ts`
/// slice is something the player has to sniff.
StreamFormat formatOfUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.m3u8')) {
    return StreamFormat.hls;
  }
  if (path.endsWith('.flv')) {
    return StreamFormat.flv;
  }
  return StreamFormat.other;
}
