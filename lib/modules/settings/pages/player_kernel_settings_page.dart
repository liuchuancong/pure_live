import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/models/player_super_resolution.dart';
import 'package:pure_live/modules/settings/pages/decoder_settings.dart';
import 'package:pure_live/modules/settings/pages/renderer_settings.dart';
import 'package:pure_live/common/services/settings/metered_network_service.dart';
import 'package:pure_live/modules/settings/pages/audio_output_settings_page.dart';
import 'package:pure_live/modules/settings/pages/super_resolution_settings_page.dart';

class PlayerKernelSettingsPage extends GetView<SettingsService> {
  const PlayerKernelSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('player_kernel_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('core_kernel_settings')),
          context.buildModernCard([
            _buildPlayerKernelTile(context),
            _buildProxyTile(context),
            context.buildSwitchTile(
              icon: Remix.speed_up_line,
              title: i18n('enable_codec'),
              subtitle: i18n('gpu_decode'),
              value: SettingsService.to.player.enableCodec,
            ),
            context.buildSwitchTile(
              icon: Remix.shut_down_line,
              title: i18n('force_destroy_player'),
              subtitle: i18n('force_destroy_player_subtitle'),
              value: SettingsService.to.player.useHardStopOnExit,
            ),
          ]),
          Obx(() {
            final activeKey = SettingsService.to.player.videoPlayerKey.v;

            if (PlayerConsts.engines[activeKey] != PlayerEngine.mediaKit) {
              return const SizedBox.shrink();
            }

            return _buildMpvSettings(context);
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPlayerKernelTile(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final activeKey = SettingsService.to.player.videoPlayerKey.v;

      final i18nKey = PlayerConsts.names[activeKey] ?? PlayerConsts.names[PlayerConsts.defaultKey] ?? '';

      return context.buildTile(
        icon: Remix.toggle_line,
        title: i18n('kernel_switch'),
        subtitle: i18n('kernel_switch_subtitle'),
        onTap: showVideoSetDialog,
        trailing: Text(
          i18n(i18nKey),
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
        ),
      );
    });
  }

  Widget _buildProxyTile(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final activeKey = SettingsService.to.player.videoPlayerKey.v;

      if (PlayerConsts.engines[activeKey] == PlayerEngine.exo) {
        return const SizedBox.shrink();
      }

      final enabled = SettingsService.to.proxy.enableProxy.v;

      return context.buildTile(
        icon: Remix.global_line,
        title: i18n('network_proxy'),
        subtitle: i18n('network_proxy_subtitle'),
        onTap: showProxySettingsDialog,
        trailing: Text(
          enabled ? i18n('enabled') : i18n('disabled'),
          style: AppTextStyles.t13.copyWith(
            color: enabled ? theme.colorScheme.primary : theme.hintColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    });
  }

  Widget _buildMpvSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 16, right: 16, top: 12), child: Divider()),
        const SizedBox(height: 8),
        _buildAdvancedSection(context),
        _buildCustomOutputSection(context),
        const SizedBox(height: 8),
        _buildVideoSection(context),
        const SizedBox(height: 8),
        _buildAudioSection(context),
        const SizedBox(height: 8),
        _buildPerformanceSection(context),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCustomOutputSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, icon: Icons.memory_rounded, title: i18n('custom_output_hwdec')),
        context.buildModernCard([
          context.buildSwitchTile(
            icon: Icons.memory_rounded,
            title: i18n('custom_output_hwdec'),
            subtitle: i18n('gpu_decode'),
            value: SettingsService.to.player.customPlayerOutput,
          ),
          if (PlatformUtils.isAndroid)
            context.buildSwitchTile(
              icon: Remix.shield_check_line,
              title: i18n('compat_mode'),
              subtitle: i18n('compat_mode_subtitle'),
              value: SettingsService.to.player.playerCompatMode,
              enabled: SettingsService.to.player.customPlayerOutput.v,
            ),
          if (PlatformUtils.isWindows)
            context.buildSwitchTile(
              icon: Remix.image_edit_line,
              title: i18n('enable_rtx_vsr'),
              subtitle: i18n('enable_rtx_vsr_subtitle'),
              value: SettingsService.to.player.enableRtxVsr,
              enabled: SettingsService.to.player.customPlayerOutput.v,
            ),
        ]),
      ],
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    return Obx(() {
      final customOutput = SettingsService.to.player.customPlayerOutput.v;

      final compat = PlatformUtils.isAndroid && SettingsService.to.player.playerCompatMode.v;

      final enabled = customOutput && !compat;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, icon: Remix.movie_2_line, title: i18n('video_settings')),
          context.buildModernCard([
            _buildSuperResolutionTile(context, enabled),
            _buildHardwareDecoderTile(context, enabled),
            if (PlatformUtils.isAndroid) _buildRendererTile(context, enabled),
          ]),
        ],
      );
    });
  }

  Widget _buildSuperResolutionTile(BuildContext context, bool enabled) {
    final value = SettingsService.to.player.defaultSuperResolutionMode.v;

    final mode = SuperResolutionMode.fromStorageValue(value);

    final isZh = Get.locale?.languageCode == 'zh';

    final rtxVsr = PlatformUtils.isWindows && SettingsService.to.player.enableRtxVsr.v;

    final itemEnabled = enabled && !rtxVsr;

    return context.buildTile(
      icon: Remix.sparkling_2_line,
      title: i18n('super_resolution'),
      subtitle: isZh ? mode.nameZh : mode.nameEn,
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: itemEnabled,
      onTap: itemEnabled ? () => Get.to(() => const SuperResolutionSettingsPage()) : null,
    );
  }

  Widget _buildHardwareDecoderTile(BuildContext context, bool enabled) {
    return context.buildTile(
      icon: Remix.cpu_line,
      title: i18n('hardware_decoder'),
      subtitle: _getHardwareDecoderName(context),
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: enabled,
      onTap: enabled ? () => Get.to(() => const DecoderSettingsPage()) : null,
    );
  }

  Widget _buildRendererTile(BuildContext context, bool enabled) {
    return context.buildTile(
      icon: Icons.tv_rounded,
      title: i18n('video_output_driver'),
      subtitle: _getRendererName(context),
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: enabled,
      onTap: enabled ? () => Get.to(() => const RendererSettingsPage()) : null,
    );
  }

  Widget _buildAudioSection(BuildContext context) {
    return Obx(() {
      final customOutput = SettingsService.to.player.customPlayerOutput.v;

      final compat = PlatformUtils.isAndroid && SettingsService.to.player.playerCompatMode.v;

      final enabled = customOutput && !compat;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, icon: Remix.volume_up_line, title: i18n('audio_settings')),
          context.buildModernCard([
            if (PlatformUtils.isAndroid)
              context.buildSwitchTile(
                title: i18n('low_latency_audio'),
                subtitle: i18n('low_latency_audio_subtitle'),
                value: SettingsService.to.player.androidEnableOpenSLES,
                icon: Remix.equalizer_2_line,
                enabled: enabled,
              ),
            context.buildTile(
              icon: Remix.volume_up_line,
              title: i18n('audio_output_driver'),
              subtitle: _getAudioOutputDriverName(context),
              trailing: const Icon(Icons.chevron_right_rounded),
              enabled: enabled,
              onTap: enabled ? () => Get.to(() => const AudioOutputSettingsPage()) : null,
            ),
          ]),
        ],
      );
    });
  }

  Widget _buildPerformanceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, icon: Remix.speed_up_line, title: i18n('performance_settings')),
        context.buildModernCard([
          context.buildSwitchTile(
            title: i18n('low_memory_mode'),
            subtitle: MeteredNetworkService.to.isMetered
                ? i18n('low_memory_mode_metered')
                : i18n('low_memory_mode_subtitle'),
            value: SettingsService.to.player.lowMemoryMode,
            icon: Remix.database_2_line,
            enabled: !MeteredNetworkService.to.isMetered,
          ),
        ]),
      ],
    );
  }

  Widget _buildAdvancedSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, icon: Remix.equalizer_line, title: i18n('mpv_advanced_settings')),
        context.buildModernCard([
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          i18n('mpv_warning_text'),
                          style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.65)),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => launchUrlString('https://mpv.io'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              i18n('mpv_official_docs'),
                              style: AppTextStyles.t12.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => SettingsService.to.player.resetMpvPlayerSettings(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Remix.refresh_line, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          i18n('reset'),
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, {required IconData icon, required String title}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.t16Bold.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  String _getAudioOutputDriverName(BuildContext context) {
    final key = SettingsService.to.player.audioOutputDriver.v;

    final item = PlayerConsts.audioOutputDriversList.firstWhere(
      (item) => item['key'] == key,
      orElse: () => PlayerConsts.audioOutputDriversList.first,
    );

    final isZh = Get.locale?.languageCode == 'zh';

    return isZh ? item['nameZh']! : item['nameEn']!;
  }

  String _getRendererName(BuildContext context) {
    final key = SettingsService.to.player.videoOutputDriver.v;

    final item = PlayerConsts.androidVideoRenderersList.firstWhere(
      (item) => item['key'] == key,
      orElse: () => PlayerConsts.androidVideoRenderersList.first,
    );

    final isZh = Get.locale?.languageCode == 'zh';

    return isZh ? item['nameZh']! : item['nameEn']!;
  }

  String _getHardwareDecoderName(BuildContext context) {
    final key = SettingsService.to.player.videoHardwareDecoder.v;

    final item = PlayerConsts.hardwareDecodersList.firstWhere(
      (item) => item['key'] == key,
      orElse: () => PlayerConsts.hardwareDecodersList.first,
    );

    final isZh = Get.locale?.languageCode == 'zh';

    return isZh ? item['nameZh']! : item['nameEn']!;
  }

  void showVideoSetDialog() {
    final playerEntries = PlayerConsts.engines.entries
        .where((entry) => PlatformUtils.isMobile || entry.value == PlayerEngine.mediaKit)
        .where((entry) => PlayerConsts.names.containsKey(entry.key))
        .toList();

    if (playerEntries.isEmpty) {
      return;
    }

    showDialog(
      context: Get.context!,
      builder: (context) {
        return SimpleDialog(
          title: Text(i18n('change_player')),
          children: [
            Obx(() {
              final activeKey = SettingsService.to.player.videoPlayerKey.v;

              return RadioGroup<String>(
                groupValue: activeKey,
                onChanged: (key) {
                  if (key == null) {
                    return;
                  }

                  _switchPlayer(key, context);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: playerEntries.map((entry) {
                    final key = entry.key;
                    final i18nKey = PlayerConsts.names[key];

                    if (i18nKey == null) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      leading: Radio<String>(value: key, activeColor: Theme.of(context).colorScheme.primary),
                      title: Text(i18n(i18nKey), style: AppTextStyles.t15),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      onTap: () => _switchPlayer(key, context),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _switchPlayer(String key, BuildContext context) {
    final engine = PlayerConsts.engines[key];

    if (engine == null) {
      return;
    }

    SettingsService.to.player.videoPlayerKey.v = key;

    GlobalPlayerService.instance.player.switchEngine(engine, isManual: true);

    Navigator.of(context).pop();
  }

  void showProxySettingsDialog() {
    final hostController = TextEditingController(text: SettingsService.to.proxy.proxyHost.v);

    final portController = TextEditingController(text: SettingsService.to.proxy.proxyPort.v.toString());

    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: Text(i18n('proxy_settings')),
          content: Obx(
            () => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  context.buildSwitchTile(
                    icon: Remix.shield_keyhole_line,
                    title: i18n('enable_player_proxy'),
                    value: SettingsService.to.proxy.enableProxy,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hostController,
                    enabled: SettingsService.to.proxy.enableProxy.v,
                    decoration: InputDecoration(
                      labelText: i18n('proxy_host'),
                      prefixIcon: const Icon(Remix.global_line, size: 20),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (value) => SettingsService.to.proxy.proxyHost.v = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: portController,
                    enabled: SettingsService.to.proxy.enableProxy.v,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: i18n('proxy_port'),
                      prefixIcon: const Icon(Remix.links_line, size: 20),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (value) {
                      final port = int.tryParse(value);

                      if (port != null) {
                        SettingsService.to.proxy.proxyPort.v = port;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('confirm')))],
        );
      },
    ).whenComplete(() {
      hostController.dispose();
      portController.dispose();
    });
  }
}
