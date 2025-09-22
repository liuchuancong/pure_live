import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/toolbox/toolbox_controller.dart';
import 'package:remixicon/remixicon.dart';

class ToolBoxPage extends GetView<ToolBoxController> {
  const ToolBoxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.live_room_link_parsing),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          buildCard(
            context: context,
            child: ExpansionTile(
              title: Text(S.current.live_room_jump),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              initiallyExpanded: true,
              children: [
                TextField(
                  minLines: 3,
                  maxLines: 3,
                  controller: controller.roomJumpToController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: S.current.live_room_link_input(Sites.supportSites.where((site) => site.id != Sites.iptvSite).map((site) => Sites.getSiteName(site.id)).toList().join("/")),
                    contentPadding: const EdgeInsets.all(12.0),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: .2),
                      ),
                    ),
                  ),
                  onSubmitted: controller.jumpToRoom,
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 4.0),
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      controller.jumpToRoom(controller.roomJumpToController.text);
                    },
                    icon: const Icon(Remix.play_circle_line),
                    label: Text(S.current.live_room_link_jump),
                  ),
                ),
              ],
            ),
          ),
          buildCard(
            context: context,
            child: ExpansionTile(
              title: Text(S.current.live_room_link_direct),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              initiallyExpanded: true,
              children: [
                TextField(
                  minLines: 3,
                  maxLines: 3,
                  controller: controller.getUrlController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: S.current.live_room_link_input(Sites.supportSites.where((site) => site.id != Sites.iptvSite).map((site) => Sites.getSiteName(site.id)).toList().join("/")),
                    contentPadding: const EdgeInsets.all(12.0),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: .2),
                      ),
                    ),
                  ),
                  onSubmitted: controller.getPlayUrl,
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 4.0),
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      controller.getPlayUrl(controller.getUrlController.text);
                    },
                    icon: const Icon(Remix.link),
                    label: Text(S.current.live_room_link_direct),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard({required BuildContext context, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        boxShadow: Get.isDarkMode
            ? []
            : [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.grey.withValues(alpha: .2),
                )
              ],
      ),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}
