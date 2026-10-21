import 'package:flutter/widgets.dart';

/// The root navigator's key.
///
/// One place, because two consumers on different sides of the widget tree
/// need the same navigator: the material app installs it, and the desktop
/// shell — which lives *outside* the tree, in the process's window lifecycle
/// code — reaches through it to show the close prompt. A provider cannot
/// serve the second consumer: it is constructed before `runApp` and has no
/// `Ref` to read.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'appNavigatorKey');
