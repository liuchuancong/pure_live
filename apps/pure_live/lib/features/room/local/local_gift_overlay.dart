import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/local/local_catalog.dart';
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity, roomLocalMessageBusProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// How long a gift banner stays.
const Duration localGiftBannerLinger = Duration(milliseconds: 3000);

/// The local gift banner: when the viewer sends a gift into their own room,
/// a card crosses the picture — the gift's glyph, "名字 送出 礼物", the
/// level's badge and the count — for three seconds, ignoring the pointer.
///
/// One at a time, as the reference does: a gift sent while a banner shows
/// replaces it and restarts the clock rather than stacking. A gift of the
/// big tier (a combo of five, or the catalogue's expensive end) draws the
/// larger card, and the chosen local preset tints it. Reduced motion swaps
/// the scale-in for no animation at all.
final class LocalGiftOverlay extends ConsumerStatefulWidget {
  /// The overlay for [identity]'s room.
  const new({required this.identity, super.key});

  /// The room whose local bus is watched.
  final RoomIdentity identity;

  @override
  ConsumerState<LocalGiftOverlay> createState() => _LocalGiftOverlayState();
}

/// One banner's data.
typedef LocalGiftShow = ({String name, String giftName, String emoji, int count, String level, bool big});

final class _LocalGiftOverlayState extends ConsumerState<LocalGiftOverlay> {
  StreamSubscription<LiveMessage>? _subscription;
  Timer? _hide;
  LocalGiftShow? _show;

  /// The chosen preset's colour, tinting the card.
  Color _tint = const Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant LocalGiftOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _hide?.cancel();
    super.dispose();
  }

  /// The catalogue entry a gift names: by id when the payload carries one,
  /// else by name, else the first — the same fallback the catalogue states.
  LocalGift? _catalogue(LiveGift payload) {
    for (final gift in LocalCatalog.gifts) {
      if (payload.giftId.isNotEmpty && gift.id == payload.giftId) {
        return gift;
      }
      if (gift.name == payload.name) {
        return gift;
      }
    }
    return null;
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = ref.read(roomLocalMessageBusProvider(widget.identity)).messages.listen((message) {
      if (!mounted || message.type != LiveMessageType.gift || !message.isLocal) {
        return;
      }
      final payload = message.payload;
      if (payload is! LiveGift) {
        return;
      }
      final settings = ref.read(appPreferencesProvider);
      if (!settings.localInteractionGiftBanner) {
        return;
      }
      final known = _catalogue(payload);
      final exp = known?.exp ?? 0;
      _hide?.cancel();
      setState(() {
        _tint = Color(LocalCatalog.presetOf(settings.localInteractionPreset).color);
        _show = (
          name: message.effectiveSender.userName,
          giftName: payload.name.isEmpty ? (known?.name ?? '') : payload.name,
          emoji: known?.emoji ?? '🎁',
          count: payload.count,
          level: message.effectiveSender.fanBadgeName,
          // A big send is the top tier's: a combo of five, or the
          // catalogue's expensive end, marks it without inventing a currency.
          big: payload.count >= 5 || exp >= 100,
        );
      });
      _hide = Timer(localGiftBannerLinger, () {
        if (mounted) {
          setState(() => _show = null);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // The bus is auto-disposed: watching it here is what keeps the instance
    // the subscription was made on alive for as long as the overlay is up.
    ref.watch(roomLocalMessageBusProvider(widget.identity));
    final show = _show;
    if (show == null) {
      return const SizedBox.shrink();
    }
    final banner = _Banner(key: ValueKey('local-gift-banner-${show.giftName}-${show.count}'), show: show, tint: _tint);
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: still
              ? banner
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.72, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: banner,
                ),
        ),
      ),
    );
  }
}

/// The card itself.
final class _Banner extends StatelessWidget {
  const new({required this.show, required this.tint, super.key});

  final LocalGiftShow show;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final big = show.big;
    return Container(
      constraints: BoxConstraints(maxWidth: big ? 440 : 320),
      padding: big ? const EdgeInsets.fromLTRB(16, 14, 22, 14) : const EdgeInsets.fromLTRB(12, 10, 18, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tint.withValues(alpha: 0.94), const Color(0xFF101014)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
        // A solid ring, no blur over the picture.
        boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.35), spreadRadius: big ? 4 : 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(show.emoji, style: TextStyle(fontSize: big ? 42 : 28, height: 1.1)),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${show.name} ${context.t.room.sentGift} ${show.giftName}',
                  key: const ValueKey('local-gift-banner-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.title.copyWith(
                    fontSize: big ? 19 : 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (show.level.isNotEmpty)
                  Text(
                    show.level,
                    maxLines: 1,
                    style: theme.text.bodySmall.copyWith(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '×${show.count}',
            key: const ValueKey('local-gift-banner-count'),
            style: theme.text.title.copyWith(
              fontSize: big ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
