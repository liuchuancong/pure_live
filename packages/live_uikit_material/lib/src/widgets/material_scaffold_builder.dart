import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// The fork's `Scaffold` takes the spec's parts as they are named: the bar in
/// the app-bar slot, the bottom bar, the floating action, the keyboard policy
/// and the extend-behind-bar choice.
///
/// The bar and the bottom strip arrive as already-dispatched widgets, and
/// `Scaffold` asks for a `PreferredSizeWidget` in both slots — so one that is
/// one goes straight in, and a foreign one (a token bar, or another language's
/// rendering inside a mixed tree) is given the height its own frame would have
/// used. Material then owns the body's extent, safe area and scroll-under
/// behaviour, which is what this language exists to get.
abstract final class MaterialScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    return mu.Scaffold(
      appBar: _bar(spec.appBar, geometry?.appBarHeight ?? 56),
      body: spec.body,
      bottomNavigationBar: _bar(spec.bottomBar, geometry?.navBarHeight ?? 64),
      floatingActionButton: spec.floatingActionButton,
      extendBodyBehindAppBar: spec.extendBodyBehindAppBar,
      resizeToAvoidBottomInset: spec.avoidKeyboard,
      backgroundColor: spec.background,
    );
  }

  static mu.PreferredSizeWidget? _bar(Widget? widget, double height) => switch (widget) {
    null => null,
    final mu.PreferredSizeWidget sized => sized,
    final child => mu.PreferredSize(preferredSize: Size.fromHeight(height), child: child),
  };
}
