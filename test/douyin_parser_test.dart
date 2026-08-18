import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyin_site.dart';

void main() {
  test('extracts escaped categoryData from the Douyin page payload', () {
    const source =
        r'prefix {\"pathname\":\"/\",\"categoryData\":[{\"partition\":{\"id_str\":\"1\",\"title\":\"热门\"},\"sub_partition\":[]}]} suffix';

    final extracted = DouyinSite().extractCategoryDataJson(source);
    final decoded = jsonDecode(extracted) as Map<String, dynamic>;

    expect(decoded['pathname'], '/');
    expect(decoded['categoryData'], isA<List<dynamic>>());
  });
}
