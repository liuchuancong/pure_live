import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// Where a download task stands, as every manager's row says it. The
/// managers' engines name their phases differently; this is the one reading
/// every queue on screen draws.
enum DownloadRowPhase {
  /// Bytes moving.
  running,

  /// Waiting its turn.
  queued,

  /// Held by the viewer.
  paused,

  /// The engine is finishing what it wrote (tags, merges).
  processing,

  /// The transfer gave up and may be tried again.
  failed,

  /// Stopped by the viewer; only the record remains to remove.
  cancelled,

  /// The file landed and plays.
  done,

  /// The record says done, but the file is gone from the disk.
  missing,
}

/// The one badge a task's state wears: the colour the phase reads as and the
/// words it says. [label] overrides the phase's own words — a running task
/// counts its percent, a task's row may carry its engine's own nuance.
DsBadge downloadRowBadge(BuildContext context, DownloadRowPhase phase, {String? label}) {
  final t = context.t;
  return DsBadge(
    status: switch (phase) {
      DownloadRowPhase.running => DsStatus.info,
      DownloadRowPhase.queued => DsStatus.neutral,
      DownloadRowPhase.paused => DsStatus.warning,
      DownloadRowPhase.processing => DsStatus.info,
      DownloadRowPhase.failed => DsStatus.danger,
      DownloadRowPhase.cancelled => DsStatus.neutral,
      DownloadRowPhase.done => DsStatus.success,
      DownloadRowPhase.missing => DsStatus.danger,
    },
    label: Text(
      label ??
          switch (phase) {
            DownloadRowPhase.running => t.settings.downloadStatusRunning,
            DownloadRowPhase.queued => t.settings.downloadStatusQueued,
            DownloadRowPhase.paused => t.settings.downloadStatusPaused,
            DownloadRowPhase.processing => t.settings.downloadStatusProcessing,
            DownloadRowPhase.failed => t.settings.downloadStatusFailed,
            DownloadRowPhase.cancelled => t.settings.downloadStatusCancelled,
            DownloadRowPhase.done => t.settings.downloadStatusDone,
            DownloadRowPhase.missing => t.common.previewFileMissing,
          },
    ),
  );
}

/// The verbs a row's state allows, handed in by the manager that owns the
/// task: the shared row draws the one that answers the phase, every queue
/// pressing the same glyph for the same state.
final class DownloadRowActions {
  /// The verbs a row can offer; null keeps a verb out.
  const DownloadRowActions({
    this.onPause,
    this.onResume,
    this.onRetry,
    this.onPlay,
    this.onOpenFile,
    this.onCancel,
    this.onRemove,
  });

  /// Stops a moving or waiting transfer.
  final VoidCallback? onPause;

  /// Carries a held transfer on.
  final VoidCallback? onResume;

  /// Fetches a failed transfer again.
  final VoidCallback? onRetry;

  /// Plays the file that landed.
  final VoidCallback? onPlay;

  /// Hands the finished file to the system — the manager whose queue has no
  /// in-app player says 打开文件 where another says 播放.
  final VoidCallback? onOpenFile;

  /// Stops a transfer the engine is still finishing.
  final VoidCallback? onCancel;

  /// Takes the record out of the queue.
  final VoidCallback? onRemove;
}

/// The one verb the row's end carries, drawn for [phase] out of [actions]:
/// pause or carry on a transfer, fetch a failed one again, play the file
/// that landed, or take a finished-with task out. A playable task whose file
/// is gone keeps its place, names the fact and stays out of reach.
Widget downloadRowVerb(
  BuildContext context,
  DownloadRowPhase phase,
  DownloadRowActions actions, {
  bool playable = false,
}) {
  final t = context.t;
  Widget icon(String label, DsIconData glyph, VoidCallback? onPressed) => DsButton.icon(
    variant: DsButtonVariant.secondary,
    size: DsSize.sm,
    semanticLabel: label,
    onPressed: onPressed,
    icon: DsIcon(glyph, size: 16),
  );
  if (phase == DownloadRowPhase.missing) {
    return icon(t.common.previewFileMissing, DsIcons.fileX, null);
  }
  if (playable) {
    return icon(t.settings.downloadPlay, DsIcons.play, actions.onPlay);
  }
  // A queue without its own player hands the file to the system instead.
  if (phase == DownloadRowPhase.done && actions.onOpenFile != null) {
    return icon(t.settings.downloadOpenFile, DsIcons.externalLink, actions.onOpenFile);
  }
  return switch (phase) {
    DownloadRowPhase.running ||
    DownloadRowPhase.queued => icon(t.settings.downloadPause, DsIcons.pause, actions.onPause),
    DownloadRowPhase.paused => icon(t.settings.downloadResume, DsIcons.play, actions.onResume),
    DownloadRowPhase.failed => icon(t.common.retry, DsIcons.refreshCw, actions.onRetry),
    DownloadRowPhase.processing => icon(t.common.cancel, DsIcons.x, actions.onCancel),
    _ => icon(t.settings.downloadRemove, DsIcons.trash2, actions.onRemove),
  };
}

/// The row menu's verbs, handed in by the manager: the facts first, then the
/// file's own three, then the record's removal — whose words change when the
/// file it names is gone, because then there is nothing to delete and only
/// the list entry to take out.
final class DownloadRowMenuActions {
  /// The menu's verbs; null keeps its row out of the menu.
  const DownloadRowMenuActions({
    required this.onDetails,
    required this.onRemove,
    this.onOpenFile,
    this.onOpenFolder,
    this.onDeleteFile,
    this.onMenuCancel,
    this.missing = false,
  });

  /// Opens the task's facts panel.
  final VoidCallback onDetails;

  /// Hands the finished file to the system.
  final VoidCallback? onOpenFile;

  /// Opens the folder the file landed in.
  final VoidCallback? onOpenFolder;

  /// Deletes the file and keeps the record.
  final VoidCallback? onDeleteFile;

  /// Takes the record out of the queue.
  final VoidCallback onRemove;

  /// Drops a transfer still owed a file; null keeps the row out.
  final VoidCallback? onMenuCancel;

  /// Whether the file the record names is gone from the disk.
  final bool missing;
}

/// The row's own ⋯ menu — the same menu on every queue, in the same order.
List<Widget> downloadRowMenu(BuildContext context, DownloadRowMenuActions actions) {
  final t = context.t;
  return [
    DsMenuItem(
      leading: const DsIcon(DsIcons.info),
      label: Text(t.common.downloadDetails),
      onPressed: actions.onDetails,
    ),
    if (actions.onMenuCancel != null)
      DsMenuItem(leading: const DsIcon(DsIcons.x), label: Text(t.common.cancel), onPressed: actions.onMenuCancel),
    const DsMenuDivider(),
    if (!actions.missing) ...[
      if (actions.onOpenFile != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.play),
          label: Text(t.settings.downloadOpenFile),
          onPressed: actions.onOpenFile,
        ),
      if (actions.onOpenFolder != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.folder),
          label: Text(t.settings.downloadOpenFolder),
          onPressed: actions.onOpenFolder,
        ),
      if (actions.onDeleteFile != null)
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.settings.downloadDeleteFile),
          destructive: true,
          onPressed: actions.onDeleteFile,
        ),
      const DsMenuDivider(),
    ],
    DsMenuItem(
      leading: const DsIcon(DsIcons.trash2),
      label: Text(actions.missing ? t.common.downloadRemoveFromList : t.settings.downloadRemove),
      destructive: true,
      onPressed: actions.onRemove,
    ),
  ];
}

/// How long a moving task still asks for, in the one format every queue
/// prints: minutes and seconds under an hour, hours and minutes over it; an
/// unknown speed says nothing rather than `--:--`.
String downloadEtaText(Duration eta) {
  final minutes = eta.inMinutes;
  if (minutes >= 60) return '${eta.inHours}h ${minutes % 60}m';
  if (minutes >= 1) return '${minutes}m ${eta.inSeconds % 60}s';
  return '${eta.inSeconds}s';
}

/// One download task's row — the shape every manager's queue wears: the task
/// at the head, its state as a badge beside the rendition it plays at, the
/// facts it can state under that, its progress as a line while it moves, and
/// at the end the one verb its state allows beside the menu with the rest.
/// Every queue on screen pressing this one shape is what makes the app's
/// download pages read as one surface.
final class DownloadTaskCard extends StatelessWidget {
  /// The row for [title], standing at [phase], stating [caption].
  const DownloadTaskCard({
    required this.title,
    required this.phase,
    required this.caption,
    this.leading,
    this.meta,
    this.badgeLabel,
    this.fraction,
    this.showProgress = false,
    this.progressLabel,
    this.actions,
    this.playable = false,
    this.menu,
    super.key,
  });

  /// The task's own name, one line.
  final String title;

  /// Where the task stands.
  final DownloadRowPhase phase;

  /// The facts the row states — speed, bytes, the wait before a retry, the
  /// error. Two lines: a failed row must not lose its second half.
  final String caption;

  /// The cover at the row's head; null when a block header above already
  /// names the artwork.
  final Widget? leading;

  /// The rendition or quality the task plays at, beside the badge.
  final String? meta;

  /// Overrides the badge's words — a running task counts its percent.
  final String? badgeLabel;

  /// How far the transfer has got, 0–1.
  final double? fraction;

  /// Whether the progress line draws (a moving task's).
  final bool showProgress;

  /// The progress line's own name, for screen readers; defaults to [title].
  final String? progressLabel;

  /// The row-end verb; null keeps the end quiet.
  final DownloadRowActions? actions;

  /// Whether the file plays (a finished task whose file is on the disk).
  final bool playable;

  /// The row's ⋯ menu; null keeps the glyph off.
  final DownloadRowMenuActions? menu;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final captionColor = switch (phase) {
      DownloadRowPhase.failed || DownloadRowPhase.missing => colors.danger.text,
      _ => colors.textMuted,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s6,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _phaseSignal(colors), shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.text),
                ),
              ),
              if (actions != null) downloadRowVerb(context, phase, actions!, playable: playable),
              if (menu != null)
                DsMenuAnchor(
                  semanticLabel: t.common.more,
                  align: DsAlign.end,
                  builder: (context, controller, child) => DsPressable(
                    semanticLabel: t.common.more,
                    onPressed: controller.toggle,
                    builder: (context, states, _) {
                      final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                      return Padding(
                        padding: const EdgeInsets.all(DsSpace.s4),
                        child: DsIcon(
                          DsIcons.ellipsisVertical,
                          size: theme.sizes.iconSm,
                          color: lit ? colors.text : colors.textSubtle,
                        ),
                      );
                    },
                  ),
                  items: downloadRowMenu(context, menu!),
                ),
            ],
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              if (showProgress)
                Expanded(
                  child: DsProgressBar(
                    value: fraction,
                    semanticLabel: progressLabel ?? title,
                    style: const DsProgressBarStyle(height: 8),
                  ),
                ),
              Flexible(
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: showProgress ? TextAlign.right : TextAlign.left,
                  style: theme.typography.caption.copyWith(color: captionColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The row's state dot: the vivid mark the status palette keeps for dots,
  /// in the color the phase's badge would wear.
  Color _phaseSignal(DsColors colors) => switch (phase) {
    DownloadRowPhase.running ||
    DownloadRowPhase.processing => colors.info.signal,
    DownloadRowPhase.queued || DownloadRowPhase.cancelled => colors.neutral.signal,
    DownloadRowPhase.paused => colors.warning.signal,
    DownloadRowPhase.failed || DownloadRowPhase.missing => colors.danger.signal,
    DownloadRowPhase.done => colors.success.signal,
  };
}

/// One archive block's head, the shape vod's parts and hongguo's episodes
/// share: the artwork at the head, the block's name, the block's own count
/// line, and the ⋯ that carries the block's verbs. The verbs themselves stay
/// with the page — they speak to that page's store — the head only hosts
/// them.
final class DownloadGroupHead extends StatelessWidget {
  /// The head for [title], counting [countLine].
  const DownloadGroupHead({
    required this.title,
    required this.countLine,
    required this.menuSemanticLabel,
    required this.menuItems,
    this.cover,
    super.key,
  });

  /// The block's name, one line.
  final String title;

  /// The block's own reading of how much it holds (分部 · N, 12/60 集).
  final String countLine;

  /// The block's artwork at the head; null when the block has none.
  final Widget? cover;

  /// The ⋯'s name, for screen readers.
  final String menuSemanticLabel;

  /// The block's verbs, built by the page.
  final List<Widget> menuItems;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, 0, DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          ?cover,
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
          Text(countLine, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          DsMenuAnchor(
            semanticLabel: menuSemanticLabel,
            align: DsAlign.end,
            items: menuItems,
            builder: (context, anchor, _) => DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              semanticLabel: menuSemanticLabel,
              onPressed: anchor.toggle,
              icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
