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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'ks.pbenum.dart';

export 'ks.pbenum.dart';

class CSWebEnterRoom_Payload extends $pb.GeneratedMessage {
  factory CSWebEnterRoom_Payload({
    $core.String? token,
    $core.String? liveStreamId,
    $core.int? reconnectCount,
    $core.int? lastErrorCode,
    $core.String? expTag,
    $core.String? attach,
    $core.String? pageId,
  }) {
    final $result = create();
    if (token != null) {
      $result.token = token;
    }
    if (liveStreamId != null) {
      $result.liveStreamId = liveStreamId;
    }
    if (reconnectCount != null) {
      $result.reconnectCount = reconnectCount;
    }
    if (lastErrorCode != null) {
      $result.lastErrorCode = lastErrorCode;
    }
    if (expTag != null) {
      $result.expTag = expTag;
    }
    if (attach != null) {
      $result.attach = attach;
    }
    if (pageId != null) {
      $result.pageId = pageId;
    }
    return $result;
  }
  CSWebEnterRoom_Payload._() : super();
  factory CSWebEnterRoom_Payload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CSWebEnterRoom_Payload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CSWebEnterRoom.Payload', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'liveStreamId', protoName: 'liveStreamId')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'reconnectCount', $pb.PbFieldType.OU3, protoName: 'reconnectCount')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'lastErrorCode', $pb.PbFieldType.OU3, protoName: 'lastErrorCode')
    ..aOS(5, _omitFieldNames ? '' : 'expTag', protoName: 'expTag')
    ..aOS(6, _omitFieldNames ? '' : 'attach')
    ..aOS(7, _omitFieldNames ? '' : 'pageId', protoName: 'pageId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CSWebEnterRoom_Payload clone() => CSWebEnterRoom_Payload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CSWebEnterRoom_Payload copyWith(void Function(CSWebEnterRoom_Payload) updates) => super.copyWith((message) => updates(message as CSWebEnterRoom_Payload)) as CSWebEnterRoom_Payload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CSWebEnterRoom_Payload create() => CSWebEnterRoom_Payload._();
  CSWebEnterRoom_Payload createEmptyInstance() => create();
  static $pb.PbList<CSWebEnterRoom_Payload> createRepeated() => $pb.PbList<CSWebEnterRoom_Payload>();
  @$core.pragma('dart2js:noInline')
  static CSWebEnterRoom_Payload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CSWebEnterRoom_Payload>(create);
  static CSWebEnterRoom_Payload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get liveStreamId => $_getSZ(1);
  @$pb.TagNumber(2)
  set liveStreamId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLiveStreamId() => $_has(1);
  @$pb.TagNumber(2)
  void clearLiveStreamId() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get reconnectCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set reconnectCount($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasReconnectCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearReconnectCount() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get lastErrorCode => $_getIZ(3);
  @$pb.TagNumber(4)
  set lastErrorCode($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLastErrorCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastErrorCode() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get expTag => $_getSZ(4);
  @$pb.TagNumber(5)
  set expTag($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasExpTag() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpTag() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get attach => $_getSZ(5);
  @$pb.TagNumber(6)
  set attach($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasAttach() => $_has(5);
  @$pb.TagNumber(6)
  void clearAttach() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get pageId => $_getSZ(6);
  @$pb.TagNumber(7)
  set pageId($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasPageId() => $_has(6);
  @$pb.TagNumber(7)
  void clearPageId() => clearField(7);
}

/// 进入房间
class CSWebEnterRoom extends $pb.GeneratedMessage {
  factory CSWebEnterRoom({
    $fixnum.Int64? payloadType,
    CSWebEnterRoom_Payload? payload,
  }) {
    final $result = create();
    if (payloadType != null) {
      $result.payloadType = payloadType;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    return $result;
  }
  CSWebEnterRoom._() : super();
  factory CSWebEnterRoom.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CSWebEnterRoom.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CSWebEnterRoom', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'payloadType', protoName: 'payloadType')
    ..aOM<CSWebEnterRoom_Payload>(3, _omitFieldNames ? '' : 'payload', subBuilder: CSWebEnterRoom_Payload.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CSWebEnterRoom clone() => CSWebEnterRoom()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CSWebEnterRoom copyWith(void Function(CSWebEnterRoom) updates) => super.copyWith((message) => updates(message as CSWebEnterRoom)) as CSWebEnterRoom;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CSWebEnterRoom create() => CSWebEnterRoom._();
  CSWebEnterRoom createEmptyInstance() => create();
  static $pb.PbList<CSWebEnterRoom> createRepeated() => $pb.PbList<CSWebEnterRoom>();
  @$core.pragma('dart2js:noInline')
  static CSWebEnterRoom getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CSWebEnterRoom>(create);
  static CSWebEnterRoom? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get payloadType => $_getI64(0);
  @$pb.TagNumber(1)
  set payloadType($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPayloadType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayloadType() => clearField(1);

  @$pb.TagNumber(3)
  CSWebEnterRoom_Payload get payload => $_getN(1);
  @$pb.TagNumber(3)
  set payload(CSWebEnterRoom_Payload v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(3)
  void clearPayload() => clearField(3);
  @$pb.TagNumber(3)
  CSWebEnterRoom_Payload ensurePayload() => $_ensure(1);
}

/// 进入房间后应答包
class SCWebEnterRoomAck extends $pb.GeneratedMessage {
  factory SCWebEnterRoomAck({
    $fixnum.Int64? minReconnectMs,
    $fixnum.Int64? maxReconnectMs,
    $fixnum.Int64? heartbeatIntervalMs,
  }) {
    final $result = create();
    if (minReconnectMs != null) {
      $result.minReconnectMs = minReconnectMs;
    }
    if (maxReconnectMs != null) {
      $result.maxReconnectMs = maxReconnectMs;
    }
    if (heartbeatIntervalMs != null) {
      $result.heartbeatIntervalMs = heartbeatIntervalMs;
    }
    return $result;
  }
  SCWebEnterRoomAck._() : super();
  factory SCWebEnterRoomAck.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SCWebEnterRoomAck.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SCWebEnterRoomAck', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'minReconnectMs', $pb.PbFieldType.OU6, protoName: 'minReconnectMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'maxReconnectMs', $pb.PbFieldType.OU6, protoName: 'maxReconnectMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'heartbeatIntervalMs', $pb.PbFieldType.OU6, protoName: 'heartbeatIntervalMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SCWebEnterRoomAck clone() => SCWebEnterRoomAck()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SCWebEnterRoomAck copyWith(void Function(SCWebEnterRoomAck) updates) => super.copyWith((message) => updates(message as SCWebEnterRoomAck)) as SCWebEnterRoomAck;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SCWebEnterRoomAck create() => SCWebEnterRoomAck._();
  SCWebEnterRoomAck createEmptyInstance() => create();
  static $pb.PbList<SCWebEnterRoomAck> createRepeated() => $pb.PbList<SCWebEnterRoomAck>();
  @$core.pragma('dart2js:noInline')
  static SCWebEnterRoomAck getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SCWebEnterRoomAck>(create);
  static SCWebEnterRoomAck? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get minReconnectMs => $_getI64(0);
  @$pb.TagNumber(1)
  set minReconnectMs($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMinReconnectMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearMinReconnectMs() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get maxReconnectMs => $_getI64(1);
  @$pb.TagNumber(2)
  set maxReconnectMs($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMaxReconnectMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxReconnectMs() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get heartbeatIntervalMs => $_getI64(2);
  @$pb.TagNumber(3)
  set heartbeatIntervalMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasHeartbeatIntervalMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeartbeatIntervalMs() => clearField(3);
}

/// 用户信息包
class SimpleUserInfo extends $pb.GeneratedMessage {
  factory SimpleUserInfo({
    $core.String? principalId,
    $core.String? userName,
    $core.String? headUrl,
  }) {
    final $result = create();
    if (principalId != null) {
      $result.principalId = principalId;
    }
    if (userName != null) {
      $result.userName = userName;
    }
    if (headUrl != null) {
      $result.headUrl = headUrl;
    }
    return $result;
  }
  SimpleUserInfo._() : super();
  factory SimpleUserInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SimpleUserInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SimpleUserInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'principalId', protoName: 'principalId')
    ..aOS(2, _omitFieldNames ? '' : 'userName', protoName: 'userName')
    ..aOS(3, _omitFieldNames ? '' : 'headUrl', protoName: 'headUrl')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SimpleUserInfo clone() => SimpleUserInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SimpleUserInfo copyWith(void Function(SimpleUserInfo) updates) => super.copyWith((message) => updates(message as SimpleUserInfo)) as SimpleUserInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimpleUserInfo create() => SimpleUserInfo._();
  SimpleUserInfo createEmptyInstance() => create();
  static $pb.PbList<SimpleUserInfo> createRepeated() => $pb.PbList<SimpleUserInfo>();
  @$core.pragma('dart2js:noInline')
  static SimpleUserInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SimpleUserInfo>(create);
  static SimpleUserInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get principalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set principalId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPrincipalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrincipalId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userName => $_getSZ(1);
  @$pb.TagNumber(2)
  set userName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserName() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get headUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set headUrl($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasHeadUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadUrl() => clearField(3);
}

/// 观看用户信息
class WebWatchingUserInfo extends $pb.GeneratedMessage {
  factory WebWatchingUserInfo({
    SimpleUserInfo? user,
    $core.bool? offline,
    $core.bool? tuhao,
    WebLiveAssistantType? liveAssistantType,
    $core.String? displayKsCoin,
  }) {
    final $result = create();
    if (user != null) {
      $result.user = user;
    }
    if (offline != null) {
      $result.offline = offline;
    }
    if (tuhao != null) {
      $result.tuhao = tuhao;
    }
    if (liveAssistantType != null) {
      $result.liveAssistantType = liveAssistantType;
    }
    if (displayKsCoin != null) {
      $result.displayKsCoin = displayKsCoin;
    }
    return $result;
  }
  WebWatchingUserInfo._() : super();
  factory WebWatchingUserInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebWatchingUserInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebWatchingUserInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOM<SimpleUserInfo>(1, _omitFieldNames ? '' : 'user', subBuilder: SimpleUserInfo.create)
    ..aOB(2, _omitFieldNames ? '' : 'offline')
    ..aOB(3, _omitFieldNames ? '' : 'tuhao')
    ..e<WebLiveAssistantType>(4, _omitFieldNames ? '' : 'liveAssistantType', $pb.PbFieldType.OE, protoName: 'liveAssistantType', defaultOrMaker: WebLiveAssistantType.WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE, valueOf: WebLiveAssistantType.valueOf, enumValues: WebLiveAssistantType.values)
    ..aOS(5, _omitFieldNames ? '' : 'displayKsCoin', protoName: 'displayKsCoin')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebWatchingUserInfo clone() => WebWatchingUserInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebWatchingUserInfo copyWith(void Function(WebWatchingUserInfo) updates) => super.copyWith((message) => updates(message as WebWatchingUserInfo)) as WebWatchingUserInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebWatchingUserInfo create() => WebWatchingUserInfo._();
  WebWatchingUserInfo createEmptyInstance() => create();
  static $pb.PbList<WebWatchingUserInfo> createRepeated() => $pb.PbList<WebWatchingUserInfo>();
  @$core.pragma('dart2js:noInline')
  static WebWatchingUserInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebWatchingUserInfo>(create);
  static WebWatchingUserInfo? _defaultInstance;

  @$pb.TagNumber(1)
  SimpleUserInfo get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(SimpleUserInfo v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => clearField(1);
  @$pb.TagNumber(1)
  SimpleUserInfo ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get offline => $_getBF(1);
  @$pb.TagNumber(2)
  set offline($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOffline() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffline() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get tuhao => $_getBF(2);
  @$pb.TagNumber(3)
  set tuhao($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTuhao() => $_has(2);
  @$pb.TagNumber(3)
  void clearTuhao() => clearField(3);

  @$pb.TagNumber(4)
  WebLiveAssistantType get liveAssistantType => $_getN(3);
  @$pb.TagNumber(4)
  set liveAssistantType(WebLiveAssistantType v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasLiveAssistantType() => $_has(3);
  @$pb.TagNumber(4)
  void clearLiveAssistantType() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get displayKsCoin => $_getSZ(4);
  @$pb.TagNumber(5)
  set displayKsCoin($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasDisplayKsCoin() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplayKsCoin() => clearField(5);
}

/// 观看用户数
class SCWebLiveWatchingUsers extends $pb.GeneratedMessage {
  factory SCWebLiveWatchingUsers({
    $core.Iterable<WebWatchingUserInfo>? watchingUser,
    $core.String? displayWatchingCount,
    $fixnum.Int64? pendingDuration,
  }) {
    final $result = create();
    if (watchingUser != null) {
      $result.watchingUser.addAll(watchingUser);
    }
    if (displayWatchingCount != null) {
      $result.displayWatchingCount = displayWatchingCount;
    }
    if (pendingDuration != null) {
      $result.pendingDuration = pendingDuration;
    }
    return $result;
  }
  SCWebLiveWatchingUsers._() : super();
  factory SCWebLiveWatchingUsers.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SCWebLiveWatchingUsers.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SCWebLiveWatchingUsers', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..pc<WebWatchingUserInfo>(1, _omitFieldNames ? '' : 'watchingUser', $pb.PbFieldType.PM, protoName: 'watchingUser', subBuilder: WebWatchingUserInfo.create)
    ..aOS(2, _omitFieldNames ? '' : 'displayWatchingCount', protoName: 'displayWatchingCount')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'pendingDuration', $pb.PbFieldType.OU6, protoName: 'pendingDuration', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SCWebLiveWatchingUsers clone() => SCWebLiveWatchingUsers()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SCWebLiveWatchingUsers copyWith(void Function(SCWebLiveWatchingUsers) updates) => super.copyWith((message) => updates(message as SCWebLiveWatchingUsers)) as SCWebLiveWatchingUsers;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SCWebLiveWatchingUsers create() => SCWebLiveWatchingUsers._();
  SCWebLiveWatchingUsers createEmptyInstance() => create();
  static $pb.PbList<SCWebLiveWatchingUsers> createRepeated() => $pb.PbList<SCWebLiveWatchingUsers>();
  @$core.pragma('dart2js:noInline')
  static SCWebLiveWatchingUsers getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SCWebLiveWatchingUsers>(create);
  static SCWebLiveWatchingUsers? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<WebWatchingUserInfo> get watchingUser => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get displayWatchingCount => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayWatchingCount($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDisplayWatchingCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayWatchingCount() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get pendingDuration => $_getI64(2);
  @$pb.TagNumber(3)
  set pendingDuration($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPendingDuration() => $_has(2);
  @$pb.TagNumber(3)
  void clearPendingDuration() => clearField(3);
}

class CSWebHeartbeat_Payload extends $pb.GeneratedMessage {
  factory CSWebHeartbeat_Payload({
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  CSWebHeartbeat_Payload._() : super();
  factory CSWebHeartbeat_Payload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CSWebHeartbeat_Payload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CSWebHeartbeat.Payload', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'timestamp', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CSWebHeartbeat_Payload clone() => CSWebHeartbeat_Payload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CSWebHeartbeat_Payload copyWith(void Function(CSWebHeartbeat_Payload) updates) => super.copyWith((message) => updates(message as CSWebHeartbeat_Payload)) as CSWebHeartbeat_Payload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CSWebHeartbeat_Payload create() => CSWebHeartbeat_Payload._();
  CSWebHeartbeat_Payload createEmptyInstance() => create();
  static $pb.PbList<CSWebHeartbeat_Payload> createRepeated() => $pb.PbList<CSWebHeartbeat_Payload>();
  @$core.pragma('dart2js:noInline')
  static CSWebHeartbeat_Payload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CSWebHeartbeat_Payload>(create);
  static CSWebHeartbeat_Payload? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get timestamp => $_getI64(0);
  @$pb.TagNumber(1)
  set timestamp($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => clearField(1);
}

/// 心跳包
class CSWebHeartbeat extends $pb.GeneratedMessage {
  factory CSWebHeartbeat({
    $fixnum.Int64? payloadType,
    CSWebHeartbeat_Payload? payload,
  }) {
    final $result = create();
    if (payloadType != null) {
      $result.payloadType = payloadType;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    return $result;
  }
  CSWebHeartbeat._() : super();
  factory CSWebHeartbeat.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CSWebHeartbeat.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CSWebHeartbeat', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'payloadType', protoName: 'payloadType')
    ..aOM<CSWebHeartbeat_Payload>(3, _omitFieldNames ? '' : 'payload', subBuilder: CSWebHeartbeat_Payload.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CSWebHeartbeat clone() => CSWebHeartbeat()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CSWebHeartbeat copyWith(void Function(CSWebHeartbeat) updates) => super.copyWith((message) => updates(message as CSWebHeartbeat)) as CSWebHeartbeat;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CSWebHeartbeat create() => CSWebHeartbeat._();
  CSWebHeartbeat createEmptyInstance() => create();
  static $pb.PbList<CSWebHeartbeat> createRepeated() => $pb.PbList<CSWebHeartbeat>();
  @$core.pragma('dart2js:noInline')
  static CSWebHeartbeat getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CSWebHeartbeat>(create);
  static CSWebHeartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get payloadType => $_getI64(0);
  @$pb.TagNumber(1)
  set payloadType($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPayloadType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayloadType() => clearField(1);

  @$pb.TagNumber(3)
  CSWebHeartbeat_Payload get payload => $_getN(1);
  @$pb.TagNumber(3)
  set payload(CSWebHeartbeat_Payload v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(3)
  void clearPayload() => clearField(3);
  @$pb.TagNumber(3)
  CSWebHeartbeat_Payload ensurePayload() => $_ensure(1);
}

/// 消息主体包
class SocketMessage extends $pb.GeneratedMessage {
  factory SocketMessage({
    PayloadType? payloadType,
    CompressionType? compressionType,
    $core.List<$core.int>? payload,
  }) {
    final $result = create();
    if (payloadType != null) {
      $result.payloadType = payloadType;
    }
    if (compressionType != null) {
      $result.compressionType = compressionType;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    return $result;
  }
  SocketMessage._() : super();
  factory SocketMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SocketMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SocketMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..e<PayloadType>(1, _omitFieldNames ? '' : 'payloadType', $pb.PbFieldType.OE, protoName: 'payloadType', defaultOrMaker: PayloadType.PAYLOAD_TYPE_UNKNOWN, valueOf: PayloadType.valueOf, enumValues: PayloadType.values)
    ..e<CompressionType>(2, _omitFieldNames ? '' : 'compressionType', $pb.PbFieldType.OE, protoName: 'compressionType', defaultOrMaker: CompressionType.COMPRESSION_TYPE_UNKNOWN, valueOf: CompressionType.valueOf, enumValues: CompressionType.values)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SocketMessage clone() => SocketMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SocketMessage copyWith(void Function(SocketMessage) updates) => super.copyWith((message) => updates(message as SocketMessage)) as SocketMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SocketMessage create() => SocketMessage._();
  SocketMessage createEmptyInstance() => create();
  static $pb.PbList<SocketMessage> createRepeated() => $pb.PbList<SocketMessage>();
  @$core.pragma('dart2js:noInline')
  static SocketMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SocketMessage>(create);
  static SocketMessage? _defaultInstance;

  @$pb.TagNumber(1)
  PayloadType get payloadType => $_getN(0);
  @$pb.TagNumber(1)
  set payloadType(PayloadType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPayloadType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayloadType() => clearField(1);

  @$pb.TagNumber(2)
  CompressionType get compressionType => $_getN(1);
  @$pb.TagNumber(2)
  set compressionType(CompressionType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasCompressionType() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompressionType() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => clearField(3);
}

/// 心跳包响应
class SCHeartbeatAck extends $pb.GeneratedMessage {
  factory SCHeartbeatAck({
    $fixnum.Int64? timestamp,
    $fixnum.Int64? clientTimestamp,
  }) {
    final $result = create();
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (clientTimestamp != null) {
      $result.clientTimestamp = clientTimestamp;
    }
    return $result;
  }
  SCHeartbeatAck._() : super();
  factory SCHeartbeatAck.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SCHeartbeatAck.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SCHeartbeatAck', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'timestamp', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'clientTimestamp', $pb.PbFieldType.OU6, protoName: 'clientTimestamp', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SCHeartbeatAck clone() => SCHeartbeatAck()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SCHeartbeatAck copyWith(void Function(SCHeartbeatAck) updates) => super.copyWith((message) => updates(message as SCHeartbeatAck)) as SCHeartbeatAck;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SCHeartbeatAck create() => SCHeartbeatAck._();
  SCHeartbeatAck createEmptyInstance() => create();
  static $pb.PbList<SCHeartbeatAck> createRepeated() => $pb.PbList<SCHeartbeatAck>();
  @$core.pragma('dart2js:noInline')
  static SCHeartbeatAck getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SCHeartbeatAck>(create);
  static SCHeartbeatAck? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get timestamp => $_getI64(0);
  @$pb.TagNumber(1)
  set timestamp($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get clientTimestamp => $_getI64(1);
  @$pb.TagNumber(2)
  set clientTimestamp($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasClientTimestamp() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientTimestamp() => clearField(2);
}

class WebCommentFeed extends $pb.GeneratedMessage {
  factory WebCommentFeed({
    $core.String? id,
    SimpleUserInfo? user,
    $core.String? content,
    $core.String? deviceHash,
    $fixnum.Int64? sortRank,
    $core.String? color,
    WebCommentFeedShowType? showType,
    LiveAudienceState? senderState,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (user != null) {
      $result.user = user;
    }
    if (content != null) {
      $result.content = content;
    }
    if (deviceHash != null) {
      $result.deviceHash = deviceHash;
    }
    if (sortRank != null) {
      $result.sortRank = sortRank;
    }
    if (color != null) {
      $result.color = color;
    }
    if (showType != null) {
      $result.showType = showType;
    }
    if (senderState != null) {
      $result.senderState = senderState;
    }
    return $result;
  }
  WebCommentFeed._() : super();
  factory WebCommentFeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebCommentFeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebCommentFeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<SimpleUserInfo>(2, _omitFieldNames ? '' : 'user', subBuilder: SimpleUserInfo.create)
    ..aOS(3, _omitFieldNames ? '' : 'content')
    ..aOS(4, _omitFieldNames ? '' : 'deviceHash', protoName: 'deviceHash')
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'sortRank', $pb.PbFieldType.OU6, protoName: 'sortRank', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'color')
    ..e<WebCommentFeedShowType>(7, _omitFieldNames ? '' : 'showType', $pb.PbFieldType.OE, protoName: 'showType', defaultOrMaker: WebCommentFeedShowType.FEED_SHOW_UNKNOWN, valueOf: WebCommentFeedShowType.valueOf, enumValues: WebCommentFeedShowType.values)
    ..aOM<LiveAudienceState>(8, _omitFieldNames ? '' : 'senderState', protoName: 'senderState', subBuilder: LiveAudienceState.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebCommentFeed clone() => WebCommentFeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebCommentFeed copyWith(void Function(WebCommentFeed) updates) => super.copyWith((message) => updates(message as WebCommentFeed)) as WebCommentFeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebCommentFeed create() => WebCommentFeed._();
  WebCommentFeed createEmptyInstance() => create();
  static $pb.PbList<WebCommentFeed> createRepeated() => $pb.PbList<WebCommentFeed>();
  @$core.pragma('dart2js:noInline')
  static WebCommentFeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebCommentFeed>(create);
  static WebCommentFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  SimpleUserInfo get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(SimpleUserInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => clearField(2);
  @$pb.TagNumber(2)
  SimpleUserInfo ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceHash => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceHash($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDeviceHash() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceHash() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get sortRank => $_getI64(4);
  @$pb.TagNumber(5)
  set sortRank($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSortRank() => $_has(4);
  @$pb.TagNumber(5)
  void clearSortRank() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get color => $_getSZ(5);
  @$pb.TagNumber(6)
  set color($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearColor() => clearField(6);

  @$pb.TagNumber(7)
  WebCommentFeedShowType get showType => $_getN(6);
  @$pb.TagNumber(7)
  set showType(WebCommentFeedShowType v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasShowType() => $_has(6);
  @$pb.TagNumber(7)
  void clearShowType() => clearField(7);

  @$pb.TagNumber(8)
  LiveAudienceState get senderState => $_getN(7);
  @$pb.TagNumber(8)
  set senderState(LiveAudienceState v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasSenderState() => $_has(7);
  @$pb.TagNumber(8)
  void clearSenderState() => clearField(8);
  @$pb.TagNumber(8)
  LiveAudienceState ensureSenderState() => $_ensure(7);
}

class LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 extends $pb.GeneratedMessage {
  factory LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1({
    $core.String? badgeIcon,
    $core.String? badgeName,
  }) {
    final $result = create();
    if (badgeIcon != null) {
      $result.badgeIcon = badgeIcon;
    }
    if (badgeName != null) {
      $result.badgeName = badgeName;
    }
    return $result;
  }
  LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1._() : super();
  factory LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LiveAudienceState.LiveAudienceState_11.LiveAudienceState_11_1', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(2, _omitFieldNames ? '' : 'badgeIcon', protoName: 'badgeIcon')
    ..aOS(4, _omitFieldNames ? '' : 'badgeName', protoName: 'badgeName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 clone() => LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 copyWith(void Function(LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1) updates) => super.copyWith((message) => updates(message as LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1)) as LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 create() => LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1._();
  LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 createEmptyInstance() => create();
  static $pb.PbList<LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1> createRepeated() => $pb.PbList<LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1>();
  @$core.pragma('dart2js:noInline')
  static LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1>(create);
  static LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1? _defaultInstance;

  /// string s1 = 1;
  @$pb.TagNumber(2)
  $core.String get badgeIcon => $_getSZ(0);
  @$pb.TagNumber(2)
  set badgeIcon($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(2)
  $core.bool hasBadgeIcon() => $_has(0);
  @$pb.TagNumber(2)
  void clearBadgeIcon() => clearField(2);

  /// uint32 int3 = 3;
  @$pb.TagNumber(4)
  $core.String get badgeName => $_getSZ(1);
  @$pb.TagNumber(4)
  set badgeName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(4)
  $core.bool hasBadgeName() => $_has(1);
  @$pb.TagNumber(4)
  void clearBadgeName() => clearField(4);
}

class LiveAudienceState_LiveAudienceState_11 extends $pb.GeneratedMessage {
  factory LiveAudienceState_LiveAudienceState_11({
    LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1? liveAudienceState111,
  }) {
    final $result = create();
    if (liveAudienceState111 != null) {
      $result.liveAudienceState111 = liveAudienceState111;
    }
    return $result;
  }
  LiveAudienceState_LiveAudienceState_11._() : super();
  factory LiveAudienceState_LiveAudienceState_11.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LiveAudienceState_LiveAudienceState_11.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LiveAudienceState.LiveAudienceState_11', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOM<LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1>(1, _omitFieldNames ? '' : 'liveAudienceState111', protoName: 'liveAudienceState_11_1', subBuilder: LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LiveAudienceState_LiveAudienceState_11 clone() => LiveAudienceState_LiveAudienceState_11()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LiveAudienceState_LiveAudienceState_11 copyWith(void Function(LiveAudienceState_LiveAudienceState_11) updates) => super.copyWith((message) => updates(message as LiveAudienceState_LiveAudienceState_11)) as LiveAudienceState_LiveAudienceState_11;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LiveAudienceState_LiveAudienceState_11 create() => LiveAudienceState_LiveAudienceState_11._();
  LiveAudienceState_LiveAudienceState_11 createEmptyInstance() => create();
  static $pb.PbList<LiveAudienceState_LiveAudienceState_11> createRepeated() => $pb.PbList<LiveAudienceState_LiveAudienceState_11>();
  @$core.pragma('dart2js:noInline')
  static LiveAudienceState_LiveAudienceState_11 getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LiveAudienceState_LiveAudienceState_11>(create);
  static LiveAudienceState_LiveAudienceState_11? _defaultInstance;

  @$pb.TagNumber(1)
  LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 get liveAudienceState111 => $_getN(0);
  @$pb.TagNumber(1)
  set liveAudienceState111(LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasLiveAudienceState111() => $_has(0);
  @$pb.TagNumber(1)
  void clearLiveAudienceState111() => clearField(1);
  @$pb.TagNumber(1)
  LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1 ensureLiveAudienceState111() => $_ensure(0);
}

class LiveAudienceState extends $pb.GeneratedMessage {
  factory LiveAudienceState({
    $core.bool? isFromFansTop,
    $core.bool? isKoi,
    AssistantType? assistantType,
    $core.int? fansGroupIntimacyLevel,
    GzoneNameplate? nameplate,
    LiveFansGroupState? liveFansGroupState,
    $core.int? wealthGrade,
    $core.String? badgeKey,
    $core.Iterable<LiveAudienceState_LiveAudienceState_11>? liveAudienceState11,
  }) {
    final $result = create();
    if (isFromFansTop != null) {
      $result.isFromFansTop = isFromFansTop;
    }
    if (isKoi != null) {
      $result.isKoi = isKoi;
    }
    if (assistantType != null) {
      $result.assistantType = assistantType;
    }
    if (fansGroupIntimacyLevel != null) {
      $result.fansGroupIntimacyLevel = fansGroupIntimacyLevel;
    }
    if (nameplate != null) {
      $result.nameplate = nameplate;
    }
    if (liveFansGroupState != null) {
      $result.liveFansGroupState = liveFansGroupState;
    }
    if (wealthGrade != null) {
      $result.wealthGrade = wealthGrade;
    }
    if (badgeKey != null) {
      $result.badgeKey = badgeKey;
    }
    if (liveAudienceState11 != null) {
      $result.liveAudienceState11.addAll(liveAudienceState11);
    }
    return $result;
  }
  LiveAudienceState._() : super();
  factory LiveAudienceState.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LiveAudienceState.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LiveAudienceState', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isFromFansTop', protoName: 'isFromFansTop')
    ..aOB(2, _omitFieldNames ? '' : 'isKoi', protoName: 'isKoi')
    ..e<AssistantType>(3, _omitFieldNames ? '' : 'assistantType', $pb.PbFieldType.OE, protoName: 'assistantType', defaultOrMaker: AssistantType.UNKNOWN_ASSISTANT_TYPE, valueOf: AssistantType.valueOf, enumValues: AssistantType.values)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'fansGroupIntimacyLevel', $pb.PbFieldType.OU3, protoName: 'fansGroupIntimacyLevel')
    ..aOM<GzoneNameplate>(5, _omitFieldNames ? '' : 'nameplate', subBuilder: GzoneNameplate.create)
    ..aOM<LiveFansGroupState>(6, _omitFieldNames ? '' : 'liveFansGroupState', protoName: 'liveFansGroupState', subBuilder: LiveFansGroupState.create)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'wealthGrade', $pb.PbFieldType.OU3, protoName: 'wealthGrade')
    ..aOS(8, _omitFieldNames ? '' : 'badgeKey', protoName: 'badgeKey')
    ..pc<LiveAudienceState_LiveAudienceState_11>(11, _omitFieldNames ? '' : 'liveAudienceState11', $pb.PbFieldType.PM, protoName: 'liveAudienceState_11', subBuilder: LiveAudienceState_LiveAudienceState_11.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LiveAudienceState clone() => LiveAudienceState()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LiveAudienceState copyWith(void Function(LiveAudienceState) updates) => super.copyWith((message) => updates(message as LiveAudienceState)) as LiveAudienceState;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LiveAudienceState create() => LiveAudienceState._();
  LiveAudienceState createEmptyInstance() => create();
  static $pb.PbList<LiveAudienceState> createRepeated() => $pb.PbList<LiveAudienceState>();
  @$core.pragma('dart2js:noInline')
  static LiveAudienceState getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LiveAudienceState>(create);
  static LiveAudienceState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isFromFansTop => $_getBF(0);
  @$pb.TagNumber(1)
  set isFromFansTop($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIsFromFansTop() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsFromFansTop() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isKoi => $_getBF(1);
  @$pb.TagNumber(2)
  set isKoi($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIsKoi() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsKoi() => clearField(2);

  @$pb.TagNumber(3)
  AssistantType get assistantType => $_getN(2);
  @$pb.TagNumber(3)
  set assistantType(AssistantType v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasAssistantType() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssistantType() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get fansGroupIntimacyLevel => $_getIZ(3);
  @$pb.TagNumber(4)
  set fansGroupIntimacyLevel($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFansGroupIntimacyLevel() => $_has(3);
  @$pb.TagNumber(4)
  void clearFansGroupIntimacyLevel() => clearField(4);

  @$pb.TagNumber(5)
  GzoneNameplate get nameplate => $_getN(4);
  @$pb.TagNumber(5)
  set nameplate(GzoneNameplate v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasNameplate() => $_has(4);
  @$pb.TagNumber(5)
  void clearNameplate() => clearField(5);
  @$pb.TagNumber(5)
  GzoneNameplate ensureNameplate() => $_ensure(4);

  @$pb.TagNumber(6)
  LiveFansGroupState get liveFansGroupState => $_getN(5);
  @$pb.TagNumber(6)
  set liveFansGroupState(LiveFansGroupState v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasLiveFansGroupState() => $_has(5);
  @$pb.TagNumber(6)
  void clearLiveFansGroupState() => clearField(6);
  @$pb.TagNumber(6)
  LiveFansGroupState ensureLiveFansGroupState() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.int get wealthGrade => $_getIZ(6);
  @$pb.TagNumber(7)
  set wealthGrade($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasWealthGrade() => $_has(6);
  @$pb.TagNumber(7)
  void clearWealthGrade() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get badgeKey => $_getSZ(7);
  @$pb.TagNumber(8)
  set badgeKey($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasBadgeKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearBadgeKey() => clearField(8);

  @$pb.TagNumber(11)
  $core.List<LiveAudienceState_LiveAudienceState_11> get liveAudienceState11 => $_getList(8);
}

class LiveFansGroupState extends $pb.GeneratedMessage {
  factory LiveFansGroupState({
    $core.int? intimacyLevel,
    $core.int? enterRoomSpecialEffect,
  }) {
    final $result = create();
    if (intimacyLevel != null) {
      $result.intimacyLevel = intimacyLevel;
    }
    if (enterRoomSpecialEffect != null) {
      $result.enterRoomSpecialEffect = enterRoomSpecialEffect;
    }
    return $result;
  }
  LiveFansGroupState._() : super();
  factory LiveFansGroupState.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LiveFansGroupState.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LiveFansGroupState', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'intimacyLevel', $pb.PbFieldType.OU3, protoName: 'intimacyLevel')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'enterRoomSpecialEffect', $pb.PbFieldType.OU3, protoName: 'enterRoomSpecialEffect')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LiveFansGroupState clone() => LiveFansGroupState()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LiveFansGroupState copyWith(void Function(LiveFansGroupState) updates) => super.copyWith((message) => updates(message as LiveFansGroupState)) as LiveFansGroupState;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LiveFansGroupState create() => LiveFansGroupState._();
  LiveFansGroupState createEmptyInstance() => create();
  static $pb.PbList<LiveFansGroupState> createRepeated() => $pb.PbList<LiveFansGroupState>();
  @$core.pragma('dart2js:noInline')
  static LiveFansGroupState getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LiveFansGroupState>(create);
  static LiveFansGroupState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get intimacyLevel => $_getIZ(0);
  @$pb.TagNumber(1)
  set intimacyLevel($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIntimacyLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntimacyLevel() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get enterRoomSpecialEffect => $_getIZ(1);
  @$pb.TagNumber(2)
  set enterRoomSpecialEffect($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEnterRoomSpecialEffect() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnterRoomSpecialEffect() => clearField(2);
}

class GzoneNameplate extends $pb.GeneratedMessage {
  factory GzoneNameplate({
    $fixnum.Int64? id,
    $core.String? name,
    $core.Iterable<PicUrl>? urls,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (name != null) {
      $result.name = name;
    }
    if (urls != null) {
      $result.urls.addAll(urls);
    }
    return $result;
  }
  GzoneNameplate._() : super();
  factory GzoneNameplate.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GzoneNameplate.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GzoneNameplate', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pc<PicUrl>(3, _omitFieldNames ? '' : 'urls', $pb.PbFieldType.PM, subBuilder: PicUrl.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GzoneNameplate clone() => GzoneNameplate()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GzoneNameplate copyWith(void Function(GzoneNameplate) updates) => super.copyWith((message) => updates(message as GzoneNameplate)) as GzoneNameplate;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GzoneNameplate create() => GzoneNameplate._();
  GzoneNameplate createEmptyInstance() => create();
  static $pb.PbList<GzoneNameplate> createRepeated() => $pb.PbList<GzoneNameplate>();
  @$core.pragma('dart2js:noInline')
  static GzoneNameplate getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GzoneNameplate>(create);
  static GzoneNameplate? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<PicUrl> get urls => $_getList(2);
}

class PicUrl extends $pb.GeneratedMessage {
  factory PicUrl({
    $core.String? cdn,
    $core.String? url,
    $core.String? urlPattern,
    $core.String? ip,
  }) {
    final $result = create();
    if (cdn != null) {
      $result.cdn = cdn;
    }
    if (url != null) {
      $result.url = url;
    }
    if (urlPattern != null) {
      $result.urlPattern = urlPattern;
    }
    if (ip != null) {
      $result.ip = ip;
    }
    return $result;
  }
  PicUrl._() : super();
  factory PicUrl.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PicUrl.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PicUrl', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cdn')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'urlPattern', protoName: 'urlPattern')
    ..aOS(4, _omitFieldNames ? '' : 'ip')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PicUrl clone() => PicUrl()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PicUrl copyWith(void Function(PicUrl) updates) => super.copyWith((message) => updates(message as PicUrl)) as PicUrl;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PicUrl create() => PicUrl._();
  PicUrl createEmptyInstance() => create();
  static $pb.PbList<PicUrl> createRepeated() => $pb.PbList<PicUrl>();
  @$core.pragma('dart2js:noInline')
  static PicUrl getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PicUrl>(create);
  static PicUrl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cdn => $_getSZ(0);
  @$pb.TagNumber(1)
  set cdn($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCdn() => $_has(0);
  @$pb.TagNumber(1)
  void clearCdn() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get urlPattern => $_getSZ(2);
  @$pb.TagNumber(3)
  set urlPattern($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasUrlPattern() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrlPattern() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get ip => $_getSZ(3);
  @$pb.TagNumber(4)
  set ip($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIp() => $_has(3);
  @$pb.TagNumber(4)
  void clearIp() => clearField(4);
}

class SCWebFeedPush extends $pb.GeneratedMessage {
  factory SCWebFeedPush({
    $core.String? displayWatchingCount,
    $core.String? displayLikeCount,
    $fixnum.Int64? pendingLikeCount,
    $fixnum.Int64? pushInterval,
    $core.Iterable<WebCommentFeed>? commentFeeds,
    $core.String? commentCursor,
    $core.Iterable<WebComboCommentFeed>? comboCommentFeed,
    $core.Iterable<WebLikeFeed>? likeFeeds,
    $core.Iterable<WebGiftFeed>? giftFeeds,
    $core.String? giftCursor,
    $core.Iterable<WebSystemNoticeFeed>? systemNoticeFeeds,
    $core.Iterable<WebShareFeed>? shareFeeds,
  }) {
    final $result = create();
    if (displayWatchingCount != null) {
      $result.displayWatchingCount = displayWatchingCount;
    }
    if (displayLikeCount != null) {
      $result.displayLikeCount = displayLikeCount;
    }
    if (pendingLikeCount != null) {
      $result.pendingLikeCount = pendingLikeCount;
    }
    if (pushInterval != null) {
      $result.pushInterval = pushInterval;
    }
    if (commentFeeds != null) {
      $result.commentFeeds.addAll(commentFeeds);
    }
    if (commentCursor != null) {
      $result.commentCursor = commentCursor;
    }
    if (comboCommentFeed != null) {
      $result.comboCommentFeed.addAll(comboCommentFeed);
    }
    if (likeFeeds != null) {
      $result.likeFeeds.addAll(likeFeeds);
    }
    if (giftFeeds != null) {
      $result.giftFeeds.addAll(giftFeeds);
    }
    if (giftCursor != null) {
      $result.giftCursor = giftCursor;
    }
    if (systemNoticeFeeds != null) {
      $result.systemNoticeFeeds.addAll(systemNoticeFeeds);
    }
    if (shareFeeds != null) {
      $result.shareFeeds.addAll(shareFeeds);
    }
    return $result;
  }
  SCWebFeedPush._() : super();
  factory SCWebFeedPush.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SCWebFeedPush.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SCWebFeedPush', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'displayWatchingCount', protoName: 'displayWatchingCount')
    ..aOS(2, _omitFieldNames ? '' : 'displayLikeCount', protoName: 'displayLikeCount')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'pendingLikeCount', $pb.PbFieldType.OU6, protoName: 'pendingLikeCount', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'pushInterval', $pb.PbFieldType.OU6, protoName: 'pushInterval', defaultOrMaker: $fixnum.Int64.ZERO)
    ..pc<WebCommentFeed>(5, _omitFieldNames ? '' : 'commentFeeds', $pb.PbFieldType.PM, protoName: 'commentFeeds', subBuilder: WebCommentFeed.create)
    ..aOS(6, _omitFieldNames ? '' : 'commentCursor', protoName: 'commentCursor')
    ..pc<WebComboCommentFeed>(7, _omitFieldNames ? '' : 'comboCommentFeed', $pb.PbFieldType.PM, protoName: 'comboCommentFeed', subBuilder: WebComboCommentFeed.create)
    ..pc<WebLikeFeed>(8, _omitFieldNames ? '' : 'likeFeeds', $pb.PbFieldType.PM, protoName: 'likeFeeds', subBuilder: WebLikeFeed.create)
    ..pc<WebGiftFeed>(9, _omitFieldNames ? '' : 'giftFeeds', $pb.PbFieldType.PM, protoName: 'giftFeeds', subBuilder: WebGiftFeed.create)
    ..aOS(10, _omitFieldNames ? '' : 'giftCursor', protoName: 'giftCursor')
    ..pc<WebSystemNoticeFeed>(11, _omitFieldNames ? '' : 'systemNoticeFeeds', $pb.PbFieldType.PM, protoName: 'systemNoticeFeeds', subBuilder: WebSystemNoticeFeed.create)
    ..pc<WebShareFeed>(12, _omitFieldNames ? '' : 'shareFeeds', $pb.PbFieldType.PM, protoName: 'shareFeeds', subBuilder: WebShareFeed.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SCWebFeedPush clone() => SCWebFeedPush()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SCWebFeedPush copyWith(void Function(SCWebFeedPush) updates) => super.copyWith((message) => updates(message as SCWebFeedPush)) as SCWebFeedPush;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SCWebFeedPush create() => SCWebFeedPush._();
  SCWebFeedPush createEmptyInstance() => create();
  static $pb.PbList<SCWebFeedPush> createRepeated() => $pb.PbList<SCWebFeedPush>();
  @$core.pragma('dart2js:noInline')
  static SCWebFeedPush getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SCWebFeedPush>(create);
  static SCWebFeedPush? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get displayWatchingCount => $_getSZ(0);
  @$pb.TagNumber(1)
  set displayWatchingCount($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDisplayWatchingCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearDisplayWatchingCount() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get displayLikeCount => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayLikeCount($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDisplayLikeCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayLikeCount() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get pendingLikeCount => $_getI64(2);
  @$pb.TagNumber(3)
  set pendingLikeCount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPendingLikeCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearPendingLikeCount() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get pushInterval => $_getI64(3);
  @$pb.TagNumber(4)
  set pushInterval($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPushInterval() => $_has(3);
  @$pb.TagNumber(4)
  void clearPushInterval() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<WebCommentFeed> get commentFeeds => $_getList(4);

  @$pb.TagNumber(6)
  $core.String get commentCursor => $_getSZ(5);
  @$pb.TagNumber(6)
  set commentCursor($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCommentCursor() => $_has(5);
  @$pb.TagNumber(6)
  void clearCommentCursor() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<WebComboCommentFeed> get comboCommentFeed => $_getList(6);

  @$pb.TagNumber(8)
  $core.List<WebLikeFeed> get likeFeeds => $_getList(7);

  @$pb.TagNumber(9)
  $core.List<WebGiftFeed> get giftFeeds => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get giftCursor => $_getSZ(9);
  @$pb.TagNumber(10)
  set giftCursor($core.String v) { $_setString(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasGiftCursor() => $_has(9);
  @$pb.TagNumber(10)
  void clearGiftCursor() => clearField(10);

  @$pb.TagNumber(11)
  $core.List<WebSystemNoticeFeed> get systemNoticeFeeds => $_getList(10);

  @$pb.TagNumber(12)
  $core.List<WebShareFeed> get shareFeeds => $_getList(11);
}

class WebShareFeed extends $pb.GeneratedMessage {
  factory WebShareFeed({
    $core.String? id,
    SimpleUserInfo? user,
    $fixnum.Int64? time,
    $core.int? thirdPartyPlatform,
    $fixnum.Int64? sortRank,
    WebLiveAssistantType? liveAssistantType,
    $core.String? deviceHash,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (user != null) {
      $result.user = user;
    }
    if (time != null) {
      $result.time = time;
    }
    if (thirdPartyPlatform != null) {
      $result.thirdPartyPlatform = thirdPartyPlatform;
    }
    if (sortRank != null) {
      $result.sortRank = sortRank;
    }
    if (liveAssistantType != null) {
      $result.liveAssistantType = liveAssistantType;
    }
    if (deviceHash != null) {
      $result.deviceHash = deviceHash;
    }
    return $result;
  }
  WebShareFeed._() : super();
  factory WebShareFeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebShareFeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebShareFeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<SimpleUserInfo>(2, _omitFieldNames ? '' : 'user', subBuilder: SimpleUserInfo.create)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'time', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'thirdPartyPlatform', $pb.PbFieldType.OU3, protoName: 'thirdPartyPlatform')
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'sortRank', $pb.PbFieldType.OU6, protoName: 'sortRank', defaultOrMaker: $fixnum.Int64.ZERO)
    ..e<WebLiveAssistantType>(6, _omitFieldNames ? '' : 'liveAssistantType', $pb.PbFieldType.OE, protoName: 'liveAssistantType', defaultOrMaker: WebLiveAssistantType.WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE, valueOf: WebLiveAssistantType.valueOf, enumValues: WebLiveAssistantType.values)
    ..aOS(7, _omitFieldNames ? '' : 'deviceHash', protoName: 'deviceHash')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebShareFeed clone() => WebShareFeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebShareFeed copyWith(void Function(WebShareFeed) updates) => super.copyWith((message) => updates(message as WebShareFeed)) as WebShareFeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebShareFeed create() => WebShareFeed._();
  WebShareFeed createEmptyInstance() => create();
  static $pb.PbList<WebShareFeed> createRepeated() => $pb.PbList<WebShareFeed>();
  @$core.pragma('dart2js:noInline')
  static WebShareFeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebShareFeed>(create);
  static WebShareFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  SimpleUserInfo get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(SimpleUserInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => clearField(2);
  @$pb.TagNumber(2)
  SimpleUserInfo ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get time => $_getI64(2);
  @$pb.TagNumber(3)
  set time($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearTime() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get thirdPartyPlatform => $_getIZ(3);
  @$pb.TagNumber(4)
  set thirdPartyPlatform($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasThirdPartyPlatform() => $_has(3);
  @$pb.TagNumber(4)
  void clearThirdPartyPlatform() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get sortRank => $_getI64(4);
  @$pb.TagNumber(5)
  set sortRank($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSortRank() => $_has(4);
  @$pb.TagNumber(5)
  void clearSortRank() => clearField(5);

  @$pb.TagNumber(6)
  WebLiveAssistantType get liveAssistantType => $_getN(5);
  @$pb.TagNumber(6)
  set liveAssistantType(WebLiveAssistantType v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasLiveAssistantType() => $_has(5);
  @$pb.TagNumber(6)
  void clearLiveAssistantType() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get deviceHash => $_getSZ(6);
  @$pb.TagNumber(7)
  set deviceHash($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasDeviceHash() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeviceHash() => clearField(7);
}

class WebSystemNoticeFeed extends $pb.GeneratedMessage {
  factory WebSystemNoticeFeed({
    $core.String? id,
    SimpleUserInfo? user,
    $fixnum.Int64? time,
    $core.String? content,
    $fixnum.Int64? displayDuration,
    $fixnum.Int64? sortRank,
    DisplayType? displayType,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (user != null) {
      $result.user = user;
    }
    if (time != null) {
      $result.time = time;
    }
    if (content != null) {
      $result.content = content;
    }
    if (displayDuration != null) {
      $result.displayDuration = displayDuration;
    }
    if (sortRank != null) {
      $result.sortRank = sortRank;
    }
    if (displayType != null) {
      $result.displayType = displayType;
    }
    return $result;
  }
  WebSystemNoticeFeed._() : super();
  factory WebSystemNoticeFeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebSystemNoticeFeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebSystemNoticeFeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<SimpleUserInfo>(2, _omitFieldNames ? '' : 'user', subBuilder: SimpleUserInfo.create)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'time', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'displayDuration', $pb.PbFieldType.OU6, protoName: 'displayDuration', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'sortRank', $pb.PbFieldType.OU6, protoName: 'sortRank', defaultOrMaker: $fixnum.Int64.ZERO)
    ..e<DisplayType>(7, _omitFieldNames ? '' : 'displayType', $pb.PbFieldType.OE, protoName: 'displayType', defaultOrMaker: DisplayType.UNKNOWN_DISPLAY_TYPE, valueOf: DisplayType.valueOf, enumValues: DisplayType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebSystemNoticeFeed clone() => WebSystemNoticeFeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebSystemNoticeFeed copyWith(void Function(WebSystemNoticeFeed) updates) => super.copyWith((message) => updates(message as WebSystemNoticeFeed)) as WebSystemNoticeFeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebSystemNoticeFeed create() => WebSystemNoticeFeed._();
  WebSystemNoticeFeed createEmptyInstance() => create();
  static $pb.PbList<WebSystemNoticeFeed> createRepeated() => $pb.PbList<WebSystemNoticeFeed>();
  @$core.pragma('dart2js:noInline')
  static WebSystemNoticeFeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebSystemNoticeFeed>(create);
  static WebSystemNoticeFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  SimpleUserInfo get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(SimpleUserInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => clearField(2);
  @$pb.TagNumber(2)
  SimpleUserInfo ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get time => $_getI64(2);
  @$pb.TagNumber(3)
  set time($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearTime() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get displayDuration => $_getI64(4);
  @$pb.TagNumber(5)
  set displayDuration($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasDisplayDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplayDuration() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get sortRank => $_getI64(5);
  @$pb.TagNumber(6)
  set sortRank($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSortRank() => $_has(5);
  @$pb.TagNumber(6)
  void clearSortRank() => clearField(6);

  @$pb.TagNumber(7)
  DisplayType get displayType => $_getN(6);
  @$pb.TagNumber(7)
  set displayType(DisplayType v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasDisplayType() => $_has(6);
  @$pb.TagNumber(7)
  void clearDisplayType() => clearField(7);
}

class WebGiftFeed extends $pb.GeneratedMessage {
  factory WebGiftFeed({
    $core.String? id,
    SimpleUserInfo? user,
    $fixnum.Int64? time,
    $core.int? giftId,
    $fixnum.Int64? sortRank,
    $core.String? mergeKey,
    $core.int? batchSize,
    $core.int? comboCount,
    $core.int? rank,
    $fixnum.Int64? expireDuration,
    $fixnum.Int64? clientTimestamp,
    $fixnum.Int64? slotDisplayDuration,
    $core.int? starLevel,
    StyleType? styleType,
    WebLiveAssistantType? liveAssistantType,
    $core.String? deviceHash,
    $core.bool? danmakuDisplay,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (user != null) {
      $result.user = user;
    }
    if (time != null) {
      $result.time = time;
    }
    if (giftId != null) {
      $result.giftId = giftId;
    }
    if (sortRank != null) {
      $result.sortRank = sortRank;
    }
    if (mergeKey != null) {
      $result.mergeKey = mergeKey;
    }
    if (batchSize != null) {
      $result.batchSize = batchSize;
    }
    if (comboCount != null) {
      $result.comboCount = comboCount;
    }
    if (rank != null) {
      $result.rank = rank;
    }
    if (expireDuration != null) {
      $result.expireDuration = expireDuration;
    }
    if (clientTimestamp != null) {
      $result.clientTimestamp = clientTimestamp;
    }
    if (slotDisplayDuration != null) {
      $result.slotDisplayDuration = slotDisplayDuration;
    }
    if (starLevel != null) {
      $result.starLevel = starLevel;
    }
    if (styleType != null) {
      $result.styleType = styleType;
    }
    if (liveAssistantType != null) {
      $result.liveAssistantType = liveAssistantType;
    }
    if (deviceHash != null) {
      $result.deviceHash = deviceHash;
    }
    if (danmakuDisplay != null) {
      $result.danmakuDisplay = danmakuDisplay;
    }
    return $result;
  }
  WebGiftFeed._() : super();
  factory WebGiftFeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebGiftFeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebGiftFeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<SimpleUserInfo>(2, _omitFieldNames ? '' : 'user', subBuilder: SimpleUserInfo.create)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'time', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'giftId', $pb.PbFieldType.OU3, protoName: 'giftId')
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'sortRank', $pb.PbFieldType.OU6, protoName: 'sortRank', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'mergeKey', protoName: 'mergeKey')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'batchSize', $pb.PbFieldType.OU3, protoName: 'batchSize')
    ..a<$core.int>(8, _omitFieldNames ? '' : 'comboCount', $pb.PbFieldType.OU3, protoName: 'comboCount')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'rank', $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(10, _omitFieldNames ? '' : 'expireDuration', $pb.PbFieldType.OU6, protoName: 'expireDuration', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(11, _omitFieldNames ? '' : 'clientTimestamp', $pb.PbFieldType.OU6, protoName: 'clientTimestamp', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(12, _omitFieldNames ? '' : 'slotDisplayDuration', $pb.PbFieldType.OU6, protoName: 'slotDisplayDuration', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(13, _omitFieldNames ? '' : 'starLevel', $pb.PbFieldType.OU3, protoName: 'starLevel')
    ..e<StyleType>(14, _omitFieldNames ? '' : 'styleType', $pb.PbFieldType.OE, protoName: 'styleType', defaultOrMaker: StyleType.UNKNOWN_STYLE, valueOf: StyleType.valueOf, enumValues: StyleType.values)
    ..e<WebLiveAssistantType>(15, _omitFieldNames ? '' : 'liveAssistantType', $pb.PbFieldType.OE, protoName: 'liveAssistantType', defaultOrMaker: WebLiveAssistantType.WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE, valueOf: WebLiveAssistantType.valueOf, enumValues: WebLiveAssistantType.values)
    ..aOS(16, _omitFieldNames ? '' : 'deviceHash', protoName: 'deviceHash')
    ..aOB(17, _omitFieldNames ? '' : 'danmakuDisplay', protoName: 'danmakuDisplay')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebGiftFeed clone() => WebGiftFeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebGiftFeed copyWith(void Function(WebGiftFeed) updates) => super.copyWith((message) => updates(message as WebGiftFeed)) as WebGiftFeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebGiftFeed create() => WebGiftFeed._();
  WebGiftFeed createEmptyInstance() => create();
  static $pb.PbList<WebGiftFeed> createRepeated() => $pb.PbList<WebGiftFeed>();
  @$core.pragma('dart2js:noInline')
  static WebGiftFeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebGiftFeed>(create);
  static WebGiftFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  SimpleUserInfo get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(SimpleUserInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => clearField(2);
  @$pb.TagNumber(2)
  SimpleUserInfo ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get time => $_getI64(2);
  @$pb.TagNumber(3)
  set time($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearTime() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get giftId => $_getIZ(3);
  @$pb.TagNumber(4)
  set giftId($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasGiftId() => $_has(3);
  @$pb.TagNumber(4)
  void clearGiftId() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get sortRank => $_getI64(4);
  @$pb.TagNumber(5)
  set sortRank($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSortRank() => $_has(4);
  @$pb.TagNumber(5)
  void clearSortRank() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get mergeKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set mergeKey($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasMergeKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearMergeKey() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get batchSize => $_getIZ(6);
  @$pb.TagNumber(7)
  set batchSize($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasBatchSize() => $_has(6);
  @$pb.TagNumber(7)
  void clearBatchSize() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get comboCount => $_getIZ(7);
  @$pb.TagNumber(8)
  set comboCount($core.int v) { $_setUnsignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasComboCount() => $_has(7);
  @$pb.TagNumber(8)
  void clearComboCount() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get rank => $_getIZ(8);
  @$pb.TagNumber(9)
  set rank($core.int v) { $_setUnsignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasRank() => $_has(8);
  @$pb.TagNumber(9)
  void clearRank() => clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get expireDuration => $_getI64(9);
  @$pb.TagNumber(10)
  set expireDuration($fixnum.Int64 v) { $_setInt64(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasExpireDuration() => $_has(9);
  @$pb.TagNumber(10)
  void clearExpireDuration() => clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get clientTimestamp => $_getI64(10);
  @$pb.TagNumber(11)
  set clientTimestamp($fixnum.Int64 v) { $_setInt64(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasClientTimestamp() => $_has(10);
  @$pb.TagNumber(11)
  void clearClientTimestamp() => clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get slotDisplayDuration => $_getI64(11);
  @$pb.TagNumber(12)
  set slotDisplayDuration($fixnum.Int64 v) { $_setInt64(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasSlotDisplayDuration() => $_has(11);
  @$pb.TagNumber(12)
  void clearSlotDisplayDuration() => clearField(12);

  @$pb.TagNumber(13)
  $core.int get starLevel => $_getIZ(12);
  @$pb.TagNumber(13)
  set starLevel($core.int v) { $_setUnsignedInt32(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasStarLevel() => $_has(12);
  @$pb.TagNumber(13)
  void clearStarLevel() => clearField(13);

  @$pb.TagNumber(14)
  StyleType get styleType => $_getN(13);
  @$pb.TagNumber(14)
  set styleType(StyleType v) { setField(14, v); }
  @$pb.TagNumber(14)
  $core.bool hasStyleType() => $_has(13);
  @$pb.TagNumber(14)
  void clearStyleType() => clearField(14);

  @$pb.TagNumber(15)
  WebLiveAssistantType get liveAssistantType => $_getN(14);
  @$pb.TagNumber(15)
  set liveAssistantType(WebLiveAssistantType v) { setField(15, v); }
  @$pb.TagNumber(15)
  $core.bool hasLiveAssistantType() => $_has(14);
  @$pb.TagNumber(15)
  void clearLiveAssistantType() => clearField(15);

  @$pb.TagNumber(16)
  $core.String get deviceHash => $_getSZ(15);
  @$pb.TagNumber(16)
  set deviceHash($core.String v) { $_setString(15, v); }
  @$pb.TagNumber(16)
  $core.bool hasDeviceHash() => $_has(15);
  @$pb.TagNumber(16)
  void clearDeviceHash() => clearField(16);

  @$pb.TagNumber(17)
  $core.bool get danmakuDisplay => $_getBF(16);
  @$pb.TagNumber(17)
  set danmakuDisplay($core.bool v) { $_setBool(16, v); }
  @$pb.TagNumber(17)
  $core.bool hasDanmakuDisplay() => $_has(16);
  @$pb.TagNumber(17)
  void clearDanmakuDisplay() => clearField(17);
}

class WebLikeFeed extends $pb.GeneratedMessage {
  factory WebLikeFeed({
    $core.String? id,
    SimpleUserInfo? user,
    $fixnum.Int64? sortRank,
    $core.String? deviceHash,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (user != null) {
      $result.user = user;
    }
    if (sortRank != null) {
      $result.sortRank = sortRank;
    }
    if (deviceHash != null) {
      $result.deviceHash = deviceHash;
    }
    return $result;
  }
  WebLikeFeed._() : super();
  factory WebLikeFeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebLikeFeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebLikeFeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<SimpleUserInfo>(2, _omitFieldNames ? '' : 'user', subBuilder: SimpleUserInfo.create)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'sortRank', $pb.PbFieldType.OU6, protoName: 'sortRank', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'deviceHash', protoName: 'deviceHash')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebLikeFeed clone() => WebLikeFeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebLikeFeed copyWith(void Function(WebLikeFeed) updates) => super.copyWith((message) => updates(message as WebLikeFeed)) as WebLikeFeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebLikeFeed create() => WebLikeFeed._();
  WebLikeFeed createEmptyInstance() => create();
  static $pb.PbList<WebLikeFeed> createRepeated() => $pb.PbList<WebLikeFeed>();
  @$core.pragma('dart2js:noInline')
  static WebLikeFeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebLikeFeed>(create);
  static WebLikeFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  SimpleUserInfo get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(SimpleUserInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => clearField(2);
  @$pb.TagNumber(2)
  SimpleUserInfo ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sortRank => $_getI64(2);
  @$pb.TagNumber(3)
  set sortRank($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSortRank() => $_has(2);
  @$pb.TagNumber(3)
  void clearSortRank() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceHash => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceHash($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDeviceHash() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceHash() => clearField(4);
}

class WebComboCommentFeed extends $pb.GeneratedMessage {
  factory WebComboCommentFeed({
    $core.String? id,
    $core.String? content,
    $core.int? comboCount,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (content != null) {
      $result.content = content;
    }
    if (comboCount != null) {
      $result.comboCount = comboCount;
    }
    return $result;
  }
  WebComboCommentFeed._() : super();
  factory WebComboCommentFeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WebComboCommentFeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WebComboCommentFeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'kuaishouPubf'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'content')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'comboCount', $pb.PbFieldType.OU3, protoName: 'comboCount')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WebComboCommentFeed clone() => WebComboCommentFeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WebComboCommentFeed copyWith(void Function(WebComboCommentFeed) updates) => super.copyWith((message) => updates(message as WebComboCommentFeed)) as WebComboCommentFeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebComboCommentFeed create() => WebComboCommentFeed._();
  WebComboCommentFeed createEmptyInstance() => create();
  static $pb.PbList<WebComboCommentFeed> createRepeated() => $pb.PbList<WebComboCommentFeed>();
  @$core.pragma('dart2js:noInline')
  static WebComboCommentFeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WebComboCommentFeed>(create);
  static WebComboCommentFeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get content => $_getSZ(1);
  @$pb.TagNumber(2)
  set content($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearContent() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get comboCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set comboCount($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasComboCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearComboCount() => clearField(3);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
