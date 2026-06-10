import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';

class IptvSettingsController extends GetxController {
  final RxString selectedSourceName = hiveString('selectedSourceName', '');
  final RxString selectedSourceId = hiveString('selectedSourceId', '');
  final RxBool isAutoSyncEnabled = hiveBool('isAutoSyncEnabled', false);
  final RxInt autoSyncHoursInterval = hiveInt('autoShutDownTime', 24);
  final RxString customIptvUserAgent = hiveString('customIptvUserAgent', '');
  final RxString m3uDirectory = hiveString('m3uDirectory', 'm3uDirectory');

  @override
  void onInit() {
    super.onInit();
    Future.delayed(3.seconds, () {
      if (SettingsService.to.fav.hotAreasList.v.contains(Sites.iptvSite)) {
        AutoSyncScheduler.instance.checkAndExecuteAutoSync();
        AutoSyncScheduler.instance.loadHotResources();
        AutoSyncScheduler.instance.loadDefaultEpgResources();
      }
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedSourceName': selectedSourceName.v,
      'selectedSourceId': selectedSourceId.v,
      'isAutoSyncEnabled': isAutoSyncEnabled.v,
      'autoSyncHoursInterval': autoSyncHoursInterval.v,
      'customIptvUserAgent': customIptvUserAgent.v,
      'm3uDirectory': m3uDirectory.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    selectedSourceName.v = json['selectedSourceName'] ?? '';
    selectedSourceId.v = json['selectedSourceId'] ?? '';
    isAutoSyncEnabled.v = json['isAutoSyncEnabled'] ?? false;
    autoSyncHoursInterval.v = json['autoSyncHoursInterval'] ?? 24;
    customIptvUserAgent.v = json['customIptvUserAgent'] ?? '';
    m3uDirectory.v = json['m3uDirectory'] ?? 'm3uDirectory';
  }
}
