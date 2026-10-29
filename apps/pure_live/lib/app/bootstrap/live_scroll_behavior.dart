import 'package:desen_ui/desen_ui.dart' show DsScrollBehavior;
import 'package:flutter/gestures.dart' show PointerDeviceKind;

/// The app's scrolling: Desen's platform feel, with every pointer able to
/// drag it. Flutter's default leaves the mouse out, so a desktop window only
/// answered its wheel and a press-and-drag over a list did nothing; a mouse
/// and a trackpad belong to the devices that scroll here.
final class LiveScrollBehavior extends DsScrollBehavior {
  /// Creates the behavior.
  const LiveScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.mouse,
  };
}
