import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// One named category of the mobile catalog: its id (`cate_type`), its name
/// and the areas under it.
typedef CcCategoryType = ({String id, String name});

/// Pure parsing of the NetEase CC catalog (9-4): the mobile site's
/// categories and areas, and 3.x's official rooms and events beside them.
abstract final class CcCatalogParser {
  /// `wapcc/gamecategory?catetype=0`: the top-level categories (`cate_list`)
  /// in the server's order, without 全部 (`cate_type` 0), as the mobile site
  /// shows them. `code` other than 0 is api-changed; a row without a
  /// positive `cate_type` or a name is skipped.
  static List<CcCategoryType> categoryTypes(String body, {int status = 200}) {
    final info = _categoryInfo(body, status: status, what: 'gamecategory');
    final seen = <String>{};
    return [
      for (final raw in CcJson.list(info['cate_list']))
        if (CcJson.object(raw) case final row?)
          if ((CcJson.integer(row['cate_type']), CcJson.catalogName(row['name'])) case (final type?, final name)
              when type > 0 && name.isNotEmpty && seen.add('$type'))
            (id: '$type', name: name),
    ];
  }

  /// `wapcc/gamecategory?catetype={id}`: the areas (`game_list`) of the
  /// category [id] named [name], in the server's order, grouped under it.
  /// The area id is the `gametype` the area rooms are listed by; the picture
  /// is `cover`. A row without a game type or a name is skipped, a repeated
  /// game type listed once.
  static List<LiveArea> categoryAreas(String body, {required String id, required String name, int status = 200}) {
    final info = _categoryInfo(body, status: status, what: 'gamecategory');
    final seen = <String>{};
    final areas = <LiveArea>[];
    for (final raw in CcJson.list(info['game_list'])) {
      final row = CcJson.object(raw);
      if (row == null) continue;
      final gametype = CcJson.string(row['gametype']) ?? '';
      final areaName = CcJson.catalogName(row['name']);
      if (!CcEndpoints.areaIdPattern.hasMatch(gametype) || areaName.isEmpty || !seen.add(gametype)) continue;
      final pic = CcJson.image(row['cover']);
      areas.add(
        LiveArea.normalized(
          platform: ccSiteId,
          areaId: gametype,
          areaName: areaName,
          parentAreaId: id,
          parentAreaName: name,
          iconUrl: pic.isEmpty ? null : pic,
        ),
      );
    }
    return areas;
  }

  /// `data.category_info` of a `gamecategory` answer.
  static Map<String, dynamic> _categoryInfo(String body, {required int status, required String what}) {
    final root = CcJson.object(CcJson.decode(body, status: status, what: what));
    if (root == null || CcJson.integer(root['code']) != 0) {
      throw CcFailure(CcFailureKind.apiChanged, '$what: code ${root?['code']}');
    }
    final info = CcJson.object(CcJson.object(root['data'])?['category_info']);
    if (info == null) throw CcFailure(CcFailureKind.apiChanged, '$what: no category_info');
    return info;
  }

  /// 3.x's official rooms and events, kept beside the mobile catalog (9-4):
  /// the `/{ccid}/` entries of the Dashen live configuration's "直播入口列表"
  /// ([configBody]), named and pictured by the game registry ([gamesBody]).
  /// Its live-area entries (`/n/ds_category/…`) are left to the mobile
  /// catalog. A hidden configuration or group lists none; an entry that is
  /// hidden, unknown to the registry, repeated or leads anywhere else is
  /// skipped. An answer without the configuration is api-changed.
  static List<LiveArea> officialAreas(
    String gamesBody,
    String configBody, {
    int gamesStatus = 200,
    int configStatus = 200,
  }) {
    final games = _catalogEnvelope(gamesBody, status: gamesStatus, what: 'game registry');
    final config = _catalogEnvelope(configBody, status: configStatus, what: 'live configuration');
    final registry = <String, ({String name, String icon})>{};
    for (final raw in CcJson.list(games['result'])) {
      if (CcJson.object(raw) case final row?) {
        if ((_catalogText(row['appKey'], 64), _catalogText(row['name'], 200)) case (final key?, final name?)) {
          registry.putIfAbsent(key, () => (name: name, icon: _httpsImage(row['icon'])));
        }
      }
    }
    final root = CcJson.object(config['result']);
    if (root == null || root['id'] != CcEndpoints.catalogConfigurationId) {
      throw CcFailure(CcFailureKind.apiChanged, 'live configuration: id ${root?['id']}');
    }
    if (_hidden(root)) return const [];
    final groups = [
      for (final raw in CcJson.list(root['itemList']))
        if (CcJson.object(raw) case final group? when group['name'] == CcEndpoints.officialGroupName) group,
    ];
    if (groups.length != 1) {
      throw CcFailure(CcFailureKind.apiChanged, 'live configuration: ${groups.length} live entry groups');
    }
    if (_hidden(groups.single)) return const [];
    final identities = <String>{};
    return [
      for (final raw in CcJson.list(groups.single['itemList']))
        if (CcJson.object(raw) case final entry? when !_hidden(entry))
          if ((registry[_catalogText(entry['name'], 64)], _officialRoom(entry['content']))
              case (final game?, final ccid?) when identities.add(ccid))
            LiveArea.normalized(
              platform: ccSiteId,
              areaId: 'official:$ccid',
              areaName: game.name,
              parentAreaId: CcEndpoints.officialAreaType,
              parentAreaName: CcEndpoints.officialLabel,
              iconUrl: game.icon.isEmpty ? null : game.icon,
            ),
    ];
  }

  /// The ccid of an official entry's `https://cc.163.com/{ccid}/` link, or
  /// null for any other link.
  static String? _officialRoom(Object? content) {
    final url = Uri.tryParse(_catalogText(content, 2048) ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'cc.163.com' ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.hasFragment) {
      return null;
    }
    return RegExp(r'^/([1-9][0-9]{0,15})/$').firstMatch(url.path)?.group(1);
  }

  /// Whether [area] is one of the catalog's official rooms or events.
  static bool isOfficialEntry(LiveArea area) =>
      area.platform.trim().toLowerCase() == ccSiteId && area.areaId.trim().startsWith('official:');

  /// Where an official entry opens (3.x's `CCCatalog.officialEntryUri`),
  /// rebuilt from its id so a stored area can never point to another host;
  /// null for any other area.
  static Uri? officialEntryUri(LiveArea area) {
    if (!isOfficialEntry(area)) return null;
    final id = area.areaId.trim().substring('official:'.length);
    if (!CcEndpoints.ccidPattern.hasMatch(id)) return null;
    return CcEndpoints.roomPageUrl(id);
  }

  /// Whether [area] is a live area the area rooms can list: a numeric game
  /// type (0 included, "其他游戏" of the mobile catalog) of this platform, or
  /// of none (3.x's check). The official entries are not: they open on the
  /// website.
  static bool isListableArea(LiveArea area) {
    final platform = area.platform.trim().toLowerCase();
    return CcEndpoints.areaIdPattern.hasMatch(area.areaId.trim()) && (platform.isEmpty || platform == ccSiteId);
  }

  /// A `{code: 200, result: …}` Dashen envelope.
  static Map<String, dynamic> _catalogEnvelope(String body, {required int status, required String what}) {
    final envelope = CcJson.object(CcJson.decode(body, status: status, what: what));
    if (envelope == null || envelope['code'] != 200) {
      throw CcFailure(CcFailureKind.apiChanged, '$what: code ${envelope?['code']}');
    }
    return envelope;
  }

  static String? _catalogText(Object? value, int limit) =>
      value is String && value.trim().isNotEmpty && value.length <= limit ? value.trim() : null;

  /// Whether a Dashen configuration item is hidden; a `hidden` that is not
  /// a bool hides it too.
  static bool _hidden(Map<String, dynamic> value) {
    final hidden = value['hidden'];
    return hidden == true || (hidden != null && hidden is! bool);
  }

  /// An https image with a host and no user info, else empty (3.x's catalog
  /// rule).
  static String _httpsImage(Object? value) {
    if (value is! String || value.length > 2048) return '';
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty ? value : '';
  }
}
