import 'package:pure_live/common/index.dart';

class AudienceMetricSettingsPage extends StatelessWidget {
  const AudienceMetricSettingsPage({super.key});

  static const _platforms = <({String id, String name, bool supported, String detailKey})>[
    (id: 'bilibili', name: '哔哩哔哩', supported: false, detailKey: 'audience_bilibili_detail'),
    (id: 'douyu', name: '斗鱼', supported: false, detailKey: 'audience_douyu_detail'),
    (id: 'huya', name: '虎牙', supported: true, detailKey: 'audience_huya_detail'),
    (id: 'douyin', name: '抖音', supported: true, detailKey: 'audience_douyin_detail'),
    (id: 'kuaishou', name: '快手', supported: true, detailKey: 'audience_kuaishou_detail'),
    (id: 'cc', name: '网易 CC', supported: true, detailKey: 'audience_cc_detail'),
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
              Obx(
                () => SwitchListTile(
                  secondary: Icon(platform.supported ? Icons.people_alt_rounded : Icons.whatshot_rounded),
                  title: Text(platform.name),
                  subtitle: Text(i18n(platform.detailKey)),
                  value: platform.supported && app.isRealOnlineEnabledFor(platform.id),
                  onChanged: platform.supported ? (value) => app.setRealOnlineEnabledFor(platform.id, value) : null,
                ),
              ),
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
