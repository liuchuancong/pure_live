import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/focus/live_focus_scope.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// Scrolls the focused item of a list or row into view.
///
/// Flutter reveals a focused widget only through `Scrollable.ensureVisible`,
/// which nothing calls on its own: a TV user pressing down at the bottom of a
/// grid moves the highlight off screen and the picture stops following them.
/// Wrapping a list in this widget fixes that in one place, for every list,
/// horizontal rows included — the reveal walks up all the scrollables between
/// the item and the root, so a card in a horizontal row inside a vertical
/// page is revealed in both directions.
///
/// The reveal is skipped while the environment says animations are off, so
/// reduced-motion builds jump rather than glide.
class LiveFocusReveal extends StatefulWidget {
  /// A reveal-on-focus wrapper around [child].
  const new({required this.child, this.alignment = 0.5, this.margin = const EdgeInsets.all(24), super.key});

  /// The scrollable content.
  final Widget child;

  /// Where in the viewport the focused item should end up, 0 being the
  /// leading edge.
  final double alignment;

  /// The space kept around the item, so a focus ring or a scaled card is not
  /// clipped at the edge.
  final EdgeInsets margin;

  @override
  State<LiveFocusReveal> createState() => _LiveFocusRevealState();
}

class _LiveFocusRevealState extends State<LiveFocusReveal> {
  late final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'live-uikit reveal scope');
  FocusManager? _manager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _manager?.removeListener(_onFocusChange);
    _manager = FocusManager.instance;
    _manager?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _manager?.removeListener(_onFocusChange);
    _scope.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary is FocusScopeNode || !_isInside(primary)) {
      return;
    }
    final context = primary.context;
    if (context == null || !context.mounted) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      alignment: widget.alignment,
      duration: LiveTheme.maybeOf(context)?.normal ?? Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  bool _isInside(FocusNode node) {
    for (final ancestor in node.ancestors) {
      if (identical(ancestor, _scope)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => FocusScope(node: _scope, child: widget.child);
}

/// The TV page frame: big margins, a display-size title and a focus scope.
///
/// It is deliberately not "a desktop page with bigger fonts": the padding
/// comes from the spacious density, the type scale from the TV configuration,
/// and the focus scope gives the page the focus memory a remote needs
/// (`restore` puts the highlight back on the row the user left). The page's
/// own structure — one large row per section, big cards, no side rail — is
/// the page's business; this only fixes the frame.
///
/// A TV page's cards are `LiveCard`s like everywhere else: the TV focus
/// scaling and glow come from the focus tokens, so there is no separate TV
/// card component to drift out of sync with the others.
class LiveTvScaffold extends StatelessWidget {
  /// A TV page frame.
  const new({required this.child, this.title, this.actions = const [], this.background, this.padding, super.key});

  /// The page's content.
  final Widget child;

  /// The page title, drawn at display size.
  final String? title;

  /// Trailing actions of the header (a search button, a refresh, a clock).
  final List<Widget> actions;

  /// Overrides the background; the TV page gradient is the default.
  final Widget? background;

  /// Overrides the page padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final inset = padding ?? geometry.pagePaddingWide;
    final header = title == null && actions.isEmpty
        ? null
        : Padding(
            padding: EdgeInsets.only(bottom: geometry.sectionGap),
            child: Row(
              children: [
                if (title case final title?) Expanded(child: Text(title, style: theme.typography.display)),
                ...actions,
              ],
            ),
          );
    return LiveFocusScope(
      child: ColoredBox(
        color: theme.colors.surface,
        child: Padding(
          padding: inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?header,
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
