import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/providers/app_providers.dart' show fontLibraryProvider;
import 'package:pure_live/features/settings/widgets/settings_chooser.dart' show showSettingsChooser;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/danmaku/danmaku_fps.dart' show displayRefreshRateProvider, resolvedDanmakuFps;
import 'package:pure_live/shared/danmaku/danmaku_template.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The shared barrage settings — the reference's `DanmakuSettingsContent`
/// (U.2f): the live room's panel tab and the settings' danmaku page show
/// this same content, and every row applies at once because the flying
/// surface and the chat list read these answers live.
///
/// The column carries grouped cards (title above, rounded card below), the
/// settings' own look; callers put it in a scroll view.
final class DanmakuSettingsContent extends ConsumerWidget {
  /// The content over [preferences], written through [update].
  const new({required this.preferences, required this.update, this.hint, super.key});

  /// The stored answers the rows show.
  final AppPreferences preferences;

  /// The store's write door.
  final Future<void> Function(AppPreferences Function(AppPreferences preferences)) update;

  /// A note right of the first group's title ("改动立即生效" in the room,
  /// U.2e c8).
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final p = preferences;
    void set(AppPreferences Function(AppPreferences) transform) => unawaited(update(transform));
    final template = BarrageTemplate.of(p);
    // The clock the surface actually repaints at — the row shows it even
    // while the manual slider sits greyed (D5).
    final rate = ref.watch(displayRefreshRateProvider).value;
    final shownFps = resolvedDanmakuFps(
      automatic: p.barrageAutoFps,
      configured: p.barrageFps,
      mode: p.barrageFpsMode,
      maxHz: rate?.maxHz,
      currentHz: rate?.currentHz,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, t.danmaku.templateGroup, hint: hint),
        _Templates(
          template: template,
          saved: p.barrageTemplate,
          onApply: (value) => set((old) => value.applyTo(old)),
          onSave: () => set((old) => old.copyWith(barrageTemplate: BarrageTemplate.of(old).encode())),
          onUse: (saved) => set((old) => (BarrageTemplate.tryDecode(saved) ?? BarrageTemplate.of(old)).applyTo(old)),
        ),
        _title(context, t.danmaku.rangeGroup),
        _Card(
          children: [
            _slider(
              context,
              title: t.danmaku.area,
              value: p.barrageArea.clamp(0, 1),
              label: '${(p.barrageArea * 100).round()}%',
              onChanged: (value) => set((old) => old.copyWith(barrageArea: value)),
            ),
            _counter(
              context,
              title: t.danmaku.marginTop,
              value: p.barrageTopArea.round().clamp(0, 300),
              onChanged: (value) => set((old) => old.copyWith(barrageTopArea: value.toDouble())),
            ),
            _counter(
              context,
              title: t.danmaku.marginBottom,
              value: p.barrageBottomArea.round().clamp(0, 300),
              onChanged: (value) => set((old) => old.copyWith(barrageBottomArea: value.toDouble())),
            ),
            _choice(
              context,
              title: t.danmaku.pausedBehavior,
              subtitle: t.danmaku.pausedBehaviorDesc,
              labels: [t.danmaku.pausedPause, t.danmaku.pausedFly],
              index: p.barragePausedBehavior == 'fly' ? 1 : 0,
              onChanged: (index) => set((old) => old.copyWith(barragePausedBehavior: index == 1 ? 'fly' : 'pause')),
            ),
            // A08.12: the platform's gifts fly over the picture too.
            _switch(
              context,
              title: t.danmaku.showGifts,
              subtitle: t.danmaku.showGiftsDesc,
              value: p.barrageShowGifts,
              onChanged: (value) => set((old) => old.copyWith(barrageShowGifts: value)),
            ),
          ],
        ),
        _title(context, t.danmaku.styleGroup),
        _Card(
          children: [
            _slider(
              context,
              title: t.danmaku.opacity,
              value: p.barrageOpacity.clamp(0, 1),
              label: '${(p.barrageOpacity * 100).round()}%',
              onChanged: (value) => set((old) => old.copyWith(barrageOpacity: value)),
            ),
            _slider(
              context,
              title: t.danmaku.speed,
              value: p.barrageSpeed.clamp(20, 400),
              min: 20,
              max: 400,
              label: '${p.barrageSpeed.round()} px/s',
              onChanged: (value) => set((old) => old.copyWith(barrageSpeed: value)),
            ),
            _slider(
              context,
              title: t.danmaku.fontSize,
              value: p.barrageFontSize.clamp(10, 30),
              min: 10,
              max: 30,
              label: '${p.barrageFontSize.toStringAsFixed(1)} px',
              onChanged: (value) => set((old) => old.copyWith(barrageFontSize: value)),
            ),
            _slider(
              context,
              title: t.danmaku.fontWeight,
              value: p.barrageFontWeight.clamp(100, 900).toDouble(),
              min: 100,
              max: 900,
              steps: 8,
              label: _weightName(context, p.barrageFontWeight),
              onChanged: (value) => set((old) => old.copyWith(barrageFontWeight: (value / 100).round() * 100)),
            ),
            _switch(
              context,
              title: t.danmaku.stroke,
              value: p.barrageStroke,
              onChanged: (value) => set((old) => old.copyWith(barrageStroke: value)),
            ),
            // D4: greyed out while the stroke is off, not hidden.
            _slider(
              context,
              title: t.danmaku.strokeWidth,
              value: p.barrageStrokeWidth.clamp(0, 4),
              max: 4,
              label: '${p.barrageStrokeWidth.toStringAsFixed(1)} px',
              enabled: p.barrageStroke,
              onChanged: (value) => set((old) => old.copyWith(barrageStrokeWidth: value)),
            ),
            // The emote gate the session's filter applies at once.
            _switch(
              context,
              title: t.danmaku.noEmoji,
              value: p.barrageNoEmoji,
              onChanged: (value) => set((old) => old.copyWith(barrageNoEmoji: value)),
            ),
            // F.2a: the danmaku font — the system's unless a downloaded
            // family is chosen; the flying lines and the list both draw with it.
            _fontRow(context, ref, p, set),
          ],
        ),
        _title(context, t.danmaku.repeatGroup),
        _Card(
          children: [
            _switch(
              context,
              title: t.danmaku.collapse,
              subtitle: t.danmaku.collapseDesc,
              value: p.barrageCollapse,
              onChanged: (value) => set((old) => old.copyWith(barrageCollapse: value)),
            ),
            // Greyed while the collapse is off, like the stroke width above.
            _counter(
              context,
              title: t.danmaku.collapseWindow,
              value: p.barrageCollapseWindow.clamp(1, 30),
              min: 1,
              max: 30,
              enabled: p.barrageCollapse,
              onChanged: (value) => set((old) => old.copyWith(barrageCollapseWindow: value)),
            ),
          ],
        ),
        _title(context, t.danmaku.interactionGroup),
        _Card(
          children: [
            // F.2b: the line on the picture answers the finger — both gestures
            // open the same message actions, as the reference has them do.
            _switch(
              context,
              title: t.danmaku.tapAction,
              value: p.barrageTapAction,
              onChanged: (value) => set((old) => old.copyWith(barrageTapAction: value)),
            ),
            _switch(
              context,
              title: t.danmaku.longPressAction,
              value: p.barrageLongPressAction,
              onChanged: (value) => set((old) => old.copyWith(barrageLongPressAction: value)),
            ),
            // D03.4: new in v4, off by default.
            _switch(
              context,
              title: t.danmaku.holdOnPress,
              subtitle: t.danmaku.holdOnPressDesc,
              value: p.barrageHoldOnPress,
              onChanged: (value) => set((old) => old.copyWith(barrageHoldOnPress: value)),
            ),
          ],
        ),
        _title(context, t.danmaku.smoothGroup),
        _Card(
          children: [
            _switch(
              context,
              title: t.danmaku.autoFps,
              subtitle: t.danmaku.autoFpsDesc,
              value: p.barrageAutoFps,
              onChanged: (value) => set((old) => old.copyWith(barrageAutoFps: value)),
            ),
            _choice(
              context,
              title: t.danmaku.fpsMode,
              labels: [t.danmaku.fpsModePowerSaving, t.danmaku.fpsModeBalanced, t.danmaku.fpsModeHighest],
              index: switch (p.barrageFpsMode) {
                'performance' => 2,
                'balanced' => 1,
                _ => 0,
              },
              onChanged: (index) =>
                  set((old) => old.copyWith(barrageFpsMode: const ['powerSaving', 'balanced', 'performance'][index])),
            ),
            // D5: greyed out while it follows the display, with the rate in use.
            _slider(
              context,
              title: t.danmaku.fps,
              value: (p.barrageAutoFps ? shownFps : p.barrageFps).clamp(25, 240).toDouble(),
              min: 25,
              max: 240,
              label: t.danmaku.fpsValue(count: shownFps),
              enabled: !p.barrageAutoFps,
              onChanged: (value) => set((old) => old.copyWith(barrageFps: value.round())),
            ),
            // D05.2: the same-screen cap, in steps of 2 so 48 stays reachable.
            _slider(
              context,
              title: t.danmaku.maxVisible,
              value: p.barrageMaxVisible.clamp(10, 120).toDouble(),
              min: 10,
              max: 120,
              steps: 55,
              label: t.danmaku.maxVisibleValue(count: p.barrageMaxVisible),
              onChanged: (value) => set((old) => old.copyWith(barrageMaxVisible: value.round())),
            ),
          ],
        ),
        _title(context, t.danmaku.listGroup),
        _Card(
          children: [
            _switch(
              context,
              title: t.danmaku.showSender,
              value: p.barrageShowSender,
              onChanged: (value) => set((old) => old.copyWith(barrageShowSender: value)),
            ),
            _choice(
              context,
              title: t.danmaku.listStyle,
              labels: [t.danmaku.listCompact, t.danmaku.listCard],
              index: p.barrageListStyle == 'card' ? 1 : 0,
              onChanged: (index) => set((old) => old.copyWith(barrageListStyle: index == 1 ? 'card' : 'compact')),
            ),
            _slider(
              context,
              title: t.danmaku.listFontSize,
              value: p.barrageListFontSize.clamp(10, 24),
              min: 10,
              max: 24,
              label: '${p.barrageListFontSize.round()} px',
              onChanged: (value) => set((old) => old.copyWith(barrageListFontSize: value)),
            ),
            _counter(
              context,
              title: t.danmaku.listLineSpacing,
              value: p.barrageListLineSpacing.round().clamp(1, 14),
              onChanged: (value) => set((old) => old.copyWith(barrageListLineSpacing: value.toDouble())),
            ),
          ],
        ),
      ],
    );
  }

  /// The danmaku font row: the families registered with the engine this
  /// process (the font manager's downloads), plus the system default.
  Widget _fontRow(
    BuildContext context,
    WidgetRef ref,
    AppPreferences p,
    void Function(AppPreferences Function(AppPreferences)) set,
  ) {
    final theme = PureTheme.of(context);
    final families = ref.watch(fontLibraryProvider).registered.toList(growable: false)..sort();
    final current = p.barrageFontFamily.trim();
    final label = current.isEmpty ? context.t.fonts.system : current;
    return PureListRow(
      key: const ValueKey('danmaku-font-family'),
      title: context.t.danmaku.fontFamily,
      subtitle: label,
      trailing: Icon(Icons.chevron_right, color: theme.colors.textTertiary),
      onTap: () async {
        final picked = await showSettingsChooser<String>(
          context,
          ref,
          title: context.t.danmaku.fontFamily,
          current: current,
          options: [('', context.t.fonts.system), for (final id in families) (id, id)],
        );
        if (picked != null && picked != current) {
          set((old) => old.copyWith(barrageFontFamily: picked));
        }
      },
    );
  }

  static String _weightName(BuildContext context, int weight) {
    final t = context.t;
    return switch (weight) {
      <= 100 => t.danmaku.weightThin,
      <= 200 => t.danmaku.weightExtraLight,
      <= 300 => t.danmaku.weightLight,
      <= 400 => t.danmaku.weightNormal,
      <= 500 => t.danmaku.weightMedium,
      <= 600 => t.danmaku.weightSemiBold,
      <= 700 => t.danmaku.weightBold,
      <= 800 => t.danmaku.weightExtraBold,
      _ => t.danmaku.weightBlack,
    };
  }

  Widget _title(BuildContext context, String title, {String? hint}) {
    final theme = PureTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.text.bodySmall.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (hint case final note?) Text(note, style: theme.text.caption.copyWith(color: theme.colors.textTertiary)),
        ],
      ),
    );
  }
}

/// The card a group of rows sits on (the reference's `PanelCard`).
final class _Card extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              Divider(height: 1, indent: 14, endIndent: 14, color: theme.colors.border.withValues(alpha: 0.5)),
            child,
          ],
        ],
      ),
    );
  }
}

/// A labelled slider row (the reference's `SettingSliderRow`).
Widget _slider(
  BuildContext context, {
  required String title,
  required double value,
  required String label,
  required ValueChanged<double> onChanged,
  double min = 0,
  double max = 1,
  int? steps,
  bool enabled = true,
}) {
  final theme = PureTheme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.text.body)),
            Text(label, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        PureSlider(
          key: ValueKey('danmaku-slider-$title'),
          value: value,
          min: min,
          max: max,
          enabled: enabled,
          onChanged: (next) {
            if (steps != null) {
              final span = max - min;
              final step = span / steps;
              onChanged((min + ((next - min) / step).roundToDouble() * step).clamp(min, max));
              return;
            }
            onChanged(next);
          },
        ),
      ],
    ),
  );
}

/// A −/+ counter row (the reference's `SettingCounterRow`).
Widget _counter(
  BuildContext context, {
  required String title,
  required int value,
  required ValueChanged<int> onChanged,
  int min = 0,
  int max = 999,
  bool enabled = true,
}) {
  final theme = PureTheme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
    child: Row(
      children: [
        Expanded(child: Text(title, style: theme.text.body)),
        PureIconButton(
          key: ValueKey('danmaku-counter-minus-$title'),
          icon: Icons.remove_circle_outline,
          tooltip: '−',
          size: ControlSize.sm,
          onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 44,
          child: Text('$value', textAlign: TextAlign.center, style: theme.text.body),
        ),
        PureIconButton(
          key: ValueKey('danmaku-counter-plus-$title'),
          icon: Icons.add_circle_outline,
          tooltip: '+',
          size: ControlSize.sm,
          onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    ),
  );
}

/// A labelled switch row (the reference's `SettingSwitchRow`).
Widget _switch(
  BuildContext context, {
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
  String? subtitle,
}) => PureListRow(
  key: ValueKey('danmaku-switch-$title'),
  title: title,
  subtitle: subtitle,
  trailing: PureSwitch(value: value, onChanged: onChanged),
);

/// A two-choice segmented row.
Widget _choice(
  BuildContext context, {
  required String title,
  required List<String> labels,
  required int index,
  required ValueChanged<int> onChanged,
  String? subtitle,
}) {
  final theme = PureTheme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Column(
      key: ValueKey('danmaku-choice-$title'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.text.body),
        if (subtitle case final note?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PureSegmented(labels: labels, index: index, onChanged: onChanged),
        ),
      ],
    ),
  );
}

/// The template chips, the line about the chosen one, and save/use of the
/// viewer's own look (U.2f D2).
final class _Templates extends StatelessWidget {
  const new({
    required this.template,
    required this.saved,
    required this.onApply,
    required this.onSave,
    required this.onUse,
  });

  final BarrageTemplate template;
  final String saved;
  final ValueChanged<BarrageTemplate> onApply;
  final VoidCallback onSave;
  final ValueChanged<String> onUse;

  String get _descriptionKey {
    final chosen = template.presetKey;
    if (chosen != null) {
      return chosen;
    }
    return 'custom';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final chosen = template.presetKey;
    String label(String key) => switch (key) {
      'best' => t.danmaku.templateBest,
      'comfort' => t.danmaku.templateComfort,
      'dense' => t.danmaku.templateDense,
      'reset' => t.danmaku.templateReset,
      _ => '',
    };
    String description() => switch (_descriptionKey) {
      'best' => t.danmaku.bestDesc,
      'comfort' => t.danmaku.comfortDesc,
      'dense' => t.danmaku.denseDesc,
      'reset' => t.danmaku.resetDesc,
      _ => t.danmaku.customDesc,
    };
    void toast(String message) => PureToast.show(context, message, type: PureToastType.success);
    return _Card(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, preset) in BarrageTemplate.presets)
                    // A chip in the language's own button, not a Material
                    // ChoiceChip — this content also renders under the
                    // non-Material hosts, where a chip asserts.
                    PureButton(
                      key: ValueKey('danmaku-template-$key'),
                      label: label(key),
                      size: ControlSize.sm,
                      variant: chosen == key ? ButtonVariant.primary : ButtonVariant.secondary,
                      onPressed: () {
                        onApply(preset);
                        toast(t.danmaku.templateApplied);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description(),
                key: const ValueKey('danmaku-template-description'),
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: PureButton(
                      key: const ValueKey('danmaku-template-save'),
                      label: t.danmaku.saveMine,
                      icon: Icons.bookmark_add_outlined,
                      size: ControlSize.sm,
                      variant: ButtonVariant.secondary,
                      onPressed: () {
                        onSave();
                        toast(t.danmaku.templateSaved);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  PureButton(
                    key: const ValueKey('danmaku-template-load'),
                    label: t.danmaku.useMine,
                    icon: Icons.bookmark_outline,
                    size: ControlSize.sm,
                    variant: ButtonVariant.ghost,
                    onPressed: saved.trim().isEmpty || BarrageTemplate.tryDecode(saved) == null
                        ? null
                        : () {
                            onUse(saved);
                            toast(t.danmaku.templateApplied);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
