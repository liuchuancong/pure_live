import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class AudienceInfo extends StatelessWidget {
  const AudienceInfo({super.key});

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  Widget build(BuildContext context) {
    if (controller.site == Sites.iptvSite) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final room = controller.state.value.room.detail;

      if (room == null) {
        return const SizedBox.shrink();
      }

      final app = SettingsService.to.app;

      final type = room.audienceType(
        preferRealOnline: app.preferRealOnlineCounts.v,
        platformEnabled: app.isRealOnlineEnabledFor(room.platform),
      );

      final value = room.audienceValue(
        preferRealOnline: app.preferRealOnlineCounts.v,
        platformEnabled: app.isRealOnlineEnabledFor(room.platform),
      );

      final icon = switch (type) {
        AudienceMetricType.onlineViewers => Icons.people_alt_rounded,
        AudienceMetricType.totalViewers => Icons.visibility_rounded,
        AudienceMetricType.followers => Icons.favorite_rounded,
        _ => Icons.whatshot_rounded,
      };

      final label = i18n(switch (type) {
        AudienceMetricType.onlineViewers => 'audience_online',
        AudienceMetricType.totalViewers => 'audience_total',
        AudienceMetricType.followers => 'audience_followers',
        AudienceMetricType.popularity => 'audience_popularity',
        AudienceMetricType.unknown => 'audience_count',
      });

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            '$label ${value.isEmpty ? i18n('audience_waiting') : readableCount(value)}',
            style: Get.textTheme.bodySmall,
          ),
        ],
      );
    });
  }
}
