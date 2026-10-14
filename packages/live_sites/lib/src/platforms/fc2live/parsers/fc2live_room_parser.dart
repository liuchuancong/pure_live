import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_json.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Where a channel stands, as the platform answers it.
enum Fc2LiveState {
  /// `is_publish` 1 and open to anonymous viewers.
  live,

  /// Not broadcasting (anything else).
  offline,

  /// Broadcasting, but paid, ticketed, for signed-in viewers only, or
  /// restricted by FC2 — [Fc2LiveChannel.restriction] says which. The channel
  /// is live and carries the restriction; 3.x showed these as an unknown state
  /// and never as live, which is why a stored room used to look dead.
  restricted,
}

/// One channel of the directory or of a member answer.
final class Fc2LiveChannel {
  /// The channel as the platform describes it.
  const Fc2LiveChannel({
    required this.channelId,
    required this.userName,
    required this.title,
    required this.cover,
    required this.categoryId,
    required this.state,
    this.description = '',
    this.avatar = '',
    this.currentViewers,
    this.totalViewers,
    this.startedAt,
    this.restriction,
    this.isAdult = false,
  });

  /// The channel number: the room id.
  final String channelId;

  /// The owner's name: `profile_data.name`, else `channel_data.tname` (a
  /// member answer) or `name` (a directory row), each decoded and collapsed;
  /// empty when the platform has none — 3.x wrote the channel number there.
  final String userName;

  /// The broadcast's title, else [userName]; empty when both are.
  final String title;

  /// `channel_data.info`: the channel's own introduction (a member answer
  /// only; the directory does not carry it).
  final String description;

  /// `image`: the current thumbnail, empty when it is not one of the
  /// platform's images.
  final String cover;

  /// The owner's picture (a member answer only): `profile_data.icon`, else
  /// `profile_data.image`, else empty.
  final String avatar;

  /// `category`: the site's channel category, 0–99.
  final int categoryId;

  /// The name of the area [categoryId] belongs to.
  String get categoryName => Fc2LiveEndpoints.areaName(categoryId);

  /// `count`: viewers now.
  final int? currentViewers;

  /// `total`: viewers of this broadcast so far.
  final int? totalViewers;

  /// When the broadcast started, while it is on air.
  final DateTime? startedAt;

  /// What keeps viewers out of a broadcast on air: [LiveRestriction.none] when
  /// nothing does, and null when the channel is offline.
  final LiveRestriction? restriction;

  /// The broadcast state.
  final Fc2LiveState state;

  /// `adult` 1: the platform's own mark, which does not keep this client out
  /// (an adult channel plays).
  final bool isAdult;

  @override
  String toString() => 'Fc2LiveChannel($channelId, ${state.name})';
}

/// A member answer: the channel and its `version`, which a control grant needs.
/// An offline channel has no version (the site answers `''`).
typedef Fc2LiveMember = ({Fc2LiveChannel channel, String? version});

/// What a room carries for the platform's own use: the state and the flags
/// behind its notice and area, so a later request knows what it may play
/// without asking the channel again.
final class Fc2LiveRoomData {
  /// The data of [channelId].
  const Fc2LiveRoomData({
    required this.channelId,
    required this.state,
    required this.categoryId,
    this.restriction,
    this.isAdult = false,
  });

  /// The channel.
  final String channelId;

  /// The broadcast state.
  final Fc2LiveState state;

  /// `category`: the site's own category number, which the area list names.
  final int categoryId;

  /// The restriction of a broadcast on air.
  final LiveRestriction? restriction;

  /// Marked adult by the platform.
  final bool isAdult;

  @override
  String toString() => 'Fc2LiveRoomData($channelId, ${state.name})';
}

/// What a comment connection needs: the channel. Comments travel on a control
/// socket of their own, so the channel number is the whole address.
@immutable
final class Fc2LiveDanmakuArgs {
  /// The arguments of [channelId].
  const Fc2LiveDanmakuArgs(this.channelId);

  /// The channel number.
  final String channelId;

  @override
  bool operator ==(Object other) => other is Fc2LiveDanmakuArgs && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;

  @override
  String toString() => 'Fc2LiveDanmakuArgs($channelId)';
}

/// Pure parsing of FC2 Live's channel answers: the directory snapshot, a
/// channel's member answer, the areas the site's categories fall into, and the
/// room the app shows.
///
/// Nothing here reaches the network. The strictness is the platform's: a field
/// the site always sends as a number fails the answer when it is not one, while
/// a single unreadable row of the directory is skipped alone (3.x failed the
/// whole list, which turned one odd row into a dead directory).
abstract final class Fc2LiveRoomParser {
  static const String _site = 'fc2live';

  /// The notice of a restricted channel, and of an adult one (3.x's zh.json
  /// text, kept in the platform's own words because it states a fact about the
  /// room that no field of the model says).
  static const Map<String, String> noticeText = {
    'restricted': '该 FC2 直播需要登录、积分、门票或付费；界面保留受限状态，不将其显示成未开播。',
    'adult': '该房间由平台标记为成人内容，不进入普通公开目录。',
  };

  // Channels and links ---------------------------------------------------------

  /// The channel [raw] names: a channel number (trimmed), a channel link, or
  /// null.
  static String? channel(String raw) {
    final input = raw.trim();
    return Fc2LiveEndpoints.isChannelId(input) ? input : channelIdFromUrl(input);
  }

  /// The channel of a channel link: http(s) on `live.fc2.com` in any case,
  /// without user info or fragment, at `/<channel>/` or `/<language>/<channel>/`
  /// (a query is allowed and ignored). Other pages of the site — `/rank/`,
  /// `/<channel>/archive` — and other hosts are not rooms, and there is no
  /// short link to follow.
  static String? channelIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != Fc2LiveEndpoints.host ||
        uri.hasFragment) {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    return switch (segments) {
      [final id] when Fc2LiveEndpoints.isChannelId(id) => id,
      [final locale, final id]
          when Fc2LiveEndpoints.locales.contains(locale.toLowerCase()) && Fc2LiveEndpoints.isChannelId(id) =>
        id,
      _ => null,
    };
  }

  // Catalog -------------------------------------------------------------------

  /// The platform's areas: the six the site's own filter row offers, in its
  /// order, under the one category `FC2 Live`. No request: FC2 has no area
  /// list, only these categories.
  static List<LiveArea> areas() => [
    for (final (index, entry) in Fc2LiveEndpoints.areaNames.entries.indexed)
      LiveArea.normalized(
        platform: _site,
        areaId: entry.key,
        areaName: entry.value,
        parentAreaId: Fc2LiveEndpoints.categoryId,
        parentAreaName: Fc2LiveEndpoints.categoryName,
        position: index,
      ),
  ];

  /// The channel category an area selects: null for `all`, else 1, 2, 4, 5 or
  /// 9. Another id — or one that is not a number at all — is a caller error,
  /// never a filter that silently matches nothing.
  static int? areaFilter(String areaId) {
    final id = areaId.trim();
    if (id == Fc2LiveEndpoints.allAreasId) return null;
    final value = int.tryParse(id);
    if (value == null || !Fc2LiveEndpoints.areaCategories.contains(value)) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.invalidArgument, 'area "$areaId" is not an FC2 Live area');
    }
    return value;
  }

  /// Whether [channel] is in the area of [category] (null: every channel). The
  /// site's "game / work" area holds both of its categories, 2 and 3.
  static bool inArea(Fc2LiveChannel channel, int? category) =>
      category == null || channel.categoryId == category || (category == 2 && channel.categoryId == 3);

  // Directory -----------------------------------------------------------------

  /// `allchannellist.php`: every public channel on air, in the site's order.
  ///
  /// A row of another `type` (0 an open chat, 2 a private two-shot) is not a
  /// public media room and is skipped. A row that cannot be read is skipped
  /// alone (3.x failed the whole directory over one row), but a list of nothing
  /// but unreadable rows is api-changed, so a changed API never looks like a
  /// quiet evening. `time` must be a positive integer and the list of at most
  /// [Fc2LiveEndpoints.maxDirectoryRows] rows: 63 rows on 2026-09-27. A channel
  /// listed twice is kept once.
  static List<Fc2LiveChannel> directory(String body, {int status = 200}) {
    const what = 'allchannellist';
    final root = Fc2LiveJson.object(body, what, status: status);
    if (Fc2LiveJson.integer(root['time'], '$what time') < 1) {
      throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'allchannellist: time');
    }
    final rows = root['channel'];
    if (rows is! List || rows.length > Fc2LiveEndpoints.maxDirectoryRows) {
      throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'allchannellist: no channel list');
    }
    final seen = <String>{};
    final channels = <Fc2LiveChannel>[];
    var unreadable = 0;
    for (final row in rows) {
      final Fc2LiveChannel channel;
      try {
        final data = Fc2LiveJson.map(row, '$what row');
        if (Fc2LiveJson.integer(data['type'], '$what type') != 1) continue;
        channel = _directoryChannel(data);
      } on Fc2LiveFailure catch (failure) {
        if (failure.kind != Fc2LiveFailureKind.apiChanged) rethrow;
        unreadable++;
        continue;
      }
      if (seen.add(channel.channelId)) channels.add(channel);
    }
    if (channels.isEmpty && unreadable > 0) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'allchannellist: none of $unreadable rows can be read');
    }
    return List.unmodifiable(channels);
  }

  static Fc2LiveChannel _directoryChannel(Map<String, Object?> data) {
    const what = 'allchannellist';
    final id = Fc2LiveJson.channelNumber(data['id'], '$what id');
    final restriction = directoryRestriction(
      pay: Fc2LiveJson.integer(data['pay'], '$what pay'),
      ticket: Fc2LiveJson.integer(data['tid'], '$what tid'),
      login: Fc2LiveJson.integer(data['login'], '$what login'),
    );
    final name = Fc2LiveJson.displayText(data['name'], '$what name');
    return Fc2LiveChannel(
      channelId: id,
      userName: name,
      title: Fc2LiveJson.firstText([Fc2LiveJson.displayText(data['title'], '$what title'), name]),
      cover: Fc2LiveJson.image(data['image']),
      categoryId: Fc2LiveJson.category(data['category'], what),
      currentViewers: Fc2LiveJson.count(data['count'], '$what count'),
      totalViewers: Fc2LiveJson.count(data['total'], '$what total'),
      startedAt: Fc2LiveJson.startTime(data['start_time']),
      restriction: restriction,
      state: restriction == LiveRestriction.none ? Fc2LiveState.live : Fc2LiveState.restricted,
    );
  }

  /// The restriction a directory row marks, by the site's card marks in their
  /// order: `pay` (points per minute) and `tid` (a ticket or premium broadcast)
  /// are paid, `login` 1 (signed-in viewers) and 2 (those holding points, free
  /// to watch) need an account, and all 0 is open.
  static LiveRestriction directoryRestriction({required int pay, required int ticket, required int login}) {
    if (pay != 0 || ticket != 0) return LiveRestriction.paid;
    if (login != 0) return LiveRestriction.needsLogin;
    return LiveRestriction.none;
  }

  /// The restriction of a live member answer: `is_limited` (the site shows
  /// "配信規制中" and sends every viewer out) is unplayable; `fee`, `ticketid`
  /// and `ticket_only` are paid; `login_only` needs an account; all 0 is open.
  static LiveRestriction memberRestriction({
    required int limited,
    required int fee,
    required int ticketId,
    required int ticketOnly,
    required int loginOnly,
  }) {
    if (limited != 0) return LiveRestriction.unplayable;
    if (fee != 0 || ticketId != 0 || ticketOnly != 0) return LiveRestriction.paid;
    if (loginOnly != 0) return LiveRestriction.needsLogin;
    return LiveRestriction.none;
  }

  /// Why a broadcast with [restriction] cannot be played here, or null when
  /// nothing keeps it out: an account-only broadcast is a login the app cannot
  /// do, and the rest is content this client is not given.
  static Fc2LiveFailure? refusal(LiveRestriction? restriction, String channelId) => switch (restriction) {
    null || LiveRestriction.none => null,
    LiveRestriction.needsLogin => Fc2LiveFailure(
      Fc2LiveFailureKind.needsLogin,
      'channel $channelId is for signed-in viewers only',
    ),
    LiveRestriction.paid => Fc2LiveFailure(
      Fc2LiveFailureKind.streamUnavailable,
      'channel $channelId is a paid or ticketed broadcast',
    ),
    LiveRestriction.unplayable => Fc2LiveFailure(
      Fc2LiveFailureKind.streamUnavailable,
      'channel $channelId is restricted by FC2 (配信規制中)',
    ),
    final LiveRestriction other => Fc2LiveFailure(
      Fc2LiveFailureKind.streamUnavailable,
      'channel $channelId is restricted (${other.name})',
    ),
  };

  // Member --------------------------------------------------------------------

  /// `memberApi.php` of [channelId].
  ///
  /// `status` other than 1 is no such channel — and so is a `status` 1 answer
  /// whose `profile_data.userid` is empty, which is how the site answers a
  /// number that was never a channel. The answer must be about [channelId].
  /// The five restriction flags, `is_publish` and `adult` must be integers (the
  /// site writes them as `"1"`), and `version` is text of at most 256
  /// characters.
  ///
  /// `is_publish` 1 is on air; a live channel with any restriction flag is
  /// [Fc2LiveState.restricted] and still live. Its `version` is kept for the
  /// grant: 3.x required one of every channel and so failed on every offline
  /// one, which the site answers with `''`.
  static Fc2LiveMember member(String body, {required String channelId, int status = 200}) {
    const what = 'memberApi';
    final root = Fc2LiveJson.object(body, what, status: status);
    if (Fc2LiveJson.integer(root['status'], '$what status') != 1) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.notFound, 'memberApi: no channel $channelId');
    }
    final data = Fc2LiveJson.map(root['data'], '$what data');
    final row = Fc2LiveJson.map(data['channel_data'], '$what channel_data');
    final rawProfile = data['profile_data'];
    final profile = rawProfile == null ? null : Fc2LiveJson.map(rawProfile, '$what profile_data');
    final id = Fc2LiveJson.channelNumber(row['channelid'], '$what channelid');
    if (id != channelId) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'memberApi: answered for channel $id, not $channelId');
    }
    if (profile != null && Fc2LiveJson.optionalId(profile['userid']) == null) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.notFound, 'memberApi: channel $channelId has no owner');
    }
    final published = Fc2LiveJson.integer(row['is_publish'], '$what is_publish') == 1;
    int flag(String key) => Fc2LiveJson.integer(row[key], '$what $key');
    final restriction = memberRestriction(
      limited: flag('is_limited'),
      fee: flag('fee'),
      ticketId: flag('ticketid'),
      ticketOnly: flag('ticket_only'),
      loginOnly: flag('login_only'),
    );
    final version = Fc2LiveJson.text(row['version'], '$what version', limit: Fc2LiveEndpoints.versionLimit);
    final name = Fc2LiveJson.firstText([
      Fc2LiveJson.displayText(profile?['name'], '$what name'),
      Fc2LiveJson.displayText(row['tname'], '$what tname'),
    ]);
    return (
      channel: Fc2LiveChannel(
        channelId: id,
        userName: name,
        title: Fc2LiveJson.firstText([Fc2LiveJson.displayText(row['title'], '$what title'), name]),
        description: Fc2LiveJson.displayText(row['info'], '$what info'),
        cover: Fc2LiveJson.image(row['image']),
        avatar: Fc2LiveJson.firstText([_profileImage(profile?['icon']), _profileImage(profile?['image'])]),
        categoryId: Fc2LiveJson.category(row['category'], what),
        currentViewers: Fc2LiveJson.count(row['count'], '$what count'),
        totalViewers: Fc2LiveJson.count(row['total'], '$what total'),
        startedAt: published ? Fc2LiveJson.startTime(row['start']) : null,
        restriction: published ? restriction : null,
        state: !published
            ? Fc2LiveState.offline
            : restriction != LiveRestriction.none
            ? Fc2LiveState.restricted
            : Fc2LiveState.live,
        isAdult: flag('adult') == 1,
      ),
      version: version.isEmpty ? null : version,
    );
  }

  /// A picture of `profile_data`: the platform's own check, with whatever it
  /// refuses made simply "no picture" — a field 3.x never read at all.
  static String _profileImage(Object? value) => value is String ? Fc2LiveJson.image(value) : '';

  // Rooms ---------------------------------------------------------------------

  /// The room of [channel]: live (a restricted one too, marked with its
  /// restriction) or offline; the viewers now and the broadcast's total only
  /// while on air (3.x wrote an offline channel's zeros); the start time while
  /// on air; the owner's picture as the avatar, else the thumbnail; the channel
  /// page as the link; the platform's notice where one applies; and the
  /// [Fc2LiveRoomData] the platform keeps for itself. With [danmaku] the room
  /// carries its comment arguments.
  static LiveRoom room(Fc2LiveChannel channel, {bool danmaku = false}) {
    final live = channel.state != Fc2LiveState.offline;
    final restriction = live ? channel.restriction : null;
    return LiveRoom.normalized(
      platform: _site,
      roomId: channel.channelId,
      content: RoomContent(
        title: channel.title,
        coverUrl: channel.cover,
        introduction: channel.description.isEmpty ? null : channel.description,
        notice: notice(channel),
        platformTags: [if (channel.isAdult) 'adult'],
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: channel.channelId,
        name: channel.userName,
        avatarUrl: channel.avatar.isEmpty ? channel.cover : channel.avatar,
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      ),
      area: LiveArea.normalized(
        platform: _site,
        areaId: '${channel.categoryId}',
        areaName: channel.categoryName,
        parentAreaId: Fc2LiveEndpoints.categoryId,
        parentAreaName: Fc2LiveEndpoints.categoryName,
      ),
      audience: RoomAudience(
        onlineViewers: live ? channel.currentViewers : null,
        totalViewers: live ? channel.totalViewers : null,
        primaryMetric: channel.currentViewers == null
            ? LiveAudienceMetricType.unknown
            : LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast(
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        startedAt: live ? channel.startedAt : null,
        restriction: restriction,
      ),
      links: RoomLinks(webUrl: Fc2LiveEndpoints.channelUrl(channel.channelId)),
      runtime: RoomRuntime(
        streamHandle: Fc2LiveRoomData(
          channelId: channel.channelId,
          state: channel.state,
          categoryId: channel.categoryId,
          restriction: restriction,
          isAdult: channel.isAdult,
        ),
        danmakuHandle: danmaku ? Fc2LiveDanmakuArgs(channel.channelId) : null,
      ),
    );
  }

  /// The room's notice: the restricted one for a broadcast the platform keeps
  /// from anonymous viewers, else the adult mark, else nothing (a restricted
  /// broadcast is named first: its restriction is why it cannot be watched,
  /// whatever else is true of it).
  static String? notice(Fc2LiveChannel channel) => switch (channel) {
    Fc2LiveChannel(state: Fc2LiveState.restricted) => noticeText['restricted'],
    Fc2LiveChannel(isAdult: true) => noticeText['adult'],
    _ => null,
  };

  // Pages ---------------------------------------------------------------------

  /// Whether 3.x served a slice of [page] by [pageSize]: page 1 and up, 1 to
  /// [Fc2LiveEndpoints.maxPageSize] rooms. Anything else gave nothing.
  static bool validSlice({required int page, required int pageSize}) =>
      page >= 1 && pageSize >= 1 && pageSize <= Fc2LiveEndpoints.maxPageSize;

  /// Slice [page] of [pageSize] of [values]: empty when [validSlice] is false
  /// or the page is past the end.
  static List<T> slice<T>(List<T> values, {required int page, required int pageSize}) {
    if (!validSlice(page: page, pageSize: pageSize)) return const [];
    final start = (page - 1) * pageSize;
    if (start >= values.length) return const [];
    return values.sublist(start, (start + pageSize).clamp(0, values.length));
  }

  /// The channels whose number, name, title or area name — the platform's own,
  /// or 3.x's English one — contains [keyword] (trimmed, case ignored), in the
  /// directory's order. FC2 has no search API: this is the whole of it, and the
  /// English names are matched so a search made under 3.x still finds the same
  /// rooms. A keyword of `'0200'` matching channel `10200498` is the site's own
  /// substring behaviour, not a mistake.
  static List<Fc2LiveChannel> search(List<Fc2LiveChannel> channels, String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final channel in channels)
        if (channel.channelId.contains(query) ||
            channel.userName.toLowerCase().contains(query) ||
            channel.title.toLowerCase().contains(query) ||
            (channel.categoryName.isNotEmpty &&
                (channel.categoryName.toLowerCase().contains(query) ||
                    Fc2LiveEndpoints.legacyAreaName(channel.categoryId).toLowerCase().contains(query))))
          channel,
    ];
  }

  /// The room id of a channel number or link, or the not-found this adapter
  /// reports for anything else — without a request.
  static String requiredChannel(String roomId) {
    final id = channel(roomId);
    if (id == null) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.notFound, 'room id "${roomId.trim()}" is not an FC2 channel');
    }
    return id;
  }
}
