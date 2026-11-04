// This is a generated file - do not edit.
//
// Generated from bilibili/app/view/v1/view.proto.

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

import 'view.pb.dart' as $0;

export 'view.pb.dart';

@$pb.GrpcServiceName('bilibili.app.view.v1.View')
class ViewClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ViewClient(super.channel, {super.options, super.interceptors});

  /// 视频页详情页
  $grpc.ResponseFuture<$0.ViewReply> view(
    $0.ViewReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$view, request, options: options);
  }

  $grpc.ResponseFuture<$0.ViewTagReply> viewTag(
    $0.ViewTagReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$viewTag, request, options: options);
  }

  $grpc.ResponseFuture<$0.ViewMaterialReply> viewMaterial(
    $0.ViewMaterialReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$viewMaterial, request, options: options);
  }

  /// 视频播放过程中的数据
  $grpc.ResponseFuture<$0.ViewProgressReply> viewProgress(
    $0.ViewProgressReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$viewProgress, request, options: options);
  }

  /// 短视频下载
  $grpc.ResponseFuture<$0.ShortFormVideoDownloadReply> shortFormVideoDownload(
    $0.ShortFormVideoDownloadReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$shortFormVideoDownload, request,
        options: options);
  }

  /// 点击播放器卡片事件
  $grpc.ResponseFuture<$0.NoReply> clickPlayerCard(
    $0.ClickPlayerCardReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clickPlayerCard, request, options: options);
  }

  /// 点击大型活动页预约
  $grpc.ResponseFuture<$0.NoReply> clickActivitySeason(
    $0.ClickActivitySeasonReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clickActivitySeason, request, options: options);
  }

  /// 合集详情页
  $grpc.ResponseFuture<$0.SeasonReply> season(
    $0.SeasonReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$season, request, options: options);
  }

  /// 播放器卡片曝光
  $grpc.ResponseFuture<$0.NoReply> exposePlayerCard(
    $0.ExposePlayerCardReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$exposePlayerCard, request, options: options);
  }

  /// 点击签订契约
  $grpc.ResponseFuture<$0.NoReply> addContract(
    $0.AddContractReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addContract, request, options: options);
  }

  /// 资源包
  $grpc.ResponseFuture<$0.Chronos> chronosPkg(
    $0.ChronosPkgReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$chronosPkg, request, options: options);
  }

  $grpc.ResponseFuture<$0.CacheViewReply> cacheView(
    $0.CacheViewReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cacheView, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContinuousPlayReply> continuousPlay(
    $0.ContinuousPlayReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$continuousPlay, request, options: options);
  }

  /// 播放页推荐IFS
  $grpc.ResponseFuture<$0.RelatesFeedReply> relatesFeed(
    $0.RelatesFeedReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$relatesFeed, request, options: options);
  }

  $grpc.ResponseFuture<$0.PremiereArchiveReply> premiereArchive(
    $0.PremiereArchiveReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$premiereArchive, request, options: options);
  }

  $grpc.ResponseFuture<$0.ReserveReply> reserve(
    $0.ReserveReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reserve, request, options: options);
  }

  $grpc.ResponseFuture<$0.PlayerRelatesReply> playerRelates(
    $0.PlayerRelatesReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$playerRelates, request, options: options);
  }

  $grpc.ResponseFuture<$0.SeasonActivityRecordReply> seasonActivityRecord(
    $0.SeasonActivityRecordReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$seasonActivityRecord, request, options: options);
  }

  $grpc.ResponseFuture<$0.SeasonWidgetExposeReply> seasonWidgetExpose(
    $0.SeasonWidgetExposeReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$seasonWidgetExpose, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetArcsPlayerReply> getArcsPlayer(
    $0.GetArcsPlayerReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getArcsPlayer, request, options: options);
  }

  // method descriptors

  static final _$view = $grpc.ClientMethod<$0.ViewReq, $0.ViewReply>(
      '/bilibili.app.view.v1.View/View',
      ($0.ViewReq value) => value.writeToBuffer(),
      $0.ViewReply.fromBuffer);
  static final _$viewTag = $grpc.ClientMethod<$0.ViewTagReq, $0.ViewTagReply>(
      '/bilibili.app.view.v1.View/ViewTag',
      ($0.ViewTagReq value) => value.writeToBuffer(),
      $0.ViewTagReply.fromBuffer);
  static final _$viewMaterial =
      $grpc.ClientMethod<$0.ViewMaterialReq, $0.ViewMaterialReply>(
          '/bilibili.app.view.v1.View/ViewMaterial',
          ($0.ViewMaterialReq value) => value.writeToBuffer(),
          $0.ViewMaterialReply.fromBuffer);
  static final _$viewProgress =
      $grpc.ClientMethod<$0.ViewProgressReq, $0.ViewProgressReply>(
          '/bilibili.app.view.v1.View/ViewProgress',
          ($0.ViewProgressReq value) => value.writeToBuffer(),
          $0.ViewProgressReply.fromBuffer);
  static final _$shortFormVideoDownload = $grpc.ClientMethod<
          $0.ShortFormVideoDownloadReq, $0.ShortFormVideoDownloadReply>(
      '/bilibili.app.view.v1.View/ShortFormVideoDownload',
      ($0.ShortFormVideoDownloadReq value) => value.writeToBuffer(),
      $0.ShortFormVideoDownloadReply.fromBuffer);
  static final _$clickPlayerCard =
      $grpc.ClientMethod<$0.ClickPlayerCardReq, $0.NoReply>(
          '/bilibili.app.view.v1.View/ClickPlayerCard',
          ($0.ClickPlayerCardReq value) => value.writeToBuffer(),
          $0.NoReply.fromBuffer);
  static final _$clickActivitySeason =
      $grpc.ClientMethod<$0.ClickActivitySeasonReq, $0.NoReply>(
          '/bilibili.app.view.v1.View/ClickActivitySeason',
          ($0.ClickActivitySeasonReq value) => value.writeToBuffer(),
          $0.NoReply.fromBuffer);
  static final _$season = $grpc.ClientMethod<$0.SeasonReq, $0.SeasonReply>(
      '/bilibili.app.view.v1.View/Season',
      ($0.SeasonReq value) => value.writeToBuffer(),
      $0.SeasonReply.fromBuffer);
  static final _$exposePlayerCard =
      $grpc.ClientMethod<$0.ExposePlayerCardReq, $0.NoReply>(
          '/bilibili.app.view.v1.View/ExposePlayerCard',
          ($0.ExposePlayerCardReq value) => value.writeToBuffer(),
          $0.NoReply.fromBuffer);
  static final _$addContract =
      $grpc.ClientMethod<$0.AddContractReq, $0.NoReply>(
          '/bilibili.app.view.v1.View/AddContract',
          ($0.AddContractReq value) => value.writeToBuffer(),
          $0.NoReply.fromBuffer);
  static final _$chronosPkg = $grpc.ClientMethod<$0.ChronosPkgReq, $0.Chronos>(
      '/bilibili.app.view.v1.View/ChronosPkg',
      ($0.ChronosPkgReq value) => value.writeToBuffer(),
      $0.Chronos.fromBuffer);
  static final _$cacheView =
      $grpc.ClientMethod<$0.CacheViewReq, $0.CacheViewReply>(
          '/bilibili.app.view.v1.View/CacheView',
          ($0.CacheViewReq value) => value.writeToBuffer(),
          $0.CacheViewReply.fromBuffer);
  static final _$continuousPlay =
      $grpc.ClientMethod<$0.ContinuousPlayReq, $0.ContinuousPlayReply>(
          '/bilibili.app.view.v1.View/ContinuousPlay',
          ($0.ContinuousPlayReq value) => value.writeToBuffer(),
          $0.ContinuousPlayReply.fromBuffer);
  static final _$relatesFeed =
      $grpc.ClientMethod<$0.RelatesFeedReq, $0.RelatesFeedReply>(
          '/bilibili.app.view.v1.View/RelatesFeed',
          ($0.RelatesFeedReq value) => value.writeToBuffer(),
          $0.RelatesFeedReply.fromBuffer);
  static final _$premiereArchive =
      $grpc.ClientMethod<$0.PremiereArchiveReq, $0.PremiereArchiveReply>(
          '/bilibili.app.view.v1.View/PremiereArchive',
          ($0.PremiereArchiveReq value) => value.writeToBuffer(),
          $0.PremiereArchiveReply.fromBuffer);
  static final _$reserve = $grpc.ClientMethod<$0.ReserveReq, $0.ReserveReply>(
      '/bilibili.app.view.v1.View/Reserve',
      ($0.ReserveReq value) => value.writeToBuffer(),
      $0.ReserveReply.fromBuffer);
  static final _$playerRelates =
      $grpc.ClientMethod<$0.PlayerRelatesReq, $0.PlayerRelatesReply>(
          '/bilibili.app.view.v1.View/PlayerRelates',
          ($0.PlayerRelatesReq value) => value.writeToBuffer(),
          $0.PlayerRelatesReply.fromBuffer);
  static final _$seasonActivityRecord = $grpc.ClientMethod<
          $0.SeasonActivityRecordReq, $0.SeasonActivityRecordReply>(
      '/bilibili.app.view.v1.View/SeasonActivityRecord',
      ($0.SeasonActivityRecordReq value) => value.writeToBuffer(),
      $0.SeasonActivityRecordReply.fromBuffer);
  static final _$seasonWidgetExpose =
      $grpc.ClientMethod<$0.SeasonWidgetExposeReq, $0.SeasonWidgetExposeReply>(
          '/bilibili.app.view.v1.View/SeasonWidgetExpose',
          ($0.SeasonWidgetExposeReq value) => value.writeToBuffer(),
          $0.SeasonWidgetExposeReply.fromBuffer);
  static final _$getArcsPlayer =
      $grpc.ClientMethod<$0.GetArcsPlayerReq, $0.GetArcsPlayerReply>(
          '/bilibili.app.view.v1.View/GetArcsPlayer',
          ($0.GetArcsPlayerReq value) => value.writeToBuffer(),
          $0.GetArcsPlayerReply.fromBuffer);
}

@$pb.GrpcServiceName('bilibili.app.view.v1.View')
abstract class ViewServiceBase extends $grpc.Service {
  $core.String get $name => 'bilibili.app.view.v1.View';

  ViewServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ViewReq, $0.ViewReply>(
        'View',
        view_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ViewReq.fromBuffer(value),
        ($0.ViewReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ViewTagReq, $0.ViewTagReply>(
        'ViewTag',
        viewTag_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ViewTagReq.fromBuffer(value),
        ($0.ViewTagReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ViewMaterialReq, $0.ViewMaterialReply>(
        'ViewMaterial',
        viewMaterial_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ViewMaterialReq.fromBuffer(value),
        ($0.ViewMaterialReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ViewProgressReq, $0.ViewProgressReply>(
        'ViewProgress',
        viewProgress_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ViewProgressReq.fromBuffer(value),
        ($0.ViewProgressReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ShortFormVideoDownloadReq,
            $0.ShortFormVideoDownloadReply>(
        'ShortFormVideoDownload',
        shortFormVideoDownload_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ShortFormVideoDownloadReq.fromBuffer(value),
        ($0.ShortFormVideoDownloadReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClickPlayerCardReq, $0.NoReply>(
        'ClickPlayerCard',
        clickPlayerCard_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClickPlayerCardReq.fromBuffer(value),
        ($0.NoReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClickActivitySeasonReq, $0.NoReply>(
        'ClickActivitySeason',
        clickActivitySeason_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClickActivitySeasonReq.fromBuffer(value),
        ($0.NoReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SeasonReq, $0.SeasonReply>(
        'Season',
        season_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SeasonReq.fromBuffer(value),
        ($0.SeasonReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ExposePlayerCardReq, $0.NoReply>(
        'ExposePlayerCard',
        exposePlayerCard_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ExposePlayerCardReq.fromBuffer(value),
        ($0.NoReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AddContractReq, $0.NoReply>(
        'AddContract',
        addContract_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AddContractReq.fromBuffer(value),
        ($0.NoReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ChronosPkgReq, $0.Chronos>(
        'ChronosPkg',
        chronosPkg_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ChronosPkgReq.fromBuffer(value),
        ($0.Chronos value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CacheViewReq, $0.CacheViewReply>(
        'CacheView',
        cacheView_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CacheViewReq.fromBuffer(value),
        ($0.CacheViewReply value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ContinuousPlayReq, $0.ContinuousPlayReply>(
            'ContinuousPlay',
            continuousPlay_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ContinuousPlayReq.fromBuffer(value),
            ($0.ContinuousPlayReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RelatesFeedReq, $0.RelatesFeedReply>(
        'RelatesFeed',
        relatesFeed_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RelatesFeedReq.fromBuffer(value),
        ($0.RelatesFeedReply value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.PremiereArchiveReq, $0.PremiereArchiveReply>(
            'PremiereArchive',
            premiereArchive_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.PremiereArchiveReq.fromBuffer(value),
            ($0.PremiereArchiveReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReserveReq, $0.ReserveReply>(
        'Reserve',
        reserve_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ReserveReq.fromBuffer(value),
        ($0.ReserveReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PlayerRelatesReq, $0.PlayerRelatesReply>(
        'PlayerRelates',
        playerRelates_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PlayerRelatesReq.fromBuffer(value),
        ($0.PlayerRelatesReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SeasonActivityRecordReq,
            $0.SeasonActivityRecordReply>(
        'SeasonActivityRecord',
        seasonActivityRecord_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SeasonActivityRecordReq.fromBuffer(value),
        ($0.SeasonActivityRecordReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SeasonWidgetExposeReq,
            $0.SeasonWidgetExposeReply>(
        'SeasonWidgetExpose',
        seasonWidgetExpose_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SeasonWidgetExposeReq.fromBuffer(value),
        ($0.SeasonWidgetExposeReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetArcsPlayerReq, $0.GetArcsPlayerReply>(
        'GetArcsPlayer',
        getArcsPlayer_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetArcsPlayerReq.fromBuffer(value),
        ($0.GetArcsPlayerReply value) => value.writeToBuffer()));
  }

  $async.Future<$0.ViewReply> view_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ViewReq> $request) async {
    return view($call, await $request);
  }

  $async.Future<$0.ViewReply> view($grpc.ServiceCall call, $0.ViewReq request);

  $async.Future<$0.ViewTagReply> viewTag_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ViewTagReq> $request) async {
    return viewTag($call, await $request);
  }

  $async.Future<$0.ViewTagReply> viewTag(
      $grpc.ServiceCall call, $0.ViewTagReq request);

  $async.Future<$0.ViewMaterialReply> viewMaterial_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ViewMaterialReq> $request) async {
    return viewMaterial($call, await $request);
  }

  $async.Future<$0.ViewMaterialReply> viewMaterial(
      $grpc.ServiceCall call, $0.ViewMaterialReq request);

  $async.Future<$0.ViewProgressReply> viewProgress_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ViewProgressReq> $request) async {
    return viewProgress($call, await $request);
  }

  $async.Future<$0.ViewProgressReply> viewProgress(
      $grpc.ServiceCall call, $0.ViewProgressReq request);

  $async.Future<$0.ShortFormVideoDownloadReply> shortFormVideoDownload_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ShortFormVideoDownloadReq> $request) async {
    return shortFormVideoDownload($call, await $request);
  }

  $async.Future<$0.ShortFormVideoDownloadReply> shortFormVideoDownload(
      $grpc.ServiceCall call, $0.ShortFormVideoDownloadReq request);

  $async.Future<$0.NoReply> clickPlayerCard_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClickPlayerCardReq> $request) async {
    return clickPlayerCard($call, await $request);
  }

  $async.Future<$0.NoReply> clickPlayerCard(
      $grpc.ServiceCall call, $0.ClickPlayerCardReq request);

  $async.Future<$0.NoReply> clickActivitySeason_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClickActivitySeasonReq> $request) async {
    return clickActivitySeason($call, await $request);
  }

  $async.Future<$0.NoReply> clickActivitySeason(
      $grpc.ServiceCall call, $0.ClickActivitySeasonReq request);

  $async.Future<$0.SeasonReply> season_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.SeasonReq> $request) async {
    return season($call, await $request);
  }

  $async.Future<$0.SeasonReply> season(
      $grpc.ServiceCall call, $0.SeasonReq request);

  $async.Future<$0.NoReply> exposePlayerCard_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ExposePlayerCardReq> $request) async {
    return exposePlayerCard($call, await $request);
  }

  $async.Future<$0.NoReply> exposePlayerCard(
      $grpc.ServiceCall call, $0.ExposePlayerCardReq request);

  $async.Future<$0.NoReply> addContract_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AddContractReq> $request) async {
    return addContract($call, await $request);
  }

  $async.Future<$0.NoReply> addContract(
      $grpc.ServiceCall call, $0.AddContractReq request);

  $async.Future<$0.Chronos> chronosPkg_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ChronosPkgReq> $request) async {
    return chronosPkg($call, await $request);
  }

  $async.Future<$0.Chronos> chronosPkg(
      $grpc.ServiceCall call, $0.ChronosPkgReq request);

  $async.Future<$0.CacheViewReply> cacheView_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.CacheViewReq> $request) async {
    return cacheView($call, await $request);
  }

  $async.Future<$0.CacheViewReply> cacheView(
      $grpc.ServiceCall call, $0.CacheViewReq request);

  $async.Future<$0.ContinuousPlayReply> continuousPlay_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ContinuousPlayReq> $request) async {
    return continuousPlay($call, await $request);
  }

  $async.Future<$0.ContinuousPlayReply> continuousPlay(
      $grpc.ServiceCall call, $0.ContinuousPlayReq request);

  $async.Future<$0.RelatesFeedReply> relatesFeed_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RelatesFeedReq> $request) async {
    return relatesFeed($call, await $request);
  }

  $async.Future<$0.RelatesFeedReply> relatesFeed(
      $grpc.ServiceCall call, $0.RelatesFeedReq request);

  $async.Future<$0.PremiereArchiveReply> premiereArchive_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.PremiereArchiveReq> $request) async {
    return premiereArchive($call, await $request);
  }

  $async.Future<$0.PremiereArchiveReply> premiereArchive(
      $grpc.ServiceCall call, $0.PremiereArchiveReq request);

  $async.Future<$0.ReserveReply> reserve_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ReserveReq> $request) async {
    return reserve($call, await $request);
  }

  $async.Future<$0.ReserveReply> reserve(
      $grpc.ServiceCall call, $0.ReserveReq request);

  $async.Future<$0.PlayerRelatesReply> playerRelates_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.PlayerRelatesReq> $request) async {
    return playerRelates($call, await $request);
  }

  $async.Future<$0.PlayerRelatesReply> playerRelates(
      $grpc.ServiceCall call, $0.PlayerRelatesReq request);

  $async.Future<$0.SeasonActivityRecordReply> seasonActivityRecord_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SeasonActivityRecordReq> $request) async {
    return seasonActivityRecord($call, await $request);
  }

  $async.Future<$0.SeasonActivityRecordReply> seasonActivityRecord(
      $grpc.ServiceCall call, $0.SeasonActivityRecordReq request);

  $async.Future<$0.SeasonWidgetExposeReply> seasonWidgetExpose_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SeasonWidgetExposeReq> $request) async {
    return seasonWidgetExpose($call, await $request);
  }

  $async.Future<$0.SeasonWidgetExposeReply> seasonWidgetExpose(
      $grpc.ServiceCall call, $0.SeasonWidgetExposeReq request);

  $async.Future<$0.GetArcsPlayerReply> getArcsPlayer_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetArcsPlayerReq> $request) async {
    return getArcsPlayer($call, await $request);
  }

  $async.Future<$0.GetArcsPlayerReply> getArcsPlayer(
      $grpc.ServiceCall call, $0.GetArcsPlayerReq request);
}
