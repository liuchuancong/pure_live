import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_import_flow.dart';
import 'package:pure_live/modules/iptv/views/iptv_panels.dart' show IptvChannelLogo;

/// How many channels a preview lists before it says how many more there are.
const int _sampleCount = 12;

/// The body of the preview half: what the page says at each step — before
/// anything was read, while it reads, what it read, why it read nothing,
/// and what the write did.
final class IptvImportPreviewBody extends ConsumerWidget {
  /// The body; [onRetry] reads the source again, [onSwitchToGuide] moves a
  /// guide that arrived as a playlist to the guide tab.
  const IptvImportPreviewBody({required this.onRetry, required this.onSwitchToGuide, super.key});

  /// Reads the same source again.
  final VoidCallback onRetry;

  /// Re-reads the source as a guide.
  final VoidCallback onSwitchToGuide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(iptvImportFlowProvider);
    final t = context.t;
    switch (flow.step) {
      case IptvImportStep.source:
        return _Message(icon: DsIcons.listChecks, title: t.iptv.previewIdleTitle, body: t.iptv.previewIdleBody);
      case IptvImportStep.reading:
        return _Busy(label: t.iptv.previewReading);
      case IptvImportStep.writing:
        return _Busy(label: t.iptv.previewWriting);
      case IptvImportStep.done:
        return _Done(flow: flow);
      case IptvImportStep.preview:
        final failure = flow.kind == IptvImportKind.guide ? flow.guide?.failure : flow.playlist?.failure;
        final written = flow.result;
        if (failure != null) {
          return _Failure(result: failure, onRetry: onRetry, onSwitchToGuide: onSwitchToGuide);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s20,
          children: [
            // A write that failed after a good preview says why above the
            // preview it kept; a declined name says so too.
            if (written != null &&
                !written.isImported &&
                (written.status != IptvImportStatus.cancelled || written.failure != null))
              DsAlert(status: DsStatus.danger, title: Text(iptvImportFailureWords(written, t))),
            if (flow.kind == IptvImportKind.guide) _GuidePreview(flow: flow) else _PlaylistPreview(flow: flow),
          ],
        );
    }
  }
}

/// The verbs under the preview half, pinned: back to the source, retry,
/// import, or — once written — import another and finish.
final class IptvImportPreviewFooter extends ConsumerWidget {
  /// The footer; [onRetry] reads the source again, [onFinish] closes the page
  /// (opening the channels when asked to).
  const IptvImportPreviewFooter({required this.onRetry, required this.onFinish, super.key});

  /// Reads the same source again.
  final VoidCallback onRetry;

  /// Closes the page; true asks it to open the channels.
  final void Function({required bool showChannels}) onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final flow = ref.watch(iptvImportFlowProvider);
    final controller = ref.read(iptvImportFlowProvider.notifier);
    final guide = flow.kind == IptvImportKind.guide;
    final List<Widget> actions;
    switch (flow.step) {
      case IptvImportStep.source || IptvImportStep.reading || IptvImportStep.writing:
        return const SizedBox.shrink();
      case IptvImportStep.done:
        actions = [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: controller.backToSource,
            leading: const DsIcon(DsIcons.plus, size: 15),
            child: Text(t.iptv.resultImportAnother),
          ),
          if (!guide)
            DsButton(
              autofocus: true,
              onPressed: () => onFinish(showChannels: true),
              leading: const DsIcon(DsIcons.tv, size: 15),
              child: Text(t.iptv.resultOpenChannels),
            )
          else
            DsButton(autofocus: true, onPressed: () => onFinish(showChannels: false), child: Text(t.iptv.importDone)),
        ];
      case IptvImportStep.preview:
        final readable = guide ? (flow.guide?.isReadable ?? false) : (flow.playlist?.isReadable ?? false);
        final clash = guide ? null : controller.nameClash();
        final canWrite = readable && flow.name.trim().isNotEmpty && (clash == null || flow.replaceNamed);
        actions = [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: controller.backToSource,
            leading: const DsIcon(DsIcons.chevronLeft, size: 15),
            child: Text(t.iptv.importBackAction),
          ),
          if (!readable)
            DsButton(
              autofocus: true,
              onPressed: onRetry,
              leading: const DsIcon(DsIcons.refreshCw, size: 15),
              child: Text(t.iptv.importRetry),
            )
          else
            DsButton(
              autofocus: true,
              onPressed: canWrite ? controller.commit : null,
              leading: const DsIcon(DsIcons.check, size: 15),
              child: Text(
                guide ? t.iptv.importCommitGuideAction : t.iptv.importCommitAction(count: flow.playlist?.channels ?? 0),
              ),
            ),
        ];
    }
    final colors = DsTheme.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: DsSpace.s8, children: actions),
      ),
    );
  }
}

/// The one sentence a failed read or write is worded with: the precise
/// reason when the importer knew it, the status otherwise.
String iptvImportFailureWords(IptvImportResult result, Translations t) => switch (result.failure) {
  IptvImportFailure.httpStatus => t.iptv.failureHttpStatus(code: result.statusCode ?? 0),
  IptvImportFailure.timeout => t.iptv.failureTimeout,
  IptvImportFailure.unreachable => t.iptv.failureUnreachable,
  IptvImportFailure.tls => t.iptv.failureTls,
  IptvImportFailure.webPage => t.iptv.failureWebPage,
  IptvImportFailure.guideFile => t.iptv.failureGuideFile,
  IptvImportFailure.noChannels => t.iptv.failureNoChannels,
  IptvImportFailure.truncated => t.iptv.failureTruncated,
  IptvImportFailure.unreadable => t.iptv.failureUnreadable,
  IptvImportFailure.nameTaken => t.iptv.failureNameTaken,
  IptvImportFailure.storage => t.iptv.failureStorage,
  null => switch (result.status) {
    IptvImportStatus.imported || IptvImportStatus.cancelled => '',
    IptvImportStatus.unsupportedFormat => t.iptv.importFormat,
    IptvImportStatus.invalid => t.iptv.importInvalid,
    IptvImportStatus.networkFailed => t.iptv.importNetworkFailed,
    IptvImportStatus.stale => t.iptv.sourceChanged,
    IptvImportStatus.failed => t.iptv.importFailed,
  },
};

/// The text "copy details" puts on the clipboard: the verdict, its cause
/// and the skipped lines — what someone helping with a broken list needs.
String _details(IptvImportResult? result, List<PlaylistIssue> issues, {String? source}) =>
    [?source, if (result != null) '$result', for (final issue in issues) '$issue'].join('\n');

final class _PlaylistPreview extends ConsumerWidget {
  const _PlaylistPreview({required this.flow});

  final IptvImportFlowState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preview = flow.playlist!;
    final result = preview.result;
    final controller = ref.read(iptvImportFlowProvider.notifier);
    final clash = controller.nameClash();
    final groups = result.groupCounts;
    final header = result.header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s20,
      children: [
        _NameField(flow: flow),
        if (preview.urlClash case final IptvPlaylist stored)
          DsAlert(
            title: Text(t.iptv.previewUrlClash(name: stored.name)),
            icon: const DsIcon(DsIcons.refreshCw),
          ),
        if (clash != null)
          DsAlert(
            status: DsStatus.warning,
            title: Text(t.iptv.previewNameTaken(name: clash.name)),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                DsCheckbox(
                  value: flow.replaceNamed,
                  onChanged: (value) => controller.setReplaceNamed(value: value ?? false),
                  label: Text(t.iptv.nameClashReplace(name: clash.name)),
                ),
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => controller.setName(controller.freeNameFor(clash.name)),
                  child: Text(t.iptv.nameClashRename(name: controller.freeNameFor(clash.name))),
                ),
              ],
            ),
          ),
        _StatStrip(
          stats: [
            (label: t.iptv.previewChannels, value: '${preview.channels}'),
            (label: t.iptv.previewGroups, value: '${groups.length}'),
            (label: t.iptv.previewLines, value: '${result.multiLineCount}'),
            (label: t.iptv.previewIssues, value: '${result.issues.length}'),
            (label: t.iptv.previewFormat, value: (result.format?.name ?? '—').toUpperCase()),
            (label: t.iptv.previewEncoding, value: _encodingWord(preview.encoding, t)),
          ],
        ),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            DsBadge(
              status: header.declaresCatchup || result.entries.any((entry) => entry.catchupSource != null)
                  ? DsStatus.success
                  : DsStatus.neutral,
              label: Text(
                header.declaresCatchup || result.entries.any((entry) => entry.catchupSource != null)
                    ? t.iptv.previewCatchup
                    : t.iptv.previewNoCatchup,
              ),
            ),
            if (result.mergedLines > 0)
              DsBadge(
                status: DsStatus.info,
                label: Text(t.iptv.previewLinesCount(count: result.mergedLines)),
              ),
          ],
        ),
        if (header.declaresGuide)
          DsCheckbox(
            value: flow.attachGuide,
            onChanged: (value) => controller.setAttachGuide(value: value ?? false),
            label: Text(t.iptv.previewGuideAttach),
            description: Text(t.iptv.previewGuideFound(name: Uri.tryParse(header.guideUrls.first)?.host ?? '')),
          ),
        if (groups.length > 1) _GroupPicker(flow: flow, groups: groups),
        _Samples(entries: result.entries),
        if (result.issues.isNotEmpty) _Issues(result: preview.failure, issues: result.issues, source: preview.url),
      ],
    );
  }

  static String _encodingWord(IptvTextEncoding? encoding, Translations t) => switch (encoding) {
    IptvTextEncoding.gbk => t.iptv.previewEncodingGbk,
    IptvTextEncoding.utf16le || IptvTextEncoding.utf16be => t.iptv.previewEncodingUtf16,
    IptvTextEncoding.utf8 || null => t.iptv.previewEncodingUtf8,
  };
}

final class _GuidePreview extends ConsumerWidget {
  const _GuidePreview({required this.flow});

  final IptvImportFlowState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preview = flow.guide!;
    final libraryChannels = ref.watch(iptvLibraryProvider).value?.channels.length ?? 0;
    final start = preview.firstStart;
    final stop = preview.lastStop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s20,
      children: [
        _NameField(flow: flow),
        _StatStrip(
          stats: [
            (label: t.iptv.previewChannels, value: '${preview.channels}'),
            (label: t.iptv.guideTitle, value: '${preview.programmes}'),
            (label: t.iptv.libraryTitle, value: '${preview.matchable}'),
          ],
        ),
        Text(
          t.iptv.previewGuideChannels(channels: preview.channels, programmes: preview.programmes),
          style: DsTheme.of(context).typography.body.copyWith(color: DsTheme.colorsOf(context).textMuted),
        ),
        if (start != null && stop != null)
          Text(
            t.iptv.previewGuideWindow(start: _day(start), end: _day(stop)),
            style: DsTheme.of(context).typography.body.copyWith(color: DsTheme.colorsOf(context).textMuted),
          ),
        // A guide whose whole window lies in the past still imports on the
        // viewer's word — they picked it — but the page says what it means:
        // nothing in it will ever be on air.
        if (stop != null && stop.isBefore(DateTime.now()))
          DsAlert(
            status: DsStatus.warning,
            title: Text(t.iptv.previewGuideStale(end: _day(stop))),
          ),
        if (libraryChannels > 0 && preview.matchable == 0)
          DsAlert(status: DsStatus.warning, title: Text(t.iptv.previewGuideNoMatch))
        else if (libraryChannels > 0)
          DsAlert(
            status: DsStatus.success,
            title: Text(t.iptv.previewGuideMatched(count: preview.matchable)),
          ),
      ],
    );
  }

  static String _day(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.month}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

/// The name the import will carry, editable over the preview.
final class _NameField extends ConsumerStatefulWidget {
  const _NameField({required this.flow});

  final IptvImportFlowState flow;

  @override
  ConsumerState<_NameField> createState() => _NameFieldState();
}

final class _NameFieldState extends ConsumerState<_NameField> {
  late final TextEditingController _name = TextEditingController(text: widget.flow.name);

  @override
  void didUpdateWidget(_NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "Save as" renames from outside the field; the field follows.
    if (widget.flow.name != _name.text) {
      _name.value = TextEditingValue(
        text: widget.flow.name,
        selection: TextSelection.collapsed(offset: widget.flow.name.length),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s6,
      children: [
        Text(t.iptv.previewName, style: theme.typography.fieldLabel.copyWith(color: colors.textMuted)),
        DsTextField(
          controller: _name,
          placeholder: t.iptv.playlistNameHint,
          semanticLabel: t.iptv.previewName,
          onChanged: ref.read(iptvImportFlowProvider.notifier).setName,
        ),
      ],
    );
  }
}

/// The preview's numbers, as tiles in a row that wraps.
final class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final List<({String label, String value})> stats;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Wrap(
      spacing: DsSpace.s8,
      runSpacing: DsSpace.s8,
      children: [
        for (final stat in stats)
          Container(
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
            decoration: BoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card - 6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(stat.value, style: theme.typography.heading.copyWith(color: colors.text)),
                Text(stat.label, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The groups the playlist carries, each with a switch: what is left off is
/// hidden once the import is in (a hidden group, not a dropped one).
final class _GroupPicker extends ConsumerWidget {
  const _GroupPicker({required this.flow, required this.groups});

  final IptvImportFlowState flow;
  final Map<String, int> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(iptvImportFlowProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s4,
          children: [
            Expanded(
              child: Text(t.iptv.previewGroupPick, style: theme.typography.small.copyWith(color: colors.textMuted)),
            ),
            DsButton(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              onPressed: () => controller.setAllGroups(shown: true),
              child: Text(t.iptv.previewGroupAll),
            ),
            DsButton(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              onPressed: () => controller.setAllGroups(shown: false),
              child: Text(t.iptv.previewGroupNone),
            ),
          ],
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 264),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(theme.radii.card - 6),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
            children: [
              for (final MapEntry(key: group, value: count) in groups.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: DsCheckbox(
                          value: !flow.hiddenGroups.contains(group),
                          onChanged: (value) => controller.toggleGroup(group, shown: value ?? false),
                          label: Text(group.isEmpty ? t.iptv.ungrouped : group),
                        ),
                      ),
                      Text('$count', style: theme.typography.caption.copyWith(color: colors.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The first channels the import writes, with their marks and lines.
final class _Samples extends StatelessWidget {
  const _Samples({required this.entries});

  final List<IptvEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final shown = entries.take(_sampleCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.iptv.previewSamples, style: theme.typography.labelStrong.copyWith(color: colors.text)),
        for (final entry in shown)
          Row(
            spacing: DsSpace.s12,
            children: [
              IptvChannelLogo(
                channel: IptvChannel.of(id: 'preview', entry: entry),
                size: DsSize.xs,
              ),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.text),
                ),
              ),
              if ((entry.group ?? '').isNotEmpty)
                Flexible(
                  child: Text(
                    entry.group!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                ),
              if (entry.alternatives.isNotEmpty)
                DsBadge(dot: false, label: Text(t.iptv.previewLinesCount(count: entry.alternatives.length + 1))),
            ],
          ),
        if (entries.length > shown.length)
          Text(
            t.iptv.previewMore(count: entries.length - shown.length),
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
      ],
    );
  }
}

/// The skipped lines, folded: the count on the header, the lines and a copy
/// verb inside.
final class _Issues extends StatelessWidget {
  const _Issues({required this.result, required this.issues, required this.source});

  final IptvImportResult? result;
  final List<PlaylistIssue> issues;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsAccordion<int>(
      items: [
        DsAccordionItem(
          value: 0,
          title: Text('${t.iptv.previewIssueList} (${issues.length})'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              for (final issue in issues.take(50))
                Text(
                  '$issue',
                  style: theme.typography.caption.copyWith(color: colors.textMuted, fontFamily: 'monospace'),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _CopyButton(text: _details(result, issues, source: source)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsButton(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) showDsToast(context: context, status: DsStatus.success, title: t.iptv.previewCopied);
      },
      leading: const DsIcon(DsIcons.copy, size: 14),
      child: Text(t.iptv.resultCopyDetail),
    );
  }
}

final class _Failure extends StatelessWidget {
  const _Failure({required this.result, required this.onRetry, required this.onSwitchToGuide});

  final IptvImportResult result;
  final VoidCallback onRetry;
  final VoidCallback onSwitchToGuide;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final network = result.status == IptvImportStatus.networkFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s12,
      children: [
        DsIcon(network ? DsIcons.wifiOff : DsIcons.circleAlert, size: 36, color: colors.danger.signal),
        Text(iptvImportFailureWords(result, t), style: theme.typography.heading.copyWith(color: colors.text)),
        if (result.error != null)
          Text(
            '${result.error}',
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            if (result.failure == IptvImportFailure.guideFile)
              DsButton(
                onPressed: onSwitchToGuide,
                leading: const DsIcon(DsIcons.calendarClock, size: 15),
                child: Text(t.iptv.importSwitchToGuide),
              ),
            _CopyButton(text: _details(result, result.issues)),
          ],
        ),
      ],
    );
  }
}

final class _Done extends ConsumerWidget {
  const _Done({required this.flow});

  final IptvImportFlowState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final result = flow.result!;
    final guideId = flow.guideResult?.id;
    final guideName = guideId == null ? null : ref.watch(iptvLibraryProvider).value?.guideSource(guideId)?.name;
    final playlist = flow.kind == IptvImportKind.playlist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s12,
      children: [
        DsIcon(DsIcons.circleCheck, size: 40, color: colors.success.signal),
        Text(t.iptv.resultImported, style: theme.typography.title.copyWith(color: colors.text)),
        Text(flow.name, style: theme.typography.body.copyWith(color: colors.textMuted)),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            DsBadge(
              status: DsStatus.success,
              label: Text(t.iptv.resultChannels(count: result.channels)),
            ),
            if (playlist) ...[
              DsBadge(
                status: DsStatus.info,
                dot: false,
                label: Text(t.iptv.resultAdded(count: result.added)),
              ),
              DsBadge(dot: false, label: Text(t.iptv.resultUpdated(count: result.updated))),
              if (result.removed > 0)
                DsBadge(
                  status: DsStatus.warning,
                  dot: false,
                  label: Text(t.iptv.resultRemoved(count: result.removed)),
                ),
              if (result.issues.isNotEmpty)
                DsBadge(
                  status: DsStatus.warning,
                  dot: false,
                  label: Text(t.iptv.resultSkipped(count: result.issues.length)),
                ),
            ],
          ],
        ),
        if (guideName != null)
          Row(
            spacing: DsSpace.s8,
            children: [
              DsIcon(DsIcons.calendarClock, size: theme.sizes.iconSm, color: colors.accentText),
              Flexible(
                child: Text(
                  t.iptv.resultGuideAttached(name: guideName),
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

final class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s48),
      child: Column(
        spacing: DsSpace.s12,
        children: [
          const DsSpinner(style: DsSpinnerStyle(size: 28)),
          Text(label, style: theme.typography.body.copyWith(color: colors.textMuted)),
          const SizedBox(width: 240, child: DsProgressBar()),
        ],
      ),
    );
  }
}

final class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final DsIconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(14)),
            child: Center(child: DsIcon(icon, size: 24, color: colors.accentText)),
          ),
          Text(title, style: theme.typography.heading.copyWith(color: colors.text)),
          Text(body, style: theme.typography.body.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}
