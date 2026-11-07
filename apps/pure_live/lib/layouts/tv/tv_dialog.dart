import 'dart:async' show Timer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/focus/tv_dialog_lock.dart';

/// Opens a dialog on a TV surface: the dialog owns the remote while it is up
/// ([tvDialogLock], so a card's select cannot fire through it), its focus
/// never escapes to the covered page ([TvDialogFocusGuard]), and the item
/// the viewer acted on gets the keyboard back after it closes.
///
/// The lock releases a beat after the dialog's future completes, because a
/// dialog's focus tree dies only when its exit transition ends — a select
/// landing in that window must still find the lock up.
Future<T?> showTvDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) async {
  final invoking = FocusManager.instance.primaryFocus;
  tvDialogLock.lock();
  try {
    return await showDsDialog<T>(
      context: context,
      dismissible: dismissible,
      builder: (context) => TvDialogFocusGuard(child: builder(context)),
    );
  } finally {
    Timer(const Duration(milliseconds: 350), tvDialogLock.unlock);
    _restoreInvokingFocus(invoking);
  }
}

/// Hands the keyboard back to the item that opened the dialog, and keeps
/// asserting it until the exit transition has finished killing the dialog's
/// own focus tree — long enough to outlast the dpad root's fallback, short
/// enough never to fight the viewer.
void _restoreInvokingFocus(FocusNode? node) {
  if (node == null) return;
  final deadline = DateTime.now().add(const Duration(milliseconds: 900));
  void attempt() {
    if (FocusManager.instance.primaryFocus == node) return; // Settled.
    if (DateTime.now().isAfter(deadline)) return;
    final usable = node.parent != null && node.context?.mounted == true && node.canRequestFocus;
    if (usable) node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
}

/// Keeps the focus inside the dialog it wraps.
///
/// The dpad root's own fallback answers a focus death by taking the
/// top-most focusable it can find — and a dialog's focus tree disposes only
/// when its exit transition ends, while the responsive list behind the
/// dialog rebuilds right away. Left alone, the highlight ends up on a card
/// underneath the visible dialog. The guard re-claims instead: whatever
/// held focus inside stays the target, and the first focusable inside is
/// the opening claim.
final class TvDialogFocusGuard extends StatefulWidget {
  /// Guards [child]'s focus.
  const TvDialogFocusGuard({required this.child, super.key});

  /// The dialog's content.
  final Widget child;

  @override
  State<TvDialogFocusGuard> createState() => _TvDialogFocusGuardState();
}

final class _TvDialogFocusGuardState extends State<TvDialogFocusGuard> {
  /// How many frames the opening claim may keep retrying while the dialog's
  /// rows are still building.
  static const int _maxClaimAttempts = 10;

  late final FocusNode _root = FocusNode(canRequestFocus: false, skipTraversal: true, debugLabel: 'tv dialog guard');
  FocusNode? _lastInside;
  bool _scheduled = false;
  int _claimAttempts = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _root.dispose();
    super.dispose();
  }

  /// Records where the viewer was while the dialog holds the keyboard, and
  /// answers a focus death one frame later: the focus that moved inside is
  /// left alone; the focus that died or escaped pulls the last known
  /// in-dialog node back. The frame of grace keeps a focus that is crossing
  /// a scope boundary (reported as a bare FocusScopeNode for an instant)
  /// from being read as an escape.
  void _onFocusChange() {
    if (!mounted || _scheduled) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode && _inside(primary)) {
      _lastInside = primary;
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      final settled = FocusManager.instance.primaryFocus;
      if (settled != null && settled is! FocusScopeNode && _inside(settled)) return;
      final last = _lastInside;
      final target = last != null && _usable(last) ? last : _firstFocusableInside();
      if (target != null) target.requestFocus();
    });
  }

  /// The opening claim: the first focusable inside, retried while the
  /// dialog's rows build. A dialog whose own action button autofocuses
  /// settles before this ever needs to move anything.
  void _claim() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary is! FocusScopeNode && _inside(primary)) return;
    final first = _firstFocusableInside();
    if (first != null) {
      first.requestFocus();
      return;
    }
    if (_claimAttempts < _maxClaimAttempts) {
      _claimAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
    }
  }

  bool _inside(FocusNode node) {
    final nodeContext = node.context;
    if (nodeContext == null || !nodeContext.mounted) return false;
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

  static bool _usable(FocusNode node) => node.parent != null && node.context?.mounted == true && node.canRequestFocus;

  /// The tree's first focusable below the guard, in build order.
  FocusNode? _firstFocusableInside() {
    for (final node in _root.descendants) {
      if (_usable(node)) return node;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _root, canRequestFocus: false, skipTraversal: true, child: widget.child);
}
