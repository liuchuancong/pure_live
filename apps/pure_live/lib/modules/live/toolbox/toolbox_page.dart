import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_log/live_log.dart' show LogLevel, LogRecord;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/room/clipboard_rooms.dart' show detectClipboardRoomsProvider;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsSection;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/toolbox/direct_link_dialog.dart';
import 'package:pure_live/modules/live/toolbox/log_settings_section.dart';
import 'package:pure_live/modules/live/toolbox/toolbox_controllers.dart';
import 'package:pure_live/shared/shared.dart';

/// The home navigation's link parser: the reference's link tool as one
/// page — a narrow form, the sign-in page's measure, rather than a field
/// stretched across the window. The network probe and image-cache clear that
/// used to sit behind the same entry are settings utilities now, under
/// System; the log console has its own rail entry beside this one.
/// Below this window width the log console's foot drops its buttons' labels
/// for their icons alone: the three labelled verbs together leave the line
/// no room beside the auto-scroll notice on a narrow window.
const double kLogsFootTextWidth = 480;

final class ToolboxPage extends ConsumerWidget {
  /// The link parser page.
  const ToolboxPage({super.key});

  /// The form's measure: the sign-in card's, a little wider for a pasted
  /// share text — narrow enough to read as a form, never a band across the
  /// window.
  static const double formWidth = LiveWindow.form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final resolvable = [
      for (final site in ref.watch(sitesProvider).all)
        if (site.capability<LiveLinkResolver>() != null) site,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s20, inset, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s20,
        children: [
          // The form stays a form's width; the supported platforms beneath
          // it are the page's own full width, laid flat.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: formWidth),
              child: const _LinkPane(),
            ),
          ),
          _SupportPlatforms(sites: resolvable),
        ],
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
      _toastFailure(link.failure, retry: _open);
      return;
    }
    unawaited(context.push(RoomRoute(platform: room.platform, roomId: room.roomId).location));
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
      _toastFailure(link.failure, retry: _direct);
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
      _toastFailure(LinkToolFailure.failed, retry: _direct);
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

  /// Why the last resolve failed, as a toast; a transient failure offers
  /// the retry that re-runs the action whose resolve failed.
  void _toastFailure(LinkToolFailure? failure, {Future<void> Function()? retry}) {
    if (failure == null) return;
    final t = context.t;
    final message = switch (failure) {
      LinkToolFailure.empty => t.toolbox.linkEmpty,
      LinkToolFailure.unsupported => t.toolbox.linkUnsupported,
      LinkToolFailure.timeout => t.toolbox.linkTimeout,
      LinkToolFailure.failed => t.toolbox.linkFailed,
    };
    final action = retry != null && failure.isTransient ? retry : null;
    showDsToast(
      context: context,
      title: message,
      status: DsStatus.danger,
      actionLabel: action != null ? t.common.retry : null,
      onAction: action == null ? null : () => unawaited(action()),
    );
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
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final link = ref.watch(linkToolProvider);
    final resolving = link.resolving;
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
              // The two actions share one line and one width: the form is
              // an errand, not a page of buttons.
              Row(
                spacing: DsSpace.s12,
                children: [
                  Expanded(
                    child: DsButton(
                      variant: DsButtonVariant.primary,
                      loading: resolving,
                      onPressed: resolving ? null : () => unawaited(_open()),
                      child: Text(t.toolbox.linkOpen),
                    ),
                  ),
                  Expanded(
                    child: DsButton(
                      variant: DsButtonVariant.secondary,
                      loading: resolving,
                      onPressed: resolving ? null : () => unawaited(_direct()),
                      child: Text(t.toolbox.linkDirect),
                    ),
                  ),
                ],
              ),
              // The same errand, run by itself: reading the clipboard for a
              // room link belongs with the paste button above, not at the
              // page's bottom.
              DsLine(color: colors.border),
              Row(
                spacing: DsSpace.s12,
                children: [
                  const DsIcon(DsIcons.clipboard),
                  Expanded(child: Text(t.toolbox.linkClipboardRooms, style: theme.typography.body)),
                  DsSwitch(
                    value: ref.watch(detectClipboardRoomsProvider),
                    semanticLabel: t.toolbox.linkClipboardRooms,
                    onChanged: (value) => unawaited(ref.read(detectClipboardRoomsProvider.notifier).set(value: value)),
                  ),
                ],
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
      ],
    );
  }
}

/// The platforms whose links resolve: a full-width card, the badges laid
/// flat — no accordion to open, the catalogue reads at a glance.
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
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              const DsIcon(DsIcons.antenna, size: 16),
              Expanded(child: Text(t.toolbox.linkSupportTitle, style: theme.typography.body)),
              Text('${sites.length}', style: theme.typography.overline.copyWith(color: colors.textSubtle)),
            ],
          ),
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
    );
  }
}

/// A site's display name, falling back to its id (the settings page's own
/// resolution; the sites' names ship zh-CN first).
String _siteName(LiveSite site) => localizedSiteName(site);

/// The node test: every probe-able platform as a small tile with its own icon,
/// the answer it measured and a per-tile test, plus a sweep that checks
/// them four at a time. The design system's badges carry the state; no
/// fake endpoint strings are shown.
///
/// It is a settings page of its own, reached from the sites page's platform
/// group under the display row whose platforms it measures — it left the proxy
/// page, which shares nothing with it.
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
            // Small tiles: the count comes from the width rather than the
            // three-tier split, about 190 px per platform — one column on a
            // phone, five on a wide pane. The old three-per-row cards made
            // each platform a third of the page wide and a screen of them
            // tall.
            const tileWidth = 190.0;
            const gap = DsSpace.s8;
            final columns = (constraints.maxWidth / (tileWidth + gap)).floor().clamp(1, 5);
            final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
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

/// One platform's node tile: its icon and name with the state badge on the
/// first line, what the probe answered and a small 测速 button on the second.
/// Two lines because a dozen of these sit in one wall, and a card that stacked
/// four made the page a scroll of panels.
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
    // One detail line: which endpoint the tile probes before a test, and what
    // it answered after. The badge and the button's spinner already say
    // 测速中, so the line never repeats it. The button's tooltip carries the
    // hint, so the tile never needs a third line.
    final detail = Text(
      success != null
          ? '${success.elapsed.inMilliseconds} ms · ${t.toolbox.nodeAnswer(count: success.rooms)}'
          : failure != null
          ? failure.error.message
          : source,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.small.copyWith(color: failure != null ? colors.danger.text : colors.textMuted),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
      decoration: DsBoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        shadows: [DsShadow.innerRing(colors.border)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          Row(
            spacing: DsSpace.s6,
            children: [
              ?localizedSiteIcon(site, size: 18),
              Expanded(
                child: Text(
                  localizedSiteName(site),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                ),
              ),
              DsBadge(label: Text(status), status: badge, dot: false),
            ],
          ),
          Row(
            spacing: DsSpace.s6,
            children: [
              Expanded(
                child: failure == null ? detail : DsTooltip(message: failure.error.message, child: detail),
              ),
              DsTooltip(
                message: t.toolbox.nodeHint,
                child: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  loading: probing,
                  onPressed: probing ? null : onTest,
                  child: Text(t.toolbox.nodeTest),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The log console's head action: the gear that opens the settings surface
/// at the log section — the same page the sidebar reaches — where the
/// rotation limits, the folder and the diagnostics live. The shells' head
/// rows carry it, so it sits at the window's top-right on every width
/// instead of floating inside the console's own content.
final class LogsSettingsButton extends ConsumerWidget {
  /// The log settings gear.
  const LogsSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.md,
      semanticLabel: context.t.settings.navLogs,
      onPressed: () {
        openSettingsSection(ref, SettingsSection.logs);
        unawaited(context.push(SettingsSectionRoute(section: SettingsSection.logs.name).location));
      },
      icon: const DsIcon(DsIcons.settings, size: 18),
    );
  }
}

/// The log page: the journal's own configuration and diagnostics card above
/// the console — the records the running app wrote, searchable, following the
/// newest line until the viewer scrolls away from the bottom.
final class LogsPane extends ConsumerStatefulWidget {
  const LogsPane({super.key});

  @override
  ConsumerState<LogsPane> createState() => _LogsPaneState();
}

final class _LogsPaneState extends ConsumerState<LogsPane> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

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

  /// Writes the in-memory records beside the log files, so they can be read
  /// after the process ends; the toast names the file and opens its folder.
  Future<void> _save() async {
    final t = context.t;
    try {
      final file = await saveAppLogCopy();
      if (!mounted) return;
      showDsToast(
        context: context,
        title: t.toolbox.logsSaved,
        description: file.uri.pathSegments.last,
        actionLabel: t.toolbox.logsOpenFolder,
        onAction: () => unawaited(_openFolder(file.parent.path)),
      );
    } on Object {
      if (mounted) showDsToast(context: context, title: t.toolbox.logsSaveFailed, status: DsStatus.danger);
    }
  }

  Future<void> _openFolder(String path) async {
    await openDownloadedPath(context, path, failedTitle: context.t.settings.logOpenFailed);
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
        if (query.isEmpty ||
            record.message.toLowerCase().contains(query) ||
            record.category.toLowerCase().contains(query) ||
            record.fields.entries.any((entry) => '${entry.key} ${entry.value}'.toLowerCase().contains(query)))
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
        // The page keeps only the two things a viewer changes while reading:
        // what is recorded and whether a file is written. The rest — the
        // rotation limits and the folder — is the settings page's, behind the
        // gear, so the console below keeps the height.
        DsAccordion<String>(
          semanticLabel: t.toolbox.logsSection,
          items: [
            DsAccordionItem<String>(
              value: 'settings',
              title: Row(
                spacing: DsSpace.s8,
                children: [
                  const DsIcon(DsIcons.gauge, size: 16),
                  Flexible(child: Text(t.toolbox.logsSection)),
                ],
              ),
              child: const LogQuickSettings(),
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
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: DsSearchField(
                          controller: _search,
                          placeholder: t.toolbox.logsSearch,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        onPressed: () => unawaited(_clear()),
                        child: Text(t.toolbox.logsClear),
                      ),
                    ],
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
                      // The foot's three verbs: labelled buttons on a wide
                      // console, their icons alone where the width would
                      // otherwise overflow — the labels stay for the screen
                      // reader either way.
                      if (MediaQuery.sizeOf(context).width >= kLogsFootTextWidth) ...[
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
                          leading: const DsIcon(DsIcons.fileDown, size: 14),
                          onPressed: () => unawaited(_save()),
                          child: Text(t.toolbox.logsSave),
                        ),
                        DsButton(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.arrowDown, size: 14),
                          onPressed: _toBottom,
                          child: Text(t.toolbox.logsScrollBottom),
                        ),
                      ] else ...[
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.toolbox.logsExport,
                          onPressed: () => unawaited(_copy()),
                          icon: const DsIcon(DsIcons.copy, size: 16),
                        ),
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.toolbox.logsSave,
                          onPressed: () => unawaited(_save()),
                          icon: const DsIcon(DsIcons.fileDown, size: 16),
                        ),
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.toolbox.logsScrollBottom,
                          onPressed: _toBottom,
                          icon: const DsIcon(DsIcons.arrowDown, size: 16),
                        ),
                      ],
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
