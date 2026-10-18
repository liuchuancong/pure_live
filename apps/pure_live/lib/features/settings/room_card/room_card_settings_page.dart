import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAnchor, LiveRoom, LiveStatus, RoomAudience, RoomBroadcast, RoomContent;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The room card settings page (3.x `RoomCardSettingsPage`, scoped to what the
/// shared card draws): the corner radius, the cover's shape, and which of the
/// card's info lines and pills show — over a live preview card.
///
/// Every control writes into the persisted room-card preferences, which the
/// popular, area, follow and search grids read, so the whole app re-cards under
/// the picker's finger. The reference's per-viewport configs and presets have no
/// backing in this build and stay out.
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
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.roomCardSettings),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.roomCardPreview),
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: RoomCard(room: _previewRoom, onOpen: () {}),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.roomCardAppearance),
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.settings.roomCardRadius, style: PureTheme.of(context).text.title),
                      PureSlider(
                        value: preferences.roomCardCornerRadius.clamp(0, 28),
                        max: 28,
                        onChanged: (value) => update((p) => p.copyWith(roomCardCornerRadius: value)),
                      ),
                      Text(
                        preferences.roomCardCornerRadius.toStringAsFixed(0),
                        style: PureTheme.of(context).text.caption
                            .copyWith(color: PureTheme.of(context).colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.crop_original_outlined),
                title: Text(t.settings.roomCardAspect),
                value: Text(_aspectLabel(context, preferences.roomCardAspect)),
                onPressed: (_) => unawaited(_chooseAspect(context, preferences, update)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.roomCardContent),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(t.settings.roomCardShowPlatform),
                description: Text(t.settings.roomCardShowPlatformSubtitle),
                initialValue: preferences.roomCardShowPlatform,
                onToggle: (value) => update((p) => p.copyWith(roomCardShowPlatform: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(t.settings.roomCardShowAudience),
                description: Text(t.settings.roomCardShowAudienceSubtitle),
                initialValue: preferences.roomCardShowAudience,
                onToggle: (value) => update((p) => p.copyWith(roomCardShowAudience: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(t.settings.roomCardShowAnchor),
                description: Text(t.settings.roomCardShowAnchorSubtitle),
                initialValue: preferences.roomCardShowAnchor,
                onToggle: (value) => update((p) => p.copyWith(roomCardShowAnchor: value)),
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    t.settings.roomCardScopeHint,
                    style: PureTheme.of(context).text.caption
                        .copyWith(color: PureTheme.of(context).colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _chooseAspect(
    BuildContext context,
    AppPreferences preferences,
    Future<void> Function(AppPreferences Function(AppPreferences)) update,
  ) async {
    final picked = await showSettingsChooser<RoomCardCoverAspect>(
      context,
      title: context.t.settings.roomCardAspect,
      current: preferences.roomCardAspect,
      options: [for (final aspect in RoomCardCoverAspect.values) (aspect, _aspectLabel(context, aspect))],
    );
    if (picked != null) {
      await update((p) => p.copyWith(roomCardAspect: picked));
    }
  }

  static String _aspectLabel(BuildContext context, RoomCardCoverAspect aspect) => switch (aspect) {
    RoomCardCoverAspect.sixteenByNine => context.t.settings.aspectSixteenByNine,
    RoomCardCoverAspect.fourByThree => context.t.settings.aspectFourByThree,
    RoomCardCoverAspect.square => context.t.settings.aspectSquare,
  };
}
