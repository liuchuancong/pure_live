import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/core/common/proxy_routing.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/utils/mpv_platform_profile.dart';
import 'package:pure_live/modules/settings/pages/decoder_settings.dart';
import 'package:pure_live/modules/settings/pages/renderer_settings.dart';
import 'package:pure_live/modules/settings/pages/audio_output_settings_page.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';


class PlayerKernelSettingsPage extends GetView<SettingsService> {
  const PlayerKernelSettingsPage({super.key});
  SettingsService get settings => SettingsService.to;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availablePlayerKeys = availableVideoPlayerKeysForPlatform(defaultTargetPlatform);
    final canSwitchPlayer = availablePlayerKeys.length > 1;

    return Scaffold(
      appBar: AppBar(title: Text(i18n("player_kernel_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("core_kernel_settings")),
          context.buildModernCard([
            Obx(() {
              final activeKey = normalizeVideoPlayerKeyForPlatform(
                SettingsService.to.player.videoPlayerKey.v,
                defaultTargetPlatform,
              );
              String activeI18nKey = PlayerConsts.names[activeKey] ?? PlayerConsts.names[PlayerConsts.defaultKey]!;

              return context.buildTile(
                icon: Remix.toggle_line,
                title: i18n("kernel_switch"),
                subtitle: i18n(canSwitchPlayer ? "kernel_switch_subtitle" : "kernel_fixed_subtitle"),
                onTap: canSwitchPlayer ? showVideoSetDialog : null,
                trailing: Text(
                  i18n(activeI18nKey),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                stackTrailingOnNarrow: true,
              );
            }),
            Obx(() {
              final activeKey = normalizeVideoPlayerKeyForPlatform(
                SettingsService.to.player.videoPlayerKey.v,
                defaultTargetPlatform,
              );
              if (PlayerConsts.engines[activeKey] == PlayerEngine.exo) {
                return const SizedBox.shrink();
              }

              return context.buildTile(
                icon: Remix.global_line,
                title: i18n("network_proxy"),
                subtitle: i18n("network_proxy_subtitle"),
                onTap: showProxySettingsDialog,
                trailing: Text(
                  SettingsService.to.proxy.enableProxy.v ? i18n("enabled") : i18n("disabled"),
                  style: AppTextStyles.t13.copyWith(
                    color: SettingsService.to.proxy.enableProxy.v ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                stackTrailingOnNarrow: true,
              );
            }),
            context.buildSwitchTile(
              icon: Remix.speed_up_line,
              title: i18n('enable_codec'),
              subtitle: i18n("gpu_decode"),
              value: SettingsService.to.player.enableCodec,
            ),
            if (PlatformUtils.isWindows)
              context.buildSwitchTile(
                icon: Remix.image_edit_line,
                title: i18n('enable_rtx_vsr'),
                subtitle: i18n('enable_rtx_vsr_subtitle'),
                value: SettingsService.to.player.enableRtxVsr,
              ),
            context.buildSwitchTile(
              icon: Remix.shut_down_line,
              title: i18n('force_destroy_player'),
              subtitle: i18n('force_destroy_player_subtitle'),
              value: SettingsService.to.player.useHardStopOnExit,
            ),
          ]),
          Obx(() {
            final activeKey = normalizeVideoPlayerKeyForPlatform(
              SettingsService.to.player.videoPlayerKey.v,
              defaultTargetPlatform,
            );
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

  Widget _buildMpvSettings(BuildContext context) {
    final theme = Theme.of(context);
    final platform = defaultTargetPlatform;
    final videoOutputDrivers = mpvVideoOutputDriversForPlatform(platform);
    final audioOutputDrivers = mpvAudioOutputDriversForPlatform(platform);
    final hardwareDecoders = mpvHardwareDecodersForPlatform(platform);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: 0, top: 12), child: Divider()),
        if (Platform.isAndroid)
          context.buildSwitchTile(
            icon: Remix.shield_check_line,
            title: i18n('compat_mode'),
            subtitle: i18n('compat_mode_subtitle'),
            value: SettingsService.to.player.playerCompatMode,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
          child: Row(
            children: [
              Icon(Remix.equalizer_line, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n("mpv_advanced_settings"),
                  style: AppTextStyles.t16Bold.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: _buildMpvWarningAndReset(context, theme),
        ),
        context.buildModernCard([
          context.buildSwitchTile(
            icon: Remix.code_box_line,
            title: i18n("custom_output_hwdec"),
            value: SettingsService.to.player.customPlayerOutput,
          ),

          Obx(() => _buildHardwareDecoderTile(context)),
          Obx(() => _buildRendererTile(context)),
          Obx(() => _buildAudioSection(context)),
        ]),
      ],
    );
  }

  Widget _buildHardwareDecoderTile(BuildContext context) {
    return context.buildTile(
      icon: Remix.cpu_line,
      title: i18n('hardware_decoder'),
      subtitle: _getHardwareDecoderName(),
      trailing: const Icon(Remix.arrow_right_s_line),
      onTap: () => Get.to(() => const DecoderSettingsPage()),
    );
  }

  Widget _buildRendererTile(BuildContext context) {
    return context.buildTile(
      icon: Remix.tv_line,
      title: i18n('video_output_driver'),
      subtitle: _getRendererName(),
      trailing: const Icon(Remix.arrow_right_s_line),
      onTap: () => Get.to(() => const RendererSettingsPage()),
    );
  }

  Widget _buildAudioSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        context.buildGroupTitle(i18n('audio_settings')),
        context.buildModernCard([
          context.buildTile(
            icon: Remix.volume_up_line,
            title: i18n('audio_output_driver'),
            subtitle: _getAudioOutputDriverName(),
            trailing: const Icon(Remix.arrow_right_s_line),
            onTap: () => Get.to(() => const AudioOutputSettingsPage()),
          ),
        ]),
      ],
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

  Widget _buildMpvWarningAndReset(BuildContext context, ThemeData theme) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('mpv_advanced_settings')),
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

  // 播放器选择弹窗
  void showVideoSetDialog() {
    final playerKeys = availableVideoPlayerKeysForPlatform(defaultTargetPlatform);
    if (playerKeys.length <= 1) return;

    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("change_player")),
          children: [
            Obx(() {
              final activeKey = normalizeVideoPlayerKeyForPlatform(
                SettingsService.to.player.videoPlayerKey.v,
                defaultTargetPlatform,
              );

              return RadioGroup<String>(
                groupValue: activeKey,
                onChanged: (String? key) {
                  if (key != null && PlayerConsts.engines.containsKey(key)) {
                    SettingsService.to.player.videoPlayerKey.v = key;
                    GlobalPlayerService.instance.player.switchEngine(PlayerConsts.engines[key]!, isManual: true);
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: playerKeys.map<Widget>((itemKey) {
                    final i18nKey = PlayerConsts.names[itemKey]!;
                    return ListTile(
                      leading: Radio<String>(value: itemKey, activeColor: Theme.of(context).colorScheme.primary),
                      title: Text(i18n(i18nKey), style: AppTextStyles.t15),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      onTap: () {
                        if (PlayerConsts.engines.containsKey(itemKey)) {
                          SettingsService.to.player.videoPlayerKey.v = itemKey;
                          GlobalPlayerService.instance.player.switchEngine(
                            PlayerConsts.engines[itemKey]!,
                            isManual: true,
                          );
                          Navigator.of(context).pop();
                        }
                      },
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

  // 代理设置弹窗（替换为统一SwitchTile）
  void showProxySettingsDialog() {
    showDialog(context: Get.context!, builder: (context) => const _PlayerProxySettingsDialog());
  }
}

final TextInputFormatter _playerProxyHostInputFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  final normalized = normalizeProxyHost(newValue.text);
  if (normalized == newValue.text) return newValue;
  return TextEditingValue(
    text: normalized,
    selection: TextSelection.collapsed(offset: normalized.length),
    composing: TextRange.empty,
  );
});

class _PlayerProxySettingsDialog extends StatefulWidget {
  const _PlayerProxySettingsDialog();

  @override
  State<_PlayerProxySettingsDialog> createState() => _PlayerProxySettingsDialogState();
}

class _PlayerProxySettingsDialogState extends State<_PlayerProxySettingsDialog> {
  final proxy = SettingsService.to.proxy;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _portInvalid = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: proxy.proxyHost.v);
    _portController = TextEditingController(text: proxy.proxyPort.v.toString());
    _portInvalid = parseProxyPortInput(_portController.text) == null;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _updatePort(String rawValue) {
    final port = parseProxyPortInput(rawValue);
    final invalid = port == null;
    if (_portInvalid != invalid) setState(() => _portInvalid = invalid);
    if (port != null) proxy.proxyPort.v = port;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(i18n("proxy_settings")),
      content: Obx(
        () => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            context.buildSwitchTile(
              icon: Remix.shield_keyhole_line,
              title: i18n("enable_player_proxy"),
              value: proxy.enableProxy,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('player-proxy-dialog-host'),
              controller: _hostController,
              enabled: proxy.enableProxy.v,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [_playerProxyHostInputFormatter],
              decoration: InputDecoration(
                labelText: i18n("proxy_host"),
                prefixIcon: const Icon(Remix.global_line, size: 20),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              onChanged: (value) => proxy.proxyHost.v = normalizeProxyHost(value),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('player-proxy-dialog-port'),
              controller: _portController,
              enabled: proxy.enableProxy.v,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: i18n("proxy_port"),
                prefixIcon: const Icon(Remix.links_line, size: 20),
                errorText: _portInvalid ? i18n('proxy_port_invalid') : null,
                errorMaxLines: 3,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              onChanged: _updatePort,
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n("confirm")))],
    );
  }
}
