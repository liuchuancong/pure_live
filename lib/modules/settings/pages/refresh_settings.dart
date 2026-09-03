import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';

class RefreshSettingsPage extends GetView<RefreshConfigController> {
  const RefreshSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('refresh_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('auto_refresh_settings')),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Remix.refresh_line,
              title: i18n('auto_refresh_follow'),
              subtitle: i18n('auto_refresh_follow_subtitle'),
              value: controller.autoRefreshFavorite,
            ),
            context.buildSwitchTile(
              icon: Remix.refresh_line,
              title: i18n('refresh_follow_on_resume'),
              subtitle: i18n('refresh_follow_on_resume_subtitle'),
              value: controller.refreshFavoriteOnResume,
            ),
            Obx(() {
              if (!controller.autoRefreshFavorite.value) {
                return const SizedBox.shrink();
              }
              return context.buildTile(
                icon: Remix.time_line,
                title: i18n('auto_refresh_interval'),
                subtitle: _getIntervalText(controller.autoRefreshInterval.value),
                onTap: () => showRefreshIntervalDialog(context),
              );
            }),
            Obx(
              () => context.buildTile(
                icon: Remix.server_line,
                title: i18n('max_concurrent_refresh'),
                subtitle:
                    '${controller.maxConcurrentRefresh.value} ${i18n('concurrent_tasks')} · ${i18n('max_concurrent_refresh_subtitle')}',
                isLong: true,
                onTap: () => showMaxConcurrentDialog(context),
              ),
            ),
            context.buildSwitchTile(
              icon: Remix.image_2_line,
              title: i18n('auto_refresh_thumbnails'),
              subtitle: i18n('auto_refresh_thumbnails_subtitle'),
              value: controller.autoRefreshThumbnails,
            ),
            Obx(() {
              if (!controller.autoRefreshThumbnails.value) {
                return const SizedBox.shrink();
              }
              return context.buildTile(
                icon: Remix.time_line,
                title: i18n('thumbnail_refresh_interval'),
                subtitle: _getIntervalText(controller.thumbnailRefreshInterval.value),
                onTap: () => showThumbnailRefreshIntervalDialog(context),
              );
            }),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getIntervalText(int minute) {
    if (minute < 60) {
      return "$minute ${i18n("minute")}";
    }
    if (minute == 60) {
      return "1 ${i18n("hour")}";
    }
    if (minute == 90) {
      return "1.5 ${i18n("hour")}";
    }
    return "${minute ~/ 60} ${i18n("hour")}";
  }

  Future<void> showRefreshIntervalDialog(BuildContext context) async {
    final Map<int, String> intervals = {
      5: "5 ${i18n("minute")}",
      10: "10 ${i18n("minute")}",
      15: "15 ${i18n("minute")}",
      20: "20 ${i18n("minute")}",
      30: "30 ${i18n("minute")}",
      45: "45 ${i18n("minute")}",
      60: "1 ${i18n("hour")}",
      90: "1.5 ${i18n("hour")}",
      120: "2 ${i18n("hour")}",
      180: "3 ${i18n("hour")}",
      240: "4 ${i18n("hour")}",
      360: "6 ${i18n("hour")}",
    };

    final int? value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _RefreshRadioDialog(
          title: i18n('auto_refresh_interval'),
          maxHeightFactor: 0.45,
          value: controller.autoRefreshInterval.value,
          items: intervals,
        );
      },
    );

    if (value != null && value != controller.autoRefreshInterval.value) {
      controller.autoRefreshInterval.value = value;
    }
  }

  Future<void> showMaxConcurrentDialog(BuildContext context) async {
    final Map<int, String> values = {
      for (int i = 1; i <= 20; i++)
        i: i == RefreshConfigController.defaultMaxConcurrentRefresh
            ? '$i · ${i18n('recommended')}'
            : i.toString(),
    };

    final int? value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _RefreshRadioDialog(
          title: i18n('max_concurrent_refresh'),
          hint: i18n('max_concurrent_refresh_hint'),
          maxHeightFactor: 0.5,
          value: controller.maxConcurrentRefresh.value,
          items: values,
        );
      },
    );

    if (value != null && value != controller.maxConcurrentRefresh.value) {
      controller.maxConcurrentRefresh.value = value;
    }
  }

  Future<void> showThumbnailRefreshIntervalDialog(BuildContext context) async {
    final Map<int, String> intervals = {
      5: "5 ${i18n("minute")}",
      10: "10 ${i18n("minute")}",
      15: "15 ${i18n("minute")}",
      30: "30 ${i18n("minute")}",
      60: "1 ${i18n("hour")}",
      120: "2 ${i18n("hour")}",
      240: "4 ${i18n("hour")}",
      360: "6 ${i18n("hour")}",
    };

    final int? value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _RefreshRadioDialog(
          title: i18n('thumbnail_refresh_interval'),
          maxHeightFactor: 0.45,
          value: controller.thumbnailRefreshInterval.value,
          items: intervals,
        );
      },
    );

    if (value != null && value != controller.thumbnailRefreshInterval.value) {
      controller.thumbnailRefreshInterval.value = value;
    }
  }
}

class _RefreshRadioDialog extends StatelessWidget {
  final String title;
  final String? hint;
  final double maxHeightFactor;
  final int value;
  final Map<int, String> items;

  const _RefreshRadioDialog({
    required this.title,
    required this.maxHeightFactor,
    required this.value,
    required this.items,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double dialogWidth = screenWidth > 600 ? 400 : screenWidth - 32;
    final double maxHeight = screenHeight * maxHeightFactor;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: screenWidth > 600 ? 280 : 0,
          maxWidth: dialogWidth,
          maxHeight: screenHeight * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(hint!, style: Theme.of(context).textTheme.bodySmall),
                ),
              SizedBox(
                height: maxHeight,
                child: RadioGroup<int>(
                  groupValue: value,
                  onChanged: (selectedValue) {
                    if (selectedValue == null) {
                      return;
                    }
                    Navigator.of(context).pop(selectedValue);
                  },
                  child: ListView(
                    physics: const PureLiveScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: items.entries.map((entry) {
                      return RadioListTile<int>(
                        title: Text(entry.value),
                        value: entry.key,
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
