import 'package:flutter/foundation.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';

typedef RoomVolumeApplier = Future<void> Function(double volume);

class RoomVolumeDialog {
  const RoomVolumeDialog._();

  static Future<void> show({
    required BuildContext context,
    required LivePlayController controller,
    @visibleForTesting TargetPlatform? platformOverride,
    @visibleForTesting RoomVolumeApplier? applyVolume,
  }) {
    final platform = platformOverride ?? defaultTargetPlatform;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoomVolumeEditor(
        isMobile: platform == TargetPlatform.android || platform == TargetPlatform.iOS,
        applyVolume:
            applyVolume ??
            (volume) async {
              final videoController = controller.state.value.player.videoController;
              if (videoController != null && !await videoController.trySetVolume(volume)) {
                throw StateError('The active room did not accept the volume update');
              }
            },
      ),
    );
  }
}

class _RoomVolumeEditor extends StatefulWidget {
  const _RoomVolumeEditor({required this.isMobile, required this.applyVolume});

  final bool isMobile;
  final RoomVolumeApplier applyVolume;

  @override
  State<_RoomVolumeEditor> createState() => _RoomVolumeEditorState();
}

class _RoomVolumeEditorState extends State<_RoomVolumeEditor> {
  late bool _mute;
  late double _mobileVolume;
  late double _desktopVolume;
  bool _saving = false;
  String? _applyError;

  @override
  void initState() {
    super.initState();
    final volume = SettingsService.to.vol;
    _mute = volume.globalVolumeMute.v;
    _mobileVolume = _normalized(volume.defaultMobileVolume.v, fallback: 0.5);
    _desktopVolume = _normalized(volume.defaultDesktopVolume.v, fallback: 1.0);
  }

  static double _normalized(double value, {required double fallback}) {
    if (!value.isFinite) return fallback;
    return value.clamp(0.0, 1.0).toDouble();
  }

  void _reset() {
    setState(() {
      _mute = false;
      _mobileVolume = 0.5;
      _desktopVolume = 1.0;
      _applyError = null;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _applyError = null;
    });

    final targetVolume = _mute ? 0.0 : (widget.isMobile ? _mobileVolume : _desktopVolume);
    try {
      await widget.applyVolume(targetVolume);
      if (!mounted) return;
      final volume = SettingsService.to.vol;
      volume.globalVolumeMute.v = _mute;
      volume.defaultMobileVolume.v = _mobileVolume;
      volume.defaultDesktopVolume.v = _desktopVolume;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _applyError = i18n('room_volume_apply_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: height > 40 ? height - 40 : height),
          child: SizedBox(
            width: 480,
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
                        Text(i18n('room_volume'), style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(i18n('room_volume_defaults_desc'), style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          key: const ValueKey('room-volume-mute'),
                          title: Text(i18n('global_mute')),
                          subtitle: Text(i18n('global_mute_subtitle')),
                          secondary: Icon(
                            _mute ? Icons.volume_off : Icons.volume_up,
                            color: _mute ? theme.colorScheme.error : theme.colorScheme.primary,
                          ),
                          value: _mute,
                          activeThumbColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _mute = value;
                                    _applyError = null;
                                  });
                                },
                        ),
                        const Divider(height: 32),
                        _VolumeRow(
                          sliderKey: const ValueKey('room-volume-mobile-slider'),
                          icon: Icons.phone_android,
                          title: i18n('mobile_default_volume'),
                          value: _mobileVolume,
                          disabled: _mute || _saving,
                          onChanged: (value) {
                            setState(() {
                              _mobileVolume = value;
                              _applyError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _VolumeRow(
                          sliderKey: const ValueKey('room-volume-desktop-slider'),
                          icon: Icons.computer,
                          title: i18n('desktop_default_volume'),
                          value: _desktopVolume,
                          disabled: _mute || _saving,
                          onChanged: (value) {
                            setState(() {
                              _desktopVolume = value;
                              _applyError = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_applyError case final error?) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              key: const ValueKey('room-volume-error'),
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey('room-volume-reset'),
                            onPressed: _saving ? null : _reset,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(i18n('reset_default')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
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
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: Text(i18n('cancel')),
                          ),
                          FilledButton(
                            key: const ValueKey('room-volume-confirm'),
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(i18n('confirm')),
                                    ],
                                  )
                                : Text(i18n('confirm')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
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
    final theme = Theme.of(context);
    final valueColor = disabled ? theme.disabledColor : theme.colorScheme.primary;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
            const SizedBox(width: 8),
            Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: valueColor),
            ),
          ],
        ),
        Slider(key: sliderKey, value: value, min: 0, max: 1, onChanged: disabled ? null : onChanged),
      ],
    );
  }
}
