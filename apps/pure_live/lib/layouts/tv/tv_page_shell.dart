import 'package:dpad/dpad.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/routing/navigation/route_observer.dart' show routeObserverProvider;
import 'package:pure_live/shared/focus/tv_focus_restorer.dart';

/// The focus plumbing under every TV page: covered pages leave the focus
/// tree, and the opening highlight is claimed by [openingFocus] or by the
/// content's first row. A page wraps its body in this shell; nothing here
/// draws.
final class TvPageShell extends ConsumerStatefulWidget {
  /// Builds the shell around [child].
  const TvPageShell({required this.child, this.topBar, this.openingFocus, this.openingRegion, super.key});

  /// The page's content.
  final Widget child;

  /// The page's own top bar, if it built one.
  final Widget? topBar;

  /// The page's back node, if any; the highlight opens on it.
  final FocusNode? openingFocus;

  /// Where the opening highlight lands; defaults to the content's top-left
  /// node.
  final GlobalKey<DpadRegionState>? openingRegion;

  @override
  ConsumerState<TvPageShell> createState() => _TvPageShellState();
}

final class _TvPageShellState extends ConsumerState<TvPageShell> with RouteAware {
  /// Lets the focus passes reach the content region's nodes.
  final GlobalKey<DpadRegionState> _contentRegionKey = GlobalKey<DpadRegionState>();

  RouteObserver<ModalRoute<void>>? _observer;
  DpadController? _dpad;

  /// Whether this page is the route on top. A covered page keeps its widgets
  /// laid out, at the coordinates of the page now on screen, so leaving it
  /// focusable would let the remote drive an invisible page — the dpad layer
  /// restores focus by geometry when the node it held dies.
  bool _isCurrent = true;

  bool _claimedFocus = false;
  int _focusClaimAttempts = 0;
  static const int _maxFocusClaimAttempts = 15;

  /// Whether this page's subtree is on stage — see [build].
  bool _onStage = true;

  /// The item the page-local restorer says the keyboard belongs to.
  FocusNode? _restoreTarget;

  bool _reclaimScheduled = false;

  @override
  void initState() {
    super.initState();
    // Cached while the state is alive: the observer is gone from `ref` by the
    // time dispose runs.
    _observer = ref.read(routeObserverProvider);
    // maybeOf, not of: a page under no dpad wrapper (another form factor's
    // preview of this layout) must skip the claims, not assert.
    _dpad = Dpad.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) _observer?.subscribe(this, route);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _observer?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _setCurrent(true);
    _reclaim();
  }

  @override
  void didPopNext() {
    _setCurrent(true);
    _reclaim();
  }

  @override
  void didPushNext() => _setCurrent(false);

  @override
  void didPop() => _setCurrent(false);

  void _setCurrent(bool current) {
    if (_isCurrent == current || !mounted) return;
    setState(() => _isCurrent = current);
  }

  /// Rearms the opening-focus claim and schedules it for the next frame.
  void _reclaim() {
    _claimedFocus = false;
    _focusClaimAttempts = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _claimFocus();
    });
  }

  /// Down on the page's top bar hands the keyboard to its content explicitly.
  ///
  /// Up already works — the content region's top edge calls [_onContentEdge]
  /// — but the other direction was left to the dpad policy's cross-region
  /// search, which can settle on a row of a page that is no longer visible.
  /// Naming the target makes the round trip deterministic instead of
  /// geometric.
  KeyEventResult _onTopBarKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) return KeyEventResult.ignored;
    final target = _contentFocusTarget();
    if (target == null) return KeyEventResult.ignored;
    _dpad?.requestFocus(target);
    return KeyEventResult.handled;
  }

  /// The row the remote should land on when it comes down from the top bar.
  FocusNode? _contentFocusTarget() {
    final region = _contentRegionKey.currentState;
    if (region == null) return null;
    final remembered = region.lastFocused;
    if (remembered != null && _usable(remembered) && region.focusNodes.contains(remembered)) return remembered;
    return _topLeftMost(region.focusNodes.where(_usable));
  }

  /// Up at the content's top edge: hand focus to whatever the page put above
  /// it.
  void _onContentEdge(TraversalDirection direction) {
    if (direction != TraversalDirection.up) return;
    final above = widget.openingFocus;
    if (above == null || !_usable(above)) return;
    _dpad?.requestFocus(above);
  }

  /// Re-claims the opening focus when the content's focus dies rather than
  /// moves — the empty-state trap: removing a list's last row (clearing
  /// recents, unfollowing the last room, emptying a queue) flips the pane to
  /// an empty view with zero focusables, the focused node is disposed, and
  /// nothing re-runs [_claimFocus] because no route changed. The remote then
  /// appears dead on a page that still has content above its list.
  ///
  /// [TvFocusRestorer] already answers a focus death by re-asserting the last
  /// in-route node, and [_focusHeldInsidePage] sees that node through
  /// [_restoreTarget]; so when the restorer has a usable target this stands
  /// down and only steps in once that node is genuinely gone. The check is
  /// deferred one frame because a focus that moves (including across a scope
  /// boundary during traversal) reports a bare FocusScopeNode for an instant.
  void _handleFocusChange() {
    if (!mounted || _reclaimScheduled) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent || !_onStage) return;

    _reclaimScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reclaimScheduled = false;
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      // Something real holds the keyboard: it moved, it did not die.
      if (primary != null && primary is! FocusScopeNode && _usable(primary)) return;
      // The restorer still has a live in-page target; leave the return to it.
      if (_focusHeldInsidePage()) return;
      _reclaim();
    });
  }

  /// Puts the opening highlight on the page's own back node when it has one,
  /// and on the first content row otherwise.
  ///
  /// Left to itself the dpad layer picks the node nearest the previously
  /// focused one, so a page could open on any row of its list. This runs once
  /// per page (and again whenever the page comes back to the top), retrying a
  /// few frames while the page's rows are still being built.
  void _claimFocus() {
    if (!mounted || _claimedFocus) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      if (_focusClaimAttempts < _maxFocusClaimAttempts) {
        _focusClaimAttempts++;
        WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
      }
      return;
    }

    // Something inside this page already holds the keyboard: leave it there.
    //
    // The page-local [TvFocusRestorer] runs before this claim on a pop and
    // puts the highlight back on the item the viewer acted on. Claiming the
    // opening node on top of that is what moved the highlight off the room
    // card and onto the shell's rail after a room was closed — the reclaim
    // also fires when the page comes back on stage, a few frames after the
    // restore, so the restore alone could never win.
    if (_focusHeldInsidePage()) {
      _claimedFocus = true;
      return;
    }

    // 1. The page's own back node, when it has one.
    final back = widget.openingFocus;
    if (back != null && _usable(back)) {
      if (!identical(FocusManager.instance.primaryFocus, back)) {
        _dpad?.requestFocus(back);
      }
      _claimedFocus = true;
      return;
    }

    // 2. No back node: the top-left-most row — of the page-named opening
    // region when there is one, otherwise of the whole content.
    final region = widget.openingRegion?.currentState ?? _contentRegionKey.currentState;
    final first = _topLeftMost((region?.focusNodes ?? const <FocusNode>[]).where(_usable));
    if (first != null) {
      _dpad?.requestFocus(first);
      _claimedFocus = true;
      return;
    }

    // 3. Nothing to focus yet: retry briefly.
    if (_focusClaimAttempts < _maxFocusClaimAttempts) {
      _focusClaimAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
    }
  }

  /// Whether the keyboard is on a real node inside this page's own subtree.
  ///
  /// Used to keep the opening claim from overriding a restore
  /// [TvFocusRestorer] already made. The live focus is checked first, but a
  /// request made in this same frame is only applied in a microtask, so the
  /// restore target the restorer reported is what answers this while a pop is
  /// settling.
  bool _focusHeldInsidePage() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode && _belongsToPage(primary)) return true;
    final target = _restoreTarget;
    return target != null && _usable(target) && _belongsToPage(target);
  }

  bool _belongsToPage(FocusNode node) {
    final nodeContext = node.context;
    if (nodeContext == null || !nodeContext.mounted) return false;
    // A plain containment walk: findAncestorStateOfType stops at the nearest
    // shell, so a node owned by a page nested inside this one (every home tab
    // carries its own shell) would answer "not mine" and still lose the
    // keyboard.
    var inside = false;
    nodeContext.visitAncestorElements((element) {
      if (element == context) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside;
  }

  /// Attached, mounted and able to take focus.
  static bool _usable(FocusNode node) => node.parent != null && node.context?.mounted == true && node.canRequestFocus;

  /// The visually first node: topmost, then leftmost, a pixel of tolerance
  /// between rows.
  FocusNode? _topLeftMost(Iterable<FocusNode> nodes) {
    FocusNode? best;
    Rect? bestRect;
    for (final node in nodes) {
      final rect = _rectOf(node);
      if (rect == null) continue;
      final better =
          bestRect == null ||
          rect.top < bestRect.top - 1 ||
          (rect.top <= bestRect.top + 1 && rect.left < bestRect.left);
      if (better) {
        best = node;
        bestRect = rect;
      }
    }
    return best;
  }

  Rect? _rectOf(FocusNode node) {
    final object = node.context?.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }

  @override
  Widget build(BuildContext context) {
    final hasBar = widget.topBar != null;

    // Whether this page is really on screen — a covered page is off stage in
    // an overlay, which is the ticker mode this subtree sees.
    //
    // RouteAware alone is not enough: it only reports pushes inside this
    // page's own navigator, and a settings pane keeps its subpages in place.
    // A route pushed on the root navigator therefore covers this shell
    // without pushing inside it, and without this check the covered shell
    // would keep a live focus tree behind the visible page — the visible page
    // ends up with no highlight and a remote that does nothing.
    final onStage = TickerMode.valuesOf(context).enabled;
    if (onStage != _onStage) {
      _onStage = onStage;
      // On screen again: whatever covered this page is gone, so take the
      // highlight back. Until then its nodes cannot be focused (they are
      // ExcludeFocus'ed below), so the claim has to wait for this. Deferred
      // to after the frame: a focus request that lands while this build's
      // layout phase is still open sets state in the wrong build scope.
      if (onStage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reclaim();
        });
      }
    }

    // Content region: its top edge hands focus to the page's bar when there
    // is one; otherwise the dpad is left to search across regions.
    final content = DpadRegion(
      key: _contentRegionKey,
      verticalEdge: hasBar ? DpadEdgeBehavior.stop : DpadEdgeBehavior.leave,
      onEdge: hasBar ? _onContentEdge : null,
      child: TvFocusRestorer(onRestoreTarget: (node) => _restoreTarget = node, child: widget.child),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        DpadRegion(
          child: ExcludeFocus(
            excluding: !_isCurrent || !onStage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.topBar != null)
                  // Passive node: it never takes focus itself, it only sees
                  // the keys the bar's buttons leave unhandled (a Down on the
                  // back row).
                  Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onTopBarKey, child: widget.topBar!),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
