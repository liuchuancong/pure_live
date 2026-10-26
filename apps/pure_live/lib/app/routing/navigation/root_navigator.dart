import 'package:flutter/widgets.dart';

/// The app's root navigator.
///
/// The desktop shell asks the viewer before closing the main window, but that
/// question reaches the app from outside the widget tree (the bootstrap's
/// close policy), so it needs a way back to the navigator's theme and
/// translations.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
