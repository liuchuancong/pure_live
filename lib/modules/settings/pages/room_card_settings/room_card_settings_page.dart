import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/mobile_settings_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/desktop_settings_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config_controller.dart';

class RoomCardSettingsPage extends GetView<RoomCardConfigController> {
  const RoomCardSettingsPage({super.key});

  String _getPresetLabel(String presetKey) {
    switch (presetKey) {
      case 'compact':
        return i18n('preset_compact');
      case 'normal':
        return i18n('preset_normal');
      case 'rich':
        return i18n('preset_rich');
      case 'custom':
        return i18n('preset_custom');
      default:
        return i18n('preset_normal');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('room_card_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('room_card_settings_subtitle')),
          context.buildModernCard([
            context.buildTile(
              icon: Icons.phone_android_rounded,
              title: i18n('mobile'),
              subtitle:
                  '${i18n('mobile_layout')} • ${_getPresetLabel(controller.mobilePreset.value)}',
              onTap: () => Get.to(() => const MobileSettingsPage()),
            ),
            context.buildTile(
              icon: Icons.computer_rounded,
              title: i18n('desktop'),
              subtitle:
                  '${i18n('desktop_layout')} • ${_getPresetLabel(controller.desktopPreset.value)}',
              onTap: () => Get.to(() => const DesktopSettingsPage()),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
