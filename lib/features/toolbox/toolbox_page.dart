import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/toolbox/toolbox_controller.dart';

class ToolBoxPage extends GetView<ToolBoxController> {
  const ToolBoxPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.autoCheckClipboard(context: context));
    });
    return Scaffold(
      appBar: AppBar(title: Text(i18n("toolbox_title")), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        physics: const PureLiveScrollPhysics(),
        children: [
          // Section 1: Jump to Room
          _buildToolCard(
            context,
            title: i18n("toolbox_room_jump"),
            icon: Remix.external_link_line,
            controller: controller.roomJumpToController,
            btnIcon: Remix.play_circle_line,
            btnLabel: i18n("toolbox_link_jump"),
            actionKind: ToolBoxAction.jump,
            onAction: (text) => controller.jumpToRoom(text, context: context),
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
            actionKind: ToolBoxAction.directLink,
            onAction: (text) => controller.getPlayUrl(text, context: context),
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
    required ToolBoxAction actionKind,
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
            title: Text(title, style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold)),
            initiallyExpanded: true,
            shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.transparent)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                minLines: 3,
                maxLines: 5,
                controller: controller,
                style: AppTextStyles.t13,
                decoration: InputDecoration(
                  hintText: i18n("toolbox_input_hint"),
                  hintStyle: AppTextStyles.t13,
                  filled: true,
                  fillColor: Theme.of(context).dividerColor.withValues(alpha: .05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    tooltip: i18n('clear'),
                    icon: const Icon(Remix.close_circle_line, size: 20),
                    onPressed: () => controller.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => FilledButton.icon(
                    onPressed: this.controller.isBusy ? null : () => onAction(controller.text),
                    icon: this.controller.action.value == actionKind
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(btnIcon, size: 18),
                    label: Text(btnLabel),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              Obx(
                () => this.controller.action.value == actionKind
                    ? TextButton(onPressed: this.controller.cancelAction, child: Text(i18n('cancel')))
                    : const SizedBox.shrink(),
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
            Expanded(
              child: Text(
                i18n("toolbox_support_list"),
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(i18n("toolbox_support_content"), style: TextStyle(color: Colors.grey, height: 1.6)),
      ],
    );
  }
}
