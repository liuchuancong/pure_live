import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';

class IptvSettingsController extends GetxController {
  final HiveRxString selectedSourceName = HiveRxString('selectedSourceName', '');
  final HiveRxString selectedSourceId = HiveRxString('selectedSourceId', '');
  final HiveRxBool isAutoSyncEnabled = HiveRxBool('isAutoSyncEnabled', false);
  final HiveRxInt autoSyncHoursInterval = HiveRxInt('autoShutDownTime', 24);
  final HiveRxString customIptvUserAgent = HiveRxString('customIptvUserAgent', '');
  final HiveRxString m3uDirectory = HiveRxString('m3uDirectory', 'm3uDirectory');

  @override
  void onInit() {
    super.onInit();
    Future.delayed(1.seconds, () {
      AutoSyncScheduler.instance.checkAndExecuteAutoSync();
      AutoSyncScheduler.instance.loadHotResources();
      AutoSyncScheduler.instance.loadDefaultEpgResources();
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
