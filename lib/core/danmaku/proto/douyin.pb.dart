import 'dart:core' as $core;
import 'douyin.pbenum.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
// This is a generated file - do not edit.
//
// Generated from douyin.proto.

// ignore: invalid_language_version_override
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'douyin.pbenum.dart';

class Response extends $pb.GeneratedMessage {
  factory Response({
    $core.Iterable<Message>? messagesList,
    $core.String? cursor,
    $fixnum.Int64? fetchInterval,
    $fixnum.Int64? now,
    $core.String? internalExt,
    $core.int? fetchType,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? routeParams,
    $fixnum.Int64? heartbeatDuration,
    $core.bool? needAck,
    $core.String? pushServer,
    $core.String? liveCursor,
    $core.bool? historyNoMore,
  }) {
    final result = create();
    if (messagesList != null) result.messagesList.addAll(messagesList);
    if (cursor != null) result.cursor = cursor;
    if (fetchInterval != null) result.fetchInterval = fetchInterval;
    if (now != null) result.now = now;
    if (internalExt != null) result.internalExt = internalExt;
    if (fetchType != null) result.fetchType = fetchType;
    if (routeParams != null) result.routeParams.addEntries(routeParams);
    if (heartbeatDuration != null) result.heartbeatDuration = heartbeatDuration;
    if (needAck != null) result.needAck = needAck;
    if (pushServer != null) result.pushServer = pushServer;
    if (liveCursor != null) result.liveCursor = liveCursor;
    if (historyNoMore != null) result.historyNoMore = historyNoMore;
    return result;
  }

  Response._();

  factory Response.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory Response.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Response',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..pPM<Message>(1, _omitFieldNames ? '' : 'messagesList', protoName: 'messagesList', subBuilder: Message.create)
        ..aOS(2, _omitFieldNames ? '' : 'cursor')
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'fetchInterval',
          $pb.PbFieldType.OU6,
          protoName: 'fetchInterval',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'now', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOS(5, _omitFieldNames ? '' : 'internalExt', protoName: 'internalExt')
        ..aI(6, _omitFieldNames ? '' : 'fetchType', protoName: 'fetchType', fieldType: $pb.PbFieldType.OU3)
        ..m<$core.String, $core.String>(
          7,
          _omitFieldNames ? '' : 'routeParams',
          protoName: 'routeParams',
          entryClassName: 'Response.RouteParamsEntry',
          keyFieldType: $pb.PbFieldType.OS,
          valueFieldType: $pb.PbFieldType.OS,
          packageName: const $pb.PackageName('douyin'),
        )
        ..a<$fixnum.Int64>(
          8,
          _omitFieldNames ? '' : 'heartbeatDuration',
          $pb.PbFieldType.OU6,
          protoName: 'heartbeatDuration',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOB(9, _omitFieldNames ? '' : 'needAck', protoName: 'needAck')
        ..aOS(10, _omitFieldNames ? '' : 'pushServer', protoName: 'pushServer')
        ..aOS(11, _omitFieldNames ? '' : 'liveCursor', protoName: 'liveCursor')
        ..aOB(12, _omitFieldNames ? '' : 'historyNoMore', protoName: 'historyNoMore')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Response copyWith(void Function(Response) updates) =>
      super.copyWith((message) => updates(message as Response)) as Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Response create() => Response._();
  @$core.override
  Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Response>(create);
  static Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Message> get messagesList => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get cursor => $_getSZ(1);
  @$pb.TagNumber(2)
  set cursor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCursor() => $_has(1);
  @$pb.TagNumber(2)
  void clearCursor() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get fetchInterval => $_getI64(2);
  @$pb.TagNumber(3)
  set fetchInterval($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFetchInterval() => $_has(2);
  @$pb.TagNumber(3)
  void clearFetchInterval() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get now => $_getI64(3);
  @$pb.TagNumber(4)
  set now($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNow() => $_has(3);
  @$pb.TagNumber(4)
  void clearNow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get internalExt => $_getSZ(4);
  @$pb.TagNumber(5)
  set internalExt($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInternalExt() => $_has(4);
  @$pb.TagNumber(5)
  void clearInternalExt() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get fetchType => $_getIZ(5);
  @$pb.TagNumber(6)
  set fetchType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFetchType() => $_has(5);
  @$pb.TagNumber(6)
  void clearFetchType() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, $core.String> get routeParams => $_getMap(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get heartbeatDuration => $_getI64(7);
  @$pb.TagNumber(8)
  set heartbeatDuration($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHeartbeatDuration() => $_has(7);
  @$pb.TagNumber(8)
  void clearHeartbeatDuration() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get needAck => $_getBF(8);
  @$pb.TagNumber(9)
  set needAck($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasNeedAck() => $_has(8);
  @$pb.TagNumber(9)
  void clearNeedAck() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get pushServer => $_getSZ(9);
  @$pb.TagNumber(10)
  set pushServer($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPushServer() => $_has(9);
  @$pb.TagNumber(10)
  void clearPushServer() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get liveCursor => $_getSZ(10);
  @$pb.TagNumber(11)
  set liveCursor($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLiveCursor() => $_has(10);
  @$pb.TagNumber(11)
  void clearLiveCursor() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get historyNoMore => $_getBF(11);
  @$pb.TagNumber(12)
  set historyNoMore($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasHistoryNoMore() => $_has(11);
  @$pb.TagNumber(12)
  void clearHistoryNoMore() => $_clearField(12);
}

class Message extends $pb.GeneratedMessage {
  factory Message({
    $core.String? method,
    $core.List<$core.int>? payload,
    $fixnum.Int64? msgId,
    $core.int? msgType,
    $fixnum.Int64? offset,
    $core.bool? needWrdsStore,
    $fixnum.Int64? wrdsVersion,
    $core.String? wrdsSubKey,
  }) {
    final result = create();
    if (method != null) result.method = method;
    if (payload != null) result.payload = payload;
    if (msgId != null) result.msgId = msgId;
    if (msgType != null) result.msgType = msgType;
    if (offset != null) result.offset = offset;
    if (needWrdsStore != null) result.needWrdsStore = needWrdsStore;
    if (wrdsVersion != null) result.wrdsVersion = wrdsVersion;
    if (wrdsSubKey != null) result.wrdsSubKey = wrdsSubKey;
    return result;
  }

  Message._();

  factory Message.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory Message.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Message',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'method')
        ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
        ..aInt64(3, _omitFieldNames ? '' : 'msgId', protoName: 'msgId')
        ..aI(4, _omitFieldNames ? '' : 'msgType', protoName: 'msgType')
        ..aInt64(5, _omitFieldNames ? '' : 'offset')
        ..aOB(6, _omitFieldNames ? '' : 'needWrdsStore', protoName: 'needWrdsStore')
        ..aInt64(7, _omitFieldNames ? '' : 'wrdsVersion', protoName: 'wrdsVersion')
        ..aOS(8, _omitFieldNames ? '' : 'wrdsSubKey', protoName: 'wrdsSubKey')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message copyWith(void Function(Message) updates) =>
      super.copyWith((message) => updates(message as Message)) as Message;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message create() => Message._();
  @$core.override
  Message createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Message>(create);
  static Message? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get method => $_getSZ(0);
  @$pb.TagNumber(1)
  set method($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMethod() => $_has(0);
  @$pb.TagNumber(1)
  void clearMethod() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayload() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get msgId => $_getI64(2);
  @$pb.TagNumber(3)
  set msgId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMsgId() => $_has(2);
  @$pb.TagNumber(3)
  void clearMsgId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get msgType => $_getIZ(3);
  @$pb.TagNumber(4)
  set msgType($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMsgType() => $_has(3);
  @$pb.TagNumber(4)
  void clearMsgType() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get offset => $_getI64(4);
  @$pb.TagNumber(5)
  set offset($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOffset() => $_has(4);
  @$pb.TagNumber(5)
  void clearOffset() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get needWrdsStore => $_getBF(5);
  @$pb.TagNumber(6)
  set needWrdsStore($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNeedWrdsStore() => $_has(5);
  @$pb.TagNumber(6)
  void clearNeedWrdsStore() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get wrdsVersion => $_getI64(6);
  @$pb.TagNumber(7)
  set wrdsVersion($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasWrdsVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearWrdsVersion() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get wrdsSubKey => $_getSZ(7);
  @$pb.TagNumber(8)
  set wrdsSubKey($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWrdsSubKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearWrdsSubKey() => $_clearField(8);
}

/// 聊天
class ChatMessage extends $pb.GeneratedMessage {
  factory ChatMessage({
    Common? common,
    User? user,
    $core.String? content,
    $core.bool? visibleToSender,
    Image? backgroundImage,
    $core.String? fullScreenTextColor,
    Image? backgroundImageV2,
    PublicAreaCommon? publicAreaCommon,
    Image? giftImage,
    $fixnum.Int64? agreeMsgId,
    $core.int? priorityLevel,
    LandscapeAreaCommon? landscapeAreaCommon,
    $fixnum.Int64? eventTime,
    $core.bool? sendReview,
    $core.bool? fromIntercom,
    $core.bool? intercomHideUserCard,
    $core.String? chatBy,
    $core.int? individualChatPriority,
    Text? rtfContent,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (user != null) result.user = user;
    if (content != null) result.content = content;
    if (visibleToSender != null) result.visibleToSender = visibleToSender;
    if (backgroundImage != null) result.backgroundImage = backgroundImage;
    if (fullScreenTextColor != null) result.fullScreenTextColor = fullScreenTextColor;
    if (backgroundImageV2 != null) result.backgroundImageV2 = backgroundImageV2;
    if (publicAreaCommon != null) result.publicAreaCommon = publicAreaCommon;
    if (giftImage != null) result.giftImage = giftImage;
    if (agreeMsgId != null) result.agreeMsgId = agreeMsgId;
    if (priorityLevel != null) result.priorityLevel = priorityLevel;
    if (landscapeAreaCommon != null) result.landscapeAreaCommon = landscapeAreaCommon;
    if (eventTime != null) result.eventTime = eventTime;
    if (sendReview != null) result.sendReview = sendReview;
    if (fromIntercom != null) result.fromIntercom = fromIntercom;
    if (intercomHideUserCard != null) result.intercomHideUserCard = intercomHideUserCard;
    if (chatBy != null) result.chatBy = chatBy;
    if (individualChatPriority != null) result.individualChatPriority = individualChatPriority;
    if (rtfContent != null) result.rtfContent = rtfContent;
    return result;
  }

  ChatMessage._();

  factory ChatMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory ChatMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'ChatMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..aOS(3, _omitFieldNames ? '' : 'content')
        ..aOB(4, _omitFieldNames ? '' : 'visibleToSender', protoName: 'visibleToSender')
        ..aOM<Image>(
          5,
          _omitFieldNames ? '' : 'backgroundImage',
          protoName: 'backgroundImage',
          subBuilder: Image.create,
        )
        ..aOS(6, _omitFieldNames ? '' : 'fullScreenTextColor', protoName: 'fullScreenTextColor')
        ..aOM<Image>(
          7,
          _omitFieldNames ? '' : 'backgroundImageV2',
          protoName: 'backgroundImageV2',
          subBuilder: Image.create,
        )
        ..aOM<PublicAreaCommon>(
          8,
          _omitFieldNames ? '' : 'publicAreaCommon',
          protoName: 'publicAreaCommon',
          subBuilder: PublicAreaCommon.create,
        )
        ..aOM<Image>(9, _omitFieldNames ? '' : 'giftImage', protoName: 'giftImage', subBuilder: Image.create)
        ..a<$fixnum.Int64>(
          11,
          _omitFieldNames ? '' : 'agreeMsgId',
          $pb.PbFieldType.OU6,
          protoName: 'agreeMsgId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aI(12, _omitFieldNames ? '' : 'priorityLevel', protoName: 'priorityLevel', fieldType: $pb.PbFieldType.OU3)
        ..aOM<LandscapeAreaCommon>(
          13,
          _omitFieldNames ? '' : 'landscapeAreaCommon',
          protoName: 'landscapeAreaCommon',
          subBuilder: LandscapeAreaCommon.create,
        )
        ..a<$fixnum.Int64>(
          15,
          _omitFieldNames ? '' : 'eventTime',
          $pb.PbFieldType.OU6,
          protoName: 'eventTime',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOB(16, _omitFieldNames ? '' : 'sendReview', protoName: 'sendReview')
        ..aOB(17, _omitFieldNames ? '' : 'fromIntercom', protoName: 'fromIntercom')
        ..aOB(18, _omitFieldNames ? '' : 'intercomHideUserCard', protoName: 'intercomHideUserCard')
        ..aOS(20, _omitFieldNames ? '' : 'chatBy', protoName: 'chatBy')
        ..aI(
          21,
          _omitFieldNames ? '' : 'individualChatPriority',
          protoName: 'individualChatPriority',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..aOM<Text>(22, _omitFieldNames ? '' : 'rtfContent', protoName: 'rtfContent', subBuilder: Text.create)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMessage copyWith(void Function(ChatMessage) updates) =>
      super.copyWith((message) => updates(message as ChatMessage)) as ChatMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatMessage create() => ChatMessage._();
  @$core.override
  ChatMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatMessage>(create);
  static ChatMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get visibleToSender => $_getBF(3);
  @$pb.TagNumber(4)
  set visibleToSender($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVisibleToSender() => $_has(3);
  @$pb.TagNumber(4)
  void clearVisibleToSender() => $_clearField(4);

  @$pb.TagNumber(5)
  Image get backgroundImage => $_getN(4);
  @$pb.TagNumber(5)
  set backgroundImage(Image value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBackgroundImage() => $_has(4);
  @$pb.TagNumber(5)
  void clearBackgroundImage() => $_clearField(5);
  @$pb.TagNumber(5)
  Image ensureBackgroundImage() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get fullScreenTextColor => $_getSZ(5);
  @$pb.TagNumber(6)
  set fullScreenTextColor($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFullScreenTextColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearFullScreenTextColor() => $_clearField(6);

  @$pb.TagNumber(7)
  Image get backgroundImageV2 => $_getN(6);
  @$pb.TagNumber(7)
  set backgroundImageV2(Image value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasBackgroundImageV2() => $_has(6);
  @$pb.TagNumber(7)
  void clearBackgroundImageV2() => $_clearField(7);
  @$pb.TagNumber(7)
  Image ensureBackgroundImageV2() => $_ensure(6);

  @$pb.TagNumber(8)
  PublicAreaCommon get publicAreaCommon => $_getN(7);
  @$pb.TagNumber(8)
  set publicAreaCommon(PublicAreaCommon value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasPublicAreaCommon() => $_has(7);
  @$pb.TagNumber(8)
  void clearPublicAreaCommon() => $_clearField(8);
  @$pb.TagNumber(8)
  PublicAreaCommon ensurePublicAreaCommon() => $_ensure(7);

  @$pb.TagNumber(9)
  Image get giftImage => $_getN(8);
  @$pb.TagNumber(9)
  set giftImage(Image value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasGiftImage() => $_has(8);
  @$pb.TagNumber(9)
  void clearGiftImage() => $_clearField(9);
  @$pb.TagNumber(9)
  Image ensureGiftImage() => $_ensure(8);

  @$pb.TagNumber(11)
  $fixnum.Int64 get agreeMsgId => $_getI64(9);
  @$pb.TagNumber(11)
  set agreeMsgId($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(11)
  $core.bool hasAgreeMsgId() => $_has(9);
  @$pb.TagNumber(11)
  void clearAgreeMsgId() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get priorityLevel => $_getIZ(10);
  @$pb.TagNumber(12)
  set priorityLevel($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(12)
  $core.bool hasPriorityLevel() => $_has(10);
  @$pb.TagNumber(12)
  void clearPriorityLevel() => $_clearField(12);

  @$pb.TagNumber(13)
  LandscapeAreaCommon get landscapeAreaCommon => $_getN(11);
  @$pb.TagNumber(13)
  set landscapeAreaCommon(LandscapeAreaCommon value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasLandscapeAreaCommon() => $_has(11);
  @$pb.TagNumber(13)
  void clearLandscapeAreaCommon() => $_clearField(13);
  @$pb.TagNumber(13)
  LandscapeAreaCommon ensureLandscapeAreaCommon() => $_ensure(11);

  @$pb.TagNumber(15)
  $fixnum.Int64 get eventTime => $_getI64(12);
  @$pb.TagNumber(15)
  set eventTime($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(15)
  $core.bool hasEventTime() => $_has(12);
  @$pb.TagNumber(15)
  void clearEventTime() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get sendReview => $_getBF(13);
  @$pb.TagNumber(16)
  set sendReview($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(16)
  $core.bool hasSendReview() => $_has(13);
  @$pb.TagNumber(16)
  void clearSendReview() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get fromIntercom => $_getBF(14);
  @$pb.TagNumber(17)
  set fromIntercom($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(17)
  $core.bool hasFromIntercom() => $_has(14);
  @$pb.TagNumber(17)
  void clearFromIntercom() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.bool get intercomHideUserCard => $_getBF(15);
  @$pb.TagNumber(18)
  set intercomHideUserCard($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(18)
  $core.bool hasIntercomHideUserCard() => $_has(15);
  @$pb.TagNumber(18)
  void clearIntercomHideUserCard() => $_clearField(18);

  /// repeated chatTagsList = 19;
  @$pb.TagNumber(20)
  $core.String get chatBy => $_getSZ(16);
  @$pb.TagNumber(20)
  set chatBy($core.String value) => $_setString(16, value);
  @$pb.TagNumber(20)
  $core.bool hasChatBy() => $_has(16);
  @$pb.TagNumber(20)
  void clearChatBy() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.int get individualChatPriority => $_getIZ(17);
  @$pb.TagNumber(21)
  set individualChatPriority($core.int value) => $_setUnsignedInt32(17, value);
  @$pb.TagNumber(21)
  $core.bool hasIndividualChatPriority() => $_has(17);
  @$pb.TagNumber(21)
  void clearIndividualChatPriority() => $_clearField(21);

  @$pb.TagNumber(22)
  Text get rtfContent => $_getN(18);
  @$pb.TagNumber(22)
  set rtfContent(Text value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasRtfContent() => $_has(18);
  @$pb.TagNumber(22)
  void clearRtfContent() => $_clearField(22);
  @$pb.TagNumber(22)
  Text ensureRtfContent() => $_ensure(18);
}

class LandscapeAreaCommon extends $pb.GeneratedMessage {
  factory LandscapeAreaCommon({
    $core.bool? showHead,
    $core.bool? showNickname,
    $core.bool? showFontColor,
    $core.Iterable<$core.String>? colorValueList,
    $core.Iterable<CommentTypeTag>? commentTypeTagsList,
  }) {
    final result = create();
    if (showHead != null) result.showHead = showHead;
    if (showNickname != null) result.showNickname = showNickname;
    if (showFontColor != null) result.showFontColor = showFontColor;
    if (colorValueList != null) result.colorValueList.addAll(colorValueList);
    if (commentTypeTagsList != null) result.commentTypeTagsList.addAll(commentTypeTagsList);
    return result;
  }

  LandscapeAreaCommon._();

  factory LandscapeAreaCommon.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory LandscapeAreaCommon.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'LandscapeAreaCommon',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOB(1, _omitFieldNames ? '' : 'showHead', protoName: 'showHead')
        ..aOB(2, _omitFieldNames ? '' : 'showNickname', protoName: 'showNickname')
        ..aOB(3, _omitFieldNames ? '' : 'showFontColor', protoName: 'showFontColor')
        ..pPS(4, _omitFieldNames ? '' : 'colorValueList', protoName: 'colorValueList')
        ..pc<CommentTypeTag>(
          5,
          _omitFieldNames ? '' : 'commentTypeTagsList',
          $pb.PbFieldType.KE,
          protoName: 'commentTypeTagsList',
          valueOf: CommentTypeTag.valueOf,
          enumValues: CommentTypeTag.values,
          defaultEnumValue: CommentTypeTag.COMMENTTYPETAGUNKNOWN,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LandscapeAreaCommon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LandscapeAreaCommon copyWith(void Function(LandscapeAreaCommon) updates) =>
      super.copyWith((message) => updates(message as LandscapeAreaCommon)) as LandscapeAreaCommon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LandscapeAreaCommon create() => LandscapeAreaCommon._();
  @$core.override
  LandscapeAreaCommon createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LandscapeAreaCommon getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LandscapeAreaCommon>(create);
  static LandscapeAreaCommon? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get showHead => $_getBF(0);
  @$pb.TagNumber(1)
  set showHead($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShowHead() => $_has(0);
  @$pb.TagNumber(1)
  void clearShowHead() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get showNickname => $_getBF(1);
  @$pb.TagNumber(2)
  set showNickname($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShowNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearShowNickname() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get showFontColor => $_getBF(2);
  @$pb.TagNumber(3)
  set showFontColor($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShowFontColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearShowFontColor() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get colorValueList => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<CommentTypeTag> get commentTypeTagsList => $_getList(4);
}

class RoomUserSeqMessage extends $pb.GeneratedMessage {
  factory RoomUserSeqMessage({
    Common? common,
    $core.Iterable<RoomUserSeqMessageContributor>? ranksList,
    $fixnum.Int64? total,
    $core.String? popStr,
    $core.Iterable<RoomUserSeqMessageContributor>? seatsList,
    $fixnum.Int64? popularity,
    $fixnum.Int64? totalUser,
    $core.String? totalUserStr,
    $core.String? totalStr,
    $core.String? onlineUserForAnchor,
    $core.String? totalPvForAnchor,
    $core.String? upRightStatsStr,
    $core.String? upRightStatsStrComplete,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (ranksList != null) result.ranksList.addAll(ranksList);
    if (total != null) result.total = total;
    if (popStr != null) result.popStr = popStr;
    if (seatsList != null) result.seatsList.addAll(seatsList);
    if (popularity != null) result.popularity = popularity;
    if (totalUser != null) result.totalUser = totalUser;
    if (totalUserStr != null) result.totalUserStr = totalUserStr;
    if (totalStr != null) result.totalStr = totalStr;
    if (onlineUserForAnchor != null) result.onlineUserForAnchor = onlineUserForAnchor;
    if (totalPvForAnchor != null) result.totalPvForAnchor = totalPvForAnchor;
    if (upRightStatsStr != null) result.upRightStatsStr = upRightStatsStr;
    if (upRightStatsStrComplete != null) result.upRightStatsStrComplete = upRightStatsStrComplete;
    return result;
  }

  RoomUserSeqMessage._();

  factory RoomUserSeqMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory RoomUserSeqMessage.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'RoomUserSeqMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..pPM<RoomUserSeqMessageContributor>(
          2,
          _omitFieldNames ? '' : 'ranksList',
          protoName: 'ranksList',
          subBuilder: RoomUserSeqMessageContributor.create,
        )
        ..aInt64(3, _omitFieldNames ? '' : 'total')
        ..aOS(4, _omitFieldNames ? '' : 'popStr', protoName: 'popStr')
        ..pPM<RoomUserSeqMessageContributor>(
          5,
          _omitFieldNames ? '' : 'seatsList',
          protoName: 'seatsList',
          subBuilder: RoomUserSeqMessageContributor.create,
        )
        ..aInt64(6, _omitFieldNames ? '' : 'popularity')
        ..aInt64(7, _omitFieldNames ? '' : 'totalUser', protoName: 'totalUser')
        ..aOS(8, _omitFieldNames ? '' : 'totalUserStr', protoName: 'totalUserStr')
        ..aOS(9, _omitFieldNames ? '' : 'totalStr', protoName: 'totalStr')
        ..aOS(10, _omitFieldNames ? '' : 'onlineUserForAnchor', protoName: 'onlineUserForAnchor')
        ..aOS(11, _omitFieldNames ? '' : 'totalPvForAnchor', protoName: 'totalPvForAnchor')
        ..aOS(12, _omitFieldNames ? '' : 'upRightStatsStr', protoName: 'upRightStatsStr')
        ..aOS(13, _omitFieldNames ? '' : 'upRightStatsStrComplete', protoName: 'upRightStatsStrComplete')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoomUserSeqMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoomUserSeqMessage copyWith(void Function(RoomUserSeqMessage) updates) =>
      super.copyWith((message) => updates(message as RoomUserSeqMessage)) as RoomUserSeqMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoomUserSeqMessage create() => RoomUserSeqMessage._();
  @$core.override
  RoomUserSeqMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoomUserSeqMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoomUserSeqMessage>(create);
  static RoomUserSeqMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<RoomUserSeqMessageContributor> get ranksList => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get total => $_getI64(2);
  @$pb.TagNumber(3)
  set total($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotal() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get popStr => $_getSZ(3);
  @$pb.TagNumber(4)
  set popStr($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPopStr() => $_has(3);
  @$pb.TagNumber(4)
  void clearPopStr() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<RoomUserSeqMessageContributor> get seatsList => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get popularity => $_getI64(5);
  @$pb.TagNumber(6)
  set popularity($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPopularity() => $_has(5);
  @$pb.TagNumber(6)
  void clearPopularity() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get totalUser => $_getI64(6);
  @$pb.TagNumber(7)
  set totalUser($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalUser() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalUser() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get totalUserStr => $_getSZ(7);
  @$pb.TagNumber(8)
  set totalUserStr($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTotalUserStr() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalUserStr() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get totalStr => $_getSZ(8);
  @$pb.TagNumber(9)
  set totalStr($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTotalStr() => $_has(8);
  @$pb.TagNumber(9)
  void clearTotalStr() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get onlineUserForAnchor => $_getSZ(9);
  @$pb.TagNumber(10)
  set onlineUserForAnchor($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasOnlineUserForAnchor() => $_has(9);
  @$pb.TagNumber(10)
  void clearOnlineUserForAnchor() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get totalPvForAnchor => $_getSZ(10);
  @$pb.TagNumber(11)
  set totalPvForAnchor($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTotalPvForAnchor() => $_has(10);
  @$pb.TagNumber(11)
  void clearTotalPvForAnchor() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get upRightStatsStr => $_getSZ(11);
  @$pb.TagNumber(12)
  set upRightStatsStr($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasUpRightStatsStr() => $_has(11);
  @$pb.TagNumber(12)
  void clearUpRightStatsStr() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get upRightStatsStrComplete => $_getSZ(12);
  @$pb.TagNumber(13)
  set upRightStatsStrComplete($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasUpRightStatsStrComplete() => $_has(12);
  @$pb.TagNumber(13)
  void clearUpRightStatsStrComplete() => $_clearField(13);
}

class CommonTextMessage extends $pb.GeneratedMessage {
  factory CommonTextMessage({Common? common, User? user, $core.String? scene}) {
    final result = create();
    if (common != null) result.common = common;
    if (user != null) result.user = user;
    if (scene != null) result.scene = scene;
    return result;
  }

  CommonTextMessage._();

  factory CommonTextMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory CommonTextMessage.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'CommonTextMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..aOS(3, _omitFieldNames ? '' : 'scene')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonTextMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonTextMessage copyWith(void Function(CommonTextMessage) updates) =>
      super.copyWith((message) => updates(message as CommonTextMessage)) as CommonTextMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommonTextMessage create() => CommonTextMessage._();
  @$core.override
  CommonTextMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommonTextMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommonTextMessage>(create);
  static CommonTextMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get scene => $_getSZ(2);
  @$pb.TagNumber(3)
  set scene($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScene() => $_has(2);
  @$pb.TagNumber(3)
  void clearScene() => $_clearField(3);
}

class UpdateFanTicketMessage extends $pb.GeneratedMessage {
  factory UpdateFanTicketMessage({
    Common? common,
    $core.String? roomFanTicketCountText,
    $fixnum.Int64? roomFanTicketCount,
    $core.bool? forceUpdate,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (roomFanTicketCountText != null) result.roomFanTicketCountText = roomFanTicketCountText;
    if (roomFanTicketCount != null) result.roomFanTicketCount = roomFanTicketCount;
    if (forceUpdate != null) result.forceUpdate = forceUpdate;
    return result;
  }

  UpdateFanTicketMessage._();

  factory UpdateFanTicketMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory UpdateFanTicketMessage.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'UpdateFanTicketMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..aOS(2, _omitFieldNames ? '' : 'roomFanTicketCountText', protoName: 'roomFanTicketCountText')
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'roomFanTicketCount',
          $pb.PbFieldType.OU6,
          protoName: 'roomFanTicketCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOB(4, _omitFieldNames ? '' : 'forceUpdate', protoName: 'forceUpdate')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFanTicketMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFanTicketMessage copyWith(void Function(UpdateFanTicketMessage) updates) =>
      super.copyWith((message) => updates(message as UpdateFanTicketMessage)) as UpdateFanTicketMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateFanTicketMessage create() => UpdateFanTicketMessage._();
  @$core.override
  UpdateFanTicketMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateFanTicketMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateFanTicketMessage>(create);
  static UpdateFanTicketMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get roomFanTicketCountText => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomFanTicketCountText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomFanTicketCountText() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomFanTicketCountText() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get roomFanTicketCount => $_getI64(2);
  @$pb.TagNumber(3)
  set roomFanTicketCount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoomFanTicketCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomFanTicketCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get forceUpdate => $_getBF(3);
  @$pb.TagNumber(4)
  set forceUpdate($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasForceUpdate() => $_has(3);
  @$pb.TagNumber(4)
  void clearForceUpdate() => $_clearField(4);
}

class RoomUserSeqMessageContributor extends $pb.GeneratedMessage {
  factory RoomUserSeqMessageContributor({
    $fixnum.Int64? score,
    User? user,
    $fixnum.Int64? rank,
    $fixnum.Int64? delta,
    $core.bool? isHidden,
    $core.String? scoreDescription,
    $core.String? exactlyScore,
  }) {
    final result = create();
    if (score != null) result.score = score;
    if (user != null) result.user = user;
    if (rank != null) result.rank = rank;
    if (delta != null) result.delta = delta;
    if (isHidden != null) result.isHidden = isHidden;
    if (scoreDescription != null) result.scoreDescription = scoreDescription;
    if (exactlyScore != null) result.exactlyScore = exactlyScore;
    return result;
  }

  RoomUserSeqMessageContributor._();

  factory RoomUserSeqMessageContributor.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory RoomUserSeqMessageContributor.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'RoomUserSeqMessageContributor',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'score', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'rank', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'delta', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOB(5, _omitFieldNames ? '' : 'isHidden', protoName: 'isHidden')
        ..aOS(6, _omitFieldNames ? '' : 'scoreDescription', protoName: 'scoreDescription')
        ..aOS(7, _omitFieldNames ? '' : 'exactlyScore', protoName: 'exactlyScore')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoomUserSeqMessageContributor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoomUserSeqMessageContributor copyWith(void Function(RoomUserSeqMessageContributor) updates) =>
      super.copyWith((message) => updates(message as RoomUserSeqMessageContributor)) as RoomUserSeqMessageContributor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoomUserSeqMessageContributor create() => RoomUserSeqMessageContributor._();
  @$core.override
  RoomUserSeqMessageContributor createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoomUserSeqMessageContributor getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoomUserSeqMessageContributor>(create);
  static RoomUserSeqMessageContributor? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get score => $_getI64(0);
  @$pb.TagNumber(1)
  set score($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScore() => $_has(0);
  @$pb.TagNumber(1)
  void clearScore() => $_clearField(1);

  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get rank => $_getI64(2);
  @$pb.TagNumber(3)
  set rank($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRank() => $_has(2);
  @$pb.TagNumber(3)
  void clearRank() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get delta => $_getI64(3);
  @$pb.TagNumber(4)
  set delta($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDelta() => $_has(3);
  @$pb.TagNumber(4)
  void clearDelta() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isHidden => $_getBF(4);
  @$pb.TagNumber(5)
  set isHidden($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsHidden() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsHidden() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get scoreDescription => $_getSZ(5);
  @$pb.TagNumber(6)
  set scoreDescription($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScoreDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearScoreDescription() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get exactlyScore => $_getSZ(6);
  @$pb.TagNumber(7)
  set exactlyScore($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExactlyScore() => $_has(6);
  @$pb.TagNumber(7)
  void clearExactlyScore() => $_clearField(7);
}

/// 礼物消息
class GiftMessage extends $pb.GeneratedMessage {
  factory GiftMessage({
    Common? common,
    $fixnum.Int64? giftId,
    $fixnum.Int64? fanTicketCount,
    $fixnum.Int64? groupCount,
    $fixnum.Int64? repeatCount,
    $fixnum.Int64? comboCount,
    User? user,
    User? toUser,
    $core.int? repeatEnd,
    TextEffect? textEffect,
    $fixnum.Int64? groupId,
    $fixnum.Int64? incomeTaskgifts,
    $fixnum.Int64? roomFanTicketCount,
    GiftIMPriority? priority,
    GiftStruct? gift,
    $core.String? logId,
    $fixnum.Int64? sendType,
    PublicAreaCommon? publicAreaCommon,
    Text? trayDisplayText,
    $fixnum.Int64? bannedDisplayEffects,
    $core.bool? displayForSelf,
    $core.String? interactGiftInfo,
    $core.String? diyItemInfo,
    $core.Iterable<$fixnum.Int64>? minAssetSetList,
    $fixnum.Int64? totalCount,
    $core.int? clientGiftSource,
    $core.Iterable<$fixnum.Int64>? toUserIdsList,
    $fixnum.Int64? sendTime,
    $fixnum.Int64? forceDisplayEffects,
    $core.String? traceId,
    $fixnum.Int64? effectDisplayTs,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (giftId != null) result.giftId = giftId;
    if (fanTicketCount != null) result.fanTicketCount = fanTicketCount;
    if (groupCount != null) result.groupCount = groupCount;
    if (repeatCount != null) result.repeatCount = repeatCount;
    if (comboCount != null) result.comboCount = comboCount;
    if (user != null) result.user = user;
    if (toUser != null) result.toUser = toUser;
    if (repeatEnd != null) result.repeatEnd = repeatEnd;
    if (textEffect != null) result.textEffect = textEffect;
    if (groupId != null) result.groupId = groupId;
    if (incomeTaskgifts != null) result.incomeTaskgifts = incomeTaskgifts;
    if (roomFanTicketCount != null) result.roomFanTicketCount = roomFanTicketCount;
    if (priority != null) result.priority = priority;
    if (gift != null) result.gift = gift;
    if (logId != null) result.logId = logId;
    if (sendType != null) result.sendType = sendType;
    if (publicAreaCommon != null) result.publicAreaCommon = publicAreaCommon;
    if (trayDisplayText != null) result.trayDisplayText = trayDisplayText;
    if (bannedDisplayEffects != null) result.bannedDisplayEffects = bannedDisplayEffects;
    if (displayForSelf != null) result.displayForSelf = displayForSelf;
    if (interactGiftInfo != null) result.interactGiftInfo = interactGiftInfo;
    if (diyItemInfo != null) result.diyItemInfo = diyItemInfo;
    if (minAssetSetList != null) result.minAssetSetList.addAll(minAssetSetList);
    if (totalCount != null) result.totalCount = totalCount;
    if (clientGiftSource != null) result.clientGiftSource = clientGiftSource;
    if (toUserIdsList != null) result.toUserIdsList.addAll(toUserIdsList);
    if (sendTime != null) result.sendTime = sendTime;
    if (forceDisplayEffects != null) result.forceDisplayEffects = forceDisplayEffects;
    if (traceId != null) result.traceId = traceId;
    if (effectDisplayTs != null) result.effectDisplayTs = effectDisplayTs;
    return result;
  }

  GiftMessage._();

  factory GiftMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory GiftMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'GiftMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'giftId',
          $pb.PbFieldType.OU6,
          protoName: 'giftId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'fanTicketCount',
          $pb.PbFieldType.OU6,
          protoName: 'fanTicketCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          4,
          _omitFieldNames ? '' : 'groupCount',
          $pb.PbFieldType.OU6,
          protoName: 'groupCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          5,
          _omitFieldNames ? '' : 'repeatCount',
          $pb.PbFieldType.OU6,
          protoName: 'repeatCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          6,
          _omitFieldNames ? '' : 'comboCount',
          $pb.PbFieldType.OU6,
          protoName: 'comboCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<User>(7, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..aOM<User>(8, _omitFieldNames ? '' : 'toUser', protoName: 'toUser', subBuilder: User.create)
        ..aI(9, _omitFieldNames ? '' : 'repeatEnd', protoName: 'repeatEnd', fieldType: $pb.PbFieldType.OU3)
        ..aOM<TextEffect>(
          10,
          _omitFieldNames ? '' : 'textEffect',
          protoName: 'textEffect',
          subBuilder: TextEffect.create,
        )
        ..a<$fixnum.Int64>(
          11,
          _omitFieldNames ? '' : 'groupId',
          $pb.PbFieldType.OU6,
          protoName: 'groupId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          12,
          _omitFieldNames ? '' : 'incomeTaskgifts',
          $pb.PbFieldType.OU6,
          protoName: 'incomeTaskgifts',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          13,
          _omitFieldNames ? '' : 'roomFanTicketCount',
          $pb.PbFieldType.OU6,
          protoName: 'roomFanTicketCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<GiftIMPriority>(14, _omitFieldNames ? '' : 'priority', subBuilder: GiftIMPriority.create)
        ..aOM<GiftStruct>(15, _omitFieldNames ? '' : 'gift', subBuilder: GiftStruct.create)
        ..aOS(16, _omitFieldNames ? '' : 'logId', protoName: 'logId')
        ..a<$fixnum.Int64>(
          17,
          _omitFieldNames ? '' : 'sendType',
          $pb.PbFieldType.OU6,
          protoName: 'sendType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<PublicAreaCommon>(
          18,
          _omitFieldNames ? '' : 'publicAreaCommon',
          protoName: 'publicAreaCommon',
          subBuilder: PublicAreaCommon.create,
        )
        ..aOM<Text>(19, _omitFieldNames ? '' : 'trayDisplayText', protoName: 'trayDisplayText', subBuilder: Text.create)
        ..a<$fixnum.Int64>(
          20,
          _omitFieldNames ? '' : 'bannedDisplayEffects',
          $pb.PbFieldType.OU6,
          protoName: 'bannedDisplayEffects',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOB(25, _omitFieldNames ? '' : 'displayForSelf', protoName: 'displayForSelf')
        ..aOS(26, _omitFieldNames ? '' : 'interactGiftInfo', protoName: 'interactGiftInfo')
        ..aOS(27, _omitFieldNames ? '' : 'diyItemInfo', protoName: 'diyItemInfo')
        ..p<$fixnum.Int64>(
          28,
          _omitFieldNames ? '' : 'minAssetSetList',
          $pb.PbFieldType.KU6,
          protoName: 'minAssetSetList',
        )
        ..a<$fixnum.Int64>(
          29,
          _omitFieldNames ? '' : 'totalCount',
          $pb.PbFieldType.OU6,
          protoName: 'totalCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aI(
          30,
          _omitFieldNames ? '' : 'clientGiftSource',
          protoName: 'clientGiftSource',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..p<$fixnum.Int64>(32, _omitFieldNames ? '' : 'toUserIdsList', $pb.PbFieldType.KU6, protoName: 'toUserIdsList')
        ..a<$fixnum.Int64>(
          33,
          _omitFieldNames ? '' : 'sendTime',
          $pb.PbFieldType.OU6,
          protoName: 'sendTime',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          34,
          _omitFieldNames ? '' : 'forceDisplayEffects',
          $pb.PbFieldType.OU6,
          protoName: 'forceDisplayEffects',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(35, _omitFieldNames ? '' : 'traceId', protoName: 'traceId')
        ..a<$fixnum.Int64>(
          36,
          _omitFieldNames ? '' : 'effectDisplayTs',
          $pb.PbFieldType.OU6,
          protoName: 'effectDisplayTs',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GiftMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GiftMessage copyWith(void Function(GiftMessage) updates) =>
      super.copyWith((message) => updates(message as GiftMessage)) as GiftMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GiftMessage create() => GiftMessage._();
  @$core.override
  GiftMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GiftMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GiftMessage>(create);
  static GiftMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get giftId => $_getI64(1);
  @$pb.TagNumber(2)
  set giftId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGiftId() => $_has(1);
  @$pb.TagNumber(2)
  void clearGiftId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get fanTicketCount => $_getI64(2);
  @$pb.TagNumber(3)
  set fanTicketCount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFanTicketCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearFanTicketCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get groupCount => $_getI64(3);
  @$pb.TagNumber(4)
  set groupCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGroupCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroupCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get repeatCount => $_getI64(4);
  @$pb.TagNumber(5)
  set repeatCount($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRepeatCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearRepeatCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get comboCount => $_getI64(5);
  @$pb.TagNumber(6)
  set comboCount($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasComboCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearComboCount() => $_clearField(6);

  @$pb.TagNumber(7)
  User get user => $_getN(6);
  @$pb.TagNumber(7)
  set user(User value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasUser() => $_has(6);
  @$pb.TagNumber(7)
  void clearUser() => $_clearField(7);
  @$pb.TagNumber(7)
  User ensureUser() => $_ensure(6);

  @$pb.TagNumber(8)
  User get toUser => $_getN(7);
  @$pb.TagNumber(8)
  set toUser(User value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasToUser() => $_has(7);
  @$pb.TagNumber(8)
  void clearToUser() => $_clearField(8);
  @$pb.TagNumber(8)
  User ensureToUser() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.int get repeatEnd => $_getIZ(8);
  @$pb.TagNumber(9)
  set repeatEnd($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRepeatEnd() => $_has(8);
  @$pb.TagNumber(9)
  void clearRepeatEnd() => $_clearField(9);

  @$pb.TagNumber(10)
  TextEffect get textEffect => $_getN(9);
  @$pb.TagNumber(10)
  set textEffect(TextEffect value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasTextEffect() => $_has(9);
  @$pb.TagNumber(10)
  void clearTextEffect() => $_clearField(10);
  @$pb.TagNumber(10)
  TextEffect ensureTextEffect() => $_ensure(9);

  @$pb.TagNumber(11)
  $fixnum.Int64 get groupId => $_getI64(10);
  @$pb.TagNumber(11)
  set groupId($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasGroupId() => $_has(10);
  @$pb.TagNumber(11)
  void clearGroupId() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get incomeTaskgifts => $_getI64(11);
  @$pb.TagNumber(12)
  set incomeTaskgifts($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIncomeTaskgifts() => $_has(11);
  @$pb.TagNumber(12)
  void clearIncomeTaskgifts() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get roomFanTicketCount => $_getI64(12);
  @$pb.TagNumber(13)
  set roomFanTicketCount($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRoomFanTicketCount() => $_has(12);
  @$pb.TagNumber(13)
  void clearRoomFanTicketCount() => $_clearField(13);

  @$pb.TagNumber(14)
  GiftIMPriority get priority => $_getN(13);
  @$pb.TagNumber(14)
  set priority(GiftIMPriority value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasPriority() => $_has(13);
  @$pb.TagNumber(14)
  void clearPriority() => $_clearField(14);
  @$pb.TagNumber(14)
  GiftIMPriority ensurePriority() => $_ensure(13);

  @$pb.TagNumber(15)
  GiftStruct get gift => $_getN(14);
  @$pb.TagNumber(15)
  set gift(GiftStruct value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasGift() => $_has(14);
  @$pb.TagNumber(15)
  void clearGift() => $_clearField(15);
  @$pb.TagNumber(15)
  GiftStruct ensureGift() => $_ensure(14);

  @$pb.TagNumber(16)
  $core.String get logId => $_getSZ(15);
  @$pb.TagNumber(16)
  set logId($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasLogId() => $_has(15);
  @$pb.TagNumber(16)
  void clearLogId() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get sendType => $_getI64(16);
  @$pb.TagNumber(17)
  set sendType($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasSendType() => $_has(16);
  @$pb.TagNumber(17)
  void clearSendType() => $_clearField(17);

  @$pb.TagNumber(18)
  PublicAreaCommon get publicAreaCommon => $_getN(17);
  @$pb.TagNumber(18)
  set publicAreaCommon(PublicAreaCommon value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasPublicAreaCommon() => $_has(17);
  @$pb.TagNumber(18)
  void clearPublicAreaCommon() => $_clearField(18);
  @$pb.TagNumber(18)
  PublicAreaCommon ensurePublicAreaCommon() => $_ensure(17);

  @$pb.TagNumber(19)
  Text get trayDisplayText => $_getN(18);
  @$pb.TagNumber(19)
  set trayDisplayText(Text value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasTrayDisplayText() => $_has(18);
  @$pb.TagNumber(19)
  void clearTrayDisplayText() => $_clearField(19);
  @$pb.TagNumber(19)
  Text ensureTrayDisplayText() => $_ensure(18);

  @$pb.TagNumber(20)
  $fixnum.Int64 get bannedDisplayEffects => $_getI64(19);
  @$pb.TagNumber(20)
  set bannedDisplayEffects($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(20)
  $core.bool hasBannedDisplayEffects() => $_has(19);
  @$pb.TagNumber(20)
  void clearBannedDisplayEffects() => $_clearField(20);

  /// GiftTrayInfo trayInfo = 21;
  /// AssetEffectMixInfo assetEffectMixInfo = 22;
  @$pb.TagNumber(25)
  $core.bool get displayForSelf => $_getBF(20);
  @$pb.TagNumber(25)
  set displayForSelf($core.bool value) => $_setBool(20, value);
  @$pb.TagNumber(25)
  $core.bool hasDisplayForSelf() => $_has(20);
  @$pb.TagNumber(25)
  void clearDisplayForSelf() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.String get interactGiftInfo => $_getSZ(21);
  @$pb.TagNumber(26)
  set interactGiftInfo($core.String value) => $_setString(21, value);
  @$pb.TagNumber(26)
  $core.bool hasInteractGiftInfo() => $_has(21);
  @$pb.TagNumber(26)
  void clearInteractGiftInfo() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.String get diyItemInfo => $_getSZ(22);
  @$pb.TagNumber(27)
  set diyItemInfo($core.String value) => $_setString(22, value);
  @$pb.TagNumber(27)
  $core.bool hasDiyItemInfo() => $_has(22);
  @$pb.TagNumber(27)
  void clearDiyItemInfo() => $_clearField(27);

  @$pb.TagNumber(28)
  $pb.PbList<$fixnum.Int64> get minAssetSetList => $_getList(23);

  @$pb.TagNumber(29)
  $fixnum.Int64 get totalCount => $_getI64(24);
  @$pb.TagNumber(29)
  set totalCount($fixnum.Int64 value) => $_setInt64(24, value);
  @$pb.TagNumber(29)
  $core.bool hasTotalCount() => $_has(24);
  @$pb.TagNumber(29)
  void clearTotalCount() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.int get clientGiftSource => $_getIZ(25);
  @$pb.TagNumber(30)
  set clientGiftSource($core.int value) => $_setUnsignedInt32(25, value);
  @$pb.TagNumber(30)
  $core.bool hasClientGiftSource() => $_has(25);
  @$pb.TagNumber(30)
  void clearClientGiftSource() => $_clearField(30);

  /// AnchorGiftData anchorGift = 31;
  @$pb.TagNumber(32)
  $pb.PbList<$fixnum.Int64> get toUserIdsList => $_getList(26);

  @$pb.TagNumber(33)
  $fixnum.Int64 get sendTime => $_getI64(27);
  @$pb.TagNumber(33)
  set sendTime($fixnum.Int64 value) => $_setInt64(27, value);
  @$pb.TagNumber(33)
  $core.bool hasSendTime() => $_has(27);
  @$pb.TagNumber(33)
  void clearSendTime() => $_clearField(33);

  @$pb.TagNumber(34)
  $fixnum.Int64 get forceDisplayEffects => $_getI64(28);
  @$pb.TagNumber(34)
  set forceDisplayEffects($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(34)
  $core.bool hasForceDisplayEffects() => $_has(28);
  @$pb.TagNumber(34)
  void clearForceDisplayEffects() => $_clearField(34);

  @$pb.TagNumber(35)
  $core.String get traceId => $_getSZ(29);
  @$pb.TagNumber(35)
  set traceId($core.String value) => $_setString(29, value);
  @$pb.TagNumber(35)
  $core.bool hasTraceId() => $_has(29);
  @$pb.TagNumber(35)
  void clearTraceId() => $_clearField(35);

  @$pb.TagNumber(36)
  $fixnum.Int64 get effectDisplayTs => $_getI64(30);
  @$pb.TagNumber(36)
  set effectDisplayTs($fixnum.Int64 value) => $_setInt64(30, value);
  @$pb.TagNumber(36)
  $core.bool hasEffectDisplayTs() => $_has(30);
  @$pb.TagNumber(36)
  void clearEffectDisplayTs() => $_clearField(36);
}

class GiftStruct extends $pb.GeneratedMessage {
  factory GiftStruct({
    Image? image,
    $core.String? describe,
    $core.bool? notify,
    $fixnum.Int64? duration,
    $fixnum.Int64? id,
    $core.bool? forLinkmic,
    $core.bool? doodle,
    $core.bool? forFansclub,
    $core.bool? combo,
    $core.int? type,
    $core.int? diamondCount,
    $core.bool? isDisplayedOnPanel,
    $fixnum.Int64? primaryEffectId,
    Image? giftLabelIcon,
    $core.String? name,
    $core.String? region,
    $core.String? manual,
    $core.bool? forCustom,
    Image? icon,
    $core.int? actionType,
  }) {
    final result = create();
    if (image != null) result.image = image;
    if (describe != null) result.describe = describe;
    if (notify != null) result.notify = notify;
    if (duration != null) result.duration = duration;
    if (id != null) result.id = id;
    if (forLinkmic != null) result.forLinkmic = forLinkmic;
    if (doodle != null) result.doodle = doodle;
    if (forFansclub != null) result.forFansclub = forFansclub;
    if (combo != null) result.combo = combo;
    if (type != null) result.type = type;
    if (diamondCount != null) result.diamondCount = diamondCount;
    if (isDisplayedOnPanel != null) result.isDisplayedOnPanel = isDisplayedOnPanel;
    if (primaryEffectId != null) result.primaryEffectId = primaryEffectId;
    if (giftLabelIcon != null) result.giftLabelIcon = giftLabelIcon;
    if (name != null) result.name = name;
    if (region != null) result.region = region;
    if (manual != null) result.manual = manual;
    if (forCustom != null) result.forCustom = forCustom;
    if (icon != null) result.icon = icon;
    if (actionType != null) result.actionType = actionType;
    return result;
  }

  GiftStruct._();

  factory GiftStruct.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory GiftStruct.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'GiftStruct',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Image>(1, _omitFieldNames ? '' : 'image', subBuilder: Image.create)
        ..aOS(2, _omitFieldNames ? '' : 'describe')
        ..aOB(3, _omitFieldNames ? '' : 'notify')
        ..a<$fixnum.Int64>(
          4,
          _omitFieldNames ? '' : 'duration',
          $pb.PbFieldType.OU6,
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOB(7, _omitFieldNames ? '' : 'forLinkmic', protoName: 'forLinkmic')
        ..aOB(8, _omitFieldNames ? '' : 'doodle')
        ..aOB(9, _omitFieldNames ? '' : 'forFansclub', protoName: 'forFansclub')
        ..aOB(10, _omitFieldNames ? '' : 'combo')
        ..aI(11, _omitFieldNames ? '' : 'type', fieldType: $pb.PbFieldType.OU3)
        ..aI(12, _omitFieldNames ? '' : 'diamondCount', protoName: 'diamondCount', fieldType: $pb.PbFieldType.OU3)
        ..aOB(13, _omitFieldNames ? '' : 'isDisplayedOnPanel', protoName: 'isDisplayedOnPanel')
        ..a<$fixnum.Int64>(
          14,
          _omitFieldNames ? '' : 'primaryEffectId',
          $pb.PbFieldType.OU6,
          protoName: 'primaryEffectId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<Image>(15, _omitFieldNames ? '' : 'giftLabelIcon', protoName: 'giftLabelIcon', subBuilder: Image.create)
        ..aOS(16, _omitFieldNames ? '' : 'name')
        ..aOS(17, _omitFieldNames ? '' : 'region')
        ..aOS(18, _omitFieldNames ? '' : 'manual')
        ..aOB(19, _omitFieldNames ? '' : 'forCustom', protoName: 'forCustom')
        ..aOM<Image>(21, _omitFieldNames ? '' : 'icon', subBuilder: Image.create)
        ..aI(22, _omitFieldNames ? '' : 'actionType', protoName: 'actionType', fieldType: $pb.PbFieldType.OU3)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GiftStruct clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GiftStruct copyWith(void Function(GiftStruct) updates) =>
      super.copyWith((message) => updates(message as GiftStruct)) as GiftStruct;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GiftStruct create() => GiftStruct._();
  @$core.override
  GiftStruct createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GiftStruct getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GiftStruct>(create);
  static GiftStruct? _defaultInstance;

  @$pb.TagNumber(1)
  Image get image => $_getN(0);
  @$pb.TagNumber(1)
  set image(Image value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasImage() => $_has(0);
  @$pb.TagNumber(1)
  void clearImage() => $_clearField(1);
  @$pb.TagNumber(1)
  Image ensureImage() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get describe => $_getSZ(1);
  @$pb.TagNumber(2)
  set describe($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescribe() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescribe() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get notify => $_getBF(2);
  @$pb.TagNumber(3)
  set notify($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNotify() => $_has(2);
  @$pb.TagNumber(3)
  void clearNotify() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get duration => $_getI64(3);
  @$pb.TagNumber(4)
  set duration($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearDuration() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get id => $_getI64(4);
  @$pb.TagNumber(5)
  set id($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasId() => $_has(4);
  @$pb.TagNumber(5)
  void clearId() => $_clearField(5);

  /// GiftStructFansClubInfo fansclubInfo = 6;
  @$pb.TagNumber(7)
  $core.bool get forLinkmic => $_getBF(5);
  @$pb.TagNumber(7)
  set forLinkmic($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(7)
  $core.bool hasForLinkmic() => $_has(5);
  @$pb.TagNumber(7)
  void clearForLinkmic() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get doodle => $_getBF(6);
  @$pb.TagNumber(8)
  set doodle($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(8)
  $core.bool hasDoodle() => $_has(6);
  @$pb.TagNumber(8)
  void clearDoodle() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get forFansclub => $_getBF(7);
  @$pb.TagNumber(9)
  set forFansclub($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(9)
  $core.bool hasForFansclub() => $_has(7);
  @$pb.TagNumber(9)
  void clearForFansclub() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get combo => $_getBF(8);
  @$pb.TagNumber(10)
  set combo($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(10)
  $core.bool hasCombo() => $_has(8);
  @$pb.TagNumber(10)
  void clearCombo() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get type => $_getIZ(9);
  @$pb.TagNumber(11)
  set type($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(11)
  $core.bool hasType() => $_has(9);
  @$pb.TagNumber(11)
  void clearType() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get diamondCount => $_getIZ(10);
  @$pb.TagNumber(12)
  set diamondCount($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(12)
  $core.bool hasDiamondCount() => $_has(10);
  @$pb.TagNumber(12)
  void clearDiamondCount() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get isDisplayedOnPanel => $_getBF(11);
  @$pb.TagNumber(13)
  set isDisplayedOnPanel($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(13)
  $core.bool hasIsDisplayedOnPanel() => $_has(11);
  @$pb.TagNumber(13)
  void clearIsDisplayedOnPanel() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get primaryEffectId => $_getI64(12);
  @$pb.TagNumber(14)
  set primaryEffectId($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(14)
  $core.bool hasPrimaryEffectId() => $_has(12);
  @$pb.TagNumber(14)
  void clearPrimaryEffectId() => $_clearField(14);

  @$pb.TagNumber(15)
  Image get giftLabelIcon => $_getN(13);
  @$pb.TagNumber(15)
  set giftLabelIcon(Image value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasGiftLabelIcon() => $_has(13);
  @$pb.TagNumber(15)
  void clearGiftLabelIcon() => $_clearField(15);
  @$pb.TagNumber(15)
  Image ensureGiftLabelIcon() => $_ensure(13);

  @$pb.TagNumber(16)
  $core.String get name => $_getSZ(14);
  @$pb.TagNumber(16)
  set name($core.String value) => $_setString(14, value);
  @$pb.TagNumber(16)
  $core.bool hasName() => $_has(14);
  @$pb.TagNumber(16)
  void clearName() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get region => $_getSZ(15);
  @$pb.TagNumber(17)
  set region($core.String value) => $_setString(15, value);
  @$pb.TagNumber(17)
  $core.bool hasRegion() => $_has(15);
  @$pb.TagNumber(17)
  void clearRegion() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.String get manual => $_getSZ(16);
  @$pb.TagNumber(18)
  set manual($core.String value) => $_setString(16, value);
  @$pb.TagNumber(18)
  $core.bool hasManual() => $_has(16);
  @$pb.TagNumber(18)
  void clearManual() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.bool get forCustom => $_getBF(17);
  @$pb.TagNumber(19)
  set forCustom($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(19)
  $core.bool hasForCustom() => $_has(17);
  @$pb.TagNumber(19)
  void clearForCustom() => $_clearField(19);

  /// specialEffectsMap = 20;
  @$pb.TagNumber(21)
  Image get icon => $_getN(18);
  @$pb.TagNumber(21)
  set icon(Image value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasIcon() => $_has(18);
  @$pb.TagNumber(21)
  void clearIcon() => $_clearField(21);
  @$pb.TagNumber(21)
  Image ensureIcon() => $_ensure(18);

  @$pb.TagNumber(22)
  $core.int get actionType => $_getIZ(19);
  @$pb.TagNumber(22)
  set actionType($core.int value) => $_setUnsignedInt32(19, value);
  @$pb.TagNumber(22)
  $core.bool hasActionType() => $_has(19);
  @$pb.TagNumber(22)
  void clearActionType() => $_clearField(22);
}

class GiftIMPriority extends $pb.GeneratedMessage {
  factory GiftIMPriority({
    $core.Iterable<$fixnum.Int64>? queueSizesList,
    $fixnum.Int64? selfQueuePriority,
    $fixnum.Int64? priority,
  }) {
    final result = create();
    if (queueSizesList != null) result.queueSizesList.addAll(queueSizesList);
    if (selfQueuePriority != null) result.selfQueuePriority = selfQueuePriority;
    if (priority != null) result.priority = priority;
    return result;
  }

  GiftIMPriority._();

  factory GiftIMPriority.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory GiftIMPriority.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'GiftIMPriority',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'queueSizesList', $pb.PbFieldType.KU6, protoName: 'queueSizesList')
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'selfQueuePriority',
          $pb.PbFieldType.OU6,
          protoName: 'selfQueuePriority',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'priority',
          $pb.PbFieldType.OU6,
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GiftIMPriority clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GiftIMPriority copyWith(void Function(GiftIMPriority) updates) =>
      super.copyWith((message) => updates(message as GiftIMPriority)) as GiftIMPriority;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GiftIMPriority create() => GiftIMPriority._();
  @$core.override
  GiftIMPriority createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GiftIMPriority getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GiftIMPriority>(create);
  static GiftIMPriority? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get queueSizesList => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get selfQueuePriority => $_getI64(1);
  @$pb.TagNumber(2)
  set selfQueuePriority($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSelfQueuePriority() => $_has(1);
  @$pb.TagNumber(2)
  void clearSelfQueuePriority() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get priority => $_getI64(2);
  @$pb.TagNumber(3)
  set priority($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPriority() => $_has(2);
  @$pb.TagNumber(3)
  void clearPriority() => $_clearField(3);
}

class TextEffect extends $pb.GeneratedMessage {
  factory TextEffect({TextEffectDetail? portrait, TextEffectDetail? landscape}) {
    final result = create();
    if (portrait != null) result.portrait = portrait;
    if (landscape != null) result.landscape = landscape;
    return result;
  }

  TextEffect._();

  factory TextEffect.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextEffect.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextEffect',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<TextEffectDetail>(1, _omitFieldNames ? '' : 'portrait', subBuilder: TextEffectDetail.create)
        ..aOM<TextEffectDetail>(2, _omitFieldNames ? '' : 'landscape', subBuilder: TextEffectDetail.create)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextEffect clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextEffect copyWith(void Function(TextEffect) updates) =>
      super.copyWith((message) => updates(message as TextEffect)) as TextEffect;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextEffect create() => TextEffect._();
  @$core.override
  TextEffect createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextEffect getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextEffect>(create);
  static TextEffect? _defaultInstance;

  @$pb.TagNumber(1)
  TextEffectDetail get portrait => $_getN(0);
  @$pb.TagNumber(1)
  set portrait(TextEffectDetail value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPortrait() => $_has(0);
  @$pb.TagNumber(1)
  void clearPortrait() => $_clearField(1);
  @$pb.TagNumber(1)
  TextEffectDetail ensurePortrait() => $_ensure(0);

  @$pb.TagNumber(2)
  TextEffectDetail get landscape => $_getN(1);
  @$pb.TagNumber(2)
  set landscape(TextEffectDetail value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLandscape() => $_has(1);
  @$pb.TagNumber(2)
  void clearLandscape() => $_clearField(2);
  @$pb.TagNumber(2)
  TextEffectDetail ensureLandscape() => $_ensure(1);
}

class TextEffectDetail extends $pb.GeneratedMessage {
  factory TextEffectDetail({
    Text? text,
    $core.int? textFontSize,
    Image? background,
    $core.int? start,
    $core.int? duration,
    $core.int? x,
    $core.int? y,
    $core.int? width,
    $core.int? height,
    $core.int? shadowDx,
    $core.int? shadowDy,
    $core.int? shadowRadius,
    $core.String? shadowColor,
    $core.String? strokeColor,
    $core.int? strokeWidth,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (textFontSize != null) result.textFontSize = textFontSize;
    if (background != null) result.background = background;
    if (start != null) result.start = start;
    if (duration != null) result.duration = duration;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (shadowDx != null) result.shadowDx = shadowDx;
    if (shadowDy != null) result.shadowDy = shadowDy;
    if (shadowRadius != null) result.shadowRadius = shadowRadius;
    if (shadowColor != null) result.shadowColor = shadowColor;
    if (strokeColor != null) result.strokeColor = strokeColor;
    if (strokeWidth != null) result.strokeWidth = strokeWidth;
    return result;
  }

  TextEffectDetail._();

  factory TextEffectDetail.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextEffectDetail.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextEffectDetail',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Text>(1, _omitFieldNames ? '' : 'text', subBuilder: Text.create)
        ..aI(2, _omitFieldNames ? '' : 'textFontSize', protoName: 'textFontSize', fieldType: $pb.PbFieldType.OU3)
        ..aOM<Image>(3, _omitFieldNames ? '' : 'background', subBuilder: Image.create)
        ..aI(4, _omitFieldNames ? '' : 'start', fieldType: $pb.PbFieldType.OU3)
        ..aI(5, _omitFieldNames ? '' : 'duration', fieldType: $pb.PbFieldType.OU3)
        ..aI(6, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OU3)
        ..aI(7, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OU3)
        ..aI(8, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
        ..aI(9, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
        ..aI(10, _omitFieldNames ? '' : 'shadowDx', protoName: 'shadowDx', fieldType: $pb.PbFieldType.OU3)
        ..aI(11, _omitFieldNames ? '' : 'shadowDy', protoName: 'shadowDy', fieldType: $pb.PbFieldType.OU3)
        ..aI(12, _omitFieldNames ? '' : 'shadowRadius', protoName: 'shadowRadius', fieldType: $pb.PbFieldType.OU3)
        ..aOS(13, _omitFieldNames ? '' : 'shadowColor', protoName: 'shadowColor')
        ..aOS(14, _omitFieldNames ? '' : 'strokeColor', protoName: 'strokeColor')
        ..aI(15, _omitFieldNames ? '' : 'strokeWidth', protoName: 'strokeWidth', fieldType: $pb.PbFieldType.OU3)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextEffectDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextEffectDetail copyWith(void Function(TextEffectDetail) updates) =>
      super.copyWith((message) => updates(message as TextEffectDetail)) as TextEffectDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextEffectDetail create() => TextEffectDetail._();
  @$core.override
  TextEffectDetail createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextEffectDetail getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextEffectDetail>(create);
  static TextEffectDetail? _defaultInstance;

  @$pb.TagNumber(1)
  Text get text => $_getN(0);
  @$pb.TagNumber(1)
  set text(Text value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
  @$pb.TagNumber(1)
  Text ensureText() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get textFontSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set textFontSize($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTextFontSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearTextFontSize() => $_clearField(2);

  @$pb.TagNumber(3)
  Image get background => $_getN(2);
  @$pb.TagNumber(3)
  set background(Image value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBackground() => $_has(2);
  @$pb.TagNumber(3)
  void clearBackground() => $_clearField(3);
  @$pb.TagNumber(3)
  Image ensureBackground() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.int get start => $_getIZ(3);
  @$pb.TagNumber(4)
  set start($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get duration => $_getIZ(4);
  @$pb.TagNumber(5)
  set duration($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get x => $_getIZ(5);
  @$pb.TagNumber(6)
  set x($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasX() => $_has(5);
  @$pb.TagNumber(6)
  void clearX() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get y => $_getIZ(6);
  @$pb.TagNumber(7)
  set y($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasY() => $_has(6);
  @$pb.TagNumber(7)
  void clearY() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get width => $_getIZ(7);
  @$pb.TagNumber(8)
  set width($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWidth() => $_has(7);
  @$pb.TagNumber(8)
  void clearWidth() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get height => $_getIZ(8);
  @$pb.TagNumber(9)
  set height($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHeight() => $_has(8);
  @$pb.TagNumber(9)
  void clearHeight() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get shadowDx => $_getIZ(9);
  @$pb.TagNumber(10)
  set shadowDx($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasShadowDx() => $_has(9);
  @$pb.TagNumber(10)
  void clearShadowDx() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get shadowDy => $_getIZ(10);
  @$pb.TagNumber(11)
  set shadowDy($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasShadowDy() => $_has(10);
  @$pb.TagNumber(11)
  void clearShadowDy() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get shadowRadius => $_getIZ(11);
  @$pb.TagNumber(12)
  set shadowRadius($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasShadowRadius() => $_has(11);
  @$pb.TagNumber(12)
  void clearShadowRadius() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get shadowColor => $_getSZ(12);
  @$pb.TagNumber(13)
  set shadowColor($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasShadowColor() => $_has(12);
  @$pb.TagNumber(13)
  void clearShadowColor() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get strokeColor => $_getSZ(13);
  @$pb.TagNumber(14)
  set strokeColor($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasStrokeColor() => $_has(13);
  @$pb.TagNumber(14)
  void clearStrokeColor() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get strokeWidth => $_getIZ(14);
  @$pb.TagNumber(15)
  set strokeWidth($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasStrokeWidth() => $_has(14);
  @$pb.TagNumber(15)
  void clearStrokeWidth() => $_clearField(15);
}

/// 成员消息
class MemberMessage extends $pb.GeneratedMessage {
  factory MemberMessage({
    Common? common,
    User? user,
    $fixnum.Int64? memberCount,
    User? operator,
    $core.bool? isSetToAdmin,
    $core.bool? isTopUser,
    $fixnum.Int64? rankScore,
    $fixnum.Int64? topUserNo,
    $fixnum.Int64? enterType,
    $fixnum.Int64? action,
    $core.String? actionDescription,
    $fixnum.Int64? userId,
    EffectConfig? effectConfig,
    $core.String? popStr,
    EffectConfig? enterEffectConfig,
    Image? backgroundImage,
    Image? backgroundImageV2,
    Text? anchorDisplayText,
    PublicAreaCommon? publicAreaCommon,
    $fixnum.Int64? userEnterTipType,
    $fixnum.Int64? anchorEnterTipType,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (user != null) result.user = user;
    if (memberCount != null) result.memberCount = memberCount;
    if (operator != null) result.operator = operator;
    if (isSetToAdmin != null) result.isSetToAdmin = isSetToAdmin;
    if (isTopUser != null) result.isTopUser = isTopUser;
    if (rankScore != null) result.rankScore = rankScore;
    if (topUserNo != null) result.topUserNo = topUserNo;
    if (enterType != null) result.enterType = enterType;
    if (action != null) result.action = action;
    if (actionDescription != null) result.actionDescription = actionDescription;
    if (userId != null) result.userId = userId;
    if (effectConfig != null) result.effectConfig = effectConfig;
    if (popStr != null) result.popStr = popStr;
    if (enterEffectConfig != null) result.enterEffectConfig = enterEffectConfig;
    if (backgroundImage != null) result.backgroundImage = backgroundImage;
    if (backgroundImageV2 != null) result.backgroundImageV2 = backgroundImageV2;
    if (anchorDisplayText != null) result.anchorDisplayText = anchorDisplayText;
    if (publicAreaCommon != null) result.publicAreaCommon = publicAreaCommon;
    if (userEnterTipType != null) result.userEnterTipType = userEnterTipType;
    if (anchorEnterTipType != null) result.anchorEnterTipType = anchorEnterTipType;
    return result;
  }

  MemberMessage._();

  factory MemberMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory MemberMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'MemberMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'memberCount',
          $pb.PbFieldType.OU6,
          protoName: 'memberCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<User>(4, _omitFieldNames ? '' : 'operator', subBuilder: User.create)
        ..aOB(5, _omitFieldNames ? '' : 'isSetToAdmin', protoName: 'isSetToAdmin')
        ..aOB(6, _omitFieldNames ? '' : 'isTopUser', protoName: 'isTopUser')
        ..a<$fixnum.Int64>(
          7,
          _omitFieldNames ? '' : 'rankScore',
          $pb.PbFieldType.OU6,
          protoName: 'rankScore',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          8,
          _omitFieldNames ? '' : 'topUserNo',
          $pb.PbFieldType.OU6,
          protoName: 'topUserNo',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          9,
          _omitFieldNames ? '' : 'enterType',
          $pb.PbFieldType.OU6,
          protoName: 'enterType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(10, _omitFieldNames ? '' : 'action', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOS(11, _omitFieldNames ? '' : 'actionDescription', protoName: 'actionDescription')
        ..a<$fixnum.Int64>(
          12,
          _omitFieldNames ? '' : 'userId',
          $pb.PbFieldType.OU6,
          protoName: 'userId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<EffectConfig>(
          13,
          _omitFieldNames ? '' : 'effectConfig',
          protoName: 'effectConfig',
          subBuilder: EffectConfig.create,
        )
        ..aOS(14, _omitFieldNames ? '' : 'popStr', protoName: 'popStr')
        ..aOM<EffectConfig>(
          15,
          _omitFieldNames ? '' : 'enterEffectConfig',
          protoName: 'enterEffectConfig',
          subBuilder: EffectConfig.create,
        )
        ..aOM<Image>(
          16,
          _omitFieldNames ? '' : 'backgroundImage',
          protoName: 'backgroundImage',
          subBuilder: Image.create,
        )
        ..aOM<Image>(
          17,
          _omitFieldNames ? '' : 'backgroundImageV2',
          protoName: 'backgroundImageV2',
          subBuilder: Image.create,
        )
        ..aOM<Text>(
          18,
          _omitFieldNames ? '' : 'anchorDisplayText',
          protoName: 'anchorDisplayText',
          subBuilder: Text.create,
        )
        ..aOM<PublicAreaCommon>(
          19,
          _omitFieldNames ? '' : 'publicAreaCommon',
          protoName: 'publicAreaCommon',
          subBuilder: PublicAreaCommon.create,
        )
        ..a<$fixnum.Int64>(
          20,
          _omitFieldNames ? '' : 'userEnterTipType',
          $pb.PbFieldType.OU6,
          protoName: 'userEnterTipType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          21,
          _omitFieldNames ? '' : 'anchorEnterTipType',
          $pb.PbFieldType.OU6,
          protoName: 'anchorEnterTipType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberMessage copyWith(void Function(MemberMessage) updates) =>
      super.copyWith((message) => updates(message as MemberMessage)) as MemberMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemberMessage create() => MemberMessage._();
  @$core.override
  MemberMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemberMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MemberMessage>(create);
  static MemberMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get memberCount => $_getI64(2);
  @$pb.TagNumber(3)
  set memberCount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMemberCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearMemberCount() => $_clearField(3);

  @$pb.TagNumber(4)
  User get operator => $_getN(3);
  @$pb.TagNumber(4)
  set operator(User value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasOperator() => $_has(3);
  @$pb.TagNumber(4)
  void clearOperator() => $_clearField(4);
  @$pb.TagNumber(4)
  User ensureOperator() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.bool get isSetToAdmin => $_getBF(4);
  @$pb.TagNumber(5)
  set isSetToAdmin($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsSetToAdmin() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsSetToAdmin() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isTopUser => $_getBF(5);
  @$pb.TagNumber(6)
  set isTopUser($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsTopUser() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsTopUser() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get rankScore => $_getI64(6);
  @$pb.TagNumber(7)
  set rankScore($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRankScore() => $_has(6);
  @$pb.TagNumber(7)
  void clearRankScore() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get topUserNo => $_getI64(7);
  @$pb.TagNumber(8)
  set topUserNo($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTopUserNo() => $_has(7);
  @$pb.TagNumber(8)
  void clearTopUserNo() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get enterType => $_getI64(8);
  @$pb.TagNumber(9)
  set enterType($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEnterType() => $_has(8);
  @$pb.TagNumber(9)
  void clearEnterType() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get action => $_getI64(9);
  @$pb.TagNumber(10)
  set action($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAction() => $_has(9);
  @$pb.TagNumber(10)
  void clearAction() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get actionDescription => $_getSZ(10);
  @$pb.TagNumber(11)
  set actionDescription($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasActionDescription() => $_has(10);
  @$pb.TagNumber(11)
  void clearActionDescription() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get userId => $_getI64(11);
  @$pb.TagNumber(12)
  set userId($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasUserId() => $_has(11);
  @$pb.TagNumber(12)
  void clearUserId() => $_clearField(12);

  @$pb.TagNumber(13)
  EffectConfig get effectConfig => $_getN(12);
  @$pb.TagNumber(13)
  set effectConfig(EffectConfig value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasEffectConfig() => $_has(12);
  @$pb.TagNumber(13)
  void clearEffectConfig() => $_clearField(13);
  @$pb.TagNumber(13)
  EffectConfig ensureEffectConfig() => $_ensure(12);

  @$pb.TagNumber(14)
  $core.String get popStr => $_getSZ(13);
  @$pb.TagNumber(14)
  set popStr($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasPopStr() => $_has(13);
  @$pb.TagNumber(14)
  void clearPopStr() => $_clearField(14);

  @$pb.TagNumber(15)
  EffectConfig get enterEffectConfig => $_getN(14);
  @$pb.TagNumber(15)
  set enterEffectConfig(EffectConfig value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasEnterEffectConfig() => $_has(14);
  @$pb.TagNumber(15)
  void clearEnterEffectConfig() => $_clearField(15);
  @$pb.TagNumber(15)
  EffectConfig ensureEnterEffectConfig() => $_ensure(14);

  @$pb.TagNumber(16)
  Image get backgroundImage => $_getN(15);
  @$pb.TagNumber(16)
  set backgroundImage(Image value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasBackgroundImage() => $_has(15);
  @$pb.TagNumber(16)
  void clearBackgroundImage() => $_clearField(16);
  @$pb.TagNumber(16)
  Image ensureBackgroundImage() => $_ensure(15);

  @$pb.TagNumber(17)
  Image get backgroundImageV2 => $_getN(16);
  @$pb.TagNumber(17)
  set backgroundImageV2(Image value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasBackgroundImageV2() => $_has(16);
  @$pb.TagNumber(17)
  void clearBackgroundImageV2() => $_clearField(17);
  @$pb.TagNumber(17)
  Image ensureBackgroundImageV2() => $_ensure(16);

  @$pb.TagNumber(18)
  Text get anchorDisplayText => $_getN(17);
  @$pb.TagNumber(18)
  set anchorDisplayText(Text value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasAnchorDisplayText() => $_has(17);
  @$pb.TagNumber(18)
  void clearAnchorDisplayText() => $_clearField(18);
  @$pb.TagNumber(18)
  Text ensureAnchorDisplayText() => $_ensure(17);

  @$pb.TagNumber(19)
  PublicAreaCommon get publicAreaCommon => $_getN(18);
  @$pb.TagNumber(19)
  set publicAreaCommon(PublicAreaCommon value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasPublicAreaCommon() => $_has(18);
  @$pb.TagNumber(19)
  void clearPublicAreaCommon() => $_clearField(19);
  @$pb.TagNumber(19)
  PublicAreaCommon ensurePublicAreaCommon() => $_ensure(18);

  @$pb.TagNumber(20)
  $fixnum.Int64 get userEnterTipType => $_getI64(19);
  @$pb.TagNumber(20)
  set userEnterTipType($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(20)
  $core.bool hasUserEnterTipType() => $_has(19);
  @$pb.TagNumber(20)
  void clearUserEnterTipType() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get anchorEnterTipType => $_getI64(20);
  @$pb.TagNumber(21)
  set anchorEnterTipType($fixnum.Int64 value) => $_setInt64(20, value);
  @$pb.TagNumber(21)
  $core.bool hasAnchorEnterTipType() => $_has(20);
  @$pb.TagNumber(21)
  void clearAnchorEnterTipType() => $_clearField(21);
}

class PublicAreaCommon extends $pb.GeneratedMessage {
  factory PublicAreaCommon({Image? userLabel, $fixnum.Int64? userConsumeInRoom, $fixnum.Int64? userSendGiftCntInRoom}) {
    final result = create();
    if (userLabel != null) result.userLabel = userLabel;
    if (userConsumeInRoom != null) result.userConsumeInRoom = userConsumeInRoom;
    if (userSendGiftCntInRoom != null) result.userSendGiftCntInRoom = userSendGiftCntInRoom;
    return result;
  }

  PublicAreaCommon._();

  factory PublicAreaCommon.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory PublicAreaCommon.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'PublicAreaCommon',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Image>(1, _omitFieldNames ? '' : 'userLabel', protoName: 'userLabel', subBuilder: Image.create)
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'userConsumeInRoom',
          $pb.PbFieldType.OU6,
          protoName: 'userConsumeInRoom',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'userSendGiftCntInRoom',
          $pb.PbFieldType.OU6,
          protoName: 'userSendGiftCntInRoom',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PublicAreaCommon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PublicAreaCommon copyWith(void Function(PublicAreaCommon) updates) =>
      super.copyWith((message) => updates(message as PublicAreaCommon)) as PublicAreaCommon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PublicAreaCommon create() => PublicAreaCommon._();
  @$core.override
  PublicAreaCommon createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PublicAreaCommon getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PublicAreaCommon>(create);
  static PublicAreaCommon? _defaultInstance;

  @$pb.TagNumber(1)
  Image get userLabel => $_getN(0);
  @$pb.TagNumber(1)
  set userLabel(Image value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserLabel() => $_clearField(1);
  @$pb.TagNumber(1)
  Image ensureUserLabel() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get userConsumeInRoom => $_getI64(1);
  @$pb.TagNumber(2)
  set userConsumeInRoom($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserConsumeInRoom() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserConsumeInRoom() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get userSendGiftCntInRoom => $_getI64(2);
  @$pb.TagNumber(3)
  set userSendGiftCntInRoom($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUserSendGiftCntInRoom() => $_has(2);
  @$pb.TagNumber(3)
  void clearUserSendGiftCntInRoom() => $_clearField(3);
}

class EffectConfig extends $pb.GeneratedMessage {
  factory EffectConfig({
    $fixnum.Int64? type,
    Image? icon,
    $fixnum.Int64? avatarPos,
    Text? text,
    Image? textIcon,
    $core.int? stayTime,
    $fixnum.Int64? animAssetId,
    Image? badge,
    $core.Iterable<$fixnum.Int64>? flexSettingArrayList,
    Image? textIconOverlay,
    Image? animatedBadge,
    $core.bool? hasSweepLight,
    $core.Iterable<$fixnum.Int64>? textFlexSettingArrayList,
    $fixnum.Int64? centerAnimAssetId,
    Image? dynamicImage,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extraMap,
    $fixnum.Int64? mp4AnimAssetId,
    $fixnum.Int64? priority,
    $fixnum.Int64? maxWaitTime,
    $core.String? dressId,
    $fixnum.Int64? alignment,
    $fixnum.Int64? alignmentOffset,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (icon != null) result.icon = icon;
    if (avatarPos != null) result.avatarPos = avatarPos;
    if (text != null) result.text = text;
    if (textIcon != null) result.textIcon = textIcon;
    if (stayTime != null) result.stayTime = stayTime;
    if (animAssetId != null) result.animAssetId = animAssetId;
    if (badge != null) result.badge = badge;
    if (flexSettingArrayList != null) result.flexSettingArrayList.addAll(flexSettingArrayList);
    if (textIconOverlay != null) result.textIconOverlay = textIconOverlay;
    if (animatedBadge != null) result.animatedBadge = animatedBadge;
    if (hasSweepLight != null) result.hasSweepLight = hasSweepLight;
    if (textFlexSettingArrayList != null) result.textFlexSettingArrayList.addAll(textFlexSettingArrayList);
    if (centerAnimAssetId != null) result.centerAnimAssetId = centerAnimAssetId;
    if (dynamicImage != null) result.dynamicImage = dynamicImage;
    if (extraMap != null) result.extraMap.addEntries(extraMap);
    if (mp4AnimAssetId != null) result.mp4AnimAssetId = mp4AnimAssetId;
    if (priority != null) result.priority = priority;
    if (maxWaitTime != null) result.maxWaitTime = maxWaitTime;
    if (dressId != null) result.dressId = dressId;
    if (alignment != null) result.alignment = alignment;
    if (alignmentOffset != null) result.alignmentOffset = alignmentOffset;
    return result;
  }

  EffectConfig._();

  factory EffectConfig.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory EffectConfig.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'EffectConfig',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOM<Image>(2, _omitFieldNames ? '' : 'icon', subBuilder: Image.create)
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'avatarPos',
          $pb.PbFieldType.OU6,
          protoName: 'avatarPos',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<Text>(4, _omitFieldNames ? '' : 'text', subBuilder: Text.create)
        ..aOM<Image>(5, _omitFieldNames ? '' : 'textIcon', protoName: 'textIcon', subBuilder: Image.create)
        ..aI(6, _omitFieldNames ? '' : 'stayTime', protoName: 'stayTime', fieldType: $pb.PbFieldType.OU3)
        ..a<$fixnum.Int64>(
          7,
          _omitFieldNames ? '' : 'animAssetId',
          $pb.PbFieldType.OU6,
          protoName: 'animAssetId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<Image>(8, _omitFieldNames ? '' : 'badge', subBuilder: Image.create)
        ..p<$fixnum.Int64>(
          9,
          _omitFieldNames ? '' : 'flexSettingArrayList',
          $pb.PbFieldType.KU6,
          protoName: 'flexSettingArrayList',
        )
        ..aOM<Image>(
          10,
          _omitFieldNames ? '' : 'textIconOverlay',
          protoName: 'textIconOverlay',
          subBuilder: Image.create,
        )
        ..aOM<Image>(11, _omitFieldNames ? '' : 'animatedBadge', protoName: 'animatedBadge', subBuilder: Image.create)
        ..aOB(12, _omitFieldNames ? '' : 'hasSweepLight', protoName: 'hasSweepLight')
        ..p<$fixnum.Int64>(
          13,
          _omitFieldNames ? '' : 'textFlexSettingArrayList',
          $pb.PbFieldType.KU6,
          protoName: 'textFlexSettingArrayList',
        )
        ..a<$fixnum.Int64>(
          14,
          _omitFieldNames ? '' : 'centerAnimAssetId',
          $pb.PbFieldType.OU6,
          protoName: 'centerAnimAssetId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<Image>(15, _omitFieldNames ? '' : 'dynamicImage', protoName: 'dynamicImage', subBuilder: Image.create)
        ..m<$core.String, $core.String>(
          16,
          _omitFieldNames ? '' : 'extraMap',
          protoName: 'extraMap',
          entryClassName: 'EffectConfig.ExtraMapEntry',
          keyFieldType: $pb.PbFieldType.OS,
          valueFieldType: $pb.PbFieldType.OS,
          packageName: const $pb.PackageName('douyin'),
        )
        ..a<$fixnum.Int64>(
          17,
          _omitFieldNames ? '' : 'mp4AnimAssetId',
          $pb.PbFieldType.OU6,
          protoName: 'mp4AnimAssetId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          18,
          _omitFieldNames ? '' : 'priority',
          $pb.PbFieldType.OU6,
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          19,
          _omitFieldNames ? '' : 'maxWaitTime',
          $pb.PbFieldType.OU6,
          protoName: 'maxWaitTime',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(20, _omitFieldNames ? '' : 'dressId', protoName: 'dressId')
        ..a<$fixnum.Int64>(
          21,
          _omitFieldNames ? '' : 'alignment',
          $pb.PbFieldType.OU6,
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          22,
          _omitFieldNames ? '' : 'alignmentOffset',
          $pb.PbFieldType.OU6,
          protoName: 'alignmentOffset',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EffectConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EffectConfig copyWith(void Function(EffectConfig) updates) =>
      super.copyWith((message) => updates(message as EffectConfig)) as EffectConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EffectConfig create() => EffectConfig._();
  @$core.override
  EffectConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EffectConfig getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EffectConfig>(create);
  static EffectConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get type => $_getI64(0);
  @$pb.TagNumber(1)
  set type($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  Image get icon => $_getN(1);
  @$pb.TagNumber(2)
  set icon(Image value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearIcon() => $_clearField(2);
  @$pb.TagNumber(2)
  Image ensureIcon() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get avatarPos => $_getI64(2);
  @$pb.TagNumber(3)
  set avatarPos($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatarPos() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatarPos() => $_clearField(3);

  @$pb.TagNumber(4)
  Text get text => $_getN(3);
  @$pb.TagNumber(4)
  set text(Text value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasText() => $_has(3);
  @$pb.TagNumber(4)
  void clearText() => $_clearField(4);
  @$pb.TagNumber(4)
  Text ensureText() => $_ensure(3);

  @$pb.TagNumber(5)
  Image get textIcon => $_getN(4);
  @$pb.TagNumber(5)
  set textIcon(Image value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTextIcon() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextIcon() => $_clearField(5);
  @$pb.TagNumber(5)
  Image ensureTextIcon() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.int get stayTime => $_getIZ(5);
  @$pb.TagNumber(6)
  set stayTime($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStayTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearStayTime() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get animAssetId => $_getI64(6);
  @$pb.TagNumber(7)
  set animAssetId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAnimAssetId() => $_has(6);
  @$pb.TagNumber(7)
  void clearAnimAssetId() => $_clearField(7);

  @$pb.TagNumber(8)
  Image get badge => $_getN(7);
  @$pb.TagNumber(8)
  set badge(Image value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasBadge() => $_has(7);
  @$pb.TagNumber(8)
  void clearBadge() => $_clearField(8);
  @$pb.TagNumber(8)
  Image ensureBadge() => $_ensure(7);

  @$pb.TagNumber(9)
  $pb.PbList<$fixnum.Int64> get flexSettingArrayList => $_getList(8);

  @$pb.TagNumber(10)
  Image get textIconOverlay => $_getN(9);
  @$pb.TagNumber(10)
  set textIconOverlay(Image value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasTextIconOverlay() => $_has(9);
  @$pb.TagNumber(10)
  void clearTextIconOverlay() => $_clearField(10);
  @$pb.TagNumber(10)
  Image ensureTextIconOverlay() => $_ensure(9);

  @$pb.TagNumber(11)
  Image get animatedBadge => $_getN(10);
  @$pb.TagNumber(11)
  set animatedBadge(Image value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasAnimatedBadge() => $_has(10);
  @$pb.TagNumber(11)
  void clearAnimatedBadge() => $_clearField(11);
  @$pb.TagNumber(11)
  Image ensureAnimatedBadge() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.bool get hasSweepLight => $_getBF(11);
  @$pb.TagNumber(12)
  set hasSweepLight($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasHasSweepLight() => $_has(11);
  @$pb.TagNumber(12)
  void clearHasSweepLight() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<$fixnum.Int64> get textFlexSettingArrayList => $_getList(12);

  @$pb.TagNumber(14)
  $fixnum.Int64 get centerAnimAssetId => $_getI64(13);
  @$pb.TagNumber(14)
  set centerAnimAssetId($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCenterAnimAssetId() => $_has(13);
  @$pb.TagNumber(14)
  void clearCenterAnimAssetId() => $_clearField(14);

  @$pb.TagNumber(15)
  Image get dynamicImage => $_getN(14);
  @$pb.TagNumber(15)
  set dynamicImage(Image value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasDynamicImage() => $_has(14);
  @$pb.TagNumber(15)
  void clearDynamicImage() => $_clearField(15);
  @$pb.TagNumber(15)
  Image ensureDynamicImage() => $_ensure(14);

  @$pb.TagNumber(16)
  $pb.PbMap<$core.String, $core.String> get extraMap => $_getMap(15);

  @$pb.TagNumber(17)
  $fixnum.Int64 get mp4AnimAssetId => $_getI64(16);
  @$pb.TagNumber(17)
  set mp4AnimAssetId($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasMp4AnimAssetId() => $_has(16);
  @$pb.TagNumber(17)
  void clearMp4AnimAssetId() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get priority => $_getI64(17);
  @$pb.TagNumber(18)
  set priority($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasPriority() => $_has(17);
  @$pb.TagNumber(18)
  void clearPriority() => $_clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get maxWaitTime => $_getI64(18);
  @$pb.TagNumber(19)
  set maxWaitTime($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(19)
  $core.bool hasMaxWaitTime() => $_has(18);
  @$pb.TagNumber(19)
  void clearMaxWaitTime() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.String get dressId => $_getSZ(19);
  @$pb.TagNumber(20)
  set dressId($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasDressId() => $_has(19);
  @$pb.TagNumber(20)
  void clearDressId() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get alignment => $_getI64(20);
  @$pb.TagNumber(21)
  set alignment($fixnum.Int64 value) => $_setInt64(20, value);
  @$pb.TagNumber(21)
  $core.bool hasAlignment() => $_has(20);
  @$pb.TagNumber(21)
  void clearAlignment() => $_clearField(21);

  @$pb.TagNumber(22)
  $fixnum.Int64 get alignmentOffset => $_getI64(21);
  @$pb.TagNumber(22)
  set alignmentOffset($fixnum.Int64 value) => $_setInt64(21, value);
  @$pb.TagNumber(22)
  $core.bool hasAlignmentOffset() => $_has(21);
  @$pb.TagNumber(22)
  void clearAlignmentOffset() => $_clearField(22);
}

class Text extends $pb.GeneratedMessage {
  factory Text({
    $core.String? key,
    $core.String? defaultPatter,
    TextFormat? defaultFormat,
    $core.Iterable<TextPiece>? piecesList,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (defaultPatter != null) result.defaultPatter = defaultPatter;
    if (defaultFormat != null) result.defaultFormat = defaultFormat;
    if (piecesList != null) result.piecesList.addAll(piecesList);
    return result;
  }

  Text._();

  factory Text.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Text.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Text',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'key')
        ..aOS(2, _omitFieldNames ? '' : 'defaultPatter', protoName: 'defaultPatter')
        ..aOM<TextFormat>(
          3,
          _omitFieldNames ? '' : 'defaultFormat',
          protoName: 'defaultFormat',
          subBuilder: TextFormat.create,
        )
        ..pPM<TextPiece>(4, _omitFieldNames ? '' : 'piecesList', protoName: 'piecesList', subBuilder: TextPiece.create)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Text clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Text copyWith(void Function(Text) updates) => super.copyWith((message) => updates(message as Text)) as Text;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Text create() => Text._();
  @$core.override
  Text createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Text getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Text>(create);
  static Text? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get defaultPatter => $_getSZ(1);
  @$pb.TagNumber(2)
  set defaultPatter($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaultPatter() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultPatter() => $_clearField(2);

  @$pb.TagNumber(3)
  TextFormat get defaultFormat => $_getN(2);
  @$pb.TagNumber(3)
  set defaultFormat(TextFormat value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDefaultFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearDefaultFormat() => $_clearField(3);
  @$pb.TagNumber(3)
  TextFormat ensureDefaultFormat() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<TextPiece> get piecesList => $_getList(3);
}

class TextPiece extends $pb.GeneratedMessage {
  factory TextPiece({
    $core.bool? type,
    TextFormat? format,
    $core.String? stringValue,
    TextPieceUser? userValue,
    TextPieceGift? giftValue,
    TextPieceHeart? heartValue,
    TextPiecePatternRef? patternRefValue,
    TextPieceImage? imageValue,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (format != null) result.format = format;
    if (stringValue != null) result.stringValue = stringValue;
    if (userValue != null) result.userValue = userValue;
    if (giftValue != null) result.giftValue = giftValue;
    if (heartValue != null) result.heartValue = heartValue;
    if (patternRefValue != null) result.patternRefValue = patternRefValue;
    if (imageValue != null) result.imageValue = imageValue;
    return result;
  }

  TextPiece._();

  factory TextPiece.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextPiece.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextPiece',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOB(1, _omitFieldNames ? '' : 'type')
        ..aOM<TextFormat>(2, _omitFieldNames ? '' : 'format', subBuilder: TextFormat.create)
        ..aOS(3, _omitFieldNames ? '' : 'stringValue', protoName: 'stringValue')
        ..aOM<TextPieceUser>(
          4,
          _omitFieldNames ? '' : 'userValue',
          protoName: 'userValue',
          subBuilder: TextPieceUser.create,
        )
        ..aOM<TextPieceGift>(
          5,
          _omitFieldNames ? '' : 'giftValue',
          protoName: 'giftValue',
          subBuilder: TextPieceGift.create,
        )
        ..aOM<TextPieceHeart>(
          6,
          _omitFieldNames ? '' : 'heartValue',
          protoName: 'heartValue',
          subBuilder: TextPieceHeart.create,
        )
        ..aOM<TextPiecePatternRef>(
          7,
          _omitFieldNames ? '' : 'patternRefValue',
          protoName: 'patternRefValue',
          subBuilder: TextPiecePatternRef.create,
        )
        ..aOM<TextPieceImage>(
          8,
          _omitFieldNames ? '' : 'imageValue',
          protoName: 'imageValue',
          subBuilder: TextPieceImage.create,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPiece clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPiece copyWith(void Function(TextPiece) updates) =>
      super.copyWith((message) => updates(message as TextPiece)) as TextPiece;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextPiece create() => TextPiece._();
  @$core.override
  TextPiece createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextPiece getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextPiece>(create);
  static TextPiece? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get type => $_getBF(0);
  @$pb.TagNumber(1)
  set type($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  TextFormat get format => $_getN(1);
  @$pb.TagNumber(2)
  set format(TextFormat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);
  @$pb.TagNumber(2)
  TextFormat ensureFormat() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get stringValue => $_getSZ(2);
  @$pb.TagNumber(3)
  set stringValue($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStringValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearStringValue() => $_clearField(3);

  @$pb.TagNumber(4)
  TextPieceUser get userValue => $_getN(3);
  @$pb.TagNumber(4)
  set userValue(TextPieceUser value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasUserValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearUserValue() => $_clearField(4);
  @$pb.TagNumber(4)
  TextPieceUser ensureUserValue() => $_ensure(3);

  @$pb.TagNumber(5)
  TextPieceGift get giftValue => $_getN(4);
  @$pb.TagNumber(5)
  set giftValue(TextPieceGift value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasGiftValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearGiftValue() => $_clearField(5);
  @$pb.TagNumber(5)
  TextPieceGift ensureGiftValue() => $_ensure(4);

  @$pb.TagNumber(6)
  TextPieceHeart get heartValue => $_getN(5);
  @$pb.TagNumber(6)
  set heartValue(TextPieceHeart value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasHeartValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeartValue() => $_clearField(6);
  @$pb.TagNumber(6)
  TextPieceHeart ensureHeartValue() => $_ensure(5);

  @$pb.TagNumber(7)
  TextPiecePatternRef get patternRefValue => $_getN(6);
  @$pb.TagNumber(7)
  set patternRefValue(TextPiecePatternRef value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPatternRefValue() => $_has(6);
  @$pb.TagNumber(7)
  void clearPatternRefValue() => $_clearField(7);
  @$pb.TagNumber(7)
  TextPiecePatternRef ensurePatternRefValue() => $_ensure(6);

  @$pb.TagNumber(8)
  TextPieceImage get imageValue => $_getN(7);
  @$pb.TagNumber(8)
  set imageValue(TextPieceImage value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasImageValue() => $_has(7);
  @$pb.TagNumber(8)
  void clearImageValue() => $_clearField(8);
  @$pb.TagNumber(8)
  TextPieceImage ensureImageValue() => $_ensure(7);
}

class TextPieceImage extends $pb.GeneratedMessage {
  factory TextPieceImage({Image? image, $core.double? scalingRate}) {
    final result = create();
    if (image != null) result.image = image;
    if (scalingRate != null) result.scalingRate = scalingRate;
    return result;
  }

  TextPieceImage._();

  factory TextPieceImage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextPieceImage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextPieceImage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Image>(1, _omitFieldNames ? '' : 'image', subBuilder: Image.create)
        ..aD(2, _omitFieldNames ? '' : 'scalingRate', protoName: 'scalingRate', fieldType: $pb.PbFieldType.OF)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceImage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceImage copyWith(void Function(TextPieceImage) updates) =>
      super.copyWith((message) => updates(message as TextPieceImage)) as TextPieceImage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextPieceImage create() => TextPieceImage._();
  @$core.override
  TextPieceImage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextPieceImage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextPieceImage>(create);
  static TextPieceImage? _defaultInstance;

  @$pb.TagNumber(1)
  Image get image => $_getN(0);
  @$pb.TagNumber(1)
  set image(Image value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasImage() => $_has(0);
  @$pb.TagNumber(1)
  void clearImage() => $_clearField(1);
  @$pb.TagNumber(1)
  Image ensureImage() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.double get scalingRate => $_getN(1);
  @$pb.TagNumber(2)
  set scalingRate($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScalingRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearScalingRate() => $_clearField(2);
}

class TextPiecePatternRef extends $pb.GeneratedMessage {
  factory TextPiecePatternRef({$core.String? key, $core.String? defaultPattern}) {
    final result = create();
    if (key != null) result.key = key;
    if (defaultPattern != null) result.defaultPattern = defaultPattern;
    return result;
  }

  TextPiecePatternRef._();

  factory TextPiecePatternRef.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextPiecePatternRef.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextPiecePatternRef',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'key')
        ..aOS(2, _omitFieldNames ? '' : 'defaultPattern', protoName: 'defaultPattern')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPiecePatternRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPiecePatternRef copyWith(void Function(TextPiecePatternRef) updates) =>
      super.copyWith((message) => updates(message as TextPiecePatternRef)) as TextPiecePatternRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextPiecePatternRef create() => TextPiecePatternRef._();
  @$core.override
  TextPiecePatternRef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextPiecePatternRef getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextPiecePatternRef>(create);
  static TextPiecePatternRef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get defaultPattern => $_getSZ(1);
  @$pb.TagNumber(2)
  set defaultPattern($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaultPattern() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultPattern() => $_clearField(2);
}

class TextPieceHeart extends $pb.GeneratedMessage {
  factory TextPieceHeart({$core.String? color}) {
    final result = create();
    if (color != null) result.color = color;
    return result;
  }

  TextPieceHeart._();

  factory TextPieceHeart.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextPieceHeart.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextPieceHeart',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'color')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceHeart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceHeart copyWith(void Function(TextPieceHeart) updates) =>
      super.copyWith((message) => updates(message as TextPieceHeart)) as TextPieceHeart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextPieceHeart create() => TextPieceHeart._();
  @$core.override
  TextPieceHeart createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextPieceHeart getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextPieceHeart>(create);
  static TextPieceHeart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get color => $_getSZ(0);
  @$pb.TagNumber(1)
  set color($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasColor() => $_has(0);
  @$pb.TagNumber(1)
  void clearColor() => $_clearField(1);
}

class TextPieceGift extends $pb.GeneratedMessage {
  factory TextPieceGift({$fixnum.Int64? giftId, PatternRef? nameRef}) {
    final result = create();
    if (giftId != null) result.giftId = giftId;
    if (nameRef != null) result.nameRef = nameRef;
    return result;
  }

  TextPieceGift._();

  factory TextPieceGift.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextPieceGift.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextPieceGift',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(
          1,
          _omitFieldNames ? '' : 'giftId',
          $pb.PbFieldType.OU6,
          protoName: 'giftId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<PatternRef>(2, _omitFieldNames ? '' : 'nameRef', protoName: 'nameRef', subBuilder: PatternRef.create)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceGift clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceGift copyWith(void Function(TextPieceGift) updates) =>
      super.copyWith((message) => updates(message as TextPieceGift)) as TextPieceGift;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextPieceGift create() => TextPieceGift._();
  @$core.override
  TextPieceGift createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextPieceGift getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextPieceGift>(create);
  static TextPieceGift? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get giftId => $_getI64(0);
  @$pb.TagNumber(1)
  set giftId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGiftId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGiftId() => $_clearField(1);

  @$pb.TagNumber(2)
  PatternRef get nameRef => $_getN(1);
  @$pb.TagNumber(2)
  set nameRef(PatternRef value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNameRef() => $_has(1);
  @$pb.TagNumber(2)
  void clearNameRef() => $_clearField(2);
  @$pb.TagNumber(2)
  PatternRef ensureNameRef() => $_ensure(1);
}

class PatternRef extends $pb.GeneratedMessage {
  factory PatternRef({$core.String? key, $core.String? defaultPattern}) {
    final result = create();
    if (key != null) result.key = key;
    if (defaultPattern != null) result.defaultPattern = defaultPattern;
    return result;
  }

  PatternRef._();

  factory PatternRef.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory PatternRef.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'PatternRef',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'key')
        ..aOS(2, _omitFieldNames ? '' : 'defaultPattern', protoName: 'defaultPattern')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PatternRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PatternRef copyWith(void Function(PatternRef) updates) =>
      super.copyWith((message) => updates(message as PatternRef)) as PatternRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PatternRef create() => PatternRef._();
  @$core.override
  PatternRef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PatternRef getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PatternRef>(create);
  static PatternRef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get defaultPattern => $_getSZ(1);
  @$pb.TagNumber(2)
  set defaultPattern($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaultPattern() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultPattern() => $_clearField(2);
}

class TextPieceUser extends $pb.GeneratedMessage {
  factory TextPieceUser({User? user, $core.bool? withColon}) {
    final result = create();
    if (user != null) result.user = user;
    if (withColon != null) result.withColon = withColon;
    return result;
  }

  TextPieceUser._();

  factory TextPieceUser.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextPieceUser.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextPieceUser',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..aOB(2, _omitFieldNames ? '' : 'withColon', protoName: 'withColon')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceUser clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextPieceUser copyWith(void Function(TextPieceUser) updates) =>
      super.copyWith((message) => updates(message as TextPieceUser)) as TextPieceUser;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextPieceUser create() => TextPieceUser._();
  @$core.override
  TextPieceUser createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextPieceUser getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextPieceUser>(create);
  static TextPieceUser? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get withColon => $_getBF(1);
  @$pb.TagNumber(2)
  set withColon($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWithColon() => $_has(1);
  @$pb.TagNumber(2)
  void clearWithColon() => $_clearField(2);
}

class TextFormat extends $pb.GeneratedMessage {
  factory TextFormat({
    $core.String? color,
    $core.bool? bold,
    $core.bool? italic,
    $core.int? weight,
    $core.int? italicAngle,
    $core.int? fontSize,
    $core.bool? useHeighLightColor,
    $core.bool? useRemoteClor,
  }) {
    final result = create();
    if (color != null) result.color = color;
    if (bold != null) result.bold = bold;
    if (italic != null) result.italic = italic;
    if (weight != null) result.weight = weight;
    if (italicAngle != null) result.italicAngle = italicAngle;
    if (fontSize != null) result.fontSize = fontSize;
    if (useHeighLightColor != null) result.useHeighLightColor = useHeighLightColor;
    if (useRemoteClor != null) result.useRemoteClor = useRemoteClor;
    return result;
  }

  TextFormat._();

  factory TextFormat.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory TextFormat.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'TextFormat',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'color')
        ..aOB(2, _omitFieldNames ? '' : 'bold')
        ..aOB(3, _omitFieldNames ? '' : 'italic')
        ..aI(4, _omitFieldNames ? '' : 'weight', fieldType: $pb.PbFieldType.OU3)
        ..aI(5, _omitFieldNames ? '' : 'italicAngle', protoName: 'italicAngle', fieldType: $pb.PbFieldType.OU3)
        ..aI(6, _omitFieldNames ? '' : 'fontSize', protoName: 'fontSize', fieldType: $pb.PbFieldType.OU3)
        ..aOB(7, _omitFieldNames ? '' : 'useHeighLightColor', protoName: 'useHeighLightColor')
        ..aOB(8, _omitFieldNames ? '' : 'useRemoteClor', protoName: 'useRemoteClor')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextFormat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextFormat copyWith(void Function(TextFormat) updates) =>
      super.copyWith((message) => updates(message as TextFormat)) as TextFormat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextFormat create() => TextFormat._();
  @$core.override
  TextFormat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextFormat getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextFormat>(create);
  static TextFormat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get color => $_getSZ(0);
  @$pb.TagNumber(1)
  set color($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasColor() => $_has(0);
  @$pb.TagNumber(1)
  void clearColor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get bold => $_getBF(1);
  @$pb.TagNumber(2)
  set bold($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBold() => $_has(1);
  @$pb.TagNumber(2)
  void clearBold() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get italic => $_getBF(2);
  @$pb.TagNumber(3)
  set italic($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasItalic() => $_has(2);
  @$pb.TagNumber(3)
  void clearItalic() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get weight => $_getIZ(3);
  @$pb.TagNumber(4)
  set weight($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearWeight() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get italicAngle => $_getIZ(4);
  @$pb.TagNumber(5)
  set italicAngle($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasItalicAngle() => $_has(4);
  @$pb.TagNumber(5)
  void clearItalicAngle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get fontSize => $_getIZ(5);
  @$pb.TagNumber(6)
  set fontSize($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFontSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearFontSize() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get useHeighLightColor => $_getBF(6);
  @$pb.TagNumber(7)
  set useHeighLightColor($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUseHeighLightColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearUseHeighLightColor() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get useRemoteClor => $_getBF(7);
  @$pb.TagNumber(8)
  set useRemoteClor($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUseRemoteClor() => $_has(7);
  @$pb.TagNumber(8)
  void clearUseRemoteClor() => $_clearField(8);
}

/// 点赞
class LikeMessage extends $pb.GeneratedMessage {
  factory LikeMessage({
    Common? common,
    $fixnum.Int64? count,
    $fixnum.Int64? total,
    $fixnum.Int64? color,
    User? user,
    $core.String? icon,
    DoubleLikeDetail? doubleLikeDetail,
    DisplayControlInfo? displayControlInfo,
    $fixnum.Int64? linkmicGuestUid,
    $core.String? scene,
    PicoDisplayInfo? picoDisplayInfo,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (count != null) result.count = count;
    if (total != null) result.total = total;
    if (color != null) result.color = color;
    if (user != null) result.user = user;
    if (icon != null) result.icon = icon;
    if (doubleLikeDetail != null) result.doubleLikeDetail = doubleLikeDetail;
    if (displayControlInfo != null) result.displayControlInfo = displayControlInfo;
    if (linkmicGuestUid != null) result.linkmicGuestUid = linkmicGuestUid;
    if (scene != null) result.scene = scene;
    if (picoDisplayInfo != null) result.picoDisplayInfo = picoDisplayInfo;
    return result;
  }

  LikeMessage._();

  factory LikeMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory LikeMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'LikeMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'count', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'total', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'color', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOM<User>(5, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..aOS(6, _omitFieldNames ? '' : 'icon')
        ..aOM<DoubleLikeDetail>(
          7,
          _omitFieldNames ? '' : 'doubleLikeDetail',
          protoName: 'doubleLikeDetail',
          subBuilder: DoubleLikeDetail.create,
        )
        ..aOM<DisplayControlInfo>(
          8,
          _omitFieldNames ? '' : 'displayControlInfo',
          protoName: 'displayControlInfo',
          subBuilder: DisplayControlInfo.create,
        )
        ..a<$fixnum.Int64>(
          9,
          _omitFieldNames ? '' : 'linkmicGuestUid',
          $pb.PbFieldType.OU6,
          protoName: 'linkmicGuestUid',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(10, _omitFieldNames ? '' : 'scene')
        ..aOM<PicoDisplayInfo>(
          11,
          _omitFieldNames ? '' : 'picoDisplayInfo',
          protoName: 'picoDisplayInfo',
          subBuilder: PicoDisplayInfo.create,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LikeMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LikeMessage copyWith(void Function(LikeMessage) updates) =>
      super.copyWith((message) => updates(message as LikeMessage)) as LikeMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LikeMessage create() => LikeMessage._();
  @$core.override
  LikeMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LikeMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LikeMessage>(create);
  static LikeMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get total => $_getI64(2);
  @$pb.TagNumber(3)
  set total($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotal() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get color => $_getI64(3);
  @$pb.TagNumber(4)
  set color($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearColor() => $_clearField(4);

  @$pb.TagNumber(5)
  User get user => $_getN(4);
  @$pb.TagNumber(5)
  set user(User value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUser() => $_has(4);
  @$pb.TagNumber(5)
  void clearUser() => $_clearField(5);
  @$pb.TagNumber(5)
  User ensureUser() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get icon => $_getSZ(5);
  @$pb.TagNumber(6)
  set icon($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIcon() => $_has(5);
  @$pb.TagNumber(6)
  void clearIcon() => $_clearField(6);

  @$pb.TagNumber(7)
  DoubleLikeDetail get doubleLikeDetail => $_getN(6);
  @$pb.TagNumber(7)
  set doubleLikeDetail(DoubleLikeDetail value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDoubleLikeDetail() => $_has(6);
  @$pb.TagNumber(7)
  void clearDoubleLikeDetail() => $_clearField(7);
  @$pb.TagNumber(7)
  DoubleLikeDetail ensureDoubleLikeDetail() => $_ensure(6);

  @$pb.TagNumber(8)
  DisplayControlInfo get displayControlInfo => $_getN(7);
  @$pb.TagNumber(8)
  set displayControlInfo(DisplayControlInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDisplayControlInfo() => $_has(7);
  @$pb.TagNumber(8)
  void clearDisplayControlInfo() => $_clearField(8);
  @$pb.TagNumber(8)
  DisplayControlInfo ensureDisplayControlInfo() => $_ensure(7);

  @$pb.TagNumber(9)
  $fixnum.Int64 get linkmicGuestUid => $_getI64(8);
  @$pb.TagNumber(9)
  set linkmicGuestUid($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLinkmicGuestUid() => $_has(8);
  @$pb.TagNumber(9)
  void clearLinkmicGuestUid() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get scene => $_getSZ(9);
  @$pb.TagNumber(10)
  set scene($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasScene() => $_has(9);
  @$pb.TagNumber(10)
  void clearScene() => $_clearField(10);

  @$pb.TagNumber(11)
  PicoDisplayInfo get picoDisplayInfo => $_getN(10);
  @$pb.TagNumber(11)
  set picoDisplayInfo(PicoDisplayInfo value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasPicoDisplayInfo() => $_has(10);
  @$pb.TagNumber(11)
  void clearPicoDisplayInfo() => $_clearField(11);
  @$pb.TagNumber(11)
  PicoDisplayInfo ensurePicoDisplayInfo() => $_ensure(10);
}

class SocialMessage extends $pb.GeneratedMessage {
  factory SocialMessage({
    Common? common,
    User? user,
    $fixnum.Int64? shareType,
    $fixnum.Int64? action,
    $core.String? shareTarget,
    $fixnum.Int64? followCount,
    PublicAreaCommon? publicAreaCommon,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (user != null) result.user = user;
    if (shareType != null) result.shareType = shareType;
    if (action != null) result.action = action;
    if (shareTarget != null) result.shareTarget = shareTarget;
    if (followCount != null) result.followCount = followCount;
    if (publicAreaCommon != null) result.publicAreaCommon = publicAreaCommon;
    return result;
  }

  SocialMessage._();

  factory SocialMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory SocialMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'SocialMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'shareType',
          $pb.PbFieldType.OU6,
          protoName: 'shareType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'action', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOS(5, _omitFieldNames ? '' : 'shareTarget', protoName: 'shareTarget')
        ..a<$fixnum.Int64>(
          6,
          _omitFieldNames ? '' : 'followCount',
          $pb.PbFieldType.OU6,
          protoName: 'followCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOM<PublicAreaCommon>(
          7,
          _omitFieldNames ? '' : 'publicAreaCommon',
          protoName: 'publicAreaCommon',
          subBuilder: PublicAreaCommon.create,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SocialMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SocialMessage copyWith(void Function(SocialMessage) updates) =>
      super.copyWith((message) => updates(message as SocialMessage)) as SocialMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SocialMessage create() => SocialMessage._();
  @$core.override
  SocialMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SocialMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SocialMessage>(create);
  static SocialMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get shareType => $_getI64(2);
  @$pb.TagNumber(3)
  set shareType($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShareType() => $_has(2);
  @$pb.TagNumber(3)
  void clearShareType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get action => $_getI64(3);
  @$pb.TagNumber(4)
  set action($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get shareTarget => $_getSZ(4);
  @$pb.TagNumber(5)
  set shareTarget($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShareTarget() => $_has(4);
  @$pb.TagNumber(5)
  void clearShareTarget() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get followCount => $_getI64(5);
  @$pb.TagNumber(6)
  set followCount($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFollowCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearFollowCount() => $_clearField(6);

  @$pb.TagNumber(7)
  PublicAreaCommon get publicAreaCommon => $_getN(6);
  @$pb.TagNumber(7)
  set publicAreaCommon(PublicAreaCommon value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPublicAreaCommon() => $_has(6);
  @$pb.TagNumber(7)
  void clearPublicAreaCommon() => $_clearField(7);
  @$pb.TagNumber(7)
  PublicAreaCommon ensurePublicAreaCommon() => $_ensure(6);
}

class PicoDisplayInfo extends $pb.GeneratedMessage {
  factory PicoDisplayInfo({
    $fixnum.Int64? comboSumCount,
    $core.String? emoji,
    Image? emojiIcon,
    $core.String? emojiText,
  }) {
    final result = create();
    if (comboSumCount != null) result.comboSumCount = comboSumCount;
    if (emoji != null) result.emoji = emoji;
    if (emojiIcon != null) result.emojiIcon = emojiIcon;
    if (emojiText != null) result.emojiText = emojiText;
    return result;
  }

  PicoDisplayInfo._();

  factory PicoDisplayInfo.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory PicoDisplayInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'PicoDisplayInfo',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(
          1,
          _omitFieldNames ? '' : 'comboSumCount',
          $pb.PbFieldType.OU6,
          protoName: 'comboSumCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(2, _omitFieldNames ? '' : 'emoji')
        ..aOM<Image>(3, _omitFieldNames ? '' : 'emojiIcon', protoName: 'emojiIcon', subBuilder: Image.create)
        ..aOS(4, _omitFieldNames ? '' : 'emojiText', protoName: 'emojiText')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PicoDisplayInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PicoDisplayInfo copyWith(void Function(PicoDisplayInfo) updates) =>
      super.copyWith((message) => updates(message as PicoDisplayInfo)) as PicoDisplayInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PicoDisplayInfo create() => PicoDisplayInfo._();
  @$core.override
  PicoDisplayInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PicoDisplayInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PicoDisplayInfo>(create);
  static PicoDisplayInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get comboSumCount => $_getI64(0);
  @$pb.TagNumber(1)
  set comboSumCount($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasComboSumCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearComboSumCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get emoji => $_getSZ(1);
  @$pb.TagNumber(2)
  set emoji($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmoji() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmoji() => $_clearField(2);

  @$pb.TagNumber(3)
  Image get emojiIcon => $_getN(2);
  @$pb.TagNumber(3)
  set emojiIcon(Image value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasEmojiIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmojiIcon() => $_clearField(3);
  @$pb.TagNumber(3)
  Image ensureEmojiIcon() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get emojiText => $_getSZ(3);
  @$pb.TagNumber(4)
  set emojiText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmojiText() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmojiText() => $_clearField(4);
}

class DoubleLikeDetail extends $pb.GeneratedMessage {
  factory DoubleLikeDetail({$core.bool? doubleFlag, $core.int? seqId, $core.int? renewalsNum, $core.int? triggersNum}) {
    final result = create();
    if (doubleFlag != null) result.doubleFlag = doubleFlag;
    if (seqId != null) result.seqId = seqId;
    if (renewalsNum != null) result.renewalsNum = renewalsNum;
    if (triggersNum != null) result.triggersNum = triggersNum;
    return result;
  }

  DoubleLikeDetail._();

  factory DoubleLikeDetail.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory DoubleLikeDetail.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'DoubleLikeDetail',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOB(1, _omitFieldNames ? '' : 'doubleFlag', protoName: 'doubleFlag')
        ..aI(2, _omitFieldNames ? '' : 'seqId', protoName: 'seqId', fieldType: $pb.PbFieldType.OU3)
        ..aI(3, _omitFieldNames ? '' : 'renewalsNum', protoName: 'renewalsNum', fieldType: $pb.PbFieldType.OU3)
        ..aI(4, _omitFieldNames ? '' : 'triggersNum', protoName: 'triggersNum', fieldType: $pb.PbFieldType.OU3)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DoubleLikeDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DoubleLikeDetail copyWith(void Function(DoubleLikeDetail) updates) =>
      super.copyWith((message) => updates(message as DoubleLikeDetail)) as DoubleLikeDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DoubleLikeDetail create() => DoubleLikeDetail._();
  @$core.override
  DoubleLikeDetail createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DoubleLikeDetail getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DoubleLikeDetail>(create);
  static DoubleLikeDetail? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get doubleFlag => $_getBF(0);
  @$pb.TagNumber(1)
  set doubleFlag($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDoubleFlag() => $_has(0);
  @$pb.TagNumber(1)
  void clearDoubleFlag() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get seqId => $_getIZ(1);
  @$pb.TagNumber(2)
  set seqId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeqId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeqId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get renewalsNum => $_getIZ(2);
  @$pb.TagNumber(3)
  set renewalsNum($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRenewalsNum() => $_has(2);
  @$pb.TagNumber(3)
  void clearRenewalsNum() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get triggersNum => $_getIZ(3);
  @$pb.TagNumber(4)
  set triggersNum($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTriggersNum() => $_has(3);
  @$pb.TagNumber(4)
  void clearTriggersNum() => $_clearField(4);
}

class DisplayControlInfo extends $pb.GeneratedMessage {
  factory DisplayControlInfo({$core.bool? showText, $core.bool? showIcons}) {
    final result = create();
    if (showText != null) result.showText = showText;
    if (showIcons != null) result.showIcons = showIcons;
    return result;
  }

  DisplayControlInfo._();

  factory DisplayControlInfo.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory DisplayControlInfo.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'DisplayControlInfo',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOB(1, _omitFieldNames ? '' : 'showText', protoName: 'showText')
        ..aOB(2, _omitFieldNames ? '' : 'showIcons', protoName: 'showIcons')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DisplayControlInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DisplayControlInfo copyWith(void Function(DisplayControlInfo) updates) =>
      super.copyWith((message) => updates(message as DisplayControlInfo)) as DisplayControlInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DisplayControlInfo create() => DisplayControlInfo._();
  @$core.override
  DisplayControlInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DisplayControlInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DisplayControlInfo>(create);
  static DisplayControlInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get showText => $_getBF(0);
  @$pb.TagNumber(1)
  set showText($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShowText() => $_has(0);
  @$pb.TagNumber(1)
  void clearShowText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get showIcons => $_getBF(1);
  @$pb.TagNumber(2)
  set showIcons($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShowIcons() => $_has(1);
  @$pb.TagNumber(2)
  void clearShowIcons() => $_clearField(2);
}

class EpisodeChatMessage extends $pb.GeneratedMessage {
  factory EpisodeChatMessage({
    Message? common,
    User? user,
    $core.String? content,
    $core.bool? visibleToSende,
    Image? giftImage,
    $fixnum.Int64? agreeMsgId,
    $core.Iterable<$core.String>? colorValueList,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (user != null) result.user = user;
    if (content != null) result.content = content;
    if (visibleToSende != null) result.visibleToSende = visibleToSende;
    if (giftImage != null) result.giftImage = giftImage;
    if (agreeMsgId != null) result.agreeMsgId = agreeMsgId;
    if (colorValueList != null) result.colorValueList.addAll(colorValueList);
    return result;
  }

  EpisodeChatMessage._();

  factory EpisodeChatMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory EpisodeChatMessage.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'EpisodeChatMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Message>(1, _omitFieldNames ? '' : 'common', subBuilder: Message.create)
        ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..aOS(3, _omitFieldNames ? '' : 'content')
        ..aOB(4, _omitFieldNames ? '' : 'visibleToSende', protoName: 'visibleToSende')
        ..aOM<Image>(7, _omitFieldNames ? '' : 'giftImage', protoName: 'giftImage', subBuilder: Image.create)
        ..a<$fixnum.Int64>(
          8,
          _omitFieldNames ? '' : 'agreeMsgId',
          $pb.PbFieldType.OU6,
          protoName: 'agreeMsgId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..pPS(9, _omitFieldNames ? '' : 'colorValueList', protoName: 'colorValueList')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeChatMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeChatMessage copyWith(void Function(EpisodeChatMessage) updates) =>
      super.copyWith((message) => updates(message as EpisodeChatMessage)) as EpisodeChatMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EpisodeChatMessage create() => EpisodeChatMessage._();
  @$core.override
  EpisodeChatMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EpisodeChatMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EpisodeChatMessage>(create);
  static EpisodeChatMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Message get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Message value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Message ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get visibleToSende => $_getBF(3);
  @$pb.TagNumber(4)
  set visibleToSende($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVisibleToSende() => $_has(3);
  @$pb.TagNumber(4)
  void clearVisibleToSende() => $_clearField(4);

  /// BackgroundImage backgroundImage = 5;
  /// PublicAreaCommon publicAreaCommon = 6;
  @$pb.TagNumber(7)
  Image get giftImage => $_getN(4);
  @$pb.TagNumber(7)
  set giftImage(Image value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasGiftImage() => $_has(4);
  @$pb.TagNumber(7)
  void clearGiftImage() => $_clearField(7);
  @$pb.TagNumber(7)
  Image ensureGiftImage() => $_ensure(4);

  @$pb.TagNumber(8)
  $fixnum.Int64 get agreeMsgId => $_getI64(5);
  @$pb.TagNumber(8)
  set agreeMsgId($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(8)
  $core.bool hasAgreeMsgId() => $_has(5);
  @$pb.TagNumber(8)
  void clearAgreeMsgId() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get colorValueList => $_getList(6);
}

class MatchAgainstScoreMessage extends $pb.GeneratedMessage {
  factory MatchAgainstScoreMessage({
    Common? common,
    Against? against,
    $core.int? matchStatus,
    $core.int? displayStatus,
  }) {
    final result = create();
    if (common != null) result.common = common;
    if (against != null) result.against = against;
    if (matchStatus != null) result.matchStatus = matchStatus;
    if (displayStatus != null) result.displayStatus = displayStatus;
    return result;
  }

  MatchAgainstScoreMessage._();

  factory MatchAgainstScoreMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory MatchAgainstScoreMessage.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'MatchAgainstScoreMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOM<Common>(1, _omitFieldNames ? '' : 'common', subBuilder: Common.create)
        ..aOM<Against>(2, _omitFieldNames ? '' : 'against', subBuilder: Against.create)
        ..aI(3, _omitFieldNames ? '' : 'matchStatus', protoName: 'matchStatus', fieldType: $pb.PbFieldType.OU3)
        ..aI(4, _omitFieldNames ? '' : 'displayStatus', protoName: 'displayStatus', fieldType: $pb.PbFieldType.OU3)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchAgainstScoreMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatchAgainstScoreMessage copyWith(void Function(MatchAgainstScoreMessage) updates) =>
      super.copyWith((message) => updates(message as MatchAgainstScoreMessage)) as MatchAgainstScoreMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchAgainstScoreMessage create() => MatchAgainstScoreMessage._();
  @$core.override
  MatchAgainstScoreMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MatchAgainstScoreMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchAgainstScoreMessage>(create);
  static MatchAgainstScoreMessage? _defaultInstance;

  @$pb.TagNumber(1)
  Common get common => $_getN(0);
  @$pb.TagNumber(1)
  set common(Common value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCommon() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommon() => $_clearField(1);
  @$pb.TagNumber(1)
  Common ensureCommon() => $_ensure(0);

  @$pb.TagNumber(2)
  Against get against => $_getN(1);
  @$pb.TagNumber(2)
  set against(Against value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAgainst() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgainst() => $_clearField(2);
  @$pb.TagNumber(2)
  Against ensureAgainst() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get matchStatus => $_getIZ(2);
  @$pb.TagNumber(3)
  set matchStatus($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMatchStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearMatchStatus() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get displayStatus => $_getIZ(3);
  @$pb.TagNumber(4)
  set displayStatus($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDisplayStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearDisplayStatus() => $_clearField(4);
}

class Against extends $pb.GeneratedMessage {
  factory Against({
    $core.String? leftName,
    Image? leftLogo,
    $core.String? leftGoal,
    $core.String? rightName,
    Image? rightLogo,
    $core.String? rightGoal,
    $fixnum.Int64? timestamp,
    $fixnum.Int64? version,
    $fixnum.Int64? leftTeamId,
    $fixnum.Int64? rightTeamId,
    $fixnum.Int64? diffSei2absSecond,
    $core.int? finalGoalStage,
    $core.int? currentGoalStage,
    $core.int? leftScoreAddition,
    $core.int? rightScoreAddition,
    $fixnum.Int64? leftGoalInt,
    $fixnum.Int64? rightGoalInt,
  }) {
    final result = create();
    if (leftName != null) result.leftName = leftName;
    if (leftLogo != null) result.leftLogo = leftLogo;
    if (leftGoal != null) result.leftGoal = leftGoal;
    if (rightName != null) result.rightName = rightName;
    if (rightLogo != null) result.rightLogo = rightLogo;
    if (rightGoal != null) result.rightGoal = rightGoal;
    if (timestamp != null) result.timestamp = timestamp;
    if (version != null) result.version = version;
    if (leftTeamId != null) result.leftTeamId = leftTeamId;
    if (rightTeamId != null) result.rightTeamId = rightTeamId;
    if (diffSei2absSecond != null) result.diffSei2absSecond = diffSei2absSecond;
    if (finalGoalStage != null) result.finalGoalStage = finalGoalStage;
    if (currentGoalStage != null) result.currentGoalStage = currentGoalStage;
    if (leftScoreAddition != null) result.leftScoreAddition = leftScoreAddition;
    if (rightScoreAddition != null) result.rightScoreAddition = rightScoreAddition;
    if (leftGoalInt != null) result.leftGoalInt = leftGoalInt;
    if (rightGoalInt != null) result.rightGoalInt = rightGoalInt;
    return result;
  }

  Against._();

  factory Against.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory Against.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Against',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'leftName', protoName: 'leftName')
        ..aOM<Image>(2, _omitFieldNames ? '' : 'leftLogo', protoName: 'leftLogo', subBuilder: Image.create)
        ..aOS(3, _omitFieldNames ? '' : 'leftGoal', protoName: 'leftGoal')
        ..aOS(6, _omitFieldNames ? '' : 'rightName', protoName: 'rightName')
        ..aOM<Image>(7, _omitFieldNames ? '' : 'rightLogo', protoName: 'rightLogo', subBuilder: Image.create)
        ..aOS(8, _omitFieldNames ? '' : 'rightGoal', protoName: 'rightGoal')
        ..a<$fixnum.Int64>(
          11,
          _omitFieldNames ? '' : 'timestamp',
          $pb.PbFieldType.OU6,
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          12,
          _omitFieldNames ? '' : 'version',
          $pb.PbFieldType.OU6,
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          13,
          _omitFieldNames ? '' : 'leftTeamId',
          $pb.PbFieldType.OU6,
          protoName: 'leftTeamId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          14,
          _omitFieldNames ? '' : 'rightTeamId',
          $pb.PbFieldType.OU6,
          protoName: 'rightTeamId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          15,
          _omitFieldNames ? '' : 'diffSei2absSecond',
          $pb.PbFieldType.OU6,
          protoName: 'diffSei2absSecond',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aI(16, _omitFieldNames ? '' : 'finalGoalStage', protoName: 'finalGoalStage', fieldType: $pb.PbFieldType.OU3)
        ..aI(
          17,
          _omitFieldNames ? '' : 'currentGoalStage',
          protoName: 'currentGoalStage',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..aI(
          18,
          _omitFieldNames ? '' : 'leftScoreAddition',
          protoName: 'leftScoreAddition',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..aI(
          19,
          _omitFieldNames ? '' : 'rightScoreAddition',
          protoName: 'rightScoreAddition',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..a<$fixnum.Int64>(
          20,
          _omitFieldNames ? '' : 'leftGoalInt',
          $pb.PbFieldType.OU6,
          protoName: 'leftGoalInt',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          21,
          _omitFieldNames ? '' : 'rightGoalInt',
          $pb.PbFieldType.OU6,
          protoName: 'rightGoalInt',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Against clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Against copyWith(void Function(Against) updates) =>
      super.copyWith((message) => updates(message as Against)) as Against;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Against create() => Against._();
  @$core.override
  Against createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Against getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Against>(create);
  static Against? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get leftName => $_getSZ(0);
  @$pb.TagNumber(1)
  set leftName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLeftName() => $_has(0);
  @$pb.TagNumber(1)
  void clearLeftName() => $_clearField(1);

  @$pb.TagNumber(2)
  Image get leftLogo => $_getN(1);
  @$pb.TagNumber(2)
  set leftLogo(Image value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLeftLogo() => $_has(1);
  @$pb.TagNumber(2)
  void clearLeftLogo() => $_clearField(2);
  @$pb.TagNumber(2)
  Image ensureLeftLogo() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get leftGoal => $_getSZ(2);
  @$pb.TagNumber(3)
  set leftGoal($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLeftGoal() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeftGoal() => $_clearField(3);

  /// LeftPlayersList leftPlayersList = 4;
  /// LeftGoalStageDetail leftGoalStageDetail = 5;
  @$pb.TagNumber(6)
  $core.String get rightName => $_getSZ(3);
  @$pb.TagNumber(6)
  set rightName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(6)
  $core.bool hasRightName() => $_has(3);
  @$pb.TagNumber(6)
  void clearRightName() => $_clearField(6);

  @$pb.TagNumber(7)
  Image get rightLogo => $_getN(4);
  @$pb.TagNumber(7)
  set rightLogo(Image value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRightLogo() => $_has(4);
  @$pb.TagNumber(7)
  void clearRightLogo() => $_clearField(7);
  @$pb.TagNumber(7)
  Image ensureRightLogo() => $_ensure(4);

  @$pb.TagNumber(8)
  $core.String get rightGoal => $_getSZ(5);
  @$pb.TagNumber(8)
  set rightGoal($core.String value) => $_setString(5, value);
  @$pb.TagNumber(8)
  $core.bool hasRightGoal() => $_has(5);
  @$pb.TagNumber(8)
  void clearRightGoal() => $_clearField(8);

  /// RightPlayersList rightPlayersList  = 9;
  /// RightGoalStageDetail rightGoalStageDetail = 10;
  @$pb.TagNumber(11)
  $fixnum.Int64 get timestamp => $_getI64(6);
  @$pb.TagNumber(11)
  set timestamp($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(11)
  $core.bool hasTimestamp() => $_has(6);
  @$pb.TagNumber(11)
  void clearTimestamp() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get version => $_getI64(7);
  @$pb.TagNumber(12)
  set version($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(12)
  $core.bool hasVersion() => $_has(7);
  @$pb.TagNumber(12)
  void clearVersion() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get leftTeamId => $_getI64(8);
  @$pb.TagNumber(13)
  set leftTeamId($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(13)
  $core.bool hasLeftTeamId() => $_has(8);
  @$pb.TagNumber(13)
  void clearLeftTeamId() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get rightTeamId => $_getI64(9);
  @$pb.TagNumber(14)
  set rightTeamId($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(14)
  $core.bool hasRightTeamId() => $_has(9);
  @$pb.TagNumber(14)
  void clearRightTeamId() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get diffSei2absSecond => $_getI64(10);
  @$pb.TagNumber(15)
  set diffSei2absSecond($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(15)
  $core.bool hasDiffSei2absSecond() => $_has(10);
  @$pb.TagNumber(15)
  void clearDiffSei2absSecond() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get finalGoalStage => $_getIZ(11);
  @$pb.TagNumber(16)
  set finalGoalStage($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(16)
  $core.bool hasFinalGoalStage() => $_has(11);
  @$pb.TagNumber(16)
  void clearFinalGoalStage() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get currentGoalStage => $_getIZ(12);
  @$pb.TagNumber(17)
  set currentGoalStage($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(17)
  $core.bool hasCurrentGoalStage() => $_has(12);
  @$pb.TagNumber(17)
  void clearCurrentGoalStage() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get leftScoreAddition => $_getIZ(13);
  @$pb.TagNumber(18)
  set leftScoreAddition($core.int value) => $_setUnsignedInt32(13, value);
  @$pb.TagNumber(18)
  $core.bool hasLeftScoreAddition() => $_has(13);
  @$pb.TagNumber(18)
  void clearLeftScoreAddition() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.int get rightScoreAddition => $_getIZ(14);
  @$pb.TagNumber(19)
  set rightScoreAddition($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(19)
  $core.bool hasRightScoreAddition() => $_has(14);
  @$pb.TagNumber(19)
  void clearRightScoreAddition() => $_clearField(19);

  @$pb.TagNumber(20)
  $fixnum.Int64 get leftGoalInt => $_getI64(15);
  @$pb.TagNumber(20)
  set leftGoalInt($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(20)
  $core.bool hasLeftGoalInt() => $_has(15);
  @$pb.TagNumber(20)
  void clearLeftGoalInt() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get rightGoalInt => $_getI64(16);
  @$pb.TagNumber(21)
  set rightGoalInt($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(21)
  $core.bool hasRightGoalInt() => $_has(16);
  @$pb.TagNumber(21)
  void clearRightGoalInt() => $_clearField(21);
}

class Common extends $pb.GeneratedMessage {
  factory Common({
    $core.String? method,
    $fixnum.Int64? msgId,
    $fixnum.Int64? roomId,
    $fixnum.Int64? createTime,
    $core.int? monitor,
    $core.bool? isShowMsg,
    $core.String? describe,
    $fixnum.Int64? foldType,
    $fixnum.Int64? anchorFoldType,
    $fixnum.Int64? priorityScore,
    $core.String? logId,
    $core.String? msgProcessFilterK,
    $core.String? msgProcessFilterV,
    User? user,
    $fixnum.Int64? anchorFoldTypeV2,
    $fixnum.Int64? processAtSeiTimeMs,
    $fixnum.Int64? randomDispatchMs,
    $core.bool? isDispatch,
    $fixnum.Int64? channelId,
    $fixnum.Int64? diffSei2absSecond,
    $fixnum.Int64? anchorFoldDuration,
  }) {
    final result = create();
    if (method != null) result.method = method;
    if (msgId != null) result.msgId = msgId;
    if (roomId != null) result.roomId = roomId;
    if (createTime != null) result.createTime = createTime;
    if (monitor != null) result.monitor = monitor;
    if (isShowMsg != null) result.isShowMsg = isShowMsg;
    if (describe != null) result.describe = describe;
    if (foldType != null) result.foldType = foldType;
    if (anchorFoldType != null) result.anchorFoldType = anchorFoldType;
    if (priorityScore != null) result.priorityScore = priorityScore;
    if (logId != null) result.logId = logId;
    if (msgProcessFilterK != null) result.msgProcessFilterK = msgProcessFilterK;
    if (msgProcessFilterV != null) result.msgProcessFilterV = msgProcessFilterV;
    if (user != null) result.user = user;
    if (anchorFoldTypeV2 != null) result.anchorFoldTypeV2 = anchorFoldTypeV2;
    if (processAtSeiTimeMs != null) result.processAtSeiTimeMs = processAtSeiTimeMs;
    if (randomDispatchMs != null) result.randomDispatchMs = randomDispatchMs;
    if (isDispatch != null) result.isDispatch = isDispatch;
    if (channelId != null) result.channelId = channelId;
    if (diffSei2absSecond != null) result.diffSei2absSecond = diffSei2absSecond;
    if (anchorFoldDuration != null) result.anchorFoldDuration = anchorFoldDuration;
    return result;
  }

  Common._();

  factory Common.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory Common.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Common',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'method')
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'msgId',
          $pb.PbFieldType.OU6,
          protoName: 'msgId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'roomId',
          $pb.PbFieldType.OU6,
          protoName: 'roomId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          4,
          _omitFieldNames ? '' : 'createTime',
          $pb.PbFieldType.OU6,
          protoName: 'createTime',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aI(5, _omitFieldNames ? '' : 'monitor', fieldType: $pb.PbFieldType.OU3)
        ..aOB(6, _omitFieldNames ? '' : 'isShowMsg', protoName: 'isShowMsg')
        ..aOS(7, _omitFieldNames ? '' : 'describe')
        ..a<$fixnum.Int64>(
          9,
          _omitFieldNames ? '' : 'foldType',
          $pb.PbFieldType.OU6,
          protoName: 'foldType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          10,
          _omitFieldNames ? '' : 'anchorFoldType',
          $pb.PbFieldType.OU6,
          protoName: 'anchorFoldType',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          11,
          _omitFieldNames ? '' : 'priorityScore',
          $pb.PbFieldType.OU6,
          protoName: 'priorityScore',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(12, _omitFieldNames ? '' : 'logId', protoName: 'logId')
        ..aOS(13, _omitFieldNames ? '' : 'msgProcessFilterK', protoName: 'msgProcessFilterK')
        ..aOS(14, _omitFieldNames ? '' : 'msgProcessFilterV', protoName: 'msgProcessFilterV')
        ..aOM<User>(15, _omitFieldNames ? '' : 'user', subBuilder: User.create)
        ..a<$fixnum.Int64>(
          17,
          _omitFieldNames ? '' : 'anchorFoldTypeV2',
          $pb.PbFieldType.OU6,
          protoName: 'anchorFoldTypeV2',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          18,
          _omitFieldNames ? '' : 'processAtSeiTimeMs',
          $pb.PbFieldType.OU6,
          protoName: 'processAtSeiTimeMs',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          19,
          _omitFieldNames ? '' : 'randomDispatchMs',
          $pb.PbFieldType.OU6,
          protoName: 'randomDispatchMs',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOB(20, _omitFieldNames ? '' : 'isDispatch', protoName: 'isDispatch')
        ..a<$fixnum.Int64>(
          21,
          _omitFieldNames ? '' : 'channelId',
          $pb.PbFieldType.OU6,
          protoName: 'channelId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          22,
          _omitFieldNames ? '' : 'diffSei2absSecond',
          $pb.PbFieldType.OU6,
          protoName: 'diffSei2absSecond',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          23,
          _omitFieldNames ? '' : 'anchorFoldDuration',
          $pb.PbFieldType.OU6,
          protoName: 'anchorFoldDuration',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Common clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Common copyWith(void Function(Common) updates) => super.copyWith((message) => updates(message as Common)) as Common;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Common create() => Common._();
  @$core.override
  Common createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Common getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Common>(create);
  static Common? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get method => $_getSZ(0);
  @$pb.TagNumber(1)
  set method($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMethod() => $_has(0);
  @$pb.TagNumber(1)
  void clearMethod() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get msgId => $_getI64(1);
  @$pb.TagNumber(2)
  set msgId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get roomId => $_getI64(2);
  @$pb.TagNumber(3)
  set roomId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoomId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get createTime => $_getI64(3);
  @$pb.TagNumber(4)
  set createTime($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreateTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreateTime() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get monitor => $_getIZ(4);
  @$pb.TagNumber(5)
  set monitor($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMonitor() => $_has(4);
  @$pb.TagNumber(5)
  void clearMonitor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isShowMsg => $_getBF(5);
  @$pb.TagNumber(6)
  set isShowMsg($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsShowMsg() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsShowMsg() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get describe => $_getSZ(6);
  @$pb.TagNumber(7)
  set describe($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDescribe() => $_has(6);
  @$pb.TagNumber(7)
  void clearDescribe() => $_clearField(7);

  /// DisplayText displayText = 8;
  @$pb.TagNumber(9)
  $fixnum.Int64 get foldType => $_getI64(7);
  @$pb.TagNumber(9)
  set foldType($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(9)
  $core.bool hasFoldType() => $_has(7);
  @$pb.TagNumber(9)
  void clearFoldType() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get anchorFoldType => $_getI64(8);
  @$pb.TagNumber(10)
  set anchorFoldType($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(10)
  $core.bool hasAnchorFoldType() => $_has(8);
  @$pb.TagNumber(10)
  void clearAnchorFoldType() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get priorityScore => $_getI64(9);
  @$pb.TagNumber(11)
  set priorityScore($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(11)
  $core.bool hasPriorityScore() => $_has(9);
  @$pb.TagNumber(11)
  void clearPriorityScore() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get logId => $_getSZ(10);
  @$pb.TagNumber(12)
  set logId($core.String value) => $_setString(10, value);
  @$pb.TagNumber(12)
  $core.bool hasLogId() => $_has(10);
  @$pb.TagNumber(12)
  void clearLogId() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get msgProcessFilterK => $_getSZ(11);
  @$pb.TagNumber(13)
  set msgProcessFilterK($core.String value) => $_setString(11, value);
  @$pb.TagNumber(13)
  $core.bool hasMsgProcessFilterK() => $_has(11);
  @$pb.TagNumber(13)
  void clearMsgProcessFilterK() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get msgProcessFilterV => $_getSZ(12);
  @$pb.TagNumber(14)
  set msgProcessFilterV($core.String value) => $_setString(12, value);
  @$pb.TagNumber(14)
  $core.bool hasMsgProcessFilterV() => $_has(12);
  @$pb.TagNumber(14)
  void clearMsgProcessFilterV() => $_clearField(14);

  @$pb.TagNumber(15)
  User get user => $_getN(13);
  @$pb.TagNumber(15)
  set user(User value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasUser() => $_has(13);
  @$pb.TagNumber(15)
  void clearUser() => $_clearField(15);
  @$pb.TagNumber(15)
  User ensureUser() => $_ensure(13);

  /// Room room = 16;
  @$pb.TagNumber(17)
  $fixnum.Int64 get anchorFoldTypeV2 => $_getI64(14);
  @$pb.TagNumber(17)
  set anchorFoldTypeV2($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(17)
  $core.bool hasAnchorFoldTypeV2() => $_has(14);
  @$pb.TagNumber(17)
  void clearAnchorFoldTypeV2() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get processAtSeiTimeMs => $_getI64(15);
  @$pb.TagNumber(18)
  set processAtSeiTimeMs($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(18)
  $core.bool hasProcessAtSeiTimeMs() => $_has(15);
  @$pb.TagNumber(18)
  void clearProcessAtSeiTimeMs() => $_clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get randomDispatchMs => $_getI64(16);
  @$pb.TagNumber(19)
  set randomDispatchMs($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(19)
  $core.bool hasRandomDispatchMs() => $_has(16);
  @$pb.TagNumber(19)
  void clearRandomDispatchMs() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.bool get isDispatch => $_getBF(17);
  @$pb.TagNumber(20)
  set isDispatch($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(20)
  $core.bool hasIsDispatch() => $_has(17);
  @$pb.TagNumber(20)
  void clearIsDispatch() => $_clearField(20);

  @$pb.TagNumber(21)
  $fixnum.Int64 get channelId => $_getI64(18);
  @$pb.TagNumber(21)
  set channelId($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(21)
  $core.bool hasChannelId() => $_has(18);
  @$pb.TagNumber(21)
  void clearChannelId() => $_clearField(21);

  @$pb.TagNumber(22)
  $fixnum.Int64 get diffSei2absSecond => $_getI64(19);
  @$pb.TagNumber(22)
  set diffSei2absSecond($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(22)
  $core.bool hasDiffSei2absSecond() => $_has(19);
  @$pb.TagNumber(22)
  void clearDiffSei2absSecond() => $_clearField(22);

  @$pb.TagNumber(23)
  $fixnum.Int64 get anchorFoldDuration => $_getI64(20);
  @$pb.TagNumber(23)
  set anchorFoldDuration($fixnum.Int64 value) => $_setInt64(20, value);
  @$pb.TagNumber(23)
  $core.bool hasAnchorFoldDuration() => $_has(20);
  @$pb.TagNumber(23)
  void clearAnchorFoldDuration() => $_clearField(23);
}

class User extends $pb.GeneratedMessage {
  factory User({
    $fixnum.Int64? id,
    $fixnum.Int64? shortId,
    $core.String? nickName,
    $core.int? gender,
    $core.String? signature,
    $core.int? level,
    $fixnum.Int64? birthday,
    $core.String? telephone,
    Image? avatarThumb,
    Image? avatarMedium,
    Image? avatarLarge,
    $core.bool? verified,
    $core.int? experience,
    $core.String? city,
    $core.int? status,
    $fixnum.Int64? createTime,
    $fixnum.Int64? modifyTime,
    $core.int? secret,
    $core.String? shareQrcodeUri,
    $core.int? incomeSharePercent,
    $core.Iterable<Image>? badgeImageList,
    FollowInfo? followInfo,
    $core.String? specialId,
    Image? avatarBorder,
    Image? medal,
    $core.Iterable<Image>? realTimeIconsList,
    $core.String? displayId,
    $core.String? secUid,
    $fixnum.Int64? fanTicketCount,
    $core.String? idStr,
    $core.int? ageRange,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (shortId != null) result.shortId = shortId;
    if (nickName != null) result.nickName = nickName;
    if (gender != null) result.gender = gender;
    if (signature != null) result.signature = signature;
    if (level != null) result.level = level;
    if (birthday != null) result.birthday = birthday;
    if (telephone != null) result.telephone = telephone;
    if (avatarThumb != null) result.avatarThumb = avatarThumb;
    if (avatarMedium != null) result.avatarMedium = avatarMedium;
    if (avatarLarge != null) result.avatarLarge = avatarLarge;
    if (verified != null) result.verified = verified;
    if (experience != null) result.experience = experience;
    if (city != null) result.city = city;
    if (status != null) result.status = status;
    if (createTime != null) result.createTime = createTime;
    if (modifyTime != null) result.modifyTime = modifyTime;
    if (secret != null) result.secret = secret;
    if (shareQrcodeUri != null) result.shareQrcodeUri = shareQrcodeUri;
    if (incomeSharePercent != null) result.incomeSharePercent = incomeSharePercent;
    if (badgeImageList != null) result.badgeImageList.addAll(badgeImageList);
    if (followInfo != null) result.followInfo = followInfo;
    if (specialId != null) result.specialId = specialId;
    if (avatarBorder != null) result.avatarBorder = avatarBorder;
    if (medal != null) result.medal = medal;
    if (realTimeIconsList != null) result.realTimeIconsList.addAll(realTimeIconsList);
    if (displayId != null) result.displayId = displayId;
    if (secUid != null) result.secUid = secUid;
    if (fanTicketCount != null) result.fanTicketCount = fanTicketCount;
    if (idStr != null) result.idStr = idStr;
    if (ageRange != null) result.ageRange = ageRange;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'User',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'shortId',
          $pb.PbFieldType.OU6,
          protoName: 'shortId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(3, _omitFieldNames ? '' : 'nickName', protoName: 'nickName')
        ..aI(4, _omitFieldNames ? '' : 'gender', fieldType: $pb.PbFieldType.OU3)
        ..aOS(5, _omitFieldNames ? '' : 'Signature', protoName: 'Signature')
        ..aI(6, _omitFieldNames ? '' : 'Level', protoName: 'Level', fieldType: $pb.PbFieldType.OU3)
        ..a<$fixnum.Int64>(
          7,
          _omitFieldNames ? '' : 'Birthday',
          $pb.PbFieldType.OU6,
          protoName: 'Birthday',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(8, _omitFieldNames ? '' : 'Telephone', protoName: 'Telephone')
        ..aOM<Image>(9, _omitFieldNames ? '' : 'AvatarThumb', protoName: 'AvatarThumb', subBuilder: Image.create)
        ..aOM<Image>(10, _omitFieldNames ? '' : 'AvatarMedium', protoName: 'AvatarMedium', subBuilder: Image.create)
        ..aOM<Image>(11, _omitFieldNames ? '' : 'AvatarLarge', protoName: 'AvatarLarge', subBuilder: Image.create)
        ..aOB(12, _omitFieldNames ? '' : 'Verified', protoName: 'Verified')
        ..aI(13, _omitFieldNames ? '' : 'Experience', protoName: 'Experience', fieldType: $pb.PbFieldType.OU3)
        ..aOS(14, _omitFieldNames ? '' : 'city')
        ..aI(15, _omitFieldNames ? '' : 'Status', protoName: 'Status')
        ..a<$fixnum.Int64>(
          16,
          _omitFieldNames ? '' : 'CreateTime',
          $pb.PbFieldType.OU6,
          protoName: 'CreateTime',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          17,
          _omitFieldNames ? '' : 'ModifyTime',
          $pb.PbFieldType.OU6,
          protoName: 'ModifyTime',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aI(18, _omitFieldNames ? '' : 'Secret', protoName: 'Secret', fieldType: $pb.PbFieldType.OU3)
        ..aOS(19, _omitFieldNames ? '' : 'ShareQrcodeUri', protoName: 'ShareQrcodeUri')
        ..aI(
          20,
          _omitFieldNames ? '' : 'IncomeSharePercent',
          protoName: 'IncomeSharePercent',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..pPM<Image>(21, _omitFieldNames ? '' : 'BadgeImageList', protoName: 'BadgeImageList', subBuilder: Image.create)
        ..aOM<FollowInfo>(
          22,
          _omitFieldNames ? '' : 'FollowInfo',
          protoName: 'FollowInfo',
          subBuilder: FollowInfo.create,
        )
        ..aOS(26, _omitFieldNames ? '' : 'SpecialId', protoName: 'SpecialId')
        ..aOM<Image>(27, _omitFieldNames ? '' : 'AvatarBorder', protoName: 'AvatarBorder', subBuilder: Image.create)
        ..aOM<Image>(28, _omitFieldNames ? '' : 'Medal', protoName: 'Medal', subBuilder: Image.create)
        ..pPM<Image>(
          29,
          _omitFieldNames ? '' : 'RealTimeIconsList',
          protoName: 'RealTimeIconsList',
          subBuilder: Image.create,
        )
        ..aOS(38, _omitFieldNames ? '' : 'displayId', protoName: 'displayId')
        ..aOS(46, _omitFieldNames ? '' : 'secUid', protoName: 'secUid')
        ..a<$fixnum.Int64>(
          1022,
          _omitFieldNames ? '' : 'fanTicketCount',
          $pb.PbFieldType.OU6,
          protoName: 'fanTicketCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(1028, _omitFieldNames ? '' : 'idStr', protoName: 'idStr')
        ..aI(1045, _omitFieldNames ? '' : 'ageRange', protoName: 'ageRange', fieldType: $pb.PbFieldType.OU3)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) => super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static User create() => User._();
  @$core.override
  User createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static User getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(create);
  static User? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get shortId => $_getI64(1);
  @$pb.TagNumber(2)
  set shortId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShortId() => $_has(1);
  @$pb.TagNumber(2)
  void clearShortId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get nickName => $_getSZ(2);
  @$pb.TagNumber(3)
  set nickName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNickName() => $_has(2);
  @$pb.TagNumber(3)
  void clearNickName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get gender => $_getIZ(3);
  @$pb.TagNumber(4)
  set gender($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGender() => $_has(3);
  @$pb.TagNumber(4)
  void clearGender() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get signature => $_getSZ(4);
  @$pb.TagNumber(5)
  set signature($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get level => $_getIZ(5);
  @$pb.TagNumber(6)
  set level($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLevel() => $_has(5);
  @$pb.TagNumber(6)
  void clearLevel() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get birthday => $_getI64(6);
  @$pb.TagNumber(7)
  set birthday($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBirthday() => $_has(6);
  @$pb.TagNumber(7)
  void clearBirthday() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get telephone => $_getSZ(7);
  @$pb.TagNumber(8)
  set telephone($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTelephone() => $_has(7);
  @$pb.TagNumber(8)
  void clearTelephone() => $_clearField(8);

  @$pb.TagNumber(9)
  Image get avatarThumb => $_getN(8);
  @$pb.TagNumber(9)
  set avatarThumb(Image value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasAvatarThumb() => $_has(8);
  @$pb.TagNumber(9)
  void clearAvatarThumb() => $_clearField(9);
  @$pb.TagNumber(9)
  Image ensureAvatarThumb() => $_ensure(8);

  @$pb.TagNumber(10)
  Image get avatarMedium => $_getN(9);
  @$pb.TagNumber(10)
  set avatarMedium(Image value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasAvatarMedium() => $_has(9);
  @$pb.TagNumber(10)
  void clearAvatarMedium() => $_clearField(10);
  @$pb.TagNumber(10)
  Image ensureAvatarMedium() => $_ensure(9);

  @$pb.TagNumber(11)
  Image get avatarLarge => $_getN(10);
  @$pb.TagNumber(11)
  set avatarLarge(Image value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasAvatarLarge() => $_has(10);
  @$pb.TagNumber(11)
  void clearAvatarLarge() => $_clearField(11);
  @$pb.TagNumber(11)
  Image ensureAvatarLarge() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.bool get verified => $_getBF(11);
  @$pb.TagNumber(12)
  set verified($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasVerified() => $_has(11);
  @$pb.TagNumber(12)
  void clearVerified() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get experience => $_getIZ(12);
  @$pb.TagNumber(13)
  set experience($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasExperience() => $_has(12);
  @$pb.TagNumber(13)
  void clearExperience() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get city => $_getSZ(13);
  @$pb.TagNumber(14)
  set city($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCity() => $_has(13);
  @$pb.TagNumber(14)
  void clearCity() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get status => $_getIZ(14);
  @$pb.TagNumber(15)
  set status($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasStatus() => $_has(14);
  @$pb.TagNumber(15)
  void clearStatus() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get createTime => $_getI64(15);
  @$pb.TagNumber(16)
  set createTime($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasCreateTime() => $_has(15);
  @$pb.TagNumber(16)
  void clearCreateTime() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get modifyTime => $_getI64(16);
  @$pb.TagNumber(17)
  set modifyTime($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasModifyTime() => $_has(16);
  @$pb.TagNumber(17)
  void clearModifyTime() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get secret => $_getIZ(17);
  @$pb.TagNumber(18)
  set secret($core.int value) => $_setUnsignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasSecret() => $_has(17);
  @$pb.TagNumber(18)
  void clearSecret() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get shareQrcodeUri => $_getSZ(18);
  @$pb.TagNumber(19)
  set shareQrcodeUri($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasShareQrcodeUri() => $_has(18);
  @$pb.TagNumber(19)
  void clearShareQrcodeUri() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.int get incomeSharePercent => $_getIZ(19);
  @$pb.TagNumber(20)
  set incomeSharePercent($core.int value) => $_setUnsignedInt32(19, value);
  @$pb.TagNumber(20)
  $core.bool hasIncomeSharePercent() => $_has(19);
  @$pb.TagNumber(20)
  void clearIncomeSharePercent() => $_clearField(20);

  @$pb.TagNumber(21)
  $pb.PbList<Image> get badgeImageList => $_getList(20);

  @$pb.TagNumber(22)
  FollowInfo get followInfo => $_getN(21);
  @$pb.TagNumber(22)
  set followInfo(FollowInfo value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasFollowInfo() => $_has(21);
  @$pb.TagNumber(22)
  void clearFollowInfo() => $_clearField(22);
  @$pb.TagNumber(22)
  FollowInfo ensureFollowInfo() => $_ensure(21);

  /// PayGrade PayGrade = 23;
  /// FansClub FansClub = 24;
  /// Border Border = 25;
  @$pb.TagNumber(26)
  $core.String get specialId => $_getSZ(22);
  @$pb.TagNumber(26)
  set specialId($core.String value) => $_setString(22, value);
  @$pb.TagNumber(26)
  $core.bool hasSpecialId() => $_has(22);
  @$pb.TagNumber(26)
  void clearSpecialId() => $_clearField(26);

  @$pb.TagNumber(27)
  Image get avatarBorder => $_getN(23);
  @$pb.TagNumber(27)
  set avatarBorder(Image value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasAvatarBorder() => $_has(23);
  @$pb.TagNumber(27)
  void clearAvatarBorder() => $_clearField(27);
  @$pb.TagNumber(27)
  Image ensureAvatarBorder() => $_ensure(23);

  @$pb.TagNumber(28)
  Image get medal => $_getN(24);
  @$pb.TagNumber(28)
  set medal(Image value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasMedal() => $_has(24);
  @$pb.TagNumber(28)
  void clearMedal() => $_clearField(28);
  @$pb.TagNumber(28)
  Image ensureMedal() => $_ensure(24);

  @$pb.TagNumber(29)
  $pb.PbList<Image> get realTimeIconsList => $_getList(25);

  @$pb.TagNumber(38)
  $core.String get displayId => $_getSZ(26);
  @$pb.TagNumber(38)
  set displayId($core.String value) => $_setString(26, value);
  @$pb.TagNumber(38)
  $core.bool hasDisplayId() => $_has(26);
  @$pb.TagNumber(38)
  void clearDisplayId() => $_clearField(38);

  @$pb.TagNumber(46)
  $core.String get secUid => $_getSZ(27);
  @$pb.TagNumber(46)
  set secUid($core.String value) => $_setString(27, value);
  @$pb.TagNumber(46)
  $core.bool hasSecUid() => $_has(27);
  @$pb.TagNumber(46)
  void clearSecUid() => $_clearField(46);

  @$pb.TagNumber(1022)
  $fixnum.Int64 get fanTicketCount => $_getI64(28);
  @$pb.TagNumber(1022)
  set fanTicketCount($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(1022)
  $core.bool hasFanTicketCount() => $_has(28);
  @$pb.TagNumber(1022)
  void clearFanTicketCount() => $_clearField(1022);

  @$pb.TagNumber(1028)
  $core.String get idStr => $_getSZ(29);
  @$pb.TagNumber(1028)
  set idStr($core.String value) => $_setString(29, value);
  @$pb.TagNumber(1028)
  $core.bool hasIdStr() => $_has(29);
  @$pb.TagNumber(1028)
  void clearIdStr() => $_clearField(1028);

  @$pb.TagNumber(1045)
  $core.int get ageRange => $_getIZ(30);
  @$pb.TagNumber(1045)
  set ageRange($core.int value) => $_setUnsignedInt32(30, value);
  @$pb.TagNumber(1045)
  $core.bool hasAgeRange() => $_has(30);
  @$pb.TagNumber(1045)
  void clearAgeRange() => $_clearField(1045);
}

class FollowInfo extends $pb.GeneratedMessage {
  factory FollowInfo({
    $fixnum.Int64? followingCount,
    $fixnum.Int64? followerCount,
    $fixnum.Int64? followStatus,
    $fixnum.Int64? pushStatus,
    $core.String? remarkName,
    $core.String? followerCountStr,
    $core.String? followingCountStr,
  }) {
    final result = create();
    if (followingCount != null) result.followingCount = followingCount;
    if (followerCount != null) result.followerCount = followerCount;
    if (followStatus != null) result.followStatus = followStatus;
    if (pushStatus != null) result.pushStatus = pushStatus;
    if (remarkName != null) result.remarkName = remarkName;
    if (followerCountStr != null) result.followerCountStr = followerCountStr;
    if (followingCountStr != null) result.followingCountStr = followingCountStr;
    return result;
  }

  FollowInfo._();

  factory FollowInfo.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory FollowInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'FollowInfo',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(
          1,
          _omitFieldNames ? '' : 'followingCount',
          $pb.PbFieldType.OU6,
          protoName: 'followingCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'followerCount',
          $pb.PbFieldType.OU6,
          protoName: 'followerCount',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'followStatus',
          $pb.PbFieldType.OU6,
          protoName: 'followStatus',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          4,
          _omitFieldNames ? '' : 'pushStatus',
          $pb.PbFieldType.OU6,
          protoName: 'pushStatus',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(5, _omitFieldNames ? '' : 'remarkName', protoName: 'remarkName')
        ..aOS(6, _omitFieldNames ? '' : 'followerCountStr', protoName: 'followerCountStr')
        ..aOS(7, _omitFieldNames ? '' : 'followingCountStr', protoName: 'followingCountStr')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FollowInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FollowInfo copyWith(void Function(FollowInfo) updates) =>
      super.copyWith((message) => updates(message as FollowInfo)) as FollowInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FollowInfo create() => FollowInfo._();
  @$core.override
  FollowInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FollowInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FollowInfo>(create);
  static FollowInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get followingCount => $_getI64(0);
  @$pb.TagNumber(1)
  set followingCount($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFollowingCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearFollowingCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get followerCount => $_getI64(1);
  @$pb.TagNumber(2)
  set followerCount($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFollowerCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearFollowerCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get followStatus => $_getI64(2);
  @$pb.TagNumber(3)
  set followStatus($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFollowStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearFollowStatus() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get pushStatus => $_getI64(3);
  @$pb.TagNumber(4)
  set pushStatus($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPushStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearPushStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get remarkName => $_getSZ(4);
  @$pb.TagNumber(5)
  set remarkName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRemarkName() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemarkName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get followerCountStr => $_getSZ(5);
  @$pb.TagNumber(6)
  set followerCountStr($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFollowerCountStr() => $_has(5);
  @$pb.TagNumber(6)
  void clearFollowerCountStr() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get followingCountStr => $_getSZ(6);
  @$pb.TagNumber(7)
  set followingCountStr($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFollowingCountStr() => $_has(6);
  @$pb.TagNumber(7)
  void clearFollowingCountStr() => $_clearField(7);
}

class Image extends $pb.GeneratedMessage {
  factory Image({
    $core.Iterable<$core.String>? urlListList,
    $core.String? uri,
    $fixnum.Int64? height,
    $fixnum.Int64? width,
    $core.String? avgColor,
    $core.int? imageType,
    $core.String? openWebUrl,
    ImageContent? content,
    $core.bool? isAnimated,
    NinePatchSetting? flexSettingList,
    NinePatchSetting? textSettingList,
  }) {
    final result = create();
    if (urlListList != null) result.urlListList.addAll(urlListList);
    if (uri != null) result.uri = uri;
    if (height != null) result.height = height;
    if (width != null) result.width = width;
    if (avgColor != null) result.avgColor = avgColor;
    if (imageType != null) result.imageType = imageType;
    if (openWebUrl != null) result.openWebUrl = openWebUrl;
    if (content != null) result.content = content;
    if (isAnimated != null) result.isAnimated = isAnimated;
    if (flexSettingList != null) result.flexSettingList = flexSettingList;
    if (textSettingList != null) result.textSettingList = textSettingList;
    return result;
  }

  Image._();

  factory Image.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory Image.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Image',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..pPS(1, _omitFieldNames ? '' : 'urlListList', protoName: 'urlListList')
        ..aOS(2, _omitFieldNames ? '' : 'uri')
        ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'height', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'width', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOS(5, _omitFieldNames ? '' : 'avgColor', protoName: 'avgColor')
        ..aI(6, _omitFieldNames ? '' : 'imageType', protoName: 'imageType', fieldType: $pb.PbFieldType.OU3)
        ..aOS(7, _omitFieldNames ? '' : 'openWebUrl', protoName: 'openWebUrl')
        ..aOM<ImageContent>(8, _omitFieldNames ? '' : 'content', subBuilder: ImageContent.create)
        ..aOB(9, _omitFieldNames ? '' : 'isAnimated', protoName: 'isAnimated')
        ..aOM<NinePatchSetting>(
          10,
          _omitFieldNames ? '' : 'FlexSettingList',
          protoName: 'FlexSettingList',
          subBuilder: NinePatchSetting.create,
        )
        ..aOM<NinePatchSetting>(
          11,
          _omitFieldNames ? '' : 'TextSettingList',
          protoName: 'TextSettingList',
          subBuilder: NinePatchSetting.create,
        )
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Image clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Image copyWith(void Function(Image) updates) => super.copyWith((message) => updates(message as Image)) as Image;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Image create() => Image._();
  @$core.override
  Image createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Image getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Image>(create);
  static Image? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get urlListList => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get uri => $_getSZ(1);
  @$pb.TagNumber(2)
  set uri($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUri() => $_has(1);
  @$pb.TagNumber(2)
  void clearUri() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get height => $_getI64(2);
  @$pb.TagNumber(3)
  set height($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get width => $_getI64(3);
  @$pb.TagNumber(4)
  set width($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearWidth() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get avgColor => $_getSZ(4);
  @$pb.TagNumber(5)
  set avgColor($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvgColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvgColor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get imageType => $_getIZ(5);
  @$pb.TagNumber(6)
  set imageType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImageType() => $_has(5);
  @$pb.TagNumber(6)
  void clearImageType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get openWebUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set openWebUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOpenWebUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearOpenWebUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  ImageContent get content => $_getN(7);
  @$pb.TagNumber(8)
  set content(ImageContent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasContent() => $_has(7);
  @$pb.TagNumber(8)
  void clearContent() => $_clearField(8);
  @$pb.TagNumber(8)
  ImageContent ensureContent() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.bool get isAnimated => $_getBF(8);
  @$pb.TagNumber(9)
  set isAnimated($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsAnimated() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsAnimated() => $_clearField(9);

  @$pb.TagNumber(10)
  NinePatchSetting get flexSettingList => $_getN(9);
  @$pb.TagNumber(10)
  set flexSettingList(NinePatchSetting value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasFlexSettingList() => $_has(9);
  @$pb.TagNumber(10)
  void clearFlexSettingList() => $_clearField(10);
  @$pb.TagNumber(10)
  NinePatchSetting ensureFlexSettingList() => $_ensure(9);

  @$pb.TagNumber(11)
  NinePatchSetting get textSettingList => $_getN(10);
  @$pb.TagNumber(11)
  set textSettingList(NinePatchSetting value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasTextSettingList() => $_has(10);
  @$pb.TagNumber(11)
  void clearTextSettingList() => $_clearField(11);
  @$pb.TagNumber(11)
  NinePatchSetting ensureTextSettingList() => $_ensure(10);
}

class NinePatchSetting extends $pb.GeneratedMessage {
  factory NinePatchSetting({$core.Iterable<$core.String>? settingListList}) {
    final result = create();
    if (settingListList != null) result.settingListList.addAll(settingListList);
    return result;
  }

  NinePatchSetting._();

  factory NinePatchSetting.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory NinePatchSetting.fromJson(
    $core.String json, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'NinePatchSetting',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..pPS(1, _omitFieldNames ? '' : 'settingListList', protoName: 'settingListList')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NinePatchSetting clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NinePatchSetting copyWith(void Function(NinePatchSetting) updates) =>
      super.copyWith((message) => updates(message as NinePatchSetting)) as NinePatchSetting;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NinePatchSetting create() => NinePatchSetting._();
  @$core.override
  NinePatchSetting createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NinePatchSetting getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NinePatchSetting>(create);
  static NinePatchSetting? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get settingListList => $_getList(0);
}

class ImageContent extends $pb.GeneratedMessage {
  factory ImageContent({
    $core.String? name,
    $core.String? fontColor,
    $fixnum.Int64? level,
    $core.String? alternativeText,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (fontColor != null) result.fontColor = fontColor;
    if (level != null) result.level = level;
    if (alternativeText != null) result.alternativeText = alternativeText;
    return result;
  }

  ImageContent._();

  factory ImageContent.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory ImageContent.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'ImageContent',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'name')
        ..aOS(2, _omitFieldNames ? '' : 'fontColor', protoName: 'fontColor')
        ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'level', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOS(4, _omitFieldNames ? '' : 'alternativeText', protoName: 'alternativeText')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageContent copyWith(void Function(ImageContent) updates) =>
      super.copyWith((message) => updates(message as ImageContent)) as ImageContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImageContent create() => ImageContent._();
  @$core.override
  ImageContent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImageContent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageContent>(create);
  static ImageContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fontColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set fontColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFontColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearFontColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get level => $_getI64(2);
  @$pb.TagNumber(3)
  set level($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLevel() => $_has(2);
  @$pb.TagNumber(3)
  void clearLevel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get alternativeText => $_getSZ(3);
  @$pb.TagNumber(4)
  set alternativeText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAlternativeText() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlternativeText() => $_clearField(4);
}

class PushFrame extends $pb.GeneratedMessage {
  factory PushFrame({
    $fixnum.Int64? seqId,
    $fixnum.Int64? logId,
    $fixnum.Int64? service,
    $fixnum.Int64? method,
    $core.Iterable<HeadersList>? headersList,
    $core.String? payloadEncoding,
    $core.String? payloadType,
    $core.List<$core.int>? payload,
  }) {
    final result = create();
    if (seqId != null) result.seqId = seqId;
    if (logId != null) result.logId = logId;
    if (service != null) result.service = service;
    if (method != null) result.method = method;
    if (headersList != null) result.headersList.addAll(headersList);
    if (payloadEncoding != null) result.payloadEncoding = payloadEncoding;
    if (payloadType != null) result.payloadType = payloadType;
    if (payload != null) result.payload = payload;
    return result;
  }

  PushFrame._();

  factory PushFrame.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory PushFrame.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'PushFrame',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(
          1,
          _omitFieldNames ? '' : 'seqId',
          $pb.PbFieldType.OU6,
          protoName: 'seqId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(
          2,
          _omitFieldNames ? '' : 'logId',
          $pb.PbFieldType.OU6,
          protoName: 'logId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'service', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'method', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..pPM<HeadersList>(
          5,
          _omitFieldNames ? '' : 'headersList',
          protoName: 'headersList',
          subBuilder: HeadersList.create,
        )
        ..aOS(6, _omitFieldNames ? '' : 'payloadEncoding', protoName: 'payloadEncoding')
        ..aOS(7, _omitFieldNames ? '' : 'payloadType', protoName: 'payloadType')
        ..a<$core.List<$core.int>>(8, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushFrame copyWith(void Function(PushFrame) updates) =>
      super.copyWith((message) => updates(message as PushFrame)) as PushFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PushFrame create() => PushFrame._();
  @$core.override
  PushFrame createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PushFrame getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PushFrame>(create);
  static PushFrame? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seqId => $_getI64(0);
  @$pb.TagNumber(1)
  set seqId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeqId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeqId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get logId => $_getI64(1);
  @$pb.TagNumber(2)
  set logId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLogId() => $_has(1);
  @$pb.TagNumber(2)
  void clearLogId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get service => $_getI64(2);
  @$pb.TagNumber(3)
  set service($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasService() => $_has(2);
  @$pb.TagNumber(3)
  void clearService() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get method => $_getI64(3);
  @$pb.TagNumber(4)
  set method($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMethod() => $_has(3);
  @$pb.TagNumber(4)
  void clearMethod() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<HeadersList> get headersList => $_getList(4);

  @$pb.TagNumber(6)
  $core.String get payloadEncoding => $_getSZ(5);
  @$pb.TagNumber(6)
  set payloadEncoding($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPayloadEncoding() => $_has(5);
  @$pb.TagNumber(6)
  void clearPayloadEncoding() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get payloadType => $_getSZ(6);
  @$pb.TagNumber(7)
  set payloadType($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPayloadType() => $_has(6);
  @$pb.TagNumber(7)
  void clearPayloadType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get payload => $_getN(7);
  @$pb.TagNumber(8)
  set payload($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPayload() => $_has(7);
  @$pb.TagNumber(8)
  void clearPayload() => $_clearField(8);
}

class kk extends $pb.GeneratedMessage {
  factory kk({$core.int? k}) {
    final result = create();
    if (k != null) result.k = k;
    return result;
  }

  kk._();

  factory kk.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory kk.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'kk',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aI(14, _omitFieldNames ? '' : 'k', fieldType: $pb.PbFieldType.OU3)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  kk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  kk copyWith(void Function(kk) updates) => super.copyWith((message) => updates(message as kk)) as kk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static kk create() => kk._();
  @$core.override
  kk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static kk getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<kk>(create);
  static kk? _defaultInstance;

  @$pb.TagNumber(14)
  $core.int get k => $_getIZ(0);
  @$pb.TagNumber(14)
  set k($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(14)
  $core.bool hasK() => $_has(0);
  @$pb.TagNumber(14)
  void clearK() => $_clearField(14);
}

class SendMessageBody extends $pb.GeneratedMessage {
  factory SendMessageBody({
    $core.String? conversationId,
    $core.int? conversationType,
    $fixnum.Int64? conversationShortId,
    $core.String? content,
    $core.Iterable<ExtList>? ext,
    $core.int? messageType,
    $core.String? ticket,
    $core.String? clientMessageId,
  }) {
    final result = create();
    if (conversationId != null) result.conversationId = conversationId;
    if (conversationType != null) result.conversationType = conversationType;
    if (conversationShortId != null) result.conversationShortId = conversationShortId;
    if (content != null) result.content = content;
    if (ext != null) result.ext.addAll(ext);
    if (messageType != null) result.messageType = messageType;
    if (ticket != null) result.ticket = ticket;
    if (clientMessageId != null) result.clientMessageId = clientMessageId;
    return result;
  }

  SendMessageBody._();

  factory SendMessageBody.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory SendMessageBody.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'SendMessageBody',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'conversationId', protoName: 'conversationId')
        ..aI(
          2,
          _omitFieldNames ? '' : 'conversationType',
          protoName: 'conversationType',
          fieldType: $pb.PbFieldType.OU3,
        )
        ..a<$fixnum.Int64>(
          3,
          _omitFieldNames ? '' : 'conversationShortId',
          $pb.PbFieldType.OU6,
          protoName: 'conversationShortId',
          defaultOrMaker: $fixnum.Int64.ZERO,
        )
        ..aOS(4, _omitFieldNames ? '' : 'content')
        ..pPM<ExtList>(5, _omitFieldNames ? '' : 'ext', subBuilder: ExtList.create)
        ..aI(6, _omitFieldNames ? '' : 'messageType', protoName: 'messageType', fieldType: $pb.PbFieldType.OU3)
        ..aOS(7, _omitFieldNames ? '' : 'ticket')
        ..aOS(8, _omitFieldNames ? '' : 'clientMessageId', protoName: 'clientMessageId')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessageBody clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessageBody copyWith(void Function(SendMessageBody) updates) =>
      super.copyWith((message) => updates(message as SendMessageBody)) as SendMessageBody;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendMessageBody create() => SendMessageBody._();
  @$core.override
  SendMessageBody createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendMessageBody getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendMessageBody>(create);
  static SendMessageBody? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get conversationType => $_getIZ(1);
  @$pb.TagNumber(2)
  set conversationType($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationType() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationType() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get conversationShortId => $_getI64(2);
  @$pb.TagNumber(3)
  set conversationShortId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationShortId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationShortId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<ExtList> get ext => $_getList(4);

  @$pb.TagNumber(6)
  $core.int get messageType => $_getIZ(5);
  @$pb.TagNumber(6)
  set messageType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMessageType() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get ticket => $_getSZ(6);
  @$pb.TagNumber(7)
  set ticket($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTicket() => $_has(6);
  @$pb.TagNumber(7)
  void clearTicket() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get clientMessageId => $_getSZ(7);
  @$pb.TagNumber(8)
  set clientMessageId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasClientMessageId() => $_has(7);
  @$pb.TagNumber(8)
  void clearClientMessageId() => $_clearField(8);
}

class ExtList extends $pb.GeneratedMessage {
  factory ExtList({$core.String? key, $core.String? value}) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  ExtList._();

  factory ExtList.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory ExtList.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'ExtList',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'key')
        ..aOS(2, _omitFieldNames ? '' : 'value')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtList copyWith(void Function(ExtList) updates) =>
      super.copyWith((message) => updates(message as ExtList)) as ExtList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExtList create() => ExtList._();
  @$core.override
  ExtList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExtList getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExtList>(create);
  static ExtList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get value => $_getSZ(1);
  @$pb.TagNumber(2)
  set value($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

class Rsp_F extends $pb.GeneratedMessage {
  factory Rsp_F({$fixnum.Int64? q1, $fixnum.Int64? q3, $core.String? q4, $fixnum.Int64? q5}) {
    final result = create();
    if (q1 != null) result.q1 = q1;
    if (q3 != null) result.q3 = q3;
    if (q4 != null) result.q4 = q4;
    if (q5 != null) result.q5 = q5;
    return result;
  }

  Rsp_F._();

  factory Rsp_F.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory Rsp_F.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Rsp.F',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'q1', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'q3', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..aOS(4, _omitFieldNames ? '' : 'q4')
        ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'q5', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rsp_F clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rsp_F copyWith(void Function(Rsp_F) updates) => super.copyWith((message) => updates(message as Rsp_F)) as Rsp_F;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Rsp_F create() => Rsp_F._();
  @$core.override
  Rsp_F createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Rsp_F getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Rsp_F>(create);
  static Rsp_F? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get q1 => $_getI64(0);
  @$pb.TagNumber(1)
  set q1($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQ1() => $_has(0);
  @$pb.TagNumber(1)
  void clearQ1() => $_clearField(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get q3 => $_getI64(1);
  @$pb.TagNumber(3)
  set q3($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(3)
  $core.bool hasQ3() => $_has(1);
  @$pb.TagNumber(3)
  void clearQ3() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get q4 => $_getSZ(2);
  @$pb.TagNumber(4)
  set q4($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasQ4() => $_has(2);
  @$pb.TagNumber(4)
  void clearQ4() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get q5 => $_getI64(3);
  @$pb.TagNumber(5)
  set q5($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(5)
  $core.bool hasQ5() => $_has(3);
  @$pb.TagNumber(5)
  void clearQ5() => $_clearField(5);
}

class Rsp extends $pb.GeneratedMessage {
  factory Rsp({
    $core.int? a,
    $core.int? b,
    $core.int? c,
    $core.String? d,
    $core.int? e,
    Rsp_F? f,
    $core.String? g,
    $fixnum.Int64? h,
    $fixnum.Int64? i,
    $fixnum.Int64? j,
  }) {
    final result = create();
    if (a != null) result.a = a;
    if (b != null) result.b = b;
    if (c != null) result.c = c;
    if (d != null) result.d = d;
    if (e != null) result.e = e;
    if (f != null) result.f = f;
    if (g != null) result.g = g;
    if (h != null) result.h = h;
    if (i != null) result.i = i;
    if (j != null) result.j = j;
    return result;
  }

  Rsp._();

  factory Rsp.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Rsp.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'Rsp',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aI(1, _omitFieldNames ? '' : 'a')
        ..aI(2, _omitFieldNames ? '' : 'b')
        ..aI(3, _omitFieldNames ? '' : 'c')
        ..aOS(4, _omitFieldNames ? '' : 'd')
        ..aI(5, _omitFieldNames ? '' : 'e')
        ..aOM<Rsp_F>(6, _omitFieldNames ? '' : 'f', subBuilder: Rsp_F.create)
        ..aOS(7, _omitFieldNames ? '' : 'g')
        ..a<$fixnum.Int64>(10, _omitFieldNames ? '' : 'h', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(11, _omitFieldNames ? '' : 'i', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..a<$fixnum.Int64>(13, _omitFieldNames ? '' : 'j', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rsp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rsp copyWith(void Function(Rsp) updates) => super.copyWith((message) => updates(message as Rsp)) as Rsp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Rsp create() => Rsp._();
  @$core.override
  Rsp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Rsp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Rsp>(create);
  static Rsp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get a => $_getIZ(0);
  @$pb.TagNumber(1)
  set a($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasA() => $_has(0);
  @$pb.TagNumber(1)
  void clearA() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get b => $_getIZ(1);
  @$pb.TagNumber(2)
  set b($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasB() => $_has(1);
  @$pb.TagNumber(2)
  void clearB() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get c => $_getIZ(2);
  @$pb.TagNumber(3)
  set c($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasC() => $_has(2);
  @$pb.TagNumber(3)
  void clearC() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get d => $_getSZ(3);
  @$pb.TagNumber(4)
  set d($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasD() => $_has(3);
  @$pb.TagNumber(4)
  void clearD() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get e => $_getIZ(4);
  @$pb.TagNumber(5)
  set e($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasE() => $_has(4);
  @$pb.TagNumber(5)
  void clearE() => $_clearField(5);

  @$pb.TagNumber(6)
  Rsp_F get f => $_getN(5);
  @$pb.TagNumber(6)
  set f(Rsp_F value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasF() => $_has(5);
  @$pb.TagNumber(6)
  void clearF() => $_clearField(6);
  @$pb.TagNumber(6)
  Rsp_F ensureF() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get g => $_getSZ(6);
  @$pb.TagNumber(7)
  set g($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasG() => $_has(6);
  @$pb.TagNumber(7)
  void clearG() => $_clearField(7);

  @$pb.TagNumber(10)
  $fixnum.Int64 get h => $_getI64(7);
  @$pb.TagNumber(10)
  set h($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(10)
  $core.bool hasH() => $_has(7);
  @$pb.TagNumber(10)
  void clearH() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get i => $_getI64(8);
  @$pb.TagNumber(11)
  set i($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(11)
  $core.bool hasI() => $_has(8);
  @$pb.TagNumber(11)
  void clearI() => $_clearField(11);

  @$pb.TagNumber(13)
  $fixnum.Int64 get j => $_getI64(9);
  @$pb.TagNumber(13)
  set j($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(13)
  $core.bool hasJ() => $_has(9);
  @$pb.TagNumber(13)
  void clearJ() => $_clearField(13);
}

class PreMessage extends $pb.GeneratedMessage {
  factory PreMessage({
    $core.int? cmd,
    $core.int? sequenceId,
    $core.String? sdkVersion,
    $core.String? token,
    $core.int? refer,
    $core.int? inboxType,
    $core.String? buildNumber,
    SendMessageBody? sendMessageBody,
    $core.String? aa,
    $core.String? devicePlatform,
    $core.Iterable<HeadersList>? headers,
    $core.int? authType,
    $core.String? biz,
    $core.String? access,
  }) {
    final result = create();
    if (cmd != null) result.cmd = cmd;
    if (sequenceId != null) result.sequenceId = sequenceId;
    if (sdkVersion != null) result.sdkVersion = sdkVersion;
    if (token != null) result.token = token;
    if (refer != null) result.refer = refer;
    if (inboxType != null) result.inboxType = inboxType;
    if (buildNumber != null) result.buildNumber = buildNumber;
    if (sendMessageBody != null) result.sendMessageBody = sendMessageBody;
    if (aa != null) result.aa = aa;
    if (devicePlatform != null) result.devicePlatform = devicePlatform;
    if (headers != null) result.headers.addAll(headers);
    if (authType != null) result.authType = authType;
    if (biz != null) result.biz = biz;
    if (access != null) result.access = access;
    return result;
  }

  PreMessage._();

  factory PreMessage.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory PreMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'PreMessage',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aI(1, _omitFieldNames ? '' : 'cmd', fieldType: $pb.PbFieldType.OU3)
        ..aI(2, _omitFieldNames ? '' : 'sequenceId', protoName: 'sequenceId', fieldType: $pb.PbFieldType.OU3)
        ..aOS(3, _omitFieldNames ? '' : 'sdkVersion', protoName: 'sdkVersion')
        ..aOS(4, _omitFieldNames ? '' : 'token')
        ..aI(5, _omitFieldNames ? '' : 'refer', fieldType: $pb.PbFieldType.OU3)
        ..aI(6, _omitFieldNames ? '' : 'inboxType', protoName: 'inboxType', fieldType: $pb.PbFieldType.OU3)
        ..aOS(7, _omitFieldNames ? '' : 'buildNumber', protoName: 'buildNumber')
        ..aOM<SendMessageBody>(
          8,
          _omitFieldNames ? '' : 'sendMessageBody',
          protoName: 'sendMessageBody',
          subBuilder: SendMessageBody.create,
        )
        ..aOS(9, _omitFieldNames ? '' : 'aa')
        ..aOS(11, _omitFieldNames ? '' : 'devicePlatform', protoName: 'devicePlatform')
        ..pPM<HeadersList>(15, _omitFieldNames ? '' : 'headers', subBuilder: HeadersList.create)
        ..aI(18, _omitFieldNames ? '' : 'authType', protoName: 'authType', fieldType: $pb.PbFieldType.OU3)
        ..aOS(21, _omitFieldNames ? '' : 'biz')
        ..aOS(22, _omitFieldNames ? '' : 'access')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreMessage copyWith(void Function(PreMessage) updates) =>
      super.copyWith((message) => updates(message as PreMessage)) as PreMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreMessage create() => PreMessage._();
  @$core.override
  PreMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PreMessage>(create);
  static PreMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get cmd => $_getIZ(0);
  @$pb.TagNumber(1)
  set cmd($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmd() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmd() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sequenceId => $_getIZ(1);
  @$pb.TagNumber(2)
  set sequenceId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSequenceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSequenceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sdkVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set sdkVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSdkVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearSdkVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get token => $_getSZ(3);
  @$pb.TagNumber(4)
  set token($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearToken() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get refer => $_getIZ(4);
  @$pb.TagNumber(5)
  set refer($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRefer() => $_has(4);
  @$pb.TagNumber(5)
  void clearRefer() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get inboxType => $_getIZ(5);
  @$pb.TagNumber(6)
  set inboxType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInboxType() => $_has(5);
  @$pb.TagNumber(6)
  void clearInboxType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get buildNumber => $_getSZ(6);
  @$pb.TagNumber(7)
  set buildNumber($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBuildNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearBuildNumber() => $_clearField(7);

  @$pb.TagNumber(8)
  SendMessageBody get sendMessageBody => $_getN(7);
  @$pb.TagNumber(8)
  set sendMessageBody(SendMessageBody value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSendMessageBody() => $_has(7);
  @$pb.TagNumber(8)
  void clearSendMessageBody() => $_clearField(8);
  @$pb.TagNumber(8)
  SendMessageBody ensureSendMessageBody() => $_ensure(7);

  /// 字段名待定
  @$pb.TagNumber(9)
  $core.String get aa => $_getSZ(8);
  @$pb.TagNumber(9)
  set aa($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAa() => $_has(8);
  @$pb.TagNumber(9)
  void clearAa() => $_clearField(9);

  @$pb.TagNumber(11)
  $core.String get devicePlatform => $_getSZ(9);
  @$pb.TagNumber(11)
  set devicePlatform($core.String value) => $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasDevicePlatform() => $_has(9);
  @$pb.TagNumber(11)
  void clearDevicePlatform() => $_clearField(11);

  @$pb.TagNumber(15)
  $pb.PbList<HeadersList> get headers => $_getList(10);

  @$pb.TagNumber(18)
  $core.int get authType => $_getIZ(11);
  @$pb.TagNumber(18)
  set authType($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(18)
  $core.bool hasAuthType() => $_has(11);
  @$pb.TagNumber(18)
  void clearAuthType() => $_clearField(18);

  @$pb.TagNumber(21)
  $core.String get biz => $_getSZ(12);
  @$pb.TagNumber(21)
  set biz($core.String value) => $_setString(12, value);
  @$pb.TagNumber(21)
  $core.bool hasBiz() => $_has(12);
  @$pb.TagNumber(21)
  void clearBiz() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get access => $_getSZ(13);
  @$pb.TagNumber(22)
  set access($core.String value) => $_setString(13, value);
  @$pb.TagNumber(22)
  $core.bool hasAccess() => $_has(13);
  @$pb.TagNumber(22)
  void clearAccess() => $_clearField(22);
}

class HeadersList extends $pb.GeneratedMessage {
  factory HeadersList({$core.String? key, $core.String? value}) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  HeadersList._();

  factory HeadersList.fromBuffer(
    $core.List<$core.int> data, [
    $pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(data, registry);
  factory HeadersList.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          _omitMessageNames ? '' : 'HeadersList',
          package: const $pb.PackageName(_omitMessageNames ? '' : 'douyin'),
          createEmptyInstance: create,
        )
        ..aOS(1, _omitFieldNames ? '' : 'key')
        ..aOS(2, _omitFieldNames ? '' : 'value')
        ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeadersList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeadersList copyWith(void Function(HeadersList) updates) =>
      super.copyWith((message) => updates(message as HeadersList)) as HeadersList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeadersList create() => HeadersList._();
  @$core.override
  HeadersList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeadersList getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HeadersList>(create);
  static HeadersList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get value => $_getSZ(1);
  @$pb.TagNumber(2)
  set value($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
