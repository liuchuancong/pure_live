import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/mpv_option_labels.dart';

/// Full-page picker for one mpv output/decoder option (layout after
/// liuchuancong/pure_live's decoder, renderer and audio pages).
class MpvOptionPage extends StatelessWidget {
  const MpvOptionPage({super.key, required this.kind, required this.title, required this.value});

  final MpvOptionKind kind;
  final String title;
  final RxString value;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final zh = Get.locale?.languageCode == 'zh';
    final options = mpvOptionsForPlatform(kind, platform, zh: zh);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildModernCard([
            Obx(() {
              final selected = normalizedMpvOption(kind, value.value, platform);
              return Column(
                children: [
                  for (final option in options)
                    InkWell(
                      onTap: () => value.value = option.key,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              option.key == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 22,
                              color: option.key == selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Text(option.label, style: AppTextStyles.t14)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
