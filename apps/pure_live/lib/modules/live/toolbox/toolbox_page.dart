import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_log/live_log.dart' show LogLevel, LogRecord;
import 'package:live_sites/live_sites.dart';
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/room/clipboard_rooms.dart' show detectClipboardRoomsProvider;
import 'package:pure_live/features/settings/settings.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/toolbox/direct_link_dialog.dart';
import 'package:pure_live/modules/live/toolbox/toolbox_controllers.dart';
import 'package:pure_live/shared/shared.dart';

/// The home navigation's link parser: the reference's link tool as one
/// page — a narrow form, the sign-in page's measure, rather than a field
/// stretched across the window. The network probe and image-cache clear that
/// used to sit behind the same entry are settings utilities now, under
/// System; the log console has its own rail entry beside this one.
final class ToolboxPage extends StatelessWidget {
  /// The link parser page.
  const ToolboxPage({super.key});

  /// The form's measure: the sign-in card's, a little wider for a pasted
  /// share text — narrow enough to read as a form, never a band across the
  /// window.
  static const double formWidth = LiveWindow.form;

  @override
  Widget build(BuildContext context) {
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s24, inset, DsSpace.s32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: formWidth),
          child: const _LinkPane(),
        ),
      ),
    );
  }
}

/// The link tool (the reference's page, cut to what this codebase can do):
/// a multi-line field for the pasted link — share texts included — the two
/// full-width actions under it, the room the last resolve found, and the
/// platforms whose links resolve at all.
final class _LinkPane extends ConsumerStatefulWidget {
  const _LinkPane();

  @override
  ConsumerState<_LinkPane> createState() => _LinkPaneState();
}

final class _LinkPaneState extends ConsumerState<_LinkPane> {
  final TextEditingController _field = TextEditingController();

  /// Whether the field holds text: the clear affordance follows it, and
  /// the field does not rebuild the pane on its own.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // The reference reads the clipboard when the tool opens: a copied
    // share text is the usual errand here. Only text that names a link is
    // offered, and only into an empty field, so a stray clipboard string
    // never looks like a paste the viewer made.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_readClipboard()));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Offers the clipboard's link text when the field is still empty.
  Future<void> _readClipboard() async {
    if (!mounted || _field.text.trim().isNotEmpty) return;
    final String? text;
    try {
      text = await Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text?.trim());
    } on Object {
      // A platform without a readable clipboard simply offers nothing.
      return;
    }
    if (!mounted || text == null || text.isEmpty || _field.text.trim().isNotEmpty) return;
    if (LinkToolController.linkUriOf(text) == null) return;
    _field.text = text;
    _edited();
  }

  /// Editing the field drops the last result and stops the resolve that
  /// works on the old text (the reference cancels on edits too).
  void _edited() {
    ref.read(linkToolProvider.notifier).reset();
    final hasText = _field.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  /// Resolves the field's text; on a room, opens it.
  Future<void> _open() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(linkToolProvider.notifier).resolve(_field.text);
    if (!mounted) return;
    final link = ref.read(linkToolProvider);
    final room = link.resolved;
    if (room == null) {
      _toastFailure(link.failure);
      return;
    }
    unawaited(context.push(RoomRoute(platform: room.platform, roomId: room.roomId).location));
  }

  /// Resolves the field's text; on a room, copies the canonical room link.
  Future<void> _copy() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(linkToolProvider.notifier).resolve(_field.text);
    if (!mounted) return;
    final link = ref.read(linkToolProvider);
    final room = link.resolved;
    if (room == null) {
      _toastFailure(link.failure);
      return;
    }
    await Clipboard.setData(ClipboardData(text: '$room.url'));
    if (!mounted) return;
    showDsToast(context: context, title: context.t.toolbox.linkCopyDone);
  }

  /// Resolves the field's text, then lists the room's direct stream links:
  /// the quality picker and the playable URLs, each to copy.
  Future<void> _direct() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(linkToolProvider.notifier).resolve(_field.text);
    if (!mounted) return;
    final link = ref.read(linkToolProvider);
    final resolved = link.resolved;
    if (resolved == null) {
      _toastFailure(link.failure);
      return;
    }
    final site = ref.read(sitesProvider).getById(resolved.platform);
    final rooms = site?.capability<LiveRoomProvider>();
    final playback = site?.capability<LivePlaybackProvider>();
    if (rooms == null || playback == null) {
      _toastFailure(LinkToolFailure.unsupported);
      return;
    }
    final roomAnswer = await rooms.getRoom(resolved.roomId);
    if (!mounted) return;
    final room = roomAnswer.fold((_) => null, (room) => room);
    if (room == null) {
      _toastFailure(LinkToolFailure.failed);
      return;
    }
    final qualitiesAnswer = await playback.getQualities(room: room);
    if (!mounted) return;
    final qualities = qualitiesAnswer.fold((_) => const <LivePlayQuality>[], (qualities) => qualities);
    if (qualities.isEmpty) {
      showDsToast(context: context, title: context.t.toolbox.linkDirectEmpty, status: DsStatus.danger);
      return;
    }
    await showDsDialog<void>(
      context: context,
      builder: (context) => DirectLinkDialog(room: room, playback: playback, qualities: qualities),
    );
  }

  /// Puts the clipboard's text in the field, replacing whatever is there.
  Future<void> _paste() async {
    final text = await Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text);
    if (!mounted || text == null || text.trim().isEmpty) return;
    _field.text = text.trim();
    _edited();
  }

  /// Empties the field and its last result.
  void _clearField() {
    _field.clear();
    _edited();
  }

  /// Why the last resolve failed, as a toast.
  void _toastFailure(LinkToolFailure? failure) {
    if (failure == null) return;
    final t = context.t;
    final message = switch (failure) {
      LinkToolFailure.empty => t.toolbox.linkEmpty,
      LinkToolFailure.unsupported => t.toolbox.linkUnsupported,
      LinkToolFailure.timeout => t.toolbox.linkTimeout,
      LinkToolFailure.failed => t.toolbox.linkFailed,
    };
    showDsToast(context: context, title: message, status: DsStatus.danger);
  }

  /// The display name of the site [platformId] names, or the id itself
  /// when the registry does not know it.
  String _siteNameById(String platformId) {
    final site = ref.read(sitesProvider).getById(platformId);
    return site == null ? platformId : _siteName(site);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final link = ref.watch(linkToolProvider);
    final resolving = link.resolving;
    final resolvable = [
      for (final site in ref.watch(sitesProvider).all)
        if (site.capability<LiveLinkResolver>() != null) site,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s20,
      children: [
        // The form itself, shaped like the sign-in page: a labelled field,
        // the quiet ways to fill and empty it, one full-width action over
        // the other, and the direct-link way as the last quiet line.
        DsCard(
          style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s20,
            children: [
              DsField(
                label: Text(t.toolbox.linkFieldLabel),
                child: DsTextField.multiline(
                  controller: _field,
                  onChanged: (_) => _edited(),
                  placeholder: t.toolbox.linkFieldHint,
                  minLines: 2,
                  maxLines: 4,
                  semanticLabel: t.toolbox.linkFieldLabel,
                ),
              ),
              Row(
                children: [
                  DsButton(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    onPressed: resolving ? null : () => unawaited(_paste()),
                    leading: const DsIcon(DsIcons.clipboardPaste, size: 16),
                    child: Text(t.toolbox.linkPaste),
                  ),
                  const Spacer(),
                  if (resolving)
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      onPressed: () => ref.read(linkToolProvider.notifier).reset(),
                      leading: const DsIcon(DsIcons.x, size: 16),
                      child: Text(t.toolbox.cancel),
                    )
                  else
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      onPressed: _hasText ? _clearField : null,
                      leading: const DsIcon(DsIcons.close, size: 16),
                      child: Text(t.toolbox.linkClear),
                    ),
                ],
              ),
              DsButton(
                variant: DsButtonVariant.primary,
                loading: resolving,
                onPressed: resolving ? null : () => unawaited(_open()),
                child: Text(t.toolbox.linkOpen),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                loading: resolving,
                onPressed: resolving ? null : () => unawaited(_copy()),
                child: Text(t.toolbox.linkCopy),
              ),
              Center(
                child: DsLink(
                  label: t.toolbox.linkDirect,
                  onPressed: resolving ? null : () => unawaited(_direct()),
                  style: DsLinkStyle(textStyle: DsTheme.of(context).typography.small),
                ),
              ),
            ],
          ),
        ),
        if (link.resolved case final room?)
          DsListSection(
            header: Text(t.toolbox.linkResolvedTitle),
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.antenna),
                title: Text(t.toolbox.linkPlatform),
                detail: Text(_siteNameById(room.platform)),
              ),
              DsListRow(leading: const DsIcon(DsIcons.tv), title: Text(t.toolbox.linkRoom), detail: Text(room.roomId)),
            ],
          ),
        _SupportPlatforms(sites: resolvable),
        // The same errand, run by itself: this is where a copied link is
        // read, so the switch that lets the app read the clipboard on its
        // own belongs here rather than on a browsing page.
        DsListSection(
          header: Text(t.toolbox.linkClipboardGroup),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.clipboard),
              title: Text(t.toolbox.linkClipboardRooms),
              description: Text(t.toolbox.linkClipboardRoomsDesc),
              trailing: DsSwitch(
                value: ref.watch(detectClipboardRoomsProvider),
                onChanged: (value) => unawaited(ref.read(detectClipboardRoomsProvider.notifier).set(value: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The platforms whose links resolve: a labelled wrap of the kit's badges,
/// one per platform with its own mark, so the catalogue reads at a glance
/// instead of one full-width row each.
final class _SupportPlatforms extends StatelessWidget {
  const _SupportPlatforms({required this.sites});

  final List<LiveSite> sites;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final badge = DsBadgeStyle(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
      background: colors.control,
      foreground: colors.text,
      borderColor: colors.border,
      borderRadius: BorderRadius.circular(DsRadii.pill),
      textStyle: theme.typography.small.copyWith(fontWeight: FontWeight.w500),
      iconSize: 16,
      gap: DsSpace.s6,
    );
    return DsListSection(
      header: Row(
        children: [
          Expanded(child: Text(t.toolbox.linkSupportTitle)),
          Text('${sites.length}', style: theme.typography.overline.copyWith(color: colors.textSubtle)),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s12,
            children: [
              Text(t.toolbox.linkSupportHint, style: theme.typography.small.copyWith(color: colors.textSubtle)),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (final site in sites)
                    DsBadge(dot: false, icon: localizedSiteIcon(site), label: Text(_siteName(site)), style: badge),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A site's display name, falling back to its id (the settings page's own
/// resolution; the sites' names ship zh-CN first).
String _siteName(LiveSite site) => localizedSiteName(site);

/// The node test: every probe-able platform as a card with its own icon,
/// the last measured latency and a per-card test, plus a sweep that checks
/// them four at a time. The design system's badges carry the state; no
/// fake endpoint strings are shown.
final class PlatformNodesPane extends ConsumerWidget {
  const PlatformNodesPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final sites = probeSites(ref.watch(sitesProvider).all);
    if (sites.isEmpty) {
      return DsEmptyState(icon: const DsIcon(DsIcons.cloudOff), title: Text(t.toolbox.nodeNoSites));
    }
    final probe = ref.watch(platformProbeProvider);
    final controller = ref.read(platformProbeProvider.notifier);
    final tested = probe.nodes.values.where((node) => node.outcome != null).length;
    final reachable = probe.nodes.values.where((node) => node.outcome is ProbeSuccess).length;
    final summary = tested == 0
        ? t.toolbox.nodeUntestedSummary(total: sites.length)
        : t.toolbox.nodeSummary(ok: reachable, tested: tested, total: sites.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        Row(
          spacing: DsSpace.s12,
          children: [
            Expanded(
              child: Text(
                summary,
                style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
              ),
            ),
            DsButton(
              variant: DsButtonVariant.primary,
              loading: probe.running,
              leading: const DsIcon(DsIcons.gauge, size: 16),
              onPressed: probe.running ? null : () => unawaited(controller.probeAll()),
              child: Text(t.toolbox.nodeTestAll),
            ),
          ],
        ),
        if (probe.running) DsProgressBar(semanticLabel: t.toolbox.nodeTesting),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = LiveWindow.isExpanded(constraints.maxWidth)
                ? 3
                : LiveWindow.isCompact(constraints.maxWidth)
                ? 1
                : 2;
            final width = (constraints.maxWidth - (columns - 1) * DsSpace.s12) / columns;
            return Wrap(
              spacing: DsSpace.s12,
              runSpacing: DsSpace.s12,
              children: [
                for (final site in sites)
                  SizedBox(
                    width: width,
                    child: _PlatformNodeCard(
                      site: site,
                      node: probe.nodes[site.manifest.id],
                      onTest: () => unawaited(controller.probe(site.manifest.id)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One platform's node card: its own icon and name, a state badge, the
/// measured latency and the per-platform test button.
final class _PlatformNodeCard extends StatelessWidget {
  const _PlatformNodeCard({required this.site, required this.node, required this.onTest});

  final LiveSite site;
  final PlatformProbeNode? node;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final outcome = node?.outcome;
    final probing = node?.probing ?? false;
    final success = outcome is ProbeSuccess ? outcome : null;
    final failure = outcome is ProbeFailure ? outcome : null;
    final (status, badge) = switch (outcome) {
      _ when probing => (t.toolbox.nodeTesting, DsStatus.info),
      ProbeSuccess() => (t.toolbox.nodeReachable, DsStatus.success),
      ProbeFailure() => (t.toolbox.nodeFailed, DsStatus.danger),
      _ => (t.toolbox.nodeUntested, DsStatus.neutral),
    };
    final source = site.capability<LiveDiscoveryProvider>() != null
        ? t.toolbox.nodeSourceRecommended
        : t.toolbox.nodeSourceHot;
    return Container(
      padding: const EdgeInsets.all(DsSpace.s16),
      decoration: DsBoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        shadows: [DsShadow.innerRing(colors.border)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              ?localizedSiteIcon(site, size: 26),
              Expanded(
                child: Text(
                  localizedSiteName(site),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                ),
              ),
              DsBadge(label: Text(status), status: badge),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
              Text(
                success == null ? '—' : '${success.elapsed.inMilliseconds} ms',
                style: theme.typography.numeric(
                  theme.typography.body.copyWith(
                    color: success != null ? colors.success.text : colors.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (success != null)
            Text(
              t.toolbox.nodeAnswer(count: success.rooms),
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            )
          else if (failure != null)
            DsTooltip(
              message: failure.error.message,
              child: Text(
                failure.error.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.danger.text),
              ),
            )
          else
            Text(t.toolbox.nodeHint, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              loading: probing,
              leading: const DsIcon(DsIcons.refreshCw, size: 14),
              onPressed: probing ? null : onTest,
              child: Text(probing ? t.toolbox.nodeTesting : t.toolbox.nodeTest),
            ),
          ),
        ],
      ),
    );
  }
}

/// The log page: the live tree's memory ring (the rotating file writes the
/// same records), a level control, a file-write switch, search, and a log
/// panel that follows the newest line until the viewer scrolls away from
/// the bottom.
final class LogsPane extends ConsumerStatefulWidget {
  const LogsPane({super.key});

  @override
  ConsumerState<LogsPane> createState() => _LogsPaneState();
}

final class _LogsPaneState extends ConsumerState<LogsPane> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  /// What this page shows, independent of what the tree records: the level
  /// the viewer wants to see, with the lowest stop as the default so nothing
  /// is hidden until they ask for it.
  LogLevel _filter = LogLevel.trace;
  bool _autoScroll = true;
  int _lastShown = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 16;
    if (atBottom != _autoScroll) {
      setState(() => _autoScroll = atBottom);
    }
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    setState(() => _autoScroll = true);
  }

  Future<void> _copy() async {
    final text = exportAppLog();
    if (text.trim().isEmpty) {
      showDsToast(context: context, title: context.t.toolbox.logsCopyEmpty);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showDsToast(context: context, title: context.t.toolbox.logsCopied);
  }

  /// The log file's own path onto the clipboard: opening the folder is the
  /// last step a viewer takes, and the path is what they paste into a report.
  Future<void> _copyPath() async {
    final path = appLogFile;
    if (path == null) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) showDsToast(context: context, title: context.t.toolbox.logsPathCopied);
  }

  Future<void> _openLogDirectory() async {
    final directory = appLogDirectory;
    if (directory == null) return;
    final opened = await OpenFile.open(directory.path);
    if (opened.type != ResultType.done && mounted) {
      showDsToast(context: context, title: context.t.toolbox.logsOpenFailed, status: DsStatus.danger);
    }
  }

  Future<void> _clear() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.toolbox.logsClearConfirm,
      description: t.toolbox.logsClearConfirmDesc,
      confirmLabel: t.toolbox.logsClear,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    clearAppLog();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final records = ref.watch(appLogRecordsProvider).value ?? const <LogRecord>[];
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final record in records)
        if (record.level.isAtLeast(_filter) &&
            (query.isEmpty ||
                record.message.toLowerCase().contains(query) ||
                record.category.toLowerCase().contains(query) ||
                record.fields.entries.any((entry) => '${entry.key} ${entry.value}'.toLowerCase().contains(query))))
          record,
    ];
    if (_autoScroll && shown.length != _lastShown) {
      _lastShown = shown.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        // The gear sits at the page's own top end: the settings page owns the
        // level, the file and the folder, so this page keeps no second entry
        // for them.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DsButton.icon(
            variant: DsButtonVariant.ghost,
            semanticLabel: t.settings.navLogs,
            onPressed: () => unawaited(context.push(SettingsSectionRoute(section: SettingsSection.logs.name).location)),
            icon: const DsIcon(DsIcons.settings, size: 18),
          ),
        ),
        // The lines are what this page is for, so its options sit in an
        // accordion that starts closed and gives the height back.
        DsAccordion<String>(
          allowMultiple: true,
          semanticLabel: t.toolbox.logsSection,
          items: [
            DsAccordionItem<String>(
              value: 'filter',
              title: _logsAccordionTitle(const DsIcon(DsIcons.listFilter, size: 16), t.toolbox.logsFilterSection),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsListRow(
                    leading: const DsIcon(DsIcons.layers),
                    title: Text(t.toolbox.logsLevelFilter),
                    description: Text(t.toolbox.logsLevelFilterDesc),
                    trailing: SizedBox(
                      width: 160,
                      child: AdaptiveChoiceField<LogLevel>(
                        value: _filter,
                        title: t.toolbox.logsLevelFilter,
                        onChanged: (level) => setState(() => _filter = level),
                        options: [
                          for (final level in const [
                            LogLevel.trace,
                            LogLevel.debug,
                            LogLevel.info,
                            LogLevel.warning,
                            LogLevel.error,
                            LogLevel.fatal,
                          ])
                            DsSelectOption(value: level, label: level.label),
                        ],
                        semanticLabel: t.toolbox.logsLevelFilter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DsAccordionItem<String>(
              value: 'file',
              title: _logsAccordionTitle(const DsIcon(DsIcons.hardDrive, size: 16), t.toolbox.logsFileTitle),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsListRow(
                    leading: const DsIcon(DsIcons.folder),
                    // The file rather than the folder: the folder is where the
                    // rotating files live, and the path a viewer wants named is
                    // this one, so it is the line the page prints.
                    title: Text(t.toolbox.logsFileTitle),
                    description: Text(appLogFile ?? t.toolbox.logsDirectoryDefault),
                    onPressed: appLogFile == null ? null : () => unawaited(_openLogDirectory()),
                    trailing: DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.toolbox.logsCopyPath,
                      onPressed: appLogFile == null ? null : () => unawaited(_copyPath()),
                      icon: const DsIcon(DsIcons.copy, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            decoration: DsBoxDecoration(
              color: colors.channel,
              borderRadius: BorderRadius.circular(theme.radii.card),
              shadows: [DsShadow.innerRing(colors.border)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s12, DsSpace.s8),
                  child: DsSearchField(
                    controller: _search,
                    placeholder: t.toolbox.logsSearch,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: DsEmptyState(
                            icon: const DsIcon(DsIcons.terminal),
                            title: Text(t.toolbox.logsEmptyTitle),
                            description: Text(t.toolbox.logsEmptyDescription),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
                          itemCount: shown.length,
                          itemBuilder: (context, index) => _LogLine(record: shown[index]),
                        ),
                ),
                DsLine(color: colors.border),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s6, DsSpace.s8, DsSpace.s6),
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          _autoScroll ? t.toolbox.logsAutoOn : t.toolbox.logsAutoOff,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                      Text(
                        t.toolbox.logsLines(count: shown.length),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.copy, size: 14),
                        onPressed: () => unawaited(_copy()),
                        child: Text(t.toolbox.logsExport),
                      ),
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.trash2, size: 14),
                        onPressed: () => unawaited(_clear()),
                        child: Text(t.toolbox.logsClear),
                      ),
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.arrowDown, size: 14),
                        onPressed: _toBottom,
                        child: Text(t.toolbox.logsScrollBottom),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// An accordion header for the log page: the section's glyph and its name.
/// The accordion styles the text itself, so this only lays the pair out.
Widget _logsAccordionTitle(Widget icon, String label) => Row(
  spacing: DsSpace.s8,
  children: [
    icon,
    Flexible(child: Text(label)),
  ],
);

/// One record as a monospaced line: clock, level, category, message and
/// its fields, with the error under it when it carries one.
final class _LogLine extends StatelessWidget {
  const _LogLine({required this.record});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final mono = theme.typography.mono(theme.typography.caption).copyWith(fontSize: 11.5, height: 1.45);
    final levelColor = switch (record.level) {
      LogLevel.trace || LogLevel.debug => colors.textSubtle,
      LogLevel.info => colors.info.text,
      LogLevel.warning => colors.warning.text,
      LogLevel.error || LogLevel.fatal => colors.danger.text,
      LogLevel.off => colors.textSubtle,
    };
    final fields = record.fields.isEmpty
        ? ''
        : ' {${record.fields.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}}';
    final time = record.timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text:
                  '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${two(time.millisecond).padLeft(3, '0')} ',
              style: mono.copyWith(color: colors.textSubtle),
            ),
            TextSpan(
              text: '${record.level.label.padRight(5)} ',
              style: mono.copyWith(color: levelColor, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '[${record.category}] ',
              style: mono.copyWith(color: colors.accent),
            ),
            TextSpan(
              text: record.message,
              style: mono.copyWith(color: colors.text),
            ),
            if (fields.isNotEmpty)
              TextSpan(
                text: fields,
                style: mono.copyWith(color: colors.textMuted),
              ),
            if (record.error != null)
              TextSpan(
                text: '\n${record.error}',
                style: mono.copyWith(color: colors.danger.text),
              ),
          ],
        ),
      ),
    );
  }
}
