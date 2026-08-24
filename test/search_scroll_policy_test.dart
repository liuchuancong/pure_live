import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_physics.dart';
import 'package:pure_live/modules/search/search_page.dart';

void main() {
  test('search platform tabs stay start-aligned with clamped boundaries', () {
    expect(searchPlatformTabAlignment, TabAlignment.start);
    expect(searchPlatformTabPhysics, isA<ClampingScrollPhysics>());
  });

  test('search results rebound on touch platforms and retain desktop policy', () {
    expect(resolveSearchResultScrollPhysics(TargetPlatform.android), isA<BouncingScrollPhysics>());
    expect(resolveSearchResultScrollPhysics(TargetPlatform.iOS), isA<BouncingScrollPhysics>());
    expect(resolveSearchResultScrollPhysics(TargetPlatform.windows), isA<PureLiveScrollPhysics>());
    expect(resolveSearchResultScrollPhysics(TargetPlatform.linux), isA<PureLiveScrollPhysics>());
  });
}
