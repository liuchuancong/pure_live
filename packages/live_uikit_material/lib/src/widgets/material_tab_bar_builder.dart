import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// `mu.TabBar` is the fork's own strip — the sliding indicator and the label
/// weight are what make a Material tab read as one — but it is driven by a
/// [mu.TabController] rather than by an index, so the controller lives here and
/// the spec's index is asserted onto it on every change. The strip stays
/// controlled: a tap reports the index and the caller's next rebuild moves the
/// indicator to wherever the spec says, which is also how a refused tap is undone.
///
/// [LanguageTabsSpec.spacing] has no Material counterpart, so the strip is left
/// with the library's own tab padding.
abstract final class MaterialTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) => _ControlledTabBar(spec: spec);
}

class _ControlledTabBar extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabsSpec spec;

  @override
  State<_ControlledTabBar> createState() => _ControlledTabBarState();
}

class _ControlledTabBarState extends State<_ControlledTabBar> with SingleTickerProviderStateMixin {
  late mu.TabController _controller = _make();

  mu.TabController _make() => mu.TabController(length: widget.spec.tabs.length, vsync: this);

  @override
  void didUpdateWidget(_ControlledTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.tabs.length != widget.spec.tabs.length) {
      _controller.dispose();
      _controller = _make();
    }
    final index = widget.spec.index;
    if (index >= 0 && index < widget.spec.tabs.length && _controller.index != index) {
      _controller.index = index;
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
    final select = spec.enabled ? spec.onChanged : null;
    return mu.TabBar(
      controller: _controller,
      isScrollable: spec.tabs.length > 5,
      tabs: [for (final tab in spec.tabs) mu.Tab(text: tab.label, icon: tab.icon == null ? null : Icon(tab.icon))],
      onTap: select,
    );
  }
}
