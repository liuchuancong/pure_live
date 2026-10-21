import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_uikit/pure_uikit.dart';

// Desktop pages of the browsing lists (the reference's `shared/rooms/paging.dart`,
// v5): popular, follows, areas and area rooms show numbered pages on wide
// windows; phones and narrow windows grow the list at its end.

/// Rooms of the first phone load and of each "load more" (the reference's
/// phone page size).
const int phonePageSize = 20;

/// The window width from which lists page instead of grow (the reference:
/// wider than 680 and not a phone).
bool usesDesktopPages(double width, {required bool isPhone}) => width > 680 && !isPhone;

/// [usesDesktopPages] with the running device's answer for "phone" — the
/// booted form factor, so a phone turned sideways keeps growing its list.
bool desktopPagesIn(WidgetRef ref, double width) =>
    usesDesktopPages(width, isPhone: ref.watch(environmentProvider).runtime.formFactor == FormFactor.phone);

/// Rooms per desktop page and the choices (the reference's
/// `PageSettingsController`: 0 or a missing size means 20 above 960 px,
/// else 12; the stored option text overrides the width rule).
({int size, List<int> options}) pageSizesOf(AppPreferences preferences, double width) {
  final wide = width > 960;
  final parsed = parsePageSizeOptions(preferences.pageSizeOptions);
  final options = parsed.isEmpty ? (wide ? const [20, 40, 60, 80] : const [12, 24, 36, 48]) : parsed;
  final stored = preferences.pageDefaultSize;
  final size = stored > 0 && options.contains(stored) ? stored : (stored > 0 ? options.first : (wide ? 20 : 12));
  return (size: size, options: options.contains(size) ? options : ([...options, size]..sort()));
}

/// The stored option text as numbers (1..100, unique, ascending); empty
/// means the width rule (the reference's `PageSizeOptionsTile.parse`).
List<int> parsePageSizeOptions(String raw) => [
  ...{
    for (final part in raw.split(','))
      if (int.tryParse(part.trim()) case final value? when value >= 1 && value <= 100) value,
  },
]..sort();

/// The desktop page bar (the reference's `PaginationBar`): refresh, previous,
/// page numbers, next, rooms per page and "go to page" — every control in
/// pure_uikit's own widgets so the bar re-skins with the design language.
class PurePaginationBar extends StatefulWidget {
  /// Creates the bar.
  const new({
    required this.page,
    required this.lastPage,
    required this.canNext,
    required this.busy,
    required this.pageSize,
    required this.pageSizes,
    required this.showGoto,
    required this.onPage,
    required this.onPageSize,
    required this.onRefresh,
    super.key,
  });

  /// The page shown.
  final int page;

  /// The last page once there are known to be no more; null while unknown.
  final int? lastPage;

  /// Whether a next page exists or may exist.
  final bool canNext;

  /// A request is running.
  final bool busy;

  /// Rooms per page.
  final int pageSize;

  /// The page-size choices; null hides the selector (setting).
  final List<int>? pageSizes;

  /// Shows "go to page" (setting `pageShowGoto`).
  final bool showGoto;

  /// Go to a page.
  final ValueChanged<int> onPage;

  /// Pick rooms per page.
  final ValueChanged<int> onPageSize;

  /// Refresh.
  final VoidCallback onRefresh;

  @override
  State<PurePaginationBar> createState() => _PurePaginationBarState();
}

class _PurePaginationBarState extends State<PurePaginationBar> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _jump() {
    final target = int.tryParse(_input.text.trim());
    if (target == null || target < 1) {
      return;
    }
    final last = widget.lastPage;
    widget.onPage(last != null && target > last ? last : target);
    _input.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final t = context.t;
    final current = widget.page;
    final last = widget.lastPage;
    final busy = widget.busy;
    Widget dots() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text('...', style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
    );
    Widget number(int page) {
      final selected = page == current;
      final enabled = !selected && !busy;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: PureBox(
          key: ValueKey('pager-page-$page'),
          onTap: enabled ? () => widget.onPage(page) : null,
          style: (state) => Style(
            background: selected
                ? theme.colors.primary
                : state == InteractionState.hovered || state == InteractionState.pressed
                ? theme.colors.fillTertiary
                : null,
            foreground: selected ? theme.colors.textLightSolid : theme.colors.text,
            borderRadius: BorderRadius.circular(6),
            borderWidth: 1,
            borderColor: selected ? theme.colors.primary : theme.colors.border,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
            alignment: Alignment.center,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
          child: Text('$page', style: theme.text.bodySmall),
        ),
      );
    }

    // 1, (dots), current-1..current+1 clamped, (dots), last — the reference's
    // window: the first and the last page stay reachable while the middle
    // slides with the selection.
    final pages = <Widget>[number(1)];
    if (current > 3) {
      pages.add(dots());
    }
    var end = current + 1;
    if (last != null && end >= last) {
      end = last - 1;
    }
    for (var page = current - 1 < 2 ? 2 : current - 1; page <= end; page++) {
      if (last == null && !widget.canNext && page > current) {
        break;
      }
      pages.add(number(page));
    }
    if (last != null && last > 1) {
      if (end < last - 1) {
        pages.add(dots());
      }
      pages.add(number(last));
    } else if (last == null && widget.canNext) {
      pages.add(dots());
    }

    final sizes = widget.pageSizes;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('pager'),
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            decoration: BoxDecoration(
              color: theme.colors.bgElevated,
              border: Border(top: BorderSide(color: theme.colors.border.withValues(alpha: 0.6))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PureButton(
                  label: t.common.refresh,
                  icon: Icons.refresh,
                  size: ControlSize.sm,
                  variant: ButtonVariant.secondary,
                  onPressed: busy ? null : widget.onRefresh,
                ),
                const SizedBox(width: 8),
                PureButton(
                  label: t.common.prevPage,
                  size: ControlSize.sm,
                  variant: ButtonVariant.ghost,
                  onPressed: current > 1 && !busy ? () => widget.onPage(current - 1) : null,
                ),
                const SizedBox(width: 8),
                ...pages,
                const SizedBox(width: 8),
                PureButton(
                  label: t.common.nextPage,
                  size: ControlSize.sm,
                  variant: ButtonVariant.ghost,
                  loading: busy,
                  onPressed: widget.canNext && !busy ? () => widget.onPage(current + 1) : null,
                ),
                if (sizes != null) ...[
                  const SizedBox(width: 24),
                  Text(t.common.perPage, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
                  const SizedBox(width: 6),
                  SizedBox(
                    key: const ValueKey('pager-size'),
                    width: 92,
                    child: PureSelect<int>(
                      items: sizes,
                      value: widget.pageSize,
                      itemLabel: (size) => '$size',
                      onChanged: widget.onPageSize,
                    ),
                  ),
                ],
                if (widget.showGoto) ...[
                  const SizedBox(width: 24),
                  Text(t.common.goTo, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      key: const ValueKey('pager-goto'),
                      width: 56,
                      child: PureTextField(
                        controller: _input,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _jump(),
                        onChanged: (text) {
                          // Digits only, the reference's input formatter: a
                          // paste of letters is stripped as it lands.
                          final digits = text.replaceAll(RegExp(r'\D'), '');
                          if (digits != text) {
                            _input.text = digits;
                            _input.selection = TextSelection.collapsed(offset: digits.length);
                          }
                        },
                      ),
                    ),
                  ),
                  Text(t.common.pageUnit, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How far a list scrolls before "to top" shows (the reference: 400).
const double jumpButtonsThreshold = 400;

/// "To top" and "to bottom" over a list once it scrolls (the reference's
/// `JumpButtons`): neither before the list first moves, then "to top" past
/// [jumpButtonsThreshold] and "to bottom" while more than that remains.
class PureJumpButtons extends StatefulWidget {
  /// Creates the buttons for [controller].
  const new({required this.controller, required this.heroTag, super.key});

  /// The list's position.
  final ScrollController controller;

  /// Unique per page (two lists may be alive at once).
  final String heroTag;

  @override
  State<PureJumpButtons> createState() => _PureJumpButtonsState();
}

class _PureJumpButtonsState extends State<PureJumpButtons> {
  bool _top = false;
  bool _bottom = false;

  /// Whether the list has moved since the buttons came: a list that opens
  /// at its top shows no "to bottom" until the user scrolls.
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // A list that comes back already scrolled (a kept offset) counts as
    // scrolled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(PureJumpButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _scrolled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    _scrolled = true;
    _sync();
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    final controller = widget.controller;
    if (!controller.hasClients || controller.positions.length != 1) {
      if (_top || _bottom) {
        setState(() => _top = _bottom = false);
      }
      return;
    }
    final position = controller.position;
    if (!_scrolled && position.hasPixels && position.pixels > position.minScrollExtent) {
      _scrolled = true;
    }
    final top = _scrolled && position.pixels > jumpButtonsThreshold;
    final bottom = _scrolled && position.maxScrollExtent - position.pixels > jumpButtonsThreshold;
    if (top != _top || bottom != _bottom) {
      setState(() {
        _top = top;
        _bottom = bottom;
      });
    }
  }

  void _jump({required bool up}) {
    final controller = widget.controller;
    if (!controller.hasClients) {
      return;
    }
    final target = up ? 0.0 : controller.position.maxScrollExtent;
    final distance = (target - controller.offset).abs();
    controller.animateTo(
      target,
      duration: Duration(milliseconds: (180 + distance / 8).round().clamp(220, 520)),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget button({required bool shown, required bool up}) => AnimatedScale(
      scale: shown ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !shown,
        child: PureIconButton(
          key: ValueKey('jump-${widget.heroTag}-${up ? 'top' : 'bottom'}'),
          tooltip: up ? t.common.toTop : t.common.toBottom,
          icon: up ? Icons.vertical_align_top : Icons.vertical_align_bottom,
          variant: ButtonVariant.secondary,
          onPressed: shown ? () => _jump(up: up) : null,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(shown: _top, up: true),
        button(shown: _bottom, up: false),
      ],
    );
  }
}
