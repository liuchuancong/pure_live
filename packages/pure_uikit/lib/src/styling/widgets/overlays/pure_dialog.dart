import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/overlays/pure_dialog_action_scope.dart';

/// Shows a modal — the Ant `Modal` counterpart.
///
/// The route, the scrim, the fade-and-scale and the dismissal are the core's and
/// stay the same in every language; the card inside them is painted here, one
/// shape per design language from the tokens — the M3 dialog's 28dp tonal sheet
/// under material, the iOS alert's blurred panel with its hairline-separated
/// button band under cupertino, the window-modal panel with its centred title
/// under macOS, WinUI's ContentDialog with the 2dp accent bar before its title
/// under fluent, Ubuntu's dialog with its ruled header band and its two equal
/// footer cells under Yaru, the shadcn alert under ForUI, the frosted card under
/// glass, the extruded mould under neumorphic and the crisp bordered panel under
/// wind. The colours, radii, shadows, motion and text all come from the tokens,
/// so a language re-skin and a dark switch still come out right — a modal is
/// exactly the surface no anchor library drops into a `PureConfigProvider` that
/// sits above the [Navigator], which is why it is painted here rather than
/// borrowed.
///
/// [actions] is built from the **dialog's** context, not the caller's: a button
/// that pops the nearest route has to pop the dialog, and handing the caller's
/// context to it would close the page instead. Each action is handed to
/// [PureDialogActionScope] — the last is the default choice, which is what makes
/// a dispatched PureButton comes back in the shape that language's alert footer
/// uses. [maxWidth] is the shared frame's constraint; the card still asks for the
/// width its own language gives a dialog, so a thin message does not stretch.
///
/// A body taller than the window scrolls inside the card, so the action row
/// always stays reachable, and the card reads to a screen reader as an alert
/// dialog named by its [title]. Escape and a tap on the scrim close it while
/// [dismissible] is true; a confirmation that must not be waved away passes
/// false.
Future<T?> showPureDialog<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  List<Widget> Function(BuildContext dialogContext)? actions,
  double maxWidth = 420,
  bool dismissible = true,
}) {
  final theme = PureTheme.of(context);
  final visual = _dialogVisual(theme);
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
          child: _DialogSurface(
            // The branch a language draws is its identity in tests and
            // diagnostics.
            key: ValueKey('PureDialog.${theme.config.language.name}'),
            theme: theme,
            visual: visual,
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
          begin: visual.beginScale,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: visual.curve)),
        child: dialog,
      ),
    ),
  );
}

/// How one design language frames the message: the card it is painted on, the
/// insets the slots keep, the text roles of title and body, the marks that name
/// the language (WinUI's accent bar, Ubuntu's header rule, iOS's button-band
/// hairlines), how its action row is laid out, and the entrance the card grows
/// through.
@immutable
final class _DialogVisual {
  const new({
    required this.panel,
    required this.minWidth,
    required this.contentPadding,
    required this.actionPadding,
    required this.headerGap,
    required this.actionGap,
    required this.buttonGap,
    required this.titleStyle,
    required this.titleAlign,
    required this.bodyStyle,
    required this.bodyAlign,
    required this.accentBar,
    required this.headerRule,
    required this.band,
    required this.actionRule,
    required this.actionTopRule,
    required this.bodyMaxHeight,
    required this.beginScale,
    required this.curve,
  });




  /// Windows's ContentDialog: the card over its smoke fill at Fluent's corner,
  /// and the mark that names it — a 2dp accent bar standing in front of the
  /// title — with the body in the secondary role and the buttons end-aligned.
  factory fluent() => _DialogVisual(
    panel: (theme, body) => DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colors.borderSecondary),
        boxShadow: _elevation(theme, 16),
      ),
      child: body,
    ),
    minWidth: 340,
    contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
    actionPadding: const EdgeInsets.only(top: 20),
    headerGap: 14,
    actionGap: 0,
    buttonGap: 8,
    titleStyle: (theme) => theme.text.title.copyWith(color: theme.colors.text),
    titleAlign: TextAlign.start,
    bodyAlign: TextAlign.start,
    bodyStyle: (theme) => theme.text.body.copyWith(color: theme.colors.textSecondary),
    accentBar: (theme) => theme.colors.primary,
    headerRule: (_) => null,
    band: _ActionBand.end,
    actionRule: (_) => null,
    actionTopRule: (_) => null,
    bodyMaxHeight: 0.6,
    beginScale: 0.93,
    curve: Curves.easeOutCubic,
  );






  /// Wraps the card's column in whatever the language paints behind it: fill,
  /// blur, border, shadow, and for iOS the clip that rounds the button band.
  final Widget Function(PureTheme theme, Widget body) panel;

  /// The width the language's own dialog asks for; the route still caps it at
  /// the caller's `maxWidth`, so this is a floor, not a frame.
  final double minWidth;

  /// The insets around title and body, and the one around the action row. iOS
  /// keeps its footer flush with the card's edges, so the two are separate.
  final EdgeInsets contentPadding;
  final EdgeInsets actionPadding;

  /// The gaps between the three slots, and between two buttons in a row.
  final double headerGap;
  final double actionGap;
  final double buttonGap;

  /// The title and body roles. The body is handed to the content through a
  /// [DefaultTextStyle], so a caller's bare [Text] arrives in the language's own
  /// colour and alignment instead of the platform default.
  final TextStyle Function(PureTheme theme) titleStyle;
  final TextAlign titleAlign;
  final TextStyle Function(PureTheme theme) bodyStyle;
  final TextAlign bodyAlign;

  /// WinUI's mark: a 2dp accent bar standing in front of the title. Null
  /// everywhere else.
  final Color? Function(PureTheme theme) accentBar;

  /// The hairline that rules a header band off the body — Ubuntu's dialog
  /// chrome, and the wind fork's crisper version of it.
  final Color? Function(PureTheme theme) headerRule;

  /// How this language lays a dialog's answers out.
  final _ActionBand band;

  /// The hairline between two stacked answers, and the one that rules the whole
  /// band off the message — iOS's alert footer.
  final Color? Function(PureTheme theme) actionRule;
  final Color? Function(PureTheme theme) actionTopRule;

  /// The share of the viewport a body may take before it scrolls, so the action
  /// row always stays reachable.
  final double bodyMaxHeight;

  /// The scale the card grows from and the curve of the entrance — the iOS alert
  /// settles down into place, WinUI grows up into it.
  final double beginScale;
  final Curve curve;

  /// The elevation shadow the flat-card languages lift the dialog on.
  static List<BoxShadow> _elevation(PureTheme theme, double blur) => [
    BoxShadow(
      color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.5 : 0.22),
      blurRadius: blur,
      offset: Offset(0, blur / 3),
    ),
  ];

}

/// The three ways a dialog's answers are put down.
enum _ActionBand {
  /// End-aligned in a row — M3, WinUI, macOS, shadcn, glass, neumorphic, wind.
  end,

  /// Equal-width cells side by side — Ubuntu's footer.
  equal,

  /// Stacked cells divided by hairlines — the iOS alert band.
  stack,
}

/// The surface inside the route: the card, its three slots, and the semantics
/// that name it an alert dialog.
class _DialogSurface extends StatelessWidget {
  const new({
    required this.theme,
    required this.visual,
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final PureTheme theme;
  final _DialogVisual visual;
  final String? title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      key: const Key('PureDialog.card'),
      mainAxisSize: MainAxisSize.min,
      // Always stretched: a centred title is the text role's own alignment, so a
      // right-aligned action row keeps the full width to align inside.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: visual.contentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title case final String heading) ...[
                _header(heading),
                if (visual.headerRule(theme) case final Color rule) ...[
                  SizedBox(height: theme.token.scale.sizes.sm),
                  ExcludeSemantics(
                    child: Container(key: const Key('PureDialog.headerRule'), height: 1, color: rule),
                  ),
                ],
                SizedBox(height: visual.headerGap),
              ],
              _body(context),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          if (visual.actionTopRule(theme) case final Color rule)
            ExcludeSemantics(child: Container(height: 1, color: rule))
          else
            SizedBox(height: visual.actionGap),
          _actions(),
        ],
      ],
    );
    return Semantics(
      role: SemanticsRole.alertDialog,
      container: true,
      label: title,
      child: visual.panel(
        theme,
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: visual.minWidth),
          child: column,
        ),
      ),
    );
  }

  /// The title, with WinUI's accent bar in front of it when the language asks.
  Widget _header(String heading) => Row(
    children: [
      if (visual.accentBar(theme) case final Color accent) ...[
        Container(
          key: const Key('PureDialog.accentBar'),
          width: 2,
          height: 16,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(1)),
        ),
        SizedBox(width: theme.token.scale.sizes.sm),
      ],
      Expanded(
        child: Text(heading, textAlign: visual.titleAlign, style: visual.titleStyle(theme)),
      ),
    ],
  );

  /// The message. A body taller than the card scrolls rather than pushing the
  /// answers off the screen, and the language's body role and alignment are
  /// handed down through a [DefaultTextStyle], so a bare [Text] from the caller
  /// arrives in the card's own ink instead of the platform default.
  Widget _body(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * visual.bodyMaxHeight),
    child: SingleChildScrollView(
      child: DefaultTextStyle(style: visual.bodyStyle(theme), textAlign: visual.bodyAlign, child: content),
    ),
  );

  /// The answers, in the form this language gives them. The row and the band are
  /// keyed, because which of the two a language draws is the difference between
  /// a button row and an iOS alert footer.
  Widget _actions() {
    final EdgeInsets padding;
    final Widget row;
    switch (visual.band) {
      case _ActionBand.end:
        padding = visual.actionPadding;
        row = Row(
          key: const Key('PureDialog.buttonRow'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < actions.length; i++) ...[if (i > 0) SizedBox(width: visual.buttonGap), actions[i]],
          ],
        );
      case _ActionBand.equal:
        padding = visual.actionPadding;
        row = Row(
          key: const Key('PureDialog.buttonRow'),
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) SizedBox(width: visual.buttonGap),
              Expanded(child: actions[i]),
            ],
          ],
        );
      case _ActionBand.stack:
        // The alert's own footer: flush with the card, one cell per answer, a
        // hairline between two of them.
        padding = visual.actionPadding;
        final rule = visual.actionRule(theme);
        row = rule == null
            ? Column(
                key: const Key('PureDialog.buttonBand'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions,
              )
            : Column(
                key: const Key('PureDialog.buttonBand'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) ExcludeSemantics(child: Container(height: 1, color: rule)),
                    actions[i],
                  ],
                ],
              );
    }
    return Padding(key: const Key('PureDialog.actions'), padding: padding, child: row);
  }
}


/// The dialog for the active design language.
_DialogVisual _dialogVisual(PureTheme theme) => _DialogVisual.fluent();

/// The actions in the dialog's own action form: the last is the default, which
/// is where both macOS and iOS put the answer to the question the dialog asks.
///
/// An [PureDialogActionScope] is an inherited widget, so it adds no box and moves
/// no pixel — the callers' action widgets are untouched, and only a dispatched
/// button that reads the scope changes shape.
List<Widget> _actionRow(List<Widget>? actions) => switch (actions) {
  null => const <Widget>[],
  final list when list.isEmpty => const <Widget>[],
  final list => [
    for (var i = 0; i < list.length; i++) PureDialogActionScope(isDefault: i == list.length - 1, child: list[i]),
  ],
};
