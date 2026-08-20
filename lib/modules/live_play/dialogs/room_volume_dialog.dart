import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class RoomVolumeDialog {
  const RoomVolumeDialog._();

  static Future<void> show({required BuildContext context, required LivePlayController controller}) async {
    final tempMute = SettingsService.to.vol.globalVolumeMute.v.obs;

    final tempMobileVol = SettingsService.to.vol.defaultMobileVolume.v.obs;

    final tempDesktopVol = SettingsService.to.vol.defaultDesktopVolume.v.obs;

    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: Text(i18n('room_volume')),
          content: Container(
            constraints: BoxConstraints(minWidth: PlatformUtils.isMobile ? Get.mediaQuery.size.width * 0.8 : 500),
            child: Obx(
              () => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: Text(i18n('global_mute')),
                      secondary: Icon(
                        tempMute.value ? Icons.volume_off : Icons.volume_up,
                        color: tempMute.value ? theme.colorScheme.error : theme.colorScheme.primary,
                      ),
                      value: tempMute.value,
                      activeThumbColor: theme.colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        tempMute.value = value;
                      },
                    ),

                    const Divider(height: 32),

                    _buildVolumeRow(
                      icon: Icons.phone_android,
                      title: i18n('mobile_default_volume'),
                      value: tempMobileVol,
                      disabled: tempMute.value,
                    ),

                    const SizedBox(height: 16),

                    _buildVolumeRow(
                      icon: Icons.computer,
                      title: i18n('desktop_default_volume'),
                      value: tempDesktopVol,
                      disabled: tempMute.value,
                    ),

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          tempMute.value = false;
                          tempMobileVol.value = 0.5;
                          tempDesktopVol.value = 1.0;
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(i18n('reset_default')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('cancel'))),
            FilledButton(
              onPressed: () {
                _save(
                  controller: controller,
                  mute: tempMute.value,
                  mobileVolume: tempMobileVol.value,
                  desktopVolume: tempDesktopVol.value,
                );

                Navigator.pop(context);
              },
              child: Text(i18n('confirm')),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildVolumeRow({
    required IconData icon,
    required String title,
    required RxDouble value,
    required bool disabled,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title)]),
                Obx(
                  () => Text(
                    '${(value.value * 100).toInt()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: disabled ? theme.disabledColor : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            Obx(
              () => Slider(
                value: value.value.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                onChanged: disabled
                    ? null
                    : (newValue) {
                        value.value = newValue;
                      },
              ),
            ),
          ],
        );
      },
    );
  }

  static void _save({
    required LivePlayController controller,
    required bool mute,
    required double mobileVolume,
    required double desktopVolume,
  }) {
    SettingsService.to.vol.globalVolumeMute.v = mute;

    SettingsService.to.vol.defaultMobileVolume.v = mobileVolume.clamp(0.0, 1.0);

    SettingsService.to.vol.defaultDesktopVolume.v = desktopVolume.clamp(0.0, 1.0);

    final videoController = controller.state.value.player.videoController;

    if (mute) {
      videoController?.setVolume(0.0);
      return;
    }

    if (PlatformUtils.isMobile) {
      videoController?.setVolume(mobileVolume);
    } else {
      videoController?.setVolume(desktopVolume);
    }
  }
}
