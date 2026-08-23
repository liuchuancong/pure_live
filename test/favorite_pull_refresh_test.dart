import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/favorite/room_grid_view.dart';

void main() {
  test('favorite platform page owns a working pull-to-refresh callback', () async {
    var refreshCount = 0;

    final widget = buildFavoritePullToRefresh(
      siteId: 'bilibili',
      onRefresh: () async => refreshCount++,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 900)]),
    );

    expect(widget, isA<EasyRefresh>());
    final refresh = widget as EasyRefresh;
    expect(refresh.key, const ValueKey('favorite_pull_to_refresh_bilibili'));
    expect(refresh.onRefresh, isNotNull);

    await refresh.onRefresh!.call();
    expect(refreshCount, 1);
  });
}
