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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("refresh_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Remix.refresh_line,
              title: i18n("auto_refresh_follow"),
              subtitle: i18n("auto_refresh_follow_subtitle"),
              value: controller.autoRefreshFavorite,
            ),
            Obx(() {
              if (controller.autoRefreshFavorite.value) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    context.buildTile(
                      icon: Remix.time_line,
                      title: i18n("auto_refresh_interval"),
                      subtitle: _getIntervalText(controller.autoRefreshInterval.value),
                      onTap: showRefreshIntervalDialog,
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            Obx(
              () => context.buildTile(
                icon: Remix.server_line,
                title: i18n("max_concurrent_refresh"),
                subtitle: controller.maxConcurrentRefresh.value.toString(),
                onTap: showMaxConcurrentDialog,
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getIntervalText(int minute) {
    if (minute == 1) return "1 ${i18n("minute")}";
    if (minute == 2) return "2 ${i18n("minute")}";
    if (minute == 3) return "3 ${i18n("minute")}";
    if (minute == 5) return "5 ${i18n("minute")}";
    if (minute == 10) return "10 ${i18n("minute")}";
    if (minute == 15) return "15 ${i18n("minute")}";
    if (minute == 20) return "20 ${i18n("minute")}";
    if (minute == 30) return "30 ${i18n("minute")}";
    if (minute == 45) return "45 ${i18n("minute")}";
    if (minute == 60) return "1 ${i18n("hour")}";
    if (minute == 90) return "1.5 ${i18n("hour")}";
    if (minute == 120) return "2 ${i18n("hour")}";
    if (minute == 180) return "3 ${i18n("hour")}";
    if (minute == 240) return "4 ${i18n("hour")}";
    if (minute == 360) return "6 ${i18n("hour")}";
    if (minute == 720) return "12 ${i18n("hour")}";
    if (minute == 1440) return "24 ${i18n("hour")}";
    return "$minute ${i18n("minute")}";
  }

  void showRefreshIntervalDialog() {
    final Map<int, String> intervals = {
      1: "1 ${i18n("minute")}",
      2: "2 ${i18n("minute")}",
      3: "3 ${i18n("minute")}",
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
      720: "12 ${i18n("hour")}",
      1440: "24 ${i18n("hour")}",
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
                    physics: const BouncingScrollPhysics(),
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
                    physics: const BouncingScrollPhysics(),
                    itemCount: 20,
                    itemBuilder: (context, index) {
                      final val = index + 1;
                      return RadioListTile<int>(
                        title: Text(val.toString()),
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
}
