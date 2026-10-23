import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// An anonymous control grant (`getControlServer.php`): the control socket of
/// one channel and the session that authorizes its playlists.
///
/// A grant is good for one socket and for about
/// [Fc2LiveEndpoints.controlLife]; the comment connection takes its own.
final class Fc2LiveGrant {
  /// The grant of [channelId].
  const Fc2LiveGrant({required this.channelId, required this.socket, required this.controlToken, required this.orz});

  /// The channel.
  final String channelId;

  /// `wss://<node>.live.fc2.com/control/channels/<channel>`.
  final Uri socket;

  /// `control_token`: the session of this socket, carried in its query.
  final String controlToken;

  /// `orz_raw`: the session token, sent as the handshake's `l_ortkn` cookie.
  final String orz;

  /// The socket with its `control_token`.
  Uri get endpoint => socket.replace(queryParameters: {'control_token': controlToken});

  /// The headers of the handshake: the site's origin and agent, and the
  /// session cookie. Nothing else is sent — the API requests carry no cookie.
  Map<String, String> get handshakeHeaders => {
    'origin': Fc2LiveEndpoints.origin,
    'user-agent': Fc2LiveEndpoints.userAgent,
    'cookie': '${Fc2LiveEndpoints.orzCookie}=$orz',
  };

  @override
  String toString() => 'Fc2LiveGrant($channelId, ${socket.host})';
}

/// The playlist a control plays, and the quality it actually is: a tier's
/// high-latency variant is played when the channel has no low-latency one, and
/// the player shows what plays rather than what was asked.
typedef Fc2LivePlaylist = ({String quality, Uri url});

/// Pure parsing of FC2 Live's playback side: a control grant, the HLS answer of
/// an open control, the qualities a channel offers, and the line of one of
/// them.
///
/// There is no URL to hand out for a channel in the abstract: the playlist
/// addresses the media server only accepts arrive from a control's HLS answer,
/// and stay worth asking for only while that control's socket is open. The
/// [Fc2LivePlayParser.lines] this makes therefore carry a
/// [LivePlayLease] for the grant's life and [LivePlayLine.lease]'s
/// `requiresReconnect`, which is what the player has instead of the socket the
/// reference held.
abstract final class Fc2LivePlayParser {
  /// The id of the adaptive quality (3.x's one and only).
  static const String autoQualityId = 'auto';

  /// The tiers, best first. The id is the playlist mode of the tier in a
  /// control's answer: the site transcodes every one of them, so none is the
  /// source. The names follow the site's own player.
  static final List<LivePlayQuality> tierQualities = [
    LivePlayQuality.of(label: '超清 3M（β）', qualityId: '50'),
    LivePlayQuality.of(label: '超清 2M', qualityId: '40'),
    LivePlayQuality.of(label: '高清', qualityId: '30'),
    LivePlayQuality.of(label: '标清', qualityId: '20'),
    LivePlayQuality.of(label: '流畅', qualityId: '10'),
  ];

  /// The adaptive master, kept after the tiers as 3.x kept it.
  static final LivePlayQuality autoQuality = LivePlayQuality.of(label: '自适应 HLS', qualityId: autoQualityId);

  /// Every quality a live room can have, in the site's menu order. Which of
  /// them a channel has is only known from its control answer ([qualitiesOf]).
  static final List<LivePlayQuality> menu = [...tierQualities, autoQuality];

  /// The ids of [menu]. 3.x's one id, `auto`, is unchanged, so a quality a
  /// viewer stored under 3.x needs no mapping.
  static const Set<String> qualityIds = {'50', '40', '30', '20', '10', autoQualityId};

  /// The playlist modes of [tierQualities], best first.
  static const List<int> tierModes = [50, 40, 30, 20, 10];

  /// The three latency families of a control's answer: the low-latency ones
  /// 3.x read, and the high- and middle-latency twins of every mode.
  static const List<String> playlistFamilies = ['playlists', 'playlists_high_latency', 'playlists_middle_latency'];

  /// The masters, by mode: the low-latency one is [autoQualityId]'s own.
  static const List<int> masterModes = [0, 1, 2];

  /// The playlist families tried for one tier, in the order the site's relay
  /// prefers: its high-latency variant (long segments, and a master makes
  /// ffmpeg fetch every variant it lists and stall), then the low-latency one,
  /// then the middle.
  static const List<int> tierOffsets = [1, 0, 2];

  /// The `getControlServer.php` answer for [channelId]: `status` other than 0
  /// is a refusal (the channel is not playable, or the site is not granting).
  ///
  /// The socket must be `wss` on the platform's own host, at exactly
  /// `/control/channels/<channelId>`, with no query, fragment or user info; the
  /// token, the session cookie and the URL must be there and within their
  /// limits, and the cookie value must be cookie-safe. Anything else is
  /// api-changed: a grant for another channel is never opened.
  static Fc2LiveGrant grant(String body, {required String channelId, int status = 200}) {
    const what = 'getControlServer';
    final root = Fc2LiveJson.object(body, what, status: status);
    final result = Fc2LiveJson.integer(root['status'], '$what status');
    if (result != 0) throw Fc2LiveFailure(Fc2LiveFailureKind.streamUnavailable, 'getControlServer: status $result');
    final url = Fc2LiveJson.bounded(root['url'], Fc2LiveEndpoints.grantUrlLimit, '$what url');
    final token = Fc2LiveJson.bounded(root['control_token'], Fc2LiveEndpoints.grantTokenLimit, '$what control_token');
    final orz = Fc2LiveJson.bounded(root['orz_raw'], Fc2LiveEndpoints.grantOrzLimit, '$what orz_raw');
    final socket = Uri.tryParse(url);
    if (socket == null ||
        socket.scheme != 'wss' ||
        socket.userInfo.isNotEmpty ||
        !Fc2LiveJson.isFc2Live(socket.host) ||
        socket.path != '/control/channels/$channelId' ||
        socket.hasQuery ||
        socket.hasFragment ||
        !orzSafe.hasMatch(orz)) {
      throw const Fc2LiveFailure(
        Fc2LiveFailureKind.apiChanged,
        'getControlServer: not a control socket of the channel',
      );
    }
    return Fc2LiveGrant(channelId: channelId, socket: socket, controlToken: token, orz: orz);
  }

  /// Whether an `orz_raw` can go in a cookie.
  static final RegExp orzSafe = RegExp(r'^[A-Za-z0-9._~-]+$');

  /// The control socket's `get_hls_information` answer, by playlist mode: every
  /// usable playlist of the three latency families, the first row of a mode
  /// winning.
  ///
  /// A mode below 10 is a family's master, the rest single variants; `90`, `91`
  /// and `92` are the sound-only ones, which no quality asks for. The answer
  /// must be the reply to request 1 (the control sends it exactly once), and
  /// its `arguments.status` other than 0 is a refusal. A row or a family that
  /// breaks the address rules is skipped alone — 3.x failed the whole answer,
  /// which lost every quality over one odd row — but an answer with no usable
  /// playlist at all is api-changed.
  static Map<int, Uri> hlsPlaylists(Map<String, Object?> message, {required String channelId}) {
    if (message['name'] != '_response_' || message['id'] != 1) {
      throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'control: not the answer to get_hls_information');
    }
    final arguments = Fc2LiveJson.map(message['arguments'], 'control arguments');
    final status = Fc2LiveJson.anyInteger(arguments['status'], 'control status');
    if (status != 0) throw Fc2LiveFailure(Fc2LiveFailureKind.streamUnavailable, 'get_hls_information: status $status');
    final found = <int, Uri>{};
    for (final family in playlistFamilies) {
      final rows = arguments[family];
      if (rows is! List || rows.length > Fc2LiveEndpoints.playlistFamilyRows) continue;
      for (final row in rows) {
        if (row is! Map) continue;
        final mode = Fc2LiveJson.jsonInt(row['mode']);
        if (mode == null || mode < 0 || mode > 999 || Fc2LiveJson.jsonInt(row['status']) != 0) continue;
        if (_playlist(row['url'], channelId: channelId, mode: mode) case final uri?) found.putIfAbsent(mode, () => uri);
      }
    }
    if (found.isEmpty) throw const Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'control: no playlist');
    return Map.unmodifiable(found);
  }

  /// A playlist address the media server will answer: https on the platform's
  /// own host, at `/a/stream/<channel>/<mode>/master_playlist` for a master and
  /// `…/playlist` for a variant, with exactly its two session tokens (and, for
  /// a master, the list of tiers it serves). Null for anything else, which
  /// loses that one playlist.
  static Uri? _playlist(Object? url, {required String channelId, required int mode}) {
    if (url is! String || url.isEmpty || url.length > Fc2LiveEndpoints.playlistLimit) return null;
    final uri = Uri.tryParse(url);
    final master = mode < 10;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !Fc2LiveJson.isFc2Live(uri.host) ||
        uri.path != '/a/stream/$channelId/$mode/${master ? 'master_playlist' : 'playlist'}' ||
        uri.hasFragment) {
      return null;
    }
    final Map<String, String> query;
    try {
      query = uri.queryParameters;
    } on FormatException {
      return null;
    }
    final keys = master ? const {'targets', 'c', 'd'} : const {'c', 'd'};
    if (!sessionToken(query['c']) ||
        !sessionToken(query['d']) ||
        (master && !targets(query['targets'])) ||
        query.keys.any((key) => !keys.contains(key))) {
      return null;
    }
    return uri;
  }

  /// One of the two session tokens a playlist carries: 1 to
  /// [Fc2LiveEndpoints.mediaTokenLimit] characters.
  static bool sessionToken(String? value) =>
      value != null && value.isNotEmpty && value.length <= Fc2LiveEndpoints.mediaTokenLimit;

  static final RegExp _targetList = RegExp(r'^\d{1,3}(?:,\d{1,3}){0,15}$');

  /// The tiers a master lists: at most [Fc2LiveEndpoints.maxTargets] numbers,
  /// within [Fc2LiveEndpoints.targetsLimit] characters.
  static bool targets(String? value) =>
      value != null && value.length <= Fc2LiveEndpoints.targetsLimit && _targetList.hasMatch(value);

  /// The qualities a channel offers, in menu order: each tier with a variant in
  /// any family (so `50` and `40` appear only for the channels that have them)
  /// and the adaptive master when one is there. Nothing at all — an answer of
  /// only the sound modes — is a channel with no quality to show.
  static List<LivePlayQuality> qualitiesOf(Map<int, Uri> playlists) {
    final offered = [
      for (final quality in tierQualities)
        if (masterModes.any((offset) => playlists.containsKey(int.parse('${quality.qualityId}') + offset))) quality,
      if (masterModes.any(playlists.containsKey)) autoQuality,
    ];
    final total = offered.length;
    return [for (final (index, quality) in offered.indexed) quality.rebuild((b) => b..platformOrder = total - index)];
  }

  /// The playlist to play for [quality] among [playlists], or null when the
  /// channel has nothing of it:
  /// - a tier plays a single variant, preferring its high-latency family; a
  ///   tier the channel no longer offers falls back to the next lower one, then
  ///   to the next higher, and then to a master, and the result names the
  ///   quality that plays;
  /// - [autoQualityId] plays the low-latency master, else another master, else
  ///   the best tier.
  ///
  /// A quality that is not one of [qualityIds] gives nothing, as does a tier
  /// written any other way than the site's own (`'030'` and `'60'` are not
  /// modes).
  static Fc2LivePlaylist? playlistFor(Map<int, Uri> playlists, String quality) {
    Fc2LivePlaylist? tier(int mode) {
      for (final offset in tierOffsets) {
        if (playlists[mode + offset] case final url?) return (quality: '$mode', url: url);
      }
      return null;
    }

    Fc2LivePlaylist? master() {
      for (final mode in masterModes) {
        if (playlists[mode] case final url?) return (quality: autoQualityId, url: url);
      }
      return null;
    }

    if (quality == autoQualityId) return master() ?? tierModes.map(tier).nonNulls.firstOrNull;
    final requested = int.tryParse(quality);
    if (requested == null || !tierModes.contains(requested) || '$requested' != quality) return null;
    final lower = tierModes.where((mode) => mode < requested);
    final higher = tierModes.reversed.where((mode) => mode > requested);
    return [requested, ...lower, ...higher].map(tier).nonNulls.firstOrNull ?? master();
  }

  /// The one line of [playlist] for [channelId], leased for as long as the
  /// control that announced it is held: the media server answers its playlists
  /// only while that socket is open, and every HLS segment is a new request, so
  /// an expired grant ends playback rather than one read.
  ///
  /// The playlist addresses have no `.m3u8` suffix (they are named by their
  /// mode), so the format is declared by the control rather than inferred from
  /// the URL, and the codec is left undeclared — the master's `CODECS` are
  /// informational, and first-byte probing names them. [LivePlayLine.lineLabel]
  /// carries the quality that plays.
  static List<LivePlayLine> lines(
    Fc2LivePlaylist playlist, {
    required String channelId,
    required DateTime issuedAt,
    Duration? life,
  }) {
    final expiresAt = issuedAt.add(life ?? Fc2LiveEndpoints.controlLife);
    return [
      LivePlayLine.of(
        url: playlist.url.toString(),
        format: LiveStreamFormat.hls,
        formatSource: LivePlayFormatSource.declared,
        headers: Fc2LiveEndpoints.mediaHeaders(channelId),
        lineLabel: playlist.quality,
        lease: LivePlayLease.of(
          refreshAt: expiresAt.subtract(renewLead),
          expiresAt: expiresAt,
          requiresReconnect: true,
        ),
      ),
    ];
  }

  /// How before its end a line is re-resolved: a tenth of
  /// [Fc2LiveEndpoints.controlLife], so a viewer who keeps watching is moved to
  /// a fresh grant and a fresh control before the current one dies.
  static const Duration renewLead = Duration(seconds: 6);
}
