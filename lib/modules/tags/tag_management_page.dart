import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';

class TagManagementPage extends GetView<TagManagementController> {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('tag_management')),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(icon: const Icon(Remix.add_line), onPressed: () => _showTagDialog(context)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: _buildTipBanner(theme)),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
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
                  final children = List.generate(controller.tags.length, (index) {
                    final tag = controller.tags[index];
                    return Material(
                      key: ValueKey(tag.id),
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3), width: 1.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              Text(
                                                i18n('tag_detail'),
                                                style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                                          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                i18n('tag_name_label'),
                                                style: AppTextStyles.t12.copyWith(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                tag.name,
                                                style: AppTextStyles.t16.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),

                                              if (tag.description.isNotEmpty) ...[
                                                const SizedBox(height: 18),
                                                Text(
                                                  i18n('tag_desc_label'),
                                                  style: AppTextStyles.t12.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                                                      alpha: 0.2,
                                                    ),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: theme.dividerColor.withValues(alpha: 0.05),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    tag.description,
                                                    style: AppTextStyles.t14.copyWith(
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                                          actions: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                elevation: 0,
                                                backgroundColor: theme.colorScheme.primary,
                                                foregroundColor: theme.colorScheme.onPrimary,
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                i18n('confirm'),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Text(
                                      tag.name,
                                      style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                tag.description.isNotEmpty ? tag.description : i18n('no_description_placeholder'),
                                style: AppTextStyles.t11.copyWith(
                                  color: tag.description.isNotEmpty
                                      ? theme.disabledColor
                                      : theme.disabledColor.withValues(alpha: 0.4),
                                  fontStyle: tag.description.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // 1. 置顶按钮
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => controller.pinToTop(index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: ReorderableDragStartListener(
                                          index: index,
                                          child: Icon(
                                            Remix.sort_number_desc,
                                            size: 16,
                                            color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 分割线
                                  Container(width: 1, height: 14, color: theme.dividerColor.withValues(alpha: 0.1)),
                                  // 2. 编辑按钮
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _showTagDialog(context, index: index, tag: tag),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Icon(
                                          Remix.edit_line,
                                          size: 16,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 分割线
                                  Container(width: 1, height: 14, color: theme.dividerColor.withValues(alpha: 0.1)),
                                  // 3. 删除按钮
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _confirmDelete(context, index, tag.name),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Icon(
                                          Remix.delete_bin_line,
                                          size: 16,
                                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });

                  return ReorderableBuilder(
                    dragChildBoxDecoration: BoxDecoration(
                      color: theme.colorScheme.surface, // 必须使用不透明的实体表面色
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    onReorder: (ReorderedListFunction reorderedListFunction) {
                      final newList = reorderedListFunction(controller.tags) as List<LiveTag>;
                      controller.updateAllTags(newList);
                    },
                    builder: (generatedChildren) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: generatedChildren.length,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 116,
                        ),
                        itemBuilder: (context, index) => generatedChildren[index],
                      );
                    },
                    children: children,
                  );
                }),
                const SizedBox(height: 32),
              ],
            ),
          ),
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
              i18n('drag_tag_to_sort_tip'),
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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? i18n('edit_tag') : i18n('add_tag')),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n('tag_name_label'),
              style: AppTextStyles.t12.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              autofocus: !isEdit,
              maxLength: 15,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: i18n('tag_input_hint'),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: nameController,
                  builder: (context, value, _) => value.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => nameController.clear())
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              i18n('tag_desc_label'),
              style: AppTextStyles.t12.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: descController,
              maxLength: 40,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (nameController.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              decoration: InputDecoration(
                hintText: i18n('tag_desc_hint'),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: descController,
                  builder: (context, value, _) => value.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => descController.clear())
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(i18n('cancel'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                SmartDialog.showToast(i18n('tag_name_empty_error'));
                return;
              }

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
