import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/dialogs/asmr_sleep_dialog.dart' show showAsmrSleepMinutesDialog;
import 'package:pure_live/features/settings/general/refresh_rate_section.dart' show RefreshRateSection;
import 'package:pure_live/features/settings/general/tv_preferences.dart'
    show tvFocusZoomProvider, tvMenuExpandedProvider;
import 'package:pure_live/features/settings/general/window_size_row.dart' show WindowSizeRow;
import 'package:pure_live/features/settings/playback/floating_window_settings.dart' show floatingWindowSettingsProvider;
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart'
    show
        PlaybackFit,
        asmrSleepDurationLabel,
        fitLabels,
        kControlsAutoHideSecondsMax,
        kControlsAutoHideSecondsMin,
        kPreferredResolutionChoices,
        kVolumeWheelStepChoices,
        kWindowsPipMinHeightMax,
        kWindowsPipMinHeightMin,
        kWindowsPipMinWidthMax,
        kWindowsPipMinWidthMin,
        playbackSettingsProvider;
import 'package:pure_live/features/settings/playback/portrait_settings_providers.dart'
    show PortraitLayoutMode, portraitLayoutModeProvider;
import 'package:pure_live/features/settings/room/room_switcher_settings.dart' show portraitSwipeSwitchProvider;
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsChild;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/pages/recorder_page.dart' show RecordingSettingsPane;
import 'package:pure_live/shared/shared.dart' show AppModule;

/// The window page: the window's own shape — title bar, room windows, size
/// and refresh rate. Closing and exit behaviour is the startup page's task.
final class WindowPane extends ConsumerWidget {
  const WindowPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final primary = ref.watch(isPrimaryWindowProvider);
    final formFactor = ref.watch(platformRuntimeProvider).environment.runtime.formFactor;
    final desktop = formFactor == FormFactor.desktop;
    final tv = formFactor == FormFactor.tv;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // A TV's remote has no pointer: how far focus grows and whether the
        // menu stays open are its display choices, so they sit with the
        // window rather than on the sites page.
        if (tv)
          DsListSection(
            header: Text(t.settings.tvGroup),
            children: [
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.focus),
                title: t.settings.tvFocusZoom,
                description: t.settings.tvFocusZoomDesc,
                control: DsSwitch(
                  value: ref.watch(tvFocusZoomProvider),
                  onChanged: (value) => unawaited(ref.read(tvFocusZoomProvider.notifier).set(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.panelLeft),
                title: t.settings.tvMenuExpanded,
                description: t.settings.tvMenuExpandedDesc,
                control: DsSwitch(
                  value: ref.watch(tvMenuExpandedProvider),
                  onChanged: (value) => unawaited(ref.read(tvMenuExpandedProvider.notifier).set(value: value)),
                ),
              ),
            ],
          ),
        DsListSection(
          header: Text(t.settings.windowGroup),
          children: [
            if (desktop)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.appWindow),
                title: t.settings.roomWindow,
                description: t.settings.roomWindowDesc,
                control: DsSwitch(
                  value: ref.watch(roomWindowsProvider),
                  onChanged: (value) => unawaited(ref.read(roomWindowsProvider.notifier).setEnabled(value: value)),
                ),
              ),
            if (primary && desktop) const WindowSizeRow(),
          ],
        ),
        const RefreshRateSection(),
      ],
    );
  }
}

/// Applies the z-order choice to a compact Windows window when one is up,
/// then stores it for the next entry.
Future<void> _setWindowsPipAlwaysOnTop(WidgetRef ref, bool value) async {
  final window = ref.read(windowsPipWindowProvider);
  if (window != null) {
    try {
      await window.setAlwaysOnTop(value: value);
    } on Object {
      // The next PiP entry reads the stored choice again.
    }
  }
  await ref.read(playbackSettingsProvider.notifier).setWindowsPipAlwaysOnTop(value: value);
}

/// Pushes the current PiP size policy into the driver; the next compact
/// window uses it without a restart.
void _syncWindowsPipConfig(WidgetRef ref) {
  ref.read(pipDriverProvider).config = windowsPipConfigFor(ref.read(playbackSettingsProvider));
}

/// Clears both remembered compact-window placements after a confirmation;
/// the next PiP entry opens at the app window's own corner again.
Future<void> _resetWindowsPipGeometry(BuildContext context) async {
  final t = context.t;
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.windowsPipResetPosition,
    description: t.settings.windowsPipResetPositionConfirm,
    confirmLabel: t.settings.windowsPipResetAction,
    cancelLabel: t.common.cancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await clearPipSavedBounds();
  if (!context.mounted) {
    return;
  }
  showDsToast(context: context, title: t.settings.windowsPipResetPositionSuccess);
}

/// A resolution tier's localized name; an unknown tier shows as stored.
String preferredQualityLabel(Translations t, String quality) => switch (quality) {
  '原画' => t.settings.qualityOriginal,
  '蓝光8M' => t.settings.qualityBluRay8M,
  '蓝光4M' => t.settings.qualityBluRay4M,
  '蓝光' => t.settings.qualityBluRay,
  '超清' => t.settings.qualityUltra,
  '高清' => t.settings.qualityHigh,
  '标清' => t.settings.qualityStandard,
  '流畅' => t.settings.qualitySmooth,
  _ => quality,
};

/// The quality-and-sound page: the stream quality a room opens with (and
/// its cellular cap) and the audio defaults, in one page because both are
/// the same user task — what playback sounds and looks like by default.
/// Picture geometry is its own page. All applied as the player handle
/// arrives.
final class QualityAudioPane extends ConsumerWidget {
  const QualityAudioPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    final network = ref.watch(networkTypeProvider);
    final stored = settings.preferredQuality ?? kPreferredResolutionChoices.first;
    // The rendition a room opens with, the danmaku habit behind it and the
    // ASMR sleep timer are the live room's own: the IPTV page has no quality
    // ladder, and the video station and the short-drama player name their own
    // first tier. The audio rows are not all shared either — the room is the
    // only player that seeds itself from the stored default mute, while every
    // one of these four pages turns a desktop wheel by the stored step, so
    // each row is shown where a reader exists and hidden where there is none.
    final module = ref.watch(selectedModuleProvider);
    final roomOnly = module == AppModule.live;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (roomOnly)
          DsListSection(
            header: Text(t.settings.navQuality),
            children: [
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.gauge),
                title: t.settings.preferredQuality,
                description: t.settings.preferredQualityDesc,
                value: stored,
                options: [
                  for (final quality in kPreferredResolutionChoices)
                    DsSelectOption(value: quality, label: preferredQualityLabel(t, quality)),
                ],
                onChanged: (value) => unawaited(controller.setPreferredQuality(value)),
              ),
              if (network.reportsCellular)
                SettingsChoiceRow<String>(
                  leading: const DsIcon(DsIcons.smartphone),
                  title: t.settings.preferredQualityCellular,
                  description: t.settings.preferredQualityCellularDesc,
                  value: settings.preferredQualityCellular ?? kPreferredResolutionChoices.first,
                  options: [
                    for (final quality in kPreferredResolutionChoices)
                      DsSelectOption(value: quality, label: preferredQualityLabel(t, quality)),
                  ],
                  onChanged: (value) => unawaited(controller.setPreferredQualityCellular(value)),
                ),
            ],
          ),
        DsListSection(
          header: Text(t.settings.navAudio),
          children: [
            if (roomOnly)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.volumeOff),
                title: t.settings.defaultMuted,
                description: t.settings.defaultMutedDesc,
                control: DsSwitch(
                  value: settings.muted,
                  onChanged: (value) => unawaited(controller.setMuted(value: value)),
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.volumeX),
              title: t.settings.globalMute,
              description: t.settings.globalMuteDesc,
              control: DsSwitch(
                value: settings.globalMute,
                onChanged: (value) => unawaited(controller.setGlobalMute(value: value)),
              ),
            ),
            if (ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.android) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.music),
                title: t.settings.backgroundPlay,
                description: t.settings.backgroundPlayDesc,
                control: DsSwitch(
                  value: settings.backgroundPlay,
                  onChanged: (value) => unawaited(controller.setBackgroundPlay(value: value)),
                ),
              ),
              // The phone's own switches behind background play: what this
              // build restricts and where to change it (Android only — the
              // whole block is).
              DsListRow(
                leading: const DsIcon(DsIcons.batteryCharging),
                title: Text(t.settings.navBackgroundGuide),
                description: Text(t.settings.backgroundGuideDescription),
                onPressed: () => openSettingsChild(context, ref, SettingsSection.backgroundGuide),
                showChevron: true,
              ),
              // The room's own background habits: the danmaku that stops when
              // the app does, the audio-only continuation, the PiP close that
              // pauses, and the ASMR timer. No other module reads them.
              if (roomOnly) ...[
                SettingsConfigRow(
                  leading: const DsIcon(DsIcons.captions),
                  title: t.settings.backgroundPauseDanmaku,
                  description: t.settings.backgroundPauseDanmakuDesc,
                  control: DsSwitch(
                    value: settings.backgroundPauseDanmaku,
                    onChanged: (value) => unawaited(controller.setBackgroundPauseDanmaku(value: value)),
                  ),
                ),
                SettingsConfigRow(
                  leading: const DsIcon(DsIcons.headphones),
                  title: t.settings.backgroundAudioOnly,
                  description: t.settings.backgroundAudioOnlyDesc,
                  control: DsSwitch(
                    value: settings.backgroundAudioOnly,
                    onChanged: (value) => unawaited(controller.setBackgroundAudioOnly(value: value)),
                  ),
                ),
                SettingsConfigRow(
                  leading: const DsIcon(DsIcons.pictureInPicture),
                  title: t.settings.pauseOnPipClose,
                  description: t.settings.pauseOnPipCloseDesc,
                  control: DsSwitch(
                    value: settings.pauseOnPipClose,
                    onChanged: (value) => unawaited(controller.setPauseOnPipClose(value: value)),
                  ),
                ),
                SettingsConfigRow(
                  leading: const DsIcon(DsIcons.moon),
                  title: t.settings.asmrSleepMode,
                  description: t.settings.asmrSleepModeDesc,
                  control: DsSwitch(
                    value: settings.asmrSleepMode,
                    onChanged: (value) => unawaited(controller.setAsmrSleepMode(value: value)),
                  ),
                ),
                if (settings.asmrSleepMode)
                  DsListRow(
                    leading: const DsIcon(DsIcons.timer),
                    title: Text(t.settings.asmrSleepTimer),
                    description: Text(t.settings.asmrSleepTimerDesc),
                    trailing: Text(asmrSleepDurationLabel(settings.asmrSleepMinutes)),
                    onPressed: () => unawaited(showAsmrSleepMinutesDialog(context, ref)),
                  ),
              ],
            ],
            // The iOS system picture-in-picture window can also be closed by
            // the viewer, so the same choice is offered there; the Android
            // block above keeps the switch next to its background playback
            // row.
            if (roomOnly && ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.ios)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.pictureInPicture),
                title: t.settings.pauseOnPipClose,
                description: t.settings.pauseOnPipCloseDesc,
                control: DsSwitch(
                  value: settings.pauseOnPipClose,
                  onChanged: (value) => unawaited(controller.setPauseOnPipClose(value: value)),
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.volume),
              title: t.settings.defaultVolume,
              description: t.settings.defaultVolumeDesc,
              detail: Text('${(controller.volume * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: controller.volume,
                onChanged: (value) => unawaited(controller.setVolume(value)),
                semanticLabel: t.settings.defaultVolume,
              ),
            ),
            // Every player that reaches this page handles a pointer wheel:
            // the room, the IPTV play page, the station's video page and the
            // short-drama player all size their step from here.
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.volume2),
              title: t.settings.volumeWheelStep,
              description: t.settings.volumeWheelStepDesc,
              value: settings.volumeWheelStepPercent,
              options: [
                for (final percent in kVolumeWheelStepChoices)
                  DsSelectOption(
                    value: percent,
                    label: t.settings.volumeWheelStepValue(percent: percent),
                  ),
              ],
              onChanged: (value) => unawaited(controller.setVolumeWheelStepPercent(value)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The picture page: how the video fills its area, how a portrait stream
/// shares the room page, and what the screen does around it. The floating and
/// compact windows the picture can leave behind are their own page.
final class PicturePane extends ConsumerWidget {
  const PicturePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final portraitLayout = ref.watch(portraitLayoutModeProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    // Four of this page's rows belong to the live room alone — how a portrait
    // stream shares the room page, the room's habit of opening fullscreen, the
    // portrait fullscreen's swipe between rooms, and the window a room leaves
    // behind. The control bar's hide delay is not read by the IPTV page, which
    // keeps its bars up. The other modules reach
    // this page from their own settings; a row they never read would be a knob
    // that turns nothing, the fault the music module's engine page had.
    final module = ref.watch(selectedModuleProvider);
    final roomOnly = module == AppModule.live;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.pictureDisplayGroup),
          children: [
            SettingsChoiceRow<PlaybackFit>(
              leading: const DsIcon(DsIcons.rectangleHorizontal),
              title: t.settings.fit,
              description: t.settings.fitDesc,
              value: settings.fit,
              options: [
                for (final (index, option) in PlaybackFit.values.indexed)
                  DsSelectOption(value: option, label: fitLabels(t)[index]),
              ],
              placeholder: t.settings.fit,
              onChanged: (value) => unawaited(controller.setFit(value)),
            ),
            // A portrait stream's share of the room page: the engine reports
            // the source's own ratio, so the layout is the only choice left.
            // A select like the fit row above, so the two read as a column of
            // the same control.
            if (roomOnly) ...[
              SettingsChoiceRow<PortraitLayoutMode>(
                leading: const DsIcon(DsIcons.rectangleVertical),
                title: t.settings.portraitLayoutMode,
                description: t.settings.portraitLayoutModeDesc,
                value: portraitLayout,
                options: [
                  DsSelectOption(value: PortraitLayoutMode.balanced, label: t.settings.portraitLayoutBalanced),
                  DsSelectOption(value: PortraitLayoutMode.immersive, label: t.settings.portraitLayoutImmersive),
                  DsSelectOption(
                    value: PortraitLayoutMode.compatibility,
                    label: t.settings.portraitLayoutCompatibility,
                  ),
                ],
                onChanged: (mode) => unawaited(ref.read(portraitLayoutModeProvider.notifier).set(mode)),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.fullscreen),
                title: t.settings.fullscreenDefault,
                description: t.settings.fullscreenDefaultDesc,
                control: DsSwitch(
                  value: settings.fullscreenDefault,
                  onChanged: (value) => unawaited(controller.setFullscreenDefault(value: value)),
                ),
              ),
              // The gesture the portrait fullscreen cannot show: without this
              // row the swipe is a feature nobody can turn on, and the room
              // page reads it on every entry.
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.arrowLeftRight),
                title: t.settings.portraitSwipeSwitch,
                description: t.settings.portraitSwipeSwitchDesc,
                control: DsSwitch(
                  value: ref.watch(portraitSwipeSwitchProvider),
                  onChanged: (value) => unawaited(ref.read(portraitSwipeSwitchProvider.notifier).set(value: value)),
                ),
              ),
            ],
            if (module != AppModule.iptv)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.eyeOff),
                title: t.settings.controlsAutoHide,
                description: t.settings.controlsAutoHideDesc,
                detail: Text(t.settings.controlsAutoHideValue(count: settings.controlsAutoHideSeconds)),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.controlsAutoHideSeconds.toDouble(),
                  min: kControlsAutoHideSecondsMin.toDouble(),
                  max: kControlsAutoHideSecondsMax.toDouble(),
                  divisions: kControlsAutoHideSecondsMax - kControlsAutoHideSecondsMin,
                  onChanged: (value) => unawaited(controller.setControlsAutoHideSeconds(value.round())),
                  semanticLabel: t.settings.controlsAutoHide,
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.sun),
              title: t.settings.keepScreenOn,
              description: t.settings.keepScreenOnDesc,
              control: DsSwitch(
                value: ref.watch(keepScreenOnProvider),
                onChanged: (value) => ref.read(keepScreenOnProvider.notifier).enabled = value,
              ),
            ),
          ],
        ),
        if (roomOnly)
          DsListSection(
            header: Text(t.settings.settingsMore),
            children: const [SettingsChildEntry(child: SettingsSection.floatingWindow)],
          ),
      ],
    );
  }
}

/// The measures the picture-in-picture size row offers, in pixels: the stored
/// range's ends, the default and three steps between.
const List<double> _kWindowsPipBaseSizes = [200, 280, 360, 480, 600, 720];

/// The floating-window page: the in-app window the player leaves behind when
/// a room scrolls away, and the system picture-in-picture it hands the
/// picture to — including the geometry only the Windows shell exposes.
final class FloatingWindowPane extends ConsumerWidget {
  const FloatingWindowPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    final windows = ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.windows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.floatWindowGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pictureInPicture2),
              title: t.settings.floatPlay,
              description: t.settings.floatPlayDesc,
              control: DsSwitch(
                value: settings.floatPlay,
                onChanged: (value) => unawaited(controller.setFloatPlay(value: value)),
              ),
            ),
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.maximize),
              title: t.settings.floatWindowSize,
              description: t.settings.floatWindowSizeDesc,
              value: ref.watch(floatingWindowSettingsProvider).size,
              options: [
                DsSelectOption(value: 'small', label: t.settings.floatWindowSmall),
                DsSelectOption(value: 'medium', label: t.settings.floatWindowMedium),
                DsSelectOption(value: 'large', label: t.settings.floatWindowLarge),
              ],
              onChanged: (value) => unawaited(ref.read(floatingWindowSettingsProvider.notifier).setSize(value)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.pipGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pictureInPicture),
              title: t.settings.autoPip,
              description: t.settings.autoPipDesc,
              control: DsSwitch(
                value: settings.autoPipOnLeave,
                onChanged: (value) => unawaited(controller.setAutoPipOnLeave(value: value)),
              ),
            ),
            // The other platforms give the picture to the operating system's
            // own player, which has none of these knobs.
            if (windows) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.pin),
                title: t.settings.windowsPipAlwaysOnTop,
                description: t.settings.windowsPipAlwaysOnTopDesc,
                control: DsSwitch(
                  value: settings.windowsPipAlwaysOnTop,
                  onChanged: (value) => unawaited(_setWindowsPipAlwaysOnTop(ref, value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.appWindow),
                title: t.settings.rememberPipPosition,
                description: t.settings.rememberPipPositionDesc,
                control: DsSwitch(
                  value: settings.rememberPipPosition,
                  onChanged: (value) => unawaited(controller.setRememberPipPosition(value: value)),
                ),
              ),
              // The window's own measure as a short list instead of a slider:
              // a size the list does not name keeps its own entry, so a value
              // typed on the old slider never reads as empty.
              SettingsChoiceRow<double>(
                leading: const DsIcon(DsIcons.aspectRatio),
                title: t.settings.windowsPipBaseSize,
                description: t.settings.windowsPipBaseSizeDesc,
                value: settings.windowsPipBaseSize,
                options: [
                  for (final size in _kWindowsPipBaseSizes) DsSelectOption(value: size, label: '${size.round()} px'),
                  if (!_kWindowsPipBaseSizes.contains(settings.windowsPipBaseSize))
                    DsSelectOption(
                      value: settings.windowsPipBaseSize,
                      label: '${settings.windowsPipBaseSize.round()} px',
                    ),
                ],
                onChanged: (value) {
                  unawaited(controller.setWindowsPipBaseSize(value));
                  _syncWindowsPipConfig(ref);
                },
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.arrowLeftRight),
                title: t.settings.windowsPipMinWidth,
                description: t.settings.windowsPipMinWidthDesc,
                detail: Text('${settings.windowsPipMinWidth.round()} px'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.windowsPipMinWidth,
                  min: kWindowsPipMinWidthMin,
                  max: kWindowsPipMinWidthMax,
                  divisions: ((kWindowsPipMinWidthMax - kWindowsPipMinWidthMin) / 10).round(),
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipMinWidth(value));
                    _syncWindowsPipConfig(ref);
                  },
                  semanticLabel: t.settings.windowsPipMinWidth,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.moveVertical),
                title: t.settings.windowsPipMinHeight,
                description: t.settings.windowsPipMinHeightDesc,
                detail: Text('${settings.windowsPipMinHeight.round()} px'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.windowsPipMinHeight,
                  min: kWindowsPipMinHeightMin,
                  max: kWindowsPipMinHeightMax,
                  divisions: ((kWindowsPipMinHeightMax - kWindowsPipMinHeightMin) / 10).round(),
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipMinHeight(value));
                    _syncWindowsPipConfig(ref);
                  },
                  semanticLabel: t.settings.windowsPipMinHeight,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.aspectRatio),
                title: t.settings.windowsPipFreeAspect,
                description: t.settings.windowsPipFreeAspectDesc,
                control: DsSwitch(
                  value: settings.windowsPipFreeAspect,
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipFreeAspect(value: value));
                    _syncWindowsPipConfig(ref);
                  },
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.locate),
                title: Text(t.settings.windowsPipResetPosition),
                description: Text(t.settings.windowsPipResetPositionDesc),
                showChevron: true,
                onPressed: () => unawaited(_resetWindowsPipGeometry(context)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The recording pane (the reference's Recording): the recorder's own settings,
/// shared with the recording centre's header so both surfaces write the
/// same stored truth.
final class RecordingPane extends StatelessWidget {
  const RecordingPane({super.key});

  @override
  Widget build(BuildContext context) => const RecordingSettingsPane();
}
