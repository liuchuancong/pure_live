import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/page_settings_controller.dart';

class PageSettingsPage extends GetView<SettingsService> {
  const PageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("page_settings"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("paging_controller")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('show_page_size_selector'),
              subtitle: i18n('show_page_size_selector_subtitle'),
              value: SettingsService.to.page.showPageSizeSelector,
              icon: Remix.list_settings_line,
            ),
            context.buildSwitchTile(
              title: i18n('show_goto_button'),
              subtitle: i18n('show_goto_button_subtitle'),
              value: SettingsService.to.page.showGotoButton,
              icon: Remix.skip_forward_mini_line,
            ),
            context.buildSwitchTile(
              title: i18n('show_scroll_to_top'),
              subtitle: i18n('show_scroll_to_top_subtitle'),
              value: SettingsService.to.page.showScrollToTopBtn,
              icon: Remix.arrow_up_circle_line,
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.list_check_2,
                title: i18n("page_size_options_manage"),
                subtitle: SettingsService.to.page.pageSizeOptions.join(', '),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showManageOptionsDialog(context),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showManageOptionsDialog(BuildContext context) {
    final customController = TextEditingController();
    final List<int> draftOptions = List<int>.from(SettingsService.to.page.pageSizeOptions);

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(i18n("page_size_options_manage"), style: AppTextStyles.t16Bold),
          content: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(i18n("current_options"), style: AppTextStyles.t12Muted),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                draftOptions.clear();
                                draftOptions.assignAll(PageSettingsController.getInitPageSizeOptions());
                              });
                            },
                            icon: const Icon(Icons.screen_rotation_rounded, size: 14),
                            label: Text(i18n("adaptive_recommend"), style: AppTextStyles.t12Primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: draftOptions.map((size) {
                          return Chip(
                            label: Text("$size", style: AppTextStyles.t12),
                            deleteIcon: const Icon(Icons.cancel, size: 16),
                            onDeleted: draftOptions.length > 1
                                ? () {
                                    setDialogState(() {
                                      draftOptions.remove(size);
                                    });
                                  }
                                : null,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(i18n("custom_input"), style: AppTextStyles.t13Medium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customController,
                              keyboardType: TextInputType.number,
                              style: AppTextStyles.t14,
                              decoration: InputDecoration(
                                hintText: "20",
                                suffixText: i18n("items_per_page"),
                                suffixStyle: AppTextStyles.t12Muted,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final int? val = int.tryParse(customController.text);
                              if (val != null && val > 0 && !draftOptions.contains(val)) {
                                setDialogState(() {
                                  draftOptions.add(val);
                                  draftOptions.sort();
                                });
                                customController.clear();
                              }
                            },
                            child: Text(
                              i18n("add"),
                              style: AppTextStyles.t13Medium.copyWith(color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n("cancel"), style: AppTextStyles.t14Muted),
            ),
            TextButton(
              onPressed: () {
                SettingsService.to.page.saveAllPageSizeOptions(draftOptions);
                Navigator.pop(context);
              },
              child: Text(i18n("confirm"), style: AppTextStyles.t14Primary),
            ),
          ],
        );
      },
    );
  }
}
