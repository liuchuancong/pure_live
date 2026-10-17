import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted dropdown from a [LanguageSelectSpec] (§9 Select).
///
/// Composed, not mapped: `glass_morphism_plus` carries no select, and an
/// overlay-anchored popup is not what this contract asks of the builder — it asks
/// for a widget that renders where it is placed, and the caller owns the overlay.
/// So the field is a [glass.GlassContainer] sheet with the chosen label (or
/// [LanguageSelectSpec.placeholder]) and the token's glyph, and choosing opens the
/// option list as a second frosted sheet *in flow*, under the field. The list
/// pushes the page rather than floating over it, which is the one behaviour a glass
/// surface can do without taking the caller's overlay (§15); it is capped and
/// scrollable, so a long list cannot run the page off the screen.
///
/// Being composed also means there is nothing to guard: the builder asserts
/// nothing about [LanguageSelectSpec.items], so duplicate, null or off-list values
/// draw as rows rather than throwing.
abstract final class GlassSelectBuilder {
  /// Builds the select for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) => _GlassSelect<T>(spec: spec);
}

class _GlassSelect<T> extends StatefulWidget {
  const new({required this.spec});

  final LanguageSelectSpec<T> spec;

  @override
  State<_GlassSelect<T>> createState() => _GlassSelectState<T>();
}

class _GlassSelectState<T> extends State<_GlassSelect<T>> {
  bool _open = false;

  void _choose(T item) {
    setState(() => _open = false);
    widget.spec.onChanged?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final spec = widget.spec;
    final interactive = spec.enabled && spec.onChanged != null;
    final radius = BorderRadius.circular(glassTheme.borderRadius);
    final selected = spec.value;
    final label = selected == null ? (spec.placeholder ?? '') : spec.itemLabel(selected);

    void toggle() {
      if (interactive) {
        setState(() => _open = !_open);
      }
    }

    final field = glass.GlassContainer(
      customBorderRadius: radius,
      child: LiveBox(
        style: (state) => Style(
          borderRadius: radius,
          minHeight: theme.select.height,
          background: switch (state) {
            InteractionState.hovered ||
            InteractionState.pressed ||
            InteractionState.focused => glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
            _ => null,
          },
          opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
        ),
        onTap: interactive ? toggle : null,
        enabled: spec.enabled,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.select.paddingInline),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.body.copyWith(
                    color: selected == null ? theme.colors.textPlaceholder : theme.colors.text,
                  ),
                ),
              ),
              SizedBox(width: theme.token.scale.sizes.xs),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: theme.text.body.fontSize! * 1.4,
                color: theme.colors.icon,
              ),
            ],
          ),
        ),
      ),
    );

    if (!_open) {
      return Semantics(button: true, expanded: _open, child: field);
    }
    return Semantics(
      button: true,
      expanded: _open,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.xs),
            child: SizedBox(
              width: double.infinity,
              child: glass.GlassContainer(
                customBorderRadius: radius,
                padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xxs),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in spec.items)
                          LiveBox(
                            style: (state) => Style(
                              background: switch (state) {
                                InteractionState.hovered ||
                                InteractionState.pressed => theme.select.itemHoverBackground,
                                _ when item == selected => theme.select.itemSelectedBackground,
                                _ => null,
                              },
                            ),
                            onTap: () => _choose(item),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.select.paddingInline,
                                vertical: theme.token.scale.sizes.xs,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      spec.itemLabel(item),
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.text.body.copyWith(
                                        color: theme.colors.text,
                                        fontWeight: item == selected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (item == selected) ...[
                                    SizedBox(width: theme.token.scale.sizes.xs),
                                    Icon(Icons.check, size: theme.text.body.fontSize, color: theme.colors.primary),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
