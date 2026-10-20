import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The toolbox (3.x `ToolBoxPage`): two tool cards, each an expanded tile
/// over a paste field and a full-width action.
///
/// - Jump to Room (3.x `toolbox_room_jump`): a platform link resolves to its
///   canonical room, which opens.
/// - Get Direct Link (3.x `toolbox_get_direct_link`): the same resolution,
///   then quality → line picks and the play URL onto the clipboard. The
///   card's footer — outside the tile, so it stays visible folded — is the
///   supported-formats list.
///
/// The resolvers come from the site registry itself — a platform whose links
/// are understood is exactly one that ships the link resolver capability,
/// and the direct-link tool needs the playback capability on top. The
/// clipboard check on open is the reference's `autoCheckClipboard`: a link
/// already on the clipboard fills the first empty field.
enum _Tool {
  /// 3.x `ToolBoxAction.jump` — follow a link into its room.
  jump,

  /// 3.x `ToolBoxAction.directLink` — export the direct play URL.
  directLink,
}

/// The toolbox page (3.x `ToolBoxPage`).
final class ToolboxPage extends ConsumerStatefulWidget {
  /// The toolbox page.
  const new({super.key});

  @override
  ConsumerState<ToolboxPage> createState() => _ToolboxPageState();
}

final class _ToolboxPageState extends ConsumerState<ToolboxPage> {
  final _link = TextEditingController();
  _Tool? _busy;
  int _generation = 0;
  bool _clipboardChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_autoCheckClipboard());
      }
    });
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// A running action is abandoned by bumping the generation: every await in
  /// the flow re-checks it, and stale completions never touch the state.
  void _cancel() {
    _generation++;
    if (mounted) {
      setState(() => _busy = null);
    }
  }

  void _toast(String message, {PureToastType type = PureToastType.error}) {
    if (mounted) {
      PureToast.show(context, message, type: type);
    }
  }

  /// Reference `autoCheckClipboard`: the opening page adopts a clipboard
  /// link it can use. Local detection only — the text must already look
  /// like a URL; recognising platforms is the resolvers' job.
  Future<void> _autoCheckClipboard() async {
    if (_clipboardChecked || _busy != null) {
      return;
    }
    _clipboardChecked = true;
    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on Object {
      return;
    }
    final text = data?.text?.trim() ?? '';
    final uri = Uri.tryParse(text);
    if (!mounted || _link.text.isNotEmpty || text.isEmpty || uri == null || !uri.hasScheme) {
      return;
    }
    setState(() => _link.text = text);
    _toast(context.t.toolbox.autoFill, type: PureToastType.info);
  }

  /// Tries every resolver; the first that owns the link wins. Sequential on
  /// purpose — resolvers follow short links, and a fan-out would fire the
  /// same follow at a dozen hosts.
  Future<({String site, String roomId})?> _resolve(String text, int generation) async {
    final uri = Uri.tryParse(text);
    if (text.isEmpty || uri == null || !uri.hasScheme) {
      _toast(context.t.toolbox.emptyLink);
      return null;
    }
    // Read before the awaits, so no message needs the context after one.
    final failed = context.t.toolbox.parseFailed;
    final resolvers = ref
        .read(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveLinkResolver>() != null)
        .toList();
    for (final site in resolvers) {
      if (generation != _generation) {
        return null;
      }
      final result = await site.capability<LiveLinkResolver>()!.resolve(uri);
      final owned = result.fold((failure) => null, (canonical) => canonical);
      if (owned != null) {
        return (site: site.manifest.id, roomId: owned.pathSegments.last);
      }
    }
    _toast(failed);
    return null;
  }

  /// 3.x `jumpToRoom`: resolve, then open the room.
  Future<void> _jumpToRoom() async {
    final text = _link.text.trim();
    if (text.isEmpty) {
      _toast(context.t.toolbox.emptyLink);
      return;
    }
    if (_busy != null) {
      return;
    }
    final generation = ++_generation;
    setState(() => _busy = _Tool.jump);
    try {
      final resolved = await _resolve(text, generation);
      if (resolved == null || generation != _generation || !mounted) {
        return;
      }
      unawaited(
        RoomRoute(siteId: resolved.site, roomId: resolved.roomId, roomName: resolved.roomId).push<void>(context),
      );
    } finally {
      if (generation == _generation && mounted) {
        setState(() => _busy = null);
      }
    }
  }

  /// 3.x `getPlayUrl`: resolve, pick a quality, pick a line, copy the play
  /// URL. The clipboard is the export — the app has no external-player
  /// hand-off to jump to.
  Future<void> _exportDirectLink() async {
    final text = _link.text.trim();
    if (text.isEmpty) {
      _toast(context.t.toolbox.emptyLink);
      return;
    }
    if (_busy != null) {
      return;
    }
    final generation = ++_generation;
    setState(() => _busy = _Tool.directLink);
    try {
      final resolved = await _resolve(text, generation);
      if (resolved == null || generation != _generation || !mounted) {
        return;
      }
      final playback = ref.read(playbackProvider(resolved.site));
      if (playback == null) {
        _toast(context.t.toolbox.getUrlFailed);
        return;
      }
      final qualities = (await playback.getQualities(roomId: resolved.roomId))
          .fold((failure) => <LivePlayQuality>[], (qualities) => qualities);
      if (generation != _generation || !mounted) {
        return;
      }
      if (qualities.isEmpty) {
        _toast(context.t.toolbox.getUrlFailed);
        return;
      }
      final quality = await _choose<LivePlayQuality>(
        context,
        context.t.toolbox.selectQuality,
        qualities,
        label: (quality, index) => quality.label,
      );
      if (quality == null || generation != _generation || !mounted) {
        return;
      }
      final lines = (await playback.getLines(
        roomId: resolved.roomId,
        quality: quality,
      )).fold((failure) => <LivePlayLine>[], (lines) => lines);
      if (generation != _generation || !mounted) {
        return;
      }
      if (lines.isEmpty) {
        _toast(context.t.toolbox.getUrlFailed);
        return;
      }
      final line = await _choose<LivePlayLine>(
        context,
        context.t.toolbox.selectLine,
        lines,
        label: (line, index) => context.t.toolbox.line(index: index + 1),
        subtitle: (line) => line.url,
      );
      if (line == null || generation != _generation || !mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: line.url));
      if (!mounted) {
        return;
      }
      _toast(context.t.toolbox.copySuccess, type: PureToastType.success);
    } on Object {
      if (mounted) {
        _toast(context.t.toolbox.getUrlFailed);
      }
    } finally {
      if (generation == _generation && mounted) {
        setState(() => _busy = null);
      }
    }
  }

  /// The quality/line pick dialog (3.x `_choose`): centred rows over a
  /// cancel.
  Future<T?> _choose<T>(
    BuildContext context,
    String title,
    List<T> items, {
    required String Function(T item, int index) label,
    String Function(T item)? subtitle,
  }) {
    return showPureDialog<T>(
      context: context,
      title: title,
      maxWidth: 560,
      child: Builder(
        builder: (dialogContext) => ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  ListTile(
                    title: Text(label(items[i], i), textAlign: TextAlign.center),
                    subtitle: subtitle == null
                        ? null
                        : Text(
                            subtitle(items[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                    onTap: () => Navigator.of(dialogContext).pop(items[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PureScaffold(
      appBar: PureAppBar(title: context.t.toolbox.title, actions: const [SettingsEntryButton()]),
      body: ListView(
        key: const ValueKey('toolbox-scroll'),
        padding: const EdgeInsets.all(12),
        children: [
          Center(
            child: ConstrainedBox(
              // c9: the cards of the settings pages, at most 720 wide.
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _linkCard(context),
                  const SizedBox(height: 16),
                  _syncCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The LAN sync tile (3.x `RemoteSyncPage` behind the tool box): the third
  /// tool card, a row instead of a paste tile — the sync page carries its own
  /// discovery and address entry.
  Widget _syncCard(BuildContext context) {
    final theme = PureTheme.of(context);
    return PureCard(
      padding: EdgeInsets.zero,
      child: PureListRow(
        leading: Icon(Icons.sync, color: theme.colors.primary),
        title: context.t.remoteSync.title,
        subtitle: context.t.remoteSync.tileSubtitle,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(context.push<void>(RoutePath.remoteSync)),
        divided: false,
      ),
    );
  }

  /// The card of the link (the reference's `_LinkCard`, c2/c3/c5/c6): a line
  /// on what it does, the box (paste when empty, clear when not), the two
  /// actions side by side, and what is being done with "取消" while an
  /// action runs. The supported-formats list sits at the card's foot.
  Widget _linkCard(BuildContext context) {
    final theme = PureTheme.of(context);
    final busy = _busy;
    return PureCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.link, color: theme.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t.toolbox.title,
                    style: theme.text.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (busy == null)
                  PureIconButton(
                    tooltip: context.t.common.clear,
                    icon: Icons.clear_rounded,
                    size: ControlSize.sm,
                    onPressed: _link.text.isEmpty ? null : () => setState(_link.clear),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: PureTextField(
              controller: _link,
              placeholder: context.t.toolbox.inputHint,
              maxLines: 4,
              keyboardType: TextInputType.url,
              enabled: busy == null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: PureButton(
                    label: context.t.toolbox.linkJump,
                    icon: Icons.play_circle_outline,
                    expand: true,
                    loading: busy == _Tool.jump,
                    onPressed: busy == null ? () => unawaited(_jumpToRoom()) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PureButton(
                    label: context.t.toolbox.directLink,
                    icon: Icons.link,
                    variant: ButtonVariant.secondary,
                    expand: true,
                    loading: busy == _Tool.directLink,
                    onPressed: busy == null ? () => unawaited(_exportDirectLink()) : null,
                  ),
                ),
              ],
            ),
          ),
          if (busy != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: PureButton(
                  label: context.t.common.cancel,
                  variant: ButtonVariant.ghost,
                  size: ControlSize.sm,
                  onPressed: _cancel,
                ),
              ),
            ),
          _supportFooter(context),
        ],
      ),
    );
  }

  /// The direct-link card's footer (3.x `_buildDescription`): the supported
  /// formats, selectable so they can be copied.
  Widget _supportFooter(BuildContext context) {
    final theme = PureTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PureDivider(),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: theme.colors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.t.toolbox.supportList,
                style: theme.text.caption.copyWith(color: theme.colors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          context.t.toolbox.supportContent,
          style: theme.text.caption.copyWith(color: theme.colors.textSecondary, height: 1.6),
        ),
      ],
    );
  }
}
