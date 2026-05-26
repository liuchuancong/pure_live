import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class TagManagementPage extends GetView<TagManagementController> {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('tag_management')),
        actions: [IconButton(icon: const Icon(Remix.add_line), onPressed: () => _showTagDialog(context))],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 16),
          context.buildGroupTitle(i18n('tag_management')),
          Obx(() {
            if (controller.tags.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.price_tag_3_line, size: 48, color: theme.disabledColor.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text(
                        i18n('no_tags_tip'),
                        style: AppTextStyles.t14.copyWith(color: theme.disabledColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
              ),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.tags.length,
                onReorderItem: (oldIndex, newIndex) => controller.onReorder(oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final tag = controller.tags[index];

                  return Material(
                    key: ValueKey(tag.id),
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(
                        tag.isPinned ? Remix.pushpin_2_fill : Remix.price_tag_3_line,
                        size: 20,
                        color: tag.isPinned ? theme.colorScheme.secondary : theme.colorScheme.primary,
                      ),
                      title: Row(
                        children: [
                          Text(tag.name, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                          if (tag.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                i18n('pinned_label'),
                                style: AppTextStyles.t12.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: tag.description.isNotEmpty
                          ? Text(tag.description, style: AppTextStyles.t12.copyWith(color: theme.disabledColor))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(tag.isPinned ? Remix.pushpin_2_line : Remix.pushpin_line, size: 18),
                            onPressed: () => controller.togglePin(index),
                          ),
                          IconButton(
                            icon: const Icon(Remix.edit_line, size: 18),
                            onPressed: () => _showTagDialog(context, index: index, tag: tag),
                          ),
                          IconButton(
                            icon: Icon(
                              Remix.delete_bin_line,
                              size: 18,
                              color: theme.colorScheme.error.withValues(alpha: 0.8),
                            ),
                            onPressed: () => _confirmDelete(context, index, tag.name),
                          ),
                          const SizedBox(width: 4),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(RemixIcons.sort_asc, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n('drag_to_sort_tip'),
              style: AppTextStyles.t13.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTagDialog(BuildContext context, {int? index, LiveTag? tag}) {
    final isEdit = index != null && tag != null;
    final nameController = TextEditingController(text: isEdit ? tag.name : '');
    final descController = TextEditingController(text: isEdit ? tag.description : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? i18n('edit_tag') : i18n('add_tag')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: !isEdit,
              decoration: InputDecoration(hintText: i18n('tag_input_hint'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(hintText: i18n('tag_desc_hint'), border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('cancel'))),
          ElevatedButton(
            onPressed: () {
              bool success;
              if (isEdit) {
                success = controller.updateTag(index, nameController.text, descController.text);
              } else {
                success = controller.addTag(nameController.text, descController.text);
              }

              if (success) {
                Navigator.pop(context);
              } else {
                SmartDialog.showToast(i18n('tag_invalid_or_duplicate'));
              }
            },
            child: Text(i18n('confirm')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int index, String tagName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i18n('delete_tag')),
        content: Text('${i18n('delete_tag_confirm_msg')} "$tagName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('cancel'))),
          TextButton(
            onPressed: () {
              controller.deleteTag(index);
              Navigator.pop(context);
            },
            child: Text(i18n('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
