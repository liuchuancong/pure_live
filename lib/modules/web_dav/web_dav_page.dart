import 'package:mime/mime.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:pure_live/modules/web_dav/web_dav_help.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/modules/web_dav/web_dav_controller.dart';

class WebDavPage extends GetView<WebDavPageController> {
  WebDavPage({super.key});

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _breadcrumbScrollController = ScrollController();
  final GlobalKey _currentBreadcrumbKey = GlobalKey();

  void _showConfigDialog({WebDAVConfig? existingConfig}) {
    final isEditing = existingConfig != null;
    final nameController = TextEditingController(text: existingConfig?.name);
    final addressController = TextEditingController(text: existingConfig?.address);
    final userController = TextEditingController(text: existingConfig?.username);
    final pwdController = TextEditingController(text: existingConfig?.password);
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        title: Text(
          isEditing ? i18n("webdav_edit_config", args: {"name": existingConfig.name}) : i18n("webdav_add_new_config"),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: ListBody(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: i18n("webdav_config_name")),
                  enabled: !isEditing,
                  validator: (value) {
                    if (value == null || value.isEmpty) return i18n("webdav_config_name_empty");
                    if (!isEditing && controller.configs.any((c) => c.name == value)) {
                      return i18n("webdav_config_name_exists");
                    }
                    return null;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(labelText: i18n("webdav_address")),
                        validator: (value) => value == null || value.isEmpty ? i18n("webdav_address_empty") : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: userController,
                  decoration: InputDecoration(labelText: i18n("webdav_username")),
                  validator: (value) => value == null || value.isEmpty ? i18n("webdav_username_empty") : null,
                ),
                TextFormField(
                  controller: pwdController,
                  decoration: InputDecoration(labelText: i18n("webdav_password")),
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty ? i18n("webdav_password_empty") : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: Navigator.of(Get.context!).pop, child: Text(i18n("webdav_cancel"))),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final newConfig = WebDAVConfig(
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                  username: userController.text.trim(),
                  password: pwdController.text,
                );

                if (isEditing) {
                  final index = controller.configs.indexWhere((c) => c.name == existingConfig.name);
                  controller.configs[index] = newConfig;
                } else {
                  controller.configs.add(newConfig);
                }
                controller.saveCurrentConfig(newConfig.name);
                controller.currentConfig.value = newConfig;
                controller.dirPath.value = '/';
                controller.initializeWebDAV();
                Navigator.of(Get.context!).pop();
              }
            },
            child: Text(isEditing ? i18n("webdav_update") : i18n("webdav_add")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [_buildAppBar(), _buildNavigationBar(), _buildBodyContent()],
      ),
      endDrawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.uploadConfigSettings(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(0), bottomLeft: Radius.circular(0)),
      ),
      backgroundColor: Theme.of(Get.context!).colorScheme.surfaceContainer,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: kToolbarHeight),
          Obx(
            () => Column(
              children: [
                for (final config in controller.configs)
                  ListTile(
                    title: Text(config.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showConfigDialog(existingConfig: config),
                        ),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _showDeleteDialog(config)),
                      ],
                    ),
                    selected: controller.currentConfig.value?.name == config.name,
                    onTap: () => controller.onConfigSelected(config),
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

  void _showDeleteDialog(WebDAVConfig config) {
    Get.dialog(
      AlertDialog(
        title: Text(i18n("webdav_confirm_delete")),
        content: Text(i18n("webdav_confirm_delete_config", args: {"name": config.name})),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(Get.context!);
            },
            child: Text(i18n("webdav_cancel")),
          ),
          TextButton(
            onPressed: () => controller.deleteConfig(config),
            child: Text(
              i18n("webdav_delete"),
              style: AppTextStyles.t14.copyWith(color: Theme.of(Get.context!).colorScheme.error),
            ),
          ),
        ],
      ),
    );
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
          icon: Icon(Icons.more_vert, color: Theme.of(Get.context!).colorScheme.onPrimaryContainer),
          tooltip: i18n("webdav_more_actions"),
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

  Widget _buildNavigationBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _BreadcrumbHeaderDelegate(
        child: Container(
          color: Theme.of(Get.context!).colorScheme.surface,
          height: 50,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Obx(
              () => ListView(
                controller: _breadcrumbScrollController,
                primary: false,
                physics: const ClampingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                children: _buildBreadcrumbs(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    List<Widget> buttons = [];
    String accumulatedPath = '/';

    buttons.add(const SizedBox(width: 48));
    buttons.add(_buildCrumbButton(label: i18n("webdav_my_files"), targetPath: accumulatedPath));

    for (String part in controller.breadcrumbParts) {
      buttons.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: const Icon(Icons.navigate_next)));
      accumulatedPath += '$part/';
      buttons.add(_buildCrumbButton(label: part, targetPath: accumulatedPath));
    }

    return buttons;
  }

  Widget _buildCrumbButton({required String label, required String targetPath}) {
    final isCurrent = targetPath == controller.dirPath.value;
    return TextButton(
      key: isCurrent ? _currentBreadcrumbKey : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        if (!isCurrent) {
          controller.dirPath.value = targetPath;
          controller.isFromBreadcrumb.value = true;
          controller.updateBreadcrumbParts();
          controller.triggerBreadcrumbScroll();
          controller.loadFiles();
        }
      },
      child: Text(
        label,
        style: TextStyle(
          color: isCurrent ? Theme.of(Get.context!).colorScheme.primary : Theme.of(Get.context!).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    return Obx(() {
      if (controller.errorMessage.value != '') {
        return _buildErrorPage(controller.errorMessage.value);
      }

      if (controller.configs.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 48),
                const SizedBox(height: 16),
                Text(i18n("webdav_no_config_create_first")),
                TextButton(onPressed: () => _showConfigDialog(), child: Text(i18n("webdav_create_new_config"))),
              ],
            ),
          ),
        );
      }

      if (controller.currentConfig.value == null) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_queue, size: 48),
                const SizedBox(height: 16),
                Text(i18n("webdav_select_config_from_sidebar")),
                TextButton(
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  child: Text(i18n("webdav_open_config_list")),
                ),
              ],
            ),
          ),
        );
      }

      if (controller.isLoading.value) {
        return const SliverFillRemaining(
          child: AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
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

  Widget _buildFileItem(webdav.File file, int index) {
    return ListTile(
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
      title: Text(
        file.name ?? i18n("webdav_unnamed_file"),
        style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        file.mTime?.toString() ?? i18n("webdav_unknown_time"),
        style: TextStyle(color: Theme.of(Get.context!).colorScheme.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Theme.of(Get.context!).colorScheme.onSurface),
        itemBuilder: (context) => [
          PopupMenuItem(value: 'Download', child: Text(i18n("webdav_sync_to_local"))),
          PopupMenuItem(value: 'Delete', child: Text(i18n("webdav_delete"))),
        ],
        onSelected: (value) {
          if (value == 'Download') {
            controller.downloadFile(file);
          } else if (value == 'Delete') {
            controller.deleteFile(file);
          }
        },
      ),
      onTap: () => controller.onFileTap(file),
    );
  }

  Widget _buildErrorPage(String message) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Theme.of(Get.context!).colorScheme.onPrimaryContainer),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.t12),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _BreadcrumbHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  double get maxExtent => 50;

  @override
  double get minExtent => 50;

  @override
  bool shouldRebuild(covariant _BreadcrumbHeaderDelegate oldDelegate) => child != oldDelegate.child;
}
