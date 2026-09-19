import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';
import 'package:pure_live/common/widgets/room_card_layout.dart';

void main() {
  test('compact rows omit cover extent while cover cards retain it', () {
    final compactNarrow = RoomCardLayoutMetrics.gridMainAxisExtent(
      itemWidth: 160,
      appearance: RoomCardAppearance.compact,
      dense: true,
    );
    final compactWide = RoomCardLayoutMetrics.gridMainAxisExtent(
      itemWidth: 420,
      appearance: RoomCardAppearance.compact,
      dense: true,
    );
    final cover = RoomCardLayoutMetrics.gridMainAxisExtent(
      itemWidth: 420,
      appearance: RoomCardAppearance.standard,
      dense: true,
    );

    expect(compactNarrow, 56);
    expect(compactWide, compactNarrow);
    expect(cover, 420 * 9 / 16 + 72);
    expect(cover, greaterThan(compactWide * 4));
  });

  test('compact row height follows accessibility text scaling', () {
    final normal = RoomCardLayoutMetrics.compactHeight(appearance: RoomCardAppearance.compact, dense: true);
    final enlarged = RoomCardLayoutMetrics.compactHeight(
      appearance: RoomCardAppearance.compact,
      dense: true,
      textScaler: const TextScaler.linear(3),
    );

    expect(enlarged, greaterThan(normal));
    expect(enlarged, greaterThanOrEqualTo(100));

    final withAction = RoomCardLayoutMetrics.compactHeight(
      appearance: RoomCardAppearance.compact,
      dense: true,
      hasAction: true,
    );
    expect(withAction, 64);
  });
}
