import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_metrics.dart';
import 'package:pure_settings_ui/src/pure/pure_text_slot.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The page bar of the pure style: pure_uikit's own [PureAppBar], which draws
/// forui's header, glass's frosted bar, the neumorphic bar or the wind bar
/// according to the active language.
///
/// It differs from [PureAppBar] in one way. That widget implies a back button
/// from the enclosing route, which is right for a page the router pushed and
/// wrong here: in a split view the list pane is not a route, and going back is
/// a callback the view owns. So the button is passed as `leading` explicitly
/// whenever [onBack] is set, and the implied one never gets a chance to fire.
///
/// A [title] that is not a [Text] cannot go through [PureAppBar], which takes a
/// string, so it gets [_PureWidgetBar] instead — plainer, but it renders.
class PurePageBar extends StatelessWidget {
  /// A bar titled [title], with a back button when [onBack] is set.
  const new({required this.title, this.onBack, this.actions, super.key});

  /// The page's title.
  final Widget? title;

  /// Leaves the page. Null when there is nowhere to go back to.
  final VoidCallback? onBack;

  /// Widgets at the end of the bar.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final label = pureTextOf(title);
    final back = _backButton(context);
    if (title != null && label == null) {
      return _PureWidgetBar(title: title, leading: back, actions: actions);
    }
    return SafeArea(
      bottom: false,
      child: PureAppBar(
        title: label ?? '',
        leading: back,
        actions: actions ?? const <Widget>[],
        height: pureSettingsBarHeight,
      ),
    );
  }

  /// The back affordance, mirrored in RTL and labelled the way pure_uikit's own
  /// implied button is — from the Material localizations, which the delegates
  /// pure_uikit ships install under every host.
  Widget? _backButton(BuildContext context) {
    final onBack = this.onBack;
    if (onBack == null) return null;
    final localizations = Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return PureIconButton(
      icon: isRtl ? Icons.arrow_forward : Icons.arrow_back,
      tooltip: localizations?.backButtonTooltip ?? '',
      onPressed: onBack,
    );
  }
}

/// The bar for a title that is not a [Text]: a token-styled row, since
/// [PureAppBar] takes a string and dropping the widget is not an option.
class _PureWidgetBar extends StatelessWidget {
  const new({required this.title, this.leading, this.actions});

  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        height: pureSettingsBarHeight,
        color: theme.colors.bgElevated,
        padding: const EdgeInsetsDirectional.only(start: PureSpacing.sm, end: PureSpacing.md),
        child: Row(
          children: [
            ?leading,
            Expanded(
              child: DefaultTextStyle(
                style: theme.text.title.copyWith(color: theme.colors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Semantics(header: true, container: true, child: title),
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}
