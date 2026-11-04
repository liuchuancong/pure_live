import io

p = 'apps/pure_live/lib/modules/live/recorder/pages/recorder_page.dart'
s = io.open(p, encoding='utf-8').read()


def once(old, new=''):
    global s
    assert s.count(old) == 1, (old[:70], s.count(old))
    s = s.replace(old, new)


# 1. cards at every width: the rich row is the design
once(
    """                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // A phone keeps the cards; from a small window up
                            // the same information is a table, and the columns
                            // that fit are the columns it shows.
                            if (constraints.maxWidth < 760) {
                              return SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: DsSpace.s8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  spacing: DsSpace.s8,
                                  children: [for (final task in attention) ..._taskCards(context, task, rooms)],
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: DsSpace.s8),
                              child: DsTable<RecordingTask>(
                                semanticLabel: t.recorder.tabTasks,
                                style: const DsTableStyle(rowHeight: 78),
                                columns: _taskColumns(context, rooms, constraints.maxWidth),
                                rows: attention,
                                rowKey: (task) => task.id,
                                emptyView: const SizedBox.shrink(),
                              ),
                            );
                          },
                        ),""",
    """                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: DsSpace.s8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: DsSpace.s8,
                            children: [for (final task in attention) ..._taskCards(context, task, rooms)],
                          ),
                        ),""",
)

# 2. the table helpers go with the table
start = s.index("  /// The subscription table: the room, its state, the figures that fit, the")
end = s.index("  Widget _tasksBody({", start)
s = s[:start] + s[end:]

# 3. the card: one identity block, the phase, five figures, the footer
start = s.index("    final processing = task.postProcessing;")
end = s.index("  /// Whether the take's file was deleted from the preview: a settled row", start)
new_body = '''    final processing = task.postProcessing;
    final fileDeleted = _fileDeleted;
    final recording = task.isRunning && !processing;
    final failed = task.enabled && task.state == RecordingTaskState.failed && !processing;
    final paused = !task.enabled && !processing;
    final area = (room?.area?.areaName ?? '').trim();
    final figuresDuration = liveElapsed > Duration.zero ? formatRecordingDuration(liveElapsed) : '—';
    final figuresSize = task.bytes > 0 ? formatRecordingBytes(task.bytes) : '—';
    final figuresBitrate = task.bytes > 0 && liveElapsed.inSeconds > 0
        ? formatRecordingBitrate(task.bytes, liveElapsed)
        : '—';
    final segmentSeconds = ref.watch(recordingSettingsProvider).segmentSeconds;
    final segmentMinutes = segmentSeconds <= 0 ? 0 : (segmentSeconds / 60).ceil();
    final segment = liveElapsed <= Duration.zero || segmentMinutes <= 0
        ? ''
        : t.recorder.segmentProgress(count: liveElapsed.inSeconds ~/ segmentSeconds + 1, minutes: segmentMinutes);
    final statusText = processing
        ? t.recorder.stateProcessing
        : recording
        ? t.recorder.stateRecording
        : failed
        ? t.recorder.stateFailed
        : paused
        ? t.recorder.statePaused
        : fileDeleted
        ? t.recorder.stateFileDeleted
        : t.recorder.stateWaiting;
    final statusTone = processing
        ? DsStatus.info
        : recording || failed
        ? DsStatus.danger
        : paused || fileDeleted
        ? DsStatus.neutral
        : DsStatus.warning;
    final statusNote = recording ? segment : (lastRun.isNotEmpty ? lastRun : (fileDeleted ? t.recorder.warningFileDeleted : ''));
    final tags = [
      if (task.quality.isNotEmpty) task.quality else t.recorder.qualityBest,
      if (area.isNotEmpty) area,
    ];
    final Widget action = processing
        ? DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.x, size: 14),
            onPressed: onCancelProcessing,
            child: Text(t.recorder.cancelProcessing),
          )
        : recording
        ? DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.pause, size: 14),
            onPressed: onToggleWatch,
            child: Text(t.recorder.pauseWatch),
          )
        : failed
        ? DsButton(
            variant: DsButtonVariant.primary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.refreshCw, size: 14),
            onPressed: onStartNow,
            child: Text(t.common.retry),
          )
        : paused
        ? DsButton(
            variant: DsButtonVariant.primary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.play, size: 14),
            onPressed: onToggleWatch,
            child: Text(t.recorder.resumeWatch),
          )
        : DsButton(
            variant: DsButtonVariant.primary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.play, size: 14),
            onPressed: onStartNow,
            child: Text(t.recorder.startNow),
          );
    final saved = (task.filePath ?? '').trim();
    return DsCard(
      onPressed: onOpen,
      semanticLabel: title,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s16),
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final (coverWidth, coverHeight) = width >= 560 ? (132.0, 74.0) : (96.0, 54.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s16,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DsImage(
                      image: cover.isEmpty ? null : cachedImage(cover),
                      width: coverWidth,
                      height: coverHeight,
                      semanticLabel: title,
                      fallback: _CoverFallback(letter: platformLetter(task.platform)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s4,
                      children: [
                        Wrap(
                          spacing: DsSpace.s6,
                          runSpacing: DsSpace.s4,
                          children: [
                            _TagChip(text: platformName, icon: platformIcon),
                            for (final tag in tags) _TagChip(text: tag),
                          ],
                        ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.heading.copyWith(color: colors.text),
                        ),
                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            DsAvatar(
                              initials: avatarInitials(anchor.isEmpty ? title : anchor),
                              image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                              size: DsSize.sm,
                              semanticLabel: anchor.isEmpty ? title : anchor,
                            ),
                            Flexible(
                              child: Text(
                                anchor.isEmpty ? title : anchor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ),
                            Text(
                              '${t.recorder.roomArea} ${task.roomId}',
                              style: theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: DsSpace.s6,
                    children: [
                      DsBadge(label: Text(statusText), status: statusTone),
                      if (statusNote.isNotEmpty)
                        SizedBox(
                          width: 150,
                          child: Text(
                            statusNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s6,
                        children: [
                          DsButton.icon(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            semanticLabel: t.recorder.roomSettings,
                            onPressed: onSchedule,
                            icon: const DsIcon(DsIcons.settings, size: 14),
                          ),
                          action,
                          _TaskMenu(
                            task: task,
                            hasFile: saved.isNotEmpty,
                            onOpen: onOpen,
                            onStop: onStop,
                            onToggleWatch: onToggleWatch,
                            onDelete: onDelete,
                            onSchedule: onSchedule,
                            onCancelProcessing: onCancelProcessing,
                            onStartNow: onStartNow,
                            onRetryJoin: onRetryJoin,
                            onPreview: onPreview,
                            onPlayExternal: onPlayExternal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 1),
              Wrap(
                spacing: DsSpace.s32,
                runSpacing: DsSpace.s12,
                children: [
                  SizedBox(
                    width: 150,
                    child: _StatBlock(
                      label: recording ? t.recorder.statThisTask : t.recorder.statLastTask,
                      value: figuresDuration,
                      emphasis: recording,
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: _StatBlock(
                      label: recording ? t.recorder.statLiveBitrate : t.recorder.statLastBitrate,
                      value: figuresBitrate,
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: _StatBlock(label: t.recorder.statProfile, value: task.quality.isNotEmpty ? task.quality : t.recorder.qualityBest),
                  ),
                  SizedBox(
                    width: 150,
                    child: _StatBlock(
                      label: t.recorder.statSaved,
                      value: figuresSize == '—' ? t.recorder.statSavedEmpty : figuresSize,
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s6,
                          children: [
                            Text(
                              t.recorder.roomCheckTitle,
                              style: theme.typography.caption.copyWith(color: colors.textSubtle, fontSize: 11),
                            ),
                            DsSwitch(
                              value: task.enabled,
                              onChanged: (value) => onToggleWatch(),
                              semanticLabel: t.recorder.roomCheckTitle,
                            ),
                          ],
                        ),
                        Text(
                          task.enabled ? t.recorder.statCheckOn : t.recorder.statCheckOff,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textSubtle, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Row(
                spacing: DsSpace.s8,
                children: [
                  DsIcon(DsIcons.folderOpen, size: 14, color: colors.textSubtle),
                  Flexible(
                    child: Text(
                      saved.isEmpty ? t.recorder.saveDirTitle : saved,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  ),
                  const Spacer(),
                  if (task.state == RecordingTaskState.recording && onStop == null)
                    Text(
                      t.recorder.stateRecordingElsewhere,
                      style: theme.typography.caption.copyWith(color: colors.warning.text),
                    )
                  else if (task.state == RecordingTaskState.failed && task.errorText.trim().isNotEmpty)
                    Flexible(
                      child: Text(
                        task.errorText.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.danger.text),
                      ),
                    )
                  else if (!processing && task.warning.isNotEmpty)
                    Flexible(
                      child: Text(
                        _warningLabel(t, task.warning),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.warning.text),
                      ),
                    ),
                ],
              ),
              if (processing) ...[
                DsProgressBar(
                  value: task.postProcessingProgress >= 0 ? task.postProcessingProgress.clamp(0.0, 1.0) : null,
                  semanticLabel: t.recorder.stateProcessing,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

'''
s = s[:start] + new_body + s[end:]

# 4. the two small widgets the card wears
once(
    """/// One figure of a row: the word over the number, so three of them line up""",
    """/// One figure of the card's strip: the value over the word that names it.
final class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography
              .numeric(theme.typography.title)
              .copyWith(color: emphasis ? colors.accent : colors.text, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.caption.copyWith(color: colors.textSubtle, fontSize: 11),
        ),
      ],
    );
  }
}

/// One small word on the card's header: the platform with its mark, or a
/// category the room carries.
final class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, this.icon});

  final String text;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return DecoratedBox(
      decoration: DsBoxDecoration(
        color: colors.hover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            ?icon,
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// One figure of a row: the word over the number, so three of them line up""",
)
io.open(p, 'w', encoding='utf-8').write(s)
print('ok')
