import 'package:pure_live/common/index.dart';

class AudienceMetricSettingsPage extends StatelessWidget {
  const AudienceMetricSettingsPage({super.key});

  static const _platforms = <({String id, String name, String detailKey})>[
    (id: 'bilibili', name: '哔哩哔哩', detailKey: 'audience_bilibili_detail'),
    (id: 'douyu', name: '斗鱼', detailKey: 'audience_douyu_detail'),
    (id: 'huya', name: '虎牙', detailKey: 'audience_huya_detail'),
    (id: 'douyin', name: '抖音', detailKey: 'audience_douyin_detail'),
    (id: 'kuaishou', name: '快手', detailKey: 'audience_kuaishou_detail'),
    (id: 'cc', name: '网易 CC', detailKey: 'audience_cc_detail'),
    (id: 'twitch', name: 'Twitch', detailKey: 'audience_twitch_detail'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = SettingsService.to.app;
    return Scaffold(
      appBar: AppBar(title: Text(i18n('audience_metric_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('audience_display_mode')),
          context.buildModernCard([
            Obx(
              () => RadioGroup<bool>(
                groupValue: app.preferRealOnlineCounts.v,
                onChanged: (value) {
                  if (value != null) app.preferRealOnlineCounts.v = value;
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      title: Text(i18n('audience_mode_heat')),
                      subtitle: Text(i18n('audience_mode_heat_desc')),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      title: Text(i18n('audience_mode_online')),
                      subtitle: Text(i18n('audience_mode_online_desc')),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('audience_online_platforms')),
          context.buildModernCard([
            for (final platform in _platforms)
              Obx(() {
                final capability = LiveRoom.audienceCapabilityFor(platform.id);
                final supported = capability.supportsConcurrentOnline;
                final sourceLabel = supported
                    ? i18n(
                        capability.onlineAvailableInRoomLists
                            ? 'audience_source_room_list'
                            : 'audience_source_room_realtime',
                      )
                    : i18n('audience_source_not_exposed');
                return SwitchListTile(
                  secondary: Icon(supported ? Icons.people_alt_rounded : Icons.whatshot_rounded),
                  title: Text(platform.name),
                  subtitle: Text('$sourceLabel\n${i18n(platform.detailKey)}'),
                  isThreeLine: true,
                  value: supported && app.isRealOnlineEnabledFor(platform.id),
                  onChanged: supported ? (value) => app.setRealOnlineEnabledFor(platform.id, value) : null,
                );
              }),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(i18n('audience_metric_fallback_desc'), style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
