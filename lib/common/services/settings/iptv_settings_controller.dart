import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';

class IptvSettingsController extends GetxController {
  static const String autoSyncHoursIntervalKey = 'autoSyncHoursInterval';

  final RxString selectedSourceName = hiveString('selectedSourceName', '');
  final RxString selectedSourceId = hiveString('selectedSourceId', '');
  final RxBool isAutoSyncEnabled = hiveBool('isAutoSyncEnabled', false);
  final RxInt autoSyncHoursInterval = hiveInt(autoSyncHoursIntervalKey, 24);
  final RxString customIptvUserAgent = hiveString('customIptvUserAgent', '');
  final RxString m3uDirectory = hiveString('m3uDirectory', 'm3uDirectory');

  Timer? _startupSyncTimer;

  @override
  void onInit() {
    super.onInit();
    if (!isAutoSyncEnabled.v) return;
    _startupSyncTimer = Timer(3.seconds, () {
      final iptvEnabled = SettingsService.to.fav.hotAreasList.v.contains(Sites.iptvSite);
      if (!shouldRunBackgroundStartupSync(iptvEnabled: iptvEnabled, autoSyncEnabled: isAutoSyncEnabled.v)) return;
      unawaited(AutoSyncScheduler.instance.checkAndExecuteAutoSync());
    });
  }

  @override
  void onClose() {
    _startupSyncTimer?.cancel();
    _startupSyncTimer = null;
    super.onClose();
  }

  /// Ordinary launches stay network-idle. Only an explicit auto-sync setting
  /// may schedule maintenance, and built-in IPTV/EPG resources are loaded by
  /// their feature entry points instead of by application startup.
  @visibleForTesting
  static bool shouldRunBackgroundStartupSync({required bool iptvEnabled, required bool autoSyncEnabled}) =>
      iptvEnabled && autoSyncEnabled;

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

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final iptv = rootConfig?['iptv'] as Map<String, dynamic>? ?? {};
    return {
      'selectedSourceName': iptv['selectedSourceName'] ?? '',
      'selectedSourceId': iptv['selectedSourceId'] ?? '',
      'isAutoSyncEnabled': iptv['isAutoSyncEnabled'] ?? false,
      'autoSyncHoursInterval': iptv['autoSyncHoursInterval'] ?? 24,
      'customIptvUserAgent': iptv['customIptvUserAgent'] ?? '',
      'm3uDirectory': iptv['m3uDirectory'] ?? 'm3uDirectory',
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final iptv = Map<String, dynamic>.from(rootConfig['iptv'] ?? {});
    updateFields.forEach((k, v) => iptv[k] = v);
    rootConfig['iptv'] = iptv;
    return rootConfig;
  }
}
