import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';

import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/images.dart' show cachedImage;
import 'package:pure_live/shared/utils/utils.dart' show avatarInitials;
import 'package:pure_live/shared/widgets/app_panel.dart';

/// One download task as its own detail sheet shows it.
///
/// The three managers (哔哩哔哩, 红果, 音乐) keep their own task models, but a
/// task answers the same questions everywhere: what it is, where it stands,
/// what it wrote where, and what went wrong. Each page maps its row onto this
/// value and the sheet is one implementation, so the three read alike.
final class DownloadDetails {
  /// The sheet's content.
  const DownloadDetails({
    required this.title,
    this.part = '',
    this.coverUrl = '',
    this.status = '',
    this.savePath = '',
    this.queuedAt = '',
    this.retries = 0,
    this.error = '',
    this.fileMissing = false,
    this.onOpenFile,
    this.onOpenFolder,
    this.onRemove,
  });

  /// The file's name, as its row says it.
  final String title;

  /// The part this file belongs to, when it is one of several.
  final String part;

  /// The poster the task kept, if any.
  final String coverUrl;

  /// The phase and the running facts — progress, size, speed, time left —
  /// in one line, as the row states them.
  final String status;

  /// The finished file's path (or where it will land).
  final String savePath;

  /// When the task was queued, in words.
  final String queuedAt;

  /// How many automatic retries this task has used; zero hides the row.
  final int retries;

  /// What failed, when it did.
  final String error;

  /// Whether the file this row names is gone from disk. The sheet says it in
  /// its own words rather than leaving 已完成 as the whole truth: the row is a
  /// record, and the viewer can move the file out from under it.
  final bool fileMissing;

  /// Opens the finished file; null when there is nothing to open yet.
  final VoidCallback? onOpenFile;

  /// Opens the file's folder; null when the task has no path.
  final VoidCallback? onOpenFolder;

  /// Takes the record out of the queue — the one action a row whose file is
  /// gone still has. Null when the caller offers it elsewhere.
  final VoidCallback? onRemove;
}

/// Shows [details] in a panel — the download rows' 详情 verb.
Future<void> showDownloadDetails(BuildContext context, DownloadDetails details) {
  return showAppPanel<void>(
    context: context,
    builder: (context) => AppPanel(
      title: Text(context.t.common.downloadDetails),
      scrollable: false,
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * 0.62).clamp(360.0, 640.0),
        child: DownloadDetailsBody(details: details),
      ),
    ),
  );
}

/// The sheet's content, also used inline by a manager's wide workspace —
/// the same facts whether they sit in a panel or beside the list.
final class DownloadDetailsBody extends StatelessWidget {
  /// The body for [details].
  const DownloadDetailsBody({required this.details, super.key});

  final DownloadDetails details;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final cover = details.coverUrl.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, 0, DsSpace.s16, DsSpace.s16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s12,
          children: [
            DsAvatar(
              initials: avatarInitials(details.title),
              image: cover.isEmpty ? null : cachedImage(cover, policy: ImageCachePolicies.videoCover),
              size: DsSize.lg,
              semanticLabel: details.title,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s4,
                children: [
                  Text(
                    details.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.title.copyWith(color: colors.text),
                  ),
                  if (details.part.trim().isNotEmpty)
                    Text(
                      details.part,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.s16),
        DsListSection(
          children: [
            if (details.status.isNotEmpty)
              DsListRow(
                title: Text(t.common.downloadStatus),
                detail: Text(details.status, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ),
            if (details.queuedAt.isNotEmpty)
              DsListRow(
                title: Text(t.common.downloadQueuedAt),
                detail: Text(details.queuedAt, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ),
            if (details.retries > 0)
              DsListRow(
                title: Text(t.common.downloadRetried),
                detail: Text(
                  t.common.downloadRetriedTimes(count: details.retries),
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            if (details.savePath.isNotEmpty)
              DsListRow(
                title: Text(t.common.downloadSavePath),
                description: Text(
                  details.savePath,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
                trailing: DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.settings.logCopyPath,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: details.savePath));
                    if (context.mounted) {
                      showDsToast(context: context, title: t.common.copied);
                    }
                  },
                  icon: const DsIcon(DsIcons.copy, size: 16),
                ),
              ),
          ],
        ),
        if (details.error.trim().isNotEmpty) ...[
          const SizedBox(height: DsSpace.s12),
          DsAlert(
            status: DsStatus.danger,
            title: Text(t.common.downloadError),
            description: Text(details.error.trim()),
          ),
        ],
        // The file's own fact, said apart from the phase's: 已完成 is true of
        // the transfer and says nothing about the disk. A row the viewer moved
        // or deleted by hand otherwise reads as a lie until 打开文件 fails.
        if (details.fileMissing) ...[
          const SizedBox(height: DsSpace.s12),
          DsAlert(
            status: DsStatus.warning,
            title: Text(t.common.previewFileMissing),
            description: Text(t.common.downloadFileMissingBody),
          ),
        ],
        if (details.onOpenFile != null || details.onOpenFolder != null || details.onRemove != null) ...[
          const SizedBox(height: DsSpace.s16),
          // A wrap, not a row: the two labels are long words in a small
          // sheet, and a narrow window stacks them instead of ellipsising.
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              if (details.onOpenFile case final open?)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.externalLink, size: 14),
                  onPressed: open,
                  child: Text(t.settings.downloadOpenFile),
                ),
              if (details.onOpenFolder case final folder?)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.folderOpen, size: 14),
                  onPressed: folder,
                  child: Text(t.settings.downloadManagerOpenFolder),
                ),
              if (details.onRemove case final remove?)
                DsButton(
                  variant: DsButtonVariant.dangerSoft,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.trash2, size: 14),
                  onPressed: remove,
                  child: Text(t.settings.downloadRemove),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
