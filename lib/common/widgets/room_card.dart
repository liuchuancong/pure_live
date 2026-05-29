import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, this.dense = false});
  final LiveRoom room;
  final bool dense;

  void onTap(BuildContext context) async {
    AppNavigator.toLiveRoomDetail(liveRoom: room);
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
    final FavoriteController favoriteController = Get.isRegistered<FavoriteController>()
        ? Get.find<FavoriteController>()
        : Get.put(FavoriteController());
    final TagManagementController tagController = Get.find<TagManagementController>();
    final theme = Theme.of(context);
    final bool isFollowed = SettingsService.to.fav.favoriteRooms.v.any(
      (r) => r.platform == room.platform && r.roomId == room.roomId,
    );

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
            SizedBox(width: 6),
            IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              icon: Icon(
                Remix.price_tag_3_line,
                size: 20,
                color: isFollowed ? theme.colorScheme.primary : theme.disabledColor.withValues(alpha: 0.6),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (isFollowed) {
                  _showTagSelectionGridModal(context, theme, favoriteController, tagController);
                } else {
                  SmartDialog.showToast(i18n('tags_need_follow_tip'));
                  showFollowDialog(
                    context,
                    theme,
                    anchorName: room.nick ?? '',
                    onConfirm: () {
                      SettingsService.to.fav.addRoom(room);
                      _showTagSelectionGridModal(context, theme, favoriteController, tagController);
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
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTagSelectionGridModal(
    BuildContext context,
    ThemeData theme,
    FavoriteController favoriteController,
    TagManagementController tagController,
  ) {
    List<String> tempSelectedIds = List<String>.from(room.tagIds);
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 600;

    bool showAddSection = false;
    final tagScrollController = ScrollController();
    Get.dialog(
      StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          titlePadding: const EdgeInsets.fromLTRB(16, 24, 16, 0), // Adjusted padding to align back arrow neatly
          contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          insetPadding: isSmallScreen
              ? EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 24)
              : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: showAddSection ? 4 : 12),
                    child: Text(
                      i18n('set_room_tags'),
                      style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                    ),
                  ),
                ],
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
                              showAddSection = false; // Collapse panel and revert header to default view layout
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
                                showAddSection = false; // Collapse panel and revert header to default view layout
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
                      icon: Icon(Remix.add_circle_line, size: 20, color: theme.colorScheme.primary),
                      onPressed: () {
                        setModalState(() {
                          showAddSection = true; // Slide open text fields inputs section block
                        });
                      },
                    ),
            ],
          ),
          content: Container(
            width: isSmallScreen ? screenWidth : 440,
            constraints: BoxConstraints(maxHeight: isSmallScreen ? screenHeight * 0.54 : 390),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAddSection) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
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
                          controller: nameController,
                          maxLines: 1,
                          style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: i18n('tag_input_hint'),
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descController,
                          maxLines: 1,
                          style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: i18n('tag_desc_hint'),
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: tagController.tags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Remix.price_tag_3_line, size: 36, color: theme.disabledColor.withValues(alpha: 0.4)),
                              const SizedBox(height: 10),
                              Text(i18n('no_tags_tip'), style: AppTextStyles.t13.copyWith(color: theme.disabledColor)),
                            ],
                          ),
                        )
                      : Scrollbar(
                          controller: tagScrollController,
                          thumbVisibility: true,
                          thickness: 4.0,
                          radius: const Radius.circular(4),
                          child: GridView.builder(
                            controller: tagScrollController,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
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
                              final isSelected = tempSelectedIds.contains(tag.id);
                              return AnimatedContainer(
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
                                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                                              ? Icon(Icons.check_rounded, size: 12, color: theme.colorScheme.onPrimary)
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
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
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
                      showAddSection = false; // Collapse panel and revert header to default view layout
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      elevation: isDark ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? Colors.grey[900] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(context),
        onLongPress: () => onLongPress(context),
        onSecondaryTap: () => onLongPress(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: isDark ? Colors.grey[850] : Colors.grey[100],

                    child: room.platform == Sites.iptvSite
                        ? CachedNetworkImage(
                            imageUrl: room.cover!,
                            cacheManager: CustomImageCacheManager.instance,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 250),
                            fadeOutDuration: const Duration(milliseconds: 250),
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).focusColor,
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: AppStatusView(
                                    type: AppStatusType.loading,
                                    title: "",
                                    subtitle: "",
                                    isMini: true,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Theme.of(context).focusColor,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: dense ? 36 : 60,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.network(
                            room.cover!,
                            fit: BoxFit.cover,
                            gaplessPlayback: false,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: isDark ? Colors.grey[850] : Colors.grey[100],
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: AppStatusView(
                                      type: AppStatusType.loading,
                                      title: "",
                                      subtitle: "",
                                      isMini: true,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isDark ? Colors.grey[850] : Colors.grey[100],
                                child: AppStatusView(type: AppStatusType.error, title: "", subtitle: "", isMini: true),
                              );
                            },
                          ),
                  ),
                ),
                if (room.isRecord == true)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CountChip(
                      icon: Icons.videocam_rounded,
                      count: i18n("replay"),
                      dense: dense,
                      color: Get.theme.primaryColor,
                    ),
                  ),
                if (room.isRecord == false && room.liveStatus == LiveStatus.live)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CountChip(
                      icon: Icons.whatshot_rounded,
                      count: readableCount(room.watching ?? "0"),
                      dense: dense,
                      color: Get.theme.primaryColor,
                    ),
                  ),
              ],
            ),
            ListTile(
              dense: dense,
              minLeadingWidth: dense ? 34 : 40,
              contentPadding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 6),
              horizontalTitleGap: dense ? 8 : 12,
              leading: CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: dense),
              title: Text(
                room.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (dense ? AppTextStyles.t13 : AppTextStyles.t15).copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                room.nick ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (dense ? AppTextStyles.t12 : AppTextStyles.t13).copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              trailing: dense
                  ? null
                  : Container(
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
                    ),
            ),
          ],
        ),
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
        isFavorite ? SettingsService.to.fav.addRoom(widget.room) : SettingsService.to.fav.removeRoom(widget.room);
        Navigator.of(Get.context!).pop();
      },
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(isFavorite ? i18n("unfollow") : i18n("follow"), style: const TextStyle(fontWeight: FontWeight.w600)),
    );
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
