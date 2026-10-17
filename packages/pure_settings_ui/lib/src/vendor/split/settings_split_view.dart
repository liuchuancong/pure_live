import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/list/settings_list.dart';
import 'package:pure_settings_ui/src/vendor/sections/abstract_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/custom_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_split.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination_page.dart';
import 'package:pure_settings_ui/src/vendor/split/split_geometry.dart';
import 'package:pure_settings_ui/src/vendor/split/split_pane_style.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

part 'settings_split_controller.dart';
part 'split_view_focus.dart';
part 'split_view_panes.dart';
part 'split_view_routes.dart';

/// A settings screen that shows the list and the selected page side by side
/// when there is room (iPad, tablets, unfolded foldables, desktop and web),
/// and the list with pages pushed over it otherwise.
///
/// Give tiles a [SettingsDestination] (`SettingsTile.navigation(destination:
/// ...)`); tapping one shows its page. With two panes the tile stays
/// highlighted and pages opened from inside the page push inside the detail
/// pane, like iPad Settings.
///
/// The per-style defaults follow the platform apps:
///
/// | Style | Two panes when | List pane |
/// |---|---|---|
/// | iOS | width >= 600 and shortest side >= 600 (any shortest side on desktop) | 320pt sidebar |
/// | Android, Fuchsia | width >= 720 and shortest side >= 600, like AOSP Settings | 36.36% of the width |
/// | Web | width > 980, like Chrome | 266px menu |
/// | macOS | width >= 560 | 232pt System Settings sidebar |
/// | Windows | width >= 641 | 300px navigation pane from 1008, a 48px icon rail below |
/// | GNOME | width > 550 (scaled by the text size) | a quarter of the width, 180–280 |
///
/// The desktop styles draw their list pane like their platforms' settings
/// apps:
///
/// - macOS: a full-height sidebar with 32pt rows, a rounded selection in the
///   accent color (grey while the window is inactive) and small bold section
///   headers. The detail pane has a 52pt toolbar with the page title and,
///   when there is a page to go back to, the back and forward buttons.
/// - Windows: a `NavigationView` pane with a sliding accent pill on the
///   selected item. Between 641 and 1007 the pane is an icon rail with
///   tooltips; its menu button opens the full pane over the page. The page
///   title is large, and pages opened from a page show a breadcrumb.
/// - GNOME: an `AdwNavigationSplitView` sidebar with rounded rows and its
///   own header bar. The detail pane has a flat header bar with a centered
///   title, and a back button when collapsed or on a nested page. With one
///   pane no row stays selected.
///
/// In the three desktop styles the arrow keys move between the sidebar's
/// rows, Enter or Space opens one (macOS opens the row as the focus moves,
/// like its sidebars), and Tab moves between the panes.
///
/// A separating hinge (a hinge, or a fold in the book posture) always gets a
/// pane on each side of it. The panes follow the text direction.
///
/// Use it as a whole screen: it draws the headers of both panes, so don't
/// put it under an app bar.
///
/// With two panes, a tile that pushes a route itself (for example
/// `onPressed: (context) => Navigator.of(context).push(...)`) pushes it on
/// the app's navigator. With one pane the list sits in the view's own
/// navigator, so the route goes there: back closes it first, named routes
/// come from the app's navigator, and the view keeps one pane until the
/// route has closed, even if the window widens meanwhile (the route covers
/// the view either way). Menus and bottom sheets opened from the list work
/// the same way.
///
/// When the tile of the page the user picked goes away (a conditional page
/// such as Developer options), the page closes: two panes go back to the
/// [initialDestinationId] page, one pane to the list, and the page doesn't
/// come back by itself with its tile. The view reads the tiles of each
/// [SettingsSection] ahead; a tile inside a [CustomSettingsSection] is only
/// known once it has built, so its page stays open when it goes away. Call
/// [SettingsSplitController.clearSelection] when you remove such a tile.
///
/// ```dart
/// SettingsSplitView(
///   title: const Text('Settings'),
///   sections: [
///     SettingsSection(tiles: [
///       SettingsTile.navigation(
///         leading: const Icon(Icons.wifi),
///         title: const Text('Network & internet'),
///         destination: SettingsDestination(
///           id: 'network',
///           builder: (context) => SettingsList(sections: [...]),
///         ),
///       ),
///     ]),
///   ],
/// )
/// ```
class SettingsSplitView extends StatefulWidget {
  const SettingsSplitView({
    super.key,
    required this.sections,
    this.title,
    this.initialDestinationId,
    this.emptyDetailBuilder,
    this.controller,
    this.onDestinationChanged,
    this.layout = SettingsSplitLayout.auto,
    this.breakpoint,
    this.listPaneWidth,
    this.restorationId,
    this.platform,
    this.lightTheme,
    this.darkTheme,
    this.brightness,
    this.applicationType = ApplicationType.material,
  });

  /// The sections of the list pane, as in [SettingsList.sections].
  final List<AbstractSettingsSection> sections;

  /// The list pane's title, e.g. `Text('Settings')`.
  final Widget? title;

  /// The destination shown in the detail pane until the user picks one.
  ///
  /// Defaults to the first destination in [sections], so the detail pane is
  /// never empty (iPad, Android and Chrome all open on a page), unless
  /// [emptyDetailBuilder] is set. The page only fills an empty detail pane:
  /// when the window narrows to one pane, the list shows, not this page.
  final String? initialDestinationId;

  /// Builds the detail pane when no destination is shown there.
  final WidgetBuilder? emptyDetailBuilder;

  /// Reads and changes the shown page. See [SettingsSplitView.of].
  final SettingsSplitController? controller;

  /// Called after the shown destination changes, with its id, or null when
  /// none is shown. Changing the layout can change it too: one pane shows the
  /// list instead of the [initialDestinationId] page. Use it to keep a URL in
  /// sync; the package doesn't touch the app's router.
  final ValueChanged<String?>? onDestinationChanged;

  /// One pane, two panes, or decide by the width.
  final SettingsSplitLayout layout;

  /// With [SettingsSplitLayout.auto], the width from which two panes show,
  /// replacing the style's rule (which also checks the screen's shortest
  /// side on phones and tablets).
  final double? breakpoint;

  /// Width of the list pane with two panes. Defaults to the style's (see the
  /// table above). The detail pane always gets at least half the width.
  ///
  /// In the Windows style it sets the open pane only: the icon rail below
  /// 1008 stays 48 wide, and its menu button opens a pane this wide (320 by
  /// default, WinUI's) over the page.
  final double? listPaneWidth;

  /// Restores the shown page, and the state of the pages that support
  /// restoration, after the app is killed. Pages pushed inside a page are
  /// not restored.
  final String? restorationId;

  /// As in [SettingsList.platform].
  final DevicePlatform? platform;

  /// As in [SettingsList.lightTheme].
  final SettingsThemeData? lightTheme;

  /// As in [SettingsList.darkTheme].
  final SettingsThemeData? darkTheme;

  /// As in [SettingsList.brightness].
  final Brightness? brightness;

  /// As in [SettingsList.applicationType].
  final ApplicationType applicationType;

  /// The controller of the [SettingsSplitView] around [context], if any.
  ///
  /// Code in a page uses it to jump to another page:
  /// `SettingsSplitView.maybeOf(context)?.select('display')`.
  static SettingsSplitController? maybeOf(BuildContext context) =>
      SettingsSplitScope.maybeOf(context)?.controller;

  /// Like [maybeOf], for code that is always inside a [SettingsSplitView].
  static SettingsSplitController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No SettingsSplitView found in the context.');
    return controller!;
  }

  @override
  State<SettingsSplitView> createState() => _SettingsSplitViewState();
}

/// A destination found among the list pane's tiles.
class _Entry {
  const _Entry(this.destination, this.title);

  final SettingsDestination destination;

  /// The header title: the destination's, or the tile's.
  final Widget title;
}

class _SettingsSplitViewState extends State<SettingsSplitView>
    with RestorationMixin {
  SettingsSplitController? _ownController;
  SettingsSplitController get _controller =>
      widget.controller ?? (_ownController ??= SettingsSplitController());

  // The destinations and the pick.

  /// The destination the user picked (a tap or [SettingsSplitController]).
  /// Null means none: two panes show the initial destination, one pane shows
  /// the list.
  final RestorableStringN _picked = RestorableStringN(null);

  /// Top-level destinations from [SettingsSplitView.sections], in order.
  Map<String, _Entry> _destinations = const {};

  /// Destinations of tiles in custom sections, which can't be read ahead:
  /// the tiles report them as they build (and when tapped).
  final Map<String, _Entry> _tapped = {};
  bool _rebuildScheduled = false;

  // What the last layout showed.
  bool _laidOut = false;
  bool _isSplit = false;
  String? _shownId;

  /// What the listeners last heard was shown. Null until the first layout
  /// is reported, which is not a change of destination.
  ({String? id, bool isSplit})? _notified;
  bool _notifyScheduled = false;

  /// The view's place in the window, measured after a frame when a display
  /// feature may cut a view that doesn't span the window (see [_findHinge]).
  Offset _measuredOrigin = Offset.zero;
  bool _originCheckScheduled = false;

  // The two navigators.
  //
  // The detail navigator shows the page and what is pushed inside it. With
  // two panes it sits next to the list. With one pane a second navigator,
  // the stack, holds the list and, over it, the page that hosts the detail
  // navigator ([_hostPage]); a route that a list tile pushes itself lands
  // on the stack too. The fields below are what the view knows about the
  // two, kept up to date by the observers and the navigators' notifications
  // (see "What the navigators report"), and what back handling reads (see
  // "Back").
  final GlobalKey<NavigatorState> _detailKey = GlobalKey<NavigatorState>(
    debugLabel: 'SettingsSplitView detail',
  );
  final GlobalKey<NavigatorState> _stackKey = GlobalKey<NavigatorState>(
    debugLabel: 'SettingsSplitView stack',
  );
  late final _DetailObserver _detailObserver = _DetailObserver(
    _handleDetailPush,
  );
  late final _StackObserver _stackObserver = _StackObserver(_syncStack);

  /// The page at the root of the detail navigator. One pane keeps the last
  /// page there while its route animates out.
  String? _detailRootId;

  /// Bumped when one pane pushes a page over the list; see [_DetailHost].
  int _hostGeneration = 0;

  /// Back belongs to the detail navigator: it has a page to pop, or its top
  /// page vetoes back.
  bool _detailCanPop = false;

  /// The list pane's back button was pressed: the view lets back through
  /// until the settings screen has closed, or refused to (see [_leave]).
  bool _leaving = false;

  /// One pane: the top route of the stack navigator was pushed from the
  /// list pane (a tile's own `Navigator.push`, a menu, a sheet), so back
  /// pops it first.
  bool _stackPagelessTop = false;

  /// One pane: routes pushed from the list pane are open (or animating
  /// out). The view keeps one pane until they are gone, so they don't
  /// vanish when the window widens.
  bool _holdOnePane = false;

  // The list pane.
  final GlobalKey _listKey = GlobalKey(debugLabel: 'SettingsSplitView list');

  /// Around the list pane, to hand it the keyboard focus.
  final FocusNode _listFocusNode = FocusNode(
    debugLabel: 'SettingsSplitView list',
    skipTraversal: true,
    canRequestFocus: false,
  );

  /// Tab and Shift+Tab between the panes.
  late final Map<Type, Action<Intent>> _paneFocusActions =
      <Type, Action<Intent>>{
        NextFocusIntent: _PaneFocusAction<NextFocusIntent>(this, true),
        PreviousFocusIntent: _PaneFocusAction<PreviousFocusIntent>(this, false),
      };

  /// Whether the iOS large title has scrolled under the bar.
  final ValueNotifier<bool> _largeTitleHidden = ValueNotifier<bool>(false);

  /// The style family of the last build. Another one draws a new list,
  /// which starts at the top.
  SettingsStyleFamily? _styleFamily;

  /// Whether the Windows style's compact rail is open over the detail pane.
  bool _fluentPaneOpen = false;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_picked, 'selected');
    if (initialRestore && _picked.value == null) {
      // A controller.select() before the view existed (a deep link).
      final pending = _controller._takePendingId();
      if (pending != null) _picked.value = pending;
    } else {
      _controller._takePendingId();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller._attach(this);
  }

  @override
  void didUpdateWidget(SettingsSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?._detach(this);
      _controller._attach(this);
      final pending = _controller._takePendingId();
      if (pending != null) _picked.value = pending;
    }
  }

  @override
  void dispose() {
    _controller._detach(this);
    _ownController?.dispose();
    _picked.dispose();
    _largeTitleHidden.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  // Destinations -----------------------------------------------------------

  /// Reads the destinations of the sections' tiles ahead for this build,
  /// and forgets the pick if its tile is gone.
  void _readDestinations() {
    final previous = _destinations;
    _destinations = _collectDestinations();
    final picked = _picked.value;
    if (picked != null &&
        previous.containsKey(picked) &&
        _lookup(picked) == null) {
      // The picked page's tile is gone (a conditional page): forget the
      // pick, so the page doesn't come back by itself with the tile. (A
      // restorable value; writing it doesn't call setState.)
      _picked.value = null;
    }
  }

  Map<String, _Entry> _collectDestinations() {
    final result = <String, _Entry>{};
    for (final section in widget.sections) {
      if (section is! SettingsSection) continue;
      for (final tile in section.tiles) {
        if (tile is! SettingsTile) continue;
        final destination = tile.destination;
        if (destination == null) continue;
        assert(
          !result.containsKey(destination.id),
          'SettingsSplitView: two tiles open a destination with the id '
          '"${destination.id}". Destination ids must be unique.',
        );
        result.putIfAbsent(
          destination.id,
          () => _Entry(destination, destination.title ?? tile.title),
        );
      }
    }
    return result;
  }

  _Entry? _lookup(String? id) =>
      id == null ? null : (_destinations[id] ?? _tapped[id]);

  /// The page two panes show when the user hasn't picked one.
  String? get _autoId {
    final initial = widget.initialDestinationId;
    if (initial != null) {
      assert(
        _lookup(initial) != null,
        'SettingsSplitView: initialDestinationId "$initial" matches no '
        'destination in the sections.',
      );
      return _lookup(initial) == null ? null : initial;
    }
    if (widget.emptyDetailBuilder != null) return null;
    return _destinations.keys.firstOrNull;
  }

  /// [_picked], if it still names a destination.
  String? get _pickedId =>
      _lookup(_picked.value) == null ? null : _picked.value;

  // Selection ----------------------------------------------------------------

  /// A tile in the list pane built with [destination]. Tiles in a
  /// [SettingsSection] are read ahead in [build]; for the others (custom
  /// sections), this keeps the page in step with the tile.
  void _handleTileBuilt(SettingsDestination destination, Widget tileTitle) {
    final id = destination.id;
    if (_destinations.containsKey(id)) return;
    final title = destination.title ?? tileTitle;
    final known = _tapped[id];
    if (known != null &&
        identical(known.destination, destination) &&
        identical(known.title, title)) {
      return;
    }
    _tapped[id] = _Entry(destination, title);
    // The tile builds during the list pane's build: show the new
    // destination on the next frame.
    if (id == _shownId || id == _picked.value) _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    }, debugLabel: 'SettingsSplitView.destinationChanged');
  }

  void _openFromTile(SettingsDestination destination, Widget tileTitle) {
    if (!_destinations.containsKey(destination.id)) {
      _tapped[destination.id] = _Entry(
        destination,
        destination.title ?? tileTitle,
      );
    }
    _select(destination.id);
  }

  void _select(String id) {
    assert(
      _lookup(id) != null,
      'SettingsSplitView: no destination with the id "$id". select() takes '
      'the id of a SettingsDestination given to a tile in the sections.',
    );
    if (_lookup(id) == null) return;
    final alreadyShown = _shownId == id;
    setState(() {
      if (_pickedId == null) _hostGeneration++;
      _picked.value = id;
      // Picking a page closes the Windows pane opened over it.
      _fluentPaneOpen = false;
    });
    if (alreadyShown) {
      // Tapping the open page again goes back to its first screen.
      _detailKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  void _clearSelection() {
    if (_picked.value == null) return;
    setState(() => _picked.value = null);
  }

  /// A page pushed inside the detail pane makes the initial page the user's
  /// pick, so folding the device keeps it open.
  void _handleDetailPush() {
    if (_picked.value == null && _shownId != null) {
      _picked.value = _shownId;
    }
  }

  // Back ---------------------------------------------------------------------
  //
  // The view's PopScope takes back while [_canHandleBack]. [_handleBack]
  // then does the first of three things that applies: pops a route pushed
  // from the list pane (one pane), pops a page pushed inside the detail
  // pane, or closes the page over the list (one pane). The route's own
  // PopScope can veto the first two.

  /// Whether the detail pane shows: always with two panes, over the list
  /// with one.
  bool get _detailVisible => _isSplit || _pickedId != null;

  /// Whether the list pane shows: not under a page in one pane.
  bool get _listShown => _isSplit || _pickedId == null;

  bool get _canHandleBack =>
      !_leaving &&
      ((!_isSplit && _stackPagelessTop) ||
          (_detailCanPop && _detailVisible) ||
          (!_isSplit && _pickedId != null));

  Future<void> _handleBack() async {
    final stack = _stackKey.currentState;
    if (!_isSplit && stack != null && _stackObserver.topIsPageless) {
      // A route pushed from the list pane: pops it, or lets it veto.
      await stack.maybePop();
      return;
    }
    final detail = _detailKey.currentState;
    if (detail != null && _detailVisible) {
      // Pops a page pushed inside the detail pane, or lets the page veto.
      if (await detail.maybePop()) return;
    }
    if (!mounted) return;
    if (!_isSplit && _pickedId != null) {
      _closeDetail();
    }
  }

  /// Closes the page shown over the list in one pane.
  void _closeDetail() {
    final stack = _stackKey.currentState;
    if (stack != null && stack.canPop()) {
      stack.pop();
    } else {
      _clearSelection();
    }
  }

  /// The list pane's back button leaves the settings screen, even when the
  /// detail pane could go back.
  void _leave() {
    setState(() => _leaving = true);
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.maybePop(context);
      if (mounted) setState(() => _leaving = false);
    });
  }

  // What the navigators report -----------------------------------------------

  /// Reads the routes pushed from the list pane in one pane.
  void _syncStack() {
    final pagelessTop = _stackObserver.topIsPageless;
    final hold = _stackObserver.hasPageless;
    if (!mounted ||
        (pagelessTop == _stackPagelessTop && hold == _holdOnePane)) {
      return;
    }
    setState(() {
      _stackPagelessTop = pagelessTop;
      _holdOnePane = hold;
    });
  }

  bool _handleStackNavigation(NavigationNotification notification) {
    _syncStack();
    // The split view's PopScope speaks for its navigators.
    return true;
  }

  /// The key of the page over the list, a new one for each page pushed.
  ValueKey<String> get _hostPageKey =>
      ValueKey<String>('settings_split_detail_$_hostGeneration');

  /// The stack navigator popped a page: with the page over the list, the
  /// pick goes too.
  void _handleStackPageRemoved(Page<Object?> page) {
    if (page.key == _hostPageKey) _clearSelection();
  }

  bool _handleDetailNavigation(NavigationNotification notification) {
    // Read the state from the navigator instead of the notification: routes
    // inside it can report "can't pop" while the navigator can, and on
    // Flutter 3.44 both reach this listener, alternately.
    final navigator = _detailKey.currentState;
    final top = _detailObserver.top;
    final canPop =
        navigator != null &&
        (navigator.canPop() ||
            top?.popDisposition == RoutePopDisposition.doNotPop);
    if (canPop != _detailCanPop && mounted) {
      setState(() => _detailCanPop = canPop);
    }
    // The split view's PopScope speaks for its navigators.
    return true;
  }

  // Named routes pushed from the list pane in one pane come from the app's
  // navigator, as they do with two panes (where the list pane isn't inside
  // the view's own navigator).
  Route<dynamic>? _generateStackRoute(RouteSettings settings) =>
      Navigator.maybeOf(context)?.widget.onGenerateRoute?.call(settings);

  Route<dynamic>? _unknownStackRoute(RouteSettings settings) =>
      Navigator.maybeOf(context)?.widget.onUnknownRoute?.call(settings);

  // Notifications ------------------------------------------------------------

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    if (_notified == (id: _shownId, isSplit: _isSplit)) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!mounted) return;
      final previous = _notified;
      _notified = (id: _shownId, isSplit: _isSplit);
      if (previous != null && previous.id != _shownId) {
        widget.onDestinationChanged?.call(_shownId);
      }
      _controller._notify();
    }, debugLabel: 'SettingsSplitView.notify');
  }

  // Build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final style = SettingsStyleConfig(
      platform: widget.platform,
      brightness: widget.brightness,
      lightTheme: widget.lightTheme,
      darkTheme: widget.darkTheme,
      applicationType: widget.applicationType,
    ).resolve(context);
    final family = settingsStyleFamily(style.platform);
    if (family != _styleFamily) {
      // The new style's list starts at the top, so the iOS large title is
      // on screen again when the view comes back to that style.
      _styleFamily = family;
      _largeTitleHidden.value = false;
    }
    _readDestinations();
    final route = ModalRoute.of(context);
    final canLeave = route?.impliesAppBarDismissal ?? false;

    return LayoutBuilder(
      builder: (context, constraints) => _buildLayout(
        style,
        _computeGeometry(context, constraints, style.platform),
        canLeave,
      ),
    );
  }

  /// One or two panes, and how wide, for a view that gets [constraints].
  SplitGeometry _computeGeometry(
    BuildContext context,
    BoxConstraints constraints,
    DevicePlatform platform,
  ) {
    final window = MediaQuery.sizeOf(context);
    final size = Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : window.width,
      constraints.hasBoundedHeight ? constraints.maxHeight : window.height,
    );
    final textDirection = Directionality.of(context);
    final hinge = _findHinge(context, window, size);
    final geometry = computeSplitGeometry(
      family: settingsStyleFamily(platform),
      forceSingle: widget.layout == SettingsSplitLayout.single,
      forceSplit: widget.layout == SettingsSplitLayout.split,
      width: size.width,
      shortestSide: window.shortestSide,
      desktop: isDesktopPlatform(Theme.of(context).platform),
      textDirection: textDirection,
      textScaler: MediaQuery.textScalerOf(context),
      breakpoint: widget.breakpoint,
      listPaneWidth: widget.listPaneWidth,
      hinge: hinge,
    );
    // A route pushed from the list pane lives in the one-pane navigator:
    // keep it (and one pane) until it closes. It covers the view either
    // way, as it does with two panes.
    return _holdOnePane ? const SplitGeometry.single() : geometry;
  }

  /// The hinge or fold that cuts the view, [size] big, in two screens.
  SeparatingHinge? _findHinge(BuildContext context, Size window, Size size) {
    final features = MediaQuery.displayFeaturesOf(context);
    if (features.isEmpty) return null;
    // Display features are in window coordinates. A full-width view
    // starts at the window's left edge; otherwise measure where it is.
    final fullWidth = (size.width - window.width).abs() < 0.5;
    if (!fullWidth) _scheduleOriginCheck();
    return findSeparatingHinge(
      features: features,
      origin: fullWidth ? Offset.zero : _measuredOrigin,
      size: size,
    );
  }

  void _scheduleOriginCheck() {
    if (_originCheckScheduled) return;
    _originCheckScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _originCheckScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final origin = box.localToGlobal(Offset.zero);
      if ((origin - _measuredOrigin).distance > 0.5) {
        setState(() => _measuredOrigin = origin);
      }
    }, debugLabel: 'SettingsSplitView.origin');
  }

  /// The panes as [geometry] lays them out (see `split_view_panes.dart`),
  /// under what the view puts around both: its scope, Tab between the
  /// panes, back handling, restoration and the theme.
  Widget _buildLayout(
    ResolvedSettingsStyle style,
    SplitGeometry geometry,
    bool canLeave,
  ) {
    _recordLayout(geometry);
    final paneStyle = SplitPaneStyle.of(style.platform, geometry);
    final list = _buildListPane(style, paneStyle, canLeave);
    final panes = geometry.isSplit
        ? _buildTwoPanes(style, paneStyle, list)
        : _buildOnePane(style, list);

    return SettingsSplitScope(
      controller: _controller,
      isSplit: _isSplit,
      shownId: _shownId,
      hostGeneration: _hostGeneration,
      goBack: _handleBack,
      child: Actions(
        actions: _paneFocusActions,
        child: PopScope<Object?>(
          canPop: !_canHandleBack,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleBack();
          },
          child: UnmanagedRestorationScope(
            bucket: bucket,
            child: SettingsTheme(
              themeData: style.themeData,
              platform: style.platform,
              child: panes,
            ),
          ),
        ),
      ),
    );
  }

  /// Notes what a layout with [geometry] shows, for back handling, the
  /// controller and the next layout.
  void _recordLayout(SplitGeometry geometry) {
    final isSplit = geometry.isSplit;
    final picked = _pickedId;
    final shownId = isSplit ? (picked ?? _autoId) : picked;
    if (_laidOut && isSplit != _isSplit) _keepFocusAcrossLayouts();
    _laidOut = true;
    _isSplit = isSplit;
    if (!geometry.compactPane) _fluentPaneOpen = false;
    _shownId = shownId;
    if (isSplit || shownId != null) _detailRootId = shownId;
    _scheduleNotify();
  }

  // The Windows compact pane -------------------------------------------------

  void _toggleFluentPane() =>
      setState(() => _fluentPaneOpen = !_fluentPaneOpen);

  void _closeFluentPane() {
    if (_fluentPaneOpen) setState(() => _fluentPaneOpen = false);
  }
}
