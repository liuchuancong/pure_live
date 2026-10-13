// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:meta/meta.dart';

/// Kind of a danmaku message.
enum LiveMessageType {
  /// Chat.
  chat,

  /// A gift, membership, gifted subscription or tip; [LiveMessage.data] holds it
  /// as a [LiveGift] (a platform's subclass), the text is [LiveGift.plainText].
  /// Local gifts hold the local interaction's map.
  gift,

  /// Audience update; [LiveMessage.data] holds a [LiveAudienceUpdate].
  online,

  /// Super chat.
  superChat,

  /// Takes back messages shown earlier (a moderator deleted one, or cleared a
  /// user's or the whole chat); [LiveMessage.data] holds a [LiveRetraction].
  retraction,

  /// A platform notice shown as a line of its own; [LiveMessage.data] holds its
  /// [LiveNoticeKind], [LiveMessage.message] the text.
  notice,
}

/// What a [LiveMessageType.retraction] takes back.
@immutable
final class LiveRetraction {
  /// The message whose [LiveMessage.messageId] is [messageId].
  const LiveRetraction.message(String this.messageId) : userId = null;

  /// Every message of the sender whose [LiveMessage.userId] is [userId].
  const LiveRetraction.user(String this.userId) : messageId = null;

  /// Every message shown so far.
  const LiveRetraction.all() : messageId = null, userId = null;

  /// The message taken back, for [LiveRetraction.message].
  final String? messageId;

  /// The sender whose messages are taken back, for [LiveRetraction.user].
  final String? userId;

  /// Whether the whole chat is taken back.
  bool get isAll => messageId == null && userId == null;

  @override
  bool operator ==(Object other) => other is LiveRetraction && other.messageId == messageId && other.userId == userId;

  @override
  int get hashCode => Object.hash(messageId, userId);

  @override
  String toString() => messageId != null
      ? 'LiveRetraction.message($messageId)'
      : userId != null
      ? 'LiveRetraction.user($userId)'
      : 'LiveRetraction.all()';
}

/// Kind of a [LiveMessageType.notice].
enum LiveNoticeKind {
  /// A message from the platform or the room (rules, announcements).
  system,

  /// A viewer subscribed, renewed or gifted subscriptions or memberships (Twitch
  /// subscriptions, YouTube memberships, CHZZK, Kick and Picarto subscriptions):
  /// the purchase itself, once.
  subscription,

  /// Another channel brought its viewers over.
  raid,

  /// A viewer received one of the subscriptions or memberships another gifted to
  /// the community (Twitch's `subgift` of a community gift, YouTube's gift
  /// redemption): the giver's own [subscription] notice counts the gift, so this
  /// one is never a super chat card.
  giftedSubscription,
}

/// Which audience number an update carries.
enum LiveAudienceMetricKind {
  /// Popularity or heat.
  popularity,

  /// Concurrent viewers.
  onlineViewers,

  /// Cumulative viewers.
  totalViewers,
}

/// A typed audience update, so heat, concurrent and cumulative viewers are never
/// relabelled as the same number.
@immutable
final class LiveAudienceUpdate {
  /// Creates an update.
  const LiveAudienceUpdate({required this.kind, required this.value});

  /// What [value] means.
  final LiveAudienceMetricKind kind;

  /// The number.
  final int value;
}

/// Where a locally composed danmaku flies.
enum LiveMessagePlacement {
  /// Scrolling.
  scroll,

  /// Fixed at the top.
  top,

  /// Fixed at the bottom.
  bottom,
}

/// Presentation of a locally composed danmaku; platform messages use the room's
/// danmaku settings.
@immutable
final class LiveMessageStyle {
  /// Creates a style.
  const LiveMessageStyle({
    required this.fontSize,
    required this.baseSpeed,
    required this.fontWeight,
    required this.showStroke,
    required this.strokeWidth,
    this.placement = LiveMessagePlacement.scroll,
    this.fontFamily,
    this.italic = false,
    this.opacity = 1,
    this.letterSpacing = 0,
    this.strokeColor = 0xFF000000,
    this.showShadow = false,
    this.shadowColor = 0xFF000000,
    this.shadowBlur = 2,
    this.shadowOffset = 1,
    this.fixedDurationMs = 4000,
  });

  /// Font size.
  final double fontSize;

  /// Scrolling speed.
  final double baseSpeed;

  /// Font weight (100–900).
  final int fontWeight;

  /// Whether to draw an outline.
  final bool showStroke;

  /// Outline width.
  final double strokeWidth;

  /// Placement.
  final LiveMessagePlacement placement;

  /// Font family, or null for the default.
  final String? fontFamily;

  /// Italic.
  final bool italic;

  /// Opacity 0–1.
  final double opacity;

  /// Letter spacing.
  final double letterSpacing;

  /// Outline colour, ARGB.
  final int strokeColor;

  /// Whether to draw a shadow.
  final bool showShadow;

  /// Shadow colour, ARGB.
  final int shadowColor;

  /// Shadow blur.
  final double shadowBlur;

  /// Shadow offset.
  final double shadowOffset;

  /// How long a fixed (top or bottom) message stays, in milliseconds.
  final int fixedDurationMs;
}

/// A danmaku colour.
@immutable
final class LiveMessageColor {
  /// Creates a colour from its channels (0–255).
  const LiveMessageColor(this.r, this.g, this.b);

  /// The colour of a platform's integer: `0xRRGGBB`, or `0xAARRGGBB` with the
  /// alpha ignored (negative 32-bit values included).
  factory LiveMessageColor.numberToColor(int value) =>
      LiveMessageColor((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);

  /// White, the default.
  static const LiveMessageColor white = LiveMessageColor(255, 255, 255);

  /// Red.
  final int r;

  /// Green.
  final int g;

  /// Blue.
  final int b;

  @override
  bool operator ==(Object other) => other is LiveMessageColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  /// `#rrggbb`.
  @override
  String toString() =>
      '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
}

/// A picture in a message: [code] is the text that stands for it in
/// [LiveMessage.message], exactly as written there, and every occurrence of it is
/// the picture at [url].
@immutable
final class LiveEmote {
  /// Creates an emote.
  const LiveEmote({required this.code, required this.url});

  /// The text standing for the picture.
  final String code;

  /// The picture's address (https or http, as the platform gives it).
  final String url;

  @override
  bool operator ==(Object other) => other is LiveEmote && other.code == code && other.url == url;

  @override
  int get hashCode => Object.hash(code, url);

  @override
  String toString() => 'LiveEmote($code, $url)';
}

/// A picture a platform shows next to a sender's name (17LIVE's prefix, role,
/// attendance and level badges): what the chat line draws, in the platform's
/// order.
@immutable
final class LiveBadge {
  /// Creates a badge.
  const LiveBadge({required this.url, this.id = ''});

  /// The picture's address (https).
  final String url;

  /// The platform's id for the badge (17LIVE's `styleID`), empty when it has
  /// none.
  final String id;

  @override
  bool operator ==(Object other) => other is LiveBadge && other.url == url && other.id == id;

  @override
  int get hashCode => Object.hash(url, id);

  @override
  String toString() => 'LiveBadge($url${id.isEmpty ? '' : ', $id'})';
}

/// One danmaku message.
@immutable
final class LiveMessage {
  /// Creates a message.
  const LiveMessage({
    required this.type,
    required this.userName,
    required this.message,
    required this.color,
    this.userId = '',
    this.data,
    this.userLevel = '',
    this.fansLevel = '',
    this.fansName = '',
    this.isLocal = false,
    this.messageId = '',
    this.sentAt,
    this.style,
    this.replayed = false,
    this.emotes = const [],
    this.sourceRoomId = '',
    this.nameColor,
    this.badges = const [],
  });

  /// Kind.
  final LiveMessageType type;

  /// Sender name.
  final String userName;

  /// Sender id.
  final String userId;

  /// Text.
  final String message;

  /// For [LiveMessageType.online] a [LiveAudienceUpdate] (older engines may send
  /// a number); for [LiveMessageType.gift] a [LiveGift].
  final Object? data;

  /// Colour.
  final LiveMessageColor color;

  /// Sender level.
  final String userLevel;

  /// Fan badge level.
  final String fansLevel;

  /// Fan badge name.
  final String fansName;

  /// Composed on this device.
  final bool isLocal;

  /// The platform's id for the message, when it has one: suppresses packets
  /// replayed after a reconnect without merging two genuine identical texts.
  final String messageId;

  /// The platform's timestamp; null when it has none (reception order then).
  final DateTime? sentAt;

  /// Presentation of a local message.
  final LiveMessageStyle? style;

  /// Not something that just happened: sent again after a reconnect resumed the
  /// chat, or a backlog the platform gives on joining.
  final bool replayed;

  /// The pictures the platform names for codes in [message], each code once;
  /// empty when it names none.
  final List<LiveEmote> emotes;

  /// The room the message was said in when it is not the room joined, as the
  /// platform names it (Kugou's PK partner); empty for this room.
  final String sourceRoomId;

  /// The colour the platform gives the sender's name (17LIVE's `name.textColor`);
  /// null for the chat's default.
  final LiveMessageColor? nameColor;

  /// The badges the platform shows next to the sender's name, in its order; empty
  /// when it shows none.
  final List<LiveBadge> badges;

  /// [data] when it is a [LiveGift]; null for other kinds and for local gifts.
  LiveGift? get gift => switch (data) {
    final LiveGift gift => gift,
    _ => null,
  };

  /// Whether [sourceRoomId] names another room.
  bool get isFromOtherRoom => sourceRoomId.isNotEmpty;
}

/// A super chat (paid message).
@immutable
final class LiveSuperChatMessage {
  /// Creates a message.
  const LiveSuperChatMessage({
    required this.userName,
    required this.face,
    required this.message,
    required this.price,
    required this.startTime,
    required this.endTime,
    required this.backgroundColor,
    required this.backgroundBottomColor,
    this.messageId = '',
    this.priceText = '',
    this.unit = LiveGiftUnit.other,
    this.image = '',
  });

  /// The platform's id for the event, when it has one. Some message-board APIs
  /// rebuild [startTime] from a countdown on every poll, so equality by time
  /// would make the same paid message look new.
  final String messageId;

  /// Sender name.
  final String userName;

  /// Sender avatar URL.
  final String face;

  /// Text.
  final String message;

  /// Price in [unit]; for a platform that only writes its price ([priceText] in
  /// the buyer's currency: YouTube) the number read from that text
  /// ([superChatAmount]), which only orders and compares.
  final int price;

  /// The price as the platform shows it (`$5.00`, `1,000 치즈`), when [price]
  /// alone cannot say it; empty otherwise.
  final String priceText;

  /// The unit of [price].
  final LiveGiftUnit unit;

  /// Start of display.
  final DateTime startTime;

  /// End of display.
  final DateTime endTime;

  /// Top background colour.
  final String backgroundColor;

  /// Bottom background colour.
  final String backgroundBottomColor;

  /// The picture the message is, an https URL (YouTube's Super Sticker); empty
  /// for a message of text.
  final String image;

  /// Same [messageId] when either has one; otherwise same sender, text and price.
  @override
  bool operator ==(Object other) {
    if (other is! LiveSuperChatMessage) return false;
    if (messageId.isNotEmpty || other.messageId.isNotEmpty) {
      return messageId.isNotEmpty && other.messageId == messageId;
    }
    return other.userName == userName && other.message == message && other.price == price;
  }

  @override
  int get hashCode => messageId.isNotEmpty ? messageId.hashCode : Object.hash(userName, message, price);
}

/// The words of a super chat's price: the platform's [priceText] when it gives
/// one; else [price] in [unit] as [unitText] writes it, or the bare number when
/// it has no words for [unit]; empty without a price.
String superChatPriceLabel(
  int price,
  LiveGiftUnit unit,
  String priceText, {
  String? Function(LiveGiftUnit unit, int price)? unitText,
}) {
  final text = priceText.trim();
  if (text.isNotEmpty) return text;
  if (price <= 0) return '';
  return unitText?.call(unit, price) ?? '$price';
}

/// The whole amount in a price the platform only writes (YouTube's
/// `purchaseAmountText`: `$5.00`, `₫1,000,000`, `2,50 €`), for ordering and
/// comparing; 0 when it has no number.
int superChatAmount(String priceText) {
  final match = _amountRun.firstMatch(priceText);
  if (match == null) return 0;
  var digits = match.group(0)!.replaceAll(_spacePattern, '');
  final decimals = RegExp(r'[.,]\d{1,2}$').firstMatch(digits);
  if (decimals != null) digits = digits.substring(0, decimals.start);
  return int.tryParse(digits.replaceAll(RegExp('[.,]'), '')) ?? 0;
}

// The pattern holds a literal apostrophe and the no-break spaces platforms write
// inside an amount, so it stays a non-raw string.
// ignore: use_raw_strings
final RegExp _amountRun = RegExp("\\d(?:[\\d.,'  ]|\\s(?=\\d))*");
final RegExp _spacePattern = RegExp('[   ]');
