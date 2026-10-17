import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A page above the current one, for the Windows style's breadcrumb title
/// ("System › Display"). Internal.
@immutable
class SettingsPageTrailEntry {
  const SettingsPageTrailEntry({required this.title, required this.route});

  /// The page's header title.
  final Widget title;

  /// The page's route: popping to it goes back to the page. Null when the
  /// page has none.
  final Route<dynamic>? route;

  @override
  bool operator ==(Object other) =>
      other is SettingsPageTrailEntry &&
      other.title == title &&
      other.route == route;

  @override
  int get hashCode => Object.hash(title, route);
}

/// Put above the body of a destination page: the pages from the first one
/// opened to this one, so a page pushed from a tile in the body knows the
/// pages above it. Internal.
class SettingsPageTrail extends InheritedWidget {
  const SettingsPageTrail({
    super.key,
    required this.entries,
    required super.child,
  });

  final List<SettingsPageTrailEntry> entries;

  /// The trail at [context], without depending on it (read when a tile
  /// opens a page).
  static List<SettingsPageTrailEntry> entriesOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsPageTrail>()?.entries ??
      const <SettingsPageTrailEntry>[];

  @override
  bool updateShouldNotify(SettingsPageTrail oldWidget) =>
      !listEquals(entries, oldWidget.entries);
}

/// Goes back to the page of [entry] from a page at [context]: pops the
/// routes above it. Does nothing when the page is gone.
void popToSettingsPage(BuildContext context, SettingsPageTrailEntry entry) {
  final route = entry.route;
  if (route == null || !route.isActive) return;
  Navigator.of(context).popUntil((candidate) => candidate == route);
}
