import 'package:flutter/services.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/config/app_settings_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';

class RoomTimerDialog {
  const RoomTimerDialog._();

  static Future<void> show({required BuildContext context, required LivePlayController controller}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _RoomTimerEditor(controller: controller),
    );
  }
}

class _RoomTimerEditor extends StatefulWidget {
  const _RoomTimerEditor({required this.controller});

  final LivePlayController controller;

  @override
  State<_RoomTimerEditor> createState() => _RoomTimerEditorState();
}

class _RoomTimerEditorState extends State<_RoomTimerEditor> {
  static const _presets = <int>[15, 30, 45, 60, 90, 120, 240, 480];

  late final TextEditingController _durationController;
  late final int _initialMinutes;
  late bool _enabled;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    final ui = widget.controller.state.value.ui;
    _initialMinutes = ui.closeTimes.clamp(1, AppSettingsController.maxSleepMinutes).toInt();
    _enabled = ui.closeTimeFlag;
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
    if (_durationError != null) setState(() => _durationError = null);
  }

  void _submit() {
    var minutes = int.tryParse(_durationController.text.trim());
    if (_enabled && (minutes == null || minutes < 1 || minutes > AppSettingsController.maxSleepMinutes)) {
      setState(() => _durationError = i18n('room_playback_timer_custom_hint'));
      return;
    }

    // Turning an active timer off must remain possible while the duration is
    // an unfinished draft. Keep the last valid value for a later re-enable.
    minutes ??= _initialMinutes;
    if (minutes < 1 || minutes > AppSettingsController.maxSleepMinutes) minutes = _initialMinutes;
    widget.controller.applyRoomPlaybackTimer(enabled: _enabled, minutes: minutes);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
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
                  key: const ValueKey('room-timer-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(i18n('room_playback_timer'), style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        key: const ValueKey('room-timer-enabled'),
                        title: Text(i18n('room_playback_timer_enable')),
                        subtitle: Text(i18n('room_playback_timer_desc')),
                        contentPadding: EdgeInsets.zero,
                        value: _enabled,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (value) {
                          setState(() {
                            _enabled = value;
                            _durationError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final minutes in _presets)
                            ActionChip(
                              key: ValueKey('room-timer-preset-$minutes'),
                              label: Text('$minutes ${i18n('minutes')}'),
                              onPressed: _enabled ? () => _selectPreset(minutes) : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('room-timer-duration'),
                        controller: _durationController,
                        enabled: _enabled,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        onChanged: (_) {
                          if (_durationError != null) setState(() => _durationError = null);
                        },
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: i18n('room_playback_timer_duration'),
                          suffixText: i18n('minutes'),
                          helperText: i18n('room_playback_timer_custom_hint'),
                          errorText: _durationError,
                          border: const OutlineInputBorder(),
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
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
                        FilledButton(
                          key: const ValueKey('room-timer-confirm'),
                          onPressed: _submit,
                          child: Text(i18n('confirm')),
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
    );
  }
}
