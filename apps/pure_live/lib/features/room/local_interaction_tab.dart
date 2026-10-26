import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/room/room_controller.dart' show roomProvider;
import 'package:pure_live/features/settings/local_interaction_settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;

/// The room's local-interaction tab: the local identity and balance, the
/// gift shelf, a composer that injects a local message into the room's own
/// chat/flying layer, the gift banner (when effects are on) and the recent
/// history. Nothing here reaches the platform.
final class LocalInteractionTab extends ConsumerStatefulWidget {
  /// The tab.
  const LocalInteractionTab({super.key});

  @override
  ConsumerState<LocalInteractionTab> createState() => _LocalInteractionTabState();
}

final class _LocalInteractionTabState extends ConsumerState<LocalInteractionTab> {
  final TextEditingController _field = TextEditingController();
  String? _banner;
  Timer? _bannerTimer;

  @override
  void dispose() {
    _field.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _showBanner(LocalGift gift, String message) {
    final local = ref.read(localInteractionProvider);
    if (!local.giftEffectLevel.shows(gift.price)) return;
    final big = gift.price >= kLocalGiftBigPrice;
    _bannerTimer?.cancel();
    setState(() => _banner = message);
    _bannerTimer = Timer(Duration(milliseconds: big ? 2800 : 1600), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Future<void> _send([String? phrase]) async {
    final fromField = phrase == null;
    final text = (phrase ?? _field.text).trim();
    if (text.isEmpty) return;
    final local = ref.read(localInteractionProvider);
    final controller = ref.read(localInteractionProvider.notifier);
    final line = '${local.title} · ${local.userName}: $text';
    if (local.showAsDanmaku) {
      ref.read(roomProvider.notifier).injectLocalMessage(
        text,
        badges: _badges(local, controller.level, _platformLabel(local.previewPlatform)),
        senderName: local.userName,
      );
    }
    await controller.addHistory('${_stamp()} $line');
    await controller.rewardChat();
    final room = ref.read(roomProvider).room;
    if (room != null) {
      await controller.recordRoomChat(room.ref.platform, room.ref.roomId, text);
    }
    if (fromField && mounted) _field.clear();
  }

  Future<void> _sendGift(LocalGift gift) async {
    final controller = ref.read(localInteractionProvider.notifier);
    final ok = await controller.sendGift(gift);
    if (!mounted) return;
    if (!ok) {
      showDsToast(context: context, title: context.t.settings.localNoCoins, status: DsStatus.danger);
      return;
    }
    final local = ref.read(localInteractionProvider);
    if (local.showAsDanmaku) {
      ref.read(roomProvider.notifier).injectLocalMessage(
        '${gift.emoji} ${gift.name} x1',
        badges: _badges(local, controller.level, _platformLabel(local.previewPlatform)),
        senderName: local.userName,
      );
    }
    _showBanner(gift, '${gift.emoji} ${gift.name}');
    showDsToast(context: context, title: context.t.settings.localGiftSent);
  }

  String _platformLabel(String id) {
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }

  static String _badges(LocalInteractionState local, int level, String platformName) => [
    if (local.showLevelBadge) 'Lv.$level',
    if (local.showPlatformBadge) platformName,
  ].join(' · ');

  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final local = ref.watch(localInteractionProvider);
    final controller = ref.read(localInteractionProvider.notifier);
    final level = controller.level;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, 0),
          child: Row(
            children: [
              DsAvatar(
                initials: local.userName,
                size: DsSize.sm,
                semanticLabel: local.userName,
              ),
              const SizedBox(width: DsSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      '${local.title} · ${local.userName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      t.settings.localStatusValue(
                        coins: '${local.coins}',
                        experience: '${local.experience}',
                        level: '$level',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.small.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_banner != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
              decoration: DsBoxDecoration(
                color: colors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(theme.radii.card),
              ),
              child: Text(_banner!, style: theme.typography.body.copyWith(color: colors.text)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          child: Text(t.settings.localGifts, style: theme.typography.small.copyWith(color: colors.textMuted)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          child: Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final gift in kLocalGifts)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(_sendGift(gift)),
                  child: Text('${gift.emoji} ${gift.name} · ${gift.price}'),
                ),
            ],
          ),
        ),
        if (local.phrases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
            child: Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s4,
              children: [
                for (final phrase in local.phrases)
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(_send(phrase)),
                    child: Text(phrase),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsTextField(
                  controller: _field,
                  clearable: true,
                  placeholder: t.settings.localMessageHint,
                  onSubmitted: (_) => unawaited(_send()),
                  semanticLabel: t.settings.localMessageHint,
                ),
              ),
              DsButton(onPressed: () => unawaited(_send()), child: Text(t.settings.localSend)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          child: Text(t.settings.localHistory, style: theme.typography.small.copyWith(color: colors.textMuted)),
        ),
        Expanded(
          child: local.history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpace.s20),
                    child: Text(
                      t.settings.localHistoryEmpty,
                      style: theme.typography.small.copyWith(color: colors.textSubtle),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s16),
                  itemCount: local.history.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.s6),
                    child: Text(
                      local.history[local.history.length - 1 - index],
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
