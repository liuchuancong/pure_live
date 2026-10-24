import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/toolbox/toolbox_controllers.dart';
import 'package:pure_live/l10n/translations.dart';

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

/// The toolbox (the reference's link tool, grown into a surface of its
/// own): the tools as grouped list rows — a wide window shows the groups
/// in a sidebar beside the open tool's pane, and under the breakpoint the
/// list stands alone and a tool opens in its place.
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
  void dispose() {
    _field.dispose();
    super.dispose();
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
                leading: const DsIcon(DsIcons.antenna),
                title: Text(_siteName(site)),
                description: Text(site.manifest.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// A site's display name, falling back to its id (the settings page's own
/// resolution; the sites' names ship zh-CN first).
String _siteName(LiveSite site) => site.manifest.name['zh-CN'] ?? site.manifest.id;

/// The network check: pick one of the platforms that answer a cheap page
/// call, run it, and read the answer — the endpoint, its latency, what it
/// returned, or how it failed.
final class _NetworkPane extends ConsumerStatefulWidget {
  const _NetworkPane();

  @override
  ConsumerState<_NetworkPane> createState() => _NetworkPaneState();
}

final class _NetworkPaneState extends ConsumerState<_NetworkPane> {
  /// The site the check runs on; null means the selected site's default.
  String? _siteId;

  /// Runs the check on the pane's current site.
  void _run() {
    final sites = probeSites(ref.read(sitesProvider).all);
    if (sites.isEmpty) return;
    unawaited(ref.read(networkProbeProvider.notifier).run(_currentSiteId(sites)));
  }

  /// The pane's site: the picker's own choice, else the browsing surfaces'
  /// site when it can be probed, else the first probe-able one.
  String _currentSiteId(List<LiveSite> sites) {
    if (_siteId != null) return _siteId!;
    final preferred = ref.read(selectedSiteIdProvider);
    return sites.any((site) => site.manifest.id == preferred) ? preferred : sites.first.manifest.id;
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
    final probe = ref.watch(networkProbeProvider);
    final sites = probeSites(ref.watch(sitesProvider).all);
    if (sites.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.toolbox.comingSoonTitle),
          description: Text(t.toolbox.networkUnsupported),
        ),
      );
    }
    final selectedId = _currentSiteId(sites);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.toolbox.networkSiteLabel),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
              child: DsSelect<String>(
                value: selectedId,
                onChanged: (id) {
                  if (id != null) setState(() => _siteId = id);
                },
                options: [for (final site in sites) DsSelectOption(value: site.manifest.id, label: _siteName(site))],
                leading: const DsIcon(DsIcons.antenna),
                semanticLabel: t.toolbox.networkSiteLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
              child: DsButton(
                variant: DsButtonVariant.primary,
                loading: probe.probing,
                onPressed: probe.probing ? null : _run,
                child: Text(t.toolbox.networkRun),
              ),
            ),
          ],
        ),
        if (probe.probing)
          Padding(
            padding: const EdgeInsets.all(DsSpace.s12),
            child: Text(
              t.toolbox.networkBusy,
              style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textSubtle),
            ),
          ),
        // The result names the site the run probed (its own record), so a
        // picker moved after the run does not dress the old answer in the
        // new site's name.
        if (!probe.probing)
          switch (probe.outcome) {
            null => const SizedBox.shrink(),
            final ProbeOutcome outcome => _ProbeResult(
              siteName: _siteNameById(probe.siteId ?? selectedId),
              outcome: outcome,
            ),
          },
      ],
    );
  }
}

/// One check's answer as a card: the endpoint that was probed, whether it
/// answered (a badge), and what came back or how it failed.
final class _ProbeResult extends StatelessWidget {
  const _ProbeResult({required this.siteName, required this.outcome});

  /// The display name of the site the run probed.
  final String siteName;

  /// The run's outcome.
  final ProbeOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsListSection(
      header: Text(t.toolbox.networkResultTitle),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.antenna),
          title: Text(t.toolbox.networkTarget),
          description: Text(siteName),
          detail: Text(t.toolbox.networkTargetDesc),
          trailing: switch (outcome) {
            ProbeSuccess() => DsBadge(label: Text(t.toolbox.networkSuccess), status: DsStatus.success),
            ProbeFailure() => DsBadge(label: Text(t.toolbox.networkFailure), status: DsStatus.danger),
          },
        ),
        switch (outcome) {
          ProbeSuccess(:final elapsed) => DsListRow(
            leading: const DsIcon(DsIcons.timer),
            title: Text(t.toolbox.networkLatency),
            detail: Text('${elapsed.inMilliseconds} ms'),
          ),
          ProbeFailure(:final error) => DsListRow(
            leading: const DsIcon(DsIcons.cloudOff),
            title: Text(t.toolbox.networkFailure),
            description: Text(error.message),
          ),
        },
        if (outcome case ProbeSuccess(:final rooms))
          DsListRow(leading: const DsIcon(DsIcons.tv), title: Text(t.toolbox.networkRooms), detail: Text('$rooms')),
      ],
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

/// The log viewer's floor: honest about the wait (the log store has no
/// reader surface yet).
final class _LogsPane extends StatelessWidget {
  const _LogsPane();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
      child: Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.hammer),
          title: Text(t.toolbox.comingSoonTitle),
          description: Text(t.toolbox.comingSoonDesc),
        ),
      ),
    );
  }
}
