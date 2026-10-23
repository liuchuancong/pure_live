import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart' show desktopWindowHostProvider, maximizedProvider;
import 'package:pure_live/app/shell/desktop/pure_title_bar.dart' show kTitleBarHeight;
import 'package:pure_live/i18n/translations.g.dart';

/// The three caption buttons: minimize, maximise-or-restore, close.
///
/// Close goes to the window host like the others; whether the shell asks
/// before quitting is the close policy's business, which arrives with the
/// storage phase.
final class WindowCaptionControls extends ConsumerWidget {
  /// The caption controls.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(desktopWindowHostProvider);
    final maximized = ref.watch(maximizedProvider);
    return Row(
      children: [
        _CaptionButton(semanticLabel: t.window.minimize, icon: DsIcons.minus, onPressed: host.minimize),
        _CaptionButton(
          semanticLabel: maximized ? t.window.restore : t.window.maximize,
          icon: maximized ? DsIcons.copy : DsIcons.square,
          onPressed: host.toggleMaximize,
        ),
        _CaptionButton(semanticLabel: t.window.close, icon: DsIcons.x, danger: true, onPressed: host.close),
      ],
    );
  }
}

final class _CaptionButton extends StatelessWidget {
  const new({required this.semanticLabel, required this.icon, required this.onPressed, this.danger = false});

  final String semanticLabel;
  final DsIconData icon;
  final Future<void> Function() onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: kTitleBarHeight,
      height: kTitleBarHeight,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          Color? background;
          if (danger && hovered) {
            background = colors.danger.fill;
          } else if (hovered || pressed) {
            background = pressed ? colors.press : colors.hover;
          }
          return ColoredBox(
            color: background ?? const Color(0x00000000),
            child: Center(child: DsIcon(icon, size: 14, color: danger && hovered ? colors.danger.onFill : colors.text)),
          );
        },
      ),
    );
  }
}
