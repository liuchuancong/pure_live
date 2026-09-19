import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';

class RoomCardSettingsPage extends StatefulWidget {
  const RoomCardSettingsPage({super.key});

  @override
  State<RoomCardSettingsPage> createState() => _RoomCardSettingsPageState();
}

class _RoomCardSettingsPageState extends State<RoomCardSettingsPage> {
  late RoomCardViewport _viewport;

  @override
  void initState() {
    super.initState();
    _viewport = SettingsService.to.roomCard.currentViewport;
  }

  LiveRoom get _previewRoom => LiveRoom(
    roomId: 'room-card-preview',
    platform: 'bilibili',
    title: 'Pure Live · ${i18n('room_card_preview_title')}',
    nick: i18n('room_card_preview_anchor'),
    cover: '',
    avatar: '',
    popularity: '12800',
    liveStatus: LiveStatus.live,
  );

  @override
  Widget build(BuildContext context) {
    final controller = SettingsService.to.roomCard;
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('room_card_settings')),
        actions: [
          IconButton(
            key: const ValueKey('room-card-reset'),
            tooltip: i18n('room_card_reset_current'),
            onPressed: () => controller.reset(_viewport),
            icon: const Icon(Remix.restart_line),
          ),
        ],
      ),
      body: Obx(() {
        final config = controller.configFor(_viewport);
        final preset = controller.presetFor(_viewport);
        return ListView(
          key: const ValueKey('room-card-settings-scroll'),
          physics: const PureLiveScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            context.buildGroupTitle(i18n('room_card_target')),
            Semantics(
              label: i18n('room_card_target'),
              child: Wrap(
                key: const ValueKey('room-card-target-selector'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  _targetChip(RoomCardViewport.mobile, Remix.smartphone_line, i18n('room_card_mobile')),
                  _targetChip(RoomCardViewport.desktop, Remix.computer_line, i18n('room_card_desktop')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n('room_card_preview')),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: RoomCard(
                  key: ValueKey('room-card-preview-${_viewport.name}'),
                  room: _previewRoom,
                  dense: _viewport == RoomCardViewport.mobile,
                  settingsViewport: _viewport,
                ),
              ),
            ),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n('room_card_presets')),
            Wrap(
              key: const ValueKey('room-card-preset-selector'),
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip(controller, preset, RoomCardPreset.compact, i18n('room_card_preset_compact')),
                _presetChip(controller, preset, RoomCardPreset.standard, i18n('room_card_preset_standard')),
                _presetChip(controller, preset, RoomCardPreset.detailed, i18n('room_card_preset_detailed')),
                if (preset == RoomCardPreset.custom)
                  Chip(
                    key: const ValueKey('room-card-custom-preset'),
                    avatar: const Icon(Remix.edit_line, size: 18),
                    label: Text(i18n('room_card_preset_custom')),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n('room_card_visible_content')),
            context.buildModernCard([
              _toggle(
                icon: Remix.user_3_line,
                title: i18n('room_card_show_avatar'),
                subtitle: i18n('room_card_show_avatar_subtitle'),
                value: config.showAvatar,
                onChanged: (value) => controller.updateConfig(_viewport, config.copyWith(showAvatar: value)),
              ),
              _toggle(
                icon: Remix.account_circle_line,
                title: i18n('room_card_show_anchor'),
                subtitle: i18n('room_card_show_anchor_subtitle'),
                value: config.showAnchorName,
                onChanged: (value) => controller.updateConfig(_viewport, config.copyWith(showAnchorName: value)),
              ),
              _platformBadgeMode(controller, config),
              _toggle(
                icon: Remix.group_line,
                title: i18n('room_card_show_audience'),
                subtitle: i18n('room_card_show_audience_subtitle'),
                value: config.showAudience,
                onChanged: (value) => controller.updateConfig(_viewport, config.copyWith(showAudience: value)),
              ),
              _toggle(
                icon: Remix.video_line,
                title: i18n('room_card_show_replay'),
                subtitle: i18n('room_card_show_replay_subtitle'),
                value: config.showReplayBadge,
                onChanged: (value) => controller.updateConfig(_viewport, config.copyWith(showReplayBadge: value)),
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n('room_card_appearance')),
            context.buildModernCard([
              _layoutMode(controller, config),
              context.buildSliderTile(
                context,
                icon: Remix.rounded_corner,
                title: i18n('room_card_corner_radius'),
                subtitle: i18n('room_card_corner_radius_subtitle'),
                value: config.cornerRadius,
                min: RoomCardAppearance.minCornerRadius,
                max: RoomCardAppearance.maxCornerRadius,
                displayValue: config.cornerRadius.toStringAsFixed(0),
                onChanged: (value) => controller.updateConfig(_viewport, config.copyWith(cornerRadius: value)),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              i18n('room_card_settings_scope_hint'),
              key: const ValueKey('room-card-settings-scope-hint'),
              style: AppTextStyles.t12.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        );
      }),
    );
  }

  Widget _targetChip(RoomCardViewport viewport, IconData icon, String label) {
    return ChoiceChip(
      key: ValueKey('room-card-target-${viewport.name}'),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: _viewport == viewport,
      onSelected: (_) => setState(() => _viewport = viewport),
    );
  }

  Widget _presetChip(
    RoomCardSettingsController controller,
    RoomCardPreset current,
    RoomCardPreset preset,
    String label,
  ) {
    return ChoiceChip(
      key: ValueKey('room-card-preset-${preset.storageKey}'),
      label: Text(label),
      selected: current == preset,
      onSelected: (_) => controller.applyPreset(_viewport, preset),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTextStyles.t12),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.only(left: 16, top: 2, bottom: 2, right: 8),
    );
  }

  Widget _platformBadgeMode(RoomCardSettingsController controller, RoomCardAppearance config) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Remix.layout_grid_line)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n('room_card_show_platform'), style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(i18n('room_card_show_platform_subtitle'), style: AppTextStyles.t12),
                const SizedBox(height: 10),
                Wrap(
                  key: const ValueKey('room-card-platform-mode'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _platformModeChip(
                      controller,
                      config,
                      RoomCardPlatformBadgeMode.automatic,
                      i18n('room_card_platform_automatic'),
                    ),
                    _platformModeChip(
                      controller,
                      config,
                      RoomCardPlatformBadgeMode.always,
                      i18n('room_card_platform_always'),
                    ),
                    _platformModeChip(
                      controller,
                      config,
                      RoomCardPlatformBadgeMode.hidden,
                      i18n('room_card_platform_hidden'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutMode(RoomCardSettingsController controller, RoomCardAppearance config) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.view_agenda_outlined)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n('room_card_layout'), style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(i18n('room_card_layout_subtitle'), style: AppTextStyles.t12),
                const SizedBox(height: 10),
                Wrap(
                  key: const ValueKey('room-card-layout-mode'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _layoutModeChip(controller, config, RoomCardLayout.cover, i18n('room_card_layout_cover')),
                    _layoutModeChip(controller, config, RoomCardLayout.compact, i18n('room_card_layout_compact')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutModeChip(
    RoomCardSettingsController controller,
    RoomCardAppearance config,
    RoomCardLayout layout,
    String label,
  ) {
    return ChoiceChip(
      key: ValueKey('room-card-layout-${layout.name}'),
      label: Text(label),
      selected: config.layout == layout,
      onSelected: (_) => controller.updateConfig(_viewport, config.copyWith(layout: layout)),
    );
  }

  Widget _platformModeChip(
    RoomCardSettingsController controller,
    RoomCardAppearance config,
    RoomCardPlatformBadgeMode mode,
    String label,
  ) {
    return ChoiceChip(
      key: ValueKey('room-card-platform-${mode.name}'),
      label: Text(label),
      selected: config.platformBadgeMode == mode,
      onSelected: (_) => controller.updateConfig(_viewport, config.withPlatformBadgeMode(mode)),
    );
  }
}
