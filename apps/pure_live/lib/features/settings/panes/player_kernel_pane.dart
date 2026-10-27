import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/dialogs/player_guide_dialog.dart' show showPlayerGuide;
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/features/settings/playback/player_tuning.dart';
import 'package:pure_live/features/settings/surface/settings_page.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsHint, SettingsSegmentedRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The player kernel page: the engine in use, its hardware decoding and
/// force-destroy switches, the tuning recipe and Anime4K pickers, and the
/// reset. The mpv knob table — outputs, sync, scaling and the engine's own
/// proxy — lives on the advanced subpage so the common rows are not drowned.
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
    final platform = defaultTargetPlatform;
    final mpv = selected == PlayerKernelBackend.mpv;
    final decoders = playerHardwareDecoderOptions(platform);
    final decoder = effectivePlayerHardwareDecoder(tuning.hwdec, platform);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navKernel),
          children: [
            if (backends.length > 1)
              SettingsSegmentedRow<PlayerKernelBackend>(
                leading: const DsIcon(DsIcons.cpu),
                title: t.settings.engineTitle,
                description: t.settings.engineDesc,
                value: selected,
                options: [for (final backend in backends) (value: backend, label: _engineLabel(t, backend))],
                onChanged: (backend) => unawaited(ref.read(playerKernelBackendProvider.notifier).select(backend)),
              )
            else
              DsListRow(
                leading: const DsIcon(DsIcons.cpu),
                title: Text(t.settings.engineTitle),
                description: Text(t.settings.engineDesc),
                detail: Text(_engineLabel(t, selected)),
              ),
            SettingsHint(backends.length > 1 ? t.settings.kernelSwitchHint : t.settings.kernelOnlyOne),
            if (mpv) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.microchip),
                title: t.settings.hardwareDecoding,
                description: tuning.customOutput
                    ? t.settings.customOutputHardwareTakeover
                    : t.settings.hardwareDecodingDesc,
                control: DsSwitch(
                  value: settings.hardwareDecoding,
                  // Custom output arms the decoder pick and replaces this
                  // switch (reference `custom_output_hwdec`).
                  onChanged: tuning.customOutput
                      ? null
                      : (value) =>
                            unawaited(ref.read(playbackSettingsProvider.notifier).setHardwareDecoding(value: value)),
                ),
              ),
              if (tuning.customOutput)
                SettingsChoiceRow<String>(
                  leading: const DsIcon(DsIcons.circuitBoard),
                  title: t.settings.hardwareDecoder,
                  description: tuning.preset.lockedOutputKeys.contains('hwdec')
                      ? '${t.settings.playerOutputLockedByPreset} · ${t.settings.hardwareDecoderDesc}'
                      : t.settings.hardwareDecoderDesc,
                  value: decoder,
                  options: [
                    for (final value in decoders) DsSelectOption(value: value, label: _hardwareDecoderLabel(t, value)),
                  ],
                  onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setHwdec(value)),
                ),
              if (settings.hardwareDecoding && !tuning.customOutput) SettingsHint(t.settings.hardwareDecoderAutoHint),
              SettingsHint(t.settings.hardwareDecodingHint),
            ],
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.power),
              title: t.settings.forceDestroy,
              description: t.settings.forceDestroyDesc,
              control: DsSwitch(
                value: tuning.forceDestroy,
                onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setForceDestroy(value: value)),
              ),
            ),
          ],
        ),
        if (mpv) ...[
          const _PlayerPresetSection(),
          if (superResolutionAvailable) const _SuperResolutionSection(),
        ] else
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s20),
            child: Text(
              t.settings.playerAdvancedRequiresMpv,
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
            ),
          ),
        DsListSection(
          children: [
            const SettingsChildEntry(child: SettingsSection.kernelAdvanced),
            // The reset belongs on the outer page, not buried in the knob
            // table: it is the way out of anything the recipes or the
            // advanced page changed.
            if (mpv)
              DsListRow(
                leading: const DsIcon(DsIcons.rotateCcw),
                title: Text(t.settings.mpvReset),
                description: Text(t.settings.mpvResetDesc),
                destructive: true,
                onPressed: () => unawaited(_resetMpvSettings(context, ref)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The kernel's advanced subpage: the mpv output, sync, scaling and
/// decoder rows, the engine's own proxy (separate from the app's, because
/// mpv opens the streams itself) and the documentation entries.
final class PlayerKernelAdvancedPane extends ConsumerWidget {
  /// The advanced page's content.
  const PlayerKernelAdvancedPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final mpv = ref.watch(playerKernelBackendProvider) == PlayerKernelBackend.mpv;
    if (!mpv) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s20),
        child: Text(
          t.settings.playerAdvancedRequiresMpv,
          style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
        ),
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [_PlayerProxySection(), _PlayerAdvancedSection()],
    );
  }
}

/// The mpv proxy's entry row: the editor dialog carries the switches.
final class _PlayerProxySection extends ConsumerWidget {
  const _PlayerProxySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final proxy = ref.watch(playerProxyProvider);
    return DsListSection(
      header: Text(t.settings.playerProxy),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.globe),
          title: Text(t.settings.playerProxy),
          description: Text(t.settings.playerProxyDesc),
          detail: Text(proxy.enabled && proxy.host.isNotEmpty ? '${proxy.host}:${proxy.port}' : t.settings.optionOff),
          showChevron: true,
          onPressed: () => unawaited(_showPlayerProxyDialog(context)),
        ),
      ],
    );
  }
}

/// The six tuning recipes, platform-gated, in one picker: the row names the
/// recipe in force and spells out what it does, and the two one-click
/// actions stay rows because they are actions, not a choice.
final class _PlayerPresetSection extends ConsumerWidget {
  const _PlayerPresetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final tuning = ref.watch(playerTuningProvider);
    final active = tuning.preset;
    return DsListSection(
      header: Text(t.settings.playerPresets),
      children: [
        SettingsHint(t.settings.playerPresetsHint),
        SettingsChoiceRow<PlayerPresetId>(
          leading: DsIcon(_presetIcon(active)),
          title: t.settings.preset,
          // The chosen recipe's own explanation rides on the row, so the
          // picker never hides what applying it would do.
          description: _presetDescription(t, active),
          // A recipe restored from another platform's backup is named but
          // not offered: it stays visible until something available is picked.
          value: active.availableHere ? active : null,
          placeholder: _presetName(t, active),
          options: [
            for (final preset in PlayerPresetId.values)
              if (preset.availableHere) DsSelectOption(value: preset, label: _presetName(t, preset)),
          ],
          onChanged: (preset) => unawaited(_applyPreset(context, ref, preset)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.wandSparkles),
          title: Text(t.settings.playerOneClick),
          description: Text(t.settings.playerOneClickDesc),
          showChevron: true,
          onPressed: () => unawaited(
            _applyOneClickPreset(context, ref, preset: PlayerPresetId.balanced, icon: DsIcons.wandSparkles),
          ),
        ),
        if (PlayerPresetId.compat.availableHere)
          DsListRow(
            leading: const DsIcon(DsIcons.smartphone),
            title: Text(t.settings.playerCompatFix),
            description: Text(t.settings.playerCompatFixDesc),
            showChevron: true,
            onPressed: () =>
                unawaited(_applyOneClickPreset(context, ref, preset: PlayerPresetId.compat, icon: DsIcons.smartphone)),
          ),
      ],
    );
  }
}

/// Applies one of the six recipes and says so; the picker's whole job.
Future<void> _applyPreset(BuildContext context, WidgetRef ref, PlayerPresetId preset) async {
  final t = context.t;
  await ref.read(playerTuningProvider.notifier).applyPreset(preset);
  if (context.mounted) showDsToast(context: context, title: t.settings.playerPresetApplied);
}

/// The reference's one-click actions (recommended setup and Android
/// compatibility): name the preset, confirm, then apply it, so a broken
/// picture needs no tour of the six recipes.
Future<void> _applyOneClickPreset(
  BuildContext context,
  WidgetRef ref, {
  required PlayerPresetId preset,
  required DsIconData icon,
}) async {
  final t = context.t;
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.playerOneClickConfirmTitle,
    description: t.settings.playerOneClickConfirmBody(preset: _presetName(t, preset)),
    confirmLabel: t.common.confirm,
    cancelLabel: t.common.cancel,
    icon: DsIcon(icon),
  );
  if (!confirmed) return;
  await ref.read(playerTuningProvider.notifier).applyPreset(preset);
  if (context.mounted) {
    showDsToast(
      context: context,
      title: t.settings.playerOneClickApplied(preset: _presetName(t, preset)),
    );
  }
}

/// Anime4K's three modes in the same picker, with the mode's own explanation
/// on the row and the platform caveat under it.
final class _SuperResolutionSection extends ConsumerWidget {
  const _SuperResolutionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final mode = ref.watch(superResolutionModeProvider);
    return DsListSection(
      header: Text(t.settings.superResolutionGroup),
      children: [
        SettingsSegmentedRow<SuperResolutionMode>(
          leading: DsIcon(_superResolutionIcon(mode)),
          title: t.settings.superResolution,
          description: _superResolutionDescription(t, mode),
          value: mode,
          options: [
            for (final candidate in SuperResolutionMode.values)
              (value: candidate, label: _superResolutionName(t, candidate)),
          ],
          onChanged: (next) => unawaited(ref.read(superResolutionModeProvider.notifier).select(next)),
        ),
        SettingsHint(t.settings.superResolutionHint),
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
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.slidersHorizontal),
          title: t.settings.customOutput,
          description: t.settings.customOutputDesc,
          control: DsSwitch(
            value: tuning.customOutput,
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setCustomOutput(value: value)),
          ),
        ),
        if (tuning.customOutput)
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.monitor),
            title: t.settings.videoOutput,
            description: tuning.preset.lockedOutputKeys.contains('vo')
                ? '${t.settings.playerOutputLockedByPreset} · ${t.settings.videoOutputHint}'
                : t.settings.videoOutputHint,
            value: tuning.vo,
            options: [
              for (final value in videoOutputs) DsSelectOption(value: value, label: _videoOutputLabel(t, value)),
            ],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setVo(value)),
          ),
        if (tuning.customOutput)
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.volume),
            title: t.settings.audioOutput,
            value: tuning.ao,
            options: [
              for (final value in audioOutputs) DsSelectOption(value: value, label: _audioOutputLabel(t, value)),
            ],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setAo(value)),
          ),
        if (desktop)
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.timer),
            title: t.settings.videoSync,
            description: t.settings.videoSyncDesc,
            value: tuning.videoSync,
            options: [
              for (final value in playerVideoSyncOptions)
                DsSelectOption(value: value, label: _videoSyncLabel(t, value)),
            ],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setVideoSync(value)),
          ),
        if (desktop)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.activity),
            title: t.settings.interpolation,
            description: t.settings.interpolationDesc,
            control: DsSwitch(
              value: tuning.interpolation,
              onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setInterpolation(value: value)),
            ),
          ),
        SettingsChoiceRow<String>(
          leading: const DsIcon(DsIcons.expand),
          title: t.settings.scaleKernel,
          description: t.settings.scaleKernelDesc,
          value: tuning.scale,
          options: [
            for (final value in playerScaleOptions(platform))
              DsSelectOption(value: value, label: _scaleLabel(t, value)),
          ],
          onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setScale(value)),
        ),
        SettingsChoiceRow<String>(
          leading: const DsIcon(DsIcons.scanLine),
          title: t.settings.deinterlace,
          description: t.settings.deinterlaceDesc,
          value: tuning.deinterlace,
          options: [
            for (final value in playerDeinterlaceOptions)
              DsSelectOption(value: value, label: _deinterlaceLabel(t, value)),
          ],
          onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setDeinterlace(value)),
        ),
        if ((platform == TargetPlatform.android || platform == TargetPlatform.windows) &&
            playerHardwareDecodingActive(hardwareDecoding: settings.hardwareDecoding, tuning: tuning))
          SettingsChoiceRow<String>(
            leading: const DsIcon(DsIcons.fileText),
            title: t.settings.hwdecCodecs,
            description: t.settings.hwdecCodecsDesc,
            value: tuning.hwdecCodecs,
            options: [
              for (final value in playerHwdecCodecOptions(platform))
                DsSelectOption(value: value, label: _hwdecCodecLabel(t, value)),
            ],
            onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setHwdecCodecs(value)),
          ),
        if (playerAudioExclusiveOptions(platform).isNotEmpty)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.headphones),
            title: t.settings.audioExclusive,
            description: t.settings.audioExclusiveDesc,
            control: DsSwitch(
              value: tuning.audioExclusive,
              onChanged: (value) => unawaited(ref.read(playerTuningProvider.notifier).setAudioExclusive(value: value)),
            ),
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
          onPressed: () => unawaited(showPlayerGuide(context)),
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
    description: t.settings.mpvResetConfirm,
    confirmLabel: t.settings.styleReset,
    cancelLabel: t.common.cancel,
    destructive: true,
    icon: const DsIcon(DsIcons.rotateCcw),
  );
  if (!confirmed) return;
  await ref.read(playerTuningProvider.notifier).resetKernelDefaults();
  await ref.read(playbackSettingsProvider.notifier).setHardwareDecoding(value: true);
  if (context.mounted) {
    showDsToast(context: context, title: t.settings.mpvResetDone);
  }
}

String _engineLabel(Translations t, PlayerKernelBackend backend) => switch (backend) {
  PlayerKernelBackend.mpv => t.settings.playerEngineMpv,
  PlayerKernelBackend.ijk => t.settings.playerEngineIjk,
  PlayerKernelBackend.betterPlayer => t.settings.playerEngineBetterPlayer,
};

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
String _videoOutputLabel(Translations t, String value) => switch (value) {
  'auto' => t.settings.videoOutputAuto,
  'libmpv' => t.settings.videoOutputLibmpv,
  'gpu' => t.settings.videoOutputGpu,
  'gpu-next' => t.settings.videoOutputGpuNext,
  'direct3d' => t.settings.videoOutputDirect3d,
  'null' => t.settings.videoOutputNull,
  'mediacodec_embed' => t.settings.videoOutputMediacodecEmbed,
  _ => _optionLabel(t, value),
};

String _hardwareDecoderLabel(Translations t, String value) => switch (value) {
  'auto' => t.settings.hardwareDecoderAuto,
  'auto-safe' => t.settings.hardwareDecoderAutoSafe,
  'auto-unsafe' => t.settings.hardwareDecoderAutoUnsafe,
  'yes' => t.settings.hardwareDecoderYes,
  'auto-copy' => t.settings.hardwareDecoderAutoCopy,
  'd3d11va' => t.settings.hardwareDecoderD3d11va,
  'd3d11va-copy' => t.settings.hardwareDecoderD3d11vaCopy,
  'nvdec' => t.settings.hardwareDecoderNvdec,
  'nvdec-copy' => t.settings.hardwareDecoderNvdecCopy,
  'videotoolbox' => t.settings.hardwareDecoderVideotoolbox,
  'videotoolbox-copy' => t.settings.hardwareDecoderVideotoolboxCopy,
  'vaapi' => t.settings.hardwareDecoderVaapi,
  'vaapi-copy' => t.settings.hardwareDecoderVaapiCopy,
  'vdpau' => t.settings.hardwareDecoderVdpau,
  'vdpau-copy' => t.settings.hardwareDecoderVdpauCopy,
  'mediacodec' => t.settings.hardwareDecoderMediacodec,
  'mediacodec-copy' => t.settings.hardwareDecoderMediacodecCopy,
  'no' => t.settings.hardwareDecoderSoftware,
  _ => _optionLabel(t, value),
};

String _audioOutputLabel(Translations t, String value) => switch (value) {
  'auto' => t.settings.audioOutputAuto,
  'audiotrack' => t.settings.audioOutputAudiotrack,
  'aaudio' => t.settings.audioOutputAaudio,
  'opensles' => t.settings.audioOutputOpensles,
  'audiounit' => t.settings.audioOutputAudiounit,
  'wasapi' => t.settings.audioOutputWasapi,
  'win32' => t.settings.audioOutputWin32,
  'sdl' => t.settings.audioOutputSdl,
  'pcm' => t.settings.audioOutputPcm,
  'alsa' => t.settings.audioOutputAlsa,
  'pipewire' => t.settings.audioOutputPipewire,
  'null' => t.settings.audioOutputNull,
  _ => _optionLabel(t, value),
};

String _videoSyncLabel(Translations t, String value) => switch (value) {
  'audio' => t.settings.videoSyncAudio,
  'display-resample' => t.settings.videoSyncDisplayResample,
  'display-resample-vdrop' => t.settings.videoSyncDisplayResampleVdrop,
  'display-resample-drop' => t.settings.videoSyncDisplayResampleDrop,
  'display-adrop' => t.settings.videoSyncDisplayAdrop,
  'display-vdrop' => t.settings.videoSyncDisplayVdrop,
  'display-desync' => t.settings.videoSyncDisplayDesync,
  'desync' => t.settings.videoSyncDesync,
  _ => value,
};

String _scaleLabel(Translations t, String value) => switch (value) {
  'lanczos' => t.settings.scaleLanczos,
  'ewa_lanczossharp' => t.settings.scaleEwaLanczosSharp,
  'ewa_lanczos4sharpest' => t.settings.scaleEwaLanczos4Sharpest,
  'ewa_lanczos' => t.settings.scaleEwaLanczos,
  'spline36' => t.settings.scaleSpline36,
  'spline16' => t.settings.scaleSpline16,
  'catmull_rom' => t.settings.scaleCatmullRom,
  'mitchell' => t.settings.scaleMitchell,
  'hermite' => t.settings.scaleHermite,
  'bicubic_fast' => t.settings.scaleBicubicFast,
  'bilinear' => t.settings.scaleBilinear,
  'nearest' => t.settings.scaleNearest,
  _ => value,
};

String _deinterlaceLabel(Translations t, String value) => switch (value) {
  'auto' => t.settings.deinterlaceAuto,
  'no' => t.settings.deinterlaceOff,
  'yes' => t.settings.deinterlaceOn,
  _ => value,
};

String _hwdecCodecLabel(Translations t, String value) => switch (value) {
  'all' => t.settings.hwdecCodecsAll,
  'h264,hevc' => t.settings.hwdecCodecsH264Hevc,
  'h264,hevc,vp9' => t.settings.hwdecCodecsH264HevcVp9,
  'h264,hevc,vp9,av1' => t.settings.hwdecCodecsH264HevcVp9Av1,
  _ => value,
};

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
  late final TextEditingController _port = TextEditingController(text: '${ref.read(playerProxyProvider).port}');

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
