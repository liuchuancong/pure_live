import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show PlatformDeviceIdentityService;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Liquid glass (the reference's `liquidGlass`, A01.5): off by default, on
/// the phone shell's bottom bar floats over the page as a frosted capsule
/// and the page scrolls visibly under it. Desktop keeps its rail, unchanged.
final class LiquidGlassController extends Notifier<bool> {
  static const String _key = 'theme.liquidGlass';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  /// Stores the choice; the mobile shell rebuilds its bar at once.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The liquid-glass preference.
final liquidGlassProvider = NotifierProvider<LiquidGlassController, bool>(LiquidGlassController.new);

/// Android phones at or under this much RAM skip the blur (A01.5 c4): a
/// blur redrawn on every scroll frame costs them more than it is worth.
/// Four GiB, as the reference's `largeImageBudgetAbove`; a "4 GB" phone
/// reads a little under it, so it stays out of the blur range.
const int kLiquidGlassBlurMinMemoryMegabytes = 4 * 1024;

/// Whether the glass frosts what is behind it: never on an Android device
/// reporting 4 GiB or less, or nothing at all — unknown memory takes the
/// plain tint, as the reference does.
bool liquidGlassBlurs({required bool android, int? memoryMegabytes}) =>
    !android || (memoryMegabytes != null && memoryMegabytes > kLiquidGlassBlurMinMemoryMegabytes);

/// The device's physical memory for the blur decision; null where the
/// platform reports none or the read fails.
final deviceMemoryMegabytesProvider = FutureProvider<int?>((ref) async {
  try {
    final identity = await const PlatformDeviceIdentityService().read();
    return identity.memoryMegabytes;
  } on Object {
    return null;
  }
});
