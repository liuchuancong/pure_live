import 'dart:io';

import 'package:pure_live/common/index.dart';

/// A matching guide: which preset and output picks fit which platform
/// and situation. Pure documentation — nothing here mutates settings.
class PlayerGuidePage extends StatelessWidget {
  const PlayerGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformName = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iOS'
        : Platform.isMacOS
        ? 'macOS'
        : Platform.isWindows
        ? 'Windows'
        : 'Linux';

    final sections = <(String, String)>[
      (
        '名词解释',
        [
          '硬解码开关：是否让显卡（硬件解码器）替 CPU 解码视频。关闭后走软解，CPU 占用高但兼容性最好。',
          '硬件解码器（--hwdec）：具体用哪种硬件解码路径；"auto" 交给 mpv 自己挑，列表里不再有"关闭"，因为那由上面的开关负责。',
          '视频输出（--vo）：mpv 把画面画到哪。libmpv 是 Flutter 纹理路径（默认），mediacodec_embed 是 Android 直通表面。',
          '音频输出（--ao）：mpv 把声音送到哪。audiotrack/aaudio/opensles 是 Android 的三种音频通道；null 表示不出声。',
        ].join('\n\n'),
      ),
      (
        '$platformName · 推荐搭配',
        _platformAdvice(),
      ),
      (
        '常见症状对照',
        [
          '花屏/绿屏/音画不同步（Android）→ 一键方案选 "Android 硬解兼容"。',
          '画面糊、屏幕高分而源只有 480P（Windows + NVIDIA）→ 选 "NVIDIA RTX 视频超分"。',
          '风扇狂转、掉帧（老机器/核显）→ 选 "低配流畅"，或关闭硬解码开关改走软解。',
          '频繁缓冲卡顿（跨网/弱网）→ 选 "弱网稳定"。',
          '直播延迟太高 → 选 "低延迟"，代价是更容易卡。',
        ].join('\n\n'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(i18n('player_guide_title'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final (title, body) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _platformAdvice() {
    if (Platform.isAndroid) {
      return '首选"标准（引擎默认）"；仅在默认路径出现花屏、绿屏、音画不同步时改用'
          '"Android 硬解兼容"（mediacodec_embed 直通表面 + 强制 mediacodec 硬解）。'
          '保持硬解码开关开启；硬件解码器留 auto。低端机器再叠加"低配流畅"。';
    }
    if (Platform.isWindows) {
      return 'NVIDIA 显卡且屏幕 ≥ 2K：选 "NVIDIA RTX 视频超分"（硬解码器会被方案锁定为 d3d11va，'
          '此时手动解码器选择不可用，这是预期行为）。AMD/Intel 显卡：选"标准（引擎默认）"，'
          '硬件解码器留 auto。老机器/核显：选"低配流畅"。';
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return '保持"标准（引擎默认）"即可：VideoToolbox 路径由引擎自动管理，'
          '不建议手动指定 --vo/--hwdec。iOS 上 mpv 的画面输出固定为 libmpv 纹理路径。';
    }
    return 'Linux 桌面：保持"标准（引擎默认）"，硬件解码器留 auto（VAAPI/VDPAU 由 mpv 自动挑选）。'
        '弱网环境叠加"弱网稳定"。';
  }
}
