import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/shield/room_shield_count.dart';

void main() {
  test('the shield counts every line it hid', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(roomShieldCountProvider.notifier)
      ..add()
      ..add();

    expect(container.read(roomShieldCountProvider), 2);
  });

  test('a new room starts the count again', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(roomShieldCountProvider.notifier)
      ..add()
      ..reset()
      ..add();

    expect(container.read(roomShieldCountProvider), 1);
  });
}
