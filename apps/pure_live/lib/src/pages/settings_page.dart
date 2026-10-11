import 'package:flutter/material.dart';
import 'package:live_preferences/live_preferences.dart';
import 'package:live_uikit/live_uikit.dart';

import 'package:pure_live/src/services.dart';
import 'package:pure_live/src/ui/ui_configuration.dart';

/// The settings page: appearance, danmaku, playback, and where the app keeps
/// its data.
///
/// Every control here writes through `PreferencesService`, which applies the
/// change to the in-memory value first and persists it in the background —
/// so a design-language switch is visible on the next frame and durable a
/// moment later, and dragging a slider costs one document write rather than
/// one per frame. The page itself holds no state: it reads `preferences.value`
/// and writes through the service, which is why switching a language here
/// rebuilds the theme without touching a single business service.
class SettingsPage extends StatefulWidget {
  /// A settings page over [services].
  const new({required this.services, super.key});

  /// The service graph.
  final PureLiveServices services;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Preferences get _preferences => widget.services.preferences.value;

  @override
  void initState() {
    super.initState();
    widget.services.preferences.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final environment = LiveEnvironmentScope.of(context);
    final geometry = theme.componentTheme;
    final preferences = widget.services.preferences;
    final appearance = _preferences.appearance;
    final danmaku = _preferences.danmaku;
    final playback = _preferences.playback;
    final library = _preferences.library;
    return ListView(
      padding: geometry.pagePaddingFor(environment.layoutMode),
      children: [
        Text(
          'Settings',
          style: environment.layoutMode == LiveLayoutMode.tv ? theme.typography.display : theme.typography.headline,
        ),
        SizedBox(height: geometry.sectionGap),
        _Section(
          title: 'Appearance',
          children: [
            _Row(
              label: 'Design language',
              description: 'The visual language every page renders in. Switching it does not touch playback.',
              child: Wrap(
                spacing: geometry.iconGap,
                runSpacing: geometry.iconGap,
                children: [
                  for (final language in LiveDesignLanguage.values)
                    LiveButton(
                      label: language.name,
                      size: LiveControlSize.small,
                      variant: theme.requestedLanguage == language
                          ? LiveButtonVariant.primary
                          : LiveButtonVariant.outline,
                      onPressed: language == theme.requestedLanguage
                          ? null
                          : () => UiConfigurationMapper.selectDesignLanguage(preferences, language),
                    ),
                ],
              ),
            ),
            _Row(
              label: 'Brightness',
              description: 'Follow the system, or pin light or dark.',
              child: Wrap(
                spacing: geometry.iconGap,
                children: [
                  for (final mode in AppThemeMode.values)
                    LiveButton(
                      label: mode.name,
                      size: LiveControlSize.small,
                      variant: appearance.themeMode == mode ? LiveButtonVariant.primary : LiveButtonVariant.outline,
                      onPressed: mode == appearance.themeMode
                          ? null
                          : () => UiConfigurationMapper.selectBrightness(preferences, mode),
                    ),
                ],
              ),
            ),
            _Row(
              label: 'Accent',
              description: 'The accent every design language derives its palette from.',
              child: Wrap(
                spacing: geometry.iconGap,
                children: [
                  for (final color in _accentChoices)
                    LiveButton(
                      label: appearance.accentColor == color.toARGB32() ? 'Selected' : 'Use',
                      size: LiveControlSize.small,
                      variant: LiveButtonVariant.outline,
                      onPressed: () => UiConfigurationMapper.selectAccent(preferences, color.toARGB32()),
                    ),
                  LiveButton(
                    label: 'Default',
                    size: LiveControlSize.small,
                    variant: LiveButtonVariant.text,
                    onPressed: appearance.accentColor == null
                        ? null
                        : () => UiConfigurationMapper.selectAccent(preferences, null),
                  ),
                ],
              ),
            ),
            _Row(
              label: 'Pure black',
              description: 'Draw dark surfaces as true black, for OLED and TV panels.',
              child: LiveButton(
                label: appearance.pureBlack ? 'On' : 'Off',
                size: LiveControlSize.small,
                variant: appearance.pureBlack ? LiveButtonVariant.primary : LiveButtonVariant.outline,
                onPressed: () => preferences.updateAppearance((value) => value.copyWith(pureBlack: !value.pureBlack)),
              ),
            ),
          ],
        ),
        SizedBox(height: geometry.sectionGap),
        _Section(
          title: 'Danmaku',
          children: [
            _Row(
              label: 'Show danmaku',
              description: 'The overlay itself; the connection stays up either way.',
              child: LiveButton(
                label: danmaku.enabled ? 'On' : 'Off',
                size: LiveControlSize.small,
                variant: danmaku.enabled ? LiveButtonVariant.primary : LiveButtonVariant.outline,
                onPressed: () => preferences.updateDanmaku((value) => value.copyWith(enabled: !value.enabled)),
              ),
            ),
            // Steps instead of a slider on purpose: a remote control cannot
            // drag, and a TV user should be able to set danmaku with the
            // d-pad alone.
            _Row(
              label: 'Opacity ${(danmaku.opacity * 100).round()}%',
              description: 'How solid the flying messages are.',
              child: _Steps<double>(
                values: const [0.25, 0.5, 0.75, 1],
                selected: danmaku.opacity,
                label: (value) => '${(value * 100).round()}%',
                onSelected: (value) => preferences.updateDanmaku((d) => d.copyWith(opacity: value)),
              ),
            ),
            _Row(
              label: 'Size ${(danmaku.fontScale * 100).round()}%',
              description: 'The text scale of the messages.',
              child: _Steps<double>(
                values: const [0.75, 1, 1.25, 1.5],
                selected: danmaku.fontScale,
                label: (value) => '${(value * 100).round()}%',
                onSelected: (value) => preferences.updateDanmaku((d) => d.copyWith(fontScale: value)),
              ),
            ),
            _Row(
              label: 'Area ${(danmaku.area * 100).round()}%',
              description: 'How much of the picture height the messages may use.',
              child: _Steps<double>(
                values: const [0.25, 0.5, 0.75, 1],
                selected: danmaku.area,
                label: (value) => '${(value * 100).round()}%',
                onSelected: (value) => preferences.updateDanmaku((d) => d.copyWith(area: value)),
              ),
            ),
          ],
        ),
        SizedBox(height: geometry.sectionGap),
        _Section(
          title: 'Playback',
          children: [
            _Row(
              label: 'Default quality',
              description: 'The label the player prefers when a site offers it.',
              child: LiveTextField(
                hint: playback.quality.isEmpty ? 'Highest available' : playback.quality,
                onSubmitted: (value) => preferences.updatePlayback((p) => p.copyWith(quality: value)),
              ),
            ),
            _Row(
              label: 'Automatic recovery',
              description: 'Advance through other lines and qualities when one fails.',
              child: LiveButton(
                label: playback.autoRecover ? 'On' : 'Off',
                size: LiveControlSize.small,
                variant: playback.autoRecover ? LiveButtonVariant.primary : LiveButtonVariant.outline,
                onPressed: () => preferences.updatePlayback((p) => p.copyWith(autoRecover: !p.autoRecover)),
              ),
            ),
          ],
        ),
        SizedBox(height: geometry.sectionGap),
        _Section(
          title: 'Lists',
          children: [
            _Row(
              label: 'Layout',
              description: 'How room lists arrange themselves.',
              child: Wrap(
                spacing: geometry.iconGap,
                children: [
                  for (final layout in LiveListLayout.values)
                    LiveButton(
                      label: layout.name,
                      size: LiveControlSize.small,
                      variant: library.listLayout == layout ? LiveButtonVariant.primary : LiveButtonVariant.outline,
                      onPressed: layout == library.listLayout
                          ? null
                          : () => preferences.updateLibrary((value) => value.copyWith(listLayout: layout)),
                    ),
                ],
              ),
            ),
            _Row(
              label: 'History length',
              description: 'How many watched rooms are remembered.',
              child: Text(
                '${library.historyLimit}',
                style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
              ),
            ),
          ],
        ),
        SizedBox(height: geometry.sectionGap),
        _Section(
          title: 'Data',
          children: [
            _Row(
              label: 'Platform',
              description: 'Detected at startup; a TV build is declared by its launcher, never guessed.',
              child: Text(
                '${widget.services.runtime.environment.runtime.kind.name} · '
                '${widget.services.runtime.environment.runtime.formFactor.name}',
                style: theme.typography.bodySmall.copyWith(color: theme.colors.textSecondary),
              ),
            ),
            _Row(
              label: 'Storage',
              description: 'Where the database, the logs and the cache live.',
              child: Text(
                widget.services.runtime.storage.toString(),
                style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
              ),
            ),
            _Row(
              label: 'Reset preferences',
              description: 'Removes every stored preference document and returns to the defaults.',
              child: LiveButton(label: 'Reset', variant: LiveButtonVariant.danger, onPressed: preferences.reset),
            ),
          ],
        ),
      ],
    );
  }

  static const List<Color> _accentChoices = [
    Color(0xFF2E6FE0),
    Color(0xFFE95420),
    Color(0xFF6750A4),
    Color(0xFF0F7B6C),
    Color(0xFFD24B4B),
  ];
}

/// A titled group of rows.
class _Section extends StatelessWidget {
  const new({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return LiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.typography.title.copyWith(color: theme.colors.textPrimary)),
          SizedBox(height: geometry.sectionGap),
          for (final child in children) ...[child, SizedBox(height: geometry.sectionGap)],
        ],
      ),
    );
  }
}

/// A row of mutually exclusive choices, for values a remote must be able to
/// set with the d-pad.
class _Steps<T extends Object> extends StatelessWidget {
  const new({required this.values, required this.selected, required this.label, required this.onSelected});

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final geometry = LiveTheme.of(context).componentTheme;
    return Wrap(
      spacing: geometry.iconGap,
      runSpacing: geometry.iconGap,
      children: [
        for (final value in values)
          LiveButton(
            label: label(value),
            size: LiveControlSize.small,
            variant: value == selected ? LiveButtonVariant.primary : LiveButtonVariant.outline,
            onPressed: value == selected ? null : () => onSelected(value),
          ),
      ],
    );
  }
}

/// A label, an explanation and the control that changes it.
class _Row extends StatelessWidget {
  const new({required this.label, required this.description, required this.child});

  final String label;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.typography.subtitle.copyWith(color: theme.colors.textPrimary)),
              const SizedBox(height: LiveSpacing.xxs),
              Text(description, style: theme.typography.caption.copyWith(color: theme.colors.textSecondary)),
            ],
          ),
        ),
        SizedBox(width: geometry.sectionGap),
        child,
      ],
    );
  }
}
