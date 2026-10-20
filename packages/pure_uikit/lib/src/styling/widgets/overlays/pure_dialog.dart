import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/overlays/pure_dialog_action_scope.dart';

/// Shows a modal — the Ant `Modal` counterpart.
///
/// The route, the barrier colour, the fade-and-scale and the dismissal are the
/// core's and stay the same in every language; the surface inside them is the
/// active design language's own dialog, constructed directly: the surface
/// builder switches on `UiConfig.language` and hands the route an
/// `AlertDialog` under material, a `CupertinoAlertDialog` under cupertino, a
/// `MacosAlertDialog` under macOS, and Fluent's own dialog renderer under
/// fluent — so what the user sees is exactly what that library's own
/// documentation shows. Switching `UiConfig.language` re-skins every dialog.
/// [actions] should be dispatched controls, which is what makes them match the
/// language, and [maxWidth] is the shared frame's constraint — a language that
/// sizes its surface by its own layout ignores it.
///
/// Three of the remaining libraries ship no dialog widget at all (glass,
/// neumorphic, wind — they are surface/style libraries), so those branches keep
/// a documented composition out of the library's own surface container; ForUI's
/// `FDialog` is a frame, not a routed dialog, so its branch folds the frame in
/// and leaves the route to the core, exactly as the other branches do.
///
/// The actions are built from the **dialog's** context, not the caller's: a
/// button that pops the nearest route has to pop the dialog, and handing the
/// caller's context to it would close the page instead.
Future<T?> showPureDialog<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  List<Widget> Function(BuildContext dialogContext)? actions,
  double maxWidth = 420,
  bool dismissible = true,
}) {
  final theme = PureTheme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: theme.colors.mask,
    transitionDuration: theme.duration,
    pageBuilder: (dialogContext, _, _) => Center(
      // The core frames the surface — centred, inset, capped in width — and the
      // language decides what the surface itself looks like.
      child: Padding(
        padding: EdgeInsets.all(theme.token.scale.sizes.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _dialogSurface(
            dialogContext,
            theme,
            title: title,
            content: child,
            actions: _actionRow(actions?.call(dialogContext)),
          ),
        ),
      ),
    ),
    transitionBuilder: (dialogContext, animation, _, dialog) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.96,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: dialog,
      ),
    ),
  );
}

/// The dialog surface for the active design language: the language's own
/// dialog widget, or Flutter's official Material `AlertDialog` where the
/// library ships no dialog.
Widget _dialogSurface(
  BuildContext dialogContext,
  PureTheme theme, {
  required String? title,
  required Widget content,
  required List<Widget> actions,
}) {
  return switch (theme.config.language) {
    // Yaru draws dialogs with the Material `AlertDialog` — that is what Yaru
    // itself is; its character comes from the host theme (see `PureApp._yaruHost`).
    PureDesignLanguage.material || PureDesignLanguage.yaru => AlertDialog(
      title: title == null ? null : Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
      content: content,
      contentTextStyle: theme.text.body.copyWith(color: theme.colors.text),
      // An absent action row is null for the library widget — an empty list
      // would paint the action band with nothing in it.
      actions: actions.isEmpty ? null : actions,
      backgroundColor: theme.colors.bgElevated,
      // The core's frame insets and aligns the surface already; the fork's own
      // dialog route padding would inset it a second time.
      insetPadding: EdgeInsets.zero,
      // The core caps the width but not the height; this flag puts a body
      // taller than the screen in a scroll view instead of overflowing.
      scrollable: true,
    ),
    PureDesignLanguage.cupertino => cupertino.CupertinoAlertDialog(
      title: title == null ? null : Text(title),
      // Plain widgets: the alert merges its own iOS heading and message styles
      // over each slot, so a token text style here would overwrite the very
      // thing the widget is used for.
      content: _scrollingBody(dialogContext, content),
      actions: actions,
    ),
    PureDesignLanguage.macos => _macosDialogSurface(
      dialogContext,
      theme,
      title: title,
      content: content,
      actions: actions,
    ),
    PureDesignLanguage.fluent => _fluentDialogSurface(dialogContext, title: title, content: content, actions: actions),
    PureDesignLanguage.forui => _foruiDialogSurface(theme, title: title, content: content, actions: actions),
    // glass_morphism_plus, flutter_neumorphic_ui_kit and fluttersdk_wind ship
    // no dialog. Use Flutter's official Material AlertDialog rather than a
    // hand-built panel.
    PureDesignLanguage.glass || PureDesignLanguage.neumorphic || PureDesignLanguage.wind => AlertDialog(
      title: title == null ? null : Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
      content: content,
      contentTextStyle: theme.text.body.copyWith(color: theme.colors.text),
      actions: actions.isEmpty ? null : actions,
      backgroundColor: theme.colors.bgElevated,
      insetPadding: EdgeInsets.zero,
      scrollable: true,
    ),
  };
}

/// The actions in the dialog's own action form: the last is the default, which
/// is where both macOS and iOS put the answer to the question the dialog asks.
///
/// An [PureDialogActionScope] is an inherited widget, so it adds no box and moves
/// no pixel — the libraries' ordinary action rows are untouched, and only a
/// dispatched button that reads the scope changes shape.
List<Widget> _actionRow(List<Widget>? actions) => switch (actions) {
  null => const <Widget>[],
  final list when list.isEmpty => const <Widget>[],
  final list => [
    for (var i = 0; i < list.length; i++) PureDialogActionScope(isDefault: i == list.length - 1, child: list[i]),
  ],
};

/// The content slot for a surface that lays its body in a plain column.
///
/// iOS's alert, macOS's alert and sheet and ForUI's frame all hand the message
/// a child slot of its own size, so a body taller than the window does not
/// scroll — it pushes the action row off the screen. Material's `AlertDialog`
/// is excluded: it takes `scrollable:` itself and a second viewport inside it
/// would fight the library's. Fluent's renderer already wraps its body in a
/// `Flexible` + scroll view for the same reason.
///
/// The cap is a height the scroll view can measure. A `SingleChildScrollView`
/// alone is not enough: inside those columns it is given an unbounded main axis
/// and simply grows to its content, so the bound has to be named here.
Widget _scrollingBody(BuildContext context, Widget content) => ConstrainedBox(
  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
  child: SingleChildScrollView(child: content),
);

/// The macOS surface: the library's own `MacosSheet` panel.
///
/// `MacosAlertDialog` is not reachable from here. It asserts that both of its
/// slots are a `macos.PushButton` at `ControlSize.large`, and the actions this
/// route is handed are dispatched `PureButton`s — the app never names a library
/// widget, which is the whole point of the kit. So the panel is the surface macOS
/// draws, and the alert's own metric reaches it through the action scope: the
/// buttons inside come back at the large step, which is what the alert row is.
Widget _macosDialogSurface(
  BuildContext dialogContext,
  PureTheme theme, {
  required String? title,
  required Widget content,
  required List<Widget> actions,
}) {
  final gap = theme.token.scale.sizes.md;
  return macos.MacosSheet(
    insetPadding: EdgeInsets.zero,
    backgroundColor: theme.colors.bgElevated,
    child: Padding(
      padding: EdgeInsets.all(theme.card.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final String heading) ...[
            Text(heading, style: theme.text.title.copyWith(color: theme.colors.text)),
            SizedBox(height: gap),
          ],
          _scrollingBody(dialogContext, content),
          if (actions.isNotEmpty) ...[
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in actions)
                  Padding(
                    padding: EdgeInsets.only(left: theme.token.scale.sizes.sm),
                    child: action,
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

/// The Fluent surface, from the library's own renderer.
///
/// `FluentDialog` itself draws its scrim, its focus trap and its entrance
/// relative to the [Overlay], all of which the core's route already owns —
/// so the surface is resolved and built through the package's public
/// recomposition contract (state, style, renderer) instead, which is the same
/// renderer the widget itself drives, minus the parts the core replaces.
Widget _fluentDialogSurface(
  BuildContext dialogContext, {
  required String? title,
  required Widget content,
  required List<Widget> actions,
}) {
  final state = f2.resolveFluentDialogState(
    content: content,
    title: title == null ? null : Text(title),
    actions: actions,
  );
  return f2.buildFluentDialog(
    state,
    f2.resolveFluentDialogStyle(state, f2.FluentTheme.of(dialogContext)),
    const <WidgetState>{},
  );
}

/// The ForUI surface: the library's `FDialog` frame. The frame is all the
/// library's dialog is in 0.27.5 — its route lives in `FDialogRoute`, which is
/// the core's job here — so the frame is folded in and the core's route carries
/// it, exactly as the other branches fold their surfaces in.
Widget _foruiDialogSurface(
  PureTheme theme, {
  required String? title,
  required Widget content,
  required List<Widget> actions,
}) {
  final gap = theme.token.scale.sizes.md;
  return forui.FDialog(
    // The core centres, insets and caps the surface, so the library's own inset —
    // which exists to keep a full-screen dialog off the viewport edges — is dropped
    // rather than stacked on top of the core's.
    style: const forui.FDialogStyleDelta.delta(insetPadding: forui.EdgeInsetsGeometryDelta.value(EdgeInsets.zero)),
    builder: (context, style) => Padding(
      // The frame ships no content padding, so the token card padding wraps the
      // column, and it has no action area, so the actions arrive as a
      // right-aligned row of the widgets the caller already dispatched.
      padding: EdgeInsets.all(theme.card.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final String heading) ...[
            DefaultTextStyle(style: style.titleTextStyle, child: Text(heading)),
            SizedBox(height: gap),
          ],
          DefaultTextStyle(style: style.bodyTextStyle, child: _scrollingBody(context, content)),
          if (actions.isNotEmpty) ...[
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in actions)
                  Padding(
                    padding: EdgeInsets.only(left: theme.token.scale.sizes.sm),
                    child: action,
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
