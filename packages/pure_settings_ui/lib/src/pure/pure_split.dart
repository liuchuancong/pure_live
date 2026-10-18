import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_page_bar.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_metrics.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/split_pane_style.dart';

/// How the pure style draws the panes of a split view.
///
/// The list pane is a card list under a [PurePageBar], not a sidebar. None of
/// the four languages this style serves is a desktop toolkit with a settings
/// sidebar of its own to imitate, and a card list is how forui, glass,
/// neumorphic and wind group rows anyway — so the tiles keep drawing their
/// usual rows ([SplitPaneStyle.sidebar] stays false) and the detail pane fills,
/// as it does for iPad and Android Settings.
///
/// It is public only because the vendored `SplitPaneStyle.of` factory, which
/// lives in the vendor tree, has to name it; the barrel does not export it.
class PurePaneStyle extends SplitPaneStyle {
  /// The pure style for a view laid out as [geometry] says.
  const new(super.platform, super.geometry);

  @override
  EdgeInsetsGeometry? get listPadding => isSplit ? const EdgeInsets.only(bottom: pureSettingsBottomPadding) : null;

  @override
  Widget buildListPane(SplitListPaneParts pane) => settingsHeaderOverBody(
    pane.viewContext,
    header: PurePageBar(title: pane.title, onBack: pane.onBack),
    body: pane.list,
  );
}
