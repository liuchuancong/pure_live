import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_log/live_log.dart' show LogLevel, LogRecord;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/logging/app_log.dart'
    show
        appLogFileEnabled,
        appLogLevel,
        clearAppLog,
        exportAppLog,
        setAppLogFileEnabled,
        setAppLogLevel;
import 'package:pure_live/app/providers/log_providers.dart' show appLogRecordsProvider;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/toolbox/toolbox_controllers.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteIcon, localizedSiteName;

/// The master-detail breakpoint (the settings page's own): below it the
/// tools are one list and a tool opens in place; above it the list sits in
/// a sidebar beside the open tool's pane.
const double _kToolboxSplitWidth = 768;

/// One tool the toolbox offers.
enum ToolboxTool {
  link(DsIcons.link),
  network(DsIcons.activity),
  cache(DsIcons.broom),
  logs(DsIcons.terminal);

  ToolboxTool(this.icon);

  /// The tool's icon.
  final DsIconData icon;

  /// The tool's name.
  String label(Translations t) => switch (this) {
    ToolboxTool.link => t.toolbox.toolLinkTitle,
    ToolboxTool.network => t.toolbox.toolNetworkTitle,
    ToolboxTool.cache => t.toolbox.toolCacheTitle,
    ToolboxTool.logs => t.toolbox.toolLogsTitle,
  };

  /// One line on what the tool does.
  String description(Translations t) => switch (this) {
    ToolboxTool.link => t.toolbox.toolLinkDescription,
    ToolboxTool.network => t.toolbox.toolNetworkDescription,
    ToolboxTool.cache => t.toolbox.toolCacheDescription,
    ToolboxTool.logs => t.toolbox.toolLogsDescription,
  };
}

/// The toolbox's groups, top to bottom: (slang key of the group label, its
/// tools). Group labels resolve through the toolbox namespace.
const List<(String, List<ToolboxTool>)> kToolboxGroups = [
  ('groupLinks', [ToolboxTool.link]),
  ('groupNetwork', [ToolboxTool.network]),
  ('groupData', [ToolboxTool.cache, ToolboxTool.logs]),
];

/// A group label's words.
String toolboxGroupLabel(Translations t, String key) => switch (key) {
  'groupLinks' => t.toolbox.groupLinks,
  'groupNetwork' => t.toolbox.groupNetwork,
  'groupData' => t.toolbox.groupData,
  _ => key,
};

/// The link parser (the reference's link parser; its link tool, grown into a
/// surface of its own): the tools as grouped list rows — a wide window shows
/// the groups in a sidebar beside the open tool's pane, and under the
/// breakpoint the list stands alone and a tool opens in its place.
///
/// The tools that can already work do: the link resolver walks the sites'
/// own `LiveLinkResolver` capabilities, the network check probes one
/// site's real feed endpoint, the cache pane clears the image cache. The
/// log viewer is honest about the wait.
final class ToolboxPage extends ConsumerStatefulWidget {
  /// The toolbox page.
  const ToolboxPage({super.key});

  @override
  ConsumerState<ToolboxPage> createState() => _ToolboxPageState();
}

final class _ToolboxPageState extends ConsumerState<ToolboxPage> {
  /// The open tool; null on a narrow window means the list is showing.
  ToolboxTool? _selected;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final compact = MediaQuery.sizeOf(context).width < _kToolboxSplitWidth;
    if (compact) {
      final selected = _selected;
      if (selected == null) return _ToolList(onSelected: (tool) => setState(() => _selected = tool));
      return _ToolPane(tool: selected, onBack: () => setState(() => _selected = null));
    }
    // A wide window always shows a pane; the link tool opens with the page.
    final selected = _selected ?? ToolboxTool.link;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The navigation column, scrollable on its own; the pane beside it
        // never scrolls with it.
        SizedBox(
          width: 264,
          child: ColoredBox(
            color: colors.sidebar,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s16, DsSpace.s12, DsSpace.s24),
              child: _ToolMenu(selected: selected, onSelected: (tool) => setState(() => _selected = tool)),
            ),
          ),
        ),
        Expanded(child: _ToolPane(tool: selected)),
      ],
    );
  }
}

/// The tool groups as list sections: the mobile list's body and the
/// desktop column's body, one card per group. A desktop row marks the open
/// tool ([selected]); a mobile row carries the chevron that says "opens".
final class _ToolSections extends StatelessWidget {
  const _ToolSections({required this.selected, required this.onSelected, required this.markSelected});

  /// The open tool, marked on its row (desktop only).
  final ToolboxTool selected;

  /// Fired when a tool's row is pressed.
  final ValueChanged<ToolboxTool> onSelected;

  /// Whether the open tool's row takes the selection style (desktop) or
  /// every row stays plain with a chevron (mobile).
  final bool markSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        for (final (groupKey, tools) in kToolboxGroups)
          DsListSection(
            header: Text(toolboxGroupLabel(t, groupKey)),
            children: [
              for (final tool in tools)
                DsListRow(
                  leading: DsIcon(tool.icon),
                  title: Text(tool.label(t)),
                  description: Text(tool.description(t)),
                  selected: markSelected && tool == selected,
                  onPressed: () => onSelected(tool),
                  trailing: markSelected ? null : const DsIcon(DsIcons.chevronRight),
                ),
            ],
          ),
      ],
    );
  }
}

/// The mobile list: the tools, one card per group, each row opening its
/// tool in place.
final class _ToolList extends StatelessWidget {
  const _ToolList({required this.onSelected});

  /// Fired when a tool's row is pressed.
  final ValueChanged<ToolboxTool> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: DsSpace.s24),
      child: _ToolSections(selected: ToolboxTool.link, onSelected: onSelected, markSelected: false),
    );
  }
}

/// The desktop column: the same groups, the open tool's row highlighted.
final class _ToolMenu extends StatelessWidget {
  const _ToolMenu({required this.selected, required this.onSelected});

  /// The highlighted tool.
  final ToolboxTool selected;

  /// Fired when a tool's row is pressed.
  final ValueChanged<ToolboxTool> onSelected;

  @override
  Widget build(BuildContext context) {
    return _ToolSections(selected: selected, onSelected: onSelected, markSelected: true);
  }
}

/// One tool's pane: the tool's name as the headline, its description, then
/// the tool's own surface. A narrow window carries the back affordance
/// that returns to the list.
final class _ToolPane extends StatelessWidget {
  const _ToolPane({required this.tool, this.onBack});

  /// The tool whose surface shows.
  final ToolboxTool tool;

  /// Returns to the list (mobile only; null on the desktop pane).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final body = switch (tool) {
      ToolboxTool.link => const _LinkPane(),
      ToolboxTool.network => const _NetworkPane(),
      ToolboxTool.cache => const _CachePane(),
      ToolboxTool.logs => const _LogsPane(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s20, DsSpace.s24, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          if (onBack != null)
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: onBack,
              leading: const DsIcon(DsIcons.chevronLeft),
              child: Text(t.toolbox.back),
            ),
          Text(tool.label(t), style: theme.typography.display.copyWith(color: colors.text)),
          Text(tool.description(t), style: theme.typography.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: DsSpace.s12),
          body,
        ],
      ),
    );
  }
}

/// The link tool (the reference's page, cut to what this codebase can do):
/// a multi-line field for the pasted link — share texts included — the two
/// actions beside it, the room the last resolve found, and the platforms
/// whose links resolve at all.
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
      builder: (context) => _DirectLinkDialog(room: room, playback: playback, qualities: qualities),
    );
  }

  /// Puts the clipboard's text in the field, replacing whatever is there.
  Future<void> _paste() async {
    final text = await Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text);
    if (!mounted || text == null || text.trim().isEmpty) return;
    _field.text = text.trim();
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
    final resolvable = [
      for (final site in ref.watch(sitesProvider).all)
        if (site.capability<LiveLinkResolver>() != null) site,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.toolbox.linkFieldLabel),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
              child: DsTextField.multiline(
                controller: _field,
                onChanged: (_) => _edited(),
                placeholder: t.toolbox.linkFieldHint,
                minLines: 2,
                maxLines: 4,
                semanticLabel: t.toolbox.linkFieldLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: Row(
                children: [
                  DsButton(
                    variant: DsButtonVariant.ghost,
                    onPressed: link.resolving ? null : () => unawaited(_paste()),
                    leading: const DsIcon(DsIcons.clipboardPaste),
                    child: Text(t.toolbox.linkPaste),
                  ),
                  const SizedBox(width: DsSpace.s8),
                  DsButton(
                    variant: DsButtonVariant.ghost,
                    onPressed: _hasText ? _field.clear : null,
                    leading: const DsIcon(DsIcons.close),
                    child: Text(t.toolbox.linkClear),
                  ),
                  if (link.resolving) ...[
                    const Spacer(),
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      onPressed: () => ref.read(linkToolProvider.notifier).reset(),
                      leading: const DsIcon(DsIcons.x),
                      child: Text(t.toolbox.cancel),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
              child: Row(
                children: [
                  Expanded(
                    child: DsButton(
                      variant: DsButtonVariant.primary,
                      loading: link.resolving,
                      onPressed: link.resolving ? null : () => unawaited(_open()),
                      child: Text(t.toolbox.linkOpen),
                    ),
                  ),
                  const SizedBox(width: DsSpace.s8),
                  Expanded(
                    child: DsButton(
                      variant: DsButtonVariant.secondary,
                      loading: link.resolving,
                      onPressed: link.resolving ? null : () => unawaited(_copy()),
                      child: Text(t.toolbox.linkCopy),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
              child: DsButton(
                variant: DsButtonVariant.ghost,
                onPressed: link.resolving ? null : () => unawaited(_direct()),
                leading: const DsIcon(DsIcons.link2),
                child: Text(t.toolbox.linkDirect),
              ),
            ),
          ],
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
        DsListSection(
          header: Row(
            children: [
              Expanded(child: Text(t.toolbox.linkSupportTitle)),
              Text(
                '${resolvable.length}',
                style: DsTheme.of(context).typography.overline.copyWith(color: DsTheme.colorsOf(context).textSubtle),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s4),
              child: Text(
                t.toolbox.linkSupportHint,
                style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textSubtle),
              ),
            ),
            for (final site in resolvable)
              DsListRow(
                leading: localizedSiteIcon(site, size: 20) ?? const DsIcon(DsIcons.antenna),
                title: Text(_siteName(site)),
                description: Text(site.manifest.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// The room's direct stream links: the quality picker over the lines the
/// site answered for it, each URL with its own copy action. The reference's
/// The direct-stream-link action, over the same capability the player uses.
final class _DirectLinkDialog extends ConsumerStatefulWidget {
  const _DirectLinkDialog({required this.room, required this.playback, required this.qualities});

  final LiveRoom room;
  final LivePlaybackProvider playback;
  final List<LivePlayQuality> qualities;

  @override
  ConsumerState<_DirectLinkDialog> createState() => _DirectLinkDialogState();
}

final class _DirectLinkDialogState extends ConsumerState<_DirectLinkDialog> {
  int _quality = 0;
  List<LivePlayLine> _lines = const [];
  bool _loading = true;
  String? _error;

  /// Drops a superseded answer when the viewer flips quality quickly.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final answer = await widget.playback.getLines(
      room: widget.room,
      quality: widget.qualities[_quality.clamp(0, widget.qualities.length - 1)],
    );
    if (!mounted || generation != _generation) return;
    answer.match(
      (error) => setState(() {
        _loading = false;
        _error = error.message;
      }),
      (lines) => setState(() {
        _loading = false;
        _lines = lines;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.toolbox.linkDirectTitle),
      description: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s12,
          children: [
            if (widget.qualities.length > 1)
              DsSelect<int>(
                value: _quality,
                onChanged: (value) {
                  if (value == null || value == _quality) return;
                  setState(() => _quality = value);
                  unawaited(_load());
                },
                options: [
                  for (final (index, quality) in widget.qualities.indexed)
                    DsSelectOption(value: index, label: quality.label),
                ],
                semanticLabel: t.toolbox.linkDirectQuality,
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: DsSpace.s24),
                child: Center(child: DsSpinner()),
              )
            else if (_error != null)
              DsAlert(
                status: DsStatus.danger,
                title: Text(t.toolbox.linkDirectFailed),
                description: Text(_error!),
              )
            else if (_lines.isEmpty)
              DsEmptyState(icon: const DsIcon(DsIcons.link2), title: Text(t.toolbox.linkDirectEmpty))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: DsListSection(
                    header: Text(t.toolbox.linkDirectLines),
                    children: [
                      for (final (index, line) in _lines.indexed)
                        DsListRow(
                          leading: const DsIcon(DsIcons.link2),
                          title: Text(line.lineLabel ?? t.room.line(n: index + 1)),
                          description: Text(line.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: DsButton(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            onPressed: () => unawaited(_copy(line)),
                            child: Text(t.toolbox.linkDirectCopy),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }

  Future<void> _copy(LivePlayLine line) async {
    await Clipboard.setData(ClipboardData(text: line.url));
    if (mounted) {
      showDsToast(context: context, title: context.t.toolbox.linkDirectCopyDone);
    }
  }
}

/// A site's display name, falling back to its id (the settings page's own
/// resolution; the sites' names ship zh-CN first).
String _siteName(LiveSite site) => localizedSiteName(site);

/// The node test: every probe-able platform as a card with its own icon,
/// the last measured latency and a per-card test, plus a sweep that checks
/// them four at a time. The design system's badges carry the state; no
/// fake endpoint strings are shown.
final class _NetworkPane extends ConsumerWidget {
  const _NetworkPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final sites = probeSites(ref.watch(sitesProvider).all);
    if (sites.isEmpty) {
      return DsEmptyState(
        icon: const DsIcon(DsIcons.cloudOff),
        title: Text(t.toolbox.nodeNoSites),
      );
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
            final columns = constraints.maxWidth >= 960
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;
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
            Text(
              t.toolbox.nodeHint,
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
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

/// The cache pane: what the image cache holds right now and the confirm
/// that releases it — the only cache this codebase keeps (the images load
/// through Flutter's own [ImageCache]).
final class _CachePane extends ConsumerStatefulWidget {
  const _CachePane();

  @override
  ConsumerState<_CachePane> createState() => _CachePaneState();
}

final class _CachePaneState extends ConsumerState<_CachePane> {
  /// Asks, then releases: the loaded pictures download again; the stored
  /// data (favorites, history) never touches the image cache.
  Future<void> _clear() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.toolbox.cacheConfirmTitle,
      description: t.toolbox.cacheConfirmDesc,
      confirmLabel: t.toolbox.confirm,
      cancelLabel: t.toolbox.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.broom),
    );
    if (!confirmed || !mounted) return;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (!mounted) return;
    setState(() {});
    showDsToast(context: context, title: t.toolbox.cacheDone);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final cache = PaintingBinding.instance.imageCache;
    final entries = cache.currentSize;
    final bytes = cache.currentSizeBytes;
    return DsListSection(
      header: Text(t.toolbox.cacheSection),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.image),
          title: Text(t.toolbox.cacheEntries),
          detail: Text(entries == 0 ? t.toolbox.cacheEmpty : '$entries'),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.database),
          title: Text(t.toolbox.cacheSize),
          detail: Text(entries == 0 ? t.toolbox.cacheEmpty : _formatBytes(bytes)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.broom),
          title: Text(t.toolbox.cacheClear),
          description: Text(t.toolbox.cacheClearDesc),
          destructive: true,
          onPressed: entries == 0 ? null : () => unawaited(_clear()),
        ),
        // The disk cache (a download directory, a media cache) arrives with
        // the features that own it.
        Padding(
          padding: const EdgeInsets.all(DsSpace.s12),
          child: Text(t.toolbox.comingSoonDesc, style: theme.typography.small.copyWith(color: colors.textSubtle)),
        ),
      ],
    );
  }

  /// A byte figure at the unit the figure itself picks.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// The log page: the live tree's memory ring (the rotating file writes the
/// same records), a level control, a file-write switch, search, and a log
/// panel that follows the newest line until the viewer scrolls away from
/// the bottom.
final class _LogsPane extends ConsumerStatefulWidget {
  const _LogsPane();

  @override
  ConsumerState<_LogsPane> createState() => _LogsPaneState();
}

final class _LogsPaneState extends ConsumerState<_LogsPane> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  LogLevel _level = appLogLevel;
  bool _fileEnabled = appLogFileEnabled;
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
        if (record.level.isAtLeast(_level) &&
            (query.isEmpty ||
                record.message.toLowerCase().contains(query) ||
                record.category.toLowerCase().contains(query) ||
                record.fields.entries.any(
                  (entry) => '${entry.key} ${entry.value}'.toLowerCase().contains(query),
                )))
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
        DsListSection(
          header: Text(t.toolbox.logsSection),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.layers),
              title: Text(t.toolbox.logsLevel),
              trailing: SizedBox(
                width: 160,
                child: DsSelect<LogLevel>(
                  value: _level,
                  onChanged: (level) {
                    if (level == null) return;
                    setAppLogLevel(level);
                    setState(() => _level = level);
                  },
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
                  semanticLabel: t.toolbox.logsLevel,
                ),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.hardDrive),
              title: Text(t.toolbox.logsFile),
              description: Text(t.toolbox.logsFileDesc),
              trailing: DsSwitch(
                value: _fileEnabled,
                onChanged: (value) {
                  setAppLogFileEnabled(enabled: value);
                  setState(() => _fileEnabled = value);
                },
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.copy),
              title: Text(t.toolbox.logsExport),
              description: Text(t.toolbox.logsExportDesc),
              onPressed: () => unawaited(_copy()),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.trash2),
              title: Text(t.toolbox.logsClear),
              description: Text(t.toolbox.logsClearDesc),
              destructive: true,
              onPressed: () => unawaited(_clear()),
            ),
          ],
        ),
        DsSearchField(
          controller: _search,
          placeholder: t.toolbox.logsSearch,
          onChanged: (_) => setState(() {}),
        ),
        Container(
          height: 440,
          decoration: DsBoxDecoration(
            color: colors.channel,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: [DsShadow.innerRing(colors.border)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        padding: const EdgeInsets.all(DsSpace.s8),
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
              text: '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${two(time.millisecond).padLeft(3, '0')} ',
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
            TextSpan(text: record.message, style: mono.copyWith(color: colors.text)),
            if (fields.isNotEmpty) TextSpan(text: fields, style: mono.copyWith(color: colors.textMuted)),
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
