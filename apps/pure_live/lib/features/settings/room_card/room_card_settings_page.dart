import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAnchor, LiveRoom, LiveStatus, RoomAudience, RoomBroadcast, RoomContent;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The room card settings page (3.x `RoomCardSettingsPage`, scoped to what
/// the shared card draws): the corner radius, the cover's shape, and which
/// of the card's info lines and pills show — over a live preview card.
///
/// Every control writes into the persisted room-card preferences, which the
/// popular, area, follow and search grids read, so the whole app re-cards
/// under the picker's finger. The reference's per-viewport configs and
/// presets have no backing in this build and stay out.
final class RoomCardSettingsPage extends ConsumerWidget {
  /// The room card settings page.
  const new({super.key});

  /// The preview card's room: a live bilibili-shaped placeholder with the
  /// pieces each knob draws.
  static final LiveRoom _previewRoom = LiveRoom.normalized(
    platform: 'bilibili',
    roomId: 'room-card-preview',
    content: const RoomContent(title: 'Pure Live · room card preview'),
    audience: const RoomAudience(onlineViewers: 12800),
    broadcast: const RoomBroadcast(liveStatus: LiveStatus.live),
    anchor: const LiveAnchor(name: 'Preview anchor'),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.roomCardSettings),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection(
            label: t.settings.roomCardPreview,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: RoomCard(room: _previewRoom, onOpen: () {}),
                ),
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection(
            label: t.settings.roomCardAppearance,
            children: [
              SettingsSliderCard(
                icon: Icons.rounded_corner_outlined,
                title: t.settings.roomCardRadius,
                subtitle: preferences.roomCardCornerRadius.toStringAsFixed(0),
                child: PureSlider(
                  value: preferences.roomCardCornerRadius.clamp(0, 28),
                  max: 28,
                  onChanged: (value) => update((p) => p.copyWith(roomCardCornerRadius: value)),
                ),
              ),
              SettingsEntryTile(
                icon: Icons.crop_original_outlined,
                title: t.settings.roomCardAspect,
                subtitle: _aspectLabel(context, preferences.roomCardAspect),
                onTap: () async {
                  final picked = await showSettingsChooser<RoomCardCoverAspect>(
                    context,
                    title: t.settings.roomCardAspect,
                    current: preferences.roomCardAspect,
                    options: [
                      for (final aspect in RoomCardCoverAspect.values) (aspect, _aspectLabel(context, aspect)),
                    ],
                  );
                  if (picked != null) {
                    await update((p) => p.copyWith(roomCardAspect: picked));
                  }
                },
                divided: false,
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.roomCardContent,
            tiles: [
              SettingsSwitchTile(
                icon: Icons.badge_outlined,
                title: t.settings.roomCardShowPlatform,
                subtitle: t.settings.roomCardShowPlatformSubtitle,
                value: preferences.roomCardShowPlatform,
                onChanged: (value) => update((p) => p.copyWith(roomCardShowPlatform: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.visibility_outlined,
                title: t.settings.roomCardShowAudience,
                subtitle: t.settings.roomCardShowAudienceSubtitle,
                value: preferences.roomCardShowAudience,
                onChanged: (value) => update((p) => p.copyWith(roomCardShowAudience: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.account_circle_outlined,
                title: t.settings.roomCardShowAnchor,
                subtitle: t.settings.roomCardShowAnchorSubtitle,
                value: preferences.roomCardShowAnchor,
                onChanged: (value) => update((p) => p.copyWith(roomCardShowAnchor: value)),
                divided: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              t.settings.roomCardScopeHint,
              style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _aspectLabel(BuildContext context, RoomCardCoverAspect aspect) => switch (aspect) {
    RoomCardCoverAspect.sixteenByNine => context.t.settings.aspectSixteenByNine,
    RoomCardCoverAspect.fourByThree => context.t.settings.aspectFourByThree,
    RoomCardCoverAspect.square => context.t.settings.aspectSquare,
  };
}
