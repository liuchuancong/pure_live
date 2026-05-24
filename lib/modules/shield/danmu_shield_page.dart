import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/shield/danmu_shield_controller.dart';

class DanmuShieldPage extends GetView<DanmuShieldController> {
  const DanmuShieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("danmaku_keyword_block"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          TextField(
            keyboardType: TextInputType.text,
            controller: controller.textEditingController,
            decoration: InputDecoration(
              hintText: i18n('please_input_keyword'),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: controller.add,
                  icon: const Icon(Remix.add_line, size: 18),
                  label: Text(i18n('add'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            onSubmitted: (_) => controller.add(),
          ),
          const SizedBox(height: 24),
          Obx(() {
            final count = controller.settingsController.shieldList.length;
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                i18n("shield_count_title", args: {"count": "$count"}),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
          Obx(() {
            final list = controller.settingsController.shieldList;

            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyView(
                  icon: Remix.discuss_line,
                  title: i18n("empty_shield_title"),
                  subtitle: i18n("empty_shield_subtitle"),
                ),
              );
            }

            return Wrap(
              runSpacing: 10,
              spacing: 10,
              children: list.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => controller.remove(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          Icon(Remix.close_line, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}
