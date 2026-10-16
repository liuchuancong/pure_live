import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds the page switcher a glass tab strip drives, from a
/// [LanguageTabViewSpec] (§9 Tab view).
///
/// Composed, not mapped: the library ships no page switcher — `glass_morphism_plus`
/// 0.1.0 publishes surfaces (`GlassContainer`/`GlassTile`/`GlassDivider`), four
/// controls and a Material `GlassAppBar`, and nothing that pages or slides.
///
/// The trade-off, stated because the languages differ on it: iOS *swipes* between
/// tab pages, and this language is the frosted reading of iOS, so the view keeps
/// the shape change and rides the framework's own `PageView` (available from
/// `package:flutter/widgets.dart`, so no Material renderer is borrowed) on a
/// frosted [glass.GlassContainer] sheet, with `ClipRRect` inside the container
/// clipping a page as it slides past the rounded corner. Fluent answers the same
/// spec with an in-place cross-fade because Windows replaces a tab body without
/// moving it; here the slide is the idiom, which is also why
/// [LanguageTabViewSpec.onIndexChanged] is honoured — a glass viewer *can* move a
/// page with a finger, and reports it back.
///
/// The view is the surface only, like every other builder in this package: the
/// index stays the caller's. [LanguageTabViewSpec.index] is followed by animating
/// to it over [LanguageTabViewSpec.duration] rather than by jumping, so a strip
/// tap and a swipe both read as one motion.
abstract final class GlassTabViewBuilder {
  /// Builds the tab view for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _GlassTabView(spec: spec);
}

class _GlassTabView extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  State<_GlassTabView> createState() => _GlassTabViewState();
}

class _GlassTabViewState extends State<_GlassTabView> {
  late final PageController _controller = PageController(initialPage: _clamped(widget.spec));

  int _clamped(LanguageTabViewSpec spec) => spec.pages.isEmpty
      ? 0
      : spec.index.clamp(0, spec.pages.length - 1);

  @override
  void didUpdateWidget(_GlassTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spec = widget.spec;
    if (spec.pages.isEmpty || oldWidget.spec.index == spec.index) {
      return;
    }
    final target = _clamped(spec);
    if (_controller.hasClients && _controller.page != target.toDouble()) {
      _controller.animateToPage(target, duration: spec.duration, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    // A swipe is the point of this view, so it is only allowed where the caller
    // can hear about it and there is more than one page to reach.
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;

    return glass.GlassContainer(
      blur: glassTheme.blur,
      opacity: glassTheme.opacity,
      borderRadius: glassTheme.borderRadius,
      color: glassTheme.color,
      elevation: glassTheme.elevation,
      shadowColor: glassTheme.shadowColor ?? theme.colors.shadowBase,
      padding: EdgeInsets.all(sizes.sm),
      child: PageView(
        controller: _controller,
        physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: swipeable ? spec.onIndexChanged : null,
        children: spec.pages,
      ),
    );
  }
}
