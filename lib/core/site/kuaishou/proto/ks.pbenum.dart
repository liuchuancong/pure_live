//
//  Generated code. Do not modify.
//  source: ks.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CompressionType extends $pb.ProtobufEnum {
  static const CompressionType COMPRESSION_TYPE_UNKNOWN = CompressionType._(0, _omitEnumNames ? '' : 'COMPRESSION_TYPE_UNKNOWN');
  static const CompressionType NONE = CompressionType._(1, _omitEnumNames ? '' : 'NONE');
  static const CompressionType GZIP = CompressionType._(2, _omitEnumNames ? '' : 'GZIP');
  static const CompressionType AES = CompressionType._(3, _omitEnumNames ? '' : 'AES');

  static const $core.List<CompressionType> values = <CompressionType> [
    COMPRESSION_TYPE_UNKNOWN,
    NONE,
    GZIP,
    AES,
  ];

  static final $core.Map<$core.int, CompressionType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CompressionType? valueOf($core.int value) => _byValue[value];

  const CompressionType._($core.int v, $core.String n) : super(v, n);
}

/// 弹幕数据包返回类型
class PayloadType extends $pb.ProtobufEnum {
  static const PayloadType PAYLOAD_TYPE_UNKNOWN = PayloadType._(0, _omitEnumNames ? '' : 'PAYLOAD_TYPE_UNKNOWN');
  static const PayloadType CS_HEARTBEAT = PayloadType._(1, _omitEnumNames ? '' : 'CS_HEARTBEAT');
  static const PayloadType CS_ERROR = PayloadType._(3, _omitEnumNames ? '' : 'CS_ERROR');
  static const PayloadType CS_PING = PayloadType._(4, _omitEnumNames ? '' : 'CS_PING');
  static const PayloadType PS_HOST_INFO = PayloadType._(51, _omitEnumNames ? '' : 'PS_HOST_INFO');
  static const PayloadType SC_HEARTBEAT_ACK = PayloadType._(101, _omitEnumNames ? '' : 'SC_HEARTBEAT_ACK');
  static const PayloadType SC_ECHO = PayloadType._(102, _omitEnumNames ? '' : 'SC_ECHO');
  static const PayloadType SC_ERROR = PayloadType._(103, _omitEnumNames ? '' : 'SC_ERROR');
  static const PayloadType SC_PING_ACK = PayloadType._(104, _omitEnumNames ? '' : 'SC_PING_ACK');
  static const PayloadType SC_INFO = PayloadType._(105, _omitEnumNames ? '' : 'SC_INFO');
  static const PayloadType CS_ENTER_ROOM = PayloadType._(200, _omitEnumNames ? '' : 'CS_ENTER_ROOM');
  static const PayloadType CS_USER_PAUSE = PayloadType._(201, _omitEnumNames ? '' : 'CS_USER_PAUSE');
  static const PayloadType CS_USER_EXIT = PayloadType._(202, _omitEnumNames ? '' : 'CS_USER_EXIT');
  static const PayloadType CS_AUTHOR_PUSH_TRAFFIC_ZERO = PayloadType._(203, _omitEnumNames ? '' : 'CS_AUTHOR_PUSH_TRAFFIC_ZERO');
  static const PayloadType CS_HORSE_RACING = PayloadType._(204, _omitEnumNames ? '' : 'CS_HORSE_RACING');
  static const PayloadType CS_RACE_LOSE = PayloadType._(205, _omitEnumNames ? '' : 'CS_RACE_LOSE');
  static const PayloadType CS_VOIP_SIGNAL = PayloadType._(206, _omitEnumNames ? '' : 'CS_VOIP_SIGNAL');
  static const PayloadType SC_ENTER_ROOM_ACK = PayloadType._(300, _omitEnumNames ? '' : 'SC_ENTER_ROOM_ACK');
  static const PayloadType SC_AUTHOR_PAUSE = PayloadType._(301, _omitEnumNames ? '' : 'SC_AUTHOR_PAUSE');
  static const PayloadType SC_AUTHOR_RESUME = PayloadType._(302, _omitEnumNames ? '' : 'SC_AUTHOR_RESUME');
  static const PayloadType SC_AUTHOR_PUSH_TRAFFIC_ZERO = PayloadType._(303, _omitEnumNames ? '' : 'SC_AUTHOR_PUSH_TRAFFIC_ZERO');
  static const PayloadType SC_AUTHOR_HEARTBEAT_MISS = PayloadType._(304, _omitEnumNames ? '' : 'SC_AUTHOR_HEARTBEAT_MISS');
  static const PayloadType SC_PIP_STARTED = PayloadType._(305, _omitEnumNames ? '' : 'SC_PIP_STARTED');
  static const PayloadType SC_PIP_ENDED = PayloadType._(306, _omitEnumNames ? '' : 'SC_PIP_ENDED');
  static const PayloadType SC_HORSE_RACING_ACK = PayloadType._(307, _omitEnumNames ? '' : 'SC_HORSE_RACING_ACK');
  static const PayloadType SC_VOIP_SIGNAL = PayloadType._(308, _omitEnumNames ? '' : 'SC_VOIP_SIGNAL');
  static const PayloadType SC_FEED_PUSH = PayloadType._(310, _omitEnumNames ? '' : 'SC_FEED_PUSH');
  static const PayloadType SC_ASSISTANT_STATUS = PayloadType._(311, _omitEnumNames ? '' : 'SC_ASSISTANT_STATUS');
  static const PayloadType SC_REFRESH_WALLET = PayloadType._(312, _omitEnumNames ? '' : 'SC_REFRESH_WALLET');
  static const PayloadType SC_LIVE_CHAT_CALL = PayloadType._(320, _omitEnumNames ? '' : 'SC_LIVE_CHAT_CALL');
  static const PayloadType SC_LIVE_CHAT_CALL_ACCEPTED = PayloadType._(321, _omitEnumNames ? '' : 'SC_LIVE_CHAT_CALL_ACCEPTED');
  static const PayloadType SC_LIVE_CHAT_CALL_REJECTED = PayloadType._(322, _omitEnumNames ? '' : 'SC_LIVE_CHAT_CALL_REJECTED');
  static const PayloadType SC_LIVE_CHAT_READY = PayloadType._(323, _omitEnumNames ? '' : 'SC_LIVE_CHAT_READY');
  static const PayloadType SC_LIVE_CHAT_GUEST_END = PayloadType._(324, _omitEnumNames ? '' : 'SC_LIVE_CHAT_GUEST_END');
  static const PayloadType SC_LIVE_CHAT_ENDED = PayloadType._(325, _omitEnumNames ? '' : 'SC_LIVE_CHAT_ENDED');
  static const PayloadType SC_RENDERING_MAGIC_FACE_DISABLE = PayloadType._(326, _omitEnumNames ? '' : 'SC_RENDERING_MAGIC_FACE_DISABLE');
  static const PayloadType SC_RENDERING_MAGIC_FACE_ENABLE = PayloadType._(327, _omitEnumNames ? '' : 'SC_RENDERING_MAGIC_FACE_ENABLE');
  static const PayloadType SC_RED_PACK_FEED = PayloadType._(330, _omitEnumNames ? '' : 'SC_RED_PACK_FEED');
  static const PayloadType SC_LIVE_WATCHING_LIST = PayloadType._(340, _omitEnumNames ? '' : 'SC_LIVE_WATCHING_LIST');
  static const PayloadType SC_LIVE_QUIZ_QUESTION_ASKED = PayloadType._(350, _omitEnumNames ? '' : 'SC_LIVE_QUIZ_QUESTION_ASKED');
  static const PayloadType SC_LIVE_QUIZ_QUESTION_REVIEWED = PayloadType._(351, _omitEnumNames ? '' : 'SC_LIVE_QUIZ_QUESTION_REVIEWED');
  static const PayloadType SC_LIVE_QUIZ_SYNC = PayloadType._(352, _omitEnumNames ? '' : 'SC_LIVE_QUIZ_SYNC');
  static const PayloadType SC_LIVE_QUIZ_ENDED = PayloadType._(353, _omitEnumNames ? '' : 'SC_LIVE_QUIZ_ENDED');
  static const PayloadType SC_LIVE_QUIZ_WINNERS = PayloadType._(354, _omitEnumNames ? '' : 'SC_LIVE_QUIZ_WINNERS');
  static const PayloadType SC_SUSPECTED_VIOLATION = PayloadType._(355, _omitEnumNames ? '' : 'SC_SUSPECTED_VIOLATION');
  static const PayloadType SC_SHOP_OPENED = PayloadType._(360, _omitEnumNames ? '' : 'SC_SHOP_OPENED');
  static const PayloadType SC_SHOP_CLOSED = PayloadType._(361, _omitEnumNames ? '' : 'SC_SHOP_CLOSED');
  static const PayloadType SC_GUESS_OPENED = PayloadType._(370, _omitEnumNames ? '' : 'SC_GUESS_OPENED');
  static const PayloadType SC_GUESS_CLOSED = PayloadType._(371, _omitEnumNames ? '' : 'SC_GUESS_CLOSED');
  static const PayloadType SC_PK_INVITATION = PayloadType._(380, _omitEnumNames ? '' : 'SC_PK_INVITATION');
  static const PayloadType SC_PK_STATISTIC = PayloadType._(381, _omitEnumNames ? '' : 'SC_PK_STATISTIC');
  static const PayloadType SC_RIDDLE_OPENED = PayloadType._(390, _omitEnumNames ? '' : 'SC_RIDDLE_OPENED');
  static const PayloadType SC_RIDDLE_CLOESED = PayloadType._(391, _omitEnumNames ? '' : 'SC_RIDDLE_CLOESED');
  static const PayloadType SC_RIDE_CHANGED = PayloadType._(412, _omitEnumNames ? '' : 'SC_RIDE_CHANGED');
  static const PayloadType SC_BET_CHANGED = PayloadType._(441, _omitEnumNames ? '' : 'SC_BET_CHANGED');
  static const PayloadType SC_BET_CLOSED = PayloadType._(442, _omitEnumNames ? '' : 'SC_BET_CLOSED');
  static const PayloadType SC_LIVE_SPECIAL_ACCOUNT_CONFIG_STATE = PayloadType._(645, _omitEnumNames ? '' : 'SC_LIVE_SPECIAL_ACCOUNT_CONFIG_STATE');
  static const PayloadType SC_LIVE_WARNING_MASK_STATUS_CHANGED_AUDIENCE = PayloadType._(758, _omitEnumNames ? '' : 'SC_LIVE_WARNING_MASK_STATUS_CHANGED_AUDIENCE');

  static const $core.List<PayloadType> values = <PayloadType> [
    PAYLOAD_TYPE_UNKNOWN,
    CS_HEARTBEAT,
    CS_ERROR,
    CS_PING,
    PS_HOST_INFO,
    SC_HEARTBEAT_ACK,
    SC_ECHO,
    SC_ERROR,
    SC_PING_ACK,
    SC_INFO,
    CS_ENTER_ROOM,
    CS_USER_PAUSE,
    CS_USER_EXIT,
    CS_AUTHOR_PUSH_TRAFFIC_ZERO,
    CS_HORSE_RACING,
    CS_RACE_LOSE,
    CS_VOIP_SIGNAL,
    SC_ENTER_ROOM_ACK,
    SC_AUTHOR_PAUSE,
    SC_AUTHOR_RESUME,
    SC_AUTHOR_PUSH_TRAFFIC_ZERO,
    SC_AUTHOR_HEARTBEAT_MISS,
    SC_PIP_STARTED,
    SC_PIP_ENDED,
    SC_HORSE_RACING_ACK,
    SC_VOIP_SIGNAL,
    SC_FEED_PUSH,
    SC_ASSISTANT_STATUS,
    SC_REFRESH_WALLET,
    SC_LIVE_CHAT_CALL,
    SC_LIVE_CHAT_CALL_ACCEPTED,
    SC_LIVE_CHAT_CALL_REJECTED,
    SC_LIVE_CHAT_READY,
    SC_LIVE_CHAT_GUEST_END,
    SC_LIVE_CHAT_ENDED,
    SC_RENDERING_MAGIC_FACE_DISABLE,
    SC_RENDERING_MAGIC_FACE_ENABLE,
    SC_RED_PACK_FEED,
    SC_LIVE_WATCHING_LIST,
    SC_LIVE_QUIZ_QUESTION_ASKED,
    SC_LIVE_QUIZ_QUESTION_REVIEWED,
    SC_LIVE_QUIZ_SYNC,
    SC_LIVE_QUIZ_ENDED,
    SC_LIVE_QUIZ_WINNERS,
    SC_SUSPECTED_VIOLATION,
    SC_SHOP_OPENED,
    SC_SHOP_CLOSED,
    SC_GUESS_OPENED,
    SC_GUESS_CLOSED,
    SC_PK_INVITATION,
    SC_PK_STATISTIC,
    SC_RIDDLE_OPENED,
    SC_RIDDLE_CLOESED,
    SC_RIDE_CHANGED,
    SC_BET_CHANGED,
    SC_BET_CLOSED,
    SC_LIVE_SPECIAL_ACCOUNT_CONFIG_STATE,
    SC_LIVE_WARNING_MASK_STATUS_CHANGED_AUDIENCE,
  ];

  static final $core.Map<$core.int, PayloadType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PayloadType? valueOf($core.int value) => _byValue[value];

  const PayloadType._($core.int v, $core.String n) : super(v, n);
}

class WebLiveAssistantType extends $pb.ProtobufEnum {
  static const WebLiveAssistantType WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE = WebLiveAssistantType._(0, _omitEnumNames ? '' : 'WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE');
  static const WebLiveAssistantType SUPER = WebLiveAssistantType._(1, _omitEnumNames ? '' : 'SUPER');
  static const WebLiveAssistantType JUNIOR = WebLiveAssistantType._(2, _omitEnumNames ? '' : 'JUNIOR');

  static const $core.List<WebLiveAssistantType> values = <WebLiveAssistantType> [
    WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE,
    SUPER,
    JUNIOR,
  ];

  static final $core.Map<$core.int, WebLiveAssistantType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static WebLiveAssistantType? valueOf($core.int value) => _byValue[value];

  const WebLiveAssistantType._($core.int v, $core.String n) : super(v, n);
}

class WebCommentFeedShowType extends $pb.ProtobufEnum {
  static const WebCommentFeedShowType FEED_SHOW_UNKNOWN = WebCommentFeedShowType._(0, _omitEnumNames ? '' : 'FEED_SHOW_UNKNOWN');
  static const WebCommentFeedShowType FEED_SHOW_NORMAL = WebCommentFeedShowType._(1, _omitEnumNames ? '' : 'FEED_SHOW_NORMAL');
  static const WebCommentFeedShowType FEED_HIDDEN = WebCommentFeedShowType._(2, _omitEnumNames ? '' : 'FEED_HIDDEN');

  static const $core.List<WebCommentFeedShowType> values = <WebCommentFeedShowType> [
    FEED_SHOW_UNKNOWN,
    FEED_SHOW_NORMAL,
    FEED_HIDDEN,
  ];

  static final $core.Map<$core.int, WebCommentFeedShowType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static WebCommentFeedShowType? valueOf($core.int value) => _byValue[value];

  const WebCommentFeedShowType._($core.int v, $core.String n) : super(v, n);
}

class AssistantType extends $pb.ProtobufEnum {
  static const AssistantType UNKNOWN_ASSISTANT_TYPE = AssistantType._(0, _omitEnumNames ? '' : 'UNKNOWN_ASSISTANT_TYPE');
  static const AssistantType ASSISTANT_SUPER = AssistantType._(1, _omitEnumNames ? '' : 'ASSISTANT_SUPER');
  static const AssistantType ASSISTANT_JUNIOR = AssistantType._(2, _omitEnumNames ? '' : 'ASSISTANT_JUNIOR');

  static const $core.List<AssistantType> values = <AssistantType> [
    UNKNOWN_ASSISTANT_TYPE,
    ASSISTANT_SUPER,
    ASSISTANT_JUNIOR,
  ];

  static final $core.Map<$core.int, AssistantType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static AssistantType? valueOf($core.int value) => _byValue[value];

  const AssistantType._($core.int v, $core.String n) : super(v, n);
}

class StyleType extends $pb.ProtobufEnum {
  static const StyleType UNKNOWN_STYLE = StyleType._(0, _omitEnumNames ? '' : 'UNKNOWN_STYLE');
  static const StyleType BATCH_STAR_0 = StyleType._(1, _omitEnumNames ? '' : 'BATCH_STAR_0');
  static const StyleType BATCH_STAR_1 = StyleType._(2, _omitEnumNames ? '' : 'BATCH_STAR_1');
  static const StyleType BATCH_STAR_2 = StyleType._(3, _omitEnumNames ? '' : 'BATCH_STAR_2');
  static const StyleType BATCH_STAR_3 = StyleType._(4, _omitEnumNames ? '' : 'BATCH_STAR_3');
  static const StyleType BATCH_STAR_4 = StyleType._(5, _omitEnumNames ? '' : 'BATCH_STAR_4');
  static const StyleType BATCH_STAR_5 = StyleType._(6, _omitEnumNames ? '' : 'BATCH_STAR_5');
  static const StyleType BATCH_STAR_6 = StyleType._(7, _omitEnumNames ? '' : 'BATCH_STAR_6');

  static const $core.List<StyleType> values = <StyleType> [
    UNKNOWN_STYLE,
    BATCH_STAR_0,
    BATCH_STAR_1,
    BATCH_STAR_2,
    BATCH_STAR_3,
    BATCH_STAR_4,
    BATCH_STAR_5,
    BATCH_STAR_6,
  ];

  static final $core.Map<$core.int, StyleType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static StyleType? valueOf($core.int value) => _byValue[value];

  const StyleType._($core.int v, $core.String n) : super(v, n);
}

class DisplayType extends $pb.ProtobufEnum {
  static const DisplayType UNKNOWN_DISPLAY_TYPE = DisplayType._(0, _omitEnumNames ? '' : 'UNKNOWN_DISPLAY_TYPE');
  static const DisplayType COMMENT = DisplayType._(1, _omitEnumNames ? '' : 'COMMENT');
  static const DisplayType ALERT = DisplayType._(2, _omitEnumNames ? '' : 'ALERT');
  static const DisplayType TOAST = DisplayType._(3, _omitEnumNames ? '' : 'TOAST');

  static const $core.List<DisplayType> values = <DisplayType> [
    UNKNOWN_DISPLAY_TYPE,
    COMMENT,
    ALERT,
    TOAST,
  ];

  static final $core.Map<$core.int, DisplayType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DisplayType? valueOf($core.int value) => _byValue[value];

  const DisplayType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
