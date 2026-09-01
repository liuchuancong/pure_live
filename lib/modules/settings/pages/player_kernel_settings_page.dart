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

  SettingsService get settings => SettingsService.to;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('player_kernel_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildCoreSettings(context),
          Obx(() {
            final activeKey = settings.player.videoPlayerKey.v;

            if (PlayerConsts.engines[activeKey] != PlayerEngine.mediaKit) {
              return const SizedBox.shrink();
            }

            return _buildMpvSettings(context);
          }),
        ],
      ),
    );
  }

  Widget _buildCoreSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('core_kernel_settings')),
        context.buildModernCard([
          _buildPlayerKernelTile(context),
          _buildProxyTile(context),
          context.buildSwitchTile(
            icon: Remix.speed_up_line,
            title: i18n('enable_codec'),
            subtitle: i18n('gpu_decode'),
            value: settings.player.enableCodec,
          ),
          context.buildSwitchTile(
            icon: Remix.shut_down_line,
            title: i18n('force_destroy_player'),
            subtitle: i18n('force_destroy_player_subtitle'),
            value: settings.player.useHardStopOnExit,
          ),
        ]),
      ],
    );
  }

  Widget _buildPlayerKernelTile(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final activeKey = settings.player.videoPlayerKey.v;

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
      final activeKey = settings.player.videoPlayerKey.v;

      if (PlayerConsts.engines[activeKey] == PlayerEngine.exo) {
        return const SizedBox.shrink();
      }

      final enabled = settings.proxy.enableProxy.v;

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
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 4),
        _buildAdvancedSection(context),
        _buildOutputSection(context),
        _buildVideoSection(context),
        _buildAudioSection(context),
        _buildPerformanceSection(context),
      ],
    );
  }

  Widget _buildOutputSection(BuildContext context) {
    return Obx(() {
      final customOutput = settings.player.customPlayerOutput.v;
      final compatMode = PlatformUtils.isAndroid && settings.player.playerCompatMode.v;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, icon: Remix.settings_4_line, title: i18n('output_settings')),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Remix.settings_5_line,
              title: i18n('custom_output'),
              subtitle: i18n('custom_output_subtitle'),
              value: settings.player.customPlayerOutput,
            ),
            if (PlatformUtils.isAndroid)
              context.buildSwitchTile(
                icon: Remix.shield_check_line,
                title: i18n('compat_mode'),
                subtitle: compatMode ? i18n('compat_mode_enabled_subtitle') : i18n('compat_mode_subtitle'),
                value: settings.player.playerCompatMode,
                enabled: customOutput,
              ),
            if (PlatformUtils.isWindows)
              context.buildSwitchTile(
                icon: Remix.sparkling_2_line,
                title: i18n('enable_rtx_vsr'),
                subtitle: i18n('enable_rtx_vsr_subtitle'),
                value: settings.player.enableRtxVsr,
                enabled: customOutput,
              ),
          ]),
        ],
      );
    });
  }

  Widget _buildVideoSection(BuildContext context) {
    return Obx(() {
      final customOutput = settings.player.customPlayerOutput.v;

      final compatMode = PlatformUtils.isAndroid && settings.player.playerCompatMode.v;

      final rtxVsr = PlatformUtils.isWindows && settings.player.enableRtxVsr.v;

      final videoSettingsEnabled = customOutput && !compatMode;

      final superResolutionEnabled = videoSettingsEnabled && !rtxVsr;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, icon: Remix.movie_2_line, title: i18n('video_settings')),
          context.buildModernCard([
            _buildSuperResolutionTile(context, enabled: superResolutionEnabled, rtxVsr: rtxVsr),
            _buildHardwareDecoderTile(context, enabled: videoSettingsEnabled),
            _buildRendererTile(context, enabled: videoSettingsEnabled),
          ]),
        ],
      );
    });
  }

  Widget _buildSuperResolutionTile(BuildContext context, {required bool enabled, required bool rtxVsr}) {
    return Obx(() {
      final value = settings.player.defaultSuperResolutionMode.v;

      final mode = SuperResolutionMode.fromStorageValue(value);

      final isZh = Get.locale?.languageCode == 'zh';

      return context.buildTile(
        icon: Remix.sparkling_2_line,
        title: i18n('super_resolution'),
        subtitle: rtxVsr
            ? i18n('disabled_by_rtx_vsr')
            : isZh
            ? mode.nameZh
            : mode.nameEn,
        trailing: const Icon(Remix.arrow_right_s_line),
        enabled: enabled,
        onTap: enabled ? () => Get.to(() => const SuperResolutionSettingsPage()) : null,
      );
    });
  }

  Widget _buildHardwareDecoderTile(BuildContext context, {required bool enabled}) {
    return Obx(() {
      return context.buildTile(
        icon: Remix.cpu_line,
        title: i18n('hardware_decoder'),
        subtitle: _getHardwareDecoderName(),
        trailing: const Icon(Remix.arrow_right_s_line),
        enabled: enabled,
        onTap: enabled ? () => Get.to(() => const DecoderSettingsPage()) : null,
      );
    });
  }

  Widget _buildRendererTile(BuildContext context, {required bool enabled}) {
    return Obx(() {
      return context.buildTile(
        icon: Remix.tv_line,
        title: i18n('video_output_driver'),
        subtitle: _getRendererName(),
        trailing: const Icon(Remix.arrow_right_s_line),
        enabled: enabled,
        onTap: enabled ? () => Get.to(() => const RendererSettingsPage()) : null,
      );
    });
  }

  Widget _buildAudioSection(BuildContext context) {
    return Obx(() {
      final customOutput = settings.player.customPlayerOutput.v;

      final compatMode = PlatformUtils.isAndroid && settings.player.playerCompatMode.v;

      final enabled = customOutput && !compatMode;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, icon: Remix.volume_up_line, title: i18n('audio_settings')),
          context.buildModernCard([
            if (PlatformUtils.isAndroid)
              context.buildSwitchTile(
                icon: Remix.equalizer_2_line,
                title: i18n('low_latency_audio'),
                subtitle: i18n('low_latency_audio_subtitle'),
                value: settings.player.androidEnableOpenSLES,
                enabled: enabled,
              ),
            context.buildTile(
              icon: Remix.volume_up_line,
              title: i18n('audio_output_driver'),
              subtitle: _getAudioOutputDriverName(),
              trailing: const Icon(Remix.arrow_right_s_line),
              enabled: enabled,
              onTap: enabled ? () => Get.to(() => const AudioOutputSettingsPage()) : null,
            ),
          ]),
        ],
      );
    });
  }

  Widget _buildPerformanceSection(BuildContext context) {
    return Obx(() {
      final metered = MeteredNetworkService.to.isMetered;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, icon: Remix.speed_up_line, title: i18n('performance_settings')),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Remix.database_2_line,
              title: i18n('low_memory_mode'),
              subtitle: metered ? i18n('low_memory_mode_metered') : i18n('low_memory_mode_subtitle'),
              value: settings.player.lowMemoryMode,
              enabled: !metered,
            ),
          ]),
        ],
      );
    });
  }

  Widget _buildAdvancedSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, icon: Remix.equalizer_line, title: i18n('mpv_advanced_settings')),
        context.buildModernCard([
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
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
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => settings.player.resetMpvPlayerSettings(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Remix.refresh_line, size: 15, color: Colors.red),
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
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.t16Bold.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  String _getAudioOutputDriverName() {
    final key = settings.player.audioOutputDriver.v;

    final item = PlayerConsts.audioOutputDriversList.firstWhere(
      (item) => item['key'] == key,
      orElse: () => PlayerConsts.audioOutputDriversList.first,
    );

    final isZh = Get.locale?.languageCode == 'zh';

    return isZh ? item['nameZh']! : item['nameEn']!;
  }

  String _getRendererName() {
    final key = settings.player.videoOutputDriver.v;

    final item = PlayerConsts.videoRenderersList.firstWhere(
      (item) => item['key'] == key,
      orElse: () => PlayerConsts.videoRenderersList.first,
    );

    final isZh = Get.locale?.languageCode == 'zh';

    return isZh ? item['nameZh']! : item['nameEn']!;
  }

  String _getHardwareDecoderName() {
    final key = settings.player.videoHardwareDecoder.v;

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
              final activeKey = settings.player.videoPlayerKey.v;

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

    settings.player.videoPlayerKey.v = key;

    GlobalPlayerService.instance.player.switchEngine(engine, isManual: true);

    Navigator.of(context).pop();
  }

  void showProxySettingsDialog() {
    final hostController = TextEditingController(text: settings.proxy.proxyHost.v);

    final portController = TextEditingController(text: settings.proxy.proxyPort.v.toString());

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
                    value: settings.proxy.enableProxy,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hostController,
                    enabled: settings.proxy.enableProxy.v,
                    decoration: InputDecoration(
                      labelText: i18n('proxy_host'),
                      prefixIcon: const Icon(Remix.global_line, size: 20),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (value) => settings.proxy.proxyHost.v = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: portController,
                    enabled: settings.proxy.enableProxy.v,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: i18n('proxy_port'),
                      prefixIcon: const Icon(Remix.links_line, size: 20),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (value) {
                      final port = int.tryParse(value);

                      if (port != null && port >= 1 && port <= 65535) {
                        settings.proxy.proxyPort.v = port;
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
