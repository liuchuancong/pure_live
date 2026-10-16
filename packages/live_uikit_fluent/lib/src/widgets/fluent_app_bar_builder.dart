import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent page header from a [LanguageAppBarSpec] (§9 AppBar).
///
/// `fluent.PageHeader` is the library's own page bar — the one slot
/// `ScaffoldPage.header` is designed to take — with a leading widget, a title and
/// a command area. The contract's [LanguageAppBarSpec.actions] are arbitrary
/// widgets while Fluent's command bar takes items it builds itself, so the
/// actions go into the header's `commandBar` slot as a row rather than through
/// `CommandBar`, which would have to be handed icons and callbacks the spec does
/// not carry.
///
/// Two fields have no Fluent counterpart and are handled rather than dropped:
/// [LanguageAppBarSpec.bottom] is stacked under the header in a column, because
/// a Fluent page has one header row; [LanguageAppBarSpec.centerTitle] and
/// [LanguageAppBarSpec.height] are not mapped — a Fluent header is left-titled
/// and content-sized, and centring it would be the app bar saying something about
/// iOS rather than about the caller.
abstract final class FluentAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final typography = fluent.FluentTheme.of(context).typography;
    final header = fluent.PageHeader(
      leading: spec.leading,
      title: Text(spec.title, style: typography.title),
      commandBar: spec.actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: spec.actions),
    );

    final bar = spec.bottom == null ? header : Column(mainAxisSize: MainAxisSize.min, children: [header, spec.bottom!]);

    if (spec.background == null) {
      return bar;
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: spec.background),
      child: bar,
    );
  }
}
