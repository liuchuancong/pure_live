import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic select control from a [LanguageSelectSpec] (§9 Select).
///
/// **Composed, and composed to be inline.** The library carries no dropdown: its
/// surfaces are containers, buttons, fields and a bottom bar, so the control is
/// built out of those — the field is the library's own interactive plane
/// (`NeuContainer`, flat when shut and [neu.NeuShape.pressed] once open, because
/// a recessed surface is how this style says "you are inside me"), and the option
/// list is a dish ([neu.NeuShape.concave]) of cells under it, the chosen value
/// pushed back out as a dome ([neu.NeuShape.convex]) with the theme's accent on
/// its label. Colours, radius and depth are all read off [neu.NeuTheme.of].
///
/// The list opens *inside the tree* rather than in a popover on purpose: the core
/// owns the overlay and asks the language for a control body it can place anywhere
/// (§9 Toast says the same about the transient surface), so this widget must render
/// with no `ScaffoldMessenger`, no `Navigator`, no overlay controller and no
/// animated ancestor. A popup menu would need one of those — the library offers no
/// anchored popover of its own, and Material's would be another language's surface
/// borrowed into a Neumorphic page. The cost is honest: the caller reserves the
/// room the open list takes, and it closes on a choice or a second tap on the
/// field.
///
/// [LanguageSelectSpec.placeholder] is the shut field's text when nothing is
/// selected; `enabled: false` or a null `onChanged` leaves a field that greys and
/// will not open, which is the library's inert state. The spec's value is matched
/// by identity against [LanguageSelectSpec.items], so an off-list value reads as
/// "nothing selected" rather than as a phantom row.
abstract final class NeumorphicSelectBuilder {
  /// Builds the select control for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) => _SelectField<T>(spec: spec);
}

class _SelectField<T> extends StatefulWidget {
  const new({required this.spec});

  final LanguageSelectSpec<T> spec;

  @override
  State<_SelectField<T>> createState() => _SelectFieldState<T>();
}

class _SelectFieldState<T> extends State<_SelectField<T>> {
  bool _open = false;

  bool get _interactive => widget.spec.enabled && widget.spec.onChanged != null;

  void _toggle() => setState(() => _open = !_open);

  void _choose(T item) {
    if (!_interactive) {
      return;
    }
    setState(() => _open = false);
    widget.spec.onChanged?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final radius = surface.borderRadius.resolve(Directionality.of(context));
    final inset = theme.token.scale.sizes.xs;
    final cellRadius = BorderRadius.circular(radius.topLeft.x <= inset ? 0.0 : radius.topLeft.x - inset);
    final selected = spec.items.contains(spec.value) ? spec.value : null;
    final label = selected == null ? (spec.placeholder ?? '') : spec.itemLabel(selected);
    final tint = spec.enabled ? theme.colors.text : theme.colors.textDisabled;

    final field = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _interactive ? _toggle : null,
      child: neu.NeuContainer(
        shape: _open ? neu.NeuShape.pressed : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: _open ? 2.0 : surface.depth,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text.body.copyWith(color: tint),
              ),
            ),
            Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: spec.enabled ? surface.accentColor : theme.colors.textDisabled,
              size: theme.text.body.fontSize,
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        if (_open) ...[
          SizedBox(height: inset),
          neu.NeuContainer(
            shape: neu.NeuShape.concave,
            borderRadius: radius,
            baseColor: surface.baseColor,
            depth: 2,
            padding: EdgeInsets.all(inset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in spec.items)
                  _Option(
                    text: spec.itemLabel(item),
                    selected: item == selected,
                    onTap: () => _choose(item),
                    radius: cellRadius,
                    surface: surface,
                    theme: theme,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const new({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius radius;
  final neu.NeuThemeData surface;
  final LiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.convex : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.text.body.copyWith(
            color: selected ? surface.accentColor : theme.colors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
