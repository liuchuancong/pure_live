import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class RoomCardController {
  RoomCardController({required this.room, this.debug = false});

  final LiveRoom room;
  final bool debug;
  void onTap(BuildContext context) {
    if (debug) return;
    AppNavigator.toLiveRoomDetail(liveRoom: room);
  }

  void onLongPress(BuildContext context) {
    final favoriteController = Get.isRegistered<FavoriteController>()
        ? Get.find<FavoriteController>()
        : Get.put(FavoriteController());

    final tagController = Get.find<TagManagementController>();
    final theme = Theme.of(context);
    final isFollowed = SettingsService.to.fav.isFavorite(room);

    Get.dialog(
      AlertDialog(
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
              child: Image.asset(Sites.of(room.platform!).logo, width: 28, height: 28),
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
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              icon: Icon(RemixIcons.share_forward_line, size: 20, color: theme.colorScheme.primary),
              onPressed: () {
                Navigator.pop(context);
                ShareCommandHandler.instance.onShareRoomPressed(room);
              },
            ),
            const SizedBox(width: 6),
            IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              icon: Icon(
                Remix.price_tag_3_line,
                size: 20,
                color: isFollowed
                    ? theme.colorScheme.primary
                    : theme.disabledColor.withValues(alpha: 0.6),
              ),
              onPressed: () {
                Navigator.pop(context);

                if (isFollowed) {
                  showTagSelectionDialog(context, theme, favoriteController, tagController);
                } else {
                  SmartDialog.showToast(i18n('tags_need_follow_tip'));

                  showFollowDialog(
                    context,
                    theme,
                    anchorName: room.nick ?? '',
                    onConfirm: () {
                      SettingsService.to.fav.addRoom(room);

                      showTagSelectionDialog(context, theme, favoriteController, tagController);
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
                  i18n('room_id_label', args: {'id': room.roomId ?? ''}),
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
          Container(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FollowButton(room: room),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    i18n('close'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showFollowDialog(
    BuildContext context,
    ThemeData theme, {
    required String anchorName,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            i18n('follow'),
            style: AppTextStyles.t16.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            i18n('dialog_follow_anchor_ask').replaceAll('{name}', anchorName),
            style: AppTextStyles.t14.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                i18n('cancel'),
                style: AppTextStyles.t14.copyWith(color: theme.colorScheme.secondary),
              ),
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
                  style: AppTextStyles.t14.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void showTagSelectionDialog(
    BuildContext context,
    ThemeData theme,
    FavoriteController favoriteController,
    TagManagementController tagController,
  ) {
    final tempSelectedIds = List<String>.from(room.tagIds);
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final tagScrollController = ScrollController();

    bool showAddSection = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            titlePadding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            insetPadding: isSmallScreen
                ? EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 24)
                : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: showAddSection ? 4 : 12),
                  child: Text(
                    i18n('set_room_tags'),
                    style: AppTextStyles.t16.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                showAddSection
                    ? Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              nameController.clear();
                              descController.clear();

                              setModalState(() {
                                showAddSection = false;
                              });
                            },
                            child: Text(
                              i18n('cancel'),
                              style: AppTextStyles.t13.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final name = nameController.text.trim();

                              if (name.isEmpty) {
                                SmartDialog.showToast(i18n('tag_name_empty_error'));
                                return;
                              }

                              final success = tagController.addTag(name, descController.text);

                              if (success) {
                                nameController.clear();
                                descController.clear();

                                setModalState(() {
                                  showAddSection = false;
                                });
                              } else {
                                SmartDialog.showToast(i18n('tag_invalid_or_duplicate'));
                              }
                            },
                            child: Text(
                              i18n('confirm'),
                              style: AppTextStyles.t13.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                    : IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        icon: Icon(
                          Remix.add_circle_line,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () {
                          setModalState(() {
                            showAddSection = true;
                          });
                        },
                      ),
              ],
            ),
            content: SizedBox(
              width: isSmallScreen ? screenWidth : 440,
              height: isSmallScreen ? screenHeight * 0.54 : 390,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showAddSection)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.03),
                          width: 0.5,
                        ),
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
                            controller: nameController,
                            maxLines: 1,
                            style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w500),
                            decoration: _inputDecoration(theme, i18n('tag_input_hint')),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: descController,
                            maxLines: 1,
                            style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w500),
                            decoration: _inputDecoration(theme, i18n('tag_desc_hint')),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: tagController.tags.isEmpty
                        ? Center(
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
                                  style: AppTextStyles.t13.copyWith(color: theme.disabledColor),
                                ),
                              ],
                            ),
                          )
                        : Scrollbar(
                            controller: tagScrollController,
                            thumbVisibility: true,
                            thickness: 4,
                            radius: const Radius.circular(4),
                            child: GridView.builder(
                              controller: tagScrollController,
                              shrinkWrap: true,
                              physics: const PureLiveScrollPhysics(),
                              itemCount: tagController.tags.length,
                              padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4, left: 2),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: 68,
                              ),
                              itemBuilder: (context, index) {
                                final tag = tagController.tags[index];
                                final selected = tempSelectedIds.contains(tag.id);

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeInOut,
                                  child: InkWell(
                                    onTap: () {
                                      if (selected) {
                                        tempSelectedIds.remove(tag.id);
                                      } else {
                                        tempSelectedIds.add(tag.id);
                                      }

                                      setModalState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? theme.colorScheme.primary.withValues(alpha: 0.06)
                                            : theme.colorScheme.surfaceContainerLow.withValues(
                                                alpha: 0.6,
                                              ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selected
                                              ? theme.colorScheme.primary
                                              : theme.dividerColor.withValues(alpha: 0.05),
                                          width: selected ? 1.4 : 0.6,
                                        ),
                                        boxShadow: selected
                                            ? [
                                                BoxShadow(
                                                  color: theme.colorScheme.primary.withValues(
                                                    alpha: 0.04,
                                                  ),
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
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: AppTextStyles.t13.copyWith(
                                                    fontWeight: selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                    color: selected
                                                        ? theme.colorScheme.primary
                                                        : theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                                if (tag.description.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: Text(
                                                      tag.description,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: AppTextStyles.t11.copyWith(
                                                        color: theme.colorScheme.onSurfaceVariant
                                                            .withValues(alpha: 0.5),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
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
                                              color: selected
                                                  ? theme.colorScheme.primary
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: selected
                                                    ? Colors.transparent
                                                    : theme.colorScheme.onSurfaceVariant.withValues(
                                                        alpha: 0.25,
                                                      ),
                                                width: selected ? 0 : 1.5,
                                              ),
                                            ),
                                            child: selected
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
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  i18n('cancel'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                onPressed: () {
                  if (showAddSection) {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      SmartDialog.showToast(i18n('tag_name_empty_error'));
                      return;
                    }

                    final success = tagController.addTag(name, descController.text);

                    if (success) {
                      nameController.clear();
                      descController.clear();

                      setModalState(() {
                        showAddSection = false;
                      });
                    } else {
                      SmartDialog.showToast(i18n('tag_invalid_or_duplicate'));
                    }
                  } else {
                    favoriteController.updateRoomTags(room, tempSelectedIds);
                    Navigator.pop(context);
                  }
                },
                child: Text(i18n('confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
      tagScrollController.dispose();
    });
  }

  InputDecoration _inputDecoration(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
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
        borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.2),
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.room});

  final LiveRoom room;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool isFavorite = SettingsService.to.fav.isFavorite(widget.room);

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: () {
        setState(() => isFavorite = !isFavorite);

        if (isFavorite) {
          SettingsService.to.fav.addRoom(widget.room);
        } else {
          SettingsService.to.fav.removeRoom(widget.room);
        }

        Navigator.of(Get.context!).pop();
      },
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(
        isFavorite ? i18n('unfollow') : i18n('follow'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
