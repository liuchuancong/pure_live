import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show EmojiAtlas;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/chat/gift_text.dart';
import 'package:pure_live/modules/live/room/chat/membership_cards.dart' show isMembershipCard;
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart'
    show blockRoomMessageKeyword, blockRoomMessageSender, copyRoomMessageText;
import 'package:pure_live/modules/live/room/chat/room_super_chats.dart' show roomSuperChatsProvider;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/shield/shield.dart';
import 'package:pure_live/shared/shared.dart';

/// The room's chat column: four tabs, as the reference's `ChatPanel` has —
/// the danmaku list with its composer, the super chats where the platform
/// keeps a board, the flying layer's own settings, and the shield's lists.
/// The tab is the panel's own state; a narrow column scrolls its bar rather
/// than cutting a label.
enum _ChatTab { danmaku, superChats, settings, shield }

/// The chat column under (or beside) the picture.
final class RoomChatPanel extends ConsumerStatefulWidget {
  /// The chat column.
  const RoomChatPanel({super.key});

  @override
  ConsumerState<RoomChatPanel> createState() => _RoomChatPanelState();
}

final class _RoomChatPanelState extends ConsumerState<RoomChatPanel> {
  _ChatTab _tab = _ChatTab.danmaku;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    // The super chat tab stays for every room, as the reference's chat
    // panel does, because a membership or a subscription can arrive where
    // the platform keeps no board.
    final tab = _tab;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsTabs<_ChatTab>(
            value: tab,
            onChanged: (value) => setState(() => _tab = value),
            semanticLabel: t.room.chatTitle,
            tabs: [
              DsTab(value: _ChatTab.danmaku, label: Text(t.room.danmakuList)),
              DsTab(value: _ChatTab.superChats, label: Text(t.room.superChats)),
              DsTab(value: _ChatTab.settings, label: Text(t.room.danmakuSettings)),
              DsTab(value: _ChatTab.shield, label: Text(t.room.blockList)),
            ],
          ),
          DsLine(color: colors.border),
          Expanded(
            child: switch (tab) {
              _ChatTab.danmaku => const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ChatFeed()),
                  _ChatComposer(),
                ],
              ),
              _ChatTab.superChats => const _SuperChatTab(),
              _ChatTab.settings => const _RoomDanmakuSettings(),
              _ChatTab.shield => const _ShieldTab(),
            },
          ),
        ],
      ),
    );
  }
}

/// The danmaku list: the pipeline's messages, newest at the bottom, the
/// sender's name before the text in the sender's color. A long press (or a
/// right click) opens the message's actions.
final class _ChatFeed extends ConsumerWidget {
  const _ChatFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final chat = ref.watch(roomChatProvider);
    final anchorName = ref.watch(roomProvider.select((state) => state.room?.anchor?.name ?? ''));
    if (chat.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.messageCircle), title: Text(t.room.noChat)),
      );
    }
    // Reversed: item 0 sits at the bottom, so new messages stay in view
    // without a scroll command, and scrolling up leaves the list where the
    // viewer put it.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
      itemCount: chat.length,
      itemBuilder: (context, index) => _ChatLine(message: chat[chat.length - 1 - index], anchorName: anchorName),
    );
  }
}

/// The chat composer: the field and the send button, only when the room's
/// chat accepts a posted message; a failure toasts, a success clears the
/// field.
final class _ChatComposer extends ConsumerStatefulWidget {
  const _ChatComposer();

  @override
  ConsumerState<_ChatComposer> createState() => _ChatComposerState();
}

final class _ChatComposerState extends ConsumerState<_ChatComposer> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canSend = ref.watch(roomProvider.notifier).canSendDanmaku;
    if (!canSend) return const SizedBox.shrink();
    // The field owns the column's bottom: a hairline above it says where the
    // conversation ends and the viewer's own voice begins.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: DsTheme.colorsOf(context).border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: DsTextField(
                controller: _field,
                clearable: true,
                placeholder: t.room.sendHint,
                onSubmitted: (word) => unawaited(_send(word)),
                style: DsTextFieldStyle(borderRadius: BorderRadius.circular(DsRadii.pill)),
              ),
            ),
            DsButton(onPressed: () => unawaited(_send(_field.text)), child: Text(t.room.send)),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String word) async {
    if (word.trim().isEmpty) return;
    final failure = await ref.read(roomProvider.notifier).sendDanmaku(word);
    if (!mounted) return;
    if (failure == null) {
      _field.clear();
    } else {
      showDsToast(context: context, title: context.t.room.sendFailed);
    }
  }
}

/// One chat line: the sender and the text, the platform's own colour when
/// it gave one. Its context menu copies the line, blocks the sender, or
/// blocks a keyword to cut out of the line.
final class _ChatLine extends ConsumerWidget {
  const _ChatLine({required this.message, this.anchorName = ''});

  final LiveMessage message;

  /// The room's streamer: a gift names its receiver only when it differs.
  final String anchorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sender = message.sender;
    var nameStyle = theme.typography.caption;
    final senderName = sender?.userName.trim() ?? '';
    final showNames = ref.watch(chatNamesProvider);
    final fontSize = ref.watch(chatListFontSizeProvider);
    final lineSpacing = ref.watch(chatListLineSpacingProvider);
    final height = switch (lineSpacing) {
      'compact' => 1.4,
      'loose' => 1.7,
      _ => 1.5,
    };
    final vertical = switch (lineSpacing) {
      // The tightest step on the spacing scale: a compact list still needs
      // lines that read apart.
      'compact' => 1.0,
      'loose' => DsSpace.s6,
      _ => DsSpace.s3,
    };
    final lineStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? fontSize.toDouble() : null,
      height: height,
      color: colors.text,
    );
    // The sender leads the line: a touch heavier than the words, so the eye
    // lands on who is talking before it reads what was said.
    nameStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? fontSize.toDouble() : null,
      height: height,
      fontWeight: FontWeight.w600,
      color: message.color == null
          ? colors.textMuted
          : Color.fromARGB(255, message.color!.r, message.color!.g, message.color!.b),
    );
    // The line's own pixel size, followed from the theme when the viewer
    // hasn't picked one; an emoticon rides a touch larger than its words.
    final fontPx = fontSize > 0 ? fontSize.toDouble() : (theme.typography.caption.fontSize ?? 13);
    final gift = _giftOf(message);
    final superChat = message.type == LiveMessageType.superChat && message.payload is LiveSuperChatMessage
        ? message.payload! as LiveSuperChatMessage
        : null;
    final replayed = message.messageId.startsWith('local-replay-');
    final valueInYuan = ref.watch(chatGiftValueInYuanProvider);
    final words = gift == null ? message.text : _giftSentence(t, gift, anchorName, inYuan: valueInYuan);
    // The room's own notices (the platform's notice and system lines) sit
    // apart from the conversation: centred, quiet, no "系统:" voice. A chat
    // message whose platform lost the sender's name is NOT a notice — it
    // stays in the flow, left-aligned, as written.
    final isSystem =
        gift == null &&
        superChat == null &&
        (message.type == LiveMessageType.notice || message.type == LiveMessageType.system);
    // The platform's own labels for who is talking: the fan badge (its name
    // and level) and the viewer's level. They ride on the sender, so a line
    // that has neither shows none.
    final fanBadgeName = (sender?.fanBadgeName ?? '').trim();
    final fanBadgeLevel = (sender?.fanBadgeLevel ?? '').trim();
    final userLevel = (sender?.userLevel ?? '').trim();
    final showBadges = showNames && !isSystem && (fanBadgeName.isNotEmpty || userLevel.isNotEmpty);
    final badgeStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? math.max(fontSize - 2, 9).toDouble() : 10,
      height: 1.2,
    );
    if (isSystem) {
      // A notice is not conversation: it sits in a quiet chip of its own, so
      // the flow of talk reads as talk and the room's own voice reads apart.
      final line = Padding(
        padding: EdgeInsets.symmetric(vertical: vertical),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: 1),
            decoration: BoxDecoration(
              color: colors.control.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(DsRadii.pill),
            ),
            child: Text(
              words,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                fontSize: fontSize > 0 ? math.max(fontSize - 1, 10).toDouble() : null,
                height: height,
                color: colors.textSubtle,
              ),
            ),
          ),
        ),
      );
      return DsContextMenuRegion(
        semanticLabel: t.room.messageActions,
        items: [
          DsMenuItem(
            leading: const DsIcon(DsIcons.copy),
            label: Text(t.room.copy),
            onPressed: () => unawaited(copyRoomMessageText(context, words)),
          ),
        ],
        child: line,
      );
    }
    // A paid line — a gift or a super chat — sits in a tinted banner; plain
    // talk is a bare line, so the column keeps live chat's own density.
    final paid = gift != null || superChat != null;
    final priceText = superChat == null ? null : _superChatPrice(superChat);
    Widget content = Padding(
      padding: EdgeInsets.symmetric(vertical: paid ? 2 : vertical),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gift != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1, end: DsSpace.s6),
              child: _GiftIcon(gift: gift, size: fontSize > 0 ? fontSize.toDouble() : 16),
            ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (priceText != null) ...[
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _ChatBadge(
                        text: priceText,
                        background: colors.warning.fill,
                        foreground: colors.warning.onFill,
                        style: badgeStyle.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const WidgetSpan(child: SizedBox(width: DsSpace.s4)),
                  ],
                  if (replayed)
                    TextSpan(
                      text: '[${t.room.replayed}] ',
                      style: nameStyle.copyWith(color: colors.textSubtle),
                    ),
                  if (showBadges) ...[
                    if (fanBadgeName.isNotEmpty)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _ChatBadge(
                          text: fanBadgeLevel.isEmpty ? fanBadgeName : '$fanBadgeName $fanBadgeLevel',
                          background: colors.accent.withValues(alpha: 0.16),
                          foreground: colors.accent,
                          style: badgeStyle,
                        ),
                      ),
                    if (fanBadgeName.isNotEmpty) const WidgetSpan(child: SizedBox(width: DsSpace.s4)),
                    if (userLevel.isNotEmpty)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _ChatBadge(
                          text: 'Lv.$userLevel',
                          background: colors.control,
                          foreground: colors.textMuted,
                          style: badgeStyle,
                        ),
                      ),
                    const WidgetSpan(child: SizedBox(width: DsSpace.s4)),
                  ],
                  if (showNames && senderName.isNotEmpty) TextSpan(text: '$senderName: ', style: nameStyle),
                  // The words with the platform's own emoticons in them, cut
                  // out of the flying layer's catalogue and drawn as itself.
                  ..._wordSpans(words, lineStyle, fontPx * 1.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (superChat != null) {
      // A super chat is the loudest money in the room: the warm banner and
      // the price chip up front, the words beside them.
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s6),
          decoration: BoxDecoration(
            color: colors.warning.tint,
            borderRadius: BorderRadius.circular(theme.radii.card),
            border: Border.fromBorderSide(BorderSide(color: colors.warning.fill.withValues(alpha: 0.35))),
          ),
          child: content,
        ),
      );
    } else if (gift != null) {
      // A gift is money on the page: the accent's own tint behind the line,
      // a hairline edge, so it reads apart from ordinary talk. Both banners
      // wear the theme's card corner, not a radius of their own.
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s5),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.fromBorderSide(BorderSide(color: colors.accent.withValues(alpha: 0.22))),
        ),
        child: content,
      );
    }
    return DsContextMenuRegion(
      semanticLabel: t.room.messageActions,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(t.room.copy),
          onPressed: () => unawaited(
            copyRoomMessageText(
              context,
              gift == null ? message.text : (senderName.isEmpty ? words : '$senderName: $words'),
            ),
          ),
        ),
        if (!message.isLocal && senderName.isNotEmpty)
          DsMenuItem(
            leading: const DsIcon(DsIcons.ban),
            label: Text(t.room.blockUser),
            onPressed: () => unawaited(blockRoomMessageSender(context, ref, senderName)),
          ),
        if (!message.isLocal)
          DsMenuItem(
            leading: const DsIcon(DsIcons.shield),
            label: Text(t.room.blockKeyword),
            onPressed: () => unawaited(blockRoomMessageKeyword(context, ref, message.text)),
          ),
      ],
      child: content,
    );
  }
}

/// The [LiveGift] a platform gift line carries; null for anything else (a
/// local gift carries a map and keeps its plain text).
LiveGift? _giftOf(LiveMessage message) =>
    message.type == LiveMessageType.gift && message.payload is LiveGift ? message.payload! as LiveGift : null;

/// The price as the platform writes it for others to see ("￥12"); null when
/// the card has none of its own.
String? _superChatPrice(LiveSuperChatMessage message) {
  final shown = message.price.displayText.trim();
  if (shown.isNotEmpty) return shown;
  final amount = message.price.amount;
  if (amount == null || amount <= 0) return null;
  return [?message.price.currency, '$amount'].join();
}

/// The value of the whole line in the gift's unit, when it has one: a free
/// gift, an unknown unit and a platform without a price show nothing.
int? _giftShownValue(LiveGift gift) {
  if (giftUnitIsFree(gift.value.unit)) return null;
  final shown = giftShownCount(gift);
  final unitPrice = gift.value.unitPrice;
  if (shown > gift.count && unitPrice != null && unitPrice > 0) return (unitPrice * shown).round();
  final total = gift.value.totalValue;
  if (total == null || total <= 0) return null;
  return total.round();
}

/// A fen amount as yuan, without trailing zeros ("100", "0.5", "12.34").
String _yuanText(int fen) {
  if (fen % 100 == 0) return '${fen ~/ 100}';
  final text = (fen / 100).toStringAsFixed(2);
  final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// The units whose rate in yuan a platform fixes, so "礼物价值换算成元" can
/// write them as yuan; the overseas rates only rank gifts and stay in their
/// own unit (the reference's A08.12 list, plus our [LiveGiftUnit.rmb]).
const Set<LiveGiftUnit> _giftYuanUnits = {
  LiveGiftUnit.fen,
  LiveGiftUnit.rmb,
  LiveGiftUnit.yuan,
  LiveGiftUnit.goldSeed,
  LiveGiftUnit.diamond,
  LiveGiftUnit.douyinCoin,
  LiveGiftUnit.acCoin,
  LiveGiftUnit.starCoin,
};

String? _giftValueText(Translations t, LiveGift gift, {bool inYuan = false}) {
  final value = _giftShownValue(gift);
  if (value == null || value <= 0) return null;
  final room = t.room;
  if (inYuan && _giftYuanUnits.contains(gift.value.unit)) {
    final rate = giftUnitsPerYuan[gift.value.unit]!;
    // At least a fen: a paid gift is never "0 元".
    final fen = math.max(1, (value * 100 / rate).round());
    return room.giftValueYuan(value: _yuanText(fen));
  }
  return switch (gift.value.unit) {
    LiveGiftUnit.fen => room.giftValueYuan(value: _yuanText(value)),
    LiveGiftUnit.rmb || LiveGiftUnit.yuan => room.giftValueYuan(value: '$value'),
    LiveGiftUnit.goldSeed => room.giftValueGoldSeed(value: '$value'),
    LiveGiftUnit.diamond => room.giftValueDiamond(value: '$value'),
    LiveGiftUnit.redBean => room.giftValueRedBean(value: '$value'),
    LiveGiftUnit.point => room.giftValuePoint(value: '$value'),
    LiveGiftUnit.bits => room.giftValueBits(value: '$value'),
    LiveGiftUnit.kicks => room.giftValueKicks(value: '$value'),
    LiveGiftUnit.cheese => room.giftValueCheese(value: '$value'),
    LiveGiftUnit.starBalloon => room.giftValueStarBalloon(value: '$value'),
    LiveGiftUnit.douyinCoin => room.giftValueDouyinCoin(value: '$value'),
    LiveGiftUnit.sixCoin => room.giftValueSixCoin(value: '$value'),
    LiveGiftUnit.acCoin => room.giftValueAcCoin(value: '$value'),
    LiveGiftUnit.starCoin => room.giftValueStarCoin(value: '$value'),
    LiveGiftUnit.heart => room.giftValueHeart(value: '$value'),
    LiveGiftUnit.note => room.giftValueNote(value: '$value'),
    LiveGiftUnit.free || LiveGiftUnit.silver || LiveGiftUnit.banana || LiveGiftUnit.gold || LiveGiftUnit.other => null,
  };
}

/// The gift in words: "送出 小心心 ×3", plus its value when known.
String _giftSentence(Translations t, LiveGift gift, String anchorName, {bool inYuan = false}) {
  final value = _giftValueText(t, gift, inYuan: inYuan);
  final words = giftSentenceText(t, gift, anchorName);
  return value == null ? words : '$words  $value';
}

/// A small inline chip on a chat line: a fan badge (its name and level) or
/// the viewer's level, in the platform's own labels.
final class _ChatBadge extends StatelessWidget {
  const _ChatBadge({required this.text, required this.background, required this.foreground, required this.style});

  final String text;
  final Color background;
  final Color foreground;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4, vertical: 1),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(DsRadii.pill)),
    child: Text(text, style: style.copyWith(color: foreground)),
  );
}

/// A line's words with the platform's emoticons drawn as themselves: the
/// flying layer's own catalogue (its keys are the emoticons' message texts,
/// "[抠鼻]") regex-cut out of the words and painted from the bundled atlas.
/// A catalogue that hasn't loaded — or a word it doesn't know — stays text,
/// exactly as written.
List<InlineSpan> _wordSpans(String words, TextStyle style, double emojiSize) {
  final atlas = EmojiAtlas.instance;
  final regex = atlas.regex;
  if (regex == null || !regex.hasMatch(words)) return [TextSpan(text: words, style: style)];
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in regex.allMatches(words)) {
    final key = match[0]!;
    final info = atlas.find(key);
    final image = info == null ? null : atlas.image(info.id);
    final src = image == null ? null : atlas.getSrcRect(key);
    // A match without a picture is left in the running text: the next
    // flush writes it out as written.
    if (image == null || src == null) continue;
    if (match.start > last) spans.add(TextSpan(text: words.substring(last, match.start), style: style));
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AtlasEmoji(image: image, src: src, size: emojiSize),
      ),
    );
    last = match.end;
  }
  if (last < words.length) spans.add(TextSpan(text: words.substring(last), style: style));
  return spans;
}

/// One emoticon of the bundled atlas: a rect of the sheet the flying layer
/// already decoded, painted at the chat line's own size.
final class _AtlasEmoji extends StatelessWidget {
  const _AtlasEmoji({required this.image, required this.src, required this.size});

  final ui.Image image;
  final Rect src;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    // A hair of air on each side, so a run of emoticons reads as a run and
    // not one pasted strip.
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: CustomPaint(size: Size.square(size), painter: _AtlasEmojiPainter(this)),
  );
}

final class _AtlasEmojiPainter extends CustomPainter {
  _AtlasEmojiPainter(this.emoji);

  final _AtlasEmoji emoji;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawImageRect(emoji.image, emoji.src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);

  @override
  bool shouldRepaint(_AtlasEmojiPainter old) =>
      old.emoji.image != emoji.image || old.emoji.src != emoji.src || old.emoji.size != emoji.size;
}

/// A gift's picture at its line's text size, with the generic gift mark
/// when the platform gave none or it failed to load.
final class _GiftIcon extends StatelessWidget {
  const _GiftIcon({required this.gift, required this.size});

  final LiveGift gift;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final fallback = DsIcon(DsIcons.gift, size: size, color: colors.textSubtle);
    final url = gift.iconUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return fallback;
    return Image(
      image: cachedImage(url, width: (size * 2).round(), height: (size * 2).round()),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// The flying layer's master switch and the way into its settings page: the
/// layer has one set of controls, in the settings centre, and a room opens
/// that page rather than a second copy of it.
final class _RoomDanmakuSettings extends ConsumerWidget {
  const _RoomDanmakuSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s20),
      children: [
        DsSwitch(
          value: settings.danmakuVisible,
          onChanged: (value) => unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: value)),
          label: Text(t.room.danmakuOn),
          description: Text(t.room.danmakuSettingsDesc),
        ),
        const SizedBox(height: DsSpace.s16),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.slidersHorizontal),
              title: Text(t.settings.navDanmaku),
              description: Text(t.settings.danmakuDescription),
              showChevron: true,
              onPressed: () =>
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.danmaku.name).location)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The super chat board: the platform's own list merged with the paid
/// messages and membership cards that arrive while the room is open; a
/// failure names the reason and offers a retry.
final class _SuperChatTab extends ConsumerWidget {
  const _SuperChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final board = ref.watch(roomSuperChatsProvider);
    void retry() => unawaited(ref.read(roomProvider.notifier).reloadSuperChats());
    if (board.loading && board.messages.isEmpty) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
    }
    final error = board.error;
    if (error != null && board.messages.isEmpty) {
      return DsEmptyState(
        icon: const DsIcon(DsIcons.badgeDollarSign),
        title: Text(t.room.superChatFailed),
        description: Text(error),
        actions: [DsButton(onPressed: retry, child: Text(t.common.retry))],
      );
    }
    if (board.messages.isEmpty) {
      return DsEmptyState(icon: const DsIcon(DsIcons.badgeDollarSign), title: Text(t.room.superChatEmpty));
    }
    final messages = board.messages;
    return ListView.separated(
      padding: const EdgeInsets.all(DsSpace.s16),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s8),
      // Newest on top, as the reference's super chat page keeps them.
      itemBuilder: (context, index) => _SuperChatCard(message: messages[messages.length - 1 - index]),
    );
  }
}

/// One paid message: who paid, how much, what was said and when it shows.
final class _SuperChatCard extends StatelessWidget {
  const _SuperChatCard({required this.message});

  final LiveSuperChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final name = message.userName.trim();
    final face = message.faceUrl.trim();
    final membership = isMembershipCard(message);
    final price = _superChatPrice(message) ?? '';
    // The price's warmth: the tint deepens with the money on the line, so
    // the board reads by value at a glance (reference's graded cards).
    final amount = message.price.amount ?? 0;
    final tint = amount >= 100
        ? 0.16
        : amount >= 10
        ? 0.10
        : 0.05;
    return Container(
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: DsBoxDecoration(
        color: colors.accent.withValues(alpha: tint),
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          // A membership card has no avatar of its own (the reference's
          // D07.2 cards), only the buyer's name.
          if (!membership)
            DsAvatar(
              initials: name,
              image: face.isEmpty ? null : cachedImage(face),
              size: DsSize.sm,
              semanticLabel: name,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                      ),
                    ),
                    if (price.isNotEmpty) DsBadge(dot: false, label: Text(price), status: DsStatus.warning),
                  ],
                ),
                Text(message.text, style: theme.typography.body.copyWith(color: colors.text)),
                if (_shownAt() case final shown?)
                  Text(shown, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The time the message stays on the board, in the viewer's clock.
  String? _shownAt() {
    final start = message.startTime?.toLocal();
    final end = message.endTime?.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    String clock(DateTime time) => '${two(time.hour)}:${two(time.minute)}';
    if (start == null && end == null) return null;
    if (start != null && end != null) return '${clock(start)} – ${clock(end)}';
    return start == null ? clock(end!) : clock(start);
  }
}

/// The shield inside the room: the compact tag-based panel the chat
/// column's width was squeezing out of the settings pane.
final class _ShieldTab extends StatelessWidget {
  const _ShieldTab();

  @override
  Widget build(BuildContext context) => const RoomShieldPanel();
}
