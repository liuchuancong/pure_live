import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/danmaku/danmaku_format.dart';
import 'package:pure_live/shared/danmaku/danmaku_save_formats.dart';

/// The saved-danmaku formats as one multi-select table: a row per format,
/// checked while chosen, so the whole choice is seen and changed in one
/// place.
///
/// One section serves both pages that decide it — the danmaku page's look
/// tab and the recorder's file tab — because they edit the same choice: a
/// live recording's chat file and a downloaded video's sidecar are written
/// in these formats.
final class DanmakuSaveFormatsSection extends ConsumerWidget {
  /// The formats section.
  const DanmakuSaveFormatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final formats = ref.watch(danmakuSaveFormatsProvider);
    return DsListSection(
      header: Text(t.settings.danmakuSaveGroup),
      children: [
        DsTable<DanmakuFormat>(
          semanticLabel: t.settings.danmakuSaveGroup,
          rows: DanmakuFormat.values,
          rowKey: (format) => format,
          selected: formats,
          onSelectionChanged: (selection) =>
              unawaited(ref.read(danmakuSaveFormatsProvider.notifier).setAll(selection.cast<DanmakuFormat>().toSet())),
          columns: [
            DsTableColumn(id: 'format', label: t.settings.danmakuSaveFormats, value: (format) => format.label(t)),
            DsTableColumn(
              id: 'extension',
              label: t.settings.danmakuSaveExtension,
              value: (format) => '.${format.extension}',
              width: const DsTableColumnWidth.intrinsic(),
            ),
          ],
        ),
      ],
    );
  }
}
