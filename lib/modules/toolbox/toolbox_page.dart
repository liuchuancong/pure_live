import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/toolbox/toolbox_controller.dart';

class ToolBoxPage extends GetView<ToolBoxController> {
  const ToolBoxPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Check clipboard automatically when the page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.autoCheckClipboard());

    return Scaffold(
      appBar: AppBar(title: Text(i18n("toolbox_title")), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section 1: Jump to Room
          _buildToolCard(
            context,
            title: i18n("toolbox_room_jump"),
            icon: Remix.external_link_line,
            controller: controller.roomJumpToController,
            btnIcon: Remix.play_circle_line,
            btnLabel: i18n("toolbox_link_jump"),
            onAction: controller.jumpToRoom,
          ),

          const SizedBox(height: 16),

          // Section 2: Get Direct Link (Description is persistent outside the fold)
          _buildToolCard(
            context,
            title: i18n("toolbox_get_direct_link"),
            icon: Remix.link_m,
            controller: controller.getUrlController,
            btnIcon: Remix.download_2_line,
            btnLabel: i18n("toolbox_get_parse"),
            onAction: controller.getPlayUrl,
            extraFooter: _buildDescription(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required IconData btnIcon,
    required String btnLabel,
    required Function(String) onAction,
    Widget? extraFooter,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: Get.isDarkMode ? [] : [BoxShadow(blurRadius: 10, color: Colors.black.withValues(alpha: .05))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpansionTile(
            leading: Icon(icon, color: Theme.of(context).primaryColor),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: true,
            shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.transparent)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                minLines: 3,
                maxLines: 5,
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: i18n("toolbox_input_hint"),
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: Theme.of(context).dividerColor.withValues(alpha: .05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Remix.close_circle_line, size: 20),
                    onPressed: () => controller.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onAction(controller.text),
                  icon: Icon(btnIcon, size: 18),
                  label: Text(btnLabel),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          // extraFooter is placed outside ExpansionTile so it stays visible when folded
          if (extraFooter != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: extraFooter),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Remix.information_line, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              i18n("toolbox_support_list"),
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          i18n("toolbox_support_content"),
          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}
