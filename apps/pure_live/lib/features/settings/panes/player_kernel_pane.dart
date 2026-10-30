import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/features/settings/playback/player_tuning.dart';
import 'package:pure_live/features/settings/surface/settings_page.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_page_action.dart';
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsSegmentedRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The player kernel page: the engine in use, its hardware decoding switch,
/// the tuning recipe, and the reset at the page's top-right. The mpv knob
/// table — outputs, sync, scaling and the engine's own proxy — lives on the
/// advanced subpage so the common rows are not drowned.
final class PlayerKernelPane extends ConsumerStatefulWidget {
  /// The kernel page's content.
  const PlayerKernelPane({super.key});

  @override
  ConsumerState<PlayerKernelPane> createState() => _PlayerKernelPaneState();
}

final class _PlayerKernelPaneState extends ConsumerState<PlayerKernelPane> {
  /// The pushed page's header slot, when the page has one.
  ValueNotifier<Widget?>? _slot;

  /// The reset action as last handed to the slot; null when none was.
  String? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot = SettingsPageActionScope.maybeOf(context);
  }

  @override
  void dispose() {
    // The page outlives this pane only while this pane is gone with it: a
    // header left holding a dead action would press nothing.
    final slot = _slot;
    if (slot != null && _published != null) slot.value = null;
    super.dispose();
  }

  /// Hands [action] to the page header, once per label; a header above this
  /// body must not be rebuilt mid-layout.
  void _publish(String? signature, Widget? action) {
    final slot = _slot;
    if (slot == null || _published == signature) return;
    _published = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) slot.value = action;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final backends = availablePlayerKernelBackends();
    final selected = ref.watch(playerKernelBackendProvider);
    final tuning = ref.watch(playerTuningProvider);
    final platform = defaultTargetPlatform;
    final mpv = selected == PlayerKernelBackend.mpv;
    final decoders = playerHardwareDecoderOptions(platform);
    final decoder = effectivePlayerHardwareDecoder(tuning.hwdec, platform);
    // The reset is a page action, not a row: a pushed page shows it at the
    // header's end, and a pane shown in place keeps it in its own corner.
    final reset = mpv
        ? DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.rotateCw, size: 16),
            onPressed: () => unawaited(_resetMpvSettings(context, ref)),
            child: Text(t.settings.styleReset),
          )
        : null;
    _publish(reset == null ? null : t.settings.styleReset, reset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (_slot == null && reset != null) Align(alignment: AlignmentDirectional.centerEnd, child: reset),
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
        if (mpv)
          const _PlayerPresetSection()
        else
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s20),
            child: Text(
              t.settings.playerAdvancedRequiresMpv,
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
            ),
          ),
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.kernelAdvanced)]),
      ],
    );
  }
}

/// The kernel's advanced subpage: the mpv output, sync, scaling and
/// decoder rows and the documentation entries. The engine's streams route
/// through the app's network proxy, so there is no player-specific one.
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
      children: [_PlayerAdvancedSection()],
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
        const SettingsChildEntry(child: SettingsSection.playerGuide),
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
