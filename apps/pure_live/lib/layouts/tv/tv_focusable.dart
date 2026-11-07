import 'package:dpad/dpad.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/focus/dpad_long_press_gate.dart';
import 'package:pure_live/shared/focus/tv_dialog_lock.dart';
import 'package:pure_live/shared/focus/tv_focus_style.dart';

/// The D-pad stop a TV control is built on: the one focus language from
/// [tvFocusEffects], the long-press gate, and the dialog lock standing down
/// while a dialog owns the remote.
///
/// This widget owns the focus — the content inside never takes it (dpad
/// excludes the child subtree) — so it is for controls built ON a TV build,
/// not a wrapper to drop around existing pressables (those keep their own
/// focus, ring and activation; TvGrowOnFocus decorates those).
final class TvFocusable extends StatelessWidget {
  /// Builds the focusable around [child].
  const TvFocusable({
    required this.child,
    this.onSelect,
    this.onLongSelect,
    this.autofocus = false,
    this.borderRadius = BorderRadius.zero,
    this.scale = kTvFocusScale,
    this.onFocusChange,
    super.key,
  });

  /// The control's content.
  final Widget child;

  /// Runs on select, unless a dialog owns the remote or a long-press just
  /// served.
  final VoidCallback? onSelect;

  /// Runs on a long-press. Leave it null when the control has none: dpad
  /// defers select to key-up for every control that carries one, and a
  /// disturbed press would then never select at all.
  final VoidCallback? onLongSelect;

  /// Takes the opening highlight.
  final bool autofocus;

  /// The corners the ring and the glow follow.
  final BorderRadius borderRadius;

  /// How far focus grows; 1.0 for a control that fills its row.
  final double scale;

  /// Reports focus moves, for controls that restyle on it.
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      autofocus: autofocus,
      effects: tvFocusEffects(context, borderRadius, scale: scale),
      onFocusChange: onFocusChange,
      onSelect: onSelect == null
          ? null
          : () {
              // A dialog owns the remote: the select belongs to it, not to
              // the card that happens to hold focus underneath.
              if (tvDialogLockedNow) return;
              // A long-press just served on some control: this select is
              // its leaking tail, not a press of ours.
              if (tvLongPressGate.swallowSelect()) return;
              onSelect!();
            },
      onLongSelect: onLongSelect == null
          ? null
          : () {
              if (tvDialogLockedNow) return;
              tvLongPressGate.markLongPress();
              onLongSelect!();
            },
      child: child,
    );
  }
}
