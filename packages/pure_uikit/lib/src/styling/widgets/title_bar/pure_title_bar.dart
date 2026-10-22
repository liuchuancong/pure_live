import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Selects and manages the appropriate title bar presentation.
///
/// This widget owns maximized-state tracking and renders the token
/// presentation: the per-language presentations are retired with the hosts,
/// and every design language draws the same token title bar.
class PureTitleBar extends StatefulWidget {
  /// Creates a title bar for the selected design language.
  const new({
    required this.labels,
    required this.actions,
    this.designLanguage,
    this.metrics,
    this.maximized,
    this.leading,
    super.key,
  });

  /// Retained for call-site compatibility; it no longer changes what this
  /// strip draws. Every language renders the token presentation.
  final PureDesignLanguage? designLanguage;

  /// The title and localized window-control labels.
  final PureTitleBarLabels labels;

  /// The window operations provided by the application Shell.
  final WindowChromeActions actions;

  /// Optional dimensions overriding the presentation defaults.
  final PureCaptionMetrics? metrics;

  /// An optional listenable containing the authoritative maximized state.
  ///
  /// When supplied, the title bar listens to this value instead of polling
  /// the window state after actions.
  final ValueListenable<bool>? maximized;

  /// The mark drawn before the title — the app's own brand.
  final Widget? leading;

  @override
  State<PureTitleBar> createState() => _PureTitleBarState();
}

class _PureTitleBarState extends State<PureTitleBar> {
  bool _isMaximized = false;
  bool _toggleInProgress = false;

  /// The caller's actions, read through this state so each window call is
  /// reported when it fails and the maximise toggle keeps its single-flight
  /// guard. Built once: it reads `widget.actions` at call time, so a replaced
  /// seam is picked up without rebuilding the wrapper.
  late final WindowChromeActions _reporting = _ReportingWindowChrome(this);

  @override
  void initState() {
    super.initState();

    widget.maximized?.addListener(_handleMaximizedChanged);
    _isMaximized = widget.maximized?.value ?? false;

    if (widget.maximized == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshMaximizedState());
      });
    }
  }

  @override
  void didUpdateWidget(covariant PureTitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.maximized != widget.maximized) {
      oldWidget.maximized?.removeListener(_handleMaximizedChanged);
      widget.maximized?.addListener(_handleMaximizedChanged);

      if (widget.maximized != null) {
        _setMaximized(widget.maximized!.value);
      } else {
        unawaited(_refreshMaximizedState());
      }
    }
  }

  @override
  void dispose() {
    widget.maximized?.removeListener(_handleMaximizedChanged);
    super.dispose();
  }

  /// Synchronizes the local state with the externally supplied value.
  void _handleMaximizedChanged() {
    final maximized = widget.maximized;
    if (maximized != null) {
      _setMaximized(maximized.value);
    }
  }

  /// Updates the maximized state only when the value has changed.
  void _setMaximized(bool value) {
    if (!mounted || _isMaximized == value) {
      return;
    }

    setState(() {
      _isMaximized = value;
    });
  }

  /// Reads the current maximized state from the window adapter.
  Future<void> _refreshMaximizedState() async {
    if (widget.maximized != null) {
      _setMaximized(widget.maximized!.value);
      return;
    }

    try {
      final value = await widget.actions.isMaximized();
      _setMaximized(value);
    } on Object catch (error, stackTrace) {
      _reportWindowActionError(error, stackTrace, 'Failed to read the window maximized state.');
    }
  }

  /// Executes a window operation and reports failures consistently.
  Future<void> _runWindowAction(Future<void> Function() action, {required String description}) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      _reportWindowActionError(error, stackTrace, description);
    }
  }

  /// Toggles the window state without allowing overlapping requests.
  Future<void> _toggleMaximize() async {
    if (_toggleInProgress) {
      return;
    }

    _toggleInProgress = true;

    try {
      await widget.actions.toggleMaximize();

      if (widget.maximized != null) {
        _setMaximized(widget.maximized!.value);
      } else {
        await _refreshMaximizedState();
      }
    } on Object catch (error, stackTrace) {
      _reportWindowActionError(error, stackTrace, 'Failed to toggle the window maximized state.');
    } finally {
      _toggleInProgress = false;
    }
  }

  /// Reports window-adapter errors through Flutter's error reporting system.
  void _reportWindowActionError(Object error, StackTrace stackTrace, String description) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'pure_uikit',
        context: ErrorDescription(description),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Every window call the strip makes goes out through the reporting wrapper,
    // so a plugin that answers with a failure surfaces in the error zone instead
    // of vanishing into an unawaited button callback.
    final actions = _reporting;
    final labels = widget.labels;
    void toggleMaximize() => unawaited(_toggleMaximize());

    final Widget presentation = PureTokenTitleBar(
      labels: labels,
      actions: actions,
      leading: widget.leading,
      isMaximized: _isMaximized,
      onToggleMaximize: toggleMaximize,
      metrics: widget.metrics ?? const PureCaptionMetrics.desktop(),
    );

    return presentation;
  }
}

/// The seam the presentations are handed: the same five operations, with every
/// failure reported and the maximise toggle guarded against overlapping calls.
final class _ReportingWindowChrome implements WindowChromeActions {
  const new(this._state);

  final _PureTitleBarState _state;

  @override
  Future<void> minimize() =>
      _state._runWindowAction(_state.widget.actions.minimize, description: 'Failed to minimize the window.');

  @override
  Future<void> close() =>
      _state._runWindowAction(_state.widget.actions.close, description: 'Failed to close the window.');

  @override
  Future<void> startDragging() =>
      _state._runWindowAction(_state.widget.actions.startDragging, description: 'Failed to start dragging the window.');

  @override
  Future<bool> isMaximized() => _state.widget.actions.isMaximized();

  @override
  Future<void> toggleMaximize() => _state._toggleMaximize();
}
