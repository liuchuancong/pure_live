// This is a generated file - do not edit.
//
// Generated from bilibili/pgc/gateway/player/v2/playurl.proto.

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

import 'playurl.pb.dart' as $0;

export 'playurl.pb.dart';

/// 视频url
@$pb.GrpcServiceName('bilibili.pgc.gateway.player.v2.PlayURL')
class PlayURLClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PlayURLClient(super.channel, {super.options, super.interceptors});

  /// 播放页信息
  $grpc.ResponseFuture<$0.PlayViewReply> playView(
    $0.PlayViewReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$playView, request, options: options);
  }

  $grpc.ResponseFuture<$0.PlayViewReply> playViewComic(
    $0.PlayViewReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$playViewComic, request, options: options);
  }

  // method descriptors

  static final _$playView =
      $grpc.ClientMethod<$0.PlayViewReq, $0.PlayViewReply>(
          '/bilibili.pgc.gateway.player.v2.PlayURL/PlayView',
          ($0.PlayViewReq value) => value.writeToBuffer(),
          $0.PlayViewReply.fromBuffer);
  static final _$playViewComic =
      $grpc.ClientMethod<$0.PlayViewReq, $0.PlayViewReply>(
          '/bilibili.pgc.gateway.player.v2.PlayURL/PlayViewComic',
          ($0.PlayViewReq value) => value.writeToBuffer(),
          $0.PlayViewReply.fromBuffer);
}

@$pb.GrpcServiceName('bilibili.pgc.gateway.player.v2.PlayURL')
abstract class PlayURLServiceBase extends $grpc.Service {
  $core.String get $name => 'bilibili.pgc.gateway.player.v2.PlayURL';

  PlayURLServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.PlayViewReq, $0.PlayViewReply>(
        'PlayView',
        playView_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PlayViewReq.fromBuffer(value),
        ($0.PlayViewReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PlayViewReq, $0.PlayViewReply>(
        'PlayViewComic',
        playViewComic_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PlayViewReq.fromBuffer(value),
        ($0.PlayViewReply value) => value.writeToBuffer()));
  }

  $async.Future<$0.PlayViewReply> playView_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PlayViewReq> $request) async {
    return playView($call, await $request);
  }

  $async.Future<$0.PlayViewReply> playView(
      $grpc.ServiceCall call, $0.PlayViewReq request);

  $async.Future<$0.PlayViewReply> playViewComic_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PlayViewReq> $request) async {
    return playViewComic($call, await $request);
  }

  $async.Future<$0.PlayViewReply> playViewComic(
      $grpc.ServiceCall call, $0.PlayViewReq request);
}
