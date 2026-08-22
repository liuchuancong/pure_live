import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';

class RefreshSettingsPage extends GetView<RefreshConfigController> {
  const RefreshSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("refresh_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("auto_refresh_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Remix.refresh_line,
              title: i18n("auto_refresh_follow"),
              subtitle: i18n("auto_refresh_follow_subtitle"),
              value: controller.autoRefreshFavorite,
            ),
            Obx(() {
              if (controller.autoRefreshFavorite.value) {
                return context.buildTile(
                  icon: Remix.time_line,
                  title: i18n("auto_refresh_interval"),
                  subtitle: _getIntervalText(controller.autoRefreshInterval.value),
                  onTap: showRefreshIntervalDialog,
                );
              }
              return const SizedBox.shrink();
            }),
            Obx(
              () => context.buildTile(
                icon: Remix.server_line,
                title: i18n("max_concurrent_refresh"),
                subtitle:
                    '${controller.maxConcurrentRefresh.value} ${i18n('concurrent_tasks')} · ${i18n('max_concurrent_refresh_subtitle')}',
                isLong: true,
                onTap: showMaxConcurrentDialog,
              ),
            ),
            context.buildSwitchTile(
              icon: Remix.image_2_line,
              title: i18n('auto_refresh_thumbnails'),
              subtitle: i18n('auto_refresh_thumbnails_subtitle'),
              value: controller.autoRefreshThumbnails,
            ),
            Obx(() {
              if (!controller.autoRefreshThumbnails.value) return const SizedBox.shrink();
              return context.buildTile(
                icon: Remix.time_line,
                title: i18n('thumbnail_refresh_interval'),
                subtitle: _getIntervalText(controller.thumbnailRefreshInterval.value),
                onTap: showThumbnailRefreshIntervalDialog,
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
    } else if (minute == 60) {
      return "1 ${i18n("hour")}";
    } else if (minute == 90) {
      return "1.5 ${i18n("hour")}";
    } else {
      return "${minute ~/ 60} ${i18n("hour")}";
    }
  }

  void showRefreshIntervalDialog() {
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

    showDialog(
      context: Get.context!,
      builder: (context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dialogWidth = screenWidth > 600 ? 400 : double.maxFinite;

        return SimpleDialog(
          title: Text(i18n("auto_refresh_interval")),
          children: [
            Obx(() {
              return RadioGroup<int>(
                groupValue: controller.autoRefreshInterval.value,
                onChanged: (val) {
                  if (val != null) {
                    controller.autoRefreshInterval.value = val;
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  width: dialogWidth,
                  child: ListView(
                    shrinkWrap: true,
                    physics: const PureLiveScrollPhysics(),
                    children: intervals.entries.map((e) {
                      return RadioListTile<int>(
                        title: Text(e.value),
                        value: e.key,
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void showMaxConcurrentDialog() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dialogWidth = screenWidth > 600 ? 400 : double.maxFinite;

        return SimpleDialog(
          title: Text(i18n("max_concurrent_refresh")),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(i18n('max_concurrent_refresh_hint'), style: Theme.of(context).textTheme.bodySmall),
            ),
            Obx(() {
              return RadioGroup<int>(
                groupValue: controller.maxConcurrentRefresh.value,
                onChanged: (val) {
                  if (val != null) {
                    controller.maxConcurrentRefresh.value = val;
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  width: dialogWidth,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const PureLiveScrollPhysics(),
                    itemCount: 20,
                    itemBuilder: (context, index) {
                      final val = index + 1;
                      return RadioListTile<int>(
                        title: Text(
                          val == RefreshConfigController.defaultMaxConcurrentRefresh
                              ? '$val · ${i18n('recommended')}'
                              : val.toString(),
                        ),
                        value: val,
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void showThumbnailRefreshIntervalDialog() {
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

    showDialog(
      context: Get.context!,
      builder: (context) => SimpleDialog(
        title: Text(i18n('thumbnail_refresh_interval')),
        children: [
          Obx(
            () => RadioGroup<int>(
              groupValue: controller.thumbnailRefreshInterval.value,
              onChanged: (value) {
                if (value == null) return;
                controller.thumbnailRefreshInterval.value = value;
                Navigator.pop(context);
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: ListView(
                  shrinkWrap: true,
                  children: intervals.entries
                      .map(
                        (entry) => RadioListTile<int>(
                          title: Text(entry.value),
                          value: entry.key,
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
