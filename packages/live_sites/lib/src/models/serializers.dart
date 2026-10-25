import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/enums.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/guide/guide_catch_up/guide_catch_up.dart';
import 'package:live_sites/src/models/guide/room_guide/room_guide.dart';
import 'package:live_sites/src/models/message/live_badge/live_badge.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/live_room_ref/live_room_ref.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_local/room_local.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';

part 'serializers.g.dart';

/// The model layer's serialization table: every persisted model registers
/// here, and the plugins define the wire format — `DateTime` as ISO-8601
/// text and `Uri` as a string. There are no stored records in the old
/// freezed/json_serializable format (no consumer has ever written one), so
/// the format starts clean here rather than imitating the retired
/// converters.
@SerializersFor([
  GuideCatchUp,
  LiveGift,
  LiveGiftCombo,
  LiveGiftValue,
  LiveSuperChatMessage,
  LiveAnchor,
  LiveArea,
  LiveAssetRef,
  LiveAudienceUpdate,
  LiveBadge,
  LiveEmote,
  LiveMessage,
  LiveRetraction,
  LiveRoom,
  LiveRoomRef,
  MessageSender,
  RoomAudience,
  RoomBroadcast,
  RoomContent,
  RoomGuide,
  RoomLinks,
  RoomLocal,
  SuperChatDisplay,
  SuperChatPrice,
])
final Serializers serializers =
    (_$serializers.toBuilder()
          ..add(LiveMessageColor.serializer)
          // The generated table registers the model classes; their enum
          // fields need a serializer of their own, or writing a room (the
          // history record) throws "No serializer for ...". Persisted as
          // the value's name, as the model docs promise.
          ..add(const _EnumSerializer<LiveAnchorRole>([LiveAnchorRole], 'LiveAnchorRole', LiveAnchorRole.values))
          ..add(
            const _EnumSerializer<LiveAudienceMetricType>(
              [LiveAudienceMetricType],
              'LiveAudienceMetricType',
              LiveAudienceMetricType.values,
            ),
          )
          ..add(const _EnumSerializer<LiveGiftKind>([LiveGiftKind], 'LiveGiftKind', LiveGiftKind.values))
          ..add(const _EnumSerializer<LiveGiftUnit>([LiveGiftUnit], 'LiveGiftUnit', LiveGiftUnit.values))
          ..add(const _EnumSerializer<LiveMessageType>([LiveMessageType], 'LiveMessageType', LiveMessageType.values))
          ..add(
            const _EnumSerializer<LiveRestriction>(
              [LiveRestriction],
              'LiveRestriction',
              LiveRestriction.values,
              fallback: LiveRestriction.none,
            ),
          )
          ..add(
            const _EnumSerializer<LiveRoomActivity>(
              [LiveRoomActivity],
              'LiveRoomActivity',
              LiveRoomActivity.values,
              fallback: LiveRoomActivity.none,
            ),
          )
          ..add(
            const _EnumSerializer<LiveStatus>(
              [LiveStatus],
              'LiveStatus',
              LiveStatus.values,
              fallback: LiveStatus.unknown,
            ),
          )
          ..addPlugin(StandardJsonPlugin())
          ..addPlugin(const _UriPlugin()))
        .build();

/// An enum field's serializer: the value's name on the wire, the value
/// itself coming back. [fallback] stands in for a name this build no
/// longer knows, so an older record never makes a room unreadable.
final class _EnumSerializer<T extends Enum> implements PrimitiveSerializer<T> {
  const _EnumSerializer(this.types, this.wireName, this.values, {this.fallback});

  @override
  final Iterable<Type> types;

  @override
  final String wireName;

  /// Every value of the enum, in declaration order.
  final List<T> values;

  /// The value an unknown stored name maps to; the first when null.
  final T? fallback;

  @override
  Object serialize(Serializers serializers, T object, {FullType specifiedType = FullType.unspecified}) => object.name;

  @override
  T deserialize(Serializers serializers, Object serialized, {FullType specifiedType = FullType.unspecified}) {
    final name = serialized.toString();
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback ?? values.first;
  }
}

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Serializes `Uri` fields as plain strings.
final class _UriPlugin implements SerializerPlugin {
  const _UriPlugin();

  @override
  Object? beforeSerialize(Object? object, FullType specifiedType) => object is Uri ? object.toString() : object;

  @override
  Object? afterSerialize(Object? object, FullType specifiedType) => object;

  @override
  Object? beforeDeserialize(Object? object, FullType specifiedType) => object;

  @override
  Object? afterDeserialize(Object? object, FullType specifiedType) =>
      specifiedType.root == Uri && object is String ? Uri.parse(object) : object;
}
