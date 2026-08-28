import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class _CategoryFixtureSite extends LiveSite {
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    return [
      LiveCategory(
        id: 'games',
        name: 'Games',
        children: [
          LiveArea(areaId: 'g1'),
          LiveArea(areaId: 'g2'),
        ],
      ),
      LiveCategory(
        id: 'music',
        name: 'Music',
        children: [LiveArea(areaId: 'm1')],
      ),
    ];
  }
}

void main() {
  test('area category selection publishes the local slice synchronously', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final controller = AreasListController(
      Site(id: 'fixture', name: 'Fixture', logo: '', liveSite: _CategoryFixtureSite()),
    );
    addTearDown(controller.onClose);

    await controller.fetchAllServerData();
    controller.processLocalPaging();
    expect(controller.list.map((area) => area.areaId), ['g1', 'g2']);

    controller.selectCategory(1);

    expect(controller.tabIndex.value, 1);
    expect(controller.currentPage, 1);
    expect(controller.list.map((area) => area.areaId), ['m1']);
    expect(controller.loadding.value, isFalse);
  });
}
