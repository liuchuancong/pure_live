import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart' show InteractionSession, InteractionState;
import 'package:live_library/live_library.dart' show FollowRepository;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/formatters/formatters.dart';
import 'package:pure_uikit/pure_uikit.dart' hide InteractionState;

/// The room's info card (the reference's header + audience info): the
/// anchor — avatar, name, follower count — with the follow toggle wired to
/// the app's follow repository, the room title with its area, and the
/// audience figure.
///
/// The audience figure is live: the danmaku session's tracker refreshes the
/// concurrent count while the room sends updates. When the session has none
/// (no connection, or a platform that stays quiet) the card falls back to the
/// room detail's own numbers and shows nothing it was never told.
final class RoomInfoCard extends ConsumerStatefulWidget {
  /// A card for [room] (the resolved detail; a normalized stub before it
  /// arrives) on [identity]'s site.
  const new({required this.identity, required this.room, super.key});

  /// The room's identity, used to reach the danmaku session's tracker.
  final RoomIdentity identity;

  /// The room detail as known right now.
  final LiveRoom room;

  @override
  ConsumerState<RoomInfoCard> createState() => _RoomInfoCardState();
}

final class _RoomInfoCardState extends ConsumerState<RoomInfoCard> {
  StreamSubscription<void>? _followChanges;
  StreamSubscription<InteractionState>? _states;
  InteractionSession? _boundSession;
  bool _followed = false;

  FollowRepository get _repository => ref.read(followRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_refreshFollowed());
    _followChanges = _repository.changes.listen((_) => unawaited(_refreshFollowed()));
  }

  @override
  void dispose() {
    unawaited(_followChanges?.cancel());
    _detach(_boundSession);
    super.dispose();
  }

  /// The session lives in the provider family; the card re-binds to the
  /// tracker whenever the provider hands over a different session (a retry,
  /// a fresh connection after a shield edit) and follows its readings live.
  void _bindTo(InteractionSession? session) {
    if (identical(_boundSession, session)) {
      return;
    }
    _detach(_boundSession);
    _boundSession = session;
    if (session != null) {
      session.audience.addListener(_onAudienceMaybeChanged);
      _states = session.states.listen((_) => _onAudienceMaybeChanged());
    }
  }

  void _detach(InteractionSession? session) {
    session?.audience.removeListener(_onAudienceMaybeChanged);
    unawaited(_states?.cancel());
    _states = null;
  }

  void _onAudienceMaybeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshFollowed() async {
    await _repository.load();
    if (mounted) {
      setState(() => _followed = _repository.isFollowed(widget.room));
    }
  }

  Future<void> _toggleFollow() async {
    if (_followed) {
      await _repository.unfollow(widget.room);
    } else {
      await _repository.follow(widget.room);
    }
  }

  /// Whether the canonical room detail arrived (the stub is not followable).
  bool get _roomResolved => widget.room.anchor != null || widget.room.content.title.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    _bindTo(ref.watch(danmakuSessionProvider(widget.identity)).value);
    final theme = PureTheme.of(context);
    final anchor = widget.room.anchor;
    final broadcast = widget.room.broadcast;
    final audience = widget.room.audience;

    // The live concurrent count wins; the detail's own figures fill in for
    // what the stream never said.
    final tracker = _boundSession?.audience;
    final online = tracker?.onlineViewers ?? audience.onlineViewers;
    final total = tracker?.totalViewers ?? audience.totalViewers;
    final popularity = audience.popularity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PureAvatar(name: anchor?.name, src: _imageOf(anchor?.avatarUrl), size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anchor == null || anchor.name.isEmpty ? widget.room.ref.roomId : anchor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.title,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(anchor?.followerCount, broadcast, context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The toggle stays inert until the canonical detail arrived:
              // following a stub would store a title-less record.
              PureButton(
                label: _followed ? context.t.room.followed : context.t.room.follow,
                icon: _followed ? Icons.favorite : Icons.favorite_border,
                variant: _followed ? ButtonVariant.secondary : ButtonVariant.primary,
                size: ControlSize.sm,
                onPressed: _roomResolved ? () => unawaited(_toggleFollow()) : null,
              ),
            ],
          ),
          if (widget.room.content.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.room.content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.text.body,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (online != null)
                _metric(
                  context,
                  Icons.people_alt_rounded,
                  '${context.t.room.online} ${compactCount(online, cjk: _cjk)}',
                ),
              if (total != null) _metric(context, Icons.visibility_rounded, compactCount(total, cjk: _cjk)),
              if (popularity != null)
                _metric(
                  context,
                  Icons.whatshot_rounded,
                  '${context.t.room.popularity} ${compactCount(popularity, cjk: _cjk)}',
                ),
              if (widget.room.area != null && widget.room.area!.areaName.isNotEmpty)
                _metric(context, Icons.category_outlined, widget.room.area!.areaName),
            ],
          ),
        ],
      ),
    );
  }

  bool get _cjk => LocaleSettings.currentLocale == AppLocale.zh;

  /// The second line: follower count when the platform gave one, plus the
  /// broadcast state when the room is not simply live.
  String _metaLine(int? followers, RoomBroadcast broadcast, BuildContext context) {
    final parts = <String>[
      if (followers != null) context.t.room.followers(count: compactCount(followers, cjk: _cjk)),
      if (broadcast.isExplicitlyOfflineNow) context.t.room.offline,
      if (broadcast.isRecord) context.t.room.replay,
    ];
    return parts.join(' · ');
  }

  Widget _metric(BuildContext context, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: PureTheme.of(context).colors.textSecondary),
      const SizedBox(width: 3),
      Text(
        label,
        style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
      ),
    ],
  );

  ImageProvider? _imageOf(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return CachedNetworkImageProvider(value);
  }
}
