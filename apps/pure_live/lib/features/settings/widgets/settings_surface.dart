import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/providers/app_providers.dart' show environmentProvider;
import 'package:pure_uikit/pure_uikit.dart';

/// A settings surface: the same body and the same actions, centred on a desktop
/// window and rising from the bottom edge on a handheld.
///
/// Where the split comes from: a dialog is the right shape when the pointer can
/// rest anywhere on the screen — it holds the body still and leaves the row that
/// opened it where it was. On a phone the body is something the thumb scrolls, and
/// a box floating in the middle of the glass sits between the two things the viewer
/// is looking at: the row they pressed, below, and the option they are reading,
/// above. So it rises from that edge instead.
///
/// [body] is built with the **surface's** context, and so is every action: both
/// routes sit on the root navigator, above whatever router the page lives under,
/// so a `Navigator.of(pageContext).pop()` would close the page and leave the
/// surface open. A body that brings its own scroll view is the other thing to
/// avoid — this function owns the scroll view and the height cap for both
/// surfaces, and a nested one is unbounded.
///
/// [formFactor] is the booted environment's, taken once when the surface opens:
/// the window is not going to change shape while a sheet is up. Both a widget's
/// `ref` and a service's `Ref` answer it through the `settingsFormFactor` getter
/// below, so a prompt raised from outside the tree (the clipboard watcher) gets
/// the same split as one raised from a row.
Future<T?> showSettingsSurface<T>(
  BuildContext context,
  FormFactor formFactor, {
  required String? title,
  required Widget Function(BuildContext surfaceContext) body,
  List<Widget> Function(BuildContext surfaceContext)? actions,
  bool dismissible = true,
}) => switch (formFactor) {
  FormFactor.phone || FormFactor.tablet => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    builder: (surfaceContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(surfaceContext).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: PureTheme.of(surfaceContext).text.title),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.only(bottom: 8), child: body(surfaceContext)),
              ),
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions(surfaceContext)),
              ),
          ],
        ),
      ),
    ),
  ),
  FormFactor.desktop || FormFactor.tv => showPureDialog<T>(
    context: context,
    title: title,
    dismissible: dismissible,
    actions: actions,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Builder(builder: body),
    ),
  ),
};

/// The form factor a surface should open in, for a widget's [WidgetRef].
extension SettingsSurfaceRef on WidgetRef {
  /// The booted environment's shape.
  FormFactor get settingsFormFactor => read(environmentProvider).runtime.formFactor;
}

/// The same fact for a service's [Ref], which has no widget to ask.
extension SettingsSurfaceServiceRef on Ref {
  /// The booted environment's shape.
  FormFactor get settingsFormFactor => read(environmentProvider).runtime.formFactor;
}
