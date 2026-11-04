// This is a generated file - do not edit.
//
// Generated from bilibili/metadata/network/network.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'network.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'network.pbenum.dart';

/// 网络类型标识
/// gRPC头部:x-bili-network-bin
class Network extends $pb.GeneratedMessage {
  factory Network({
    NetworkType? type,
    TFType? tf,
    $core.String? oid,
  }) {
    final result = Network._();
    if (type != null) result.type = type;
    if (tf != null) result.tf = tf;
    if (oid != null) result.oid = oid;
    return result;
  }

  Network._();

  factory Network.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Network()..mergeFromBuffer(data, registry);
  factory Network.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Network()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Network',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.metadata.network'),
      createEmptyInstance: Network.$_createMessage)
    ..aE<NetworkType>(1, _omitFieldNames ? '' : 'type',
        enumValues: NetworkType.values)
    ..aE<TFType>(2, _omitFieldNames ? '' : 'tf', enumValues: TFType.values)
    ..aOS(3, _omitFieldNames ? '' : 'oid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Network clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Network copyWith(void Function(Network) updates) =>
      super.copyWith((message) => updates(message as Network)) as Network;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Network() / Network.new instead')
  static Network create() => Network._();
  static $pb.GeneratedMessage $_createMessage() => Network._();
  @$core.override
  Network createEmptyInstance() => Network._();
  @$core.pragma('dart2js:noInline')
  static Network getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Network>(Network.$_createMessage);
  static Network? _defaultInstance;

  /// 网络类型
  @$pb.TagNumber(1)
  NetworkType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(NetworkType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// 免流类型
  @$pb.TagNumber(2)
  TFType get tf => $_getN(1);
  @$pb.TagNumber(2)
  set tf(TFType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTf() => $_has(1);
  @$pb.TagNumber(2)
  void clearTf() => $_clearField(2);

  /// 运营商
  @$pb.TagNumber(3)
  $core.String get oid => $_getSZ(2);
  @$pb.TagNumber(3)
  set oid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOid() => $_has(2);
  @$pb.TagNumber(3)
  void clearOid() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
