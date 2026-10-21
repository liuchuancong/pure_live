import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart' show InteractionSession;
import 'package:live_sites/live_sites.dart' show LivePlayLine, LivePlayQuality;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity, danmakuSessionProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/formatters/formatters.dart' show compactCount;
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The strip between the video and the pane: what the room is worth, and which
/// stream is playing — the reference's `ResolutionsRow`.
///
/// It is a panel head, not a form: the two selectors are the row's only
/// controls and they take the row's trailing weight, while the audience figures
/// keep the leading one. A site with no playback capability shows the figures
/// and nothing else.
final class RoomResolutionRow extends ConsumerWidget {
  /// The row for [identity], driven by [controller] and read from [state].
  const new({required this.identity, required this.controller, required this.state, this.dense = false, super.key});

  /// The room whose stream this picks.
  final RoomIdentity identity;

  /// The page logic the selectors call.
  final RoomController controller;

  /// The snapshot they read.
  final RoomState state;

  /// A short version for a bar that has to share its row with buttons.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(danmakuSessionProvider(identity)).value;
    final preferences = ref.watch(appPreferencesProvider);
    // The audience answers (the reference's preferRealOnlineCounts): a room
    // on a trusted platform leads with its concurrent-online figure, every
    // other one with the platform's own heat.
    final leadOnline = preferences.preferRealOnlineCounts && preferences.realOnlinePlatforms.contains(identity.siteId);
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          if (!dense)
            Expanded(
              flex: 3,
              child: _Audience(state: state, session: session, cjk: _cjk(context), leadOnline: leadOnline),
            ),
          if (state.qualities.isNotEmpty)
            Expanded(
              flex: dense ? 2 : 3,
              child: PureSelect<LivePlayQuality>(
                items: state.qualities,
                value: state.quality,
                itemLabel: (quality) => '${context.t.room.quality} · ${quality.label}',
                enabled: !state.switching,
                onChanged: (quality) => unawaited(controller.openLines(quality: quality)),
              ),
            ),
          if (state.lines.length > 1) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: PureSelect<LivePlayLine>(
                items: state.lines,
                value: state.line,
                itemLabel: (line) => '${context.t.room.line} · ${_lineLabel(context, state, line)}',
                enabled: !state.switching,
                onChanged: (line) => unawaited(controller.play(line)),
              ),
            ),
          ],
          if (state.switching) ...[const SizedBox(width: 8), const PureSpinner(size: 16)],
          if (dense) const Spacer(),
        ],
      ),
    );
  }

  static String _lineLabel(BuildContext context, RoomState state, LivePlayLine line) {
    final label = line.lineLabel;
    if (label != null && label.isNotEmpty) {
      return label;
    }
    final index = state.lines.indexOf(line);
    return context.t.room.lineN(n: '${index + 1}');
  }

  /// Whether to count in 万/亿: the compact formatter is a Chinese-language
  /// one, and an English room list should not read "3.2万".
  static bool _cjk(BuildContext context) => Localizations.localeOf(context).languageCode == 'zh';
}

/// The audience figures the platform gave, or the barrage's own tracker for
/// whatever it is currently reporting.
final class _Audience extends StatelessWidget {
  const new({required this.state, required this.session, required this.cjk, required this.leadOnline});

  final RoomState state;
  final InteractionSession? session;
  final bool cjk;

  /// Whether the online figure leads; false puts the platform's heat first
  /// (the video settings' 观众 display-mode answer).
  final bool leadOnline;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final audience = state.room?.audience;
    // The live reading wins where it exists; a figure the stream never sent
    // is not invented from the detail's snapshot.
    final online = session?.audience.onlineViewers ?? audience?.onlineViewers;
    final popularity = audience?.popularity;
    final style = theme.text.caption.copyWith(color: theme.colors.textSecondary);
    final metrics = [
      if (online != null)
        _metric(Icons.people_alt_outlined, '${context.t.room.online} ${compactCount(online, cjk: cjk)}', style),
      if (popularity != null)
        _metric(Icons.whatshot_outlined, '${context.t.room.popularity} ${compactCount(popularity, cjk: cjk)}', style),
    ];
    // The chosen figure reads first; the other stays behind it when both
    // exist — dropping a number the platform sent would be its own lie.
    if (metrics.length == 2 && !leadOnline) {
      metrics
        ..removeAt(0)
        ..insert(0, metrics.removeLast());
    }
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...metrics,
        if (metrics.isEmpty) Text(context.t.room.audienceWaiting, style: style),
      ],
    );
  }

  Widget _metric(IconData icon, String label, TextStyle style) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: style.color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    ],
  );
}
