import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';

class DesktopPaginationBar extends StatelessWidget {
  final BasePageScrollAndStateBone controller;
  final bool showSelector;
  final List<int> options;
  final _inputController = TextEditingController();

  DesktopPaginationBar({super.key, required this.controller, required this.showSelector, required this.options});

  void _executeJump(BuildContext context, int maxPage, bool isFixedMode) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final int? targetPage = int.tryParse(text);
    if (targetPage == null || targetPage < 1) return;
    if (isFixedMode && targetPage > maxPage) {
      controller.goToPage(maxPage);
    } else {
      controller.goToPage(targetPage);
    }
    _inputController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int current = controller.currentPage;
      final bool hasPrev = current > 1;
      final bool hasNext = controller.canLoadMore.value;
      final int? total = controller.totalCount.value;
      final int size = controller.pageSize.value;
      final int maxPage = total != null ? (total / size).ceil() : 0;

      List<Widget> pageNodes = [];
      pageNodes.add(_buildNumBlock(context, 1, current == 1));

      if (current > 3) {
        pageNodes.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: AppTextStyles.t13Muted),
          ),
        );
      }

      int start = current - 1;
      int end = current + 1;
      if (start <= 1) start = 2;
      if (total != null && end >= maxPage) end = maxPage - 1;

      for (int i = start; i <= end; i++) {
        if (total == null && !hasNext && i > current) break;
        if (i <= 1) continue;
        pageNodes.add(_buildNumBlock(context, i, current == i));
      }

      if (total != null && maxPage > 1) {
        if (end < maxPage - 1) {
          pageNodes.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("...", style: AppTextStyles.t13Muted),
            ),
          );
        }
        pageNodes.add(_buildNumBlock(context, maxPage, current == maxPage));
      } else if (total == null && hasNext) {
        pageNodes.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: AppTextStyles.t13Muted),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: controller.loadding ? null : () => controller.refreshData(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(i18n("refresh")),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: (hasPrev && !controller.loadding) ? () => controller.goToPage(current - 1) : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 12),
                  label: Text(i18n("prev_page")),
                ),
                const SizedBox(width: 8),
                ...pageNodes,
                const SizedBox(width: 8),
                TextButton(
                  onPressed: (hasNext && !controller.loadding) ? () => controller.goToPage(current + 1) : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(i18n("next_page")),
                      const SizedBox(width: 4),
                      if (controller.loadding)
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSelector) ...[
                  Text('${i18n("per_page")}: ', style: AppTextStyles.t13Muted),
                  const SizedBox(width: 6),
                  CompactPageSizeSelector(controller: controller, options: options),
                  const SizedBox(width: 24),
                ],
                Text(i18n("go_to"), style: AppTextStyles.t13Muted),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 50,
                    height: 30,
                    child: TextField(
                      controller: _inputController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppTextStyles.t13.copyWith(height: 1.2),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onSubmitted: (_) => _executeJump(context, maxPage, total != null),
                    ),
                  ),
                ),
                Text(i18n("page_unit"), style: AppTextStyles.t13Muted),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNumBlock(BuildContext context, int pageNum, bool isCurrent) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: (isCurrent || controller.loadding) ? null : () => controller.goToPage(pageNum),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          constraints: const BoxConstraints(minWidth: 32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isCurrent ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Text(
            "$pageNum",
            style: isCurrent
                ? AppTextStyles.t13Bold.copyWith(color: theme.colorScheme.onPrimary)
                : AppTextStyles.t13.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class CompactPageSizeSelector extends StatelessWidget {
  final BasePageScrollAndStateBone controller;
  final List<int> options;

  const CompactPageSizeSelector({super.key, required this.controller, required this.options});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int currentSize = options.contains(controller.pageSize.value) ? controller.pageSize.value : options.first;

      return PopupMenuButton<int>(
        initialValue: currentSize,
        tooltip: i18n("per_page"),
        position: PopupMenuPosition.under,
        offset: const Offset(0, 170),
        onSelected: (int newValue) {
          controller.setPageSize(newValue);
        },
        itemBuilder: (BuildContext context) {
          return options.map((int value) {
            return PopupMenuItem<int>(
              value: value,
              height: 36,
              child: Center(
                child: Text(
                  '$value',
                  style: currentSize == value
                      ? AppTextStyles.t13Bold.copyWith(color: Theme.of(context).colorScheme.primary)
                      : AppTextStyles.t13,
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$currentSize', style: AppTextStyles.t13),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: Theme.of(context).hintColor),
            ],
          ),
        ),
      );
    });
  }
}
