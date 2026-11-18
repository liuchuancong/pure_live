import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:live_vod/src/huya_ssr.dart' show HuyaSsr;
import 'package:live_vod/src/huya_video_api.dart' show HuyaVideo, HuyaVideoApi;
import 'package:live_vod/src/vod_models.dart' show VodFailure;

/// One stand the material library groups its clips by (`vhuyalol` → 英雄联盟).
final class HuyaMaterialChannel {
  /// The stand.
  const new({required this.id, required this.label});

  /// The id the library's own URLs carry.
  final String id;

  /// The stand's display name.
  final String label;
}

/// The material library (`www.huya.com/material`) over its server-rendered
/// pages.
///
/// The library has no JSON answers of its own: every listing — the week's
/// picks, a stand's clips, a search — is one HTML page the station renders
/// whole, and the pool it shows is the pool there is. There is no paging:
/// the station itself carries none, its URLs ignore a page number, and the
/// plays a visitor scrolls are the plays that exist. Each clip's `vid` is
/// the video site's own, so playback rides the video site's detail answer
/// ([HuyaVideoApi.detail]) and its player unchanged.
final class HuyaMaterialApi {
  /// Builds the client over the shared proxied transport.
  new(this.http);

  /// The shared transport; this wrapper does not close it.
  final LiveHttp http;

  /// Asks as the same desktop browser the video site's pages ask as.
  Map<String, String> get _headers => HuyaVideoApi.pageHeaders;

  /// The week's picks, the library's landing page.
  Future<List<HuyaVideo>> hot() async => _items(await _text(Uri.https('www.huya.com', '/material')));

  /// The stands, in the library's own order.
  Future<List<HuyaMaterialChannel>> channels() async {
    final html = await _text(Uri.https('www.huya.com', '/material/channel/list'));
    final matches = RegExp('title="([^"]{1,24})" href="[^"]*/material/channel/index/([A-Za-z0-9_-]{1,32})"')
        .allMatches(html);
    final seen = <String>{};
    return [
      for (final match in matches)
        if (seen.add(match.group(2)!))
          HuyaMaterialChannel(id: match.group(2)!, label: HuyaSsr.entities(match.group(1)!)),
    ];
  }

  /// One stand's clips.
  Future<List<HuyaVideo>> channel(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(id)) {
      throw const VodFailure('the library keeps no such stand');
    }
    return _items(await _text(Uri.https('www.huya.com', '/material/channel/index/$id')));
  }

  /// The clips a word matches, the library's own search.
  Future<List<HuyaVideo>> search(String word) async {
    final query = word.trim();
    if (query.isEmpty || query.length > 40) {
      throw const VodFailure('the library asks for a word to search');
    }
    return _items(await _text(Uri.https('www.huya.com', '/material/search', {'w': query})));
  }

  Future<String> _text(Uri url) async {
    final response = await http.send(LiveRequest.get(url, headers: _headers, site: 'huya'));
    if (response.statusCode == 404) {
      throw const VodFailure('the library keeps no such page');
    }
    if (response.statusCode == 401) {
      throw const VodFailure('the library asks a login for this page');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const VodFailure('the library refused the request');
    }
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    return response.text;
  }

  /// The clips one rendered page carries, in the page's own order. The card
  /// is the library's only row shape — a play link, a lazy cover, a length,
  /// a name and the uploader the clip came from — and a page holds fifty or
  /// fewer of them.
  List<HuyaVideo> _items(String html) {
    final cards = html.split('<li class="video-card-wrap">');
    final idSet = <String>{};
    final videos = <HuyaVideo>[];
    for (final card in cards.skip(1)) {
      final vid = RegExp('material/play/([1-9][0-9]{0,18})').firstMatch(card)?.group(1);
      if (vid == null || !idSet.add(vid)) continue;
      final cover = RegExp('data-original="([^"]+)"').firstMatch(card)?.group(1) ?? '';
      final length = RegExp('tag bottom-right">([0-9:]{2,8})</span>').firstMatch(card)?.group(1) ?? '';
      final title = RegExp('<h3>([^<]{1,120})</h3>').firstMatch(card)?.group(1) ?? '';
      final uploader = RegExp(r'profile/index/([1-9][0-9]{0,18})"[^>]*>\s*<i class="[^"]*"></i>([^<]{1,40})</a>')
          .firstMatch(card);
      videos.add(
        HuyaVideo(
          id: vid,
          title: HuyaSsr.entities(title).trim(),
          cover: cover,
          duration: _stamp(length),
          uploaderId: uploader?.group(1) ?? '',
          uploaderName: uploader == null ? '' : HuyaSsr.entities(uploader.group(2)!).trim(),
          channelId: RegExp('type=([A-Za-z0-9_-]{1,32})').firstMatch(card)?.group(1) ?? '',
        ),
      );
    }
    return videos;
  }

  /// The card's own `mm:ss` as a duration; a stamp it did not carry reads as
  /// unknown rather than zero.
  Duration _stamp(String text) {
    final parts = text.split(':');
    final seconds = int.tryParse(parts.last) ?? 0;
    final minutes = parts.length > 1 ? int.tryParse(parts[parts.length - 2]) ?? 0 : 0;
    final hours = parts.length > 2 ? int.tryParse(parts[parts.length - 3]) ?? 0 : 0;
    if (seconds == 0 && minutes == 0 && hours == 0) return Duration.zero;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}
