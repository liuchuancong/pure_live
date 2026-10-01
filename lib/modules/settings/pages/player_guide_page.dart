import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pure_live/common/index.dart';

/// The player manual: concepts, every setting and what it does, organized
/// in collapsible chapters. Pure documentation — nothing here mutates state.
class PlayerGuidePage extends StatefulWidget {
  const PlayerGuidePage({super.key});

  @override
  State<PlayerGuidePage> createState() => _PlayerGuidePageState();
}

class _GuideEntry {
  const _GuideEntry(this.key, this.zh, this.en, {this.badge});

  /// mpv option / switch name shown in a monospace chip; empty for prose rows.
  final String key;
  final String zh;
  final String en;
  final String? badge;

  String text(bool zh) => zh ? this.zh : en;
}

class _GuideChapter {
  const _GuideChapter(this.icon, this.titleZh, this.titleEn, this.entries);

  final IconData icon;
  final String titleZh;
  final String titleEn;
  final List<_GuideEntry> entries;

  String title(bool zh) => zh ? titleZh : titleEn;
}

class _PlayerGuidePageState extends State<PlayerGuidePage> {
  bool get _zh => Get.locale?.languageCode != 'en';

  List<_GuideChapter> get _chapters {
    final android = Platform.isAndroid;
    final windows = Platform.isWindows;

    return [
      _GuideChapter(Icons.school_rounded, '基础概念', 'Core concepts', [
        _GuideEntry(
          '硬解码开关',
          '让显卡代替 CPU 解码视频。开启后 CPU 占用低、发热小；关闭则走软解，兼容性最好，老机器反而更流畅。',
          'Let the GPU decode video instead of the CPU. Lower usage and heat when on; software decoding is the most compatible fallback.',
        ),
        _GuideEntry(
          '--hwdec',
          '具体用哪种硬解路径。auto 全部尝试（个别机型可能花屏）；auto-safe 只用白名单内的安全路径（推荐）；带 -copy 的变体把解码结果拷回内存，滤镜和截图需要它。',
          'Which hardware decode path to use. auto tries everything (may glitch on some SoCs); auto-safe only whitelisted paths (recommended); -copy variants decode back into memory, needed by some filters and screenshots.',
          badge: 'hwdec',
        ),
        _GuideEntry(
          '--vo',
          'mpv 把画面画到哪里。libmpv 画进 Flutter 纹理（内嵌播放器，默认）；gpu/gpu-next/direct3d 会打开一个独立的 mpv 原生窗口（不在应用画面内）；null 不渲染画面。',
          'Where mpv draws the picture. libmpv renders into the Flutter texture (embedded, default); gpu/gpu-next/direct3d open a standalone mpv window (outside the app); null renders nothing.',
          badge: 'vo',
        ),
        _GuideEntry(
          '--ao',
          'mpv 把声音送到哪个系统通道。Windows 用 wasapi，Android 用 audiotrack/aaudio/opensles；null 表示静音。',
          'Which system channel carries the sound. Windows: wasapi; Android: audiotrack/aaudio/opensles; null mutes.',
          badge: 'ao',
        ),
      ]),
      _GuideChapter(Icons.auto_fix_high_rounded, '一键播放方案', 'One-click presets', [
        _GuideEntry(
          '标准（引擎默认）',
          '全部交给 mpv 自己决定，只附加直播所需的解复用与缓存调优。大多数设备和网络的首选。',
          'Everything left to mpv, plus the live-stream demuxer/cache tuning. The first choice on most devices.',
        ),
        _GuideEntry(
          'Android 硬解兼容',
          '仅 Android。改用 mediacodec_embed 直通表面并强制 mediacodec 硬解，花屏/绿屏/音画不同步时使用。',
          'Android only: mediacodec_embed surface + forced mediacodec decode, for glitch/green-screen/AV-desync devices.',
          badge: android ? null : 'Android',
        ),
        _GuideEntry(
          'NVIDIA RTX 视频超分',
          '仅 Windows + NVIDIA。d3d11va 硬解并叠加 RTX Video Super Resolution 滤镜，把低清源放大观看。会锁定硬件解码器为 d3d11va。',
          'Windows + NVIDIA only: d3d11va decode plus the RTX Video Super Resolution filter. Locks the decoder to d3d11va.',
          badge: windows ? null : 'Windows',
        ),
        _GuideEntry(
          '低配流畅',
          '软解 + 线程上限 2 + lowres 降采样 + 小缓冲。CPU 让给画面本身，核显/老机器用。',
          'Software decode with capped threads, lowres and a small buffer. For weak CPUs and iGPUs.',
        ),
        _GuideEntry(
          '弱网稳定',
          '加大缓冲与预读、开启重连退避。用内存换卡顿，跨网/信号边缘时使用。',
          'Bigger buffers and reconnect backoff. Trades memory for fewer stalls.',
        ),
        _GuideEntry(
          '低延迟',
          '最小缓冲 + 双端丢帧。时效优先，代价是更容易卡。',
          'Minimum buffering + frame dropping. Lowest delay, more hiccups.',
        ),
      ]),
      _GuideChapter(Icons.tune_rounded, '画面与同步', 'Picture & sync', [
        _GuideEntry(
          '--video-sync',
          '音画时钟对齐方式。audio 是 mpv 默认；display-resample 最平滑但吃 GPU，配合运动插帧使用；带 vdrop/drop 的变体在节奏对不上时丢帧。',
          'How audio and video clocks align. audio is the mpv default; display-resample is smoothest but GPU heavy and pairs with interpolation; vdrop/drop variants drop frames on drift.',
          badge: 'vo',
        ),
        _GuideEntry(
          '--interpolation',
          '运动插帧。平移画面时按帧间计算补帧，显著更顺滑；必须配合 display-resample 同步模式，GPU 消耗明显。',
          'Motion-interpolated rendering. Noticeably smoother pans; requires display-resample sync and real GPU headroom.',
        ),
        _GuideEntry(
          '--scale',
          '画面放大算法。lanczos 均衡推荐；ewa_lanczossharp 最锐利；ewa_lanczos4sharpest 专为插帧设计；bilinear/nearest 最快但糊/块状。',
          'Upscaling kernel. lanczos is the balanced pick; ewa_lanczossharp the sharpest; ewa_lanczos4sharpest is designed for interpolation; bilinear/nearest are fastest.',
        ),
        _GuideEntry(
          '--deinterlace',
          '反交错处理。直播源基本都是逐行的，保持自动即可；只有老电视信号/采集卡源才需要开启。',
          'Deinterlacing. Modern streams are progressive — leave on auto; only legacy TV/capture sources need yes.',
        ),
      ]),
      _GuideChapter(Icons.hd_rounded, '画质增强', 'Quality enhancement', [
        _GuideEntry(
          'RTX 超分辨率',
          '设置 - 播放器内核 - 超分辨率。三档：效率档（轻量 CNN）/ 质量档（完整 CNN）。仅 Windows 桌面 GPU 能实时运行；效果是把 480P 源放大到高分屏仍然清晰。',
          'Settings - Player kernel - Super resolution. Efficiency / quality Anime4K chains. Desktop GPUs only; upscales 480P sources on high-DPI screens.',
        ),
        _GuideEntry(
          '同屏最大弹幕条数',
          '弹幕设置里限制同屏弹幕数量。低配设备调低可显著减负。',
          'Caps simultaneous danmaku. Lower it on weak devices to cut load.',
        ),
        _GuideEntry(
          '--hwdec-codecs',
          '限制哪些编码格式走硬解。Android 上默认 h264,hevc 已覆盖绝大多数直播间；某编码黑屏时可把它从列表移除（回退软解）。',
          'Which codecs hardware-decode. Android default h264,hevc covers most rooms; drop a codec from the list to software-fallback it.',
          badge: 'hwdec',
        ),
      ]),
      _GuideChapter(Icons.volume_up_rounded, '声音', 'Audio', [
        _GuideEntry(
          '--audio-exclusive',
          '仅 Windows。独占 WASAPI 设备，绕过系统混音器，可能有更好的音质；代价是其他应用无法出声。',
          'Windows only. Claims the WASAPI device exclusively — possibly cleaner output, but other apps go silent.',
        ),
        _GuideEntry(
          '--ao 选择建议',
          '不确定就用 auto。声音断续时 Windows 换 win32，Android 换 opensles；蓝牙耳机延迟大时可尝试不同通道对比。',
          'When unsure use auto. On stutter: win32 (Windows) or opensles (Android); compare channels for Bluetooth latency.',
          badge: 'ao',
        ),
      ]),
      _GuideChapter(Icons.healing_rounded, '症状对照', 'Symptom table', [
        _GuideEntry(
          '花屏 / 绿屏 / 音画不同步',
          'Android：一键方案切 "Android 硬解兼容"。其它平台：硬件解码器改 auto-safe，或关闭硬解开关走软解。',
          'Android: switch to the compat preset. Elsewhere: set hwdec to auto-safe or turn hardware decoding off.',
        ),
        _GuideEntry(
          '低清源在高分屏发糊',
          'Windows + NVIDIA：选 "NVIDIA RTX 视频超分"；其它 GPU：放大算法改 ewa_lanczossharp（GPU 够强时）。',
          'Windows + NVIDIA: use the RTX preset. Other GPUs: switch the scale kernel to ewa_lanczossharp if the GPU allows.',
        ),
        _GuideEntry(
          '风扇狂转 / 掉帧',
          '选 "低配流畅" 方案；仍不行就关闭硬解码开关（老设备软解反而快）。',
          'Use the low-end preset; if that fails, turn hardware decoding off (old devices can software-decode faster).',
        ),
        _GuideEntry(
          '频繁缓冲',
          '选 "弱网稳定"；同时检查代理设置——代理是直播卡顿的常见来源。',
          'Use the stable-network preset; also check proxy settings — a proxy is a common stall source.',
        ),
        _GuideEntry(
          '延迟高（连麦/赛事情景）',
          '选 "低延迟" 方案，并调低缓冲相关属性。',
          'Use the low-latency preset and shrink buffering properties.',
        ),
        _GuideEntry(
          '有声音没画面',
          '检查视频输出驱动是否被改过（null = 不渲染画面）；恢复 "自动" 即可。恢复出厂设置也能解决。',
          'Check the video output driver: null renders nothing. Reset it to auto, or use the factory reset.',
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapters = _chapters;

    return Scaffold(
      appBar: AppBar(title: Text(_zh ? '播放指南' : 'Player Guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_zh ? '这本手册怎么用' : 'How to use this manual', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    _zh
                        ? '遇到问题先看「症状对照」；想理解某个设置是什么，在「基础概念」和各章里查。'
                        : 'Start from the symptom table; look up any setting in the glossary chapter.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < chapters.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: PageStorageKey('guide-' + i.toString()),
                initiallyExpanded: i == 0,
                leading: Icon(chapters[i].icon, color: theme.colorScheme.primary),
                title: Text(chapters[i].title(_zh), style: theme.textTheme.titleMedium),
                subtitle: Text(
                  i18n('player_guide_entries', args: {'count': chapters[i].entries.length.toString()}),
                  style: theme.textTheme.bodySmall,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  const Divider(height: 1),
                  for (final entry in chapters[i].entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (entry.key.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                )
                              else
                                Text(entry.text(_zh), style: theme.textTheme.titleSmall),
                              if (entry.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    entry.badge!,
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ),
                            ],
                          ),
                          if (entry.key.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(entry.text(_zh), style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
