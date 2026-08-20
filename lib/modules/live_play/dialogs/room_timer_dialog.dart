import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class RoomTimerDialog {
  const RoomTimerDialog._();

  static Future<void> show({required BuildContext context, required LivePlayController controller}) async {
    final durationController = TextEditingController(text: controller.state.value.ui.closeTimes.toString());

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(i18n('room_playback_timer')),
          content: Obx(() {
            final uiState = controller.state.value.ui;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: Text(i18n('room_playback_timer_enable')),
                  subtitle: Text(i18n('room_playback_timer_desc')),
                  contentPadding: EdgeInsets.zero,
                  value: uiState.closeTimeFlag,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: controller.updateTimerFlag,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [15, 30, 45, 60, 90, 120, 240, 480].map((minutes) {
                    return ActionChip(
                      label: Text('$minutes ${i18n('minutes')}'),
                      onPressed: () {
                        durationController.text = minutes.toString();
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n('room_playback_timer_duration'),
                    suffixText: i18n('minutes'),
                    helperText: i18n('room_playback_timer_custom_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            );
          }),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(durationController.text.trim());

                if (minutes == null || minutes < 1 || minutes > AppSettingsController.maxSleepMinutes) {
                  ToastUtil.show(i18n('room_playback_timer_custom_hint'));
                  return;
                }

                controller.updateTimerTimes(minutes);

                controller.updateTimerFlag(true);

                Navigator.of(context).pop();
              },
              child: Text(i18n('start_timer')),
            ),
          ],
        );
      },
    );

    durationController.dispose();
  }
}
