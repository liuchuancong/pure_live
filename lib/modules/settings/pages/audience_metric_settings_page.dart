import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';

class AudienceMetricSettingsPage extends StatelessWidget {
  const AudienceMetricSettingsPage({super.key});

  static const _platforms = <({String id, String labelKey, String detailKey})>[
    (id: 'bilibili', labelKey: 'site_bilibili', detailKey: 'audience_bilibili_detail'),
    (id: 'douyu', labelKey: 'site_douyu', detailKey: 'audience_douyu_detail'),
    (id: 'huya', labelKey: 'site_huya', detailKey: 'audience_huya_detail'),
    (id: 'douyin', labelKey: 'site_douyin', detailKey: 'audience_douyin_detail'),
    (id: 'kuaishou', labelKey: 'site_kuaishou', detailKey: 'audience_kuaishou_detail'),
    (id: 'cc', labelKey: 'site_cc', detailKey: 'audience_cc_detail'),
    (id: 'twitch', labelKey: 'site_twitch', detailKey: 'audience_twitch_detail'),
    (id: 'soop', labelKey: 'site_soop', detailKey: 'audience_soop_detail'),
    (id: 'yy', labelKey: 'site_yy', detailKey: 'audience_yy_detail'),
    (id: 'acfun', labelKey: 'site_acfun', detailKey: 'audience_acfun_detail'),
    (id: 'picarto', labelKey: 'site_picarto', detailKey: 'audience_picarto_detail'),
    (id: 'twitcasting', labelKey: 'site_twitcasting', detailKey: 'audience_twitcasting_detail'),
    (id: 'missevan', labelKey: 'site_missevan', detailKey: 'audience_missevan_detail'),
    (id: 'inke', labelKey: 'site_inke', detailKey: 'audience_inke_detail'),
    (id: 'kilakila', labelKey: 'site_kilakila', detailKey: 'audience_kilakila_detail'),
    (id: 'xiaohongshu', labelKey: 'site_xiaohongshu', detailKey: 'audience_xiaohongshu_detail'),
    (id: 'niconico', labelKey: 'site_niconico', detailKey: 'audience_niconico_detail'),
    (id: 'weibo', labelKey: 'site_weibo', detailKey: 'audience_weibo_detail'),
    (id: 'looklive', labelKey: 'site_looklive', detailKey: 'audience_looklive_detail'),
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
                    const _AudienceModeTile(
                      key: ValueKey('audience-mode-heat'),
                      value: false,
                      titleKey: 'audience_mode_heat',
                      detailKey: 'audience_mode_heat_desc',
                    ),
                    const _AudienceModeTile(
                      key: ValueKey('audience-mode-online'),
                      value: true,
                      titleKey: 'audience_mode_online',
                      detailKey: 'audience_mode_online_desc',
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(i18n('audience_ranking_rule_desc'), style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('audience_online_platforms')),
          context.buildModernCard([
            for (final platform in _platforms)
              _AudiencePlatformTile(
                id: platform.id,
                labelKey: platform.labelKey,
                detailKey: platform.detailKey,
                app: app,
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

class _AudienceModeTile extends StatelessWidget {
  const _AudienceModeTile({super.key, required this.value, required this.titleKey, required this.detailKey});

  final bool value;
  final String titleKey;
  final String detailKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Text(i18n(titleKey));
      final detail = Text(i18n(detailKey));
      final stackText = constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
      return RadioListTile<bool>(
        value: value,
        title: stackText
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), detail],
              )
            : title,
        subtitle: stackText ? null : detail,
      );
    },
  );
}

class _AudiencePlatformTile extends StatelessWidget {
  const _AudiencePlatformTile({required this.id, required this.labelKey, required this.detailKey, required this.app});

  final String id;
  final String labelKey;
  final String detailKey;
  final AppSettingsController app;

  @override
  Widget build(BuildContext context) {
    final capability = LiveRoom.audienceCapabilityFor(id);
    final supported = capability.supportsConcurrentOnline;
    final sourceLabel = supported
        ? i18n(capability.onlineAvailableInRoomLists ? 'audience_source_room_list' : 'audience_source_room_realtime')
        : i18n('audience_source_not_exposed');

    Widget tile({required bool value, ValueChanged<bool>? onChanged}) => LayoutBuilder(
      builder: (context, constraints) {
        final title = Text(i18n(labelKey), key: ValueKey('audience-platform-title-$id'));
        final detail = Text('$sourceLabel\n${i18n(detailKey)}', key: ValueKey('audience-platform-detail-$id'));
        final stackText = constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
        return SwitchListTile(
          key: ValueKey('audience-platform-$id'),
          secondary: Icon(supported ? Icons.people_alt_rounded : Icons.whatshot_rounded),
          title: stackText
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 4), detail],
                )
              : title,
          subtitle: stackText ? null : detail,
          isThreeLine: !stackText,
          value: value,
          onChanged: onChanged,
        );
      },
    );

    // Unsupported rows are deliberately not wrapped in Obx. An Obx builder
    // without an Rx read is rejected by GetX and previously left this whole
    // card looking like a large empty grey block.
    if (!supported) return tile(value: false);
    return Obx(
      () => tile(value: app.isRealOnlineEnabledFor(id), onChanged: (value) => app.setRealOnlineEnabledFor(id, value)),
    );
  }
}
