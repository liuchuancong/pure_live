import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:pure_live/features/areas/areas_common.dart'
    show followedAreasProvider, isAreaFollowed, toggleAreaFollow;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Follows or unfollows the area a room list is showing, from its app bar —
/// the room header's pill, in the place the reference puts it for partitions.
///
/// The pill is grey and unpressable until the library has answered once, so a
/// tap can never act on a state the store has not confirmed.
final class FollowAreaButton extends ConsumerStatefulWidget {
  /// The button of [area].
  const new({required this.area, super.key});

  /// The area this page lists the rooms of.
  final LiveArea area;

  @override
  ConsumerState<FollowAreaButton> createState() => _FollowAreaButtonState();
}

final class _FollowAreaButtonState extends ConsumerState<FollowAreaButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await toggleAreaFollow(context, ref, widget.area);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(followedAreasProvider);
    final followed = isAreaFollowed(areas.value ?? const [], widget.area);
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: PureButton(
          key: const ValueKey('follow-area-button'),
          label: followed ? t.room.followed : t.room.follow,
          icon: followed ? Icons.favorite : Icons.favorite_border,
          variant: followed ? ButtonVariant.secondary : ButtonVariant.primary,
          size: ControlSize.sm,
          onPressed: areas.hasValue && !_busy ? () => unawaited(_toggle()) : null,
        ),
      ),
    );
  }
}
