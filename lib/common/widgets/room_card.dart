import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';

double _roomTagTextScale(BuildContext context) {
  final style = AppTextStyles.t13;
  final fontSize = style.fontSize ?? 13;
  return fontSize > 0 ? MediaQuery.textScalerOf(context).scale(fontSize) / fontSize : 1;
}

double _roomTagItemExtent(BuildContext context) {
  final textScaler = MediaQuery.textScalerOf(context);

  double singleLineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  return (singleLineHeight(AppTextStyles.t13) + 3 + singleLineHeight(AppTextStyles.t11) + 24).ceilToDouble().clamp(
    68.0,
    double.infinity,
  );
}

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.dense = false,
    this.statusPending = false,
    this.statusPendingLabel,
    this.showDelete = false,
    this.onDelete,
    this.deleteTooltip,
    this.settingsViewport,
  });
  final LiveRoom room;
  final bool dense;
  final bool statusPending;
  final String? statusPendingLabel;
  final bool showDelete;
  final VoidCallback? onDelete;
  final String? deleteTooltip;
  final RoomCardViewport? settingsViewport;
  Widget _buildCover(BuildContext context, bool isDark) {
    final coverUrl = normalizeNetworkImageUrl(room.cover);

    if (coverUrl.isEmpty) {
      return _coverFallback(context, isDark);
    }

    // Keep a stable image element and an encoded disk entry. The previous
    // global epoch rebuilt every visible Image.network at once, discarded the
    // old pixels and forced independent network/decode progress callbacks for
    // the full grid. That was the main source of mixed placeholders, flashes
    // and CPU spikes during refresh and tab switching.
    return Obx(() {
      final epoch = SettingsService.to.cache.imageCacheEpoch.value;
      return LayoutBuilder(
        builder: (context, constraints) {
          final logicalWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width / 2;
          final cacheWidth = (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(240, 720).toInt();

          return CachedNetworkImage(
            imageUrl: coverUrl,
            cacheKey: epoch == 0 ? coverUrl : '$coverUrl#$epoch',
            httpHeaders: networkImageHeaders(coverUrl),
            cacheManager: CustomImageCacheManager.instance,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            memCacheWidth: cacheWidth,
            // maxWidthDiskCache: 720,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: (context, _) => _coverPlaceholder(context, isDark),
            errorWidget: (context, _, _) => _coverFallback(context, isDark),
          );
        },
      );
    });
  }

  Widget _coverPlaceholder(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      child: Center(
        // Do not create one infinite AnimationController per loading card. A
        // page of failed/slow covers used to repaint the complete grid at the
        // monitor refresh rate and could saturate Android CPU during startup.
        child: Icon(Icons.live_tv_rounded, size: 24, color: isDark ? Colors.white24 : Colors.black12),
      ),
    );
  }

  Widget _coverFallback(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      child: AppStatusView(type: AppStatusType.error, title: "", subtitle: "", isMini: true),
    );
  }

  void onTap(BuildContext context) {
    unawaited(AppNavigator.toLiveRoomDetail(liveRoom: room));
  }

  void showFollowDialog(
    BuildContext context,
    ThemeData theme, {
    required String anchorName,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            i18n('follow'),
            style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          content: Text(
            i18n('dialog_follow_anchor_ask').replaceAll('{name}', anchorName),
            style: AppTextStyles.t14.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(i18n('cancel'), style: AppTextStyles.t14.copyWith(color: theme.colorScheme.secondary)),
            ),
            Theme(
              data: ThemeData(useMaterial3: true),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
                child: Text(
                  i18n('follow'),
                  style: AppTextStyles.t14.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void onLongPress(BuildContext context) {
    final TagManagementController tagController = Get.find<TagManagementController>();
    final theme = Theme.of(context);
    final bool isFollowed = SettingsService.to.fav.isFavorite(room);

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(Sites.logoForId(room.normalizedPlatformId), width: 28, height: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  room.nick ?? '',
                  style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              IconButton(
                tooltip: i18n('share'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(RemixIcons.share_forward_line, size: 20, color: theme.colorScheme.primary),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ShareCommandHandler.instance.onShareRoomPressed(room);
                },
              ),
              SizedBox(width: 6),
              IconButton(
                tooltip: i18n('set_room_tags'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Remix.price_tag_3_line,
                  size: 20,
                  color: isFollowed ? theme.colorScheme.primary : theme.disabledColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (isFollowed) {
                    unawaited(_showTagSelectionGridModal(context, theme, tagController));
                  } else {
                    SmartDialog.showToast(i18n('tags_need_follow_tip'));
                    showFollowDialog(
                      context,
                      theme,
                      anchorName: room.nick ?? '',
                      onConfirm: () async {
                        try {
                          final favorites = SettingsService.to.fav;
                          final changed = await favorites.addRoomDurably(room);
                          if (changed) EventBus.instance.emit('changeFavorite', true);
                          if (context.mounted && favorites.isFavorite(room)) {
                            await _showTagSelectionGridModal(context, theme, tagController);
                          }
                        } catch (error) {
                          debugPrint('Favorite room change failed: $error');
                          ToastUtil.show(i18n('favorite_changes_save_failed'));
                        }
                      },
                    );
                  }
                },
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.04), width: 0.8),
                  ),
                  child: Text(
                    room.title ?? '',
                    style: AppTextStyles.t14.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    i18n('room_id_label', args: {"id": ?room.roomId}),
                    style: AppTextStyles.t11.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FollowButton(room: room),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                i18n('close'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagSelectionGridModal(
    BuildContext context,
    ThemeData theme,
    TagManagementController tagController,
  ) async {
    final availableTagIds = tagController.tags.map((tag) => tag.id).toSet();
    final tempSelectedIds = tagController
        .getTagsForRoom(room)
        .where(availableTagIds.contains)
        .toSet()
        .toList(growable: true);
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final nameFocusNode = FocusNode();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 600;

    bool showAddSection = false;
    bool tagCreationPending = false;
    bool assignmentPending = false;
    String? nameErrorText;
    final tagScrollController = ScrollController();
    void clearName(StateSetter setModalState) {
      nameController.clear();
      if (nameErrorText != null) setModalState(() => nameErrorText = null);
      nameFocusNode.requestFocus();
    }

    Future<void> submitNewTag(BuildContext dialogContext, StateSetter setModalState) async {
      if (tagCreationPending || assignmentPending) return;
      final name = nameController.text.trim();
      final validation = tagController.validateTagName(name);
      if (validation != TagNameValidation.valid) {
        setModalState(() {
          nameErrorText = switch (validation) {
            TagNameValidation.empty => i18n('tag_name_empty_error'),
            TagNameValidation.duplicate => i18n('tag_name_duplicate_error'),
            TagNameValidation.valid => null,
          };
        });
        nameFocusNode.requestFocus();
        return;
      }
      setModalState(() => tagCreationPending = true);
      try {
        if (!await tagController.addTag(name, descController.text)) {
          if (!dialogContext.mounted) return;
          setModalState(() {
            tagCreationPending = false;
            nameErrorText = i18n('tag_invalid_or_duplicate');
          });
          nameFocusNode.requestFocus();
          return;
        }
        if (!dialogContext.mounted) return;
        final newTag = tagController.tags.firstWhere((tag) => tag.name.toLowerCase() == name.toLowerCase());
        tempSelectedIds.add(newTag.id);
        nameController.clear();
        descController.clear();
        nameFocusNode.unfocus();
        setModalState(() {
          tagCreationPending = false;
          nameErrorText = null;
          showAddSection = false;
        });
      } catch (error) {
        debugPrint('Creating a room tag failed: $error');
        if (!dialogContext.mounted) return;
        setModalState(() => tagCreationPending = false);
        ToastUtil.show(i18n('tag_changes_save_failed'));
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          titlePadding: EdgeInsets.fromLTRB(16, _roomTagTextScale(context) >= 2 ? 8 : 24, 16, 0),
          contentPadding: _roomTagTextScale(context) >= 2
              ? const EdgeInsets.fromLTRB(12, 8, 12, 4)
              : const EdgeInsets.fromLTRB(28, 20, 28, 12),
          actionsPadding: _roomTagTextScale(context) >= 2
              ? const EdgeInsets.fromLTRB(8, 0, 8, 8)
              : const EdgeInsets.fromLTRB(20, 0, 20, 20),
          insetPadding: isSmallScreen
              ? EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: _roomTagTextScale(context) >= 2 ? 8 : 24)
              : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          title: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: showAddSection ? 4 : 12),
                  child: Text(
                    i18n('set_room_tags'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
              ),
              showAddSection
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('room-tag-cancel-new'),
                          tooltip: i18n('cancel'),
                          onPressed: tagCreationPending
                              ? null
                              : () {
                                  nameController.clear();
                                  descController.clear();
                                  nameFocusNode.unfocus();
                                  setModalState(() {
                                    nameErrorText = null;
                                    showAddSection = false;
                                  });
                                },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        IconButton(
                          key: const ValueKey('room-tag-submit-new'),
                          tooltip: i18n('add_tag'),
                          onPressed: tagCreationPending
                              ? null
                              : () => unawaited(submitNewTag(dialogContext, setModalState)),
                          icon: tagCreationPending
                              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check_rounded),
                        ),
                      ],
                    )
                  : IconButton(
                      key: const ValueKey('room-tag-open-new'),
                      tooltip: i18n('add_tag'),
                      visualDensity: VisualDensity.standard,
                      constraints: const BoxConstraints(
                        minWidth: kMinInteractiveDimension,
                        minHeight: kMinInteractiveDimension,
                      ),
                      icon: Icon(Remix.add_circle_line, size: 20, color: theme.colorScheme.primary),
                      onPressed: assignmentPending
                          ? null
                          : () {
                              setModalState(() {
                                showAddSection = true; // Slide open text fields inputs section block
                              });
                            },
                    ),
            ],
          ),
          content: Container(
            width: isSmallScreen ? screenWidth : 440,
            height: isSmallScreen && _roomTagTextScale(context) >= 2 ? screenHeight * 0.42 : null,
            constraints: BoxConstraints(
              maxHeight: isSmallScreen ? screenHeight * (_roomTagTextScale(context) >= 2 ? 0.42 : 0.54) : 390,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAddSection)
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('room-tag-add-form-scroll'),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.03), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n('add_tag'),
                              style: AppTextStyles.t12.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const ValueKey('room-tag-name'),
                              controller: nameController,
                              focusNode: nameFocusNode,
                              autofocus: true,
                              maxLength: 15,
                              maxLines: 1,
                              textInputAction: TextInputAction.next,
                              enabled: !tagCreationPending,
                              onChanged: (_) {
                                if (nameErrorText != null) setModalState(() => nameErrorText = null);
                              },
                              style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: i18n('tag_input_hint'),
                                errorText: nameErrorText,
                                counterText: '',
                                hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.75)),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
                                ),
                                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: nameController,
                                  builder: (context, value, _) => value.text.isNotEmpty
                                      ? Semantics(
                                          key: const ValueKey('room-tag-clear-name'),
                                          container: true,
                                          excludeSemantics: true,
                                          label: i18n('clear_tag_name'),
                                          button: true,
                                          onTap: () => clearName(setModalState),
                                          child: IconButton(
                                            tooltip: i18n('clear_tag_name'),
                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () => clearName(setModalState),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('room-tag-description'),
                              controller: descController,
                              maxLength: 40,
                              maxLines: 1,
                              textInputAction: TextInputAction.done,
                              enabled: !tagCreationPending,
                              onSubmitted: (_) => unawaited(submitNewTag(dialogContext, setModalState)),
                              style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: i18n('tag_desc_hint'),
                                counterText: '',
                                hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: descController,
                                  builder: (context, value, _) => value.text.isNotEmpty
                                      ? Semantics(
                                          key: const ValueKey('room-tag-clear-description'),
                                          container: true,
                                          excludeSemantics: true,
                                          label: i18n('clear_tag_description'),
                                          button: true,
                                          onTap: descController.clear,
                                          child: IconButton(
                                            tooltip: i18n('clear_tag_description'),
                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: descController.clear,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!showAddSection)
                  Expanded(
                    child: tagController.tags.isEmpty
                        ? SingleChildScrollView(
                            key: const ValueKey('room-tag-empty-scroll'),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Remix.price_tag_3_line,
                                    size: 36,
                                    color: theme.disabledColor.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    i18n('no_tags_tip'),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.t13.copyWith(color: theme.disabledColor),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: tagScrollController,
                            thumbVisibility: true,
                            thickness: 4.0,
                            radius: const Radius.circular(4),
                            child: GridView.builder(
                              key: const ValueKey('room-tag-assignment-list'),
                              controller: tagScrollController,
                              shrinkWrap: true,
                              physics: const PureLiveScrollPhysics(),
                              itemCount: tagController.tags.length,
                              padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4, left: 2),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isSmallScreen || _roomTagTextScale(context) >= 1.6 ? 1 : 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: _roomTagItemExtent(context),
                              ),
                              itemBuilder: (context, index) {
                                final tag = tagController.tags[index];
                                final isSelected = tempSelectedIds.contains(tag.id);
                                return Semantics(
                                  label: tag.name,
                                  selected: isSelected,
                                  button: true,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeInOut,
                                    child: InkWell(
                                      onTap: () {
                                        if (isSelected) {
                                          tempSelectedIds.remove(tag.id);
                                        } else {
                                          tempSelectedIds.add(tag.id);
                                        }
                                        setModalState(() {});
                                      },
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.primary.withValues(alpha: 0.06)
                                              : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.dividerColor.withValues(alpha: 0.05),
                                            width: isSelected ? 1.4 : 0.6,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    tag.name,
                                                    style: AppTextStyles.t13.copyWith(
                                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                      color: isSelected
                                                          ? theme.colorScheme.primary
                                                          : theme.colorScheme.onSurface,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (tag.description.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      tag.description,
                                                      style: AppTextStyles.t11.copyWith(
                                                        color: theme.colorScheme.onSurfaceVariant.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.transparent
                                                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                                                  width: isSelected ? 0 : 1.5,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? Icon(
                                                      Icons.check_rounded,
                                                      size: 12,
                                                      color: theme.colorScheme.onPrimary,
                                                    )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: tagCreationPending || assignmentPending ? null : () => Navigator.pop(context),
                      child: Text(
                        i18n('cancel'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: showAddSection || tagCreationPending || assignmentPending
                          ? null
                          : () async {
                              setModalState(() => assignmentPending = true);
                              try {
                                await tagController.setRoomTags(room, tempSelectedIds);
                                if (context.mounted) Navigator.pop(context);
                              } catch (error) {
                                debugPrint('Room tag assignment failed: $error');
                                if (context.mounted) {
                                  setModalState(() => assignmentPending = false);
                                  ToastUtil.show(i18n('tag_assignment_save_failed'));
                                }
                              }
                            },
                      child: assignmentPending
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: i18n('refresh_loading')),
                            )
                          : Text(
                              i18n('confirm'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
      nameFocusNode.dispose();
      tagScrollController.dispose();
    });
  }

  Widget _buildAudienceMetric({required bool dense}) {
    return Obx(() {
      final app = SettingsService.to.app;
      final preferReal = app.preferRealOnlineCounts.v;
      final platformEnabled = app.isRealOnlineEnabledFor(room.platform);
      final type = room.audienceType(preferRealOnline: preferReal, platformEnabled: platformEnabled);
      final value = room.audienceValue(preferRealOnline: preferReal, platformEnabled: platformEnabled);
      final labelKey = switch (type) {
        AudienceMetricType.popularity => 'audience_popularity',
        AudienceMetricType.onlineViewers => 'audience_online',
        AudienceMetricType.totalViewers => 'audience_total',
        AudienceMetricType.followers => 'audience_followers',
        AudienceMetricType.unknown => 'audience_count',
      };
      final displayValue = value.isEmpty ? i18n('audience_waiting') : readableCount(value);
      return CoverMetricBadge(
        key: const ValueKey('cover-audience-metric'),
        icon: switch (type) {
          AudienceMetricType.onlineViewers => Icons.people_alt_rounded,
          AudienceMetricType.followers => Icons.favorite_rounded,
          AudienceMetricType.totalViewers => Icons.visibility_rounded,
          _ => Icons.whatshot_rounded,
        },
        value: displayValue,
        semanticLabel: '${i18n(labelKey)} $displayValue',
        dense: dense,
      );
    });
  }

  Widget _buildCompactPlatformBadge(bool isDark) {
    return Container(
      key: const ValueKey('room-card-platform-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        room.platform?.toUpperCase() ?? '',
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: AppTextStyles.t11.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    );
  }

  Widget? _buildCompactTrailing({
    required RoomCardAppearance config,
    required bool isDark,
    required bool showAutomaticPlatformBadge,
    required double availableWidth,
    required double textScale,
  }) {
    final minimumMetricWidth = showDelete ? 360.0 : (dense ? 260.0 : 300.0);
    final canShowMetrics = availableWidth >= minimumMetricWidth && textScale < 1.8;
    final children = <Widget>[];

    if (canShowMetrics && (config.showPlatformBadge || showAutomaticPlatformBadge)) {
      children.add(_buildCompactPlatformBadge(isDark));
    }
    if (canShowMetrics) {
      if (statusPending) {
        children.add(
          CoverMetricBadge(
            icon: Icons.sync_rounded,
            value: statusPendingLabel ?? i18n('favorite_status_verifying'),
            semanticLabel: statusPendingLabel ?? i18n('favorite_status_verifying'),
            dense: true,
          ),
        );
      } else if (config.showAudience && room.isLiveNow) {
        children.add(_buildAudienceMetric(dense: true));
      } else if (config.showReplayBadge && room.isRecord == true) {
        children.add(
          CountChip(icon: Icons.videocam_rounded, count: i18n('replay'), dense: true, color: Get.theme.primaryColor),
        );
      }
    } else if (statusPending) {
      children.add(
        Tooltip(
          message: statusPendingLabel ?? i18n('favorite_status_verifying'),
          child: const Icon(Icons.sync_rounded, size: 18),
        ),
      );
    }

    if (showDelete) {
      children.add(
        IconButton(
          key: const ValueKey('room-card-delete'),
          tooltip: deleteTooltip ?? i18n('delete'),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(RemixIcons.delete_bin_line, size: dense ? 17 : 19),
        ),
      );
    }
    if (children.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            children[index],
          ],
        ],
      ),
    );
  }

  Widget _buildCompactLayout({
    required BuildContext context,
    required RoomCardAppearance config,
    required bool isDark,
    required bool showAutomaticPlatformBadge,
    required double availableWidth,
    required double textScale,
  }) {
    final height = RoomCardLayoutMetrics.compactHeight(
      appearance: config,
      dense: dense,
      hasAction: showDelete,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final trailing = _buildCompactTrailing(
      config: config,
      isDark: isDark,
      showAutomaticPlatformBadge: showAutomaticPlatformBadge,
      availableWidth: availableWidth,
      textScale: textScale,
    );

    return SizedBox(
      key: const ValueKey('room-card-compact-layout'),
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 8 : 10),
        child: Row(
          children: [
            if (config.showAvatar) ...[
              KeyedSubtree(
                key: const ValueKey('room-card-avatar'),
                child: CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: dense),
              ),
              SizedBox(width: dense ? 8 : 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (dense ? AppTextStyles.t13 : AppTextStyles.t15).copyWith(
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (config.showAnchorName) ...[
                    SizedBox(height: dense ? 2 : 3),
                    Text(
                      room.nick ?? '',
                      key: const ValueKey('room-card-anchor-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (dense ? AppTextStyles.t12 : AppTextStyles.t13).copyWith(
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // GridView already inserts a RepaintBoundary around every child. Avoid a
    // second composited layer per card and keep the cover clip lightweight.
    return Obx(() {
      final config = SettingsService.to.roomCard.resolve(viewport: settingsViewport);
      final radius = config.cornerRadius;

      return LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final showAutomaticPlatformBadge =
              config.automaticPlatformBadge && !dense && constraints.maxWidth >= 280 && textScale < 1.8;
          return Card(
            key: const ValueKey('room-card-surface'),
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            color: isDark ? Colors.grey[900] : Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: () => onTap(context),
              onLongPress: () => onLongPress(context),
              onSecondaryTap: () => onLongPress(context),
              child: config.layout == RoomCardLayout.compact
                  ? _buildCompactLayout(
                      context: context,
                      config: config,
                      isDark: isDark,
                      showAutomaticPlatformBadge: showAutomaticPlatformBadge,
                      availableWidth: constraints.maxWidth,
                      textScale: textScale,
                    )
                  : Column(
                      key: const ValueKey('room-card-cover-layout'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(radius),
                                child: ColoredBox(
                                  color: isDark ? Colors.grey[850]! : Colors.grey.shade100,
                                  child: _buildCover(context, isDark),
                                ),
                              ),
                            ),
                            if (config.showPlatformBadge)
                              Positioned(
                                key: const ValueKey('room-card-platform-badge'),
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 3 : 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    room.platform?.toUpperCase() ?? '',
                                    style: AppTextStyles.t11.copyWith(
                                      fontSize: dense ? 10 : null,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            if (config.showReplayBadge && room.isRecord == true)
                              Positioned(
                                key: const ValueKey('room-card-replay-badge'),
                                right: showDelete ? (dense ? 44 : 48) : 8,
                                top: 8,
                                child: CountChip(
                                  icon: Icons.videocam_rounded,
                                  count: i18n("replay"),
                                  dense: dense,
                                  color: Get.theme.primaryColor,
                                ),
                              ),
                            if (statusPending)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: CoverMetricBadge(
                                  icon: Icons.sync_rounded,
                                  value: statusPendingLabel ?? i18n('favorite_status_verifying'),
                                  semanticLabel: statusPendingLabel ?? i18n('favorite_status_verifying'),
                                  dense: dense,
                                ),
                              )
                            else if (config.showAudience && room.isLiveNow)
                              Positioned(right: 8, bottom: 8, child: _buildAudienceMetric(dense: dense)),
                            if (showDelete)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  key: const ValueKey('room-card-delete'),
                                  tooltip: deleteTooltip ?? i18n('delete'),
                                  onPressed: onDelete,
                                  padding: const EdgeInsets.all(10),
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(RemixIcons.delete_bin_line, color: Colors.white, size: dense ? 16 : 18),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListTile(
                          dense: dense,
                          minLeadingWidth: dense ? 34 : 40,
                          contentPadding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 6),
                          horizontalTitleGap: dense ? 8 : 12,
                          leading: config.showAvatar
                              ? KeyedSubtree(
                                  key: const ValueKey('room-card-avatar'),
                                  child: CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: dense),
                                )
                              : null,
                          title: Text(
                            room.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (dense ? AppTextStyles.t13 : AppTextStyles.t15).copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: config.showAnchorName
                              ? Text(
                                  room.nick ?? '',
                                  key: const ValueKey('room-card-anchor-name'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: (dense ? AppTextStyles.t12 : AppTextStyles.t13).copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  ),
                                )
                              : null,
                          trailing: showAutomaticPlatformBadge
                              ? Container(
                                  key: const ValueKey('room-card-platform-badge'),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    room.platform?.toUpperCase() ?? '',
                                    style: AppTextStyles.t11.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
            ),
          );
        },
      );
    });
  }
}

class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.room});

  final LiveRoom room;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _busy = false;

  Future<void> _toggleFavorite(bool isFavorite) async {
    if (_busy) return;
    setState(() => _busy = true);

    final favorites = SettingsService.to.fav;
    try {
      if (!isFavorite) {
        final changed = await favorites.addRoomDurably(widget.room);
        if (changed) EventBus.instance.emit('changeFavorite', true);

        if (mounted && (changed || favorites.isFavorite(widget.room))) {
          Navigator.of(context).pop();
        }
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Text(i18n('unfollow')),
          content: Text(i18n('unfollow_message', args: {'name': widget.room.nick ?? ''})),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('confirm'))),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      final changed = await favorites.removeRoomDurably(widget.room);
      if (changed) EventBus.instance.emit('changeFavorite', true);
      if (!mounted) return;
      if (!favorites.isFavorite(widget.room)) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      debugPrint('Favorite room change failed: $error');
      ToastUtil.show(i18n('favorite_changes_save_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final favoriteRooms = SettingsService.to.fav.favoriteRooms.value;
      final isFavorite = favoriteRooms.any((candidate) => candidate.hasSameIdentity(widget.room));

      return FilledButton.tonal(
        onPressed: _busy ? null : () => _toggleFavorite(isFavorite),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: Text(
          isFavorite ? i18n('unfollow') : i18n('follow'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    });
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.icon, required this.count, this.dense = false, required this.color});

  final IconData icon;
  final String count;
  final bool dense;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const StadiumBorder(),
      color: color,
      shadowColor: Colors.transparent,

      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: dense ? 16 : 18),
            const SizedBox(width: 4),
            Text(
              count,
              style: (dense ? AppTextStyles.t12 : AppTextStyles.t13).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cover metric stays compact and readable without obscuring thumbnails.
/// The full metric name remains available to accessibility and hover users.
class CoverMetricBadge extends StatelessWidget {
  const CoverMetricBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.semanticLabel,
    this.dense = false,
  });

  final IconData icon;
  final String value;
  final String semanticLabel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Keep the background mostly neutral so the badge works on both bright
    // and dark cover images. The theme primary color is used as the accent.
    final backgroundColor = theme.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.48);

    final foregroundColor = Colors.white;

    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        label: semanticLabel,
        container: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 4 : 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(dense ? 10 : 12),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.12), width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: dense ? 14 : 16),
              SizedBox(width: dense ? 4 : 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: dense ? 11 : 12,
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
