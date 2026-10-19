import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/app_providers.dart' show windowChromeProvider;
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_uikit/pure_uikit.dart' show PureTheme;
import 'package:window_frame_kit/window_frame_kit.dart';

/// The line Windows used to draw around the window, drawn here instead.
///
/// Taking the title bar over is done natively, by `bitsdojo_window`: it answers
/// `WM_NCCALCSIZE` with the client area set to the whole window rectangle, which
/// is what lets a Flutter strip sit at the top. The side effect is that the
/// non-client band — the strip Windows paints its one-pixel frame border into —
/// comes out zero wide on all four edges, so there is nowhere left for that
/// border to be drawn. Nothing removes it; it is simply never painted.
///
/// Windows 11 still rounds the corners, because that is composed separately, so
/// the window keeps a shape and the missing line reads as a thin gap rather than
/// a fault. Windows 10 keeps neither, which is why the self-drawn mode is only
/// the default on 11.
///
/// ## What the drawing has to agree with
///
/// The corner radius is the system's, not the design language's: DWM clips the
/// window to `DWMWCP_ROUND`'s own curve before anything Flutter paints reaches
/// the screen, so a square border loses its last few pixels at each corner and a
/// rounded one whose radius does not match shows a line bending out from under
/// the clip. A one-pixel stroke forgives a sub-pixel mismatch; it does not
/// forgive a corner that stops short.
///
/// Suppressed while maximised: the window is flush with the work area there, the
/// line would sit under the screen's own edge, and Windows 11 neither rounds nor
/// draws a border on a maximised window.
///
/// Only on Windows, and only when the app owns the frame — with the native
/// caption the system is drawing the edge, and ours on top of it would be two
/// lines.
class WindowFrameEdge extends StatefulWidget {
  /// Wraps [child] in the edge the app has to supply itself.
  const new({required this.child, super.key});

  /// The window's content.
  final Widget child;

  @override
  State<WindowFrameEdge> createState() => _WindowFrameEdgeState();
}

class _WindowFrameEdgeState extends State<WindowFrameEdge> {
  /// DWM's `DWMWCP_ROUND` default corner radius, in logical pixels.
  static const double _cornerRadius = 8;

  /// False until the window manager answers, so a window that opens maximised
  /// does not paint an edge on the frames before the answer lands.
  bool _maximised = false;

  late final _MaximiseListener _listener = _MaximiseListener(onChange: _onMaximised);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(_listener);
    // The window can already be maximised — restored from a previous session, or
    // opened onto a snapped monitor — so the live state is asked for, not assumed.
    unawaited(_readInitialState());
  }

  @override
  void dispose() {
    windowManager.removeListener(_listener);
    super.dispose();
  }

  Future<void> _readInitialState() async {
    try {
      final maximised = await windowManager.isMaximized();
      _onMaximised(maximised: maximised);
    } on Object {
      // A window manager that will not answer is a window that is not going to
      // change state either; the edge stays as it was first drawn.
    }
  }

  void _onMaximised({required bool maximised}) {
    if (mounted && maximised != _maximised) {
      setState(() => _maximised = maximised);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return widget.child;
    }
    return Consumer(
      builder: (context, ref, child) {
        final drawsEdge = ref.watch(windowChromeProvider) == ShellWindowChrome.app && !_maximised;
        if (!drawsEdge) {
          return child!;
        }
        final theme = PureTheme.of(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colors.borderSecondary),
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Turns the window manager's maximise events into one boolean.
///
/// A listener rather than a poll: the edge has to follow a snap layout, a
/// `Win`+up, a double-click on the strip and the restore button at the moment
/// they happen, and none of those arrive in Flutter as anything a widget could
/// observe on its own.
class _MaximiseListener extends WindowListener {
  new({required this.onChange});

  final void Function({required bool maximised}) onChange;

  @override
  void onWindowMaximize() => onChange(maximised: true);

  @override
  void onWindowUnmaximize() => onChange(maximised: false);

  // Restoring a maximised window is the unmaximise path on some hosts, and the
  // edge wants the same answer whichever name the event arrives under.
  @override
  void onWindowRestore() => onChange(maximised: false);
}
