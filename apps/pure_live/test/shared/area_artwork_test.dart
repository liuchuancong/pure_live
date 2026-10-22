// The area-picture rules, pinned: a catalogue teaches its artwork, an area
// without one borrows by name (exact, then the closest containing name), and
// a two-state sprite icon is never lent and shows its coloured half.
import 'package:flutter/widgets.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:pure_live/shared/areas/area_artwork.dart';

LiveArea _area(String name, {String? icon}) => LiveArea(areaId: name, areaName: name, iconUrl: icon);

void main() {
  test('a two-state icon shows the half that carries its colour', () {
    expect(areaArtworkAlignment('https://static.maoercdn.com/live/catalog/icon/104-web.png'), Alignment.topCenter);
    expect(areaArtworkAlignment('https://static.maoercdn.com/live/catalog/icon/104.png'), Alignment.bottomCenter);
    expect(areaArtworkAlignment('https://example.com/cat.png'), Alignment.center);
    expect(areaArtworkAlignment(null), Alignment.center);
  });

  test('a catalogue teaches its own artwork', () {
    final pictures = AreaPictures()..remember([_area('单机', icon: 'https://a/1.png')]);
    expect(pictures.pictureFor(_area('单机')), 'https://a/1.png');
  });

  test('an area without artwork borrows the same name', () {
    final pictures = AreaPictures()..remember([_area('英雄联盟', icon: 'https://a/lol.png')]);
    expect(pictures.pictureFor(_area('英雄联盟 ')), 'https://a/lol.png');
  });

  test('a containing name borrows too, the closest one winning', () {
    final pictures = AreaPictures()
      ..remember([_area('英雄联盟赛事', icon: 'https://a/events.png'), _area('英雄联盟', icon: 'https://a/lol.png')]);
    expect(pictures.pictureFor(_area('英雄联盟')), 'https://a/lol.png');
    // Only the containing name matches here — S赛 and 赛事 are different
    // strings, so the shorter 「英雄联盟」 is the one that lends.
    expect(pictures.pictureFor(_area('英雄联盟S赛')), 'https://a/lol.png');
    final events = AreaPictures()..remember([_area('英雄联盟赛事', icon: 'https://a/events.png')]);
    expect(events.pictureFor(_area('英雄联盟赛事回顾')), 'https://a/events.png');
  });

  test('a two-state icon is not taught', () {
    final pictures = AreaPictures()
      ..remember([_area('单机', icon: 'https://static.maoercdn.com/live/catalog/icon/105.png')]);
    expect(pictures.pictureFor(_area('单机')), isNull);
  });

  test('the area keeps its own picture over a borrowed one', () {
    final pictures = AreaPictures()..remember([_area('单机', icon: 'https://a/1.png')]);
    expect(pictures.pictureFor(_area('单机', icon: 'https://mine/2.png')), 'https://mine/2.png');
  });
}
