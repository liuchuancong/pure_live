import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';

/// The visual language the settings previews share with the wallpaper preview
/// page: a black stage with a chip in its corner and round controls floating
/// over it, under a heading led by a tinted icon tile.

/// Below this width a preview stacks its controls under the stage instead of
/// placing them beside it.
const double kSettingsPreviewWideBreakpoint = 900;

/// A settings sample shown full-window, in the wallpaper preview page's frame:
/// the sample in a dark stage with the controls that shape it beside it, and
/// on a narrow window the same stage over the controls, which take the lower
/// half while they are open.
///
/// Only the frame lives here. Each preview brings its own sample and its own
/// controls, so the wallpaper, danmaku and room-card previews read as one
/// feature without sharing a subject.
final class SettingsPreviewPage extends StatefulWidget {
  /// The page showing [stage] with [settings].
  const SettingsPreviewPage({
    required this.icon,
    required this.title,
    required this.stage,
    required this.settings,
    this.subtitle,
    this.footer,
    super.key,
  });

  /// The icon tile in the sidebar's heading.
  final DsIconData icon;

  /// What the preview shows.
  final String title;

  /// The state beside the subject, e.g. the active preset.
  final String? subtitle;

  /// The sample, filling the stage. The caller draws its own chip and
  /// controls over it.
  final Widget stage;

  /// The controls that shape the sample, laid out as the settings pages lay
  /// their rows out.
  final Widget settings;

  /// An action row under the controls on a wide window, or under the lower
  /// half's controls on a narrow one. Previews whose changes are instant leave
  /// it out.
  final Widget? footer;

  @override
  State<SettingsPreviewPage> createState() => _SettingsPreviewPageState();
}

final class _SettingsPreviewPageState extends State<SettingsPreviewPage> {
  /// On a narrow window the controls start folded away, so the sample opens
  /// full-height; opening them takes the lower half and lifts the sample.
  bool _settingsOpen = false;

  @override
  Widget build(BuildContext context) {
    // The frame follows the app's light or dark skin; only the stage itself
    // stays black, because the sample — not the shell — owns those colours.
    final colors = DsTheme.colorsOf(context);
    final wide = MediaQuery.sizeOf(context).width >= kSettingsPreviewWideBreakpoint;
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(child: wide ? _wide(context) : _narrow(context)),
    );
  }

  Widget _wide(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 920),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 56, offset: Offset(0, 28))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpace.s16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ColoredBox(color: const Color(0xFF000000), child: widget.stage),
                      ),
                    ),
                  ),
                  Container(
                    width: 380,
                    decoration: BoxDecoration(
                      border: BorderDirectional(start: BorderSide(color: colors.border)),
                    ),
                    child: _controls(context, collapsible: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The narrow layout: the sample full-height with the controls folded away,
  /// and the controls over the lower half once opened. The sample keeps the
  /// upper half, so it moves up as the controls arrive.
  Widget _narrow(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.stage,
                PositionedDirectional(
                  top: DsSpace.s8,
                  start: DsSpace.s8,
                  child: SettingsPreviewCircleButton(
                    icon: DsIcons.chevronLeft,
                    semanticLabel: t.common.back,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                PositionedDirectional(
                  top: DsSpace.s8,
                  end: DsSpace.s8,
                  child: SettingsPreviewCircleButton(
                    icon: DsIcons.slidersHorizontal,
                    semanticLabel: t.settings.backgroundPreviewSettingsTitle,
                    selected: _settingsOpen,
                    onPressed: () => setState(() => _settingsOpen = !_settingsOpen),
                  ),
                ),
              ],
            ),
          ),
          if (_settingsOpen)
            SizedBox(
              height: constraints.maxHeight * 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: BorderDirectional(top: BorderSide(color: colors.border)),
                ),
                child: _controls(context, collapsible: true),
              ),
            ),
        ],
      ),
    );
  }

  /// The heading, the scrollable controls and the optional footer: the wide
  /// window's sidebar, and the narrow window's lower half. Only the narrow
  /// layout can fold the controls away, so [collapsible] decides whether the
  /// heading's button folds them or closes the page.
  Widget _controls(BuildContext context, {required bool collapsible}) {
    final footer = widget.footer;
    final folded = collapsible && _settingsOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsPreviewHeading(
          icon: widget.icon,
          title: widget.title,
          subtitle: widget.subtitle,
          trailing: DsButton.icon(
            variant: DsButtonVariant.ghost,
            onPressed: () => folded ? setState(() => _settingsOpen = false) : Navigator.of(context).pop(),
            icon: DsIcon(folded ? DsIcons.chevronDown : DsIcons.close),
            semanticLabel: context.t.common.close,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: widget.settings,
          ),
        ),
        if (footer != null) Padding(padding: const EdgeInsets.all(DsSpace.s20), child: footer),
      ],
    );
  }
}

/// A preview's heading: the tinted icon tile the wallpaper page's sidebar
/// leads with, the subject over a muted line, and an optional control.
final class SettingsPreviewHeading extends StatelessWidget {
  /// The heading for [title].
  const SettingsPreviewHeading({required this.icon, required this.title, this.subtitle, this.trailing, super.key});

  /// The tile's icon.
  final DsIconData icon;

  /// What the preview shows.
  final String title;

  /// The state beside the subject, e.g. the active preset.
  final String? subtitle;

  /// A control at the row's end, e.g. the wallpaper page's close button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s20),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: DsIcon(icon, size: 20, color: colors.accent)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.heading.copyWith(color: colors.text),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(color: colors.textSubtle),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A chip over a stage: the pixel size, a video's kind, a setting's value.
final class SettingsPreviewChip extends StatelessWidget {
  /// The chip showing [label].
  const SettingsPreviewChip({required this.label, super.key});

  /// What the chip says.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x8A000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
        child: Text(label, style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF))),
      ),
    );
  }
}

/// A round control floating over a stage or its strip.
final class SettingsPreviewCircleButton extends StatelessWidget {
  /// The control.
  const SettingsPreviewCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 36,
    this.selected = false,
    super.key,
  });

  /// The glyph.
  final DsIconData icon;

  /// What the control does, for screen readers.
  final String semanticLabel;

  /// Fired on tap; null draws the control out of reach.
  final VoidCallback? onPressed;

  /// The circle's diameter.
  final double size;

  /// Whether this is one of a set's active choice: the circle fills with
  /// white and the glyph turns dark, so a toggle reads at a glance.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? const Color(0xE6FFFFFF) : const Color(0x66000000),
          border: Border.all(color: selected ? const Color(0xFFFFFFFF) : const Color(0x26FFFFFF)),
        ),
        child: Center(
          child: DsIcon(
            icon,
            size: size * 0.45,
            color: selected
                ? const Color(0xFF000000)
                : onPressed == null
                ? colors.textSubtle
                : const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// The gradient bar along a stage's bottom edge, where its controls float.
final class SettingsPreviewBar extends StatelessWidget {
  /// The bar holding [children].
  const SettingsPreviewBar({required this.children, super.key});

  /// The controls and labels, laid out in a row.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s24, DsSpace.s12, DsSpace.s8),
        child: Row(spacing: DsSpace.s4, children: children),
      ),
    );
  }
}
