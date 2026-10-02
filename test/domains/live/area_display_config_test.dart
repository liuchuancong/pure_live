import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/presentation/areas/area_display_config.dart';

LiveArea _area(String id) => LiveArea(areaId: id, areaName: id, platform: 'test');

LiveCategory _category(String id, int childCount) => LiveCategory(
  id: id,
  name: id,
  children: List<LiveArea>.generate(childCount, (index) => _area('$id-$index')),
);

void main() {
  group('area display config', () {
    test('a listed site renders flat whatever it returns', () {
      expect(shouldFlattenCategories(Sites.douyinSite, <LiveCategory>[_category('a', 2), _category('b', 2)]), isTrue);
    });

    test('a single top-level category flattens by itself', () {
      expect(shouldFlattenCategories(Sites.bilibiliSite, <LiveCategory>[_category('a', 3)]), isTrue);
      expect(shouldFlattenCategories(Sites.bilibiliSite, const <LiveCategory>[]), isTrue);
    });

    test('a site with several groups keeps its tabs', () {
      final List<LiveCategory> categories = <LiveCategory>[_category('a', 2), _category('b', 2), _category('c', 2)];
      expect(shouldFlattenCategories(Sites.bilibiliSite, categories), isFalse);
    });

    test('flattening expands the groups without reordering', () {
      final List<LiveArea> flattened = flattenCategories(<LiveCategory>[_category('a', 2), _category('b', 3)]);
      expect(flattened.map((area) => area.areaId).toList(), <String>['a-0', 'a-1', 'b-0', 'b-1', 'b-2']);
    });

    test('site ids match case- and space-insensitively', () {
      expect(isFlatAreaSite(' Douyin '), isTrue);
      expect(isFlatAreaSite(Sites.bilibiliSite), isFalse);
    });
  });
}
