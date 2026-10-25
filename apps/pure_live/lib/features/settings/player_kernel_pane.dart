import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/player_backend_providers.dart'
    show PlayerKernelBackend, availablePlayerKernelBackends, playerKernelBackendProvider;
import 'package:pure_live/features/settings/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/features/settings/player_tuning.dart';
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsChoiceRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/player/super_resolution.dart'
    show SuperResolutionMode, superResolutionAvailable, superResolutionModeProvider;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The full player kernel page: the engine and its proxy, the one-click
/// recipes, Anime4K, and the mpv advanced table the old client shipped.
final class PlayerKernelPane extends ConsumerWidget {
  /// The kernel page's content.
  const PlayerKernelPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final backends = availablePlayerKernelBackends();
    final selected = ref.watch(playerKernelBackendProvider);
    final tuning = ref.watch(playerTuningProvider);
    final proxy = ref.watch(playerProxyProvider);
    final platform = defaultTargetPlatform;
    final mpv = selected == PlayerKernelBackend.mpv;
    final muted = DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted);
    final decoders = playerHardwareDecoderOptions(platform).where((value) => value != 'no').toList(growable: false);
    final decoder = tuning.hwdec == 'no' ? 'auto-safe' : tuning.hwdec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navKernel),
          children: [
            if (backends.length > 1)
              SettingsChoiceRow<PlayerKernelBackend>(
                leading: const DsIcon(DsIcons.cpu),
                title: t.settings.engineTitle,
                description: t.settings.engineDesc,
                value: selected,
                options: [for (final backend in backends) DsSelectOption(value: backend, label: backend.label)],
                onChanged: (backend) => unawaited(ref.read(playerKernelBackendProvider.notifier).select(backend)),
              )
            else
              DsListRow(
                leading: const DsIcon(DsIcons.cpu),
                title: Text(t.settings.engineTitle),
                description: Text(t.settings.engineDesc),
                detail: Text(selected.label),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
              child: Text(backends.length > 1 ? t.settings.kernelSwitchHint : t.settings.kernelOnlyOne, style: muted),
            ),
            if (mpv)
              DsListRow(
                leading: const DsIcon(DsIcons.globe),
                title: Text(t.settings.playerProxy),
                description: Text(t.settings.playerProxyDesc),
                detail: Text(proxy.enabled ? '${proxy.host}:${proxy.port}' : t.settings.optionOff),
                showChevron: true,
                onPressed: () => unawaited(_showPlayerProxyDialog(context)),
              ),
            DsListRow(
              leading: const DsIcon(DsIcons.gauge),
              title: Text(t.settings.hardwareDecoding),
              description: Text(t.settings.hardwareDecodingDesc),
              trailing: DsSwitch(
                value: settings.hardwareDecoding,
                onChanged: (value) =>
                    unawaited(ref.read(playbackSettingsProvider.notifier).setHardwareDecoding(value: value)),
              ),
            ),
            if (mpv && settings.hardwareDecoding)
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.cpu),
                title: t.settings.hardwareDecoder,
                description: t.settings.hardwareDecoderDesc,
                value: decoders.contains(decoder) ? decoder : decoders.first,
                options: [for (final value in decoders) DsSelectOption(value: value, label: _optionLabel(t, value))],
                onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setHwdec(value)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
              child: Text(t.settings.hardwareDecodingHint, style: muted),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.power),
              title: Text(t.settings.forceDestroy),
              description: Text(t.settings.forceDestroyDesc),
              trailing: DsSwitch(
                value: tuning.forceDestroy,
                onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setForceDestroy(value: value)),
              ),
            ),
          ],
        ),
        if (mpv) ...[
          const _PlayerPresetSection(),
          if (superResolutionAvailable) const _SuperResolutionSection(),
          const _PlayerAdvancedSection(),
        ] else
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s20),
            child: Text(t.settings.playerAdvancedRequiresMpv, style: muted),
          ),
      ],
    );
  }
}

/// The six tuning recipes, platform-gated, as a card of full-row choices.
final class _PlayerPresetSection extends ConsumerWidget {
  const _PlayerPresetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final tuning = ref.watch(playerTuningProvider);
    final muted = DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted);
    return DsListSection(
      header: Text(t.settings.playerPresets),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Text(t.settings.playerPresetsHint, style: muted),
        ),
        for (final preset in PlayerPresetId.values)
          if (preset.availableHere)
            DsListRow(
              leading: DsIcon(_presetIcon(preset)),
              title: Text(_presetName(t, preset)),
              description: Text(_presetDescription(t, preset)),
              selected: tuning.preset == preset,
              trailing: tuning.preset == preset ? const DsIcon(DsIcons.check) : null,
              onPressed: () async {
                await ref.read(playerTuningProvider.notifier).applyPreset(preset);
                if (context.mounted) showDsToast(context: context, title: t.settings.playerPresetApplied);
              },
            ),
      ],
    );
  }
}

/// Anime4K modes as rows with their own explanations, not a bare picker.
final class _SuperResolutionSection extends ConsumerWidget {
  const _SuperResolutionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final mode = ref.watch(superResolutionModeProvider);
    final muted = DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted);
    return DsListSection(
      header: Text(t.settings.superResolutionGroup),
      children: [
        for (final candidate in SuperResolutionMode.values)
          DsListRow(
            leading: DsIcon(_superResolutionIcon(candidate)),
            title: Text(_superResolutionName(t, candidate)),
            description: Text(_superResolutionDescription(t, candidate)),
            selected: mode == candidate,
            trailing: mode == candidate ? const DsIcon(DsIcons.check) : null,
            onPressed: () => unawaited(ref.read(superResolutionModeProvider.notifier).select(candidate)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
          child: Text(t.settings.superResolutionHint, style: muted),
        ),
      ],
    );
  }
}

/// The mpv output, sync, scaling and decoder options the old kernel page
/// carried, in one advanced card.
final class _PlayerAdvancedSection extends ConsumerWidget {
  const _PlayerAdvancedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final tuning = ref.watch(playerTuningProvider);
    final settings = ref.watch(playbackSettingsProvider);
    final platform = defaultTargetPlatform;
    final desktop = platform != TargetPlatform.android && platform != TargetPlatform.iOS;
    final videoOutputs = playerVideoOutputOptions(platform);
    final audioOutputs = playerAudioOutputOptions(platform);
    return DsListSection(
      header: Text(t.settings.mpvAdvanced),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.slidersHorizontal),
          title: Text(t.settings.customOutput),
          description: Text(t.settings.customOutputDesc),
          trailing: DsSwitch(
            value: tuning.customOutput,
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setCustomOutput(value: value)),
          ),
        ),
        if (tuning.customOutput)
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.monitor),
            title: t.settings.videoOutput,
            description: t.settings.videoOutputHint,
            value: tuning.vo,
            options: [for (final value in videoOutputs) DsSelectOption(value: value, label: _optionLabel(t, value))],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setVo(value)),
          ),
        if (tuning.customOutput)
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.volume),
            title: t.settings.audioOutput,
            value: tuning.ao,
            options: [for (final value in audioOutputs) DsSelectOption(value: value, label: _optionLabel(t, value))],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setAo(value)),
          ),
        if (desktop)
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.timer),
            title: t.settings.videoSync,
            description: t.settings.videoSyncDesc,
            value: tuning.videoSync,
            options: [
              for (final value in playerVideoSyncOptions) DsSelectOption(value: value, label: _optionLabel(t, value)),
            ],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setVideoSync(value)),
          ),
        if (desktop)
          DsListRow(
            leading: const DsIcon(DsIcons.activity),
            title: Text(t.settings.interpolation),
            description: Text(t.settings.interpolationDesc),
            trailing: DsSwitch(
              value: tuning.interpolation,
              onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setInterpolation(value: value)),
            ),
          ),
        SettingsChoiceRow<String>(
          leading: const DsIcon(DsIcons.scale),
          title: t.settings.scaleKernel,
          description: t.settings.scaleKernelDesc,
          value: tuning.scale,
          options: [
            for (final value in playerScaleOptions(platform))
              DsSelectOption(value: value, label: _optionLabel(t, value)),
          ],
          onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setScale(value)),
        ),
        SettingsChoiceRow<String>(
          leading: const DsIcon(DsIcons.layoutGrid),
          title: t.settings.deinterlace,
          description: t.settings.deinterlaceDesc,
          value: tuning.deinterlace,
          options: [
            for (final value in playerDeinterlaceOptions) DsSelectOption(value: value, label: _optionLabel(t, value)),
          ],
          onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setDeinterlace(value)),
        ),
        if (settings.hardwareDecoding && (platform == TargetPlatform.android || platform == TargetPlatform.windows))
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.fileText),
            title: t.settings.hwdecCodecs,
            description: t.settings.hwdecCodecsDesc,
            value: tuning.hwdecCodecs,
            options: [
              for (final value in playerHwdecCodecOptions(platform))
                DsSelectOption(value: value, label: _optionLabel(t, value)),
            ],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setHwdecCodecs(value)),
          ),
        if (platform == TargetPlatform.windows)
          DsListRow(
            leading: const DsIcon(DsIcons.headphones),
            title: Text(t.settings.audioExclusive),
            description: Text(t.settings.audioExclusiveDesc),
            trailing: DsSwitch(
              value: tuning.audioExclusive,
              onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setAudioExclusive(value: value)),
            ),
          ),
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCcw),
          title: Text(t.settings.mpvReset),
          description: Text(t.settings.mpvResetDesc),
          destructive: true,
          onPressed: () => unawaited(_resetMpvSettings(context, ref)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.bookOpen),
          title: Text(t.settings.mpvDocs),
          description: Text(t.settings.mpvDocsDesc),
          showChevron: true,
          onPressed: () =>
              unawaited(launchUrl(Uri.parse('https://mpv.io/manual/'), mode: LaunchMode.externalApplication)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.graduationCap),
          title: Text(t.settings.playerGuide),
          description: Text(t.settings.playerGuideDesc),
          showChevron: true,
          onPressed: () => unawaited(_showPlayerGuide(context)),
        ),
      ],
    );
  }
}

Future<void> _resetMpvSettings(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.mpvReset,
    description: t.settings.mpvResetDesc,
    confirmLabel: t.common.confirm,
    cancelLabel: t.common.cancel,
    destructive: true,
    icon: const DsIcon(DsIcons.rotateCcw),
  );
  if (!confirmed) return;
  await ref.read(playerTuningProvider.notifier).reset();
  await ref.read(playbackSettingsProvider.notifier).setHardwareDecoding(value: true);
}

String _presetName(Translations t, PlayerPresetId preset) => switch (preset) {
  PlayerPresetId.balanced => t.settings.presetBalanced,
  PlayerPresetId.compat => t.settings.presetCompat,
  PlayerPresetId.rtxVsr => t.settings.presetRtxVsr,
  PlayerPresetId.lowEnd => t.settings.presetLowEnd,
  PlayerPresetId.stableNetwork => t.settings.presetStableNetwork,
  PlayerPresetId.lowLatency => t.settings.presetLowLatency,
};

String _presetDescription(Translations t, PlayerPresetId preset) => switch (preset) {
  PlayerPresetId.balanced => t.settings.presetBalancedDesc,
  PlayerPresetId.compat => t.settings.presetCompatDesc,
  PlayerPresetId.rtxVsr => t.settings.presetRtxVsrDesc,
  PlayerPresetId.lowEnd => t.settings.presetLowEndDesc,
  PlayerPresetId.stableNetwork => t.settings.presetStableNetworkDesc,
  PlayerPresetId.lowLatency => t.settings.presetLowLatencyDesc,
};

DsIconData _presetIcon(PlayerPresetId preset) => switch (preset) {
  PlayerPresetId.balanced => DsIcons.slidersHorizontal,
  PlayerPresetId.compat => DsIcons.smartphone,
  PlayerPresetId.rtxVsr => DsIcons.wandSparkles,
  PlayerPresetId.lowEnd => DsIcons.feather,
  PlayerPresetId.stableNetwork => DsIcons.wifi,
  PlayerPresetId.lowLatency => DsIcons.zap,
};

String _superResolutionName(Translations t, SuperResolutionMode mode) => switch (mode) {
  SuperResolutionMode.off => t.settings.superResolutionOff,
  SuperResolutionMode.efficiency => t.settings.superResolutionEfficiency,
  SuperResolutionMode.quality => t.settings.superResolutionQuality,
};

String _superResolutionDescription(Translations t, SuperResolutionMode mode) => switch (mode) {
  SuperResolutionMode.off => t.settings.superResolutionOffDesc,
  SuperResolutionMode.efficiency => t.settings.superResolutionEfficiencyDesc,
  SuperResolutionMode.quality => t.settings.superResolutionQualityDesc,
};

DsIconData _superResolutionIcon(SuperResolutionMode mode) => switch (mode) {
  SuperResolutionMode.off => DsIcons.circleOff,
  SuperResolutionMode.efficiency => DsIcons.wandSparkles,
  SuperResolutionMode.quality => DsIcons.sparkles,
};

/// A technical mpv value's readable word; unknown values keep their engine
/// spelling, which is what the manual calls them.
String _optionLabel(Translations t, String value) => switch (value) {
  'auto' => t.settings.optionAuto,
  'no' => t.settings.optionOff,
  'yes' => t.settings.optionOn,
  'null' => t.settings.optionNoOutput,
  _ => value,
};

Future<void> _showPlayerProxyDialog(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _PlayerProxyDialog());

/// The player's proxy editor: host, port and the on/off switch, applied on
/// Confirm. It is separate from the app's proxy because mpv opens the
/// streams itself.
final class _PlayerProxyDialog extends ConsumerStatefulWidget {
  const _PlayerProxyDialog();

  @override
  ConsumerState<_PlayerProxyDialog> createState() => _PlayerProxyDialogState();
}

final class _PlayerProxyDialogState extends ConsumerState<_PlayerProxyDialog> {
  late bool _enabled = ref.read(playerProxyProvider).enabled;
  late final TextEditingController _host = TextEditingController(text: ref.read(playerProxyProvider).host);
  late final TextEditingController _port = TextEditingController(
    text: ref.read(playerProxyProvider).port > 0 ? '${ref.read(playerProxyProvider).port}' : '',
  );

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  bool get _valid {
    if (!_enabled) return true;
    final port = int.tryParse(_port.text.trim());
    return _host.text.trim().isNotEmpty && port != null && port > 0 && port <= 65535;
  }

  void _confirm() {
    final port = int.tryParse(_port.text.trim()) ?? 0;
    unawaited(ref.read(playerProxyProvider.notifier).save((enabled: _enabled, host: _host.text.trim(), port: port)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final invalid = !_valid;
    return DsDialog(
      title: Text(t.settings.playerProxy),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsSwitch(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            label: Text(t.settings.playerProxyEnable),
          ),
          DsTextField(
            controller: _host,
            enabled: _enabled,
            placeholder: t.settings.proxyHost,
            onChanged: (_) => setState(() {}),
            semanticLabel: t.settings.proxyHost,
          ),
          DsTextField(
            controller: _port,
            enabled: _enabled,
            placeholder: t.settings.proxyPort,
            keyboardType: TextInputType.number,
            error: invalid,
            onChanged: (_) => setState(() {}),
            semanticLabel: t.settings.proxyPort,
          ),
          if (invalid)
            Text(
              t.settings.playerProxyInvalid,
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).danger.text),
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(onPressed: invalid ? null : _confirm, child: Text(t.common.confirm)),
      ],
    );
  }
}

/// A short manual: the concepts and the symptoms the presets exist for.
Future<void> _showPlayerGuide(BuildContext context) => showDsDialog<void>(
  context: context,
  builder: (context) {
    final t = context.t;
    final tips = [
      (DsIcons.circleAlert, t.settings.playerGuideTip1),
      (DsIcons.sparkles, t.settings.playerGuideTip2),
      (DsIcons.wifi, t.settings.playerGuideTip3),
      (DsIcons.volume, t.settings.playerGuideTip4),
    ];
    return DsDialog(
      title: Text(t.settings.playerGuide),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.settings.playerGuideIntro),
          for (final (icon, text) in tips)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                DsIcon(icon, size: 16),
                Expanded(child: Text(text)),
              ],
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  },
);
