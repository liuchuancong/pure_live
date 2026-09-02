import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';

void main() {
  group('CC category migration fallback', () {
    test('keeps stable top-level tabs when legacy endpoint returns HTML', () {
      final categories = CCSite.parseCategoryPayload('<!DOCTYPE html><html></html>');

      expect(categories.map((category) => category.id), ['1', '2', '4', '5']);
      expect(categories.map((category) => category.children), everyElement(isEmpty));
    });

    test('hydrates legacy game groups when JSON remains available', () {
      final categories = CCSite.parseCategoryPayload('''
        {
          "game_list": [
            {"gametype": 11, "gamename": "PC", "game_tag": "pc_game", "img": "pc.png"},
            {"gametype": 22, "gamename": "Mobile", "game_tag": "mobile_game", "img": "mobile.png"},
            {"gametype": 33, "gamename": "Other", "game_tag": "other", "img": "other.png"}
          ]
        }
      ''');

      expect(categories[0].children.length, 3);
      expect(categories[1].children.single.areaId, '11');
      expect(categories[2].children.single.areaId, '22');
      expect(categories[3].children.single.areaId, '33');
    });
  });
}
