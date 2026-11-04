// This is a generated file - do not edit.
//
// Generated from bilibili/pgc/gateway/player/v2/playurl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $1;

import 'playurl.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'playurl.pbenum.dart';

class Animation extends $pb.GeneratedMessage {
  factory Animation({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        qnSvgaAnimationMap,
  }) {
    final result = Animation._();
    if (qnSvgaAnimationMap != null)
      result.qnSvgaAnimationMap.addEntries(qnSvgaAnimationMap);
    return result;
  }

  Animation._();

  factory Animation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Animation()..mergeFromBuffer(data, registry);
  factory Animation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Animation()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Animation',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Animation.$_createMessage)
    ..m<$core.String, $core.String>(
        1, _omitFieldNames ? '' : 'qnSvgaAnimationMap',
        entryClassName: 'Animation.QnSvgaAnimationMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Animation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Animation copyWith(void Function(Animation) updates) =>
      super.copyWith((message) => updates(message as Animation)) as Animation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Animation() / Animation.new instead')
  static Animation create() => Animation._();
  static $pb.GeneratedMessage $_createMessage() => Animation._();
  @$core.override
  Animation createEmptyInstance() => Animation._();
  @$core.pragma('dart2js:noInline')
  static Animation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Animation>(Animation.$_createMessage);
  static Animation? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get qnSvgaAnimationMap => $_getMap(0);
}

class AudioMaterialProto extends $pb.GeneratedMessage {
  factory AudioMaterialProto({
    $core.String? audioId,
    $core.String? title,
    $core.String? edition,
    $fixnum.Int64? personId,
    $core.String? personName,
    $core.String? personAvatar,
    $core.Iterable<DashItem>? audio,
  }) {
    final result = AudioMaterialProto._();
    if (audioId != null) result.audioId = audioId;
    if (title != null) result.title = title;
    if (edition != null) result.edition = edition;
    if (personId != null) result.personId = personId;
    if (personName != null) result.personName = personName;
    if (personAvatar != null) result.personAvatar = personAvatar;
    if (audio != null) result.audio.addAll(audio);
    return result;
  }

  AudioMaterialProto._();

  factory AudioMaterialProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AudioMaterialProto()..mergeFromBuffer(data, registry);
  factory AudioMaterialProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AudioMaterialProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AudioMaterialProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: AudioMaterialProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'audioId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'edition')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'personId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(5, _omitFieldNames ? '' : 'personName')
    ..aOS(6, _omitFieldNames ? '' : 'personAvatar')
    ..pPM<DashItem>(7, _omitFieldNames ? '' : 'audio',
        subBuilder: DashItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioMaterialProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioMaterialProto copyWith(void Function(AudioMaterialProto) updates) =>
      super.copyWith((message) => updates(message as AudioMaterialProto))
          as AudioMaterialProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AudioMaterialProto() / AudioMaterialProto.new instead')
  static AudioMaterialProto create() => AudioMaterialProto._();
  static $pb.GeneratedMessage $_createMessage() => AudioMaterialProto._();
  @$core.override
  AudioMaterialProto createEmptyInstance() => AudioMaterialProto._();
  @$core.pragma('dart2js:noInline')
  static AudioMaterialProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AudioMaterialProto>(
          AudioMaterialProto.$_createMessage);
  static AudioMaterialProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get audioId => $_getSZ(0);
  @$pb.TagNumber(1)
  set audioId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAudioId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAudioId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get edition => $_getSZ(2);
  @$pb.TagNumber(3)
  set edition($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEdition() => $_has(2);
  @$pb.TagNumber(3)
  void clearEdition() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get personId => $_getI64(3);
  @$pb.TagNumber(4)
  set personId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPersonId() => $_has(3);
  @$pb.TagNumber(4)
  void clearPersonId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get personName => $_getSZ(4);
  @$pb.TagNumber(5)
  set personName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPersonName() => $_has(4);
  @$pb.TagNumber(5)
  void clearPersonName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get personAvatar => $_getSZ(5);
  @$pb.TagNumber(6)
  set personAvatar($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPersonAvatar() => $_has(5);
  @$pb.TagNumber(6)
  void clearPersonAvatar() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<DashItem> get audio => $_getList(6);
}

/// 角标信息
class BadgeInfo extends $pb.GeneratedMessage {
  factory BadgeInfo({
    $core.String? text,
    $core.String? bgColor,
    $core.String? bgColorNight,
    $core.String? textColor,
    GradientColor? bgGradientColor,
    $core.String? img,
  }) {
    final result = BadgeInfo._();
    if (text != null) result.text = text;
    if (bgColor != null) result.bgColor = bgColor;
    if (bgColorNight != null) result.bgColorNight = bgColorNight;
    if (textColor != null) result.textColor = textColor;
    if (bgGradientColor != null) result.bgGradientColor = bgGradientColor;
    if (img != null) result.img = img;
    return result;
  }

  BadgeInfo._();

  factory BadgeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BadgeInfo()..mergeFromBuffer(data, registry);
  factory BadgeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BadgeInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BadgeInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: BadgeInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'bgColor')
    ..aOS(3, _omitFieldNames ? '' : 'bgColorNight')
    ..aOS(4, _omitFieldNames ? '' : 'textColor')
    ..aOM<GradientColor>(5, _omitFieldNames ? '' : 'bgGradientColor',
        subBuilder: GradientColor.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'img')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BadgeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BadgeInfo copyWith(void Function(BadgeInfo) updates) =>
      super.copyWith((message) => updates(message as BadgeInfo)) as BadgeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BadgeInfo() / BadgeInfo.new instead')
  static BadgeInfo create() => BadgeInfo._();
  static $pb.GeneratedMessage $_createMessage() => BadgeInfo._();
  @$core.override
  BadgeInfo createEmptyInstance() => BadgeInfo._();
  @$core.pragma('dart2js:noInline')
  static BadgeInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BadgeInfo>(BadgeInfo.$_createMessage);
  static BadgeInfo? _defaultInstance;

  /// 角标文案
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// 角标色值
  @$pb.TagNumber(2)
  $core.String get bgColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set bgColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBgColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearBgColor() => $_clearField(2);

  /// 角标色值-夜间模式
  @$pb.TagNumber(3)
  $core.String get bgColorNight => $_getSZ(2);
  @$pb.TagNumber(3)
  set bgColorNight($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBgColorNight() => $_has(2);
  @$pb.TagNumber(3)
  void clearBgColorNight() => $_clearField(3);

  /// 文案色值
  @$pb.TagNumber(4)
  $core.String get textColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set textColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTextColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearTextColor() => $_clearField(4);

  /// ? 新版本客户端已弃用此项
  @$pb.TagNumber(5)
  GradientColor get bgGradientColor => $_getN(4);
  @$pb.TagNumber(5)
  set bgGradientColor(GradientColor value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBgGradientColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearBgGradientColor() => $_clearField(5);
  @$pb.TagNumber(5)
  GradientColor ensureBgGradientColor() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get img => $_getSZ(5);
  @$pb.TagNumber(6)
  set img($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImg() => $_has(5);
  @$pb.TagNumber(6)
  void clearImg() => $_clearField(6);
}

/// Dialog组件: 底部显示
class BottomDisplay extends $pb.GeneratedMessage {
  factory BottomDisplay({
    TextInfo? title,
    $core.String? icon,
  }) {
    final result = BottomDisplay._();
    if (title != null) result.title = title;
    if (icon != null) result.icon = icon;
    return result;
  }

  BottomDisplay._();

  factory BottomDisplay.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BottomDisplay()..mergeFromBuffer(data, registry);
  factory BottomDisplay.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BottomDisplay()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BottomDisplay',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: BottomDisplay.$_createMessage)
    ..aOM<TextInfo>(1, _omitFieldNames ? '' : 'title',
        subBuilder: TextInfo.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'icon')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BottomDisplay clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BottomDisplay copyWith(void Function(BottomDisplay) updates) =>
      super.copyWith((message) => updates(message as BottomDisplay))
          as BottomDisplay;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BottomDisplay() / BottomDisplay.new instead')
  static BottomDisplay create() => BottomDisplay._();
  static $pb.GeneratedMessage $_createMessage() => BottomDisplay._();
  @$core.override
  BottomDisplay createEmptyInstance() => BottomDisplay._();
  @$core.pragma('dart2js:noInline')
  static BottomDisplay getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BottomDisplay>(
          BottomDisplay.$_createMessage);
  static BottomDisplay? _defaultInstance;

  /// 文案
  @$pb.TagNumber(1)
  TextInfo get title => $_getN(0);
  @$pb.TagNumber(1)
  set title(TextInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);
  @$pb.TagNumber(1)
  TextInfo ensureTitle() => $_ensure(0);

  /// 图标
  @$pb.TagNumber(2)
  $core.String get icon => $_getSZ(1);
  @$pb.TagNumber(2)
  set icon($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearIcon() => $_clearField(2);
}

/// 按钮信息
class ButtonInfo extends $pb.GeneratedMessage {
  factory ButtonInfo({
    $core.String? text,
    $core.String? textColor,
    $core.String? textColorNight,
    $core.String? bgColor,
    $core.String? bgColorNight,
    $core.String? link,
    $core.String? actionType,
    BadgeInfo? badgeInfo,
    Report? report,
    $core.String? leftStrikethroughText,
    TextInfo? simpleTextInfo,
    $core.String? simpleBgColor,
    $core.String? simpleBgColorNight,
    GradientColor? bgGradientColor,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        orderReportParams,
    TaskParam? taskParam,
    $core.String? pcLink,
  }) {
    final result = ButtonInfo._();
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    if (bgColor != null) result.bgColor = bgColor;
    if (bgColorNight != null) result.bgColorNight = bgColorNight;
    if (link != null) result.link = link;
    if (actionType != null) result.actionType = actionType;
    if (badgeInfo != null) result.badgeInfo = badgeInfo;
    if (report != null) result.report = report;
    if (leftStrikethroughText != null)
      result.leftStrikethroughText = leftStrikethroughText;
    if (simpleTextInfo != null) result.simpleTextInfo = simpleTextInfo;
    if (simpleBgColor != null) result.simpleBgColor = simpleBgColor;
    if (simpleBgColorNight != null)
      result.simpleBgColorNight = simpleBgColorNight;
    if (bgGradientColor != null) result.bgGradientColor = bgGradientColor;
    if (orderReportParams != null)
      result.orderReportParams.addEntries(orderReportParams);
    if (taskParam != null) result.taskParam = taskParam;
    if (pcLink != null) result.pcLink = pcLink;
    return result;
  }

  ButtonInfo._();

  factory ButtonInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ButtonInfo()..mergeFromBuffer(data, registry);
  factory ButtonInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ButtonInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ButtonInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: ButtonInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'textColor')
    ..aOS(3, _omitFieldNames ? '' : 'textColorNight')
    ..aOS(4, _omitFieldNames ? '' : 'bgColor')
    ..aOS(5, _omitFieldNames ? '' : 'bgColorNight')
    ..aOS(6, _omitFieldNames ? '' : 'link')
    ..aOS(7, _omitFieldNames ? '' : 'actionType')
    ..aOM<BadgeInfo>(8, _omitFieldNames ? '' : 'badgeInfo',
        subBuilder: BadgeInfo.$_createMessage)
    ..aOM<Report>(9, _omitFieldNames ? '' : 'report',
        subBuilder: Report.$_createMessage)
    ..aOS(10, _omitFieldNames ? '' : 'leftStrikethroughText')
    ..aOM<TextInfo>(11, _omitFieldNames ? '' : 'simpleTextInfo',
        subBuilder: TextInfo.$_createMessage)
    ..aOS(12, _omitFieldNames ? '' : 'simpleBgColor')
    ..aOS(13, _omitFieldNames ? '' : 'simpleBgColorNight')
    ..aOM<GradientColor>(14, _omitFieldNames ? '' : 'bgGradientColor',
        subBuilder: GradientColor.$_createMessage)
    ..m<$core.String, $core.String>(
        15, _omitFieldNames ? '' : 'orderReportParams',
        entryClassName: 'ButtonInfo.OrderReportParamsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..aOM<TaskParam>(16, _omitFieldNames ? '' : 'taskParam',
        subBuilder: TaskParam.$_createMessage)
    ..aOS(17, _omitFieldNames ? '' : 'pcLink')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ButtonInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ButtonInfo copyWith(void Function(ButtonInfo) updates) =>
      super.copyWith((message) => updates(message as ButtonInfo)) as ButtonInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ButtonInfo() / ButtonInfo.new instead')
  static ButtonInfo create() => ButtonInfo._();
  static $pb.GeneratedMessage $_createMessage() => ButtonInfo._();
  @$core.override
  ButtonInfo createEmptyInstance() => ButtonInfo._();
  @$core.pragma('dart2js:noInline')
  static ButtonInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ButtonInfo>(ButtonInfo.$_createMessage);
  static ButtonInfo? _defaultInstance;

  /// 按钮文案
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// 按钮字体色值
  @$pb.TagNumber(2)
  $core.String get textColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set textColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTextColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearTextColor() => $_clearField(2);

  /// 按钮字体色值-夜间模式
  @$pb.TagNumber(3)
  $core.String get textColorNight => $_getSZ(2);
  @$pb.TagNumber(3)
  set textColorNight($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTextColorNight() => $_has(2);
  @$pb.TagNumber(3)
  void clearTextColorNight() => $_clearField(3);

  /// 按钮背景色
  @$pb.TagNumber(4)
  $core.String get bgColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set bgColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBgColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearBgColor() => $_clearField(4);

  /// 按钮背景色-夜间模式
  @$pb.TagNumber(5)
  $core.String get bgColorNight => $_getSZ(4);
  @$pb.TagNumber(5)
  set bgColorNight($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBgColorNight() => $_has(4);
  @$pb.TagNumber(5)
  void clearBgColorNight() => $_clearField(5);

  /// 按钮链接
  @$pb.TagNumber(6)
  $core.String get link => $_getSZ(5);
  @$pb.TagNumber(6)
  set link($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLink() => $_has(5);
  @$pb.TagNumber(6)
  void clearLink() => $_clearField(6);

  /// 按钮动作类型
  @$pb.TagNumber(7)
  $core.String get actionType => $_getSZ(6);
  @$pb.TagNumber(7)
  set actionType($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasActionType() => $_has(6);
  @$pb.TagNumber(7)
  void clearActionType() => $_clearField(7);

  /// 角标信息
  @$pb.TagNumber(8)
  BadgeInfo get badgeInfo => $_getN(7);
  @$pb.TagNumber(8)
  set badgeInfo(BadgeInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasBadgeInfo() => $_has(7);
  @$pb.TagNumber(8)
  void clearBadgeInfo() => $_clearField(8);
  @$pb.TagNumber(8)
  BadgeInfo ensureBadgeInfo() => $_ensure(7);

  /// 埋点上报信息
  @$pb.TagNumber(9)
  Report get report => $_getN(8);
  @$pb.TagNumber(9)
  set report(Report value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasReport() => $_has(8);
  @$pb.TagNumber(9)
  void clearReport() => $_clearField(9);
  @$pb.TagNumber(9)
  Report ensureReport() => $_ensure(8);

  /// 左侧删除线样式文案
  @$pb.TagNumber(10)
  $core.String get leftStrikethroughText => $_getSZ(9);
  @$pb.TagNumber(10)
  set leftStrikethroughText($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLeftStrikethroughText() => $_has(9);
  @$pb.TagNumber(10)
  void clearLeftStrikethroughText() => $_clearField(10);

  /// 缩略按钮文案信息
  @$pb.TagNumber(11)
  TextInfo get simpleTextInfo => $_getN(10);
  @$pb.TagNumber(11)
  set simpleTextInfo(TextInfo value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSimpleTextInfo() => $_has(10);
  @$pb.TagNumber(11)
  void clearSimpleTextInfo() => $_clearField(11);
  @$pb.TagNumber(11)
  TextInfo ensureSimpleTextInfo() => $_ensure(10);

  /// 缩略按钮背景色值
  @$pb.TagNumber(12)
  $core.String get simpleBgColor => $_getSZ(11);
  @$pb.TagNumber(12)
  set simpleBgColor($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSimpleBgColor() => $_has(11);
  @$pb.TagNumber(12)
  void clearSimpleBgColor() => $_clearField(12);

  /// 缩略按钮字体色值-夜间模式
  @$pb.TagNumber(13)
  $core.String get simpleBgColorNight => $_getSZ(12);
  @$pb.TagNumber(13)
  set simpleBgColorNight($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasSimpleBgColorNight() => $_has(12);
  @$pb.TagNumber(13)
  void clearSimpleBgColorNight() => $_clearField(13);

  @$pb.TagNumber(14)
  GradientColor get bgGradientColor => $_getN(13);
  @$pb.TagNumber(14)
  set bgGradientColor(GradientColor value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasBgGradientColor() => $_has(13);
  @$pb.TagNumber(14)
  void clearBgGradientColor() => $_clearField(14);
  @$pb.TagNumber(14)
  GradientColor ensureBgGradientColor() => $_ensure(13);

  @$pb.TagNumber(15)
  $pb.PbMap<$core.String, $core.String> get orderReportParams => $_getMap(14);

  @$pb.TagNumber(16)
  TaskParam get taskParam => $_getN(15);
  @$pb.TagNumber(16)
  set taskParam(TaskParam value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasTaskParam() => $_has(15);
  @$pb.TagNumber(16)
  void clearTaskParam() => $_clearField(16);
  @$pb.TagNumber(16)
  TaskParam ensureTaskParam() => $_ensure(15);

  @$pb.TagNumber(17)
  $core.String get pcLink => $_getSZ(16);
  @$pb.TagNumber(17)
  set pcLink($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasPcLink() => $_has(16);
  @$pb.TagNumber(17)
  void clearPcLink() => $_clearField(17);
}

/// 投屏限制. code = 0 时为无限制, 否则表示不不允许投屏并提示message
class CastTips extends $pb.GeneratedMessage {
  factory CastTips({
    $core.int? code,
    $core.String? message,
  }) {
    final result = CastTips._();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  CastTips._();

  factory CastTips.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CastTips()..mergeFromBuffer(data, registry);
  factory CastTips.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CastTips()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CastTips',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: CastTips.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CastTips clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CastTips copyWith(void Function(CastTips) updates) =>
      super.copyWith((message) => updates(message as CastTips)) as CastTips;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CastTips() / CastTips.new instead')
  static CastTips create() => CastTips._();
  static $pb.GeneratedMessage $_createMessage() => CastTips._();
  @$core.override
  CastTips createEmptyInstance() => CastTips._();
  @$core.pragma('dart2js:noInline')
  static CastTips getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CastTips>(CastTips.$_createMessage);
  static CastTips? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

/// 跳过片头/片尾配置
class ClipInfo extends $pb.GeneratedMessage {
  factory ClipInfo({
    $fixnum.Int64? materialNo,
    $core.int? start,
    $core.int? end,
    ClipType? clipType,
    $core.String? toastText,
    MultiView? multiView,
  }) {
    final result = ClipInfo._();
    if (materialNo != null) result.materialNo = materialNo;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (clipType != null) result.clipType = clipType;
    if (toastText != null) result.toastText = toastText;
    if (multiView != null) result.multiView = multiView;
    return result;
  }

  ClipInfo._();

  factory ClipInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClipInfo()..mergeFromBuffer(data, registry);
  factory ClipInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClipInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: ClipInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'materialNo')
    ..aI(2, _omitFieldNames ? '' : 'start')
    ..aI(3, _omitFieldNames ? '' : 'end')
    ..aE<ClipType>(4, _omitFieldNames ? '' : 'clipType',
        enumValues: ClipType.values)
    ..aOS(5, _omitFieldNames ? '' : 'toastText')
    ..aOM<MultiView>(6, _omitFieldNames ? '' : 'multiView',
        subBuilder: MultiView.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipInfo copyWith(void Function(ClipInfo) updates) =>
      super.copyWith((message) => updates(message as ClipInfo)) as ClipInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ClipInfo() / ClipInfo.new instead')
  static ClipInfo create() => ClipInfo._();
  static $pb.GeneratedMessage $_createMessage() => ClipInfo._();
  @$core.override
  ClipInfo createEmptyInstance() => ClipInfo._();
  @$core.pragma('dart2js:noInline')
  static ClipInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipInfo>(ClipInfo.$_createMessage);
  static ClipInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get materialNo => $_getI64(0);
  @$pb.TagNumber(1)
  set materialNo($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMaterialNo() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaterialNo() => $_clearField(1);

  /// DASH分段始
  @$pb.TagNumber(2)
  $core.int get start => $_getIZ(1);
  @$pb.TagNumber(2)
  set start($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearStart() => $_clearField(2);

  /// DASH分段终
  @$pb.TagNumber(3)
  $core.int get end => $_getIZ(2);
  @$pb.TagNumber(3)
  set end($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEnd() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnd() => $_clearField(3);

  /// Clip类型
  @$pb.TagNumber(4)
  ClipType get clipType => $_getN(3);
  @$pb.TagNumber(4)
  set clipType(ClipType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasClipType() => $_has(3);
  @$pb.TagNumber(4)
  void clearClipType() => $_clearField(4);

  /// 跳过片头/片尾时的提示语
  @$pb.TagNumber(5)
  $core.String get toastText => $_getSZ(4);
  @$pb.TagNumber(5)
  set toastText($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasToastText() => $_has(4);
  @$pb.TagNumber(5)
  void clearToastText() => $_clearField(5);

  @$pb.TagNumber(6)
  MultiView get multiView => $_getN(5);
  @$pb.TagNumber(6)
  set multiView(MultiView value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMultiView() => $_has(5);
  @$pb.TagNumber(6)
  void clearMultiView() => $_clearField(6);
  @$pb.TagNumber(6)
  MultiView ensureMultiView() => $_ensure(5);
}

class ContinuePlayInfo extends $pb.GeneratedMessage {
  factory ContinuePlayInfo({
    $fixnum.Int64? continuePlayEpId,
  }) {
    final result = ContinuePlayInfo._();
    if (continuePlayEpId != null) result.continuePlayEpId = continuePlayEpId;
    return result;
  }

  ContinuePlayInfo._();

  factory ContinuePlayInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinuePlayInfo()..mergeFromBuffer(data, registry);
  factory ContinuePlayInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinuePlayInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinuePlayInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: ContinuePlayInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'continuePlayEpId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinuePlayInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinuePlayInfo copyWith(void Function(ContinuePlayInfo) updates) =>
      super.copyWith((message) => updates(message as ContinuePlayInfo))
          as ContinuePlayInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContinuePlayInfo() / ContinuePlayInfo.new instead')
  static ContinuePlayInfo create() => ContinuePlayInfo._();
  static $pb.GeneratedMessage $_createMessage() => ContinuePlayInfo._();
  @$core.override
  ContinuePlayInfo createEmptyInstance() => ContinuePlayInfo._();
  @$core.pragma('dart2js:noInline')
  static ContinuePlayInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContinuePlayInfo>(
          ContinuePlayInfo.$_createMessage);
  static ContinuePlayInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get continuePlayEpId => $_getI64(0);
  @$pb.TagNumber(1)
  set continuePlayEpId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContinuePlayEpId() => $_has(0);
  @$pb.TagNumber(1)
  void clearContinuePlayEpId() => $_clearField(1);
}

/// 优惠券
class Coupon extends $pb.GeneratedMessage {
  factory Coupon({
    $core.String? couponToken,
    $fixnum.Int64? type,
    $core.String? value,
    $core.String? useDesc,
    $core.String? title,
    $core.String? desc,
    $core.String? payButtonText,
    $core.String? payButtonTextLineThrough,
    $core.String? realAmount,
    $1.Timestamp? expireTime,
    $fixnum.Int64? otype,
    $core.String? amount,
  }) {
    final result = Coupon._();
    if (couponToken != null) result.couponToken = couponToken;
    if (type != null) result.type = type;
    if (value != null) result.value = value;
    if (useDesc != null) result.useDesc = useDesc;
    if (title != null) result.title = title;
    if (desc != null) result.desc = desc;
    if (payButtonText != null) result.payButtonText = payButtonText;
    if (payButtonTextLineThrough != null)
      result.payButtonTextLineThrough = payButtonTextLineThrough;
    if (realAmount != null) result.realAmount = realAmount;
    if (expireTime != null) result.expireTime = expireTime;
    if (otype != null) result.otype = otype;
    if (amount != null) result.amount = amount;
    return result;
  }

  Coupon._();

  factory Coupon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Coupon()..mergeFromBuffer(data, registry);
  factory Coupon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Coupon()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Coupon',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Coupon.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'couponToken')
    ..aInt64(2, _omitFieldNames ? '' : 'type')
    ..aOS(3, _omitFieldNames ? '' : 'value')
    ..aOS(4, _omitFieldNames ? '' : 'useDesc')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aOS(6, _omitFieldNames ? '' : 'desc')
    ..aOS(7, _omitFieldNames ? '' : 'payButtonText')
    ..aOS(8, _omitFieldNames ? '' : 'payButtonTextLineThrough')
    ..aOS(9, _omitFieldNames ? '' : 'realAmount')
    ..aOM<$1.Timestamp>(10, _omitFieldNames ? '' : 'expireTime',
        subBuilder: $1.Timestamp.$_createMessage)
    ..aInt64(11, _omitFieldNames ? '' : 'otype')
    ..aOS(12, _omitFieldNames ? '' : 'amount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Coupon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Coupon copyWith(void Function(Coupon) updates) =>
      super.copyWith((message) => updates(message as Coupon)) as Coupon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Coupon() / Coupon.new instead')
  static Coupon create() => Coupon._();
  static $pb.GeneratedMessage $_createMessage() => Coupon._();
  @$core.override
  Coupon createEmptyInstance() => Coupon._();
  @$core.pragma('dart2js:noInline')
  static Coupon getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Coupon>(Coupon.$_createMessage);
  static Coupon? _defaultInstance;

  /// 优惠券token
  @$pb.TagNumber(1)
  $core.String get couponToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set couponToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCouponToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearCouponToken() => $_clearField(1);

  /// 优惠券类型
  /// 1:折扣券 2:满减券 3:兑换券
  @$pb.TagNumber(2)
  $fixnum.Int64 get type => $_getI64(1);
  @$pb.TagNumber(2)
  set type($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  /// 优惠券面值
  @$pb.TagNumber(3)
  $core.String get value => $_getSZ(2);
  @$pb.TagNumber(3)
  set value($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);

  /// 优惠券使用描述
  @$pb.TagNumber(4)
  $core.String get useDesc => $_getSZ(3);
  @$pb.TagNumber(4)
  set useDesc($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUseDesc() => $_has(3);
  @$pb.TagNumber(4)
  void clearUseDesc() => $_clearField(4);

  /// 优惠券标题
  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  /// 优惠券描述
  @$pb.TagNumber(6)
  $core.String get desc => $_getSZ(5);
  @$pb.TagNumber(6)
  set desc($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDesc() => $_has(5);
  @$pb.TagNumber(6)
  void clearDesc() => $_clearField(6);

  /// 优惠券支付按钮文案
  @$pb.TagNumber(7)
  $core.String get payButtonText => $_getSZ(6);
  @$pb.TagNumber(7)
  set payButtonText($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPayButtonText() => $_has(6);
  @$pb.TagNumber(7)
  void clearPayButtonText() => $_clearField(7);

  /// 优惠券支付按钮删除线文案
  @$pb.TagNumber(8)
  $core.String get payButtonTextLineThrough => $_getSZ(7);
  @$pb.TagNumber(8)
  set payButtonTextLineThrough($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPayButtonTextLineThrough() => $_has(7);
  @$pb.TagNumber(8)
  void clearPayButtonTextLineThrough() => $_clearField(8);

  /// 实付金额
  @$pb.TagNumber(9)
  $core.String get realAmount => $_getSZ(8);
  @$pb.TagNumber(9)
  set realAmount($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRealAmount() => $_has(8);
  @$pb.TagNumber(9)
  void clearRealAmount() => $_clearField(9);

  /// 使用过期时间
  @$pb.TagNumber(10)
  $1.Timestamp get expireTime => $_getN(9);
  @$pb.TagNumber(10)
  set expireTime($1.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasExpireTime() => $_has(9);
  @$pb.TagNumber(10)
  void clearExpireTime() => $_clearField(10);
  @$pb.TagNumber(10)
  $1.Timestamp ensureExpireTime() => $_ensure(9);

  @$pb.TagNumber(11)
  $fixnum.Int64 get otype => $_getI64(10);
  @$pb.TagNumber(11)
  set otype($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasOtype() => $_has(10);
  @$pb.TagNumber(11)
  void clearOtype() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get amount => $_getSZ(11);
  @$pb.TagNumber(12)
  set amount($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAmount() => $_has(11);
  @$pb.TagNumber(12)
  void clearAmount() => $_clearField(12);
}

/// 优惠券信息
class CouponInfo extends $pb.GeneratedMessage {
  factory CouponInfo({
    CouponToast? toast,
    PopWin? popWin,
  }) {
    final result = CouponInfo._();
    if (toast != null) result.toast = toast;
    if (popWin != null) result.popWin = popWin;
    return result;
  }

  CouponInfo._();

  factory CouponInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CouponInfo()..mergeFromBuffer(data, registry);
  factory CouponInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CouponInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CouponInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: CouponInfo.$_createMessage)
    ..aOM<CouponToast>(1, _omitFieldNames ? '' : 'toast',
        subBuilder: CouponToast.$_createMessage)
    ..aOM<PopWin>(2, _omitFieldNames ? '' : 'popWin',
        subBuilder: PopWin.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CouponInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CouponInfo copyWith(void Function(CouponInfo) updates) =>
      super.copyWith((message) => updates(message as CouponInfo)) as CouponInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CouponInfo() / CouponInfo.new instead')
  static CouponInfo create() => CouponInfo._();
  static $pb.GeneratedMessage $_createMessage() => CouponInfo._();
  @$core.override
  CouponInfo createEmptyInstance() => CouponInfo._();
  @$core.pragma('dart2js:noInline')
  static CouponInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CouponInfo>(CouponInfo.$_createMessage);
  static CouponInfo? _defaultInstance;

  /// 提示框信息
  @$pb.TagNumber(1)
  CouponToast get toast => $_getN(0);
  @$pb.TagNumber(1)
  set toast(CouponToast value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasToast() => $_has(0);
  @$pb.TagNumber(1)
  void clearToast() => $_clearField(1);
  @$pb.TagNumber(1)
  CouponToast ensureToast() => $_ensure(0);

  /// 弹窗信息
  @$pb.TagNumber(2)
  PopWin get popWin => $_getN(1);
  @$pb.TagNumber(2)
  set popWin(PopWin value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPopWin() => $_has(1);
  @$pb.TagNumber(2)
  void clearPopWin() => $_clearField(2);
  @$pb.TagNumber(2)
  PopWin ensurePopWin() => $_ensure(1);
}

/// 优惠券提示框文案信息
class CouponTextInfo extends $pb.GeneratedMessage {
  factory CouponTextInfo({
    $core.String? positivePreview,
    $core.String? section,
  }) {
    final result = CouponTextInfo._();
    if (positivePreview != null) result.positivePreview = positivePreview;
    if (section != null) result.section = section;
    return result;
  }

  CouponTextInfo._();

  factory CouponTextInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CouponTextInfo()..mergeFromBuffer(data, registry);
  factory CouponTextInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CouponTextInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CouponTextInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: CouponTextInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'positivePreview')
    ..aOS(2, _omitFieldNames ? '' : 'section')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CouponTextInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CouponTextInfo copyWith(void Function(CouponTextInfo) updates) =>
      super.copyWith((message) => updates(message as CouponTextInfo))
          as CouponTextInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CouponTextInfo() / CouponTextInfo.new instead')
  static CouponTextInfo create() => CouponTextInfo._();
  static $pb.GeneratedMessage $_createMessage() => CouponTextInfo._();
  @$core.override
  CouponTextInfo createEmptyInstance() => CouponTextInfo._();
  @$core.pragma('dart2js:noInline')
  static CouponTextInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CouponTextInfo>(
          CouponTextInfo.$_createMessage);
  static CouponTextInfo? _defaultInstance;

  /// 提示框文案-播正片6分钟预览
  @$pb.TagNumber(1)
  $core.String get positivePreview => $_getSZ(0);
  @$pb.TagNumber(1)
  set positivePreview($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPositivePreview() => $_has(0);
  @$pb.TagNumber(1)
  void clearPositivePreview() => $_clearField(1);

  /// 提示框文案-播非正片分节ep
  @$pb.TagNumber(2)
  $core.String get section => $_getSZ(1);
  @$pb.TagNumber(2)
  set section($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSection() => $_has(1);
  @$pb.TagNumber(2)
  void clearSection() => $_clearField(2);
}

/// 优惠券提示框信息
class CouponToast extends $pb.GeneratedMessage {
  factory CouponToast({
    CouponTextInfo? textInfo,
    ButtonInfo? button,
  }) {
    final result = CouponToast._();
    if (textInfo != null) result.textInfo = textInfo;
    if (button != null) result.button = button;
    return result;
  }

  CouponToast._();

  factory CouponToast.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CouponToast()..mergeFromBuffer(data, registry);
  factory CouponToast.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CouponToast()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CouponToast',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: CouponToast.$_createMessage)
    ..aOM<CouponTextInfo>(1, _omitFieldNames ? '' : 'textInfo',
        subBuilder: CouponTextInfo.$_createMessage)
    ..aOM<ButtonInfo>(2, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CouponToast clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CouponToast copyWith(void Function(CouponToast) updates) =>
      super.copyWith((message) => updates(message as CouponToast))
          as CouponToast;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CouponToast() / CouponToast.new instead')
  static CouponToast create() => CouponToast._();
  static $pb.GeneratedMessage $_createMessage() => CouponToast._();
  @$core.override
  CouponToast createEmptyInstance() => CouponToast._();
  @$core.pragma('dart2js:noInline')
  static CouponToast getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CouponToast>(
          CouponToast.$_createMessage);
  static CouponToast? _defaultInstance;

  /// 提示框文案信息
  @$pb.TagNumber(1)
  CouponTextInfo get textInfo => $_getN(0);
  @$pb.TagNumber(1)
  set textInfo(CouponTextInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTextInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearTextInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  CouponTextInfo ensureTextInfo() => $_ensure(0);

  /// 提示框按钮
  @$pb.TagNumber(2)
  ButtonInfo get button => $_getN(1);
  @$pb.TagNumber(2)
  set button(ButtonInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasButton() => $_has(1);
  @$pb.TagNumber(2)
  void clearButton() => $_clearField(2);
  @$pb.TagNumber(2)
  ButtonInfo ensureButton() => $_ensure(1);
}

/// dash条目
class DashItem extends $pb.GeneratedMessage {
  factory DashItem({
    $core.int? id,
    $core.String? baseUrl,
    $core.Iterable<$core.String>? backupUrl,
    $core.int? bandwidth,
    $core.int? codecid,
    $core.String? md5,
    $fixnum.Int64? size,
    $core.String? frameRate,
    $core.String? widevinePssh,
  }) {
    final result = DashItem._();
    if (id != null) result.id = id;
    if (baseUrl != null) result.baseUrl = baseUrl;
    if (backupUrl != null) result.backupUrl.addAll(backupUrl);
    if (bandwidth != null) result.bandwidth = bandwidth;
    if (codecid != null) result.codecid = codecid;
    if (md5 != null) result.md5 = md5;
    if (size != null) result.size = size;
    if (frameRate != null) result.frameRate = frameRate;
    if (widevinePssh != null) result.widevinePssh = widevinePssh;
    return result;
  }

  DashItem._();

  factory DashItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DashItem()..mergeFromBuffer(data, registry);
  factory DashItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DashItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DashItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: DashItem.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'baseUrl')
    ..pPS(3, _omitFieldNames ? '' : 'backupUrl')
    ..aI(4, _omitFieldNames ? '' : 'bandwidth', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'codecid', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'md5')
    ..a<$fixnum.Int64>(7, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(8, _omitFieldNames ? '' : 'frameRate')
    ..aOS(9, _omitFieldNames ? '' : 'widevinePssh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DashItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DashItem copyWith(void Function(DashItem) updates) =>
      super.copyWith((message) => updates(message as DashItem)) as DashItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DashItem() / DashItem.new instead')
  static DashItem create() => DashItem._();
  static $pb.GeneratedMessage $_createMessage() => DashItem._();
  @$core.override
  DashItem createEmptyInstance() => DashItem._();
  @$core.pragma('dart2js:noInline')
  static DashItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DashItem>(DashItem.$_createMessage);
  static DashItem? _defaultInstance;

  /// 清晰度
  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 主线流
  @$pb.TagNumber(2)
  $core.String get baseUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set baseUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBaseUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearBaseUrl() => $_clearField(2);

  /// 备用流
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get backupUrl => $_getList(2);

  /// 带宽
  @$pb.TagNumber(4)
  $core.int get bandwidth => $_getIZ(3);
  @$pb.TagNumber(4)
  set bandwidth($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBandwidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearBandwidth() => $_clearField(4);

  /// 编码id
  @$pb.TagNumber(5)
  $core.int get codecid => $_getIZ(4);
  @$pb.TagNumber(5)
  set codecid($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCodecid() => $_has(4);
  @$pb.TagNumber(5)
  void clearCodecid() => $_clearField(5);

  /// md5
  @$pb.TagNumber(6)
  $core.String get md5 => $_getSZ(5);
  @$pb.TagNumber(6)
  set md5($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMd5() => $_has(5);
  @$pb.TagNumber(6)
  void clearMd5() => $_clearField(6);

  /// 视频大小
  @$pb.TagNumber(7)
  $fixnum.Int64 get size => $_getI64(6);
  @$pb.TagNumber(7)
  set size($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSize() => $_has(6);
  @$pb.TagNumber(7)
  void clearSize() => $_clearField(7);

  /// 帧率
  @$pb.TagNumber(8)
  $core.String get frameRate => $_getSZ(7);
  @$pb.TagNumber(8)
  set frameRate($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFrameRate() => $_has(7);
  @$pb.TagNumber(8)
  void clearFrameRate() => $_clearField(8);

  /// DRM widevine 密钥
  @$pb.TagNumber(9)
  $core.String get widevinePssh => $_getSZ(8);
  @$pb.TagNumber(9)
  set widevinePssh($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasWidevinePssh() => $_has(8);
  @$pb.TagNumber(9)
  void clearWidevinePssh() => $_clearField(9);
}

/// dash视频流
class DashVideo extends $pb.GeneratedMessage {
  factory DashVideo({
    $core.String? baseUrl,
    $core.Iterable<$core.String>? backupUrl,
    $core.int? bandwidth,
    $core.int? codecid,
    $core.String? md5,
    $fixnum.Int64? size,
    $core.int? audioId,
    $core.bool? noRexcode,
    $core.String? frameRate,
    $core.int? width,
    $core.int? height,
    $core.String? widevinePssh,
  }) {
    final result = DashVideo._();
    if (baseUrl != null) result.baseUrl = baseUrl;
    if (backupUrl != null) result.backupUrl.addAll(backupUrl);
    if (bandwidth != null) result.bandwidth = bandwidth;
    if (codecid != null) result.codecid = codecid;
    if (md5 != null) result.md5 = md5;
    if (size != null) result.size = size;
    if (audioId != null) result.audioId = audioId;
    if (noRexcode != null) result.noRexcode = noRexcode;
    if (frameRate != null) result.frameRate = frameRate;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (widevinePssh != null) result.widevinePssh = widevinePssh;
    return result;
  }

  DashVideo._();

  factory DashVideo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DashVideo()..mergeFromBuffer(data, registry);
  factory DashVideo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DashVideo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DashVideo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: DashVideo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'baseUrl')
    ..pPS(2, _omitFieldNames ? '' : 'backupUrl')
    ..aI(3, _omitFieldNames ? '' : 'bandwidth', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'codecid', fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'md5')
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(7, _omitFieldNames ? '' : 'audioId', fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'noRexcode')
    ..aOS(9, _omitFieldNames ? '' : 'frameRate')
    ..aI(10, _omitFieldNames ? '' : 'width')
    ..aI(11, _omitFieldNames ? '' : 'height')
    ..aOS(12, _omitFieldNames ? '' : 'widevinePssh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DashVideo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DashVideo copyWith(void Function(DashVideo) updates) =>
      super.copyWith((message) => updates(message as DashVideo)) as DashVideo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DashVideo() / DashVideo.new instead')
  static DashVideo create() => DashVideo._();
  static $pb.GeneratedMessage $_createMessage() => DashVideo._();
  @$core.override
  DashVideo createEmptyInstance() => DashVideo._();
  @$core.pragma('dart2js:noInline')
  static DashVideo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DashVideo>(DashVideo.$_createMessage);
  static DashVideo? _defaultInstance;

  /// 主线流
  @$pb.TagNumber(1)
  $core.String get baseUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set baseUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBaseUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearBaseUrl() => $_clearField(1);

  /// 备用流
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get backupUrl => $_getList(1);

  /// 带宽
  @$pb.TagNumber(3)
  $core.int get bandwidth => $_getIZ(2);
  @$pb.TagNumber(3)
  set bandwidth($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBandwidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearBandwidth() => $_clearField(3);

  /// 编码id
  @$pb.TagNumber(4)
  $core.int get codecid => $_getIZ(3);
  @$pb.TagNumber(4)
  set codecid($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCodecid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCodecid() => $_clearField(4);

  /// md5
  @$pb.TagNumber(5)
  $core.String get md5 => $_getSZ(4);
  @$pb.TagNumber(5)
  set md5($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMd5() => $_has(4);
  @$pb.TagNumber(5)
  void clearMd5() => $_clearField(5);

  /// 大小
  @$pb.TagNumber(6)
  $fixnum.Int64 get size => $_getI64(5);
  @$pb.TagNumber(6)
  set size($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearSize() => $_clearField(6);

  /// 伴音质量id
  @$pb.TagNumber(7)
  $core.int get audioId => $_getIZ(6);
  @$pb.TagNumber(7)
  set audioId($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAudioId() => $_has(6);
  @$pb.TagNumber(7)
  void clearAudioId() => $_clearField(7);

  /// 是否非全二压
  @$pb.TagNumber(8)
  $core.bool get noRexcode => $_getBF(7);
  @$pb.TagNumber(8)
  set noRexcode($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNoRexcode() => $_has(7);
  @$pb.TagNumber(8)
  void clearNoRexcode() => $_clearField(8);

  /// 帧率
  @$pb.TagNumber(9)
  $core.String get frameRate => $_getSZ(8);
  @$pb.TagNumber(9)
  set frameRate($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFrameRate() => $_has(8);
  @$pb.TagNumber(9)
  void clearFrameRate() => $_clearField(9);

  /// 宽
  @$pb.TagNumber(10)
  $core.int get width => $_getIZ(9);
  @$pb.TagNumber(10)
  set width($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasWidth() => $_has(9);
  @$pb.TagNumber(10)
  void clearWidth() => $_clearField(10);

  /// 高
  @$pb.TagNumber(11)
  $core.int get height => $_getIZ(10);
  @$pb.TagNumber(11)
  set height($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasHeight() => $_has(10);
  @$pb.TagNumber(11)
  void clearHeight() => $_clearField(11);

  /// DRM 密钥
  @$pb.TagNumber(12)
  $core.String get widevinePssh => $_getSZ(11);
  @$pb.TagNumber(12)
  set widevinePssh($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasWidevinePssh() => $_has(11);
  @$pb.TagNumber(12)
  void clearWidevinePssh() => $_clearField(12);
}

class DataControl extends $pb.GeneratedMessage {
  factory DataControl({
    $core.bool? needWatchProgress,
  }) {
    final result = DataControl._();
    if (needWatchProgress != null) result.needWatchProgress = needWatchProgress;
    return result;
  }

  DataControl._();

  factory DataControl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DataControl()..mergeFromBuffer(data, registry);
  factory DataControl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DataControl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DataControl',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: DataControl.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'needWatchProgress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataControl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataControl copyWith(void Function(DataControl) updates) =>
      super.copyWith((message) => updates(message as DataControl))
          as DataControl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DataControl() / DataControl.new instead')
  static DataControl create() => DataControl._();
  static $pb.GeneratedMessage $_createMessage() => DataControl._();
  @$core.override
  DataControl createEmptyInstance() => DataControl._();
  @$core.pragma('dart2js:noInline')
  static DataControl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DataControl>(
          DataControl.$_createMessage);
  static DataControl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get needWatchProgress => $_getBF(0);
  @$pb.TagNumber(1)
  set needWatchProgress($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNeedWatchProgress() => $_has(0);
  @$pb.TagNumber(1)
  void clearNeedWatchProgress() => $_clearField(1);
}

/// 鉴权浮层
class Dialog extends $pb.GeneratedMessage {
  factory Dialog({
    $fixnum.Int64? code,
    $core.String? msg,
    $core.String? type,
    $core.String? styleType,
    DialogConfig? config,
    TextInfo? title,
    TextInfo? subtitle,
    ImageInfo? image,
    $core.Iterable<ButtonInfo>? button,
    ButtonInfo? bottomDesc,
    Report? report,
    $core.int? countDownSec,
    TextInfo? rightBottomDesc,
    $core.Iterable<BottomDisplay>? bottomDisplay,
    $core.Iterable<PlayList>? playList,
  }) {
    final result = Dialog._();
    if (code != null) result.code = code;
    if (msg != null) result.msg = msg;
    if (type != null) result.type = type;
    if (styleType != null) result.styleType = styleType;
    if (config != null) result.config = config;
    if (title != null) result.title = title;
    if (subtitle != null) result.subtitle = subtitle;
    if (image != null) result.image = image;
    if (button != null) result.button.addAll(button);
    if (bottomDesc != null) result.bottomDesc = bottomDesc;
    if (report != null) result.report = report;
    if (countDownSec != null) result.countDownSec = countDownSec;
    if (rightBottomDesc != null) result.rightBottomDesc = rightBottomDesc;
    if (bottomDisplay != null) result.bottomDisplay.addAll(bottomDisplay);
    if (playList != null) result.playList.addAll(playList);
    return result;
  }

  Dialog._();

  factory Dialog.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Dialog()..mergeFromBuffer(data, registry);
  factory Dialog.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Dialog()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Dialog',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Dialog.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'msg')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOS(4, _omitFieldNames ? '' : 'styleType')
    ..aOM<DialogConfig>(5, _omitFieldNames ? '' : 'config',
        subBuilder: DialogConfig.$_createMessage)
    ..aOM<TextInfo>(6, _omitFieldNames ? '' : 'title',
        subBuilder: TextInfo.$_createMessage)
    ..aOM<TextInfo>(7, _omitFieldNames ? '' : 'subtitle',
        subBuilder: TextInfo.$_createMessage)
    ..aOM<ImageInfo>(8, _omitFieldNames ? '' : 'image',
        subBuilder: ImageInfo.$_createMessage)
    ..pPM<ButtonInfo>(9, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonInfo.$_createMessage)
    ..aOM<ButtonInfo>(10, _omitFieldNames ? '' : 'bottomDesc',
        subBuilder: ButtonInfo.$_createMessage)
    ..aOM<Report>(11, _omitFieldNames ? '' : 'report',
        subBuilder: Report.$_createMessage)
    ..aI(12, _omitFieldNames ? '' : 'countDownSec')
    ..aOM<TextInfo>(13, _omitFieldNames ? '' : 'rightBottomDesc',
        subBuilder: TextInfo.$_createMessage)
    ..pPM<BottomDisplay>(14, _omitFieldNames ? '' : 'bottomDisplay',
        subBuilder: BottomDisplay.$_createMessage)
    ..pPM<PlayList>(15, _omitFieldNames ? '' : 'playList',
        subBuilder: PlayList.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Dialog clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Dialog copyWith(void Function(Dialog) updates) =>
      super.copyWith((message) => updates(message as Dialog)) as Dialog;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Dialog() / Dialog.new instead')
  static Dialog create() => Dialog._();
  static $pb.GeneratedMessage $_createMessage() => Dialog._();
  @$core.override
  Dialog createEmptyInstance() => Dialog._();
  @$core.pragma('dart2js:noInline')
  static Dialog getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Dialog>(Dialog.$_createMessage);
  static Dialog? _defaultInstance;

  /// 鉴权限制码
  @$pb.TagNumber(1)
  $fixnum.Int64 get code => $_getI64(0);
  @$pb.TagNumber(1)
  set code($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  /// 鉴权限制信息
  @$pb.TagNumber(2)
  $core.String get msg => $_getSZ(1);
  @$pb.TagNumber(2)
  set msg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsg() => $_clearField(2);

  /// 浮层类型
  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  /// 浮层样式类型
  @$pb.TagNumber(4)
  $core.String get styleType => $_getSZ(3);
  @$pb.TagNumber(4)
  set styleType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStyleType() => $_has(3);
  @$pb.TagNumber(4)
  void clearStyleType() => $_clearField(4);

  /// 浮层配置
  @$pb.TagNumber(5)
  DialogConfig get config => $_getN(4);
  @$pb.TagNumber(5)
  set config(DialogConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasConfig() => $_has(4);
  @$pb.TagNumber(5)
  void clearConfig() => $_clearField(5);
  @$pb.TagNumber(5)
  DialogConfig ensureConfig() => $_ensure(4);

  /// 标题
  @$pb.TagNumber(6)
  TextInfo get title => $_getN(5);
  @$pb.TagNumber(6)
  set title(TextInfo value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTitle() => $_has(5);
  @$pb.TagNumber(6)
  void clearTitle() => $_clearField(6);
  @$pb.TagNumber(6)
  TextInfo ensureTitle() => $_ensure(5);

  /// 副标题
  @$pb.TagNumber(7)
  TextInfo get subtitle => $_getN(6);
  @$pb.TagNumber(7)
  set subtitle(TextInfo value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSubtitle() => $_has(6);
  @$pb.TagNumber(7)
  void clearSubtitle() => $_clearField(7);
  @$pb.TagNumber(7)
  TextInfo ensureSubtitle() => $_ensure(6);

  /// 图片信息
  @$pb.TagNumber(8)
  ImageInfo get image => $_getN(7);
  @$pb.TagNumber(8)
  set image(ImageInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasImage() => $_has(7);
  @$pb.TagNumber(8)
  void clearImage() => $_clearField(8);
  @$pb.TagNumber(8)
  ImageInfo ensureImage() => $_ensure(7);

  /// 按钮列表
  @$pb.TagNumber(9)
  $pb.PbList<ButtonInfo> get button => $_getList(8);

  /// 底部描述
  @$pb.TagNumber(10)
  ButtonInfo get bottomDesc => $_getN(9);
  @$pb.TagNumber(10)
  set bottomDesc(ButtonInfo value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasBottomDesc() => $_has(9);
  @$pb.TagNumber(10)
  void clearBottomDesc() => $_clearField(10);
  @$pb.TagNumber(10)
  ButtonInfo ensureBottomDesc() => $_ensure(9);

  /// 埋点上报信息
  @$pb.TagNumber(11)
  Report get report => $_getN(10);
  @$pb.TagNumber(11)
  set report(Report value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasReport() => $_has(10);
  @$pb.TagNumber(11)
  void clearReport() => $_clearField(11);
  @$pb.TagNumber(11)
  Report ensureReport() => $_ensure(10);

  /// 倒计时 秒
  @$pb.TagNumber(12)
  $core.int get countDownSec => $_getIZ(11);
  @$pb.TagNumber(12)
  set countDownSec($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCountDownSec() => $_has(11);
  @$pb.TagNumber(12)
  void clearCountDownSec() => $_clearField(12);

  /// 右下描述
  @$pb.TagNumber(13)
  TextInfo get rightBottomDesc => $_getN(12);
  @$pb.TagNumber(13)
  set rightBottomDesc(TextInfo value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRightBottomDesc() => $_has(12);
  @$pb.TagNumber(13)
  void clearRightBottomDesc() => $_clearField(13);
  @$pb.TagNumber(13)
  TextInfo ensureRightBottomDesc() => $_ensure(12);

  @$pb.TagNumber(14)
  $pb.PbList<BottomDisplay> get bottomDisplay => $_getList(13);

  @$pb.TagNumber(15)
  $pb.PbList<PlayList> get playList => $_getList(14);
}

/// 鉴权浮层配置
class DialogConfig extends $pb.GeneratedMessage {
  factory DialogConfig({
    $core.bool? isShowCover,
    $core.bool? isOrientationEnable,
    $core.bool? isNestedScrollEnable,
    $core.bool? isForceHalfscreenEnable,
    $core.bool? isBackgroundTranslucentEnable,
  }) {
    final result = DialogConfig._();
    if (isShowCover != null) result.isShowCover = isShowCover;
    if (isOrientationEnable != null)
      result.isOrientationEnable = isOrientationEnable;
    if (isNestedScrollEnable != null)
      result.isNestedScrollEnable = isNestedScrollEnable;
    if (isForceHalfscreenEnable != null)
      result.isForceHalfscreenEnable = isForceHalfscreenEnable;
    if (isBackgroundTranslucentEnable != null)
      result.isBackgroundTranslucentEnable = isBackgroundTranslucentEnable;
    return result;
  }

  DialogConfig._();

  factory DialogConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DialogConfig()..mergeFromBuffer(data, registry);
  factory DialogConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DialogConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DialogConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: DialogConfig.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'isShowCover')
    ..aOB(2, _omitFieldNames ? '' : 'isOrientationEnable')
    ..aOB(3, _omitFieldNames ? '' : 'isNestedScrollEnable')
    ..aOB(4, _omitFieldNames ? '' : 'isForceHalfscreenEnable')
    ..aOB(5, _omitFieldNames ? '' : 'isBackgroundTranslucentEnable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DialogConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DialogConfig copyWith(void Function(DialogConfig) updates) =>
      super.copyWith((message) => updates(message as DialogConfig))
          as DialogConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DialogConfig() / DialogConfig.new instead')
  static DialogConfig create() => DialogConfig._();
  static $pb.GeneratedMessage $_createMessage() => DialogConfig._();
  @$core.override
  DialogConfig createEmptyInstance() => DialogConfig._();
  @$core.pragma('dart2js:noInline')
  static DialogConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DialogConfig>(
          DialogConfig.$_createMessage);
  static DialogConfig? _defaultInstance;

  /// 是否显示高斯模糊背景图
  @$pb.TagNumber(1)
  $core.bool get isShowCover => $_getBF(0);
  @$pb.TagNumber(1)
  set isShowCover($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsShowCover() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsShowCover() => $_clearField(1);

  /// 是否响应转屏
  @$pb.TagNumber(2)
  $core.bool get isOrientationEnable => $_getBF(1);
  @$pb.TagNumber(2)
  set isOrientationEnable($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsOrientationEnable() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsOrientationEnable() => $_clearField(2);

  /// 是否响应上滑吸顶
  @$pb.TagNumber(3)
  $core.bool get isNestedScrollEnable => $_getBF(2);
  @$pb.TagNumber(3)
  set isNestedScrollEnable($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsNestedScrollEnable() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsNestedScrollEnable() => $_clearField(3);

  /// 是否强制竖屏
  @$pb.TagNumber(4)
  $core.bool get isForceHalfscreenEnable => $_getBF(3);
  @$pb.TagNumber(4)
  set isForceHalfscreenEnable($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsForceHalfscreenEnable() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsForceHalfscreenEnable() => $_clearField(4);

  /// 是否启用背景半透明
  @$pb.TagNumber(5)
  $core.bool get isBackgroundTranslucentEnable => $_getBF(4);
  @$pb.TagNumber(5)
  set isBackgroundTranslucentEnable($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsBackgroundTranslucentEnable() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsBackgroundTranslucentEnable() => $_clearField(5);
}

/// 当前分辨率信息
class Dimension extends $pb.GeneratedMessage {
  factory Dimension({
    $core.int? width,
    $core.int? height,
    $core.int? rotate,
  }) {
    final result = Dimension._();
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (rotate != null) result.rotate = rotate;
    return result;
  }

  Dimension._();

  factory Dimension.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Dimension()..mergeFromBuffer(data, registry);
  factory Dimension.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Dimension()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Dimension',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Dimension.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'width')
    ..aI(2, _omitFieldNames ? '' : 'height')
    ..aI(3, _omitFieldNames ? '' : 'rotate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Dimension clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Dimension copyWith(void Function(Dimension) updates) =>
      super.copyWith((message) => updates(message as Dimension)) as Dimension;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Dimension() / Dimension.new instead')
  static Dimension create() => Dimension._();
  static $pb.GeneratedMessage $_createMessage() => Dimension._();
  @$core.override
  Dimension createEmptyInstance() => Dimension._();
  @$core.pragma('dart2js:noInline')
  static Dimension getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Dimension>(Dimension.$_createMessage);
  static Dimension? _defaultInstance;

  /// 宽
  @$pb.TagNumber(1)
  $core.int get width => $_getIZ(0);
  @$pb.TagNumber(1)
  set width($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => $_clearField(1);

  /// 长
  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);

  /// 旋转角度
  @$pb.TagNumber(3)
  $core.int get rotate => $_getIZ(2);
  @$pb.TagNumber(3)
  set rotate($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRotate() => $_has(2);
  @$pb.TagNumber(3)
  void clearRotate() => $_clearField(3);
}

/// 杜比音频信息
class DolbyItem extends $pb.GeneratedMessage {
  factory DolbyItem({
    DolbyItem_Type? type,
    DashItem? audio,
  }) {
    final result = DolbyItem._();
    if (type != null) result.type = type;
    if (audio != null) result.audio = audio;
    return result;
  }

  DolbyItem._();

  factory DolbyItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DolbyItem()..mergeFromBuffer(data, registry);
  factory DolbyItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DolbyItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DolbyItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: DolbyItem.$_createMessage)
    ..aE<DolbyItem_Type>(1, _omitFieldNames ? '' : 'type',
        enumValues: DolbyItem_Type.values)
    ..aOM<DashItem>(2, _omitFieldNames ? '' : 'audio',
        subBuilder: DashItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DolbyItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DolbyItem copyWith(void Function(DolbyItem) updates) =>
      super.copyWith((message) => updates(message as DolbyItem)) as DolbyItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DolbyItem() / DolbyItem.new instead')
  static DolbyItem create() => DolbyItem._();
  static $pb.GeneratedMessage $_createMessage() => DolbyItem._();
  @$core.override
  DolbyItem createEmptyInstance() => DolbyItem._();
  @$core.pragma('dart2js:noInline')
  static DolbyItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DolbyItem>(DolbyItem.$_createMessage);
  static DolbyItem? _defaultInstance;

  /// 杜比类型
  @$pb.TagNumber(1)
  DolbyItem_Type get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(DolbyItem_Type value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// 音频流
  @$pb.TagNumber(2)
  DashItem get audio => $_getN(1);
  @$pb.TagNumber(2)
  set audio(DashItem value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAudio() => $_has(1);
  @$pb.TagNumber(2)
  void clearAudio() => $_clearField(2);
  @$pb.TagNumber(2)
  DashItem ensureAudio() => $_ensure(1);
}

/// 播放结束后的尾页Dialog
class EndPage extends $pb.GeneratedMessage {
  factory EndPage({
    Dialog? dialog,
    $core.bool? hide,
  }) {
    final result = EndPage._();
    if (dialog != null) result.dialog = dialog;
    if (hide != null) result.hide = hide;
    return result;
  }

  EndPage._();

  factory EndPage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EndPage()..mergeFromBuffer(data, registry);
  factory EndPage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EndPage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EndPage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: EndPage.$_createMessage)
    ..aOM<Dialog>(1, _omitFieldNames ? '' : 'dialog',
        subBuilder: Dialog.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'hide')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndPage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndPage copyWith(void Function(EndPage) updates) =>
      super.copyWith((message) => updates(message as EndPage)) as EndPage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EndPage() / EndPage.new instead')
  static EndPage create() => EndPage._();
  static $pb.GeneratedMessage $_createMessage() => EndPage._();
  @$core.override
  EndPage createEmptyInstance() => EndPage._();
  @$core.pragma('dart2js:noInline')
  static EndPage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EndPage>(EndPage.$_createMessage);
  static EndPage? _defaultInstance;

  @$pb.TagNumber(1)
  Dialog get dialog => $_getN(0);
  @$pb.TagNumber(1)
  set dialog(Dialog value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDialog() => $_has(0);
  @$pb.TagNumber(1)
  void clearDialog() => $_clearField(1);
  @$pb.TagNumber(1)
  Dialog ensureDialog() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get hide => $_getBF(1);
  @$pb.TagNumber(2)
  set hide($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHide() => $_has(1);
  @$pb.TagNumber(2)
  void clearHide() => $_clearField(2);
}

class EpInlineVideo extends $pb.GeneratedMessage {
  factory EpInlineVideo({
    $fixnum.Int64? materialNo,
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
  }) {
    final result = EpInlineVideo._();
    if (materialNo != null) result.materialNo = materialNo;
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    return result;
  }

  EpInlineVideo._();

  factory EpInlineVideo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpInlineVideo()..mergeFromBuffer(data, registry);
  factory EpInlineVideo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpInlineVideo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpInlineVideo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: EpInlineVideo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'materialNo')
    ..aInt64(2, _omitFieldNames ? '' : 'aid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpInlineVideo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpInlineVideo copyWith(void Function(EpInlineVideo) updates) =>
      super.copyWith((message) => updates(message as EpInlineVideo))
          as EpInlineVideo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EpInlineVideo() / EpInlineVideo.new instead')
  static EpInlineVideo create() => EpInlineVideo._();
  static $pb.GeneratedMessage $_createMessage() => EpInlineVideo._();
  @$core.override
  EpInlineVideo createEmptyInstance() => EpInlineVideo._();
  @$core.pragma('dart2js:noInline')
  static EpInlineVideo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EpInlineVideo>(
          EpInlineVideo.$_createMessage);
  static EpInlineVideo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get materialNo => $_getI64(0);
  @$pb.TagNumber(1)
  set materialNo($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMaterialNo() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaterialNo() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get aid => $_getI64(1);
  @$pb.TagNumber(2)
  set aid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAid() => $_has(1);
  @$pb.TagNumber(2)
  void clearAid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);
}

/// 剧集广告信息
class EpisodeAdvertisementInfo extends $pb.GeneratedMessage {
  factory EpisodeAdvertisementInfo({
    $fixnum.Int64? aid,
    $core.String? title,
    $core.String? link,
    $core.int? followVideoBntFlag,
    $core.String? nextVideoTitle,
    $core.String? nextVideoLink,
    $fixnum.Int64? cid,
    $core.int? seasonId,
    $core.int? follow,
  }) {
    final result = EpisodeAdvertisementInfo._();
    if (aid != null) result.aid = aid;
    if (title != null) result.title = title;
    if (link != null) result.link = link;
    if (followVideoBntFlag != null)
      result.followVideoBntFlag = followVideoBntFlag;
    if (nextVideoTitle != null) result.nextVideoTitle = nextVideoTitle;
    if (nextVideoLink != null) result.nextVideoLink = nextVideoLink;
    if (cid != null) result.cid = cid;
    if (seasonId != null) result.seasonId = seasonId;
    if (follow != null) result.follow = follow;
    return result;
  }

  EpisodeAdvertisementInfo._();

  factory EpisodeAdvertisementInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeAdvertisementInfo()..mergeFromBuffer(data, registry);
  factory EpisodeAdvertisementInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeAdvertisementInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpisodeAdvertisementInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: EpisodeAdvertisementInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'link')
    ..aI(4, _omitFieldNames ? '' : 'followVideoBntFlag')
    ..aOS(5, _omitFieldNames ? '' : 'nextVideoTitle')
    ..aOS(6, _omitFieldNames ? '' : 'nextVideoLink')
    ..aInt64(7, _omitFieldNames ? '' : 'cid')
    ..aI(8, _omitFieldNames ? '' : 'seasonId')
    ..aI(9, _omitFieldNames ? '' : 'follow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeAdvertisementInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeAdvertisementInfo copyWith(
          void Function(EpisodeAdvertisementInfo) updates) =>
      super.copyWith((message) => updates(message as EpisodeAdvertisementInfo))
          as EpisodeAdvertisementInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use EpisodeAdvertisementInfo() / EpisodeAdvertisementInfo.new instead')
  static EpisodeAdvertisementInfo create() => EpisodeAdvertisementInfo._();
  static $pb.GeneratedMessage $_createMessage() => EpisodeAdvertisementInfo._();
  @$core.override
  EpisodeAdvertisementInfo createEmptyInstance() =>
      EpisodeAdvertisementInfo._();
  @$core.pragma('dart2js:noInline')
  static EpisodeAdvertisementInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EpisodeAdvertisementInfo>(
          EpisodeAdvertisementInfo.$_createMessage);
  static EpisodeAdvertisementInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get link => $_getSZ(2);
  @$pb.TagNumber(3)
  set link($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLink() => $_has(2);
  @$pb.TagNumber(3)
  void clearLink() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get followVideoBntFlag => $_getIZ(3);
  @$pb.TagNumber(4)
  set followVideoBntFlag($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFollowVideoBntFlag() => $_has(3);
  @$pb.TagNumber(4)
  void clearFollowVideoBntFlag() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get nextVideoTitle => $_getSZ(4);
  @$pb.TagNumber(5)
  set nextVideoTitle($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNextVideoTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearNextVideoTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get nextVideoLink => $_getSZ(5);
  @$pb.TagNumber(6)
  set nextVideoLink($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNextVideoLink() => $_has(5);
  @$pb.TagNumber(6)
  void clearNextVideoLink() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get cid => $_getI64(6);
  @$pb.TagNumber(7)
  set cid($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCid() => $_has(6);
  @$pb.TagNumber(7)
  void clearCid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get seasonId => $_getIZ(7);
  @$pb.TagNumber(8)
  set seasonId($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSeasonId() => $_has(7);
  @$pb.TagNumber(8)
  void clearSeasonId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get follow => $_getIZ(8);
  @$pb.TagNumber(9)
  set follow($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFollow() => $_has(8);
  @$pb.TagNumber(9)
  void clearFollow() => $_clearField(9);
}

/// EP信息
class EpisodeInfo extends $pb.GeneratedMessage {
  factory EpisodeInfo({
    $core.int? epId,
    $fixnum.Int64? cid,
    $fixnum.Int64? aid,
    $fixnum.Int64? epStatus,
    SeasonInfo? seasonInfo,
    $core.String? cover,
    $core.String? title,
    Interaction? interaction,
    $core.String? longTitle,
  }) {
    final result = EpisodeInfo._();
    if (epId != null) result.epId = epId;
    if (cid != null) result.cid = cid;
    if (aid != null) result.aid = aid;
    if (epStatus != null) result.epStatus = epStatus;
    if (seasonInfo != null) result.seasonInfo = seasonInfo;
    if (cover != null) result.cover = cover;
    if (title != null) result.title = title;
    if (interaction != null) result.interaction = interaction;
    if (longTitle != null) result.longTitle = longTitle;
    return result;
  }

  EpisodeInfo._();

  factory EpisodeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeInfo()..mergeFromBuffer(data, registry);
  factory EpisodeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpisodeInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpisodeInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: EpisodeInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'epId')
    ..aInt64(2, _omitFieldNames ? '' : 'cid')
    ..aInt64(3, _omitFieldNames ? '' : 'aid')
    ..aInt64(4, _omitFieldNames ? '' : 'epStatus')
    ..aOM<SeasonInfo>(5, _omitFieldNames ? '' : 'seasonInfo',
        subBuilder: SeasonInfo.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'cover')
    ..aOS(7, _omitFieldNames ? '' : 'title')
    ..aOM<Interaction>(8, _omitFieldNames ? '' : 'interaction',
        subBuilder: Interaction.$_createMessage)
    ..aOS(9, _omitFieldNames ? '' : 'longTitle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpisodeInfo copyWith(void Function(EpisodeInfo) updates) =>
      super.copyWith((message) => updates(message as EpisodeInfo))
          as EpisodeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EpisodeInfo() / EpisodeInfo.new instead')
  static EpisodeInfo create() => EpisodeInfo._();
  static $pb.GeneratedMessage $_createMessage() => EpisodeInfo._();
  @$core.override
  EpisodeInfo createEmptyInstance() => EpisodeInfo._();
  @$core.pragma('dart2js:noInline')
  static EpisodeInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EpisodeInfo>(
          EpisodeInfo.$_createMessage);
  static EpisodeInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get epId => $_getIZ(0);
  @$pb.TagNumber(1)
  set epId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEpId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEpId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get cid => $_getI64(1);
  @$pb.TagNumber(2)
  set cid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get aid => $_getI64(2);
  @$pb.TagNumber(3)
  set aid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAid() => $_has(2);
  @$pb.TagNumber(3)
  void clearAid() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get epStatus => $_getI64(3);
  @$pb.TagNumber(4)
  set epStatus($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEpStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearEpStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  SeasonInfo get seasonInfo => $_getN(4);
  @$pb.TagNumber(5)
  set seasonInfo(SeasonInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSeasonInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeasonInfo() => $_clearField(5);
  @$pb.TagNumber(5)
  SeasonInfo ensureSeasonInfo() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get cover => $_getSZ(5);
  @$pb.TagNumber(6)
  set cover($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCover() => $_has(5);
  @$pb.TagNumber(6)
  void clearCover() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get title => $_getSZ(6);
  @$pb.TagNumber(7)
  set title($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTitle() => $_has(6);
  @$pb.TagNumber(7)
  void clearTitle() => $_clearField(7);

  @$pb.TagNumber(8)
  Interaction get interaction => $_getN(7);
  @$pb.TagNumber(8)
  set interaction(Interaction value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasInteraction() => $_has(7);
  @$pb.TagNumber(8)
  void clearInteraction() => $_clearField(8);
  @$pb.TagNumber(8)
  Interaction ensureInteraction() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get longTitle => $_getSZ(8);
  @$pb.TagNumber(9)
  set longTitle($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLongTitle() => $_has(8);
  @$pb.TagNumber(9)
  void clearLongTitle() => $_clearField(9);
}

class EpPreVideo extends $pb.GeneratedMessage {
  factory EpPreVideo({
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
  }) {
    final result = EpPreVideo._();
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    return result;
  }

  EpPreVideo._();

  factory EpPreVideo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpPreVideo()..mergeFromBuffer(data, registry);
  factory EpPreVideo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpPreVideo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpPreVideo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: EpPreVideo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aInt64(2, _omitFieldNames ? '' : 'cid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpPreVideo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpPreVideo copyWith(void Function(EpPreVideo) updates) =>
      super.copyWith((message) => updates(message as EpPreVideo)) as EpPreVideo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EpPreVideo() / EpPreVideo.new instead')
  static EpPreVideo create() => EpPreVideo._();
  static $pb.GeneratedMessage $_createMessage() => EpPreVideo._();
  @$core.override
  EpPreVideo createEmptyInstance() => EpPreVideo._();
  @$core.pragma('dart2js:noInline')
  static EpPreVideo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EpPreVideo>(EpPreVideo.$_createMessage);
  static EpPreVideo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get cid => $_getI64(1);
  @$pb.TagNumber(2)
  set cid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => $_clearField(2);
}

enum EpPublicityVideo_Data { epPreVideo, epInlineVideo, notSet }

class EpPublicityVideo extends $pb.GeneratedMessage {
  factory EpPublicityVideo({
    EpPublicityVideo_Type? type,
    EpPreVideo? epPreVideo,
    EpInlineVideo? epInlineVideo,
  }) {
    final result = EpPublicityVideo._();
    if (type != null) result.type = type;
    if (epPreVideo != null) result.epPreVideo = epPreVideo;
    if (epInlineVideo != null) result.epInlineVideo = epInlineVideo;
    return result;
  }

  EpPublicityVideo._();

  factory EpPublicityVideo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpPublicityVideo()..mergeFromBuffer(data, registry);
  factory EpPublicityVideo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EpPublicityVideo()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, EpPublicityVideo_Data>
      _EpPublicityVideo_DataByTag = {
    2: EpPublicityVideo_Data.epPreVideo,
    3: EpPublicityVideo_Data.epInlineVideo,
    0: EpPublicityVideo_Data.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EpPublicityVideo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: EpPublicityVideo.$_createMessage)
    ..oo(0, [2, 3])
    ..aE<EpPublicityVideo_Type>(1, _omitFieldNames ? '' : 'type',
        enumValues: EpPublicityVideo_Type.values)
    ..aOM<EpPreVideo>(2, _omitFieldNames ? '' : 'epPreVideo',
        subBuilder: EpPreVideo.$_createMessage)
    ..aOM<EpInlineVideo>(3, _omitFieldNames ? '' : 'epInlineVideo',
        subBuilder: EpInlineVideo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpPublicityVideo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EpPublicityVideo copyWith(void Function(EpPublicityVideo) updates) =>
      super.copyWith((message) => updates(message as EpPublicityVideo))
          as EpPublicityVideo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EpPublicityVideo() / EpPublicityVideo.new instead')
  static EpPublicityVideo create() => EpPublicityVideo._();
  static $pb.GeneratedMessage $_createMessage() => EpPublicityVideo._();
  @$core.override
  EpPublicityVideo createEmptyInstance() => EpPublicityVideo._();
  @$core.pragma('dart2js:noInline')
  static EpPublicityVideo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EpPublicityVideo>(
          EpPublicityVideo.$_createMessage);
  static EpPublicityVideo? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  EpPublicityVideo_Data whichData() =>
      _EpPublicityVideo_DataByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearData() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  EpPublicityVideo_Type get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(EpPublicityVideo_Type value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  EpPreVideo get epPreVideo => $_getN(1);
  @$pb.TagNumber(2)
  set epPreVideo(EpPreVideo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasEpPreVideo() => $_has(1);
  @$pb.TagNumber(2)
  void clearEpPreVideo() => $_clearField(2);
  @$pb.TagNumber(2)
  EpPreVideo ensureEpPreVideo() => $_ensure(1);

  @$pb.TagNumber(3)
  EpInlineVideo get epInlineVideo => $_getN(2);
  @$pb.TagNumber(3)
  set epInlineVideo(EpInlineVideo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasEpInlineVideo() => $_has(2);
  @$pb.TagNumber(3)
  void clearEpInlineVideo() => $_clearField(3);
  @$pb.TagNumber(3)
  EpInlineVideo ensureEpInlineVideo() => $_ensure(2);
}

/// 事件
class Event extends $pb.GeneratedMessage {
  factory Event({
    Shake? shake,
  }) {
    final result = Event._();
    if (shake != null) result.shake = shake;
    return result;
  }

  Event._();

  factory Event.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Event()..mergeFromBuffer(data, registry);
  factory Event.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Event()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Event.$_createMessage)
    ..aOM<Shake>(1, _omitFieldNames ? '' : 'shake',
        subBuilder: Shake.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event copyWith(void Function(Event) updates) =>
      super.copyWith((message) => updates(message as Event)) as Event;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Event() / Event.new instead')
  static Event create() => Event._();
  static $pb.GeneratedMessage $_createMessage() => Event._();
  @$core.override
  Event createEmptyInstance() => Event._();
  @$core.pragma('dart2js:noInline')
  static Event getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Event>(Event.$_createMessage);
  static Event? _defaultInstance;

  /// 震动
  @$pb.TagNumber(1)
  Shake get shake => $_getN(0);
  @$pb.TagNumber(1)
  set shake(Shake value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasShake() => $_has(0);
  @$pb.TagNumber(1)
  void clearShake() => $_clearField(1);
  @$pb.TagNumber(1)
  Shake ensureShake() => $_ensure(0);
}

/// 放映室提示语
class FreyaConfig extends $pb.GeneratedMessage {
  factory FreyaConfig({
    $core.String? desc,
    $core.int? type,
    $core.int? issuedCnt,
    $core.bool? isAlwaysShow,
    $core.int? screenNumber,
    $core.int? fullScreenNumber,
  }) {
    final result = FreyaConfig._();
    if (desc != null) result.desc = desc;
    if (type != null) result.type = type;
    if (issuedCnt != null) result.issuedCnt = issuedCnt;
    if (isAlwaysShow != null) result.isAlwaysShow = isAlwaysShow;
    if (screenNumber != null) result.screenNumber = screenNumber;
    if (fullScreenNumber != null) result.fullScreenNumber = fullScreenNumber;
    return result;
  }

  FreyaConfig._();

  factory FreyaConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FreyaConfig()..mergeFromBuffer(data, registry);
  factory FreyaConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FreyaConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FreyaConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: FreyaConfig.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'desc')
    ..aI(2, _omitFieldNames ? '' : 'type')
    ..aI(3, _omitFieldNames ? '' : 'issuedCnt')
    ..aOB(4, _omitFieldNames ? '' : 'isAlwaysShow')
    ..aI(5, _omitFieldNames ? '' : 'screenNumber')
    ..aI(6, _omitFieldNames ? '' : 'fullScreenNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FreyaConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FreyaConfig copyWith(void Function(FreyaConfig) updates) =>
      super.copyWith((message) => updates(message as FreyaConfig))
          as FreyaConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FreyaConfig() / FreyaConfig.new instead')
  static FreyaConfig create() => FreyaConfig._();
  static $pb.GeneratedMessage $_createMessage() => FreyaConfig._();
  @$core.override
  FreyaConfig createEmptyInstance() => FreyaConfig._();
  @$core.pragma('dart2js:noInline')
  static FreyaConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FreyaConfig>(
          FreyaConfig.$_createMessage);
  static FreyaConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get desc => $_getSZ(0);
  @$pb.TagNumber(1)
  set desc($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDesc() => $_has(0);
  @$pb.TagNumber(1)
  void clearDesc() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get type => $_getIZ(1);
  @$pb.TagNumber(2)
  set type($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get issuedCnt => $_getIZ(2);
  @$pb.TagNumber(3)
  set issuedCnt($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIssuedCnt() => $_has(2);
  @$pb.TagNumber(3)
  void clearIssuedCnt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isAlwaysShow => $_getBF(3);
  @$pb.TagNumber(4)
  set isAlwaysShow($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsAlwaysShow() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsAlwaysShow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get screenNumber => $_getIZ(4);
  @$pb.TagNumber(5)
  set screenNumber($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScreenNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearScreenNumber() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get fullScreenNumber => $_getIZ(5);
  @$pb.TagNumber(6)
  set fullScreenNumber($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFullScreenNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearFullScreenNumber() => $_clearField(6);
}

/// 渐变色信息
class GradientColor extends $pb.GeneratedMessage {
  factory GradientColor({
    $core.String? startColor,
    $core.String? endColor,
  }) {
    final result = GradientColor._();
    if (startColor != null) result.startColor = startColor;
    if (endColor != null) result.endColor = endColor;
    return result;
  }

  GradientColor._();

  factory GradientColor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GradientColor()..mergeFromBuffer(data, registry);
  factory GradientColor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GradientColor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GradientColor',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: GradientColor.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'startColor')
    ..aOS(2, _omitFieldNames ? '' : 'endColor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradientColor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradientColor copyWith(void Function(GradientColor) updates) =>
      super.copyWith((message) => updates(message as GradientColor))
          as GradientColor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GradientColor() / GradientColor.new instead')
  static GradientColor create() => GradientColor._();
  static $pb.GeneratedMessage $_createMessage() => GradientColor._();
  @$core.override
  GradientColor createEmptyInstance() => GradientColor._();
  @$core.pragma('dart2js:noInline')
  static GradientColor getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GradientColor>(
          GradientColor.$_createMessage);
  static GradientColor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get startColor => $_getSZ(0);
  @$pb.TagNumber(1)
  set startColor($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartColor() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartColor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get endColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set endColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndColor() => $_clearField(2);
}

/// 高画质试看信息
class HighDefinitionTrialInfo extends $pb.GeneratedMessage {
  factory HighDefinitionTrialInfo({
    $core.bool? trialAble,
    $core.int? remainingTimes,
    $core.int? start,
    $core.int? timeLength,
    Toast? startToast,
    Toast? endToast,
    Report? report,
    ButtonInfo? qualityOpenTipBtn,
    ButtonInfo? noLongerTrialBtn,
  }) {
    final result = HighDefinitionTrialInfo._();
    if (trialAble != null) result.trialAble = trialAble;
    if (remainingTimes != null) result.remainingTimes = remainingTimes;
    if (start != null) result.start = start;
    if (timeLength != null) result.timeLength = timeLength;
    if (startToast != null) result.startToast = startToast;
    if (endToast != null) result.endToast = endToast;
    if (report != null) result.report = report;
    if (qualityOpenTipBtn != null) result.qualityOpenTipBtn = qualityOpenTipBtn;
    if (noLongerTrialBtn != null) result.noLongerTrialBtn = noLongerTrialBtn;
    return result;
  }

  HighDefinitionTrialInfo._();

  factory HighDefinitionTrialInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HighDefinitionTrialInfo()..mergeFromBuffer(data, registry);
  factory HighDefinitionTrialInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HighDefinitionTrialInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HighDefinitionTrialInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: HighDefinitionTrialInfo.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'trialAble')
    ..aI(2, _omitFieldNames ? '' : 'remainingTimes')
    ..aI(3, _omitFieldNames ? '' : 'start')
    ..aI(4, _omitFieldNames ? '' : 'timeLength')
    ..aOM<Toast>(5, _omitFieldNames ? '' : 'startToast',
        subBuilder: Toast.$_createMessage)
    ..aOM<Toast>(6, _omitFieldNames ? '' : 'endToast',
        subBuilder: Toast.$_createMessage)
    ..aOM<Report>(7, _omitFieldNames ? '' : 'report',
        subBuilder: Report.$_createMessage)
    ..aOM<ButtonInfo>(8, _omitFieldNames ? '' : 'qualityOpenTipBtn',
        subBuilder: ButtonInfo.$_createMessage)
    ..aOM<ButtonInfo>(9, _omitFieldNames ? '' : 'noLongerTrialBtn',
        subBuilder: ButtonInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HighDefinitionTrialInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HighDefinitionTrialInfo copyWith(
          void Function(HighDefinitionTrialInfo) updates) =>
      super.copyWith((message) => updates(message as HighDefinitionTrialInfo))
          as HighDefinitionTrialInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use HighDefinitionTrialInfo() / HighDefinitionTrialInfo.new instead')
  static HighDefinitionTrialInfo create() => HighDefinitionTrialInfo._();
  static $pb.GeneratedMessage $_createMessage() => HighDefinitionTrialInfo._();
  @$core.override
  HighDefinitionTrialInfo createEmptyInstance() => HighDefinitionTrialInfo._();
  @$core.pragma('dart2js:noInline')
  static HighDefinitionTrialInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HighDefinitionTrialInfo>(
          HighDefinitionTrialInfo.$_createMessage);
  static HighDefinitionTrialInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get trialAble => $_getBF(0);
  @$pb.TagNumber(1)
  set trialAble($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrialAble() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrialAble() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get remainingTimes => $_getIZ(1);
  @$pb.TagNumber(2)
  set remainingTimes($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRemainingTimes() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemainingTimes() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get start => $_getIZ(2);
  @$pb.TagNumber(3)
  set start($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearStart() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get timeLength => $_getIZ(3);
  @$pb.TagNumber(4)
  set timeLength($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimeLength() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimeLength() => $_clearField(4);

  @$pb.TagNumber(5)
  Toast get startToast => $_getN(4);
  @$pb.TagNumber(5)
  set startToast(Toast value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStartToast() => $_has(4);
  @$pb.TagNumber(5)
  void clearStartToast() => $_clearField(5);
  @$pb.TagNumber(5)
  Toast ensureStartToast() => $_ensure(4);

  @$pb.TagNumber(6)
  Toast get endToast => $_getN(5);
  @$pb.TagNumber(6)
  set endToast(Toast value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasEndToast() => $_has(5);
  @$pb.TagNumber(6)
  void clearEndToast() => $_clearField(6);
  @$pb.TagNumber(6)
  Toast ensureEndToast() => $_ensure(5);

  @$pb.TagNumber(7)
  Report get report => $_getN(6);
  @$pb.TagNumber(7)
  set report(Report value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReport() => $_has(6);
  @$pb.TagNumber(7)
  void clearReport() => $_clearField(7);
  @$pb.TagNumber(7)
  Report ensureReport() => $_ensure(6);

  @$pb.TagNumber(8)
  ButtonInfo get qualityOpenTipBtn => $_getN(7);
  @$pb.TagNumber(8)
  set qualityOpenTipBtn(ButtonInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasQualityOpenTipBtn() => $_has(7);
  @$pb.TagNumber(8)
  void clearQualityOpenTipBtn() => $_clearField(8);
  @$pb.TagNumber(8)
  ButtonInfo ensureQualityOpenTipBtn() => $_ensure(7);

  @$pb.TagNumber(9)
  ButtonInfo get noLongerTrialBtn => $_getN(8);
  @$pb.TagNumber(9)
  set noLongerTrialBtn(ButtonInfo value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasNoLongerTrialBtn() => $_has(8);
  @$pb.TagNumber(9)
  void clearNoLongerTrialBtn() => $_clearField(9);
  @$pb.TagNumber(9)
  ButtonInfo ensureNoLongerTrialBtn() => $_ensure(8);
}

/// 历史记录节点
class HistoryNode extends $pb.GeneratedMessage {
  factory HistoryNode({
    $fixnum.Int64? nodeId,
    $core.String? title,
    $fixnum.Int64? cid,
  }) {
    final result = HistoryNode._();
    if (nodeId != null) result.nodeId = nodeId;
    if (title != null) result.title = title;
    if (cid != null) result.cid = cid;
    return result;
  }

  HistoryNode._();

  factory HistoryNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HistoryNode()..mergeFromBuffer(data, registry);
  factory HistoryNode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HistoryNode()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoryNode',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: HistoryNode.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'nodeId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryNode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryNode copyWith(void Function(HistoryNode) updates) =>
      super.copyWith((message) => updates(message as HistoryNode))
          as HistoryNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HistoryNode() / HistoryNode.new instead')
  static HistoryNode create() => HistoryNode._();
  static $pb.GeneratedMessage $_createMessage() => HistoryNode._();
  @$core.override
  HistoryNode createEmptyInstance() => HistoryNode._();
  @$core.pragma('dart2js:noInline')
  static HistoryNode getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HistoryNode>(
          HistoryNode.$_createMessage);
  static HistoryNode? _defaultInstance;

  /// 节点ID
  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  /// 节点标题
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// 对应CID
  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);
}

/// 图片信息
class ImageInfo extends $pb.GeneratedMessage {
  factory ImageInfo({
    $core.String? url,
  }) {
    final result = ImageInfo._();
    if (url != null) result.url = url;
    return result;
  }

  ImageInfo._();

  factory ImageInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageInfo()..mergeFromBuffer(data, registry);
  factory ImageInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: ImageInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageInfo copyWith(void Function(ImageInfo) updates) =>
      super.copyWith((message) => updates(message as ImageInfo)) as ImageInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageInfo() / ImageInfo.new instead')
  static ImageInfo create() => ImageInfo._();
  static $pb.GeneratedMessage $_createMessage() => ImageInfo._();
  @$core.override
  ImageInfo createEmptyInstance() => ImageInfo._();
  @$core.pragma('dart2js:noInline')
  static ImageInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImageInfo>(ImageInfo.$_createMessage);
  static ImageInfo? _defaultInstance;

  /// 图片链接
  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);
}

/// 交互信息
class Interaction extends $pb.GeneratedMessage {
  factory Interaction({
    HistoryNode? historyNode,
    $fixnum.Int64? graphVersion,
    $core.String? msg,
    $core.bool? isInteraction,
  }) {
    final result = Interaction._();
    if (historyNode != null) result.historyNode = historyNode;
    if (graphVersion != null) result.graphVersion = graphVersion;
    if (msg != null) result.msg = msg;
    if (isInteraction != null) result.isInteraction = isInteraction;
    return result;
  }

  Interaction._();

  factory Interaction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Interaction()..mergeFromBuffer(data, registry);
  factory Interaction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Interaction()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Interaction',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Interaction.$_createMessage)
    ..aOM<HistoryNode>(1, _omitFieldNames ? '' : 'historyNode',
        subBuilder: HistoryNode.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'graphVersion')
    ..aOS(3, _omitFieldNames ? '' : 'msg')
    ..aOB(4, _omitFieldNames ? '' : 'isInteraction')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Interaction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Interaction copyWith(void Function(Interaction) updates) =>
      super.copyWith((message) => updates(message as Interaction))
          as Interaction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Interaction() / Interaction.new instead')
  static Interaction create() => Interaction._();
  static $pb.GeneratedMessage $_createMessage() => Interaction._();
  @$core.override
  Interaction createEmptyInstance() => Interaction._();
  @$core.pragma('dart2js:noInline')
  static Interaction getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Interaction>(
          Interaction.$_createMessage);
  static Interaction? _defaultInstance;

  /// 历史节点
  @$pb.TagNumber(1)
  HistoryNode get historyNode => $_getN(0);
  @$pb.TagNumber(1)
  set historyNode(HistoryNode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHistoryNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearHistoryNode() => $_clearField(1);
  @$pb.TagNumber(1)
  HistoryNode ensureHistoryNode() => $_ensure(0);

  /// 版本
  @$pb.TagNumber(2)
  $fixnum.Int64 get graphVersion => $_getI64(1);
  @$pb.TagNumber(2)
  set graphVersion($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGraphVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearGraphVersion() => $_clearField(2);

  /// 交互消息
  @$pb.TagNumber(3)
  $core.String get msg => $_getSZ(2);
  @$pb.TagNumber(3)
  set msg($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMsg() => $_has(2);
  @$pb.TagNumber(3)
  void clearMsg() => $_clearField(3);

  /// 是否为交互
  @$pb.TagNumber(4)
  $core.bool get isInteraction => $_getBF(3);
  @$pb.TagNumber(4)
  set isInteraction($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsInteraction() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsInteraction() => $_clearField(4);
}

class MultiView extends $pb.GeneratedMessage {
  factory MultiView({
    $core.String? buttonMaterial,
    $fixnum.Int64? epId,
    $fixnum.Int64? cid,
    $fixnum.Int64? avid,
  }) {
    final result = MultiView._();
    if (buttonMaterial != null) result.buttonMaterial = buttonMaterial;
    if (epId != null) result.epId = epId;
    if (cid != null) result.cid = cid;
    if (avid != null) result.avid = avid;
    return result;
  }

  MultiView._();

  factory MultiView.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MultiView()..mergeFromBuffer(data, registry);
  factory MultiView.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MultiView()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MultiView',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: MultiView.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'buttonMaterial')
    ..aInt64(2, _omitFieldNames ? '' : 'epId')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..aInt64(4, _omitFieldNames ? '' : 'avid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MultiView clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MultiView copyWith(void Function(MultiView) updates) =>
      super.copyWith((message) => updates(message as MultiView)) as MultiView;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MultiView() / MultiView.new instead')
  static MultiView create() => MultiView._();
  static $pb.GeneratedMessage $_createMessage() => MultiView._();
  @$core.override
  MultiView createEmptyInstance() => MultiView._();
  @$core.pragma('dart2js:noInline')
  static MultiView getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MultiView>(MultiView.$_createMessage);
  static MultiView? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buttonMaterial => $_getSZ(0);
  @$pb.TagNumber(1)
  set buttonMaterial($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasButtonMaterial() => $_has(0);
  @$pb.TagNumber(1)
  void clearButtonMaterial() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get epId => $_getI64(1);
  @$pb.TagNumber(2)
  set epId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEpId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEpId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get avid => $_getI64(3);
  @$pb.TagNumber(4)
  set avid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvid() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvid() => $_clearField(4);
}

/// 大会员广告: 支付提示信息
class PayTip extends $pb.GeneratedMessage {
  factory PayTip({
    $core.String? title,
    $core.String? url,
    $core.String? icon,
    $core.int? type,
    $core.int? showType,
    $core.String? img,
    $core.String? bgDayColor,
    $core.String? bgNightColor,
    $core.String? bgLineColor,
    $core.String? bgNightLineColor,
    $core.String? textColor,
    $core.String? textNightColor,
    $fixnum.Int64? viewStartTime,
    $core.Iterable<ButtonInfo>? button,
    $core.int? urlOpenType,
    Report? report,
    $core.int? angleStyle,
    $core.int? reportType,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        orderReportParams,
    $core.String? giantScreenImg,
  }) {
    final result = PayTip._();
    if (title != null) result.title = title;
    if (url != null) result.url = url;
    if (icon != null) result.icon = icon;
    if (type != null) result.type = type;
    if (showType != null) result.showType = showType;
    if (img != null) result.img = img;
    if (bgDayColor != null) result.bgDayColor = bgDayColor;
    if (bgNightColor != null) result.bgNightColor = bgNightColor;
    if (bgLineColor != null) result.bgLineColor = bgLineColor;
    if (bgNightLineColor != null) result.bgNightLineColor = bgNightLineColor;
    if (textColor != null) result.textColor = textColor;
    if (textNightColor != null) result.textNightColor = textNightColor;
    if (viewStartTime != null) result.viewStartTime = viewStartTime;
    if (button != null) result.button.addAll(button);
    if (urlOpenType != null) result.urlOpenType = urlOpenType;
    if (report != null) result.report = report;
    if (angleStyle != null) result.angleStyle = angleStyle;
    if (reportType != null) result.reportType = reportType;
    if (orderReportParams != null)
      result.orderReportParams.addEntries(orderReportParams);
    if (giantScreenImg != null) result.giantScreenImg = giantScreenImg;
    return result;
  }

  PayTip._();

  factory PayTip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PayTip()..mergeFromBuffer(data, registry);
  factory PayTip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PayTip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PayTip',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PayTip.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aI(4, _omitFieldNames ? '' : 'type')
    ..aI(5, _omitFieldNames ? '' : 'showType')
    ..aOS(6, _omitFieldNames ? '' : 'img')
    ..aOS(7, _omitFieldNames ? '' : 'bgDayColor')
    ..aOS(8, _omitFieldNames ? '' : 'bgNightColor')
    ..aOS(9, _omitFieldNames ? '' : 'bgLineColor')
    ..aOS(10, _omitFieldNames ? '' : 'bgNightLineColor')
    ..aOS(11, _omitFieldNames ? '' : 'textColor')
    ..aOS(12, _omitFieldNames ? '' : 'textNightColor')
    ..aInt64(13, _omitFieldNames ? '' : 'viewStartTime')
    ..pPM<ButtonInfo>(14, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonInfo.$_createMessage)
    ..aI(15, _omitFieldNames ? '' : 'urlOpenType')
    ..aOM<Report>(16, _omitFieldNames ? '' : 'report',
        subBuilder: Report.$_createMessage)
    ..aI(17, _omitFieldNames ? '' : 'angleStyle')
    ..aI(18, _omitFieldNames ? '' : 'reportType')
    ..m<$core.String, $core.String>(
        19, _omitFieldNames ? '' : 'orderReportParams',
        entryClassName: 'PayTip.OrderReportParamsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..aOS(20, _omitFieldNames ? '' : 'giantScreenImg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayTip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PayTip copyWith(void Function(PayTip) updates) =>
      super.copyWith((message) => updates(message as PayTip)) as PayTip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PayTip() / PayTip.new instead')
  static PayTip create() => PayTip._();
  static $pb.GeneratedMessage $_createMessage() => PayTip._();
  @$core.override
  PayTip createEmptyInstance() => PayTip._();
  @$core.pragma('dart2js:noInline')
  static PayTip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PayTip>(PayTip.$_createMessage);
  static PayTip? _defaultInstance;

  /// 标题
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 跳转链接
  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  /// 图标
  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  /// 浮层类型
  @$pb.TagNumber(4)
  $core.int get type => $_getIZ(3);
  @$pb.TagNumber(4)
  set type($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  /// 显示类型
  @$pb.TagNumber(5)
  $core.int get showType => $_getIZ(4);
  @$pb.TagNumber(5)
  set showType($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShowType() => $_has(4);
  @$pb.TagNumber(5)
  void clearShowType() => $_clearField(5);

  /// 图片信息
  @$pb.TagNumber(6)
  $core.String get img => $_getSZ(5);
  @$pb.TagNumber(6)
  set img($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImg() => $_has(5);
  @$pb.TagNumber(6)
  void clearImg() => $_clearField(6);

  /// 白天背景颜色
  @$pb.TagNumber(7)
  $core.String get bgDayColor => $_getSZ(6);
  @$pb.TagNumber(7)
  set bgDayColor($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBgDayColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearBgDayColor() => $_clearField(7);

  /// 夜间背景颜色
  @$pb.TagNumber(8)
  $core.String get bgNightColor => $_getSZ(7);
  @$pb.TagNumber(8)
  set bgNightColor($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBgNightColor() => $_has(7);
  @$pb.TagNumber(8)
  void clearBgNightColor() => $_clearField(8);

  /// 白天线条颜色
  @$pb.TagNumber(9)
  $core.String get bgLineColor => $_getSZ(8);
  @$pb.TagNumber(9)
  set bgLineColor($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBgLineColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearBgLineColor() => $_clearField(9);

  /// 夜间线条颜色
  @$pb.TagNumber(10)
  $core.String get bgNightLineColor => $_getSZ(9);
  @$pb.TagNumber(10)
  set bgNightLineColor($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBgNightLineColor() => $_has(9);
  @$pb.TagNumber(10)
  void clearBgNightLineColor() => $_clearField(10);

  /// 文字颜色
  @$pb.TagNumber(11)
  $core.String get textColor => $_getSZ(10);
  @$pb.TagNumber(11)
  set textColor($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTextColor() => $_has(10);
  @$pb.TagNumber(11)
  void clearTextColor() => $_clearField(11);

  /// 夜间文字颜色
  @$pb.TagNumber(12)
  $core.String get textNightColor => $_getSZ(11);
  @$pb.TagNumber(12)
  set textNightColor($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasTextNightColor() => $_has(11);
  @$pb.TagNumber(12)
  void clearTextNightColor() => $_clearField(12);

  /// 视图展示起始时间
  @$pb.TagNumber(13)
  $fixnum.Int64 get viewStartTime => $_getI64(12);
  @$pb.TagNumber(13)
  set viewStartTime($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasViewStartTime() => $_has(12);
  @$pb.TagNumber(13)
  void clearViewStartTime() => $_clearField(13);

  /// 按钮列表
  @$pb.TagNumber(14)
  $pb.PbList<ButtonInfo> get button => $_getList(13);

  /// 跳转链接打开方式
  @$pb.TagNumber(15)
  $core.int get urlOpenType => $_getIZ(14);
  @$pb.TagNumber(15)
  set urlOpenType($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasUrlOpenType() => $_has(14);
  @$pb.TagNumber(15)
  void clearUrlOpenType() => $_clearField(15);

  /// 埋点上报信息
  @$pb.TagNumber(16)
  Report get report => $_getN(15);
  @$pb.TagNumber(16)
  set report(Report value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasReport() => $_has(15);
  @$pb.TagNumber(16)
  void clearReport() => $_clearField(16);
  @$pb.TagNumber(16)
  Report ensureReport() => $_ensure(15);

  /// 角度样式
  @$pb.TagNumber(17)
  $core.int get angleStyle => $_getIZ(16);
  @$pb.TagNumber(17)
  set angleStyle($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasAngleStyle() => $_has(16);
  @$pb.TagNumber(17)
  void clearAngleStyle() => $_clearField(17);

  /// 埋点上报类型
  @$pb.TagNumber(18)
  $core.int get reportType => $_getIZ(17);
  @$pb.TagNumber(18)
  set reportType($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasReportType() => $_has(17);
  @$pb.TagNumber(18)
  void clearReportType() => $_clearField(18);

  /// 订单埋点上报参数
  @$pb.TagNumber(19)
  $pb.PbMap<$core.String, $core.String> get orderReportParams => $_getMap(18);

  /// 巨屏图片信息
  @$pb.TagNumber(20)
  $core.String get giantScreenImg => $_getSZ(19);
  @$pb.TagNumber(20)
  set giantScreenImg($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasGiantScreenImg() => $_has(19);
  @$pb.TagNumber(20)
  void clearGiantScreenImg() => $_clearField(20);
}

/// 禁用功能配置
class PlayAbilityConf extends $pb.GeneratedMessage {
  factory PlayAbilityConf({
    $core.bool? backgroundPlayDisable,
    $core.bool? flipDisable,
    $core.bool? castDisable,
    $core.bool? feedbackDisable,
    $core.bool? subtitleDisable,
    $core.bool? playbackRateDisable,
    $core.bool? timeUpDisable,
    $core.bool? playbackModeDisable,
    $core.bool? scaleModeDisable,
    $core.bool? likeDisable,
    $core.bool? dislikeDisable,
    $core.bool? coinDisable,
    $core.bool? elecDisable,
    $core.bool? shareDisable,
    $core.bool? screenShotDisable,
    $core.bool? lockScreenDisable,
    $core.bool? recommendDisable,
    $core.bool? playbackSpeedDisable,
    $core.bool? definitionDisable,
    $core.bool? selectionsDisable,
    $core.bool? nextDisable,
    $core.bool? editDmDisable,
    $core.bool? smallWindowDisable,
    $core.bool? shakeDisable,
    $core.bool? outerDmDisable,
    $core.bool? innerDmDisable,
    $core.bool? freyaEnterDisable,
    $core.bool? dolbyDisable,
    $core.bool? freyaFullDisable,
    $core.bool? skipOpedSwitchDisable,
    $core.bool? recordScreenDisable,
    $core.bool? colorOptimizeDisable,
    $core.bool? dubbingDisable,
  }) {
    final result = PlayAbilityConf._();
    if (backgroundPlayDisable != null)
      result.backgroundPlayDisable = backgroundPlayDisable;
    if (flipDisable != null) result.flipDisable = flipDisable;
    if (castDisable != null) result.castDisable = castDisable;
    if (feedbackDisable != null) result.feedbackDisable = feedbackDisable;
    if (subtitleDisable != null) result.subtitleDisable = subtitleDisable;
    if (playbackRateDisable != null)
      result.playbackRateDisable = playbackRateDisable;
    if (timeUpDisable != null) result.timeUpDisable = timeUpDisable;
    if (playbackModeDisable != null)
      result.playbackModeDisable = playbackModeDisable;
    if (scaleModeDisable != null) result.scaleModeDisable = scaleModeDisable;
    if (likeDisable != null) result.likeDisable = likeDisable;
    if (dislikeDisable != null) result.dislikeDisable = dislikeDisable;
    if (coinDisable != null) result.coinDisable = coinDisable;
    if (elecDisable != null) result.elecDisable = elecDisable;
    if (shareDisable != null) result.shareDisable = shareDisable;
    if (screenShotDisable != null) result.screenShotDisable = screenShotDisable;
    if (lockScreenDisable != null) result.lockScreenDisable = lockScreenDisable;
    if (recommendDisable != null) result.recommendDisable = recommendDisable;
    if (playbackSpeedDisable != null)
      result.playbackSpeedDisable = playbackSpeedDisable;
    if (definitionDisable != null) result.definitionDisable = definitionDisable;
    if (selectionsDisable != null) result.selectionsDisable = selectionsDisable;
    if (nextDisable != null) result.nextDisable = nextDisable;
    if (editDmDisable != null) result.editDmDisable = editDmDisable;
    if (smallWindowDisable != null)
      result.smallWindowDisable = smallWindowDisable;
    if (shakeDisable != null) result.shakeDisable = shakeDisable;
    if (outerDmDisable != null) result.outerDmDisable = outerDmDisable;
    if (innerDmDisable != null) result.innerDmDisable = innerDmDisable;
    if (freyaEnterDisable != null) result.freyaEnterDisable = freyaEnterDisable;
    if (dolbyDisable != null) result.dolbyDisable = dolbyDisable;
    if (freyaFullDisable != null) result.freyaFullDisable = freyaFullDisable;
    if (skipOpedSwitchDisable != null)
      result.skipOpedSwitchDisable = skipOpedSwitchDisable;
    if (recordScreenDisable != null)
      result.recordScreenDisable = recordScreenDisable;
    if (colorOptimizeDisable != null)
      result.colorOptimizeDisable = colorOptimizeDisable;
    if (dubbingDisable != null) result.dubbingDisable = dubbingDisable;
    return result;
  }

  PlayAbilityConf._();

  factory PlayAbilityConf.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayAbilityConf()..mergeFromBuffer(data, registry);
  factory PlayAbilityConf.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayAbilityConf()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayAbilityConf',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayAbilityConf.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'backgroundPlayDisable')
    ..aOB(2, _omitFieldNames ? '' : 'flipDisable')
    ..aOB(3, _omitFieldNames ? '' : 'castDisable')
    ..aOB(4, _omitFieldNames ? '' : 'feedbackDisable')
    ..aOB(5, _omitFieldNames ? '' : 'subtitleDisable')
    ..aOB(6, _omitFieldNames ? '' : 'playbackRateDisable')
    ..aOB(7, _omitFieldNames ? '' : 'timeUpDisable')
    ..aOB(8, _omitFieldNames ? '' : 'playbackModeDisable')
    ..aOB(9, _omitFieldNames ? '' : 'scaleModeDisable')
    ..aOB(10, _omitFieldNames ? '' : 'likeDisable')
    ..aOB(11, _omitFieldNames ? '' : 'dislikeDisable')
    ..aOB(12, _omitFieldNames ? '' : 'coinDisable')
    ..aOB(13, _omitFieldNames ? '' : 'elecDisable')
    ..aOB(14, _omitFieldNames ? '' : 'shareDisable')
    ..aOB(15, _omitFieldNames ? '' : 'screenShotDisable')
    ..aOB(16, _omitFieldNames ? '' : 'lockScreenDisable')
    ..aOB(17, _omitFieldNames ? '' : 'recommendDisable')
    ..aOB(18, _omitFieldNames ? '' : 'playbackSpeedDisable')
    ..aOB(19, _omitFieldNames ? '' : 'definitionDisable')
    ..aOB(20, _omitFieldNames ? '' : 'selectionsDisable')
    ..aOB(21, _omitFieldNames ? '' : 'nextDisable')
    ..aOB(22, _omitFieldNames ? '' : 'editDmDisable')
    ..aOB(23, _omitFieldNames ? '' : 'smallWindowDisable')
    ..aOB(24, _omitFieldNames ? '' : 'shakeDisable')
    ..aOB(25, _omitFieldNames ? '' : 'outerDmDisable')
    ..aOB(26, _omitFieldNames ? '' : 'innerDmDisable')
    ..aOB(27, _omitFieldNames ? '' : 'freyaEnterDisable')
    ..aOB(28, _omitFieldNames ? '' : 'dolbyDisable')
    ..aOB(29, _omitFieldNames ? '' : 'freyaFullDisable')
    ..aOB(30, _omitFieldNames ? '' : 'skipOpedSwitchDisable')
    ..aOB(31, _omitFieldNames ? '' : 'recordScreenDisable')
    ..aOB(32, _omitFieldNames ? '' : 'colorOptimizeDisable')
    ..aOB(33, _omitFieldNames ? '' : 'dubbingDisable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayAbilityConf clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayAbilityConf copyWith(void Function(PlayAbilityConf) updates) =>
      super.copyWith((message) => updates(message as PlayAbilityConf))
          as PlayAbilityConf;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayAbilityConf() / PlayAbilityConf.new instead')
  static PlayAbilityConf create() => PlayAbilityConf._();
  static $pb.GeneratedMessage $_createMessage() => PlayAbilityConf._();
  @$core.override
  PlayAbilityConf createEmptyInstance() => PlayAbilityConf._();
  @$core.pragma('dart2js:noInline')
  static PlayAbilityConf getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayAbilityConf>(
          PlayAbilityConf.$_createMessage);
  static PlayAbilityConf? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get backgroundPlayDisable => $_getBF(0);
  @$pb.TagNumber(1)
  set backgroundPlayDisable($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackgroundPlayDisable() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackgroundPlayDisable() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get flipDisable => $_getBF(1);
  @$pb.TagNumber(2)
  set flipDisable($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFlipDisable() => $_has(1);
  @$pb.TagNumber(2)
  void clearFlipDisable() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get castDisable => $_getBF(2);
  @$pb.TagNumber(3)
  set castDisable($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCastDisable() => $_has(2);
  @$pb.TagNumber(3)
  void clearCastDisable() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get feedbackDisable => $_getBF(3);
  @$pb.TagNumber(4)
  set feedbackDisable($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFeedbackDisable() => $_has(3);
  @$pb.TagNumber(4)
  void clearFeedbackDisable() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get subtitleDisable => $_getBF(4);
  @$pb.TagNumber(5)
  set subtitleDisable($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSubtitleDisable() => $_has(4);
  @$pb.TagNumber(5)
  void clearSubtitleDisable() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get playbackRateDisable => $_getBF(5);
  @$pb.TagNumber(6)
  set playbackRateDisable($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPlaybackRateDisable() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlaybackRateDisable() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get timeUpDisable => $_getBF(6);
  @$pb.TagNumber(7)
  set timeUpDisable($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimeUpDisable() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimeUpDisable() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get playbackModeDisable => $_getBF(7);
  @$pb.TagNumber(8)
  set playbackModeDisable($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPlaybackModeDisable() => $_has(7);
  @$pb.TagNumber(8)
  void clearPlaybackModeDisable() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get scaleModeDisable => $_getBF(8);
  @$pb.TagNumber(9)
  set scaleModeDisable($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasScaleModeDisable() => $_has(8);
  @$pb.TagNumber(9)
  void clearScaleModeDisable() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get likeDisable => $_getBF(9);
  @$pb.TagNumber(10)
  set likeDisable($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLikeDisable() => $_has(9);
  @$pb.TagNumber(10)
  void clearLikeDisable() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get dislikeDisable => $_getBF(10);
  @$pb.TagNumber(11)
  set dislikeDisable($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasDislikeDisable() => $_has(10);
  @$pb.TagNumber(11)
  void clearDislikeDisable() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get coinDisable => $_getBF(11);
  @$pb.TagNumber(12)
  set coinDisable($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCoinDisable() => $_has(11);
  @$pb.TagNumber(12)
  void clearCoinDisable() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get elecDisable => $_getBF(12);
  @$pb.TagNumber(13)
  set elecDisable($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasElecDisable() => $_has(12);
  @$pb.TagNumber(13)
  void clearElecDisable() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get shareDisable => $_getBF(13);
  @$pb.TagNumber(14)
  set shareDisable($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasShareDisable() => $_has(13);
  @$pb.TagNumber(14)
  void clearShareDisable() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get screenShotDisable => $_getBF(14);
  @$pb.TagNumber(15)
  set screenShotDisable($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasScreenShotDisable() => $_has(14);
  @$pb.TagNumber(15)
  void clearScreenShotDisable() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get lockScreenDisable => $_getBF(15);
  @$pb.TagNumber(16)
  set lockScreenDisable($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasLockScreenDisable() => $_has(15);
  @$pb.TagNumber(16)
  void clearLockScreenDisable() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get recommendDisable => $_getBF(16);
  @$pb.TagNumber(17)
  set recommendDisable($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(17)
  $core.bool hasRecommendDisable() => $_has(16);
  @$pb.TagNumber(17)
  void clearRecommendDisable() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.bool get playbackSpeedDisable => $_getBF(17);
  @$pb.TagNumber(18)
  set playbackSpeedDisable($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(18)
  $core.bool hasPlaybackSpeedDisable() => $_has(17);
  @$pb.TagNumber(18)
  void clearPlaybackSpeedDisable() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.bool get definitionDisable => $_getBF(18);
  @$pb.TagNumber(19)
  set definitionDisable($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(19)
  $core.bool hasDefinitionDisable() => $_has(18);
  @$pb.TagNumber(19)
  void clearDefinitionDisable() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.bool get selectionsDisable => $_getBF(19);
  @$pb.TagNumber(20)
  set selectionsDisable($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(20)
  $core.bool hasSelectionsDisable() => $_has(19);
  @$pb.TagNumber(20)
  void clearSelectionsDisable() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.bool get nextDisable => $_getBF(20);
  @$pb.TagNumber(21)
  set nextDisable($core.bool value) => $_setBool(20, value);
  @$pb.TagNumber(21)
  $core.bool hasNextDisable() => $_has(20);
  @$pb.TagNumber(21)
  void clearNextDisable() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.bool get editDmDisable => $_getBF(21);
  @$pb.TagNumber(22)
  set editDmDisable($core.bool value) => $_setBool(21, value);
  @$pb.TagNumber(22)
  $core.bool hasEditDmDisable() => $_has(21);
  @$pb.TagNumber(22)
  void clearEditDmDisable() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.bool get smallWindowDisable => $_getBF(22);
  @$pb.TagNumber(23)
  set smallWindowDisable($core.bool value) => $_setBool(22, value);
  @$pb.TagNumber(23)
  $core.bool hasSmallWindowDisable() => $_has(22);
  @$pb.TagNumber(23)
  void clearSmallWindowDisable() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.bool get shakeDisable => $_getBF(23);
  @$pb.TagNumber(24)
  set shakeDisable($core.bool value) => $_setBool(23, value);
  @$pb.TagNumber(24)
  $core.bool hasShakeDisable() => $_has(23);
  @$pb.TagNumber(24)
  void clearShakeDisable() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.bool get outerDmDisable => $_getBF(24);
  @$pb.TagNumber(25)
  set outerDmDisable($core.bool value) => $_setBool(24, value);
  @$pb.TagNumber(25)
  $core.bool hasOuterDmDisable() => $_has(24);
  @$pb.TagNumber(25)
  void clearOuterDmDisable() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.bool get innerDmDisable => $_getBF(25);
  @$pb.TagNumber(26)
  set innerDmDisable($core.bool value) => $_setBool(25, value);
  @$pb.TagNumber(26)
  $core.bool hasInnerDmDisable() => $_has(25);
  @$pb.TagNumber(26)
  void clearInnerDmDisable() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.bool get freyaEnterDisable => $_getBF(26);
  @$pb.TagNumber(27)
  set freyaEnterDisable($core.bool value) => $_setBool(26, value);
  @$pb.TagNumber(27)
  $core.bool hasFreyaEnterDisable() => $_has(26);
  @$pb.TagNumber(27)
  void clearFreyaEnterDisable() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.bool get dolbyDisable => $_getBF(27);
  @$pb.TagNumber(28)
  set dolbyDisable($core.bool value) => $_setBool(27, value);
  @$pb.TagNumber(28)
  $core.bool hasDolbyDisable() => $_has(27);
  @$pb.TagNumber(28)
  void clearDolbyDisable() => $_clearField(28);

  @$pb.TagNumber(29)
  $core.bool get freyaFullDisable => $_getBF(28);
  @$pb.TagNumber(29)
  set freyaFullDisable($core.bool value) => $_setBool(28, value);
  @$pb.TagNumber(29)
  $core.bool hasFreyaFullDisable() => $_has(28);
  @$pb.TagNumber(29)
  void clearFreyaFullDisable() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.bool get skipOpedSwitchDisable => $_getBF(29);
  @$pb.TagNumber(30)
  set skipOpedSwitchDisable($core.bool value) => $_setBool(29, value);
  @$pb.TagNumber(30)
  $core.bool hasSkipOpedSwitchDisable() => $_has(29);
  @$pb.TagNumber(30)
  void clearSkipOpedSwitchDisable() => $_clearField(30);

  @$pb.TagNumber(31)
  $core.bool get recordScreenDisable => $_getBF(30);
  @$pb.TagNumber(31)
  set recordScreenDisable($core.bool value) => $_setBool(30, value);
  @$pb.TagNumber(31)
  $core.bool hasRecordScreenDisable() => $_has(30);
  @$pb.TagNumber(31)
  void clearRecordScreenDisable() => $_clearField(31);

  @$pb.TagNumber(32)
  $core.bool get colorOptimizeDisable => $_getBF(31);
  @$pb.TagNumber(32)
  set colorOptimizeDisable($core.bool value) => $_setBool(31, value);
  @$pb.TagNumber(32)
  $core.bool hasColorOptimizeDisable() => $_has(31);
  @$pb.TagNumber(32)
  void clearColorOptimizeDisable() => $_clearField(32);

  @$pb.TagNumber(33)
  $core.bool get dubbingDisable => $_getBF(32);
  @$pb.TagNumber(33)
  set dubbingDisable($core.bool value) => $_setBool(32, value);
  @$pb.TagNumber(33)
  $core.bool hasDubbingDisable() => $_has(32);
  @$pb.TagNumber(33)
  void clearDubbingDisable() => $_clearField(33);
}

/// 云控扩展配置信息
class PlayAbilityExtConf extends $pb.GeneratedMessage {
  factory PlayAbilityExtConf({
    $core.bool? allowCloseSubtitle,
    FreyaConfig? freyaConfig,
    CastTips? castTips,
  }) {
    final result = PlayAbilityExtConf._();
    if (allowCloseSubtitle != null)
      result.allowCloseSubtitle = allowCloseSubtitle;
    if (freyaConfig != null) result.freyaConfig = freyaConfig;
    if (castTips != null) result.castTips = castTips;
    return result;
  }

  PlayAbilityExtConf._();

  factory PlayAbilityExtConf.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayAbilityExtConf()..mergeFromBuffer(data, registry);
  factory PlayAbilityExtConf.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayAbilityExtConf()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayAbilityExtConf',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayAbilityExtConf.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'allowCloseSubtitle')
    ..aOM<FreyaConfig>(2, _omitFieldNames ? '' : 'freyaConfig',
        subBuilder: FreyaConfig.$_createMessage)
    ..aOM<CastTips>(3, _omitFieldNames ? '' : 'castTips',
        subBuilder: CastTips.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayAbilityExtConf clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayAbilityExtConf copyWith(void Function(PlayAbilityExtConf) updates) =>
      super.copyWith((message) => updates(message as PlayAbilityExtConf))
          as PlayAbilityExtConf;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayAbilityExtConf() / PlayAbilityExtConf.new instead')
  static PlayAbilityExtConf create() => PlayAbilityExtConf._();
  static $pb.GeneratedMessage $_createMessage() => PlayAbilityExtConf._();
  @$core.override
  PlayAbilityExtConf createEmptyInstance() => PlayAbilityExtConf._();
  @$core.pragma('dart2js:noInline')
  static PlayAbilityExtConf getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayAbilityExtConf>(
          PlayAbilityExtConf.$_createMessage);
  static PlayAbilityExtConf? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get allowCloseSubtitle => $_getBF(0);
  @$pb.TagNumber(1)
  set allowCloseSubtitle($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllowCloseSubtitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllowCloseSubtitle() => $_clearField(1);

  @$pb.TagNumber(2)
  FreyaConfig get freyaConfig => $_getN(1);
  @$pb.TagNumber(2)
  set freyaConfig(FreyaConfig value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFreyaConfig() => $_has(1);
  @$pb.TagNumber(2)
  void clearFreyaConfig() => $_clearField(2);
  @$pb.TagNumber(2)
  FreyaConfig ensureFreyaConfig() => $_ensure(1);

  @$pb.TagNumber(3)
  CastTips get castTips => $_getN(2);
  @$pb.TagNumber(3)
  set castTips(CastTips value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCastTips() => $_has(2);
  @$pb.TagNumber(3)
  void clearCastTips() => $_clearField(3);
  @$pb.TagNumber(3)
  CastTips ensureCastTips() => $_ensure(2);
}

/// 播放配音信息
class PlayDubbingInfo extends $pb.GeneratedMessage {
  factory PlayDubbingInfo({
    AudioMaterialProto? backgroundAudio,
    $core.Iterable<RoleAudioProto>? roleAudioList,
    $core.String? guideText,
  }) {
    final result = PlayDubbingInfo._();
    if (backgroundAudio != null) result.backgroundAudio = backgroundAudio;
    if (roleAudioList != null) result.roleAudioList.addAll(roleAudioList);
    if (guideText != null) result.guideText = guideText;
    return result;
  }

  PlayDubbingInfo._();

  factory PlayDubbingInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayDubbingInfo()..mergeFromBuffer(data, registry);
  factory PlayDubbingInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayDubbingInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayDubbingInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayDubbingInfo.$_createMessage)
    ..aOM<AudioMaterialProto>(1, _omitFieldNames ? '' : 'backgroundAudio',
        subBuilder: AudioMaterialProto.$_createMessage)
    ..pPM<RoleAudioProto>(2, _omitFieldNames ? '' : 'roleAudioList',
        subBuilder: RoleAudioProto.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'guideText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayDubbingInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayDubbingInfo copyWith(void Function(PlayDubbingInfo) updates) =>
      super.copyWith((message) => updates(message as PlayDubbingInfo))
          as PlayDubbingInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayDubbingInfo() / PlayDubbingInfo.new instead')
  static PlayDubbingInfo create() => PlayDubbingInfo._();
  static $pb.GeneratedMessage $_createMessage() => PlayDubbingInfo._();
  @$core.override
  PlayDubbingInfo createEmptyInstance() => PlayDubbingInfo._();
  @$core.pragma('dart2js:noInline')
  static PlayDubbingInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayDubbingInfo>(
          PlayDubbingInfo.$_createMessage);
  static PlayDubbingInfo? _defaultInstance;

  /// 背景音频
  @$pb.TagNumber(1)
  AudioMaterialProto get backgroundAudio => $_getN(0);
  @$pb.TagNumber(1)
  set backgroundAudio(AudioMaterialProto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBackgroundAudio() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackgroundAudio() => $_clearField(1);
  @$pb.TagNumber(1)
  AudioMaterialProto ensureBackgroundAudio() => $_ensure(0);

  /// 角色音频列表
  @$pb.TagNumber(2)
  $pb.PbList<RoleAudioProto> get roleAudioList => $_getList(1);

  /// 引导文本
  @$pb.TagNumber(3)
  $core.String get guideText => $_getSZ(2);
  @$pb.TagNumber(3)
  set guideText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGuideText() => $_has(2);
  @$pb.TagNumber(3)
  void clearGuideText() => $_clearField(3);
}

/// 播放扩展信息
class PlayExtInfo extends $pb.GeneratedMessage {
  factory PlayExtInfo({
    PlayDubbingInfo? playDubbingInfo,
  }) {
    final result = PlayExtInfo._();
    if (playDubbingInfo != null) result.playDubbingInfo = playDubbingInfo;
    return result;
  }

  PlayExtInfo._();

  factory PlayExtInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayExtInfo()..mergeFromBuffer(data, registry);
  factory PlayExtInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayExtInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayExtInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayExtInfo.$_createMessage)
    ..aOM<PlayDubbingInfo>(1, _omitFieldNames ? '' : 'playDubbingInfo',
        subBuilder: PlayDubbingInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayExtInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayExtInfo copyWith(void Function(PlayExtInfo) updates) =>
      super.copyWith((message) => updates(message as PlayExtInfo))
          as PlayExtInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayExtInfo() / PlayExtInfo.new instead')
  static PlayExtInfo create() => PlayExtInfo._();
  static $pb.GeneratedMessage $_createMessage() => PlayExtInfo._();
  @$core.override
  PlayExtInfo createEmptyInstance() => PlayExtInfo._();
  @$core.pragma('dart2js:noInline')
  static PlayExtInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayExtInfo>(
          PlayExtInfo.$_createMessage);
  static PlayExtInfo? _defaultInstance;

  /// 播放配音信息
  @$pb.TagNumber(1)
  PlayDubbingInfo get playDubbingInfo => $_getN(0);
  @$pb.TagNumber(1)
  set playDubbingInfo(PlayDubbingInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPlayDubbingInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlayDubbingInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  PlayDubbingInfo ensurePlayDubbingInfo() => $_ensure(0);
}

class PlayList extends $pb.GeneratedMessage {
  factory PlayList({
    $core.int? seasonId,
    $core.String? title,
    $core.String? cover,
    $core.String? link,
    BadgeInfo? badgeInfo,
  }) {
    final result = PlayList._();
    if (seasonId != null) result.seasonId = seasonId;
    if (title != null) result.title = title;
    if (cover != null) result.cover = cover;
    if (link != null) result.link = link;
    if (badgeInfo != null) result.badgeInfo = badgeInfo;
    return result;
  }

  PlayList._();

  factory PlayList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayList()..mergeFromBuffer(data, registry);
  factory PlayList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayList',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayList.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'seasonId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'cover')
    ..aOS(4, _omitFieldNames ? '' : 'link')
    ..aOM<BadgeInfo>(5, _omitFieldNames ? '' : 'badgeInfo',
        subBuilder: BadgeInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayList copyWith(void Function(PlayList) updates) =>
      super.copyWith((message) => updates(message as PlayList)) as PlayList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayList() / PlayList.new instead')
  static PlayList create() => PlayList._();
  static $pb.GeneratedMessage $_createMessage() => PlayList._();
  @$core.override
  PlayList createEmptyInstance() => PlayList._();
  @$core.pragma('dart2js:noInline')
  static PlayList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayList>(PlayList.$_createMessage);
  static PlayList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get seasonId => $_getIZ(0);
  @$pb.TagNumber(1)
  set seasonId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get cover => $_getSZ(2);
  @$pb.TagNumber(3)
  set cover($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCover() => $_has(2);
  @$pb.TagNumber(3)
  void clearCover() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get link => $_getSZ(3);
  @$pb.TagNumber(4)
  set link($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLink() => $_has(3);
  @$pb.TagNumber(4)
  void clearLink() => $_clearField(4);

  @$pb.TagNumber(5)
  BadgeInfo get badgeInfo => $_getN(4);
  @$pb.TagNumber(5)
  set badgeInfo(BadgeInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBadgeInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearBadgeInfo() => $_clearField(5);
  @$pb.TagNumber(5)
  BadgeInfo ensureBadgeInfo() => $_ensure(4);
}

/// 其他业务信息
class PlayViewBusinessInfo extends $pb.GeneratedMessage {
  factory PlayViewBusinessInfo({
    $core.bool? isPreview,
    $core.bool? bp,
    $core.String? marlinToken,
    $core.String? playbackSpeedColor,
    ContinuePlayInfo? continuePlayInfo,
    $core.Iterable<ClipInfo>? clipInfo,
    InlineType? inlineType,
    $core.int? epWholeDuration,
    Dimension? dimension,
    $core.Iterable<$core.MapEntry<$core.int, QualityExtInfo>>? qualityExtMap,
    $core.Iterable<$core.MapEntry<$core.String, $core.int>>? expMap,
    DrmTechType? drmTechType,
    $core.int? limitActionType,
    $core.bool? isDrm,
    RecordInfo? recordInfo,
    $core.int? vipStatus,
    $core.bool? isLivePre,
    EpisodeInfo? episodeInfo,
    EpisodeAdvertisementInfo? episodeAdvertisementInfo,
    UserStatus? userStatus,
  }) {
    final result = PlayViewBusinessInfo._();
    if (isPreview != null) result.isPreview = isPreview;
    if (bp != null) result.bp = bp;
    if (marlinToken != null) result.marlinToken = marlinToken;
    if (playbackSpeedColor != null)
      result.playbackSpeedColor = playbackSpeedColor;
    if (continuePlayInfo != null) result.continuePlayInfo = continuePlayInfo;
    if (clipInfo != null) result.clipInfo.addAll(clipInfo);
    if (inlineType != null) result.inlineType = inlineType;
    if (epWholeDuration != null) result.epWholeDuration = epWholeDuration;
    if (dimension != null) result.dimension = dimension;
    if (qualityExtMap != null) result.qualityExtMap.addEntries(qualityExtMap);
    if (expMap != null) result.expMap.addEntries(expMap);
    if (drmTechType != null) result.drmTechType = drmTechType;
    if (limitActionType != null) result.limitActionType = limitActionType;
    if (isDrm != null) result.isDrm = isDrm;
    if (recordInfo != null) result.recordInfo = recordInfo;
    if (vipStatus != null) result.vipStatus = vipStatus;
    if (isLivePre != null) result.isLivePre = isLivePre;
    if (episodeInfo != null) result.episodeInfo = episodeInfo;
    if (episodeAdvertisementInfo != null)
      result.episodeAdvertisementInfo = episodeAdvertisementInfo;
    if (userStatus != null) result.userStatus = userStatus;
    return result;
  }

  PlayViewBusinessInfo._();

  factory PlayViewBusinessInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewBusinessInfo()..mergeFromBuffer(data, registry);
  factory PlayViewBusinessInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewBusinessInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewBusinessInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayViewBusinessInfo.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'isPreview')
    ..aOB(2, _omitFieldNames ? '' : 'bp')
    ..aOS(3, _omitFieldNames ? '' : 'marlinToken')
    ..aOS(4, _omitFieldNames ? '' : 'playbackSpeedColor')
    ..aOM<ContinuePlayInfo>(5, _omitFieldNames ? '' : 'continuePlayInfo',
        subBuilder: ContinuePlayInfo.$_createMessage)
    ..pPM<ClipInfo>(6, _omitFieldNames ? '' : 'clipInfo',
        subBuilder: ClipInfo.$_createMessage)
    ..aE<InlineType>(7, _omitFieldNames ? '' : 'inlineType',
        enumValues: InlineType.values)
    ..aI(8, _omitFieldNames ? '' : 'epWholeDuration')
    ..aOM<Dimension>(9, _omitFieldNames ? '' : 'dimension',
        subBuilder: Dimension.$_createMessage)
    ..m<$core.int, QualityExtInfo>(10, _omitFieldNames ? '' : 'qualityExtMap',
        entryClassName: 'PlayViewBusinessInfo.QualityExtMapEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: QualityExtInfo.$_createMessage,
        valueDefaultOrMaker: QualityExtInfo.getDefault,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..m<$core.String, $core.int>(11, _omitFieldNames ? '' : 'expMap',
        entryClassName: 'PlayViewBusinessInfo.ExpMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O3,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..aE<DrmTechType>(12, _omitFieldNames ? '' : 'drmTechType',
        enumValues: DrmTechType.values)
    ..aI(13, _omitFieldNames ? '' : 'limitActionType')
    ..aOB(14, _omitFieldNames ? '' : 'isDrm')
    ..aOM<RecordInfo>(15, _omitFieldNames ? '' : 'recordInfo',
        subBuilder: RecordInfo.$_createMessage)
    ..aI(16, _omitFieldNames ? '' : 'vipStatus')
    ..aOB(17, _omitFieldNames ? '' : 'isLivePre')
    ..aOM<EpisodeInfo>(18, _omitFieldNames ? '' : 'episodeInfo',
        subBuilder: EpisodeInfo.$_createMessage)
    ..aOM<EpisodeAdvertisementInfo>(
        19, _omitFieldNames ? '' : 'episodeAdvertisementInfo',
        subBuilder: EpisodeAdvertisementInfo.$_createMessage)
    ..aOM<UserStatus>(20, _omitFieldNames ? '' : 'userStatus',
        subBuilder: UserStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewBusinessInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewBusinessInfo copyWith(void Function(PlayViewBusinessInfo) updates) =>
      super.copyWith((message) => updates(message as PlayViewBusinessInfo))
          as PlayViewBusinessInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PlayViewBusinessInfo() / PlayViewBusinessInfo.new instead')
  static PlayViewBusinessInfo create() => PlayViewBusinessInfo._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewBusinessInfo._();
  @$core.override
  PlayViewBusinessInfo createEmptyInstance() => PlayViewBusinessInfo._();
  @$core.pragma('dart2js:noInline')
  static PlayViewBusinessInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayViewBusinessInfo>(
          PlayViewBusinessInfo.$_createMessage);
  static PlayViewBusinessInfo? _defaultInstance;

  /// 当前视频是否是预览
  @$pb.TagNumber(1)
  $core.bool get isPreview => $_getBF(0);
  @$pb.TagNumber(1)
  set isPreview($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsPreview() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsPreview() => $_clearField(1);

  /// 用户是否承包过
  @$pb.TagNumber(2)
  $core.bool get bp => $_getBF(1);
  @$pb.TagNumber(2)
  set bp($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBp() => $_has(1);
  @$pb.TagNumber(2)
  void clearBp() => $_clearField(2);

  /// drm使用
  @$pb.TagNumber(3)
  $core.String get marlinToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set marlinToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarlinToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarlinToken() => $_clearField(3);

  /// 倍速动效色值
  @$pb.TagNumber(4)
  $core.String get playbackSpeedColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set playbackSpeedColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlaybackSpeedColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlaybackSpeedColor() => $_clearField(4);

  @$pb.TagNumber(5)
  ContinuePlayInfo get continuePlayInfo => $_getN(4);
  @$pb.TagNumber(5)
  set continuePlayInfo(ContinuePlayInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasContinuePlayInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearContinuePlayInfo() => $_clearField(5);
  @$pb.TagNumber(5)
  ContinuePlayInfo ensureContinuePlayInfo() => $_ensure(4);

  /// 跳过片头/片尾配置
  @$pb.TagNumber(6)
  $pb.PbList<ClipInfo> get clipInfo => $_getList(5);

  @$pb.TagNumber(7)
  InlineType get inlineType => $_getN(6);
  @$pb.TagNumber(7)
  set inlineType(InlineType value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasInlineType() => $_has(6);
  @$pb.TagNumber(7)
  void clearInlineType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get epWholeDuration => $_getIZ(7);
  @$pb.TagNumber(8)
  set epWholeDuration($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEpWholeDuration() => $_has(7);
  @$pb.TagNumber(8)
  void clearEpWholeDuration() => $_clearField(8);

  /// 当前分辨率信息
  @$pb.TagNumber(9)
  Dimension get dimension => $_getN(8);
  @$pb.TagNumber(9)
  set dimension(Dimension value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasDimension() => $_has(8);
  @$pb.TagNumber(9)
  void clearDimension() => $_clearField(9);
  @$pb.TagNumber(9)
  Dimension ensureDimension() => $_ensure(8);

  @$pb.TagNumber(10)
  $pb.PbMap<$core.int, QualityExtInfo> get qualityExtMap => $_getMap(9);

  @$pb.TagNumber(11)
  $pb.PbMap<$core.String, $core.int> get expMap => $_getMap(10);

  /// DRM技术类型
  @$pb.TagNumber(12)
  DrmTechType get drmTechType => $_getN(11);
  @$pb.TagNumber(12)
  set drmTechType(DrmTechType value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasDrmTechType() => $_has(11);
  @$pb.TagNumber(12)
  void clearDrmTechType() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get limitActionType => $_getIZ(12);
  @$pb.TagNumber(13)
  set limitActionType($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasLimitActionType() => $_has(12);
  @$pb.TagNumber(13)
  void clearLimitActionType() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get isDrm => $_getBF(13);
  @$pb.TagNumber(14)
  set isDrm($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasIsDrm() => $_has(13);
  @$pb.TagNumber(14)
  void clearIsDrm() => $_clearField(14);

  @$pb.TagNumber(15)
  RecordInfo get recordInfo => $_getN(14);
  @$pb.TagNumber(15)
  set recordInfo(RecordInfo value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasRecordInfo() => $_has(14);
  @$pb.TagNumber(15)
  void clearRecordInfo() => $_clearField(15);
  @$pb.TagNumber(15)
  RecordInfo ensureRecordInfo() => $_ensure(14);

  @$pb.TagNumber(16)
  $core.int get vipStatus => $_getIZ(15);
  @$pb.TagNumber(16)
  set vipStatus($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasVipStatus() => $_has(15);
  @$pb.TagNumber(16)
  void clearVipStatus() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get isLivePre => $_getBF(16);
  @$pb.TagNumber(17)
  set isLivePre($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(17)
  $core.bool hasIsLivePre() => $_has(16);
  @$pb.TagNumber(17)
  void clearIsLivePre() => $_clearField(17);

  @$pb.TagNumber(18)
  EpisodeInfo get episodeInfo => $_getN(17);
  @$pb.TagNumber(18)
  set episodeInfo(EpisodeInfo value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasEpisodeInfo() => $_has(17);
  @$pb.TagNumber(18)
  void clearEpisodeInfo() => $_clearField(18);
  @$pb.TagNumber(18)
  EpisodeInfo ensureEpisodeInfo() => $_ensure(17);

  @$pb.TagNumber(19)
  EpisodeAdvertisementInfo get episodeAdvertisementInfo => $_getN(18);
  @$pb.TagNumber(19)
  set episodeAdvertisementInfo(EpisodeAdvertisementInfo value) =>
      $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasEpisodeAdvertisementInfo() => $_has(18);
  @$pb.TagNumber(19)
  void clearEpisodeAdvertisementInfo() => $_clearField(19);
  @$pb.TagNumber(19)
  EpisodeAdvertisementInfo ensureEpisodeAdvertisementInfo() => $_ensure(18);

  @$pb.TagNumber(20)
  UserStatus get userStatus => $_getN(19);
  @$pb.TagNumber(20)
  set userStatus(UserStatus value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasUserStatus() => $_has(19);
  @$pb.TagNumber(20)
  void clearUserStatus() => $_clearField(20);
  @$pb.TagNumber(20)
  UserStatus ensureUserStatus() => $_ensure(19);
}

/// 播放页信息-响应
class PlayViewReply extends $pb.GeneratedMessage {
  factory PlayViewReply({
    VideoInfo? videoInfo,
    PlayAbilityConf? playConf,
    PlayViewBusinessInfo? business,
    Event? event,
    ViewInfo? viewInfo,
    PlayAbilityExtConf? playExtConf,
    PlayExtInfo? playExtInfo,
  }) {
    final result = PlayViewReply._();
    if (videoInfo != null) result.videoInfo = videoInfo;
    if (playConf != null) result.playConf = playConf;
    if (business != null) result.business = business;
    if (event != null) result.event = event;
    if (viewInfo != null) result.viewInfo = viewInfo;
    if (playExtConf != null) result.playExtConf = playExtConf;
    if (playExtInfo != null) result.playExtInfo = playExtInfo;
    return result;
  }

  PlayViewReply._();

  factory PlayViewReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewReply()..mergeFromBuffer(data, registry);
  factory PlayViewReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayViewReply.$_createMessage)
    ..aOM<VideoInfo>(1, _omitFieldNames ? '' : 'videoInfo',
        subBuilder: VideoInfo.$_createMessage)
    ..aOM<PlayAbilityConf>(2, _omitFieldNames ? '' : 'playConf',
        subBuilder: PlayAbilityConf.$_createMessage)
    ..aOM<PlayViewBusinessInfo>(3, _omitFieldNames ? '' : 'business',
        subBuilder: PlayViewBusinessInfo.$_createMessage)
    ..aOM<Event>(4, _omitFieldNames ? '' : 'event',
        subBuilder: Event.$_createMessage)
    ..aOM<ViewInfo>(5, _omitFieldNames ? '' : 'viewInfo',
        subBuilder: ViewInfo.$_createMessage)
    ..aOM<PlayAbilityExtConf>(6, _omitFieldNames ? '' : 'playExtConf',
        subBuilder: PlayAbilityExtConf.$_createMessage)
    ..aOM<PlayExtInfo>(7, _omitFieldNames ? '' : 'playExtInfo',
        subBuilder: PlayExtInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewReply copyWith(void Function(PlayViewReply) updates) =>
      super.copyWith((message) => updates(message as PlayViewReply))
          as PlayViewReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayViewReply() / PlayViewReply.new instead')
  static PlayViewReply create() => PlayViewReply._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewReply._();
  @$core.override
  PlayViewReply createEmptyInstance() => PlayViewReply._();
  @$core.pragma('dart2js:noInline')
  static PlayViewReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayViewReply>(
          PlayViewReply.$_createMessage);
  static PlayViewReply? _defaultInstance;

  /// 视频流信息
  @$pb.TagNumber(1)
  VideoInfo get videoInfo => $_getN(0);
  @$pb.TagNumber(1)
  set videoInfo(VideoInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVideoInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearVideoInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  VideoInfo ensureVideoInfo() => $_ensure(0);

  /// 播放控件用户自定义配置
  @$pb.TagNumber(2)
  PlayAbilityConf get playConf => $_getN(1);
  @$pb.TagNumber(2)
  set playConf(PlayAbilityConf value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPlayConf() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlayConf() => $_clearField(2);
  @$pb.TagNumber(2)
  PlayAbilityConf ensurePlayConf() => $_ensure(1);

  /// 业务需要的其他信息
  @$pb.TagNumber(3)
  PlayViewBusinessInfo get business => $_getN(2);
  @$pb.TagNumber(3)
  set business(PlayViewBusinessInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBusiness() => $_has(2);
  @$pb.TagNumber(3)
  void clearBusiness() => $_clearField(3);
  @$pb.TagNumber(3)
  PlayViewBusinessInfo ensureBusiness() => $_ensure(2);

  /// 事件
  @$pb.TagNumber(4)
  Event get event => $_getN(3);
  @$pb.TagNumber(4)
  set event(Event value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasEvent() => $_has(3);
  @$pb.TagNumber(4)
  void clearEvent() => $_clearField(4);
  @$pb.TagNumber(4)
  Event ensureEvent() => $_ensure(3);

  /// 展示信息
  @$pb.TagNumber(5)
  ViewInfo get viewInfo => $_getN(4);
  @$pb.TagNumber(5)
  set viewInfo(ViewInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasViewInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearViewInfo() => $_clearField(5);
  @$pb.TagNumber(5)
  ViewInfo ensureViewInfo() => $_ensure(4);

  /// 自定义配置扩展信息
  @$pb.TagNumber(6)
  PlayAbilityExtConf get playExtConf => $_getN(5);
  @$pb.TagNumber(6)
  set playExtConf(PlayAbilityExtConf value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlayExtConf() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlayExtConf() => $_clearField(6);
  @$pb.TagNumber(6)
  PlayAbilityExtConf ensurePlayExtConf() => $_ensure(5);

  /// 播放扩展信息
  @$pb.TagNumber(7)
  PlayExtInfo get playExtInfo => $_getN(6);
  @$pb.TagNumber(7)
  set playExtInfo(PlayExtInfo value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPlayExtInfo() => $_has(6);
  @$pb.TagNumber(7)
  void clearPlayExtInfo() => $_clearField(7);
  @$pb.TagNumber(7)
  PlayExtInfo ensurePlayExtInfo() => $_ensure(6);
}

/// 播放页信息-请求
class PlayViewReq extends $pb.GeneratedMessage {
  factory PlayViewReq({
    $fixnum.Int64? epid,
    $fixnum.Int64? cid,
    $fixnum.Int64? qn,
    $core.int? fnver,
    $core.int? fnval,
    $core.int? download,
    $core.int? forceHost,
    $core.bool? fourk,
    $core.String? spmid,
    $core.String? fromSpmid,
    $core.int? teenagersMode,
    CodeType? preferCodecType,
    $core.bool? isPreview,
    $fixnum.Int64? roomId,
    $core.bool? isNeedViewInfo,
    SceneControl? sceneControl,
    InlineScene? inlineScene,
    $fixnum.Int64? materialNo,
    $core.int? securityLevel,
    $fixnum.Int64? seasonId,
    DataControl? dataControl,
  }) {
    final result = PlayViewReq._();
    if (epid != null) result.epid = epid;
    if (cid != null) result.cid = cid;
    if (qn != null) result.qn = qn;
    if (fnver != null) result.fnver = fnver;
    if (fnval != null) result.fnval = fnval;
    if (download != null) result.download = download;
    if (forceHost != null) result.forceHost = forceHost;
    if (fourk != null) result.fourk = fourk;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (teenagersMode != null) result.teenagersMode = teenagersMode;
    if (preferCodecType != null) result.preferCodecType = preferCodecType;
    if (isPreview != null) result.isPreview = isPreview;
    if (roomId != null) result.roomId = roomId;
    if (isNeedViewInfo != null) result.isNeedViewInfo = isNeedViewInfo;
    if (sceneControl != null) result.sceneControl = sceneControl;
    if (inlineScene != null) result.inlineScene = inlineScene;
    if (materialNo != null) result.materialNo = materialNo;
    if (securityLevel != null) result.securityLevel = securityLevel;
    if (seasonId != null) result.seasonId = seasonId;
    if (dataControl != null) result.dataControl = dataControl;
    return result;
  }

  PlayViewReq._();

  factory PlayViewReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewReq()..mergeFromBuffer(data, registry);
  factory PlayViewReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PlayViewReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'epid')
    ..aInt64(2, _omitFieldNames ? '' : 'cid')
    ..aInt64(3, _omitFieldNames ? '' : 'qn')
    ..aI(4, _omitFieldNames ? '' : 'fnver')
    ..aI(5, _omitFieldNames ? '' : 'fnval')
    ..aI(6, _omitFieldNames ? '' : 'download', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'forceHost')
    ..aOB(8, _omitFieldNames ? '' : 'fourk')
    ..aOS(9, _omitFieldNames ? '' : 'spmid')
    ..aOS(10, _omitFieldNames ? '' : 'fromSpmid')
    ..aI(11, _omitFieldNames ? '' : 'teenagersMode')
    ..aE<CodeType>(12, _omitFieldNames ? '' : 'preferCodecType',
        enumValues: CodeType.values)
    ..aOB(13, _omitFieldNames ? '' : 'isPreview')
    ..aInt64(14, _omitFieldNames ? '' : 'roomId')
    ..aOB(15, _omitFieldNames ? '' : 'isNeedViewInfo')
    ..aOM<SceneControl>(16, _omitFieldNames ? '' : 'sceneControl',
        subBuilder: SceneControl.$_createMessage)
    ..aE<InlineScene>(17, _omitFieldNames ? '' : 'inlineScene',
        enumValues: InlineScene.values)
    ..aInt64(18, _omitFieldNames ? '' : 'materialNo')
    ..aI(19, _omitFieldNames ? '' : 'securityLevel')
    ..aInt64(20, _omitFieldNames ? '' : 'seasonId')
    ..aOM<DataControl>(21, _omitFieldNames ? '' : 'dataControl',
        subBuilder: DataControl.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewReq copyWith(void Function(PlayViewReq) updates) =>
      super.copyWith((message) => updates(message as PlayViewReq))
          as PlayViewReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayViewReq() / PlayViewReq.new instead')
  static PlayViewReq create() => PlayViewReq._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewReq._();
  @$core.override
  PlayViewReq createEmptyInstance() => PlayViewReq._();
  @$core.pragma('dart2js:noInline')
  static PlayViewReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayViewReq>(
          PlayViewReq.$_createMessage);
  static PlayViewReq? _defaultInstance;

  /// 剧集epid
  @$pb.TagNumber(1)
  $fixnum.Int64 get epid => $_getI64(0);
  @$pb.TagNumber(1)
  set epid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEpid() => $_has(0);
  @$pb.TagNumber(1)
  void clearEpid() => $_clearField(1);

  /// 视频cid
  @$pb.TagNumber(2)
  $fixnum.Int64 get cid => $_getI64(1);
  @$pb.TagNumber(2)
  set cid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => $_clearField(2);

  /// 清晰度
  @$pb.TagNumber(3)
  $fixnum.Int64 get qn => $_getI64(2);
  @$pb.TagNumber(3)
  set qn($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQn() => $_has(2);
  @$pb.TagNumber(3)
  void clearQn() => $_clearField(3);

  /// 视频流版本
  @$pb.TagNumber(4)
  $core.int get fnver => $_getIZ(3);
  @$pb.TagNumber(4)
  set fnver($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFnver() => $_has(3);
  @$pb.TagNumber(4)
  void clearFnver() => $_clearField(4);

  /// 视频流格式
  @$pb.TagNumber(5)
  $core.int get fnval => $_getIZ(4);
  @$pb.TagNumber(5)
  set fnval($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFnval() => $_has(4);
  @$pb.TagNumber(5)
  void clearFnval() => $_clearField(5);

  /// 下载模式
  /// 0:播放 1:flv下载 2:dash下载
  @$pb.TagNumber(6)
  $core.int get download => $_getIZ(5);
  @$pb.TagNumber(6)
  set download($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDownload() => $_has(5);
  @$pb.TagNumber(6)
  void clearDownload() => $_clearField(6);

  /// 流url强制是用域名
  /// 0:允许使用ip 1:使用http 2:使用https
  @$pb.TagNumber(7)
  $core.int get forceHost => $_getIZ(6);
  @$pb.TagNumber(7)
  set forceHost($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasForceHost() => $_has(6);
  @$pb.TagNumber(7)
  void clearForceHost() => $_clearField(7);

  /// 是否4K
  @$pb.TagNumber(8)
  $core.bool get fourk => $_getBF(7);
  @$pb.TagNumber(8)
  set fourk($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFourk() => $_has(7);
  @$pb.TagNumber(8)
  void clearFourk() => $_clearField(8);

  /// 当前页spm
  @$pb.TagNumber(9)
  $core.String get spmid => $_getSZ(8);
  @$pb.TagNumber(9)
  set spmid($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSpmid() => $_has(8);
  @$pb.TagNumber(9)
  void clearSpmid() => $_clearField(9);

  /// 上一页spm
  @$pb.TagNumber(10)
  $core.String get fromSpmid => $_getSZ(9);
  @$pb.TagNumber(10)
  set fromSpmid($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasFromSpmid() => $_has(9);
  @$pb.TagNumber(10)
  void clearFromSpmid() => $_clearField(10);

  /// 青少年模式
  @$pb.TagNumber(11)
  $core.int get teenagersMode => $_getIZ(10);
  @$pb.TagNumber(11)
  set teenagersMode($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTeenagersMode() => $_has(10);
  @$pb.TagNumber(11)
  void clearTeenagersMode() => $_clearField(11);

  /// 视频编码
  @$pb.TagNumber(12)
  CodeType get preferCodecType => $_getN(11);
  @$pb.TagNumber(12)
  set preferCodecType(CodeType value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasPreferCodecType() => $_has(11);
  @$pb.TagNumber(12)
  void clearPreferCodecType() => $_clearField(12);

  /// 是否强制请求预览视频
  @$pb.TagNumber(13)
  $core.bool get isPreview => $_getBF(12);
  @$pb.TagNumber(13)
  set isPreview($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasIsPreview() => $_has(12);
  @$pb.TagNumber(13)
  void clearIsPreview() => $_clearField(13);

  /// 一起看房间id
  @$pb.TagNumber(14)
  $fixnum.Int64 get roomId => $_getI64(13);
  @$pb.TagNumber(14)
  set roomId($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRoomId() => $_has(13);
  @$pb.TagNumber(14)
  void clearRoomId() => $_clearField(14);

  /// 是否需要展示信息
  @$pb.TagNumber(15)
  $core.bool get isNeedViewInfo => $_getBF(14);
  @$pb.TagNumber(15)
  set isNeedViewInfo($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasIsNeedViewInfo() => $_has(14);
  @$pb.TagNumber(15)
  void clearIsNeedViewInfo() => $_clearField(15);

  /// 场景控制
  @$pb.TagNumber(16)
  SceneControl get sceneControl => $_getN(15);
  @$pb.TagNumber(16)
  set sceneControl(SceneControl value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasSceneControl() => $_has(15);
  @$pb.TagNumber(16)
  void clearSceneControl() => $_clearField(16);
  @$pb.TagNumber(16)
  SceneControl ensureSceneControl() => $_ensure(15);

  @$pb.TagNumber(17)
  InlineScene get inlineScene => $_getN(16);
  @$pb.TagNumber(17)
  set inlineScene(InlineScene value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasInlineScene() => $_has(16);
  @$pb.TagNumber(17)
  void clearInlineScene() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get materialNo => $_getI64(17);
  @$pb.TagNumber(18)
  set materialNo($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasMaterialNo() => $_has(17);
  @$pb.TagNumber(18)
  void clearMaterialNo() => $_clearField(18);

  /// DRM 安全等级
  @$pb.TagNumber(19)
  $core.int get securityLevel => $_getIZ(18);
  @$pb.TagNumber(19)
  set securityLevel($core.int value) => $_setSignedInt32(18, value);
  @$pb.TagNumber(19)
  $core.bool hasSecurityLevel() => $_has(18);
  @$pb.TagNumber(19)
  void clearSecurityLevel() => $_clearField(19);

  @$pb.TagNumber(20)
  $fixnum.Int64 get seasonId => $_getI64(19);
  @$pb.TagNumber(20)
  set seasonId($fixnum.Int64 value) => $_setInt64(19, value);
  @$pb.TagNumber(20)
  $core.bool hasSeasonId() => $_has(19);
  @$pb.TagNumber(20)
  void clearSeasonId() => $_clearField(20);

  @$pb.TagNumber(21)
  DataControl get dataControl => $_getN(20);
  @$pb.TagNumber(21)
  set dataControl(DataControl value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasDataControl() => $_has(20);
  @$pb.TagNumber(21)
  void clearDataControl() => $_clearField(21);
  @$pb.TagNumber(21)
  DataControl ensureDataControl() => $_ensure(20);
}

/// 弹窗信息
class PopWin extends $pb.GeneratedMessage {
  factory PopWin({
    $core.String? title,
    $core.Iterable<Coupon>? coupon,
    $core.Iterable<ButtonInfo>? button,
    $core.String? bottomText,
    TextInfo? popTitle,
    TextInfo? subtitle,
    ButtonInfo? bottomDesc,
    $core.String? cover,
    $core.String? popType,
  }) {
    final result = PopWin._();
    if (title != null) result.title = title;
    if (coupon != null) result.coupon.addAll(coupon);
    if (button != null) result.button.addAll(button);
    if (bottomText != null) result.bottomText = bottomText;
    if (popTitle != null) result.popTitle = popTitle;
    if (subtitle != null) result.subtitle = subtitle;
    if (bottomDesc != null) result.bottomDesc = bottomDesc;
    if (cover != null) result.cover = cover;
    if (popType != null) result.popType = popType;
    return result;
  }

  PopWin._();

  factory PopWin.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PopWin()..mergeFromBuffer(data, registry);
  factory PopWin.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PopWin()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PopWin',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PopWin.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..pPM<Coupon>(2, _omitFieldNames ? '' : 'coupon',
        subBuilder: Coupon.$_createMessage)
    ..pPM<ButtonInfo>(3, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonInfo.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'bottomText')
    ..aOM<TextInfo>(5, _omitFieldNames ? '' : 'popTitle',
        subBuilder: TextInfo.$_createMessage)
    ..aOM<TextInfo>(6, _omitFieldNames ? '' : 'subtitle',
        subBuilder: TextInfo.$_createMessage)
    ..aOM<ButtonInfo>(7, _omitFieldNames ? '' : 'bottomDesc',
        subBuilder: ButtonInfo.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'cover')
    ..aOS(9, _omitFieldNames ? '' : 'popType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PopWin clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PopWin copyWith(void Function(PopWin) updates) =>
      super.copyWith((message) => updates(message as PopWin)) as PopWin;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PopWin() / PopWin.new instead')
  static PopWin create() => PopWin._();
  static $pb.GeneratedMessage $_createMessage() => PopWin._();
  @$core.override
  PopWin createEmptyInstance() => PopWin._();
  @$core.pragma('dart2js:noInline')
  static PopWin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PopWin>(PopWin.$_createMessage);
  static PopWin? _defaultInstance;

  /// 弹窗标题 老字段
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 优惠券列表
  @$pb.TagNumber(2)
  $pb.PbList<Coupon> get coupon => $_getList(1);

  /// 弹窗按钮列表
  @$pb.TagNumber(3)
  $pb.PbList<ButtonInfo> get button => $_getList(2);

  /// 底部文案 老字段
  @$pb.TagNumber(4)
  $core.String get bottomText => $_getSZ(3);
  @$pb.TagNumber(4)
  set bottomText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBottomText() => $_has(3);
  @$pb.TagNumber(4)
  void clearBottomText() => $_clearField(4);

  /// 弹窗标题 新字段
  @$pb.TagNumber(5)
  TextInfo get popTitle => $_getN(4);
  @$pb.TagNumber(5)
  set popTitle(TextInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPopTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearPopTitle() => $_clearField(5);
  @$pb.TagNumber(5)
  TextInfo ensurePopTitle() => $_ensure(4);

  /// 弹窗副标题
  @$pb.TagNumber(6)
  TextInfo get subtitle => $_getN(5);
  @$pb.TagNumber(6)
  set subtitle(TextInfo value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSubtitle() => $_has(5);
  @$pb.TagNumber(6)
  void clearSubtitle() => $_clearField(6);
  @$pb.TagNumber(6)
  TextInfo ensureSubtitle() => $_ensure(5);

  /// 底部描述 新字段
  @$pb.TagNumber(7)
  ButtonInfo get bottomDesc => $_getN(6);
  @$pb.TagNumber(7)
  set bottomDesc(ButtonInfo value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasBottomDesc() => $_has(6);
  @$pb.TagNumber(7)
  void clearBottomDesc() => $_clearField(7);
  @$pb.TagNumber(7)
  ButtonInfo ensureBottomDesc() => $_ensure(6);

  /// 弹窗小图
  @$pb.TagNumber(8)
  $core.String get cover => $_getSZ(7);
  @$pb.TagNumber(8)
  set cover($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCover() => $_has(7);
  @$pb.TagNumber(8)
  void clearCover() => $_clearField(8);

  /// 弹窗类型
  @$pb.TagNumber(9)
  $core.String get popType => $_getSZ(8);
  @$pb.TagNumber(9)
  set popType($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPopType() => $_has(8);
  @$pb.TagNumber(9)
  void clearPopType() => $_clearField(9);
}

/// 广告组件: 竖屏时视频下部提示栏
class PromptBar extends $pb.GeneratedMessage {
  factory PromptBar({
    TextInfo? title,
    TextInfo? subTitle,
    $core.String? subTitleIcon,
    $core.String? bgImage,
    GradientColor? bgGradientColor,
    $core.Iterable<ButtonInfo>? button,
    Report? report,
    $core.String? fullScreenIpIcon,
    GradientColor? fullScreenBgGradientColor,
  }) {
    final result = PromptBar._();
    if (title != null) result.title = title;
    if (subTitle != null) result.subTitle = subTitle;
    if (subTitleIcon != null) result.subTitleIcon = subTitleIcon;
    if (bgImage != null) result.bgImage = bgImage;
    if (bgGradientColor != null) result.bgGradientColor = bgGradientColor;
    if (button != null) result.button.addAll(button);
    if (report != null) result.report = report;
    if (fullScreenIpIcon != null) result.fullScreenIpIcon = fullScreenIpIcon;
    if (fullScreenBgGradientColor != null)
      result.fullScreenBgGradientColor = fullScreenBgGradientColor;
    return result;
  }

  PromptBar._();

  factory PromptBar.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PromptBar()..mergeFromBuffer(data, registry);
  factory PromptBar.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PromptBar()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PromptBar',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: PromptBar.$_createMessage)
    ..aOM<TextInfo>(1, _omitFieldNames ? '' : 'title',
        subBuilder: TextInfo.$_createMessage)
    ..aOM<TextInfo>(2, _omitFieldNames ? '' : 'subTitle',
        subBuilder: TextInfo.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'subTitleIcon')
    ..aOS(4, _omitFieldNames ? '' : 'bgImage')
    ..aOM<GradientColor>(5, _omitFieldNames ? '' : 'bgGradientColor',
        subBuilder: GradientColor.$_createMessage)
    ..pPM<ButtonInfo>(6, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonInfo.$_createMessage)
    ..aOM<Report>(7, _omitFieldNames ? '' : 'report',
        subBuilder: Report.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'fullScreenIpIcon')
    ..aOM<GradientColor>(9, _omitFieldNames ? '' : 'fullScreenBgGradientColor',
        subBuilder: GradientColor.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PromptBar clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PromptBar copyWith(void Function(PromptBar) updates) =>
      super.copyWith((message) => updates(message as PromptBar)) as PromptBar;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PromptBar() / PromptBar.new instead')
  static PromptBar create() => PromptBar._();
  static $pb.GeneratedMessage $_createMessage() => PromptBar._();
  @$core.override
  PromptBar createEmptyInstance() => PromptBar._();
  @$core.pragma('dart2js:noInline')
  static PromptBar getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PromptBar>(PromptBar.$_createMessage);
  static PromptBar? _defaultInstance;

  /// 主标题, 如: "本片含大会员专享内容"
  @$pb.TagNumber(1)
  TextInfo get title => $_getN(0);
  @$pb.TagNumber(1)
  set title(TextInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);
  @$pb.TagNumber(1)
  TextInfo ensureTitle() => $_ensure(0);

  /// 副标题, 如: "成为大会员可免费看全部剧集"
  @$pb.TagNumber(2)
  TextInfo get subTitle => $_getN(1);
  @$pb.TagNumber(2)
  set subTitle(TextInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSubTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubTitle() => $_clearField(2);
  @$pb.TagNumber(2)
  TextInfo ensureSubTitle() => $_ensure(1);

  /// 副标题前面的icon
  @$pb.TagNumber(3)
  $core.String get subTitleIcon => $_getSZ(2);
  @$pb.TagNumber(3)
  set subTitleIcon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubTitleIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubTitleIcon() => $_clearField(3);

  /// 背景图
  @$pb.TagNumber(4)
  $core.String get bgImage => $_getSZ(3);
  @$pb.TagNumber(4)
  set bgImage($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBgImage() => $_has(3);
  @$pb.TagNumber(4)
  void clearBgImage() => $_clearField(4);

  /// 背景渐变色
  @$pb.TagNumber(5)
  GradientColor get bgGradientColor => $_getN(4);
  @$pb.TagNumber(5)
  set bgGradientColor(GradientColor value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBgGradientColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearBgGradientColor() => $_clearField(5);
  @$pb.TagNumber(5)
  GradientColor ensureBgGradientColor() => $_ensure(4);

  /// 按钮
  @$pb.TagNumber(6)
  $pb.PbList<ButtonInfo> get button => $_getList(5);

  /// 埋点上报信息
  @$pb.TagNumber(7)
  Report get report => $_getN(6);
  @$pb.TagNumber(7)
  set report(Report value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReport() => $_has(6);
  @$pb.TagNumber(7)
  void clearReport() => $_clearField(7);
  @$pb.TagNumber(7)
  Report ensureReport() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get fullScreenIpIcon => $_getSZ(7);
  @$pb.TagNumber(8)
  set fullScreenIpIcon($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFullScreenIpIcon() => $_has(7);
  @$pb.TagNumber(8)
  void clearFullScreenIpIcon() => $_clearField(8);

  @$pb.TagNumber(9)
  GradientColor get fullScreenBgGradientColor => $_getN(8);
  @$pb.TagNumber(9)
  set fullScreenBgGradientColor(GradientColor value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasFullScreenBgGradientColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearFullScreenBgGradientColor() => $_clearField(9);
  @$pb.TagNumber(9)
  GradientColor ensureFullScreenBgGradientColor() => $_ensure(8);
}

/// 云控拓展视频画质信息
class QualityExtInfo extends $pb.GeneratedMessage {
  factory QualityExtInfo({
    $core.bool? trialSupport,
  }) {
    final result = QualityExtInfo._();
    if (trialSupport != null) result.trialSupport = trialSupport;
    return result;
  }

  QualityExtInfo._();

  factory QualityExtInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QualityExtInfo()..mergeFromBuffer(data, registry);
  factory QualityExtInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QualityExtInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QualityExtInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: QualityExtInfo.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'trialSupport')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QualityExtInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QualityExtInfo copyWith(void Function(QualityExtInfo) updates) =>
      super.copyWith((message) => updates(message as QualityExtInfo))
          as QualityExtInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use QualityExtInfo() / QualityExtInfo.new instead')
  static QualityExtInfo create() => QualityExtInfo._();
  static $pb.GeneratedMessage $_createMessage() => QualityExtInfo._();
  @$core.override
  QualityExtInfo createEmptyInstance() => QualityExtInfo._();
  @$core.pragma('dart2js:noInline')
  static QualityExtInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QualityExtInfo>(
          QualityExtInfo.$_createMessage);
  static QualityExtInfo? _defaultInstance;

  /// 是否支持试看
  @$pb.TagNumber(1)
  $core.bool get trialSupport => $_getBF(0);
  @$pb.TagNumber(1)
  set trialSupport($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrialSupport() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrialSupport() => $_clearField(1);
}

/// 备案信息
class RecordInfo extends $pb.GeneratedMessage {
  factory RecordInfo({
    $core.String? record,
    $core.String? recordIcon,
  }) {
    final result = RecordInfo._();
    if (record != null) result.record = record;
    if (recordIcon != null) result.recordIcon = recordIcon;
    return result;
  }

  RecordInfo._();

  factory RecordInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RecordInfo()..mergeFromBuffer(data, registry);
  factory RecordInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RecordInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: RecordInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'record')
    ..aOS(2, _omitFieldNames ? '' : 'recordIcon')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordInfo copyWith(void Function(RecordInfo) updates) =>
      super.copyWith((message) => updates(message as RecordInfo)) as RecordInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RecordInfo() / RecordInfo.new instead')
  static RecordInfo create() => RecordInfo._();
  static $pb.GeneratedMessage $_createMessage() => RecordInfo._();
  @$core.override
  RecordInfo createEmptyInstance() => RecordInfo._();
  @$core.pragma('dart2js:noInline')
  static RecordInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordInfo>(RecordInfo.$_createMessage);
  static RecordInfo? _defaultInstance;

  /// 记录
  @$pb.TagNumber(1)
  $core.String get record => $_getSZ(0);
  @$pb.TagNumber(1)
  set record($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRecord() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecord() => $_clearField(1);

  /// 记录图标
  @$pb.TagNumber(2)
  $core.String get recordIcon => $_getSZ(1);
  @$pb.TagNumber(2)
  set recordIcon($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRecordIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearRecordIcon() => $_clearField(2);
}

/// 埋点上报信息
class Report extends $pb.GeneratedMessage {
  factory Report({
    $core.String? showEventId,
    $core.String? clickEventId,
    $core.String? extends_3,
  }) {
    final result = Report._();
    if (showEventId != null) result.showEventId = showEventId;
    if (clickEventId != null) result.clickEventId = clickEventId;
    if (extends_3 != null) result.extends_3 = extends_3;
    return result;
  }

  Report._();

  factory Report.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Report()..mergeFromBuffer(data, registry);
  factory Report.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Report()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Report',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Report.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'showEventId')
    ..aOS(2, _omitFieldNames ? '' : 'clickEventId')
    ..aOS(3, _omitFieldNames ? '' : 'extends')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Report clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Report copyWith(void Function(Report) updates) =>
      super.copyWith((message) => updates(message as Report)) as Report;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Report() / Report.new instead')
  static Report create() => Report._();
  static $pb.GeneratedMessage $_createMessage() => Report._();
  @$core.override
  Report createEmptyInstance() => Report._();
  @$core.pragma('dart2js:noInline')
  static Report getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Report>(Report.$_createMessage);
  static Report? _defaultInstance;

  /// 曝光事件
  @$pb.TagNumber(1)
  $core.String get showEventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set showEventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShowEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearShowEventId() => $_clearField(1);

  /// 点击事件
  @$pb.TagNumber(2)
  $core.String get clickEventId => $_getSZ(1);
  @$pb.TagNumber(2)
  set clickEventId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClickEventId() => $_has(1);
  @$pb.TagNumber(2)
  void clearClickEventId() => $_clearField(2);

  /// 埋点透传参数
  @$pb.TagNumber(3)
  $core.String get extends_3 => $_getSZ(2);
  @$pb.TagNumber(3)
  set extends_3($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExtends_3() => $_has(2);
  @$pb.TagNumber(3)
  void clearExtends_3() => $_clearField(3);
}

/// 分段流条目
class ResponseUrl extends $pb.GeneratedMessage {
  factory ResponseUrl({
    $core.int? order,
    $fixnum.Int64? length,
    $fixnum.Int64? size,
    $core.String? url,
    $core.Iterable<$core.String>? backupUrl,
    $core.String? md5,
  }) {
    final result = ResponseUrl._();
    if (order != null) result.order = order;
    if (length != null) result.length = length;
    if (size != null) result.size = size;
    if (url != null) result.url = url;
    if (backupUrl != null) result.backupUrl.addAll(backupUrl);
    if (md5 != null) result.md5 = md5;
    return result;
  }

  ResponseUrl._();

  factory ResponseUrl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResponseUrl()..mergeFromBuffer(data, registry);
  factory ResponseUrl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResponseUrl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResponseUrl',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: ResponseUrl.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'order', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'length', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'url')
    ..pPS(5, _omitFieldNames ? '' : 'backupUrl')
    ..aOS(6, _omitFieldNames ? '' : 'md5')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResponseUrl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResponseUrl copyWith(void Function(ResponseUrl) updates) =>
      super.copyWith((message) => updates(message as ResponseUrl))
          as ResponseUrl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ResponseUrl() / ResponseUrl.new instead')
  static ResponseUrl create() => ResponseUrl._();
  static $pb.GeneratedMessage $_createMessage() => ResponseUrl._();
  @$core.override
  ResponseUrl createEmptyInstance() => ResponseUrl._();
  @$core.pragma('dart2js:noInline')
  static ResponseUrl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResponseUrl>(
          ResponseUrl.$_createMessage);
  static ResponseUrl? _defaultInstance;

  /// 分段序号
  @$pb.TagNumber(1)
  $core.int get order => $_getIZ(0);
  @$pb.TagNumber(1)
  set order($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrder() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrder() => $_clearField(1);

  /// 分段时长
  @$pb.TagNumber(2)
  $fixnum.Int64 get length => $_getI64(1);
  @$pb.TagNumber(2)
  set length($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => $_clearField(2);

  /// 分段大小
  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);

  /// 主线流
  @$pb.TagNumber(4)
  $core.String get url => $_getSZ(3);
  @$pb.TagNumber(4)
  set url($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearUrl() => $_clearField(4);

  /// 备用流
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get backupUrl => $_getList(4);

  /// md5
  @$pb.TagNumber(6)
  $core.String get md5 => $_getSZ(5);
  @$pb.TagNumber(6)
  set md5($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMd5() => $_has(5);
  @$pb.TagNumber(6)
  void clearMd5() => $_clearField(6);
}

/// 权限信息
class Rights extends $pb.GeneratedMessage {
  factory Rights({
    $core.int? canWatch,
  }) {
    final result = Rights._();
    if (canWatch != null) result.canWatch = canWatch;
    return result;
  }

  Rights._();

  factory Rights.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Rights()..mergeFromBuffer(data, registry);
  factory Rights.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Rights()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Rights',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Rights.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'canWatch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rights clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rights copyWith(void Function(Rights) updates) =>
      super.copyWith((message) => updates(message as Rights)) as Rights;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Rights() / Rights.new instead')
  static Rights create() => Rights._();
  static $pb.GeneratedMessage $_createMessage() => Rights._();
  @$core.override
  Rights createEmptyInstance() => Rights._();
  @$core.pragma('dart2js:noInline')
  static Rights getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Rights>(Rights.$_createMessage);
  static Rights? _defaultInstance;

  /// 是否可以观看
  @$pb.TagNumber(1)
  $core.int get canWatch => $_getIZ(0);
  @$pb.TagNumber(1)
  set canWatch($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCanWatch() => $_has(0);
  @$pb.TagNumber(1)
  void clearCanWatch() => $_clearField(1);
}

/// 角色配音信息
class RoleAudioProto extends $pb.GeneratedMessage {
  factory RoleAudioProto({
    $fixnum.Int64? roleId,
    $core.String? roleName,
    $core.String? roleAvatar,
    $core.Iterable<AudioMaterialProto>? audioMaterialList,
  }) {
    final result = RoleAudioProto._();
    if (roleId != null) result.roleId = roleId;
    if (roleName != null) result.roleName = roleName;
    if (roleAvatar != null) result.roleAvatar = roleAvatar;
    if (audioMaterialList != null)
      result.audioMaterialList.addAll(audioMaterialList);
    return result;
  }

  RoleAudioProto._();

  factory RoleAudioProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RoleAudioProto()..mergeFromBuffer(data, registry);
  factory RoleAudioProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RoleAudioProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoleAudioProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: RoleAudioProto.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'roleId')
    ..aOS(2, _omitFieldNames ? '' : 'roleName')
    ..aOS(3, _omitFieldNames ? '' : 'roleAvatar')
    ..pPM<AudioMaterialProto>(4, _omitFieldNames ? '' : 'audioMaterialList',
        subBuilder: AudioMaterialProto.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleAudioProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleAudioProto copyWith(void Function(RoleAudioProto) updates) =>
      super.copyWith((message) => updates(message as RoleAudioProto))
          as RoleAudioProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RoleAudioProto() / RoleAudioProto.new instead')
  static RoleAudioProto create() => RoleAudioProto._();
  static $pb.GeneratedMessage $_createMessage() => RoleAudioProto._();
  @$core.override
  RoleAudioProto createEmptyInstance() => RoleAudioProto._();
  @$core.pragma('dart2js:noInline')
  static RoleAudioProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoleAudioProto>(
          RoleAudioProto.$_createMessage);
  static RoleAudioProto? _defaultInstance;

  /// 角色ID
  @$pb.TagNumber(1)
  $fixnum.Int64 get roleId => $_getI64(0);
  @$pb.TagNumber(1)
  set roleId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoleId() => $_clearField(1);

  /// 角色名称
  @$pb.TagNumber(2)
  $core.String get roleName => $_getSZ(1);
  @$pb.TagNumber(2)
  set roleName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoleName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoleName() => $_clearField(2);

  /// 角色头像
  @$pb.TagNumber(3)
  $core.String get roleAvatar => $_getSZ(2);
  @$pb.TagNumber(3)
  set roleAvatar($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoleAvatar() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoleAvatar() => $_clearField(3);

  /// 音频素材列表
  @$pb.TagNumber(4)
  $pb.PbList<AudioMaterialProto> get audioMaterialList => $_getList(3);
}

/// 场景控制
class SceneControl extends $pb.GeneratedMessage {
  factory SceneControl({
    $core.bool? favPlaylist,
    $core.bool? smallWindow,
    $core.bool? pip,
    $core.bool? wasHeInline,
    $core.bool? isNeedTrial,
  }) {
    final result = SceneControl._();
    if (favPlaylist != null) result.favPlaylist = favPlaylist;
    if (smallWindow != null) result.smallWindow = smallWindow;
    if (pip != null) result.pip = pip;
    if (wasHeInline != null) result.wasHeInline = wasHeInline;
    if (isNeedTrial != null) result.isNeedTrial = isNeedTrial;
    return result;
  }

  SceneControl._();

  factory SceneControl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SceneControl()..mergeFromBuffer(data, registry);
  factory SceneControl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SceneControl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SceneControl',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: SceneControl.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'favPlaylist')
    ..aOB(2, _omitFieldNames ? '' : 'smallWindow')
    ..aOB(3, _omitFieldNames ? '' : 'pip')
    ..aOB(4, _omitFieldNames ? '' : 'wasHeInline')
    ..aOB(5, _omitFieldNames ? '' : 'isNeedTrial')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SceneControl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SceneControl copyWith(void Function(SceneControl) updates) =>
      super.copyWith((message) => updates(message as SceneControl))
          as SceneControl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SceneControl() / SceneControl.new instead')
  static SceneControl create() => SceneControl._();
  static $pb.GeneratedMessage $_createMessage() => SceneControl._();
  @$core.override
  SceneControl createEmptyInstance() => SceneControl._();
  @$core.pragma('dart2js:noInline')
  static SceneControl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SceneControl>(
          SceneControl.$_createMessage);
  static SceneControl? _defaultInstance;

  /// 是否收藏播单
  @$pb.TagNumber(1)
  $core.bool get favPlaylist => $_getBF(0);
  @$pb.TagNumber(1)
  set favPlaylist($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFavPlaylist() => $_has(0);
  @$pb.TagNumber(1)
  void clearFavPlaylist() => $_clearField(1);

  /// 是否小窗
  @$pb.TagNumber(2)
  $core.bool get smallWindow => $_getBF(1);
  @$pb.TagNumber(2)
  set smallWindow($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSmallWindow() => $_has(1);
  @$pb.TagNumber(2)
  void clearSmallWindow() => $_clearField(2);

  /// 是否画中画
  @$pb.TagNumber(3)
  $core.bool get pip => $_getBF(2);
  @$pb.TagNumber(3)
  set pip($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPip() => $_has(2);
  @$pb.TagNumber(3)
  void clearPip() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get wasHeInline => $_getBF(3);
  @$pb.TagNumber(4)
  set wasHeInline($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWasHeInline() => $_has(3);
  @$pb.TagNumber(4)
  void clearWasHeInline() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isNeedTrial => $_getBF(4);
  @$pb.TagNumber(5)
  set isNeedTrial($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsNeedTrial() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsNeedTrial() => $_clearField(5);
}

/// 方案
class Scheme extends $pb.GeneratedMessage {
  factory Scheme({
    Scheme_ActionType? actionType,
    $core.String? toast,
  }) {
    final result = Scheme._();
    if (actionType != null) result.actionType = actionType;
    if (toast != null) result.toast = toast;
    return result;
  }

  Scheme._();

  factory Scheme.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Scheme()..mergeFromBuffer(data, registry);
  factory Scheme.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Scheme()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Scheme',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Scheme.$_createMessage)
    ..aE<Scheme_ActionType>(1, _omitFieldNames ? '' : 'actionType',
        enumValues: Scheme_ActionType.values)
    ..aOS(2, _omitFieldNames ? '' : 'toast')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Scheme clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Scheme copyWith(void Function(Scheme) updates) =>
      super.copyWith((message) => updates(message as Scheme)) as Scheme;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Scheme() / Scheme.new instead')
  static Scheme create() => Scheme._();
  static $pb.GeneratedMessage $_createMessage() => Scheme._();
  @$core.override
  Scheme createEmptyInstance() => Scheme._();
  @$core.pragma('dart2js:noInline')
  static Scheme getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Scheme>(Scheme.$_createMessage);
  static Scheme? _defaultInstance;

  @$pb.TagNumber(1)
  Scheme_ActionType get actionType => $_getN(0);
  @$pb.TagNumber(1)
  set actionType(Scheme_ActionType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasActionType() => $_has(0);
  @$pb.TagNumber(1)
  void clearActionType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get toast => $_getSZ(1);
  @$pb.TagNumber(2)
  set toast($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToast() => $_has(1);
  @$pb.TagNumber(2)
  void clearToast() => $_clearField(2);
}

/// PGC SEASON 信息
class SeasonInfo extends $pb.GeneratedMessage {
  factory SeasonInfo({
    $core.int? seasonId,
    $core.int? seasonType,
    $core.int? seasonStatus,
    $core.String? cover,
    $core.String? title,
    Rights? rights,
    $core.int? mode,
  }) {
    final result = SeasonInfo._();
    if (seasonId != null) result.seasonId = seasonId;
    if (seasonType != null) result.seasonType = seasonType;
    if (seasonStatus != null) result.seasonStatus = seasonStatus;
    if (cover != null) result.cover = cover;
    if (title != null) result.title = title;
    if (rights != null) result.rights = rights;
    if (mode != null) result.mode = mode;
    return result;
  }

  SeasonInfo._();

  factory SeasonInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonInfo()..mergeFromBuffer(data, registry);
  factory SeasonInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: SeasonInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'seasonId')
    ..aI(2, _omitFieldNames ? '' : 'seasonType')
    ..aI(3, _omitFieldNames ? '' : 'seasonStatus')
    ..aOS(4, _omitFieldNames ? '' : 'cover')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aOM<Rights>(6, _omitFieldNames ? '' : 'rights',
        subBuilder: Rights.$_createMessage)
    ..aI(7, _omitFieldNames ? '' : 'mode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonInfo copyWith(void Function(SeasonInfo) updates) =>
      super.copyWith((message) => updates(message as SeasonInfo)) as SeasonInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeasonInfo() / SeasonInfo.new instead')
  static SeasonInfo create() => SeasonInfo._();
  static $pb.GeneratedMessage $_createMessage() => SeasonInfo._();
  @$core.override
  SeasonInfo createEmptyInstance() => SeasonInfo._();
  @$core.pragma('dart2js:noInline')
  static SeasonInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonInfo>(SeasonInfo.$_createMessage);
  static SeasonInfo? _defaultInstance;

  /// PGC SEASON ID
  @$pb.TagNumber(1)
  $core.int get seasonId => $_getIZ(0);
  @$pb.TagNumber(1)
  set seasonId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);

  /// PGC SEASON 类型
  @$pb.TagNumber(2)
  $core.int get seasonType => $_getIZ(1);
  @$pb.TagNumber(2)
  set seasonType($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeasonType() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeasonType() => $_clearField(2);

  /// PGC SEASON 状态
  @$pb.TagNumber(3)
  $core.int get seasonStatus => $_getIZ(2);
  @$pb.TagNumber(3)
  set seasonStatus($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSeasonStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeasonStatus() => $_clearField(3);

  /// 封面
  @$pb.TagNumber(4)
  $core.String get cover => $_getSZ(3);
  @$pb.TagNumber(4)
  set cover($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCover() => $_has(3);
  @$pb.TagNumber(4)
  void clearCover() => $_clearField(4);

  /// 标题
  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  /// 权限信息
  @$pb.TagNumber(6)
  Rights get rights => $_getN(5);
  @$pb.TagNumber(6)
  set rights(Rights value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRights() => $_has(5);
  @$pb.TagNumber(6)
  void clearRights() => $_clearField(6);
  @$pb.TagNumber(6)
  Rights ensureRights() => $_ensure(5);

  /// 模式
  @$pb.TagNumber(7)
  $core.int get mode => $_getIZ(6);
  @$pb.TagNumber(7)
  set mode($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearMode() => $_clearField(7);
}

/// 分段视频流
class SegmentVideo extends $pb.GeneratedMessage {
  factory SegmentVideo({
    $core.Iterable<ResponseUrl>? segment,
  }) {
    final result = SegmentVideo._();
    if (segment != null) result.segment.addAll(segment);
    return result;
  }

  SegmentVideo._();

  factory SegmentVideo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SegmentVideo()..mergeFromBuffer(data, registry);
  factory SegmentVideo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SegmentVideo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SegmentVideo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: SegmentVideo.$_createMessage)
    ..pPM<ResponseUrl>(1, _omitFieldNames ? '' : 'segment',
        subBuilder: ResponseUrl.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SegmentVideo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SegmentVideo copyWith(void Function(SegmentVideo) updates) =>
      super.copyWith((message) => updates(message as SegmentVideo))
          as SegmentVideo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SegmentVideo() / SegmentVideo.new instead')
  static SegmentVideo create() => SegmentVideo._();
  static $pb.GeneratedMessage $_createMessage() => SegmentVideo._();
  @$core.override
  SegmentVideo createEmptyInstance() => SegmentVideo._();
  @$core.pragma('dart2js:noInline')
  static SegmentVideo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SegmentVideo>(
          SegmentVideo.$_createMessage);
  static SegmentVideo? _defaultInstance;

  /// 分段视频流列表
  @$pb.TagNumber(1)
  $pb.PbList<ResponseUrl> get segment => $_getList(0);
}

/// 震动
class Shake extends $pb.GeneratedMessage {
  factory Shake({
    $core.String? file,
  }) {
    final result = Shake._();
    if (file != null) result.file = file;
    return result;
  }

  Shake._();

  factory Shake.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Shake()..mergeFromBuffer(data, registry);
  factory Shake.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Shake()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Shake',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Shake.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'file')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Shake clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Shake copyWith(void Function(Shake) updates) =>
      super.copyWith((message) => updates(message as Shake)) as Shake;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Shake() / Shake.new instead')
  static Shake create() => Shake._();
  static $pb.GeneratedMessage $_createMessage() => Shake._();
  @$core.override
  Shake createEmptyInstance() => Shake._();
  @$core.pragma('dart2js:noInline')
  static Shake getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Shake>(Shake.$_createMessage);
  static Shake? _defaultInstance;

  /// 文件地址
  @$pb.TagNumber(1)
  $core.String get file => $_getSZ(0);
  @$pb.TagNumber(1)
  set file($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
}

enum Stream_Content { dashVideo, segmentVideo, notSet }

/// 视频流信息
class Stream extends $pb.GeneratedMessage {
  factory Stream({
    StreamInfo? info,
    DashVideo? dashVideo,
    SegmentVideo? segmentVideo,
  }) {
    final result = Stream._();
    if (info != null) result.info = info;
    if (dashVideo != null) result.dashVideo = dashVideo;
    if (segmentVideo != null) result.segmentVideo = segmentVideo;
    return result;
  }

  Stream._();

  factory Stream.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Stream()..mergeFromBuffer(data, registry);
  factory Stream.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Stream()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Stream_Content> _Stream_ContentByTag = {
    2: Stream_Content.dashVideo,
    3: Stream_Content.segmentVideo,
    0: Stream_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Stream',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Stream.$_createMessage)
    ..oo(0, [2, 3])
    ..aOM<StreamInfo>(1, _omitFieldNames ? '' : 'info',
        subBuilder: StreamInfo.$_createMessage)
    ..aOM<DashVideo>(2, _omitFieldNames ? '' : 'dashVideo',
        subBuilder: DashVideo.$_createMessage)
    ..aOM<SegmentVideo>(3, _omitFieldNames ? '' : 'segmentVideo',
        subBuilder: SegmentVideo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Stream clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Stream copyWith(void Function(Stream) updates) =>
      super.copyWith((message) => updates(message as Stream)) as Stream;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Stream() / Stream.new instead')
  static Stream create() => Stream._();
  static $pb.GeneratedMessage $_createMessage() => Stream._();
  @$core.override
  Stream createEmptyInstance() => Stream._();
  @$core.pragma('dart2js:noInline')
  static Stream getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Stream>(Stream.$_createMessage);
  static Stream? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  Stream_Content whichContent() => _Stream_ContentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearContent() => $_clearField($_whichOneof(0));

  /// 元数据
  @$pb.TagNumber(1)
  StreamInfo get info => $_getN(0);
  @$pb.TagNumber(1)
  set info(StreamInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  StreamInfo ensureInfo() => $_ensure(0);

  /// dash流
  @$pb.TagNumber(2)
  DashVideo get dashVideo => $_getN(1);
  @$pb.TagNumber(2)
  set dashVideo(DashVideo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDashVideo() => $_has(1);
  @$pb.TagNumber(2)
  void clearDashVideo() => $_clearField(2);
  @$pb.TagNumber(2)
  DashVideo ensureDashVideo() => $_ensure(1);

  /// 分段流
  @$pb.TagNumber(3)
  SegmentVideo get segmentVideo => $_getN(2);
  @$pb.TagNumber(3)
  set segmentVideo(SegmentVideo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSegmentVideo() => $_has(2);
  @$pb.TagNumber(3)
  void clearSegmentVideo() => $_clearField(3);
  @$pb.TagNumber(3)
  SegmentVideo ensureSegmentVideo() => $_ensure(2);
}

/// 流媒体元数据
class StreamInfo extends $pb.GeneratedMessage {
  factory StreamInfo({
    $core.int? quality,
    $core.String? format,
    $core.String? description,
    $core.int? errCode,
    StreamLimit? limit,
    $core.bool? needVip,
    $core.bool? needLogin,
    $core.bool? intact,
    $fixnum.Int64? attribute,
    $core.String? newDescription,
    $core.String? displayDesc,
    $core.String? superscript,
    Scheme? scheme,
    $core.bool? supportDrm,
    $core.String? subtitle,
  }) {
    final result = StreamInfo._();
    if (quality != null) result.quality = quality;
    if (format != null) result.format = format;
    if (description != null) result.description = description;
    if (errCode != null) result.errCode = errCode;
    if (limit != null) result.limit = limit;
    if (needVip != null) result.needVip = needVip;
    if (needLogin != null) result.needLogin = needLogin;
    if (intact != null) result.intact = intact;
    if (attribute != null) result.attribute = attribute;
    if (newDescription != null) result.newDescription = newDescription;
    if (displayDesc != null) result.displayDesc = displayDesc;
    if (superscript != null) result.superscript = superscript;
    if (scheme != null) result.scheme = scheme;
    if (supportDrm != null) result.supportDrm = supportDrm;
    if (subtitle != null) result.subtitle = subtitle;
    return result;
  }

  StreamInfo._();

  factory StreamInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamInfo()..mergeFromBuffer(data, registry);
  factory StreamInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: StreamInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'quality')
    ..aOS(2, _omitFieldNames ? '' : 'format')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aI(4, _omitFieldNames ? '' : 'errCode')
    ..aOM<StreamLimit>(5, _omitFieldNames ? '' : 'limit',
        subBuilder: StreamLimit.$_createMessage)
    ..aOB(6, _omitFieldNames ? '' : 'needVip')
    ..aOB(7, _omitFieldNames ? '' : 'needLogin')
    ..aOB(8, _omitFieldNames ? '' : 'intact')
    ..aInt64(10, _omitFieldNames ? '' : 'attribute')
    ..aOS(11, _omitFieldNames ? '' : 'newDescription')
    ..aOS(12, _omitFieldNames ? '' : 'displayDesc')
    ..aOS(13, _omitFieldNames ? '' : 'superscript')
    ..aOM<Scheme>(14, _omitFieldNames ? '' : 'scheme',
        subBuilder: Scheme.$_createMessage)
    ..aOB(15, _omitFieldNames ? '' : 'supportDrm')
    ..aOS(16, _omitFieldNames ? '' : 'subtitle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamInfo copyWith(void Function(StreamInfo) updates) =>
      super.copyWith((message) => updates(message as StreamInfo)) as StreamInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StreamInfo() / StreamInfo.new instead')
  static StreamInfo create() => StreamInfo._();
  static $pb.GeneratedMessage $_createMessage() => StreamInfo._();
  @$core.override
  StreamInfo createEmptyInstance() => StreamInfo._();
  @$core.pragma('dart2js:noInline')
  static StreamInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamInfo>(StreamInfo.$_createMessage);
  static StreamInfo? _defaultInstance;

  /// 视频质量
  @$pb.TagNumber(1)
  $core.int get quality => $_getIZ(0);
  @$pb.TagNumber(1)
  set quality($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuality() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuality() => $_clearField(1);

  /// 视频格式
  @$pb.TagNumber(2)
  $core.String get format => $_getSZ(1);
  @$pb.TagNumber(2)
  set format($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);

  /// 描述信息
  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  /// 错误码
  @$pb.TagNumber(4)
  $core.int get errCode => $_getIZ(3);
  @$pb.TagNumber(4)
  set errCode($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasErrCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearErrCode() => $_clearField(4);

  /// 流限制信息
  @$pb.TagNumber(5)
  StreamLimit get limit => $_getN(4);
  @$pb.TagNumber(5)
  set limit(StreamLimit value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearLimit() => $_clearField(5);
  @$pb.TagNumber(5)
  StreamLimit ensureLimit() => $_ensure(4);

  /// 是否需要VIP
  @$pb.TagNumber(6)
  $core.bool get needVip => $_getBF(5);
  @$pb.TagNumber(6)
  set needVip($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNeedVip() => $_has(5);
  @$pb.TagNumber(6)
  void clearNeedVip() => $_clearField(6);

  /// 是否需要登录
  @$pb.TagNumber(7)
  $core.bool get needLogin => $_getBF(6);
  @$pb.TagNumber(7)
  set needLogin($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNeedLogin() => $_has(6);
  @$pb.TagNumber(7)
  void clearNeedLogin() => $_clearField(7);

  /// 是否完整
  @$pb.TagNumber(8)
  $core.bool get intact => $_getBF(7);
  @$pb.TagNumber(8)
  set intact($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIntact() => $_has(7);
  @$pb.TagNumber(8)
  void clearIntact() => $_clearField(8);

  /// 权限信息
  @$pb.TagNumber(10)
  $fixnum.Int64 get attribute => $_getI64(8);
  @$pb.TagNumber(10)
  set attribute($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(10)
  $core.bool hasAttribute() => $_has(8);
  @$pb.TagNumber(10)
  void clearAttribute() => $_clearField(10);

  /// 新版描述信息
  @$pb.TagNumber(11)
  $core.String get newDescription => $_getSZ(9);
  @$pb.TagNumber(11)
  set newDescription($core.String value) => $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasNewDescription() => $_has(9);
  @$pb.TagNumber(11)
  void clearNewDescription() => $_clearField(11);

  /// 显示描述信息
  @$pb.TagNumber(12)
  $core.String get displayDesc => $_getSZ(10);
  @$pb.TagNumber(12)
  set displayDesc($core.String value) => $_setString(10, value);
  @$pb.TagNumber(12)
  $core.bool hasDisplayDesc() => $_has(10);
  @$pb.TagNumber(12)
  void clearDisplayDesc() => $_clearField(12);

  /// 上标
  @$pb.TagNumber(13)
  $core.String get superscript => $_getSZ(11);
  @$pb.TagNumber(13)
  set superscript($core.String value) => $_setString(11, value);
  @$pb.TagNumber(13)
  $core.bool hasSuperscript() => $_has(11);
  @$pb.TagNumber(13)
  void clearSuperscript() => $_clearField(13);

  /// 方案信息
  @$pb.TagNumber(14)
  Scheme get scheme => $_getN(12);
  @$pb.TagNumber(14)
  set scheme(Scheme value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasScheme() => $_has(12);
  @$pb.TagNumber(14)
  void clearScheme() => $_clearField(14);
  @$pb.TagNumber(14)
  Scheme ensureScheme() => $_ensure(12);

  /// 是否支持DRM
  @$pb.TagNumber(15)
  $core.bool get supportDrm => $_getBF(13);
  @$pb.TagNumber(15)
  set supportDrm($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(15)
  $core.bool hasSupportDrm() => $_has(13);
  @$pb.TagNumber(15)
  void clearSupportDrm() => $_clearField(15);

  /// 字幕信息
  @$pb.TagNumber(16)
  $core.String get subtitle => $_getSZ(14);
  @$pb.TagNumber(16)
  set subtitle($core.String value) => $_setString(14, value);
  @$pb.TagNumber(16)
  $core.bool hasSubtitle() => $_has(14);
  @$pb.TagNumber(16)
  void clearSubtitle() => $_clearField(16);
}

/// 清晰度不满足条件信息
class StreamLimit extends $pb.GeneratedMessage {
  factory StreamLimit({
    $core.String? title,
    $core.String? uri,
    $core.String? msg,
  }) {
    final result = StreamLimit._();
    if (title != null) result.title = title;
    if (uri != null) result.uri = uri;
    if (msg != null) result.msg = msg;
    return result;
  }

  StreamLimit._();

  factory StreamLimit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamLimit()..mergeFromBuffer(data, registry);
  factory StreamLimit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StreamLimit()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamLimit',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: StreamLimit.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'uri')
    ..aOS(3, _omitFieldNames ? '' : 'msg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamLimit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamLimit copyWith(void Function(StreamLimit) updates) =>
      super.copyWith((message) => updates(message as StreamLimit))
          as StreamLimit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StreamLimit() / StreamLimit.new instead')
  static StreamLimit create() => StreamLimit._();
  static $pb.GeneratedMessage $_createMessage() => StreamLimit._();
  @$core.override
  StreamLimit createEmptyInstance() => StreamLimit._();
  @$core.pragma('dart2js:noInline')
  static StreamLimit getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StreamLimit>(
          StreamLimit.$_createMessage);
  static StreamLimit? _defaultInstance;

  /// 标题
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 跳转地址
  @$pb.TagNumber(2)
  $core.String get uri => $_getSZ(1);
  @$pb.TagNumber(2)
  set uri($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUri() => $_has(1);
  @$pb.TagNumber(2)
  void clearUri() => $_clearField(2);

  /// 提示信息
  @$pb.TagNumber(3)
  $core.String get msg => $_getSZ(2);
  @$pb.TagNumber(3)
  set msg($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMsg() => $_has(2);
  @$pb.TagNumber(3)
  void clearMsg() => $_clearField(3);
}

/// 任务参数信息
class TaskParam extends $pb.GeneratedMessage {
  factory TaskParam({
    $core.String? taskType,
    $fixnum.Int64? activityId,
    $fixnum.Int64? tipsId,
  }) {
    final result = TaskParam._();
    if (taskType != null) result.taskType = taskType;
    if (activityId != null) result.activityId = activityId;
    if (tipsId != null) result.tipsId = tipsId;
    return result;
  }

  TaskParam._();

  factory TaskParam.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskParam()..mergeFromBuffer(data, registry);
  factory TaskParam.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskParam()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskParam',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: TaskParam.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'taskType')
    ..aInt64(2, _omitFieldNames ? '' : 'activityId')
    ..aInt64(3, _omitFieldNames ? '' : 'tipsId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskParam clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskParam copyWith(void Function(TaskParam) updates) =>
      super.copyWith((message) => updates(message as TaskParam)) as TaskParam;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskParam() / TaskParam.new instead')
  static TaskParam create() => TaskParam._();
  static $pb.GeneratedMessage $_createMessage() => TaskParam._();
  @$core.override
  TaskParam createEmptyInstance() => TaskParam._();
  @$core.pragma('dart2js:noInline')
  static TaskParam getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaskParam>(TaskParam.$_createMessage);
  static TaskParam? _defaultInstance;

  /// 任务类型
  @$pb.TagNumber(1)
  $core.String get taskType => $_getSZ(0);
  @$pb.TagNumber(1)
  set taskType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTaskType() => $_has(0);
  @$pb.TagNumber(1)
  void clearTaskType() => $_clearField(1);

  /// 活动ID
  @$pb.TagNumber(2)
  $fixnum.Int64 get activityId => $_getI64(1);
  @$pb.TagNumber(2)
  set activityId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActivityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearActivityId() => $_clearField(2);

  /// 提示ID
  @$pb.TagNumber(3)
  $fixnum.Int64 get tipsId => $_getI64(2);
  @$pb.TagNumber(3)
  set tipsId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTipsId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTipsId() => $_clearField(3);
}

/// 文案信息
class TextInfo extends $pb.GeneratedMessage {
  factory TextInfo({
    $core.String? text,
    $core.String? textColor,
    $core.String? textColorNight,
  }) {
    final result = TextInfo._();
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    return result;
  }

  TextInfo._();

  factory TextInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TextInfo()..mergeFromBuffer(data, registry);
  factory TextInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TextInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TextInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: TextInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'textColor')
    ..aOS(3, _omitFieldNames ? '' : 'textColorNight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextInfo copyWith(void Function(TextInfo) updates) =>
      super.copyWith((message) => updates(message as TextInfo)) as TextInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TextInfo() / TextInfo.new instead')
  static TextInfo create() => TextInfo._();
  static $pb.GeneratedMessage $_createMessage() => TextInfo._();
  @$core.override
  TextInfo createEmptyInstance() => TextInfo._();
  @$core.pragma('dart2js:noInline')
  static TextInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TextInfo>(TextInfo.$_createMessage);
  static TextInfo? _defaultInstance;

  /// 文案
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// 字体色值
  @$pb.TagNumber(2)
  $core.String get textColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set textColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTextColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearTextColor() => $_clearField(2);

  /// 字体色值-夜间模式
  @$pb.TagNumber(3)
  $core.String get textColorNight => $_getSZ(2);
  @$pb.TagNumber(3)
  set textColorNight($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTextColorNight() => $_has(2);
  @$pb.TagNumber(3)
  void clearTextColorNight() => $_clearField(3);
}

/// toast
class Toast extends $pb.GeneratedMessage {
  factory Toast({
    $core.String? text,
    ButtonInfo? button,
    $core.int? showStyleType,
    $core.String? icon,
    TextInfo? toastText,
    Report? report,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        orderReportParams,
  }) {
    final result = Toast._();
    if (text != null) result.text = text;
    if (button != null) result.button = button;
    if (showStyleType != null) result.showStyleType = showStyleType;
    if (icon != null) result.icon = icon;
    if (toastText != null) result.toastText = toastText;
    if (report != null) result.report = report;
    if (orderReportParams != null)
      result.orderReportParams.addEntries(orderReportParams);
    return result;
  }

  Toast._();

  factory Toast.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Toast()..mergeFromBuffer(data, registry);
  factory Toast.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Toast()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Toast',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: Toast.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOM<ButtonInfo>(2, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonInfo.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'showStyleType')
    ..aOS(4, _omitFieldNames ? '' : 'icon')
    ..aOM<TextInfo>(5, _omitFieldNames ? '' : 'toastText',
        subBuilder: TextInfo.$_createMessage)
    ..aOM<Report>(6, _omitFieldNames ? '' : 'report',
        subBuilder: Report.$_createMessage)
    ..m<$core.String, $core.String>(
        7, _omitFieldNames ? '' : 'orderReportParams',
        entryClassName: 'Toast.OrderReportParamsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Toast clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Toast copyWith(void Function(Toast) updates) =>
      super.copyWith((message) => updates(message as Toast)) as Toast;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Toast() / Toast.new instead')
  static Toast create() => Toast._();
  static $pb.GeneratedMessage $_createMessage() => Toast._();
  @$core.override
  Toast createEmptyInstance() => Toast._();
  @$core.pragma('dart2js:noInline')
  static Toast getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Toast>(Toast.$_createMessage);
  static Toast? _defaultInstance;

  /// toast文案 老字段
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// toast按钮
  @$pb.TagNumber(2)
  ButtonInfo get button => $_getN(1);
  @$pb.TagNumber(2)
  set button(ButtonInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasButton() => $_has(1);
  @$pb.TagNumber(2)
  void clearButton() => $_clearField(2);
  @$pb.TagNumber(2)
  ButtonInfo ensureButton() => $_ensure(1);

  /// 显示样式类型
  @$pb.TagNumber(3)
  $core.int get showStyleType => $_getIZ(2);
  @$pb.TagNumber(3)
  set showStyleType($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShowStyleType() => $_has(2);
  @$pb.TagNumber(3)
  void clearShowStyleType() => $_clearField(3);

  /// 图标
  @$pb.TagNumber(4)
  $core.String get icon => $_getSZ(3);
  @$pb.TagNumber(4)
  set icon($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIcon() => $_has(3);
  @$pb.TagNumber(4)
  void clearIcon() => $_clearField(4);

  /// toast文案 新字段
  @$pb.TagNumber(5)
  TextInfo get toastText => $_getN(4);
  @$pb.TagNumber(5)
  set toastText(TextInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasToastText() => $_has(4);
  @$pb.TagNumber(5)
  void clearToastText() => $_clearField(5);
  @$pb.TagNumber(5)
  TextInfo ensureToastText() => $_ensure(4);

  /// 埋点上报信息
  @$pb.TagNumber(6)
  Report get report => $_getN(5);
  @$pb.TagNumber(6)
  set report(Report value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasReport() => $_has(5);
  @$pb.TagNumber(6)
  void clearReport() => $_clearField(6);
  @$pb.TagNumber(6)
  Report ensureReport() => $_ensure(5);

  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, $core.String> get orderReportParams => $_getMap(6);
}

/// 用户状态信息
class UserStatus extends $pb.GeneratedMessage {
  factory UserStatus({
    $core.bool? payCheck,
    $core.bool? sponsor,
    WatchProgress? watchProgress,
    WatchProgress? aidWatchProgress,
  }) {
    final result = UserStatus._();
    if (payCheck != null) result.payCheck = payCheck;
    if (sponsor != null) result.sponsor = sponsor;
    if (watchProgress != null) result.watchProgress = watchProgress;
    if (aidWatchProgress != null) result.aidWatchProgress = aidWatchProgress;
    return result;
  }

  UserStatus._();

  factory UserStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserStatus()..mergeFromBuffer(data, registry);
  factory UserStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserStatus',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: UserStatus.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'payCheck')
    ..aOB(2, _omitFieldNames ? '' : 'sponsor')
    ..aOM<WatchProgress>(3, _omitFieldNames ? '' : 'watchProgress',
        subBuilder: WatchProgress.$_createMessage)
    ..aOM<WatchProgress>(4, _omitFieldNames ? '' : 'aidWatchProgress',
        subBuilder: WatchProgress.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserStatus copyWith(void Function(UserStatus) updates) =>
      super.copyWith((message) => updates(message as UserStatus)) as UserStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserStatus() / UserStatus.new instead')
  static UserStatus create() => UserStatus._();
  static $pb.GeneratedMessage $_createMessage() => UserStatus._();
  @$core.override
  UserStatus createEmptyInstance() => UserStatus._();
  @$core.pragma('dart2js:noInline')
  static UserStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserStatus>(UserStatus.$_createMessage);
  static UserStatus? _defaultInstance;

  /// 是否支付
  @$pb.TagNumber(1)
  $core.bool get payCheck => $_getBF(0);
  @$pb.TagNumber(1)
  set payCheck($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPayCheck() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayCheck() => $_clearField(1);

  /// 是否承包
  @$pb.TagNumber(2)
  $core.bool get sponsor => $_getBF(1);
  @$pb.TagNumber(2)
  set sponsor($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSponsor() => $_has(1);
  @$pb.TagNumber(2)
  void clearSponsor() => $_clearField(2);

  /// 观看进度
  @$pb.TagNumber(3)
  WatchProgress get watchProgress => $_getN(2);
  @$pb.TagNumber(3)
  set watchProgress(WatchProgress value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasWatchProgress() => $_has(2);
  @$pb.TagNumber(3)
  void clearWatchProgress() => $_clearField(3);
  @$pb.TagNumber(3)
  WatchProgress ensureWatchProgress() => $_ensure(2);

  /// 系列观看进度
  @$pb.TagNumber(4)
  WatchProgress get aidWatchProgress => $_getN(3);
  @$pb.TagNumber(4)
  set aidWatchProgress(WatchProgress value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAidWatchProgress() => $_has(3);
  @$pb.TagNumber(4)
  void clearAidWatchProgress() => $_clearField(4);
  @$pb.TagNumber(4)
  WatchProgress ensureAidWatchProgress() => $_ensure(3);
}

/// 视频url信息
class VideoInfo extends $pb.GeneratedMessage {
  factory VideoInfo({
    $core.int? quality,
    $core.String? format,
    $fixnum.Int64? timelength,
    $core.int? videoCodecid,
    $core.Iterable<Stream>? streamList,
    $core.Iterable<DashItem>? dashAudio,
    DolbyItem? dolby,
  }) {
    final result = VideoInfo._();
    if (quality != null) result.quality = quality;
    if (format != null) result.format = format;
    if (timelength != null) result.timelength = timelength;
    if (videoCodecid != null) result.videoCodecid = videoCodecid;
    if (streamList != null) result.streamList.addAll(streamList);
    if (dashAudio != null) result.dashAudio.addAll(dashAudio);
    if (dolby != null) result.dolby = dolby;
    return result;
  }

  VideoInfo._();

  factory VideoInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoInfo()..mergeFromBuffer(data, registry);
  factory VideoInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VideoInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: VideoInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'quality', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'format')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'timelength', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'videoCodecid',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<Stream>(5, _omitFieldNames ? '' : 'streamList',
        subBuilder: Stream.$_createMessage)
    ..pPM<DashItem>(6, _omitFieldNames ? '' : 'dashAudio',
        subBuilder: DashItem.$_createMessage)
    ..aOM<DolbyItem>(7, _omitFieldNames ? '' : 'dolby',
        subBuilder: DolbyItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoInfo copyWith(void Function(VideoInfo) updates) =>
      super.copyWith((message) => updates(message as VideoInfo)) as VideoInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VideoInfo() / VideoInfo.new instead')
  static VideoInfo create() => VideoInfo._();
  static $pb.GeneratedMessage $_createMessage() => VideoInfo._();
  @$core.override
  VideoInfo createEmptyInstance() => VideoInfo._();
  @$core.pragma('dart2js:noInline')
  static VideoInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VideoInfo>(VideoInfo.$_createMessage);
  static VideoInfo? _defaultInstance;

  /// 视频清晰度
  @$pb.TagNumber(1)
  $core.int get quality => $_getIZ(0);
  @$pb.TagNumber(1)
  set quality($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuality() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuality() => $_clearField(1);

  /// 视频格式
  @$pb.TagNumber(2)
  $core.String get format => $_getSZ(1);
  @$pb.TagNumber(2)
  set format($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);

  /// 视频时长
  @$pb.TagNumber(3)
  $fixnum.Int64 get timelength => $_getI64(2);
  @$pb.TagNumber(3)
  set timelength($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimelength() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimelength() => $_clearField(3);

  /// 视频编码id
  @$pb.TagNumber(4)
  $core.int get videoCodecid => $_getIZ(3);
  @$pb.TagNumber(4)
  set videoCodecid($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVideoCodecid() => $_has(3);
  @$pb.TagNumber(4)
  void clearVideoCodecid() => $_clearField(4);

  /// 视频流
  @$pb.TagNumber(5)
  $pb.PbList<Stream> get streamList => $_getList(4);

  /// 伴音流
  @$pb.TagNumber(6)
  $pb.PbList<DashItem> get dashAudio => $_getList(5);

  /// 杜比伴音流
  @$pb.TagNumber(7)
  DolbyItem get dolby => $_getN(6);
  @$pb.TagNumber(7)
  set dolby(DolbyItem value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDolby() => $_has(6);
  @$pb.TagNumber(7)
  void clearDolby() => $_clearField(7);
  @$pb.TagNumber(7)
  DolbyItem ensureDolby() => $_ensure(6);
}

/// 展示信息
class ViewInfo extends $pb.GeneratedMessage {
  factory ViewInfo({
    Dialog? dialog,
    Toast? toast,
    CouponInfo? couponInfo,
    $core.Iterable<$fixnum.Int64>? demandNoPayEpids,
    EndPage? endPage,
    $core.Iterable<$core.MapEntry<$core.String, $core.bool>>? expConfig,
    PopWin? popWin,
    PromptBar? tryWatchPromptBar,
    PayTip? payTip,
    HighDefinitionTrialInfo? highDefinitionTrialInfo,
    $core.Iterable<$core.MapEntry<$core.String, Dialog>>? extDialog,
    Animation? animation,
    $core.Iterable<$core.MapEntry<$core.String, Toast>>? extToast,
  }) {
    final result = ViewInfo._();
    if (dialog != null) result.dialog = dialog;
    if (toast != null) result.toast = toast;
    if (couponInfo != null) result.couponInfo = couponInfo;
    if (demandNoPayEpids != null)
      result.demandNoPayEpids.addAll(demandNoPayEpids);
    if (endPage != null) result.endPage = endPage;
    if (expConfig != null) result.expConfig.addEntries(expConfig);
    if (popWin != null) result.popWin = popWin;
    if (tryWatchPromptBar != null) result.tryWatchPromptBar = tryWatchPromptBar;
    if (payTip != null) result.payTip = payTip;
    if (highDefinitionTrialInfo != null)
      result.highDefinitionTrialInfo = highDefinitionTrialInfo;
    if (extDialog != null) result.extDialog.addEntries(extDialog);
    if (animation != null) result.animation = animation;
    if (extToast != null) result.extToast.addEntries(extToast);
    return result;
  }

  ViewInfo._();

  factory ViewInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewInfo()..mergeFromBuffer(data, registry);
  factory ViewInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: ViewInfo.$_createMessage)
    ..aOM<Dialog>(1, _omitFieldNames ? '' : 'dialog',
        subBuilder: Dialog.$_createMessage)
    ..aOM<Toast>(2, _omitFieldNames ? '' : 'toast',
        subBuilder: Toast.$_createMessage)
    ..aOM<CouponInfo>(3, _omitFieldNames ? '' : 'couponInfo',
        subBuilder: CouponInfo.$_createMessage)
    ..p<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'demandNoPayEpids', $pb.PbFieldType.K6)
    ..aOM<EndPage>(5, _omitFieldNames ? '' : 'endPage',
        subBuilder: EndPage.$_createMessage)
    ..m<$core.String, $core.bool>(6, _omitFieldNames ? '' : 'expConfig',
        entryClassName: 'ViewInfo.ExpConfigEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OB,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..aOM<PopWin>(7, _omitFieldNames ? '' : 'popWin',
        subBuilder: PopWin.$_createMessage)
    ..aOM<PromptBar>(8, _omitFieldNames ? '' : 'tryWatchPromptBar',
        subBuilder: PromptBar.$_createMessage)
    ..aOM<PayTip>(9, _omitFieldNames ? '' : 'payTip',
        subBuilder: PayTip.$_createMessage)
    ..aOM<HighDefinitionTrialInfo>(
        10, _omitFieldNames ? '' : 'highDefinitionTrialInfo',
        subBuilder: HighDefinitionTrialInfo.$_createMessage)
    ..m<$core.String, Dialog>(11, _omitFieldNames ? '' : 'extDialog',
        entryClassName: 'ViewInfo.ExtDialogEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Dialog.$_createMessage,
        valueDefaultOrMaker: Dialog.getDefault,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..aOM<Animation>(12, _omitFieldNames ? '' : 'animation',
        subBuilder: Animation.$_createMessage)
    ..m<$core.String, Toast>(13, _omitFieldNames ? '' : 'extToast',
        entryClassName: 'ViewInfo.ExtToastEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Toast.$_createMessage,
        valueDefaultOrMaker: Toast.getDefault,
        packageName: const $pb.PackageName('bilibili.pgc.gateway.player.v2'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewInfo copyWith(void Function(ViewInfo) updates) =>
      super.copyWith((message) => updates(message as ViewInfo)) as ViewInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewInfo() / ViewInfo.new instead')
  static ViewInfo create() => ViewInfo._();
  static $pb.GeneratedMessage $_createMessage() => ViewInfo._();
  @$core.override
  ViewInfo createEmptyInstance() => ViewInfo._();
  @$core.pragma('dart2js:noInline')
  static ViewInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ViewInfo>(ViewInfo.$_createMessage);
  static ViewInfo? _defaultInstance;

  /// 弹窗
  @$pb.TagNumber(1)
  Dialog get dialog => $_getN(0);
  @$pb.TagNumber(1)
  set dialog(Dialog value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDialog() => $_has(0);
  @$pb.TagNumber(1)
  void clearDialog() => $_clearField(1);
  @$pb.TagNumber(1)
  Dialog ensureDialog() => $_ensure(0);

  /// Toast
  @$pb.TagNumber(2)
  Toast get toast => $_getN(1);
  @$pb.TagNumber(2)
  set toast(Toast value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasToast() => $_has(1);
  @$pb.TagNumber(2)
  void clearToast() => $_clearField(2);
  @$pb.TagNumber(2)
  Toast ensureToast() => $_ensure(1);

  /// 优惠券信息
  @$pb.TagNumber(3)
  CouponInfo get couponInfo => $_getN(2);
  @$pb.TagNumber(3)
  set couponInfo(CouponInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCouponInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearCouponInfo() => $_clearField(3);
  @$pb.TagNumber(3)
  CouponInfo ensureCouponInfo() => $_ensure(2);

  /// 未支付剧集ID列表
  @$pb.TagNumber(4)
  $pb.PbList<$fixnum.Int64> get demandNoPayEpids => $_getList(3);

  /// 结束页
  @$pb.TagNumber(5)
  EndPage get endPage => $_getN(4);
  @$pb.TagNumber(5)
  set endPage(EndPage value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEndPage() => $_has(4);
  @$pb.TagNumber(5)
  void clearEndPage() => $_clearField(5);
  @$pb.TagNumber(5)
  EndPage ensureEndPage() => $_ensure(4);

  /// 扩展配置
  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, $core.bool> get expConfig => $_getMap(5);

  /// 弹窗
  @$pb.TagNumber(7)
  PopWin get popWin => $_getN(6);
  @$pb.TagNumber(7)
  set popWin(PopWin value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPopWin() => $_has(6);
  @$pb.TagNumber(7)
  void clearPopWin() => $_clearField(7);
  @$pb.TagNumber(7)
  PopWin ensurePopWin() => $_ensure(6);

  /// 试看提示栏
  @$pb.TagNumber(8)
  PromptBar get tryWatchPromptBar => $_getN(7);
  @$pb.TagNumber(8)
  set tryWatchPromptBar(PromptBar value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTryWatchPromptBar() => $_has(7);
  @$pb.TagNumber(8)
  void clearTryWatchPromptBar() => $_clearField(8);
  @$pb.TagNumber(8)
  PromptBar ensureTryWatchPromptBar() => $_ensure(7);

  /// 支付提示信息
  @$pb.TagNumber(9)
  PayTip get payTip => $_getN(8);
  @$pb.TagNumber(9)
  set payTip(PayTip value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasPayTip() => $_has(8);
  @$pb.TagNumber(9)
  void clearPayTip() => $_clearField(9);
  @$pb.TagNumber(9)
  PayTip ensurePayTip() => $_ensure(8);

  /// 高清试看提示信息
  @$pb.TagNumber(10)
  HighDefinitionTrialInfo get highDefinitionTrialInfo => $_getN(9);
  @$pb.TagNumber(10)
  set highDefinitionTrialInfo(HighDefinitionTrialInfo value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasHighDefinitionTrialInfo() => $_has(9);
  @$pb.TagNumber(10)
  void clearHighDefinitionTrialInfo() => $_clearField(10);
  @$pb.TagNumber(10)
  HighDefinitionTrialInfo ensureHighDefinitionTrialInfo() => $_ensure(9);

  /// 弹窗扩展
  @$pb.TagNumber(11)
  $pb.PbMap<$core.String, Dialog> get extDialog => $_getMap(10);

  /// 动画
  @$pb.TagNumber(12)
  Animation get animation => $_getN(11);
  @$pb.TagNumber(12)
  set animation(Animation value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasAnimation() => $_has(11);
  @$pb.TagNumber(12)
  void clearAnimation() => $_clearField(12);
  @$pb.TagNumber(12)
  Animation ensureAnimation() => $_ensure(11);

  /// Toast扩展
  @$pb.TagNumber(13)
  $pb.PbMap<$core.String, Toast> get extToast => $_getMap(12);
}

/// 观看进度信息
class WatchProgress extends $pb.GeneratedMessage {
  factory WatchProgress({
    $core.int? lastEpId,
    $core.String? lastEpIndex,
    $fixnum.Int64? progress,
    $fixnum.Int64? lastPlayCid,
    Toast? toast,
    Toast? toastWithoutTime,
    $fixnum.Int64? lastPlayAid,
  }) {
    final result = WatchProgress._();
    if (lastEpId != null) result.lastEpId = lastEpId;
    if (lastEpIndex != null) result.lastEpIndex = lastEpIndex;
    if (progress != null) result.progress = progress;
    if (lastPlayCid != null) result.lastPlayCid = lastPlayCid;
    if (toast != null) result.toast = toast;
    if (toastWithoutTime != null) result.toastWithoutTime = toastWithoutTime;
    if (lastPlayAid != null) result.lastPlayAid = lastPlayAid;
    return result;
  }

  WatchProgress._();

  factory WatchProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchProgress()..mergeFromBuffer(data, registry);
  factory WatchProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchProgress',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.pgc.gateway.player.v2'),
      createEmptyInstance: WatchProgress.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'lastEpId')
    ..aOS(2, _omitFieldNames ? '' : 'lastEpIndex')
    ..aInt64(3, _omitFieldNames ? '' : 'progress')
    ..aInt64(4, _omitFieldNames ? '' : 'lastPlayCid')
    ..aOM<Toast>(5, _omitFieldNames ? '' : 'toast',
        subBuilder: Toast.$_createMessage)
    ..aOM<Toast>(6, _omitFieldNames ? '' : 'toastWithoutTime',
        subBuilder: Toast.$_createMessage)
    ..aInt64(7, _omitFieldNames ? '' : 'lastPlayAid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchProgress copyWith(void Function(WatchProgress) updates) =>
      super.copyWith((message) => updates(message as WatchProgress))
          as WatchProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchProgress() / WatchProgress.new instead')
  static WatchProgress create() => WatchProgress._();
  static $pb.GeneratedMessage $_createMessage() => WatchProgress._();
  @$core.override
  WatchProgress createEmptyInstance() => WatchProgress._();
  @$core.pragma('dart2js:noInline')
  static WatchProgress getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WatchProgress>(
          WatchProgress.$_createMessage);
  static WatchProgress? _defaultInstance;

  /// 上次观看的 EP ID
  @$pb.TagNumber(1)
  $core.int get lastEpId => $_getIZ(0);
  @$pb.TagNumber(1)
  set lastEpId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLastEpId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLastEpId() => $_clearField(1);

  /// 上次观看到的EP INDEX
  @$pb.TagNumber(2)
  $core.String get lastEpIndex => $_getSZ(1);
  @$pb.TagNumber(2)
  set lastEpIndex($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastEpIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastEpIndex() => $_clearField(2);

  /// 上次观看的进度
  @$pb.TagNumber(3)
  $fixnum.Int64 get progress => $_getI64(2);
  @$pb.TagNumber(3)
  set progress($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProgress() => $_has(2);
  @$pb.TagNumber(3)
  void clearProgress() => $_clearField(3);

  /// 上次观看的 CID
  @$pb.TagNumber(4)
  $fixnum.Int64 get lastPlayCid => $_getI64(3);
  @$pb.TagNumber(4)
  set lastPlayCid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastPlayCid() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastPlayCid() => $_clearField(4);

  /// 带时间的提示信息
  @$pb.TagNumber(5)
  Toast get toast => $_getN(4);
  @$pb.TagNumber(5)
  set toast(Toast value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasToast() => $_has(4);
  @$pb.TagNumber(5)
  void clearToast() => $_clearField(5);
  @$pb.TagNumber(5)
  Toast ensureToast() => $_ensure(4);

  /// 不带时间的提示信息
  @$pb.TagNumber(6)
  Toast get toastWithoutTime => $_getN(5);
  @$pb.TagNumber(6)
  set toastWithoutTime(Toast value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasToastWithoutTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearToastWithoutTime() => $_clearField(6);
  @$pb.TagNumber(6)
  Toast ensureToastWithoutTime() => $_ensure(5);

  /// 上次观看的 AID
  @$pb.TagNumber(7)
  $fixnum.Int64 get lastPlayAid => $_getI64(6);
  @$pb.TagNumber(7)
  set lastPlayAid($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastPlayAid() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastPlayAid() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
