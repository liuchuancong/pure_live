import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/local_interaction_controller.dart';

class LocalInteractionSettingsPage extends StatefulWidget {
  const LocalInteractionSettingsPage({super.key});

  @override
  State<LocalInteractionSettingsPage> createState() => _LocalInteractionSettingsPageState();
}

class _LocalInteractionSettingsPageState extends State<LocalInteractionSettingsPage> {
  late final LocalInteractionController controller;
  late final TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<LocalInteractionController>();
    nameController = TextEditingController(text: controller.userName.v);
  }

  @override
  void dispose() {
    controller.updateName(nameController.text);
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('local_interaction_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('local_interaction_settings')),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('local_interaction_enable'),
              subtitle: i18n('local_interaction_enable_desc'),
              value: controller.enabled,
              icon: Icons.auto_awesome_rounded,
              isLong: true,
            ),
          ]),
          Obx(() {
            if (!controller.enabled.v) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                context.buildGroupTitle(i18n('local_user_profile')),
                context.buildModernCard([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: TextField(
                      controller: nameController,
                      maxLength: 20,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(labelText: i18n('local_user_name'), counterText: ''),
                      onSubmitted: controller.updateName,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n('local_title_select'), style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Obx(
                          () => Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: LocalInteractionController.titles
                                .map(
                                  (title) => ChoiceChip(
                                    label: Text(i18n('local_title_$title')),
                                    selected: controller.selectedTitle.v == title,
                                    onSelected: (_) => controller.selectedTitle.v = title,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  context.buildSwitchTile(
                    title: i18n('local_overlay_message'),
                    subtitle: i18n('local_overlay_message_desc'),
                    value: controller.showAsDanmaku,
                    icon: Icons.subtitles_rounded,
                    isLong: true,
                  ),
                  Obx(
                    () => context.buildTile(
                      title: i18n('local_interaction_status'),
                      subtitle: '${controller.coins.v} · Lv.${controller.level}',
                      icon: Icons.toll_rounded,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(i18n('local_interaction_room_entry_desc'), style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
