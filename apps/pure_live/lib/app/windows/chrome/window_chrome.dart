import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show ChromeMode;
import 'package:multiview_desktop/multiview_desktop.dart' show MultiViewDesktop, ResizeEdge;
import 'package:pure_live/app/providers/providers.dart' show desktopWindowHostProvider, maximizedProvider;
import 'package:pure_live/l10n/translations.dart';

/// Who owns the running window's title bar.
///
/// The caption style is dressed when the window is created, and every desktop
/// window is dressed to draw its own strip: the system's caption cannot carry
/// the app's chrome. The mode the boot's plan produced is recorded here so the
/// layouts can decide who draws the strip and its buttons — macOS keeps the
/// system's traffic lights inset in that strip, Windows and Linux draw the
/// buttons too.
abstract final class WindowChromeState {
  /// The mode the window was dressed in.
  static ChromeMode mode = ChromeMode.nativeCaption;

  /// Whether the shell draws its own strip for this window.
  static bool get drawsStrip => mode != ChromeMode.nativeCaption;

  /// Whether the strip also draws minimise, maximise and close. macOS keeps
  /// its own traffic lights inset in the app's bar, so the app does not add
  /// a second set.
  static bool get drawsCaptionControls => mode == ChromeMode.selfDrawn;
}

/// The draggable band of a window that draws its own caption: press and move
/// the OS window, double press to maximise or restore.
///
/// A route that replaces the shell's strip with its own bar (the room page)
/// wraps that bar's title in this, so the window stays movable without a
/// second caption row above the page.
final class WindowDragArea extends ConsumerWidget {
  /// Makes [child] the window's drag handle.
  const WindowDragArea({required this.child, super.key});

  /// The band's content.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(desktopWindowHostProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => host.startDragging(),
      onDoubleTap: host.toggleMaximize,
      child: child,
    );
  }
}

/// The minimise, maximise and close buttons for a window that draws its own
/// caption.
///
/// The shell's strip and a route that owns its title bar share this one
/// widget, so the three buttons never differ between them; [height] is the bar
/// they sit in, so a hover fill reaches both of its edges.
final class WindowCaptionControls extends ConsumerWidget {
  /// The three buttons for a bar [height] tall.
  const WindowCaptionControls({this.height = 44, super.key});

  /// The height of the bar the buttons fill.
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final host = ref.watch(desktopWindowHostProvider);
    final maximized = ref.watch(maximizedProvider);
    return Row(
      children: [
        WindowCaptionButton(
          semanticLabel: t.common.minimize,
          icon: DsIcons.minus,
          size: height,
          onPressed: host.minimize,
        ),
        WindowCaptionButton(
          semanticLabel: maximized ? t.common.restore : t.common.maximize,
          icon: maximized ? DsIcons.copy : DsIcons.square,
          size: height,
          onPressed: host.toggleMaximize,
        ),
        WindowCaptionButton(
          semanticLabel: t.common.close,
          icon: DsIcons.x,
          size: height,
          danger: true,
          onPressed: host.close,
        ),
      ],
    );
  }
}

/// One caption button: a hover fill, the danger tint on close, and the label
/// a screen reader reads.
///
/// Shared by the caption triple and by the trail arrows in the strip, so the
/// two never drift apart. A square [size] makes the button fill the height of
/// the bar it sits in.
final class WindowCaptionButton extends ConsumerWidget {
  /// A caption button [size] logical pixels square.
  const WindowCaptionButton({
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.enabled = true,
    this.danger = false,
    super.key,
  });

  /// The button's accessible name.
  final String semanticLabel;

  /// The glyph.
  final DsIconData icon;

  /// The host's calls return futures; a void return swallows them.
  final VoidCallback onPressed;

  /// The button's width and height.
  final double size;

  /// False dims the icon and deadens the press: an arrow over an empty trail,
  /// say.
  final bool enabled;

  /// Paints the close button's fill in the danger colour.
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: enabled ? onPressed : null,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          Color? background;
          if (enabled) {
            if (danger && hovered) {
              background = colors.danger.fill;
            } else if (hovered || pressed) {
              background = pressed ? colors.press : colors.hover;
            }
          }
          return ColoredBox(
            color: background ?? const Color(0x00000000),
            child: Center(child: DsIcon(icon, size: 14, color: enabled ? colors.text : colors.textSubtle)),
          );
        },
      ),
    );
  }
}

/// The window's top edge as a resize strip.
///
/// The hidden caption keeps the system's sizing frame on the left, the right
/// and the bottom, so those three edges resize natively — but the top band is
/// client area that nothing answers the resize hit test for, and the window
/// cannot be sized from the top at all. This transparent strip hands a press
/// there to the plugin's own resize verb, which enters the system's sizing
/// loop; the corners stay with the system, whose side bands already resize
/// them diagonally.
final class WindowTopResizeBand extends StatefulWidget {
  /// A strip over the window of [viewId].
  const WindowTopResizeBand({required this.viewId, super.key});

  /// The plugin's view id of the window the strip resizes.
  final int viewId;

  @override
  State<WindowTopResizeBand> createState() => _WindowTopResizeBandState();
}

final class _WindowTopResizeBandState extends State<WindowTopResizeBand> {
  // The verdict the cursor shows, re-read under the pointer: a strip that
  // keeps promising a resize it cannot deliver is worse than no strip.
  bool _sizable = false;

  bool get _sizableNow {
    if (defaultTargetPlatform != TargetPlatform.windows || !WindowChromeState.drawsStrip) {
      return false;
    }
    final window = MultiViewDesktop.fromId(widget.viewId);
    return window.isResizable() && !window.isMaximized() && !window.isFullScreen();
  }

  void _refresh() {
    final sizable = _sizableNow;
    if (sizable != _sizable) setState(() => _sizable = sizable);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.windows || !WindowChromeState.drawsStrip) {
      return const SizedBox.shrink();
    }
    // As tall as the strips the window still has on its other three sides:
    // the system's eight physical pixels.
    final band = 8 / View.of(context).devicePixelRatio;
    return MouseRegion(
      cursor: _sizable ? SystemMouseCursors.resizeUp : MouseCursor.defer,
      onEnter: (_) => _refresh(),
      onHover: (_) => _refresh(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (_) {
          if (_sizableNow) MultiViewDesktop.fromId(widget.viewId).startResizing(ResizeEdge.top);
        },
        child: SizedBox(height: band, width: double.infinity),
      ),
    );
  }
}
