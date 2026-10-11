import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// The dialog every page uses.
///
/// Two entry points cover the cases pages actually have: [show] for a
/// dialog that completes with a typed action result, and [confirm] for the
/// yes/no question that everything else is built on. Both go through the
/// active language's implementation, so a Fluent build shows a Fluent
/// dialog without the page knowing.
abstract final class LiveDialog {
  /// Shows [spec] and completes with the chosen action's result, or null
  /// when the dialog was dismissed.
  static Future<T?> show<T>(BuildContext context, LiveDialogSpec<T> spec) =>
      LiveTheme.of(context).components.dialog<T>(context, spec);

  /// Asks a yes/no question about [title] (with an optional [message]),
  /// completing with false when the dialog is dismissed.
  ///
  /// [danger] flips the confirm button to the destructive variant — a
  /// delete confirmation must not look like a save confirmation.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    bool danger = false,
    Widget? content,
    String? confirmAccessibilityLabel,
  }) async {
    final theme = LiveTheme.of(context);
    final result = await theme.components.dialog<bool>(
      context,
      LiveDialogSpec<bool>(
        title: title,
        message: message,
        content: content,
        actions: [
          LiveDialogAction<bool>(label: cancelLabel, result: false, autofocus: !danger),
          LiveDialogAction<bool>(
            label: confirmLabel,
            result: true,
            variant: danger ? LiveButtonVariant.danger : LiveButtonVariant.primary,
            autofocus: danger,
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
