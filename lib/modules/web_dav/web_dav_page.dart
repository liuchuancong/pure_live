import 'dart:async';

import 'package:mime/mime.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/modules/web_dav/web_dav_help.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/modules/web_dav/web_dav_controller.dart';

class WebDavPage extends StatefulWidget {
  const WebDavPage({super.key});

  @override
  State<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends State<WebDavPage> {
  WebDavPageController get controller => Get.find<WebDavPageController>();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _breadcrumbScrollController = ScrollController();
  int _breadcrumbScrollGeneration = 0;

  void _showConfigDialog({WebDAVConfig? existingConfig}) {
    showDialog<void>(
      context: context,
      builder: (_) => _WebDavConfigDialog(controller: controller, existingConfig: existingConfig),
    );
  }

  @override
  void dispose() {
    _breadcrumbScrollGeneration++;
    _breadcrumbScrollController.dispose();
    super.dispose();
  }

  void _scheduleBreadcrumbScrollToCurrent() {
    final generation = ++_breadcrumbScrollGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _breadcrumbScrollGeneration || !_breadcrumbScrollController.hasClients) return;
      final position = _breadcrumbScrollController.position;
      if (!position.hasContentDimensions) return;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 0.5) return;
      unawaited(
        _breadcrumbScrollController
            .animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic)
            .then((_) {
              if (!mounted || generation != _breadcrumbScrollGeneration || !_breadcrumbScrollController.hasClients) {
                return;
              }
              final settledPosition = _breadcrumbScrollController.position;
              final settledTarget = settledPosition.maxScrollExtent;
              if ((settledPosition.pixels - settledTarget).abs() >= 0.5) {
                settledPosition.jumpTo(settledTarget);
              }
            }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final breadcrumbExtent = _breadcrumbHeaderExtent(context);
          final minimumStateHeight = (constraints.maxHeight - kToolbarHeight - breadcrumbExtent)
              .clamp(0.0, double.infinity)
              .toDouble();
          return CustomScrollView(
            key: const ValueKey('webdav-page-scroll'),
            physics: const PureLiveScrollPhysics(),
            slivers: [
              _buildAppBar(),
              _buildNavigationBar(breadcrumbExtent),
              SliverToBoxAdapter(child: _buildFileActionStatus()),
              _buildBodyContent(minimumStateHeight),
            ],
          );
        },
      ),
      endDrawer: _buildDrawer(context),
      floatingActionButton: Obx(
        () => FloatingActionButton(
          onPressed: controller.canUpload ? () => controller.uploadConfigSettings() : null,
          tooltip: i18n(controller.isUploading.value ? 'webdav_uploading' : 'webdav_upload_current'),
          child: controller.isUploading.value
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined),
        ),
      ),
    );
  }

  Widget _buildFileActionStatus() => Obx(() {
    final key = controller.fileActionLabelKey.value;
    if (key.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Text(i18n(key)),
          const SizedBox(height: 6),
          LinearProgressIndicator(semanticsLabel: i18n(key)),
        ],
      ),
    );
  });

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(0), bottomLeft: Radius.circular(0)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: kToolbarHeight),
          Obx(
            () => Column(
              children: [
                for (final config in controller.configs)
                  ListTile(
                    title: Tooltip(
                      message: config.name,
                      child: Text(config.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: i18n("webdav_edit_config", args: {"name": config.name}),
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showConfigDialog(existingConfig: config),
                        ),
                        IconButton(
                          tooltip: i18n("webdav_delete"),
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeleteDialog(config),
                        ),
                      ],
                    ),
                    selected: controller.currentConfig.value?.name == config.name,
                    onTap: () {
                      controller.onConfigSelected(config);
                      _scaffoldKey.currentState?.closeEndDrawer();
                    },
                  ),
                ListTile(
                  title: Text(i18n("webdav_add_new_config")),
                  leading: const Icon(Icons.add),
                  onTap: () => _showConfigDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(WebDAVConfig config) async {
    final confirmed = await _showDeleteConfirmation(i18n("webdav_confirm_delete_config", args: {"name": config.name}));
    if (confirmed && mounted) controller.deleteConfig(config);
  }

  Future<bool> _showFileDeleteDialog(webdav.File file) =>
      _showDeleteConfirmation(i18n("webdav_confirm_delete_item", args: {"name": _fileDisplayName(file)}));

  Future<bool> _showDeleteConfirmation(String message) => _showConfirmation(
    title: i18n("webdav_confirm_delete"),
    message: message,
    confirmLabel: i18n("webdav_delete"),
    danger: true,
  );

  Future<bool> _showFileRestoreDialog(webdav.File file, BackupRestoreScope scope) {
    final favoritesOnly = scope == BackupRestoreScope.favorites;
    return _showConfirmation(
      title: i18n(favoritesOnly ? 'webdav_restore_favorites' : 'recover_backup'),
      message: favoritesOnly
          ? '${i18n("webdav_confirm_restore_favorites_item", args: {"name": _fileDisplayName(file)})} '
                '${i18n("webdav_favorites_unchanged_hint")}'
          : i18n("webdav_confirm_restore_item", args: {"name": _fileDisplayName(file)}),
      confirmLabel: i18n(favoritesOnly ? 'webdav_restore_favorites' : 'recover_backup'),
    );
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(title),
          content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(i18n("webdav_cancel")),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    )
                  : FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      pinned: false,
      snap: false,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(i18n("webdav"), style: const TextStyle(fontWeight: FontWeight.w400)),
      actions: [
        PopupMenuButton<int>(
          tooltip: i18n("webdav_more_actions"),
          child: SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: Icon(Icons.more_vert, color: Theme.of(Get.context!).colorScheme.onPrimaryContainer),
          ),
          onSelected: (int value) {
            if (value == 1) {
              controller.loadFiles();
            } else if (value == 2) {
              _scaffoldKey.currentState?.openEndDrawer();
            } else if (value == 3) {
              Get.to(() => const WebDavHelpPage());
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 1,
              child: MenuListTile(leading: const Icon(Icons.refresh), text: i18n("webdav_refresh")),
            ),
            PopupMenuItem(
              value: 2,
              child: MenuListTile(leading: const Icon(Icons.menu), text: i18n("webdav_open_config_list")),
            ),
            PopupMenuItem(
              value: 3,
              child: MenuListTile(leading: const Icon(Remix.question_line), text: i18n("webdav_help_tutorial")),
            ),
          ],
        ),
      ],
    );
  }

  double _breadcrumbHeaderExtent(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500);
    final painter = TextPainter(
      text: TextSpan(text: 'Ag国🙂', style: labelStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final scaledExtent = painter.height + 16;
    return scaledExtent < 50 ? 50 : scaledExtent;
  }

  Widget _buildNavigationBar(double extent) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _BreadcrumbHeaderDelegate(
        extent: extent,
        child: Container(
          key: const ValueKey('webdav-breadcrumb-header'),
          color: Theme.of(Get.context!).colorScheme.surface,
          height: extent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Obx(() {
              final parts = controller.breadcrumbParts.toList(growable: false);
              _scheduleBreadcrumbScrollToCurrent();
              return ListView(
                key: const ValueKey('webdav-breadcrumb-scroll'),
                controller: _breadcrumbScrollController,
                primary: false,
                physics: const PureLiveBoundedScrollPhysics(),
                scrollDirection: Axis.horizontal,
                children: _buildBreadcrumbs(parts),
              );
            }),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs(List<String> parts) {
    List<Widget> buttons = [];
    String accumulatedPath = '/';

    buttons.add(const SizedBox(width: 48));
    buttons.add(_buildCrumbButton(label: i18n("webdav_my_files"), targetPath: accumulatedPath));

    for (final part in parts) {
      buttons.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: const Icon(Icons.navigate_next)));
      accumulatedPath += '$part/';
      buttons.add(_buildCrumbButton(label: part, targetPath: accumulatedPath));
    }

    return buttons;
  }

  Widget _buildCrumbButton({required String label, required String targetPath}) {
    final isCurrent = targetPath == controller.dirPath.value;
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        if (!isCurrent) {
          controller.dirPath.value = targetPath;
          controller.updateBreadcrumbParts();
          controller.loadFiles();
        }
      },
      child: Tooltip(
        message: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent
                  ? Theme.of(Get.context!).colorScheme.primary
                  : Theme.of(Get.context!).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(double minimumStateHeight) {
    return Obx(() {
      if (controller.configs.isEmpty) {
        return _buildStateSurface(
          minimumHeight: minimumStateHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, size: 48),
              const SizedBox(height: 16),
              ..._configurationIssueKeyWidgets(),
              Text(i18n("webdav_no_config_create_first"), textAlign: TextAlign.center),
              TextButton(onPressed: () => _showConfigDialog(), child: Text(i18n("webdav_create_new_config"))),
            ],
          ),
        );
      }

      if (controller.currentConfig.value == null) {
        return _buildStateSurface(
          minimumHeight: minimumStateHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_queue, size: 48),
              const SizedBox(height: 16),
              ..._configurationIssueKeyWidgets(),
              Text(i18n("webdav_select_config_from_sidebar"), textAlign: TextAlign.center),
              TextButton(
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Text(i18n("webdav_open_config_list")),
              ),
            ],
          ),
        );
      }

      if (controller.errorMessage.value.isNotEmpty) {
        return _buildErrorPage(controller.errorMessage.value, minimumStateHeight);
      }

      if (controller.isLoading.value) {
        return _buildStateSurface(
          minimumHeight: minimumStateHeight,
          child: const AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
        );
      }

      if (controller.files.isEmpty) {
        return _buildStateSurface(
          minimumHeight: minimumStateHeight,
          child: Text(i18n("status_empty_title"), textAlign: TextAlign.center),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final file = controller.files[index];
          return _buildFileItem(file, index);
        }, childCount: controller.files.length),
      );
    });
  }

  Widget _buildStateSurface({required double minimumHeight, required Widget child}) {
    return SliverToBoxAdapter(
      child: ConstrainedBox(
        key: const ValueKey('webdav-state-content'),
        constraints: BoxConstraints(minHeight: minimumHeight),
        child: Center(
          child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 96), child: child),
        ),
      ),
    );
  }

  List<Widget> _configurationIssueKeyWidgets() => [
    if (controller.configurationIssueKey.value.isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Text(i18n(controller.configurationIssueKey.value), textAlign: TextAlign.center),
      ),
  ];

  Widget _buildFileItem(webdav.File file, int index) {
    final displayName = _fileDisplayName(file);
    return ListTile(
      isThreeLine: true,
      hoverColor: Theme.of(Get.context!).colorScheme.primaryContainer,
      leading: Icon(
        file.isDir ?? false
            ? Icons.folder_outlined
            : lookupMimeType(file.name ?? '')?.startsWith('image/') ?? false
            ? Icons.image_outlined
            : lookupMimeType(file.name ?? '')?.startsWith('video/') ?? false
            ? Icons.video_library_outlined
            : lookupMimeType(file.name ?? '')?.startsWith('audio/') ?? false
            ? Icons.audio_file_outlined
            : lookupMimeType(file.name ?? '')?.startsWith('text/') ?? false
            ? Icons.text_snippet_outlined
            : Icons.insert_drive_file_outlined,
        color: Theme.of(Get.context!).colorScheme.primary,
        size: 28,
      ),
      title: Tooltip(
        message: displayName,
        child: Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      subtitle: Text(
        file.mTime?.toString() ?? i18n("webdav_unknown_time"),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(Get.context!).colorScheme.onSurfaceVariant),
      ),
      trailing: Obx(
        () {
          final enabled = controller.canStartFileAction;
          return PopupMenuButton<String>(
            enabled: enabled,
            tooltip: i18n("webdav_more_actions"),
            child: SizedBox.square(
              dimension: kMinInteractiveDimension,
              child: Icon(
                Icons.more_vert,
                color: enabled ? Theme.of(Get.context!).colorScheme.onSurface : Theme.of(Get.context!).disabledColor,
              ),
            ),
            itemBuilder: (context) => [
              if (file.isDir != true) ...[
                PopupMenuItem(value: 'RestoreAll', child: Text(i18n("webdav_restore_all_settings"))),
                PopupMenuItem(value: 'RestoreFavorites', child: Text(i18n("webdav_restore_favorites"))),
              ],
              PopupMenuItem(value: 'Delete', child: Text(i18n("webdav_delete"))),
            ],
            onSelected: (value) {
              if (value == 'RestoreAll') {
                unawaited(
                  controller.downloadFile(
                    file,
                    confirmRestore: () => _showFileRestoreDialog(file, BackupRestoreScope.all),
                  ),
                );
              } else if (value == 'RestoreFavorites') {
                unawaited(
                  controller.downloadFile(
                    file,
                    scope: BackupRestoreScope.favorites,
                    confirmRestore: () => _showFileRestoreDialog(file, BackupRestoreScope.favorites),
                  ),
                );
              } else if (value == 'Delete') {
                unawaited(controller.deleteFile(file, confirmDelete: () => _showFileDeleteDialog(file)));
              }
            },
          );
        },
      ),
      onTap: () => controller.onFileTap(file),
    );
  }

  String _fileDisplayName(webdav.File file) {
    final name = file.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final path = file.path?.trim().replaceAll(RegExp(r'/+$'), '');
    if (path != null && path.isNotEmpty) {
      final pathName = path.split('/').last.trim();
      if (pathName.isNotEmpty) return pathName;
    }
    return i18n("webdav_unnamed_file");
  }

  Widget _buildErrorPage(String message, double minimumStateHeight) {
    return _buildStateSurface(
      minimumHeight: minimumStateHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error, size: 64, color: Theme.of(Get.context!).colorScheme.onPrimaryContainer),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.t12),
          TextButton(onPressed: controller.loadFiles, child: Text(i18n("retry"))),
        ],
      ),
    );
  }
}

class _WebDavConfigDialog extends StatefulWidget {
  const _WebDavConfigDialog({required this.controller, this.existingConfig});

  final WebDavPageController controller;
  final WebDAVConfig? existingConfig;

  @override
  State<_WebDavConfigDialog> createState() => _WebDavConfigDialogState();
}

class _WebDavConfigDialogState extends State<_WebDavConfigDialog> {
  WebDavPageController get controller => widget.controller;
  WebDAVConfig? get existingConfig => widget.existingConfig;
  bool get isEditing => existingConfig != null;
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(text: existingConfig?.name);
  late final addressController = TextEditingController(text: existingConfig?.address);
  late final userController = TextEditingController(text: existingConfig?.username);
  late final pwdController = TextEditingController(text: existingConfig?.password);

  @override
  void dispose() {
    // A popped dialog remains mounted until its reverse transition completes.
    // Its State, rather than the route-result future, owns these controllers.
    nameController.dispose();
    addressController.dispose();
    userController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = isEditing
        ? i18n("webdav_edit_config", args: {"name": existingConfig!.name})
        : i18n("webdav_add_new_config");
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 8),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      title: Row(
        children: [
          Icon(
            isEditing ? Remix.edit_box_line : Remix.add_box_line,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: titleText,
              child: Text(titleText, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.t18Bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: formKey,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: i18n("webdav_config_name"),
                    prefixIcon: const Icon(Remix.bookmark_line, size: 20),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  enabled: !isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return i18n("webdav_config_name_empty");
                    if (!isEditing && controller.configs.any((c) => c.name == value.trim())) {
                      return i18n("webdav_config_name_exists");
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: i18n("webdav_address"),
                    errorMaxLines: 6,
                    prefixIcon: const Icon(Remix.global_line, size: 20),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return i18n("webdav_address_empty");
                    return WebDAVConfig.isValidAddress(value) ? null : i18n("webdav_address_invalid");
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: userController,
                  decoration: InputDecoration(
                    labelText: i18n("webdav_username"),
                    prefixIcon: const Icon(Remix.user_3_line, size: 20),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? i18n("webdav_username_empty") : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pwdController,
                  decoration: InputDecoration(
                    labelText: i18n("webdav_password"),
                    prefixIcon: const Icon(Remix.lock_password_line, size: 20),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty ? i18n("webdav_password_empty") : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: Navigator.of(context).pop,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(i18n("webdav_cancel")),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              final newConfig = WebDAVConfig(
                name: nameController.text.trim(),
                address: addressController.text.trim(),
                username: userController.text.trim(),
                password: pwdController.text,
              );

              if (isEditing) {
                final index = controller.configs.indexWhere((c) => c.name == existingConfig!.name);
                controller.configs[index] = newConfig;
              } else {
                controller.configs.add(newConfig);
              }
              controller.currentConfig.value = newConfig;
              controller.saveCurrentConfig(newConfig.name);
              controller.dirPath.value = '/';
              controller.initializeWebDAV();
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text(isEditing ? i18n("webdav_update") : i18n("webdav_add")),
        ),
      ],
    );
  }
}

class _BreadcrumbHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;

  _BreadcrumbHeaderDelegate({required this.child, required this.extent});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  bool shouldRebuild(covariant _BreadcrumbHeaderDelegate oldDelegate) =>
      child != oldDelegate.child || extent != oldDelegate.extent;
}
