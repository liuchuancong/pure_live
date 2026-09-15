import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  TagManagementController get controller => Get.find<TagManagementController>();

  bool _dialogActive = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('tag_management')),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              key: const ValueKey('add-tag'),
              tooltip: i18n('add_tag'),
              icon: const Icon(Remix.add_line),
              onPressed: _dialogActive ? null : () => unawaited(_showTagDialog(context)),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 12),
          context.buildGroupTitle(i18n('tag_management')),
          Obx(() {
            if (controller.tags.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
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
              final isTop = index == 0;
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
                      Row(children: [Expanded(child: _buildTagDetailAction(context, tag))]),

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
                            Expanded(
                              child: _buildTagCardAction(
                                key: ValueKey('pin-tag-${tag.id}'),
                                label: i18n(
                                  isTop ? 'tag_already_at_top_named' : 'move_tag_to_top_named',
                                  args: {'name': tag.name},
                                ),
                                onActivate: _dialogActive || isTop ? null : () => controller.pinToTop(index),
                                child: Icon(
                                  isTop ? Remix.pushpin_fill : Remix.pushpin_line,
                                  size: 16,
                                  color: isTop
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 14, color: theme.dividerColor.withValues(alpha: 0.1)),
                            Expanded(
                              child: _buildTagCardAction(
                                key: ValueKey('edit-tag-${tag.id}'),
                                label: i18n('edit_tag_named', args: {'name': tag.name}),
                                onActivate: _dialogActive
                                    ? null
                                    : () => unawaited(_showTagDialog(context, index: index, tag: tag)),
                                child: Icon(Remix.edit_line, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                            Container(width: 1, height: 14, color: theme.dividerColor.withValues(alpha: 0.1)),
                            Expanded(
                              child: _buildTagCardAction(
                                key: ValueKey('delete-tag-${tag.id}'),
                                label: i18n('delete_tag_named', args: {'name': tag.name}),
                                onActivate: _dialogActive ? null : () => unawaited(_confirmDelete(context, tag)),
                                child: Icon(
                                  Remix.delete_bin_line,
                                  size: 16,
                                  color: theme.colorScheme.error.withValues(alpha: 0.7),
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
                color: theme.colorScheme.surface,
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
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final textScaler = MediaQuery.textScalerOf(context);
                    final textScale = textScaler.scale(14) / 14;
                    final singleColumn = constraints.maxWidth < 420 || textScale > 1.5;
                    final titleStyle = AppTextStyles.t14;
                    final descriptionStyle = AppTextStyles.t11;
                    final titleLineExtent = textScaler.scale(titleStyle.fontSize ?? 14) * (titleStyle.height ?? 1.2);
                    final descriptionLineExtent =
                        textScaler.scale(descriptionStyle.fontSize ?? 12) * (descriptionStyle.height ?? 1.2);
                    final titleExtent = titleLineExtent < 48 ? 48.0 : titleLineExtent;
                    // Padding, gaps and the three 48 px action targets occupy 82 px.
                    final cardExtent = 82 + titleExtent + descriptionLineExtent * 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: generatedChildren.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: singleColumn ? constraints.maxWidth : 180,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: cardExtent,
                      ),
                      itemBuilder: (context, index) => generatedChildren[index],
                    );
                  },
                );
              },
              children: children,
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTagDetailAction(BuildContext context, LiveTag tag) {
    final actionLabel = i18n('view_tag_details_named', args: {'name': tag.name});
    final VoidCallback? onActivate = _dialogActive ? null : () => unawaited(_showTagDetails(context, tag));
    return Semantics(
      container: true,
      button: true,
      enabled: !_dialogActive,
      label: actionLabel,
      excludeSemantics: true,
      onTap: onActivate,
      child: Tooltip(
        message: actionLabel,
        child: InkWell(
          key: ValueKey('tag-detail-${tag.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onActivate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tag.name,
                style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagCardAction({
    required Key key,
    required String label,
    required VoidCallback? onActivate,
    required Widget child,
  }) {
    return Semantics(
      container: true,
      button: true,
      enabled: onActivate != null,
      label: label,
      excludeSemantics: true,
      onTap: onActivate,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(6),
          onTap: onActivate,
          child: SizedBox(height: 48, child: child),
        ),
      ),
    );
  }

  Future<void> _showTagDetails(BuildContext context, LiveTag tag) {
    return _runOwnedDialog(
      () => showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(i18n('tag_detail'), style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold)),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n('tag_name_label'),
                  style: AppTextStyles.t12.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  tag.name,
                  style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
                if (tag.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    i18n('tag_desc_label'),
                    style: AppTextStyles.t12.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
                    ),
                    child: Text(
                      tag.description,
                      style: AppTextStyles.t14.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(i18n('confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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

  Future<void> _showTagDialog(BuildContext context, {int? index, LiveTag? tag}) {
    return _runOwnedDialog(
      () => showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => _TagEditorDialog(controller: controller, index: index, tag: tag),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LiveTag tag) {
    final owner = controller;
    return _runOwnedDialog(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(i18n('delete_tag')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(i18n('delete_tag_confirm_named', args: {'name': tag.name})),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                key: const ValueKey('delete-tag-cancel'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(i18n('cancel')),
              ),
              FilledButton(
                key: const ValueKey('delete-tag-confirm'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(i18n('delete')),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      if (!Get.isRegistered<TagManagementController>() || !identical(Get.find<TagManagementController>(), owner)) {
        return;
      }
      owner.deleteTag(owner.tags.indexWhere((current) => identical(current, tag)));
    });
  }

  Future<void> _runOwnedDialog(Future<void> Function() showDialogRoute) async {
    if (_dialogActive || !mounted) return;
    setState(() => _dialogActive = true);
    try {
      await showDialogRoute();
    } finally {
      if (mounted) setState(() => _dialogActive = false);
    }
  }
}

class _TagEditorDialog extends StatefulWidget {
  const _TagEditorDialog({required this.controller, this.index, this.tag});

  final TagManagementController controller;
  final int? index;
  final LiveTag? tag;

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final FocusNode _nameFocusNode;
  late final String _initialName;
  late final String _initialDescription;
  String? _nameErrorText;
  String? _transactionErrorText;

  bool get _isEdit => widget.index != null && widget.tag != null;

  @override
  void initState() {
    super.initState();
    _initialName = _isEdit ? widget.tag!.name : '';
    _initialDescription = _isEdit ? widget.tag!.description : '';
    _nameController = TextEditingController(text: _initialName);
    _descriptionController = TextEditingController(text: _initialDescription);
    _nameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_transactionErrorText != null) return;
    if (!Get.isRegistered<TagManagementController>() ||
        !identical(Get.find<TagManagementController>(), widget.controller)) {
      _markTransactionStale();
      return;
    }

    int? editIndex;
    if (_isEdit) {
      editIndex = widget.controller.tags.indexWhere((current) => identical(current, widget.tag));
      final target = editIndex >= 0 ? widget.controller.tags[editIndex] : null;
      if (target == null || target.name != _initialName || target.description != _initialDescription) {
        _markTransactionStale();
        return;
      }
    }
    final validation = widget.controller.validateTagName(_nameController.text, excludingIndex: editIndex);
    if (validation != TagNameValidation.valid) {
      setState(() {
        _nameErrorText = switch (validation) {
          TagNameValidation.empty => i18n('tag_name_empty_error'),
          TagNameValidation.duplicate => i18n('tag_name_duplicate_error'),
          TagNameValidation.valid => null,
        };
      });
      _nameFocusNode.requestFocus();
      return;
    }

    final success = editIndex != null
        ? widget.controller.updateTag(editIndex, _nameController.text, _descriptionController.text)
        : widget.controller.addTag(_nameController.text, _descriptionController.text);
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _nameErrorText = i18n('tag_invalid_or_duplicate'));
      _nameFocusNode.requestFocus();
    }
  }

  void _markTransactionStale() {
    setState(() {
      _nameErrorText = null;
      _transactionErrorText = i18n('tag_editor_stale_error');
    });
    _nameFocusNode.unfocus();
  }

  void _clearNameError() {
    if (_nameErrorText != null) setState(() => _nameErrorText = null);
  }

  void _clearName() {
    _nameController.clear();
    _clearNameError();
    _nameFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_isEdit ? i18n('edit_tag') : i18n('add_tag')),
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
            key: const ValueKey('tag-editor-name'),
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: !_isEdit,
            maxLength: 15,
            maxLines: 1,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearNameError(),
            decoration: InputDecoration(
              hintText: i18n('tag_input_hint'),
              errorText: _nameErrorText,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, value, _) => value.text.isNotEmpty
                    ? Semantics(
                        key: const ValueKey('tag-editor-clear-name'),
                        container: true,
                        excludeSemantics: true,
                        label: i18n('clear_tag_name'),
                        button: true,
                        onTap: _clearName,
                        child: IconButton(
                          tooltip: i18n('clear_tag_name'),
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _clearName,
                        ),
                      )
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
            key: const ValueKey('tag-editor-description'),
            controller: _descriptionController,
            maxLength: 40,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: i18n('tag_desc_hint'),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _descriptionController,
                builder: (context, value, _) => value.text.isNotEmpty
                    ? Semantics(
                        key: const ValueKey('tag-editor-clear-description'),
                        container: true,
                        excludeSemantics: true,
                        label: i18n('clear_tag_description'),
                        button: true,
                        onTap: _descriptionController.clear,
                        child: IconButton(
                          tooltip: i18n('clear_tag_description'),
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _descriptionController.clear,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          if (_transactionErrorText case final errorText?) ...[
            const SizedBox(height: 16),
            Semantics(
              key: const ValueKey('tag-editor-transaction-error'),
              container: true,
              liveRegion: true,
              label: errorText,
              excludeSemantics: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(errorText, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          key: const ValueKey('tag-editor-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context),
          child: Text(i18n('cancel'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          key: const ValueKey('tag-editor-confirm'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 48),
            elevation: 0,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _transactionErrorText == null ? _submit : null,
          child: Text(i18n('confirm')),
        ),
      ],
    );
  }
}
