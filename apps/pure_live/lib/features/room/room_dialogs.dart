import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart' hide InteractionState;

/// The room's volume dialog — the reference's `RoomVolumeDialog`.
///
/// The layout is the reference's: a scrollable body (title, description, the
/// global-mute row, the two per-device level rows, the error line and the
/// reset) over a fixed cancel/confirm footer. Its logic is the reference's
/// too: the dialog keeps a draft, the draft is only committed on confirm, a
/// commit that the live player refuses keeps the dialog open with the reason,
/// and the reset restores 0.5 / 1.0 / unmuted without submitting.
Future<void> showRoomVolumeDialog(BuildContext context, RoomIdentity identity) => showPureDialog<void>(
  context: context,
  dismissible: false,
  maxWidth: 520,
  // The toolkit's own dialog surface: the language draws the frame, the
  // dialog below only brings its content. `showDialog` + `Dialog` printed a
  // Material card under every non-Material host.
  child: _RoomVolumeDialog(identity: identity),
);

final class _RoomVolumeDialog extends ConsumerStatefulWidget {
  const new({required this.identity});

  final RoomIdentity identity;

  @override
  ConsumerState<_RoomVolumeDialog> createState() => _RoomVolumeDialogState();
}

final class _RoomVolumeDialogState extends ConsumerState<_RoomVolumeDialog> {
  late bool _mute;
  late double _mobileVolume;
  late double _desktopVolume;
  bool _saving = false;
  String? _applyError;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(appPreferencesProvider);
    _mute = preferences.volumeMuted;
    _mobileVolume = _clamped(preferences.defaultMobileVolume, fallback: 0.5);
    _desktopVolume = _clamped(preferences.defaultDesktopVolume, fallback: 1);
  }

  static double _clamped(double value, {required double fallback}) => value.isFinite ? value.clamp(0.0, 1.0) : fallback;

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _applyError = null;
    });
    final controller = ref.read(roomControllerProvider(widget.identity).notifier);
    try {
      // The reference applies to the live player first and persists only once
      // the player accepted — a refused update leaves the draft editable.
      await controller.commitRoomVolumeDefaults(muted: _mute, mobile: _mobileVolume, desktop: _desktopVolume);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _applyError = context.t.room.volumeApplyFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !_saving,
      // The surface comes from showPureDialog now; this only caps its height
      // so the body scrolls and the footer stays reachable on a short window.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height > 40 ? height - 40 : height),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('room-volume-scroll'),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.room.roomVolume, style: theme.text.title),
                    const SizedBox(height: 8),
                    Text(t.room.roomVolumeDesc, style: theme.text.body.copyWith(color: theme.colors.textSecondary)),
                    const SizedBox(height: 12),
                    _Row(
                      icon: _mute ? Icons.volume_off : Icons.volume_up,
                      iconColor: _mute ? theme.colors.error : theme.colors.primary,
                      title: t.room.globalMute,
                      subtitle: t.room.globalMuteSubtitle,
                      trailing: PureSwitch(
                        value: _mute,
                        enabled: !_saving,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _mute = value;
                                _applyError = null;
                              }),
                      ),
                    ),
                    const PureDivider(extent: 32),
                    _VolumeRow(
                      sliderKey: const ValueKey('room-volume-mobile-slider'),
                      icon: Icons.phone_android,
                      title: t.room.mobileDefaultVolume,
                      value: _mobileVolume,
                      disabled: _mute || _saving,
                      onChanged: (value) => setState(() {
                        _mobileVolume = value;
                        _applyError = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _VolumeRow(
                      sliderKey: const ValueKey('room-volume-desktop-slider'),
                      icon: Icons.computer,
                      title: t.room.desktopDefaultVolume,
                      value: _desktopVolume,
                      disabled: _mute || _saving,
                      onChanged: (value) => setState(() {
                        _desktopVolume = value;
                        _applyError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (_applyError case final error?) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          key: const ValueKey('room-volume-error'),
                          style: theme.text.body.copyWith(color: theme.colors.error),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: PureButton(
                        label: t.room.resetDefault,
                        icon: Icons.refresh,
                        variant: ButtonVariant.ghost,
                        size: ControlSize.sm,
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _mute = false;
                                _mobileVolume = 0.5;
                                _desktopVolume = 1;
                                _applyError = null;
                              }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PureDivider(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PureButton(
                        label: t.common.cancel,
                        variant: ButtonVariant.ghost,
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      ),
                      PureButton(label: t.common.confirm, onPressed: _saving ? null : () => unawaited(_submit())),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled icon/title/subtitle row with a trailing widget — the dialog's
/// mute row, in the reference's SwitchListTile shape without its Material skin.
final class _Row extends StatelessWidget {
  const new({required this.icon, required this.title, required this.trailing, this.iconColor, this.subtitle});

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor ?? theme.colors.text),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.text.body),
              if (subtitle != null)
                Text(subtitle!, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

/// Title with the live percentage as an accent badge, the track under it —
/// the reference's `_VolumeRow`.
final class _VolumeRow extends StatelessWidget {
  const new({
    required this.sliderKey,
    required this.icon,
    required this.title,
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  final Key sliderKey;
  final IconData icon;
  final String title;
  final double value;
  final bool disabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final valueColor = disabled ? theme.colors.textDisabled : theme.colors.primary;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.text.body)),
            const SizedBox(width: 8),
            Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: theme.text.body.copyWith(fontWeight: FontWeight.bold, color: valueColor),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: PureSlider(key: sliderKey, value: value, enabled: !disabled, onChanged: disabled ? null : onChanged),
        ),
      ],
    );
  }
}

/// The room's sleep-timer dialog — the reference's `RoomTimerDialog`.
///
/// Same body/footer split and the same draft contract: the presets and the
/// field edit the dialog's own draft; the countdown only re-arms on confirm;
/// cancelling an active timer still works while the duration is an unfinished
/// draft; a draft out of range refuses to confirm with a reason.
Future<void> showRoomTimerDialog(BuildContext context, RoomIdentity identity) => showPureDialog<void>(
  context: context,
  maxWidth: 520,
  // The language's own dialog surface; see the volume dialog above.
  child: _RoomTimerDialog(identity: identity),
);

final class _RoomTimerDialog extends ConsumerStatefulWidget {
  const new({required this.identity});

  final RoomIdentity identity;

  @override
  ConsumerState<_RoomTimerDialog> createState() => _RoomTimerDialogState();
}

final class _RoomTimerDialogState extends ConsumerState<_RoomTimerDialog> {
  /// The reference's preset row, in its order.
  static const _presets = <int>[15, 30, 45, 60, 90, 120, 240, 480];

  /// The duration ceiling, the reference's `AppSettingsController.maxSleepMinutes`.
  static const _maxMinutes = 525600;

  late final TextEditingController _durationController;
  late final int _initialMinutes;
  late bool _enabled;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    final state = ref.read(roomControllerProvider(widget.identity));
    _initialMinutes = state.sleepMinutes.clamp(1, _maxMinutes);
    _enabled = state.sleepTimerActive;
    _durationController = TextEditingController(text: '$_initialMinutes');
  }

  @override
  void dispose() {
    // The editor owns its draft through the complete dialog exit animation.
    _durationController.dispose();
    super.dispose();
  }

  void _selectPreset(int minutes) {
    _durationController.text = '$minutes';
    _durationController.selection = TextSelection.collapsed(offset: _durationController.text.length);
    if (_durationError != null) {
      setState(() => _durationError = null);
    }
  }

  void _submit() {
    var minutes = int.tryParse(_durationController.text.trim());
    if (_enabled && (minutes == null || minutes < 1 || minutes > _maxMinutes)) {
      setState(() => _durationError = context.t.room.timerInvalid);
      return;
    }
    // Turning an active timer off must remain possible while the duration is
    // an unfinished draft; keep the last valid value for a later re-enable.
    minutes ??= _initialMinutes;
    if (minutes < 1 || minutes > _maxMinutes) {
      minutes = _initialMinutes;
    }
    ref.read(roomControllerProvider(widget.identity).notifier).applySleepTimer(enabled: _enabled, minutes: minutes);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height > 40 ? height - 40 : height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('room-timer-scroll'),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.room.sleepTimer, style: theme.text.title),
                  const SizedBox(height: 16),
                  _Row(
                    icon: Icons.bedtime_outlined,
                    title: t.room.sleepTimerEnable,
                    subtitle: t.room.sleepTimerDesc,
                    trailing: PureSwitch(
                      key: const ValueKey('room-timer-enabled'),
                      value: _enabled,
                      onChanged: (value) => setState(() {
                        _enabled = value;
                        _durationError = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in _presets)
                        PureButton(
                          key: ValueKey('room-timer-preset-$minutes'),
                          label: t.room.minutesN(minutes: '$minutes'),
                          size: ControlSize.sm,
                          variant: _enabled ? ButtonVariant.secondary : ButtonVariant.ghost,
                          onPressed: _enabled ? () => _selectPreset(minutes) : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PureTextField(
                    controller: _durationController,
                    enabled: _enabled,
                    keyboardType: TextInputType.number,
                    placeholder: t.room.timerDurationHint,
                    // The reference spells the accepted range out under the
                    // field; the kit's field has no helper line, so the hint
                    // rides in the placeholder and the error says the rest.
                    errorText: _durationError,
                    suffix: Text(t.room.minutesUnit),
                    onChanged: (_) {
                      if (_durationError != null) {
                        setState(() => _durationError = null);
                      }
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
          ),
          const PureDivider(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PureButton(
                      label: t.common.cancel,
                      variant: ButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    PureButton(label: t.common.confirm, onPressed: _submit),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
