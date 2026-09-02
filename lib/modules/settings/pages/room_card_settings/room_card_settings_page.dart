import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/mobile_settings_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/desktop_settings_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config_controller.dart';

class RoomCardSettingsPage extends GetView<RoomCardConfigController> {
  const RoomCardSettingsPage({super.key});

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
              subtitle: '${i18n('mobile_layout')} • ${RoomCardPreset.fromKey(controller.mobilePreset.value).label}',
              onTap: () => Get.to(() => const MobileSettingsPage()),
            ),
            context.buildTile(
              icon: Icons.computer_rounded,
              title: i18n('desktop'),
              subtitle: '${i18n('desktop_layout')} • ${RoomCardPreset.fromKey(controller.desktopPreset.value).label}',
              onTap: () => Get.to(() => const DesktopSettingsPage()),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
