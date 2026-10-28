import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
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
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
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
    final listStyle = ref.watch(chatListStyleProvider);
    final fontSize = ref.watch(chatListFontSizeProvider);
    final lineSpacing = ref.watch(chatListLineSpacingProvider);
    final height = switch (lineSpacing) {
      'compact' => 1.4,
      'loose' => 1.7,
      _ => 1.5,
    };
    final vertical = switch (lineSpacing) {
      'compact' => DsSpace.s3,
      'loose' => DsSpace.s6,
      _ => DsSpace.s3,
    };
    final lineStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? fontSize.toDouble() : null,
      height: height,
      color: colors.text,
    );
    nameStyle = theme.typography.caption.copyWith(
      fontSize: fontSize > 0 ? fontSize.toDouble() : null,
      height: height,
      color: message.color == null
          ? colors.textMuted
          : Color.fromARGB(255, message.color!.r, message.color!.g, message.color!.b),
    );
    final gift = _giftOf(message);
    final replayed = message.messageId.startsWith('local-replay-');
    final valueInYuan = ref.watch(chatGiftValueInYuanProvider);
    final words = gift == null ? message.text : _giftSentence(t, gift, anchorName, inYuan: valueInYuan);
    // The room's own notices (the platform's system lines) sit apart from
    // the conversation: centred, quiet, no "系统:" voice.
    final isSystem = gift == null && senderName.isEmpty;
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
      final line = Padding(
        padding: EdgeInsets.symmetric(vertical: vertical),
        child: Align(
          alignment: AlignmentDirectional.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s3),
            decoration: BoxDecoration(
              color: colors.control.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(DsRadii.pill),
            ),
            child: Text(
              words,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                fontSize: fontSize > 0 ? fontSize.toDouble() : null,
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
    Widget content = Padding(
      padding: EdgeInsets.symmetric(vertical: gift == null ? vertical : 2),
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
                  TextSpan(text: words, style: lineStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (gift != null) {
      // A gift is money on the page: the accent's own tint behind the line,
      // a hairline edge, so it reads apart from ordinary talk.
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s6),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.fromBorderSide(BorderSide(color: colors.accent.withValues(alpha: 0.18))),
        ),
        child: content,
      );
    } else if (listStyle == 'card') {
      content = Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s6),
        decoration: BoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
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

/// The flying danmaku's own settings, right beside the list: whether it
/// draws, then size, speed, the share of the picture it may cross, opacity,
/// the outline and the way back to the defaults.
final class _RoomDanmakuSettings extends ConsumerWidget {
  const _RoomDanmakuSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final frameRate = ref.watch(danmakuFrameRateProvider);
    final frameRateController = ref.read(danmakuFrameRateProvider.notifier);
    final effectiveFps = ref.watch(danmakuEffectiveFpsProvider);
    // Clones share one settings store; there is no per-window scope here.
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s20),
      children: [
        DsSwitch(
          value: settings.danmakuVisible,
          onChanged: (value) => unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: value)),
          label: Text(t.room.danmakuOn),
          description: Text(t.room.danmakuSettingsDesc),
        ),
        const SizedBox(height: DsSpace.s12),
        _StyleSlider(
          icon: DsIcons.type,
          label: t.settings.styleFontSize,
          shown: '${style.fontSize.toStringAsFixed(1)} px',
          value: style.fontSize,
          min: DanmakuStyleRange.fontSizeMin,
          max: DanmakuStyleRange.fontSizeMax,
          onChanged: (value) => unawaited(controller.setFontSize(value)),
          semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
        ),
        _StyleSlider(
          icon: DsIcons.bold,
          label: t.settings.styleFontWeight,
          shown: danmakuFontWeightLabel(t, style.fontWeight),
          value: style.fontWeight.toDouble(),
          min: DanmakuStyleRange.fontWeightMin.toDouble(),
          max: DanmakuStyleRange.fontWeightMax.toDouble(),
          divisions: DanmakuStyleRange.fontWeightDivisions,
          onChanged: (value) => unawaited(controller.setFontWeight(value.round())),
          semanticFormatter: (value) => danmakuFontWeightLabel(t, value.round()),
        ),
        _StyleSlider(
          icon: DsIcons.letterSpacing,
          label: t.settings.styleLetterSpacing,
          shown: '${style.letterSpacing.toStringAsFixed(1)} px',
          value: style.letterSpacing,
          min: DanmakuStyleRange.letterSpacingMin,
          max: DanmakuStyleRange.letterSpacingMax,
          onChanged: (value) => unawaited(controller.setLetterSpacing(value)),
          semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
        ),
        _StyleSlider(
          icon: DsIcons.wind,
          label: t.settings.styleSpeed,
          shown: '${style.baseSpeed.round()} px/s',
          value: style.baseSpeed,
          min: DanmakuStyleRange.speedMin,
          max: DanmakuStyleRange.speedMax,
          onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
          semanticFormatter: (value) => '${value.round()} px/s',
        ),
        _StyleSlider(
          icon: DsIcons.moveVertical,
          label: t.settings.styleArea,
          shown: '${(style.area * 100).round()}%',
          value: style.area,
          min: DanmakuStyleRange.areaMin,
          max: DanmakuStyleRange.areaMax,
          divisions: DanmakuStyleRange.areaDivisions,
          onChanged: (value) => unawaited(controller.setArea(value)),
        ),
        _StyleSlider(
          icon: DsIcons.circle,
          label: t.settings.styleOpacity,
          shown: '${(style.opacity * 100).round()}%',
          value: style.opacity,
          min: DanmakuStyleRange.opacityMin,
          max: 1,
          onChanged: (value) => unawaited(controller.setOpacity(value)),
        ),
        const SizedBox(height: DsSpace.s8),
        DsSwitch(
          value: style.showStroke,
          onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
          label: Text(t.settings.styleStroke),
        ),
        _StyleSlider(
          icon: DsIcons.square,
          label: t.settings.styleStrokeWidth,
          shown: '${style.strokeWidth.toStringAsFixed(1)} px',
          value: style.strokeWidth,
          min: DanmakuStyleRange.strokeWidthMin,
          max: DanmakuStyleRange.strokeWidthMax,
          // Greyed out while the outline is off, as in the reference.
          onChanged: style.showStroke ? (value) => unawaited(controller.setStrokeWidth(value)) : null,
          semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.s8),
          child: DsSwitch(
            value: frameRate.autoFps,
            onChanged: (value) => unawaited(frameRateController.setAutoFps(value: value)),
            label: Text(t.settings.styleFpsFollow),
            description: Text(t.settings.styleFpsFollowDesc),
          ),
        ),
        _StyleSlider(
          icon: DsIcons.gauge,
          label: t.settings.styleFps,
          shown: t.settings.styleFpsValue(count: '${frameRate.autoFps ? effectiveFps : frameRate.fps}'),
          value: (frameRate.autoFps ? effectiveFps : frameRate.fps).toDouble(),
          min: DanmakuStyleRange.fpsMin.toDouble(),
          max: DanmakuStyleRange.fpsMax.toDouble(),
          divisions: DanmakuStyleRange.fpsDivisions,
          onChanged: frameRate.autoFps ? null : (value) => unawaited(frameRateController.setFps(value.round())),
          semanticFormatter: (value) => t.settings.styleFpsValue(count: '${value.round()}'),
        ),
        _StyleSlider(
          icon: DsIcons.layers,
          label: t.settings.styleMaxVisible,
          shown: t.settings.styleMaxVisibleValue(count: '${style.maxVisibleCount}'),
          value: style.maxVisibleCount.toDouble(),
          min: DanmakuStyleRange.maxVisibleMin.toDouble(),
          max: DanmakuStyleRange.maxVisibleMax.toDouble(),
          divisions: DanmakuStyleRange.maxVisibleDivisions,
          onChanged: style.massMode ? null : (value) => unawaited(controller.setMaxVisibleCount(value.round())),
          semanticFormatter: (value) => t.settings.styleMaxVisibleValue(count: '${value.round()}'),
        ),
        DsSwitch(
          value: style.massMode,
          onChanged: (value) => unawaited(controller.setMassMode(value: value)),
          label: Text(t.settings.styleMassMode),
          description: Text(t.settings.styleMassModeDesc),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCw),
          title: Text(t.settings.styleReset),
          onPressed: () {
            unawaited(controller.reset());
            unawaited(frameRateController.reset());
          },
        ),
      ],
    );
  }
}

/// One labelled slider of the in-room danmaku settings: the same bar row the
/// settings centre uses — the name and its current value on the line, the
/// bar at its end (under the line while the column is narrow).
final class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.icon,
    required this.label,
    required this.shown,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.semanticFormatter,
  });

  final DsIconData icon;
  final String label;
  final String shown;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value)? semanticFormatter;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsConfigRow(
      leading: DsIcon(icon),
      title: label,
      detail: Text(shown),
      controlWidth: 220,
      control: DsSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        semanticLabel: label,
        semanticFormatter: semanticFormatter,
      ),
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
    final price = message.price.displayText.trim().isNotEmpty
        ? message.price.displayText.trim()
        : [?message.price.currency, if (message.price.amount case final amount?) '$amount'].join();
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
