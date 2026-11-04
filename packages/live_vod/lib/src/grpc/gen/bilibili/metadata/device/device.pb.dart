// This is a generated file - do not edit.
//
// Generated from bilibili/metadata/device/device.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// 设备信息
/// gRPC头部:x-bili-device-bin
class Device extends $pb.GeneratedMessage {
  factory Device({
    $core.int? appId,
    $core.int? build,
    $core.String? buvid,
    $core.String? mobiApp,
    $core.String? platform,
    $core.String? device,
    $core.String? channel,
    $core.String? brand,
    $core.String? model,
    $core.String? osver,
    $core.String? fpLocal,
    $core.String? fpRemote,
    $core.String? versionName,
    $core.String? fp,
    $fixnum.Int64? fts,
  }) {
    final result = Device._();
    if (appId != null) result.appId = appId;
    if (build != null) result.build = build;
    if (buvid != null) result.buvid = buvid;
    if (mobiApp != null) result.mobiApp = mobiApp;
    if (platform != null) result.platform = platform;
    if (device != null) result.device = device;
    if (channel != null) result.channel = channel;
    if (brand != null) result.brand = brand;
    if (model != null) result.model = model;
    if (osver != null) result.osver = osver;
    if (fpLocal != null) result.fpLocal = fpLocal;
    if (fpRemote != null) result.fpRemote = fpRemote;
    if (versionName != null) result.versionName = versionName;
    if (fp != null) result.fp = fp;
    if (fts != null) result.fts = fts;
    return result;
  }

  Device._();

  factory Device.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Device()..mergeFromBuffer(data, registry);
  factory Device.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Device()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.metadata.device'),
      createEmptyInstance: Device.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'appId')
    ..aI(2, _omitFieldNames ? '' : 'build')
    ..aOS(3, _omitFieldNames ? '' : 'buvid')
    ..aOS(4, _omitFieldNames ? '' : 'mobiApp')
    ..aOS(5, _omitFieldNames ? '' : 'platform')
    ..aOS(6, _omitFieldNames ? '' : 'device')
    ..aOS(7, _omitFieldNames ? '' : 'channel')
    ..aOS(8, _omitFieldNames ? '' : 'brand')
    ..aOS(9, _omitFieldNames ? '' : 'model')
    ..aOS(10, _omitFieldNames ? '' : 'osver')
    ..aOS(11, _omitFieldNames ? '' : 'fpLocal')
    ..aOS(12, _omitFieldNames ? '' : 'fpRemote')
    ..aOS(13, _omitFieldNames ? '' : 'versionName')
    ..aOS(14, _omitFieldNames ? '' : 'fp')
    ..aInt64(15, _omitFieldNames ? '' : 'fts')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device copyWith(void Function(Device) updates) =>
      super.copyWith((message) => updates(message as Device)) as Device;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Device() / Device.new instead')
  static Device create() => Device._();
  static $pb.GeneratedMessage $_createMessage() => Device._();
  @$core.override
  Device createEmptyInstance() => Device._();
  @$core.pragma('dart2js:noInline')
  static Device getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Device>(Device.$_createMessage);
  static Device? _defaultInstance;

  /// 产品id
  /// 粉 白 蓝 直播姬 HD 海外 OTT 漫画 TV野版 小视频 网易漫画 网易漫画 网易漫画HD 国际版 东南亚版
  /// 1  2  3    4    5   6    7   8     9     10      11       12       13       14       30
  @$pb.TagNumber(1)
  $core.int get appId => $_getIZ(0);
  @$pb.TagNumber(1)
  set appId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppId() => $_clearField(1);

  /// 构建id
  @$pb.TagNumber(2)
  $core.int get build => $_getIZ(1);
  @$pb.TagNumber(2)
  set build($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBuild() => $_has(1);
  @$pb.TagNumber(2)
  void clearBuild() => $_clearField(2);

  /// 设备buvid
  @$pb.TagNumber(3)
  $core.String get buvid => $_getSZ(2);
  @$pb.TagNumber(3)
  set buvid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBuvid() => $_has(2);
  @$pb.TagNumber(3)
  void clearBuvid() => $_clearField(3);

  /// 包类型
  @$pb.TagNumber(4)
  $core.String get mobiApp => $_getSZ(3);
  @$pb.TagNumber(4)
  set mobiApp($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMobiApp() => $_has(3);
  @$pb.TagNumber(4)
  void clearMobiApp() => $_clearField(4);

  /// 平台类型
  /// ios android
  @$pb.TagNumber(5)
  $core.String get platform => $_getSZ(4);
  @$pb.TagNumber(5)
  set platform($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPlatform() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlatform() => $_clearField(5);

  /// 设备类型
  @$pb.TagNumber(6)
  $core.String get device => $_getSZ(5);
  @$pb.TagNumber(6)
  set device($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDevice() => $_has(5);
  @$pb.TagNumber(6)
  void clearDevice() => $_clearField(6);

  /// 渠道
  @$pb.TagNumber(7)
  $core.String get channel => $_getSZ(6);
  @$pb.TagNumber(7)
  set channel($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasChannel() => $_has(6);
  @$pb.TagNumber(7)
  void clearChannel() => $_clearField(7);

  /// 手机品牌
  @$pb.TagNumber(8)
  $core.String get brand => $_getSZ(7);
  @$pb.TagNumber(8)
  set brand($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBrand() => $_has(7);
  @$pb.TagNumber(8)
  void clearBrand() => $_clearField(8);

  /// 手机型号
  @$pb.TagNumber(9)
  $core.String get model => $_getSZ(8);
  @$pb.TagNumber(9)
  set model($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasModel() => $_has(8);
  @$pb.TagNumber(9)
  void clearModel() => $_clearField(9);

  /// 系统版本
  @$pb.TagNumber(10)
  $core.String get osver => $_getSZ(9);
  @$pb.TagNumber(10)
  set osver($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasOsver() => $_has(9);
  @$pb.TagNumber(10)
  void clearOsver() => $_clearField(10);

  /// 本地设备指纹
  @$pb.TagNumber(11)
  $core.String get fpLocal => $_getSZ(10);
  @$pb.TagNumber(11)
  set fpLocal($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasFpLocal() => $_has(10);
  @$pb.TagNumber(11)
  void clearFpLocal() => $_clearField(11);

  /// 远程设备指纹
  @$pb.TagNumber(12)
  $core.String get fpRemote => $_getSZ(11);
  @$pb.TagNumber(12)
  set fpRemote($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasFpRemote() => $_has(11);
  @$pb.TagNumber(12)
  void clearFpRemote() => $_clearField(12);

  /// APP版本号
  @$pb.TagNumber(13)
  $core.String get versionName => $_getSZ(12);
  @$pb.TagNumber(13)
  set versionName($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasVersionName() => $_has(12);
  @$pb.TagNumber(13)
  void clearVersionName() => $_clearField(13);

  /// 设备指纹, 不区分本地或远程设备指纹，作为推送目标的索引
  @$pb.TagNumber(14)
  $core.String get fp => $_getSZ(13);
  @$pb.TagNumber(14)
  set fp($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasFp() => $_has(13);
  @$pb.TagNumber(14)
  void clearFp() => $_clearField(14);

  /// 首次启动时的毫秒时间戳
  @$pb.TagNumber(15)
  $fixnum.Int64 get fts => $_getI64(14);
  @$pb.TagNumber(15)
  set fts($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasFts() => $_has(14);
  @$pb.TagNumber(15)
  void clearFts() => $_clearField(15);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
