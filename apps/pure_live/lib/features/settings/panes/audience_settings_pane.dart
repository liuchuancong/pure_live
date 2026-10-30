import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveAudienceCapability, LiveAudienceOnlineAvailability, LiveSite;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/browse/audience_metric_provider.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsHint;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The audience page (the reference's audience metric settings): the figure
/// cards lead with, whether concurrent viewers take precedence on the
/// platforms that publish them, and the platforms that only report heat or
/// total views.
final class AudienceSettingsPane extends ConsumerWidget {
  /// Creates the audience page.
  const AudienceSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final choice = ref.watch(audienceMetricProvider);
    final policy = ref.watch(audiencePolicyProvider);
    final automatic = choice == AudienceMetricChoice.automatic;
    final sites = _orderedSites(ref.watch(sitesProvider).all);
    final onlineSites = [
      for (final site in sites)
        if (LiveAudienceCapability.of(site.manifest.id).supportsConcurrentOnline) site,
    ];
    bool heatOrTotalOnly(LiveSite site) {
      final capability = LiveAudienceCapability.of(site.manifest.id);
      return !capability.supportsConcurrentOnline && (capability.hasPopularity || capability.hasTotalViewers);
    }

    final heatOnlySites = [
      for (final site in sites)
        if (heatOrTotalOnly(site)) site,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.audienceDisplayGroup),
          children: [
            SettingsChoiceRow<AudienceMetricChoice>(
              leading: const DsIcon(DsIcons.eye),
              title: t.settings.audienceMetric,
              description: t.settings.audienceMetricDesc,
              value: choice,
              options: [
                DsSelectOption(value: AudienceMetricChoice.automatic, label: t.settings.audienceAutomatic),
                DsSelectOption(value: AudienceMetricChoice.onlineViewers, label: t.settings.audienceOnline),
                DsSelectOption(value: AudienceMetricChoice.popularity, label: t.settings.audiencePopularity),
                DsSelectOption(value: AudienceMetricChoice.totalViewers, label: t.settings.audienceTotal),
              ],
              onChanged: (value) => unawaited(ref.read(audienceMetricProvider.notifier).select(value)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.audienceRealOnlineGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.activity),
              title: t.settings.audienceRealOnline,
              description: t.settings.audienceRealOnlineDesc,
              control: DsSwitch(
                value: policy.preferRealOnline,
                onChanged: automatic
                    ? (value) => unawaited(ref.read(audiencePolicyProvider.notifier).setPreferRealOnline(value: value))
                    : null,
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.audiencePlatformsGroup),
          children: [
            for (final site in onlineSites)
              _PlatformRow(
                site: site,
                enabled: policy.enabledFor(site.manifest.id),
                interactive: automatic && policy.preferRealOnline,
              ),
          ],
        ),
        if (heatOnlySites.isNotEmpty)
          DsListSection(
            header: Text('${t.settings.audienceHeatOnlyGroup} (${heatOnlySites.length})'),
            children: [
              SettingsHint(
                heatOnlySites
                    .map(localizedSiteName)
                    .join(LocaleSettings.currentLocale.languageCode == 'zh' ? '、' : ', '),
              ),
            ],
          ),
      ],
    );
  }
}

/// The reference's platform order (its legacy eight first), then any
/// platform this build adds in registry order.
const List<String> _audiencePlatformOrder = [
  'bilibili',
  'douyu',
  'huya',
  'douyin',
  'kuaishou',
  'cc',
  'twitch',
  'soop',
  'yy',
  'acfun',
  'picarto',
  'twitcasting',
  'missevan',
  'inke',
  'kilakila',
  'xiaohongshu',
  'niconico',
  'weibo',
  'looklive',
];

List<LiveSite> _orderedSites(Iterable<LiveSite> sites) {
  final remaining = {for (final site in sites) site.manifest.id: site};
  final ordered = <LiveSite>[];
  for (final id in _audiencePlatformOrder) {
    final site = remaining.remove(id);
    if (site != null) ordered.add(site);
  }
  ordered.addAll(remaining.values);
  return ordered;
}

/// The audience mode's words, shared by the choice row and the picture
/// page's entry to this page.
String audienceModeLabel(Translations t, AudienceMetricChoice choice) => switch (choice) {
  AudienceMetricChoice.automatic => t.settings.audienceAutomatic,
  AudienceMetricChoice.onlineViewers => t.settings.audienceOnline,
  AudienceMetricChoice.popularity => t.settings.audiencePopularity,
  AudienceMetricChoice.totalViewers => t.settings.audienceTotal,
};

/// A platform with a concurrent-viewer count and the switch that includes
/// it in the real-online preference. The switch is disabled, as in the
/// reference, while the preference itself is off; the stored choice stays.
final class _PlatformRow extends ConsumerWidget {
  const _PlatformRow({required this.site, required this.enabled, required this.interactive});

  final LiveSite site;
  final bool enabled;

  /// Whether the real-online preference is on; the switches are read-only
  /// otherwise (the reference greys them out under the heat-first mode).
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final capability = LiveAudienceCapability.of(site.manifest.id);
    return SettingsConfigRow(
      leading: localizedSiteIcon(site, size: 20) ?? const DsIcon(DsIcons.antenna),
      title: localizedSiteName(site),
      description: capability.onlineAvailability == LiveAudienceOnlineAvailability.roomList
          ? t.settings.audienceSourceRoomList
          : t.settings.audienceSourceRoomRealtime,
      control: DsSwitch(
        value: enabled,
        onChanged: interactive
            ? (value) => unawaited(
                ref.read(audiencePolicyProvider.notifier).setPlatformEnabled(site.manifest.id, enabled: value),
              )
            : null,
        semanticLabel: localizedSiteName(site),
      ),
    );
  }
}
