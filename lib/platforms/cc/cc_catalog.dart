import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/model/live_category.dart';

/// The public game registry supplies artwork/names, not live categories.
/// Only entries selected by the official live configuration are navigable.
class CCCatalog {
  static const configurationId = '67b32cdd1801fc391a6c2657';
  static final _numericId = RegExp(r'^[1-9][0-9]{0,15}$');

  static bool isOfficialEntry(LiveArea area) =>
      area.platform?.trim().toLowerCase() == 'cc' && (area.areaId?.startsWith('official:') ?? false);

  /// Reconstruct an official destination from a bounded identity. Saved
  /// categories never contain a URL that could point to another host/scheme.
  static Uri? officialEntryUri(LiveArea area) {
    if (!isOfficialEntry(area)) return null;
    final id = area.areaId!.substring('official:'.length);
    if (!_numericId.hasMatch(id)) return null;
    return Uri.https('cc.163.com', '/$id/', {'open': 'blizzardtv', 'from': '8382', 'platform': 'ds'});
  }

  static List<LiveCategory> parse(
    Object? gamePayload,
    Object? configPayload, {
    String categoryLabel = '直播分类',
    String officialLabel = '官方房间/专题',
  }) {
    final gameRows = _list(_envelope(gamePayload)['result'], 2000);
    final metadata = <String, Map>{};
    for (final raw in gameRows) {
      final row = _map(raw);
      final key = _text(row['appKey'], 64);
      if (metadata.containsKey(key)) throw const FormatException('Duplicate CC game key');
      metadata[key] = row;
    }
    final config = _map(_envelope(configPayload)['result']);
    if (config['id'] != configurationId) throw const FormatException('Mismatched CC configuration');
    if (_hidden(config)) return [];
    final groups = _list(config['itemList'], 256).map(_map).where((row) => row['name'] == '直播入口列表').toList();
    if (groups.length != 1) throw const FormatException('Missing or ambiguous CC live entry group');
    if (_hidden(groups.single)) return [];

    final categories = <LiveArea>[];
    final official = <LiveArea>[];
    final identities = <String>{};
    for (final raw in _list(groups.single['itemList'], 256)) {
      final entry = _map(raw);
      if (_hidden(entry)) continue;
      final key = _text(entry['name'], 64);
      final game = metadata[key];
      if (game == null) throw const FormatException('CC live entry has no matching game');
      final url = Uri.tryParse(_text(entry['content'], 2048));
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'cc.163.com' ||
          url.userInfo.isNotEmpty ||
          url.hasPort ||
          url.hasFragment) {
        throw const FormatException('Invalid CC live entry destination');
      }
      final category = RegExp(r'^/n/ds_category/([1-9][0-9]{0,15})/$').firstMatch(url.path);
      final room = RegExp(r'^/([1-9][0-9]{0,15})/$').firstMatch(url.path);
      if (category == null && room == null) throw const FormatException('Unknown CC live entry route');
      final id = category != null ? category.group(1)! : 'official:${room!.group(1)}';
      if (!identities.add(id)) throw const FormatException('Duplicate CC live entry identity');
      final parent = category != null ? '1' : 'official';
      final label = category != null ? categoryLabel : officialLabel;
      final area = LiveArea(
        platform: 'cc',
        areaId: id,
        areaType: parent,
        typeName: label,
        areaName: _text(game['name'], 200),
        areaPic: _image(game['icon']),
      );
      (category != null ? categories : official).add(area);
    }
    return [
      if (categories.isNotEmpty) LiveCategory(id: '1', name: categoryLabel, children: categories),
      if (official.isNotEmpty) LiveCategory(id: 'official', name: officialLabel, children: official),
    ];
  }

  static Map _envelope(Object? value) {
    final envelope = _map(value);
    if (envelope['code'] != 200) throw const FormatException('CC catalogue request was not successful');
    return envelope;
  }

  static Map _map(Object? value) {
    if (value is! Map) throw const FormatException('Invalid CC catalogue object');
    return value;
  }

  static List _list(Object? value, int limit) {
    if (value is! List || value.length > limit) throw const FormatException('Invalid CC catalogue list');
    return value;
  }

  static String _text(Object? value, int limit) {
    if (value is! String || value.trim().isEmpty || value.length > limit) {
      throw const FormatException('Invalid CC catalogue text');
    }
    return value.trim();
  }

  static bool _hidden(Map value) {
    final hidden = value['hidden'];
    if (hidden != null && hidden is! bool) throw const FormatException('Invalid CC visibility');
    return hidden == true;
  }

  static String _image(Object? value) {
    if (value is! String || value.length > 2048) return '';
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty ? value : '';
  }
}
