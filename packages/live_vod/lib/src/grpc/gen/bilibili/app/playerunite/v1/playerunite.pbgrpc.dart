// This is a generated file - do not edit.
//
// Generated from bilibili/app/playerunite/v1/playerunite.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'playerunite.pb.dart' as $0;

export 'playerunite.pb.dart';

/// 统一视频url
@$pb.GrpcServiceName('bilibili.app.playerunite.v1.Player')
class PlayerClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PlayerClient(super.channel, {super.options, super.interceptors});

  /// 视频地址
  $grpc.ResponseFuture<$0.PlayViewUniteReply> playViewUnite(
    $0.PlayViewUniteReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$playViewUnite, request, options: options);
  }

  // method descriptors

  static final _$playViewUnite =
      $grpc.ClientMethod<$0.PlayViewUniteReq, $0.PlayViewUniteReply>(
          '/bilibili.app.playerunite.v1.Player/PlayViewUnite',
          ($0.PlayViewUniteReq value) => value.writeToBuffer(),
          $0.PlayViewUniteReply.fromBuffer);
}

@$pb.GrpcServiceName('bilibili.app.playerunite.v1.Player')
abstract class PlayerServiceBase extends $grpc.Service {
  $core.String get $name => 'bilibili.app.playerunite.v1.Player';

  PlayerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.PlayViewUniteReq, $0.PlayViewUniteReply>(
        'PlayViewUnite',
        playViewUnite_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PlayViewUniteReq.fromBuffer(value),
        ($0.PlayViewUniteReply value) => value.writeToBuffer()));
  }

  $async.Future<$0.PlayViewUniteReply> playViewUnite_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.PlayViewUniteReq> $request) async {
    return playViewUnite($call, await $request);
  }

  $async.Future<$0.PlayViewUniteReply> playViewUnite(
      $grpc.ServiceCall call, $0.PlayViewUniteReq request);
}
