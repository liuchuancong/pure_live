import 'dart:convert';

import 'package:live_iptv/src/import/iptv_importer.dart' show IptvFetcher;
import 'package:live_iptv/src/import/live_net_fetch.dart';
import 'package:live_iptv/src/model/iptv_channel/iptv_channel.dart';
import 'package:live_iptv/src/model/iptv_entry/iptv_entry.dart';
import 'package:live_iptv/src/model/xtream_source/xtream_source.dart';
import 'package:live_net/live_net.dart';

/// The live catalogue of an [XtreamSource], read over the Xtream Codes
/// player API.
///
/// Two requests carry it, and they are the two every Xtream Codes server
/// understands: `action=get_live_streams` for the channels and
/// `action=get_live_categories` for the names of their groups — the stream
/// rows carry only a `category_id`, so without the join every group would
/// be a number. The transport is the importer's [IptvFetcher] seam, wired
/// at the composition root with `iptvFetcherFor`, so a catalogue download
/// goes out with the same client, proxy rules and user agent as every
/// other.
final class XtreamCatalogService {
  /// A catalogue service over [http].
  new({required LiveHttp http, Duration timeout = iptvFetchDefaultTimeout, String? userAgent, ProxyRoute? proxyRoute})
    : _fetch = iptvFetcherFor(http, timeout: timeout, userAgent: userAgent, proxyRoute: proxyRoute);

  /// How the player API is downloaded.
  final IptvFetcher _fetch;

  /// Every live stream [source]'s account can play.
  ///
  /// A channel's [IptvChannel.id] is the stream id the server gave, prefixed
  /// by the host so two servers cannot collide; its EPG match is the
  /// `epg_channel_id` the panel carries, which a guide matches the way a
  /// playlist's `tvg-id` does; and its playable URL is
  /// [XtreamSource.liveStreamUrl].
  ///
  /// A rejected account, an answer that is not a stream list, or a
  /// transport failure throws — a catalogue that pretends to be empty sends
  /// the viewer hunting for channels that were never there. A genuinely
  /// empty catalogue comes back as an empty list. The categories request
  /// decides only the groups: when it fails, the channels keep whatever
  /// group their rows carried, because an unnamed group costs less than a
  /// catalogue the server did answer.
  Future<List<IptvChannel>> fetchChannels(XtreamSource source) async {
    final streams = await _streamList(source);
    final categories = await _categoryNames(source);
    final api = source.playerApi();
    final host = api.hasPort ? '${api.host}:${api.port}' : api.host;
    final channels = <IptvChannel>[];
    for (final stream in streams) {
      if (stream is! Map) {
        continue;
      }
      final channel = _channelOf(stream, source: source, categories: categories, host: host);
      if (channel != null) {
        channels.add(channel);
      }
    }
    return channels;
  }

  /// `action=get_live_streams` as the list it must be.
  Future<List<Object?>> _streamList(XtreamSource source) async {
    final text = await _fetch(source.playerApi(action: 'get_live_streams'));
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException('the player API answered no JSON: ${error.message}', source.url);
    }
    if (decoded is List) {
      return decoded;
    }
    // An account the panel refuses never reaches a stream list: it comes
    // back as the account object the API answers with instead.
    if (decoded case {'user_info': final Object? userInfo} when userInfo is Map && _denied(userInfo['auth'])) {
      throw FormatException('the server rejected these credentials', source.url);
    }
    throw FormatException('the player API answered something other than a stream list', source.url);
  }

  /// `category_id` → `category_name`, empty when the request fails: the
  /// groups are decoration, and one broken request must not cost the
  /// channels under them.
  Future<Map<String, String>> _categoryNames(XtreamSource source) async {
    try {
      final text = await _fetch(source.playerApi(action: 'get_live_categories'));
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        return const {};
      }
      return {
        for (final category in decoded)
          if (category is Map && _text(category['id']) != null)
            if (_text(category['category_name']) case final String name) '${category['id']}': name,
      };
    } on Object {
      return const {};
    }
  }

  /// [stream] as a channel, or null when it has no stream id to play —
  /// a row without one is a row nothing can ever open.
  IptvChannel? _channelOf(
    Map<Object?, Object?> stream, {
    required XtreamSource source,
    required Map<String, String> categories,
    required String host,
  }) {
    final id = _text(stream['stream_id']);
    if (id == null) {
      return null;
    }
    final group = _text(stream['group_title']) ?? categories[_text(stream['category_id']) ?? ''];
    return IptvChannel.of(
      id: 'xtream://$host/$id',
      entry: IptvEntry.of(
        name: _text(stream['name']) ?? '',
        url: source.liveStreamUrl(id).toString(),
        group: group,
        tvgId: _text(stream['epg_channel_id']),
        tvgLogo: _text(stream['stream_icon']),
        channelNumber: int.tryParse(_text(stream['num']) ?? ''),
      ),
    );
  }

  /// Whether an account's `auth` answer says no.
  ///
  /// Panels write the refusal in every type they have: `false`, `0`,
  /// `"False"`.
  bool _denied(Object? auth) => switch (auth) {
    null => false,
    final bool value => !value,
    final num value => value == 0,
    final String value => switch (value.trim().toLowerCase()) {
      '' || 'false' || '0' => true,
      _ => false,
    },
    _ => false,
  };

  /// [value] as the trimmed text of a stream row, null when it is absent or
  /// blank — a blank logo is no logo, not a logo of the empty string.
  String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
