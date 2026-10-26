import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show DisplayRefreshRate, DisplayRefreshRatePreference;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

/// The display-rate section of the general pane: what the monitor reports,
/// and the modes the active backend can actually request.
///
/// The reference calls the three choices power saving, balanced and
/// performance. A platform that cannot request a preferred rate (Windows,
/// macOS and Linux currently) gets the read-only rates and a note instead of
/// a selector that would do nothing. All platform work lives in live_device.
final class RefreshRateSection extends ConsumerWidget {
  /// Creates the section.
  const RefreshRateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(displayRefreshRateProvider);
    final notifier = ref.read(displayRefreshRateProvider.notifier);
    final snapshot = state.snapshot;
    final modes = state.modes;
    final matchVideo = ref.watch(matchVideoFrameRateProvider);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final supportedRates = snapshot?.supportedHz ?? const <double>[];
    final singleRate = supportedRates.length == 1;
    final canMatchContent = state.capabilities?.canMatchContent ?? true;
    final matchVideoDescription = singleRate
        ? t.settings.refreshRateMatchVideoSingle(rate: _hz(supportedRates.single))
        : canMatchContent
        ? t.settings.refreshRateMatchVideoDesc
        : t.settings.refreshRateMatchVideoUnsupported;
    return DsListSection(
      header: Text(t.settings.refreshRateGroup),
      children: [
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.monitor),
          title: t.settings.refreshRateDisplay,
          description: _rateDescription(t, snapshot),
          controlWidth: 140,
          control: DsButton.icon(
            variant: DsButtonVariant.secondary,
            loading: state.loading,
            onPressed: state.loading ? null : () => unawaited(notifier.refresh()),
            icon: const DsIcon(DsIcons.refreshCw),
            semanticLabel: t.settings.refreshRateRefresh,
          ),
        ),
        if (state.error.isNotEmpty)
          DsListRow(
            leading: const DsIcon(DsIcons.circleAlert),
            title: Text(t.settings.refreshRateFailed),
            description: Text(state.error, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        if (modes.isNotEmpty)
          SettingsChoiceRow<RefreshRateMode>(
            leading: const DsIcon(DsIcons.gauge),
            title: t.settings.refreshRateMode,
            description: t.settings.refreshRateModeDesc,
            value: modes.contains(state.mode) ? state.mode : modes.first,
            options: [for (final mode in modes) DsSelectOption(value: mode, label: _modeLabel(t, mode))],
            onChanged: (mode) => unawaited(_select(context, ref, mode)),
          )
        else if (state.capabilities != null)
          DsListRow(
            leading: const DsIcon(DsIcons.info),
            title: Text(t.settings.refreshRateReadOnly),
            description: Text(t.settings.refreshRateReadOnlyDesc),
          ),
        if (android)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.gauge),
            title: t.settings.refreshRateMatchVideo,
            description: matchVideoDescription,
            control: DsSwitch(
              value: !singleRate && canMatchContent && matchVideo,
              onChanged: singleRate || !canMatchContent
                  ? null
                  : (value) => unawaited(ref.read(matchVideoFrameRateProvider.notifier).setEnabled(value: value)),
            ),
          ),
        if (snapshot != null && (snapshot.monitorCount ?? 0) > 1)
          DsListRow(
            leading: const DsIcon(DsIcons.monitor),
            title: Text(t.settings.refreshRateMultiMonitor(count: snapshot.monitorCount!)),
            description: Text(t.settings.refreshRateMultiMonitorDesc),
          ),
      ],
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref, RefreshRateMode mode) async {
    await ref.read(displayRefreshRateProvider.notifier).select(mode);
    if (!context.mounted) return;
    final outcome = ref.read(displayRefreshRateProvider).lastOutcome;
    if (outcome == DisplayRefreshRatePreference.failed ||
        outcome == DisplayRefreshRatePreference.unavailable ||
        outcome == DisplayRefreshRatePreference.unsupported) {
      showDsToast(context: context, title: context.t.settings.refreshRateApplyFailed, status: DsStatus.danger);
    }
  }

  /// The current/max line; unknown values use the localized dash instead of
  /// inventing a rate.
  static String _rateDescription(Translations t, DisplayRefreshRate? snapshot) {
    if (snapshot == null) return t.settings.refreshRateUnknown;
    final current = snapshot.currentHz > 0 ? '${_hz(snapshot.currentHz)} Hz' : t.settings.refreshRateUnknown;
    final max = snapshot.maxHz == null ? t.settings.refreshRateUnknown : '${_hz(snapshot.maxHz!)} Hz';
    final base = t.settings.refreshRateCurrentMax(current: current, max: max);
    if (snapshot.isLowPowerMode) return '$base · ${t.settings.refreshRateLowPower}';
    return base;
  }

  static String _hz(double hz) => hz == hz.roundToDouble() ? '${hz.round()}' : hz.toStringAsFixed(1);

  static String _modeLabel(Translations t, RefreshRateMode mode) => switch (mode) {
    RefreshRateMode.powerSaving => t.settings.refreshRatePowerSaving,
    RefreshRateMode.balanced => t.settings.refreshRateBalanced,
    RefreshRateMode.performance => t.settings.refreshRatePerformance,
  };
}
