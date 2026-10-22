import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The fine-tuned text sizes (the reference's `FontSizesPage`): five of the
/// eight roles get their own pixel size, while a role left alone keeps the
/// design language's own size. A drag stores an absolute size, so the row's
/// preview is the exact type it sets.
final class FontSizesPage extends ConsumerWidget {
  /// The page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final appearance = ref.watch(appearancePreferencesProvider);
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    void write(AppearancePreferences Function(AppearancePreferences) change) => unawaited(update(change));

    CustomSettingsTile row({
      required Key key,
      required String title,
      required IconData icon,
      required double min,
      required double max,
      required double? size,
      required double effective,
      required FontWeight weight,
      required ValueChanged<double> onChanged,
    }) => CustomSettingsTile(
      child: _RoleTile(
        key: key,
        title: title,
        icon: icon,
        min: min,
        max: max,
        overrideSize: size,
        effective: effective,
        weight: weight,
        onChanged: onChanged,
      ),
    );

    return PureScaffold(
      appBar: PureAppBar(
        title: t.settings.fineFontSizes,
        actions: [
          PureIconButton(
            key: const ValueKey('font-size-reset'),
            icon: Icons.restart_alt,
            tooltip: t.settings.fontSizeReset,
            onPressed: () {
              write(
                (a) => a.copyWith(
                  bodySmallSize: null,
                  bodySize: null,
                  subtitleSize: null,
                  titleSize: null,
                  headlineSize: null,
                ),
              );
              PureToast.show(context, t.settings.fontSizeResetDone);
            },
          ),
        ],
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupFineFontSizes),
            tiles: [
              row(
                key: const ValueKey('font-size-bodySmall'),
                title: t.settings.fontSizeBodySmall,
                icon: Icons.text_fields_outlined,
                min: 9,
                max: 20,
                size: appearance.bodySmallSize,
                effective: theme.text.bodySmall.fontSize ?? 12,
                weight: FontWeight.w400,
                onChanged: (value) => write((a) => a.copyWith(bodySmallSize: value)),
              ),
              row(
                key: const ValueKey('font-size-body'),
                title: t.settings.fontSizeBody,
                icon: Icons.short_text,
                min: 10,
                max: 24,
                size: appearance.bodySize,
                effective: theme.text.body.fontSize ?? 14,
                weight: FontWeight.w400,
                onChanged: (value) => write((a) => a.copyWith(bodySize: value)),
              ),
              row(
                key: const ValueKey('font-size-subtitle'),
                title: t.settings.fontSizeSubtitle,
                icon: Icons.subject,
                min: 11,
                max: 26,
                size: appearance.subtitleSize,
                effective: theme.text.subtitle.fontSize ?? 16,
                weight: FontWeight.w500,
                onChanged: (value) => write((a) => a.copyWith(subtitleSize: value)),
              ),
              row(
                key: const ValueKey('font-size-title'),
                title: t.settings.fontSizeTitle,
                icon: Icons.title,
                min: 12,
                max: 30,
                size: appearance.titleSize,
                effective: theme.text.title.fontSize ?? 20,
                weight: FontWeight.w600,
                onChanged: (value) => write((a) => a.copyWith(titleSize: value)),
              ),
              row(
                key: const ValueKey('font-size-headline'),
                title: t.settings.fontSizeHeadline,
                icon: Icons.text_increase,
                min: 14,
                max: 36,
                size: appearance.headlineSize,
                effective: theme.text.headline.fontSize ?? 24,
                weight: FontWeight.w600,
                onChanged: (value) => write((a) => a.copyWith(headlineSize: value)),
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.lg, vertical: 6),
                  child: Text(
                    t.settings.fontSizeFineNote,
                    style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One role: the sample line at the size it sets, then the track.
final class _RoleTile extends StatelessWidget {
  const new({
    required this.title,
    required this.icon,
    required this.min,
    required this.max,
    required this.overrideSize,
    required this.effective,
    required this.weight,
    required this.onChanged,
    super.key,
  });

  final String title;
  final IconData icon;
  final double min;
  final double max;
  final double? overrideSize;
  final double effective;
  final FontWeight weight;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final size = overrideSize ?? effective;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            context.t.settings.previewText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, fontWeight: weight, height: 1.35, color: theme.colors.text),
          ),
        ),
        SettingsSliderRow(
          icon: icon,
          title: title,
          value: size.clamp(min, max),
          min: min,
          max: max,
          valueLabel: '${size.round()} px',
          onChanged: (value) => onChanged(value.roundToDouble()),
        ),
      ],
    );
  }
}
