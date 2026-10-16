import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveLinkResolver;
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The toolbox (3.x `lib/modules/toolbox`): paste a platform link, the
/// resolver that owns it follows it to the canonical room, and the room
/// opens.
///
/// The resolvers come from the site registry itself — a platform whose
/// links are understood is exactly one that ships the link resolver
/// capability. Unrecognised links fail with an honest message; a resolved
/// room's id is the canonical URL's last segment, the shape every current
/// resolver normalises to.
final class ToolboxPage extends ConsumerStatefulWidget {
  /// The toolbox page.
  const new({super.key});

  @override
  ConsumerState<ToolboxPage> createState() => _ToolboxPageState();
}

final class _ToolboxPageState extends ConsumerState<ToolboxPage> {
  final _link = TextEditingController();
  bool _resolving = false;
  String? _failure;
  ({String site, String roomId, Uri url})? _resolved;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// Tries every resolver; the first that owns the link wins. Sequential
  /// on purpose — resolvers follow short links, and a fan-out would fire
  /// the same follow at a dozen hosts.
  Future<void> _resolve() async {
    final text = _link.text.trim();
    final uri = Uri.tryParse(text);
    if (text.isEmpty || uri == null || !uri.hasScheme) {
      setState(() => _failure = context.t.toolbox.hint);
      return;
    }
    setState(() {
      _resolving = true;
      _failure = null;
      _resolved = null;
    });
    final resolvers = ref
        .read(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveLinkResolver>() != null)
        .toList();
    for (final site in resolvers) {
      final result = await site.capability<LiveLinkResolver>()!.resolve(uri);
      final owned = result.fold((failure) => null, (canonical) => canonical);
      if (owned != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _resolved = (site: site.manifest.id, roomId: owned.pathSegments.last, url: owned);
          _resolving = false;
        });
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _failure = context.t.toolbox.failed;
      _resolving = false;
    });
  }

  Future<void> _readClipboard() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (text.trim().isEmpty) {
      return;
    }
    _link.text = text.trim();
    unawaited(_resolve());
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    return LiveScaffold(
      appBar: LiveAppBar(title: context.t.toolbox.title, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SearchBar(
            controller: _link,
            hintText: context.t.toolbox.hint,
            onSubmitted: (_) => unawaited(_resolve()),
            trailing: [
              LiveIconButton(
                tooltip: context.t.toolbox.readClipboard,
                icon: Icons.content_paste,
                onPressed: _readClipboard,
              ),
              LiveIconButton(
                tooltip: context.t.toolbox.resolve,
                icon: Icons.travel_explore,
                onPressed: _resolving ? null : _resolve,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_resolving)
            const Center(child: LiveSpinner(size: 40))
          else if (resolved != null)
            _resolvedCard(context, resolved)
          else ...[
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_failure!, style: TextStyle(color: LiveTheme.of(context).colors.error)),
              ),
            LiveEmpty(title: context.t.toolbox.hint),
          ],
        ],
      ),
    );
  }

  Widget _resolvedCard(BuildContext context, ({String site, String roomId, Uri url}) resolved) => LiveCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(resolved.site, style: LiveTheme.of(context).text.caption),
        const SizedBox(height: 4),
        Text(resolved.roomId, style: LiveTheme.of(context).text.title),
        const SizedBox(height: 4),
        Text(
          resolved.url.toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: LiveTheme.of(context).text.caption,
        ),
        const SizedBox(height: 12),
        LiveButton(
          label: context.t.toolbox.openRoom,
          icon: Icons.play_circle_outline,
          onPressed: () =>
              RoomRoute(siteId: resolved.site, roomId: resolved.roomId, roomName: resolved.roomId).push<void>(context),
        ),
      ],
    ),
  );
}
