// This is a generated file - do not edit.
//
// Generated from bilibili/app/playerunite/v1/playerunite.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart' as $2;

import '../../../playershared/playershared.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PlayViewUniteReq extends $pb.GeneratedMessage {
  factory PlayViewUniteReq({
    $1.VideoVod? vod,
    $core.String? spmid,
    $core.String? fromSpmid,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extraContent,
    $core.String? bvid,
  }) {
    final result = PlayViewUniteReq._();
    if (vod != null) result.vod = vod;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (extraContent != null) result.extraContent.addEntries(extraContent);
    if (bvid != null) result.bvid = bvid;
    return result;
  }

  PlayViewUniteReq._();

  factory PlayViewUniteReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewUniteReq()..mergeFromBuffer(data, registry);
  factory PlayViewUniteReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewUniteReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewUniteReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.playerunite.v1'),
      createEmptyInstance: PlayViewUniteReq.$_createMessage)
    ..aOM<$1.VideoVod>(1, _omitFieldNames ? '' : 'vod',
        subBuilder: $1.VideoVod.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'spmid')
    ..aOS(3, _omitFieldNames ? '' : 'fromSpmid')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'extraContent',
        entryClassName: 'PlayViewUniteReq.ExtraContentEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bilibili.app.playerunite.v1'))
    ..aOS(5, _omitFieldNames ? '' : 'bvid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReq copyWith(void Function(PlayViewUniteReq) updates) =>
      super.copyWith((message) => updates(message as PlayViewUniteReq))
          as PlayViewUniteReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayViewUniteReq() / PlayViewUniteReq.new instead')
  static PlayViewUniteReq create() => PlayViewUniteReq._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewUniteReq._();
  @$core.override
  PlayViewUniteReq createEmptyInstance() => PlayViewUniteReq._();
  @$core.pragma('dart2js:noInline')
  static PlayViewUniteReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayViewUniteReq>(
          PlayViewUniteReq.$_createMessage);
  static PlayViewUniteReq? _defaultInstance;

  /// 请求资源VOD信息
  @$pb.TagNumber(1)
  $1.VideoVod get vod => $_getN(0);
  @$pb.TagNumber(1)
  set vod($1.VideoVod value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVod() => $_has(0);
  @$pb.TagNumber(1)
  void clearVod() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.VideoVod ensureVod() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get spmid => $_getSZ(1);
  @$pb.TagNumber(2)
  set spmid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSpmid() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpmid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fromSpmid => $_getSZ(2);
  @$pb.TagNumber(3)
  set fromSpmid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFromSpmid() => $_has(2);
  @$pb.TagNumber(3)
  void clearFromSpmid() => $_clearField(3);

  /// 补充信息, 如ep_id等
  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get extraContent => $_getMap(3);

  @$pb.TagNumber(5)
  $core.String get bvid => $_getSZ(4);
  @$pb.TagNumber(5)
  set bvid($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBvid() => $_has(4);
  @$pb.TagNumber(5)
  void clearBvid() => $_clearField(5);
}

class PlayViewUniteReply extends $pb.GeneratedMessage {
  factory PlayViewUniteReply({
    $1.VodInfo? vodInfo,
    $1.PlayArcConf? playArcConf,
    $1.PlayDeviceConf? playDeviceConf,
    $1.Event? event,
    $2.Any? supplement,
    $1.PlayArc? playArc,
    $1.QnTrialInfo? qnTrialInfo,
    $1.History? history,
    $1.ViewInfo? viewInfo,
  }) {
    final result = PlayViewUniteReply._();
    if (vodInfo != null) result.vodInfo = vodInfo;
    if (playArcConf != null) result.playArcConf = playArcConf;
    if (playDeviceConf != null) result.playDeviceConf = playDeviceConf;
    if (event != null) result.event = event;
    if (supplement != null) result.supplement = supplement;
    if (playArc != null) result.playArc = playArc;
    if (qnTrialInfo != null) result.qnTrialInfo = qnTrialInfo;
    if (history != null) result.history = history;
    if (viewInfo != null) result.viewInfo = viewInfo;
    return result;
  }

  PlayViewUniteReply._();

  factory PlayViewUniteReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewUniteReply()..mergeFromBuffer(data, registry);
  factory PlayViewUniteReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewUniteReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewUniteReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.playerunite.v1'),
      createEmptyInstance: PlayViewUniteReply.$_createMessage)
    ..aOM<$1.VodInfo>(1, _omitFieldNames ? '' : 'vodInfo',
        subBuilder: $1.VodInfo.$_createMessage)
    ..aOM<$1.PlayArcConf>(2, _omitFieldNames ? '' : 'playArcConf',
        subBuilder: $1.PlayArcConf.$_createMessage)
    ..aOM<$1.PlayDeviceConf>(3, _omitFieldNames ? '' : 'playDeviceConf',
        subBuilder: $1.PlayDeviceConf.$_createMessage)
    ..aOM<$1.Event>(4, _omitFieldNames ? '' : 'event',
        subBuilder: $1.Event.$_createMessage)
    ..aOM<$2.Any>(5, _omitFieldNames ? '' : 'supplement',
        subBuilder: $2.Any.$_createMessage)
    ..aOM<$1.PlayArc>(6, _omitFieldNames ? '' : 'playArc',
        subBuilder: $1.PlayArc.$_createMessage)
    ..aOM<$1.QnTrialInfo>(7, _omitFieldNames ? '' : 'qnTrialInfo',
        subBuilder: $1.QnTrialInfo.$_createMessage)
    ..aOM<$1.History>(8, _omitFieldNames ? '' : 'history',
        subBuilder: $1.History.$_createMessage)
    ..aOM<$1.ViewInfo>(9, _omitFieldNames ? '' : 'viewInfo',
        subBuilder: $1.ViewInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReply copyWith(void Function(PlayViewUniteReply) updates) =>
      super.copyWith((message) => updates(message as PlayViewUniteReply))
          as PlayViewUniteReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayViewUniteReply() / PlayViewUniteReply.new instead')
  static PlayViewUniteReply create() => PlayViewUniteReply._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewUniteReply._();
  @$core.override
  PlayViewUniteReply createEmptyInstance() => PlayViewUniteReply._();
  @$core.pragma('dart2js:noInline')
  static PlayViewUniteReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayViewUniteReply>(
          PlayViewUniteReply.$_createMessage);
  static PlayViewUniteReply? _defaultInstance;

  /// 音视频流信息
  @$pb.TagNumber(1)
  $1.VodInfo get vodInfo => $_getN(0);
  @$pb.TagNumber(1)
  set vodInfo($1.VodInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVodInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearVodInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.VodInfo ensureVodInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $1.PlayArcConf get playArcConf => $_getN(1);
  @$pb.TagNumber(2)
  set playArcConf($1.PlayArcConf value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPlayArcConf() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlayArcConf() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.PlayArcConf ensurePlayArcConf() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.PlayDeviceConf get playDeviceConf => $_getN(2);
  @$pb.TagNumber(3)
  set playDeviceConf($1.PlayDeviceConf value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPlayDeviceConf() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlayDeviceConf() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.PlayDeviceConf ensurePlayDeviceConf() => $_ensure(2);

  @$pb.TagNumber(4)
  $1.Event get event => $_getN(3);
  @$pb.TagNumber(4)
  set event($1.Event value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasEvent() => $_has(3);
  @$pb.TagNumber(4)
  void clearEvent() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Event ensureEvent() => $_ensure(3);

  /// 使用 pgcanymodel / ugcanymodel 进行proto any转换成对应业务码结构体
  @$pb.TagNumber(5)
  $2.Any get supplement => $_getN(4);
  @$pb.TagNumber(5)
  set supplement($2.Any value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSupplement() => $_has(4);
  @$pb.TagNumber(5)
  void clearSupplement() => $_clearField(5);
  @$pb.TagNumber(5)
  $2.Any ensureSupplement() => $_ensure(4);

  @$pb.TagNumber(6)
  $1.PlayArc get playArc => $_getN(5);
  @$pb.TagNumber(6)
  set playArc($1.PlayArc value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlayArc() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlayArc() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.PlayArc ensurePlayArc() => $_ensure(5);

  @$pb.TagNumber(7)
  $1.QnTrialInfo get qnTrialInfo => $_getN(6);
  @$pb.TagNumber(7)
  set qnTrialInfo($1.QnTrialInfo value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasQnTrialInfo() => $_has(6);
  @$pb.TagNumber(7)
  void clearQnTrialInfo() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.QnTrialInfo ensureQnTrialInfo() => $_ensure(6);

  @$pb.TagNumber(8)
  $1.History get history => $_getN(7);
  @$pb.TagNumber(8)
  set history($1.History value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasHistory() => $_has(7);
  @$pb.TagNumber(8)
  void clearHistory() => $_clearField(8);
  @$pb.TagNumber(8)
  $1.History ensureHistory() => $_ensure(7);

  @$pb.TagNumber(9)
  $1.ViewInfo get viewInfo => $_getN(8);
  @$pb.TagNumber(9)
  set viewInfo($1.ViewInfo value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasViewInfo() => $_has(8);
  @$pb.TagNumber(9)
  void clearViewInfo() => $_clearField(9);
  @$pb.TagNumber(9)
  $1.ViewInfo ensureViewInfo() => $_ensure(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
