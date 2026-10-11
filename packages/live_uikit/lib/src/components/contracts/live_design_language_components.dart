import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';

/// One design language's implementation of the component contract.
///
/// Every method takes the *normalized* spec of a component and returns the
/// widget that language draws for it. A language implements this interface
/// once (`MaterialComponents`, `CupertinoComponents`, …); pages never
/// branch on the language, and languages never see business types — only
/// specs, strings and callbacks.
///
/// The interface grows as components are added to the contract, in the same
/// order as `components/`: Phase 2 covers buttons, inputs, cards, menus,
/// dialogs and the state views, and later phases add navigation, tabs,
/// lists and the TV-specific layouts.
abstract interface class LiveDesignLanguageComponents {
  /// The language's button.
  Widget button(BuildContext context, LiveButtonSpec spec);

  /// The language's icon button.
  Widget iconButton(BuildContext context, LiveIconButtonSpec spec);

  /// The language's single-line text field.
  Widget textField(BuildContext context, LiveTextFieldSpec spec);

  /// The language's search field.
  Widget searchField(BuildContext context, LiveSearchFieldSpec spec);

  /// The language's card surface.
  Widget card(BuildContext context, LiveCardSpec spec);

  /// The language's menu, anchored at [LiveMenuSpec.child].
  Widget menu(BuildContext context, LiveMenuSpec spec);

  /// Shows the language's dialog and completes with the chosen action's
  /// result, or null when the dialog was dismissed.
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec);

  /// The language's progress indicator.
  Widget progressIndicator(BuildContext context, LiveProgressIndicatorSpec spec);

  /// The language's full-view loading state.
  Widget loadingView(BuildContext context, LiveLoadingViewSpec spec);

  /// The language's full-view error state.
  Widget errorView(BuildContext context, LiveErrorViewSpec spec);

  /// The language's full-view empty state.
  Widget emptyView(BuildContext context, LiveEmptyViewSpec spec);
}
