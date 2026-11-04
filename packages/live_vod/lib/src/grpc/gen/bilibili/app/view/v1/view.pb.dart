// This is a generated file - do not edit.
//
// Generated from bilibili/app/view/v1/view.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart' as $2;

import '../../../pagination/pagination.pb.dart' as $4;
import '../../archive/middleware/v1/preload.pb.dart' as $3;
import '../../archive/v1/archive.pb.dart' as $1;
import 'view.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'view.pbenum.dart';

/// 活动页资源包
class ActivityResource extends $pb.GeneratedMessage {
  factory ActivityResource({
    $core.String? modPoolName,
    $core.String? modResourceName,
    $core.String? bgColor,
    $core.String? selectedBgColor,
    $core.String? textColor,
    $core.String? lightTextColor,
    $core.String? darkTextColor,
    $core.String? dividerColor,
  }) {
    final result = ActivityResource._();
    if (modPoolName != null) result.modPoolName = modPoolName;
    if (modResourceName != null) result.modResourceName = modResourceName;
    if (bgColor != null) result.bgColor = bgColor;
    if (selectedBgColor != null) result.selectedBgColor = selectedBgColor;
    if (textColor != null) result.textColor = textColor;
    if (lightTextColor != null) result.lightTextColor = lightTextColor;
    if (darkTextColor != null) result.darkTextColor = darkTextColor;
    if (dividerColor != null) result.dividerColor = dividerColor;
    return result;
  }

  ActivityResource._();

  factory ActivityResource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ActivityResource()..mergeFromBuffer(data, registry);
  factory ActivityResource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ActivityResource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivityResource',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ActivityResource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'modPoolName')
    ..aOS(2, _omitFieldNames ? '' : 'modResourceName')
    ..aOS(3, _omitFieldNames ? '' : 'bgColor')
    ..aOS(4, _omitFieldNames ? '' : 'selectedBgColor')
    ..aOS(5, _omitFieldNames ? '' : 'textColor')
    ..aOS(6, _omitFieldNames ? '' : 'lightTextColor')
    ..aOS(7, _omitFieldNames ? '' : 'darkTextColor')
    ..aOS(8, _omitFieldNames ? '' : 'dividerColor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityResource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivityResource copyWith(void Function(ActivityResource) updates) =>
      super.copyWith((message) => updates(message as ActivityResource))
          as ActivityResource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ActivityResource() / ActivityResource.new instead')
  static ActivityResource create() => ActivityResource._();
  static $pb.GeneratedMessage $_createMessage() => ActivityResource._();
  @$core.override
  ActivityResource createEmptyInstance() => ActivityResource._();
  @$core.pragma('dart2js:noInline')
  static ActivityResource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ActivityResource>(
          ActivityResource.$_createMessage);
  static ActivityResource? _defaultInstance;

  /// mod资源池名称
  @$pb.TagNumber(1)
  $core.String get modPoolName => $_getSZ(0);
  @$pb.TagNumber(1)
  set modPoolName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModPoolName() => $_has(0);
  @$pb.TagNumber(1)
  void clearModPoolName() => $_clearField(1);

  /// mod资源名称
  @$pb.TagNumber(2)
  $core.String get modResourceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set modResourceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModResourceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearModResourceName() => $_clearField(2);

  /// 背景色
  @$pb.TagNumber(3)
  $core.String get bgColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set bgColor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBgColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearBgColor() => $_clearField(3);

  /// 选中背景色
  @$pb.TagNumber(4)
  $core.String get selectedBgColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set selectedBgColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSelectedBgColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearSelectedBgColor() => $_clearField(4);

  /// 文字颜色
  @$pb.TagNumber(5)
  $core.String get textColor => $_getSZ(4);
  @$pb.TagNumber(5)
  set textColor($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTextColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextColor() => $_clearField(5);

  /// 浅字色
  @$pb.TagNumber(6)
  $core.String get lightTextColor => $_getSZ(5);
  @$pb.TagNumber(6)
  set lightTextColor($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLightTextColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearLightTextColor() => $_clearField(6);

  /// 深字色
  @$pb.TagNumber(7)
  $core.String get darkTextColor => $_getSZ(6);
  @$pb.TagNumber(7)
  set darkTextColor($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDarkTextColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearDarkTextColor() => $_clearField(7);

  /// 分割线色
  @$pb.TagNumber(8)
  $core.String get dividerColor => $_getSZ(7);
  @$pb.TagNumber(8)
  set dividerColor($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDividerColor() => $_has(7);
  @$pb.TagNumber(8)
  void clearDividerColor() => $_clearField(8);
}

/// 大型活动合集
class ActivitySeason extends $pb.GeneratedMessage {
  factory ActivitySeason({
    $1.Arc? arc,
    $core.Iterable<ViewPage>? pages,
    OnwerExt? ownerExt,
    ReqUser? reqUser,
    ElecRank? elecRank,
    History? history,
    $core.String? bvid,
    Honor? honor,
    $core.Iterable<Staff>? staff,
    UgcSeason? ugcSeason,
    Tab? tab,
    Rank? rank,
    Order? order,
    $core.bool? supportDislike,
    OperationRelate? operationRelate,
    ActivityResource? activityResource,
    $core.String? shortLink,
    Label? label,
    Dislike? dislike,
    PlayerIcon? playerIcon,
    $core.String? shareSubtitle,
    CMConfig? cmConfig,
    TFPanelCustomized? tfPanelCustomized,
    $core.String? argueMsg,
    ECode? ecode,
    CustomConfig? customConfig,
    $core.String? badgeUrl,
    $core.Iterable<DescV2>? descV2,
    Config? config,
    Online? online,
    ArcExtra? arcExtra,
    ReplyStyle? replyPreface,
  }) {
    final result = ActivitySeason._();
    if (arc != null) result.arc = arc;
    if (pages != null) result.pages.addAll(pages);
    if (ownerExt != null) result.ownerExt = ownerExt;
    if (reqUser != null) result.reqUser = reqUser;
    if (elecRank != null) result.elecRank = elecRank;
    if (history != null) result.history = history;
    if (bvid != null) result.bvid = bvid;
    if (honor != null) result.honor = honor;
    if (staff != null) result.staff.addAll(staff);
    if (ugcSeason != null) result.ugcSeason = ugcSeason;
    if (tab != null) result.tab = tab;
    if (rank != null) result.rank = rank;
    if (order != null) result.order = order;
    if (supportDislike != null) result.supportDislike = supportDislike;
    if (operationRelate != null) result.operationRelate = operationRelate;
    if (activityResource != null) result.activityResource = activityResource;
    if (shortLink != null) result.shortLink = shortLink;
    if (label != null) result.label = label;
    if (dislike != null) result.dislike = dislike;
    if (playerIcon != null) result.playerIcon = playerIcon;
    if (shareSubtitle != null) result.shareSubtitle = shareSubtitle;
    if (cmConfig != null) result.cmConfig = cmConfig;
    if (tfPanelCustomized != null) result.tfPanelCustomized = tfPanelCustomized;
    if (argueMsg != null) result.argueMsg = argueMsg;
    if (ecode != null) result.ecode = ecode;
    if (customConfig != null) result.customConfig = customConfig;
    if (badgeUrl != null) result.badgeUrl = badgeUrl;
    if (descV2 != null) result.descV2.addAll(descV2);
    if (config != null) result.config = config;
    if (online != null) result.online = online;
    if (arcExtra != null) result.arcExtra = arcExtra;
    if (replyPreface != null) result.replyPreface = replyPreface;
    return result;
  }

  ActivitySeason._();

  factory ActivitySeason.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ActivitySeason()..mergeFromBuffer(data, registry);
  factory ActivitySeason.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ActivitySeason()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActivitySeason',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ActivitySeason.$_createMessage)
    ..aOM<$1.Arc>(1, _omitFieldNames ? '' : 'arc',
        subBuilder: $1.Arc.$_createMessage)
    ..pPM<ViewPage>(2, _omitFieldNames ? '' : 'pages',
        subBuilder: ViewPage.$_createMessage)
    ..aOM<OnwerExt>(3, _omitFieldNames ? '' : 'ownerExt',
        subBuilder: OnwerExt.$_createMessage)
    ..aOM<ReqUser>(4, _omitFieldNames ? '' : 'reqUser',
        subBuilder: ReqUser.$_createMessage)
    ..aOM<ElecRank>(5, _omitFieldNames ? '' : 'elecRank',
        subBuilder: ElecRank.$_createMessage)
    ..aOM<History>(6, _omitFieldNames ? '' : 'history',
        subBuilder: History.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'bvid')
    ..aOM<Honor>(8, _omitFieldNames ? '' : 'honor',
        subBuilder: Honor.$_createMessage)
    ..pPM<Staff>(9, _omitFieldNames ? '' : 'staff',
        subBuilder: Staff.$_createMessage)
    ..aOM<UgcSeason>(10, _omitFieldNames ? '' : 'ugcSeason',
        subBuilder: UgcSeason.$_createMessage)
    ..aOM<Tab>(11, _omitFieldNames ? '' : 'tab',
        subBuilder: Tab.$_createMessage)
    ..aOM<Rank>(12, _omitFieldNames ? '' : 'rank',
        subBuilder: Rank.$_createMessage)
    ..aOM<Order>(13, _omitFieldNames ? '' : 'order',
        subBuilder: Order.$_createMessage)
    ..aOB(14, _omitFieldNames ? '' : 'supportDislike')
    ..aOM<OperationRelate>(15, _omitFieldNames ? '' : 'operationRelate',
        subBuilder: OperationRelate.$_createMessage)
    ..aOM<ActivityResource>(16, _omitFieldNames ? '' : 'activityResource',
        subBuilder: ActivityResource.$_createMessage)
    ..aOS(17, _omitFieldNames ? '' : 'shortLink')
    ..aOM<Label>(18, _omitFieldNames ? '' : 'label',
        subBuilder: Label.$_createMessage)
    ..aOM<Dislike>(19, _omitFieldNames ? '' : 'dislike',
        subBuilder: Dislike.$_createMessage)
    ..aOM<PlayerIcon>(20, _omitFieldNames ? '' : 'playerIcon',
        subBuilder: PlayerIcon.$_createMessage)
    ..aOS(21, _omitFieldNames ? '' : 'shareSubtitle')
    ..aOM<CMConfig>(22, _omitFieldNames ? '' : 'cmConfig',
        subBuilder: CMConfig.$_createMessage)
    ..aOM<TFPanelCustomized>(23, _omitFieldNames ? '' : 'tfPanelCustomized',
        subBuilder: TFPanelCustomized.$_createMessage)
    ..aOS(24, _omitFieldNames ? '' : 'argueMsg')
    ..aE<ECode>(25, _omitFieldNames ? '' : 'ecode', enumValues: ECode.values)
    ..aOM<CustomConfig>(26, _omitFieldNames ? '' : 'customConfig',
        subBuilder: CustomConfig.$_createMessage)
    ..aOS(27, _omitFieldNames ? '' : 'badgeUrl')
    ..pPM<DescV2>(28, _omitFieldNames ? '' : 'descV2',
        subBuilder: DescV2.$_createMessage)
    ..aOM<Config>(29, _omitFieldNames ? '' : 'config',
        subBuilder: Config.$_createMessage)
    ..aOM<Online>(30, _omitFieldNames ? '' : 'online',
        subBuilder: Online.$_createMessage)
    ..aOM<ArcExtra>(31, _omitFieldNames ? '' : 'arcExtra',
        subBuilder: ArcExtra.$_createMessage)
    ..aOM<ReplyStyle>(32, _omitFieldNames ? '' : 'replyPreface',
        subBuilder: ReplyStyle.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivitySeason clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActivitySeason copyWith(void Function(ActivitySeason) updates) =>
      super.copyWith((message) => updates(message as ActivitySeason))
          as ActivitySeason;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ActivitySeason() / ActivitySeason.new instead')
  static ActivitySeason create() => ActivitySeason._();
  static $pb.GeneratedMessage $_createMessage() => ActivitySeason._();
  @$core.override
  ActivitySeason createEmptyInstance() => ActivitySeason._();
  @$core.pragma('dart2js:noInline')
  static ActivitySeason getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ActivitySeason>(
          ActivitySeason.$_createMessage);
  static ActivitySeason? _defaultInstance;

  /// 稿件信息
  @$pb.TagNumber(1)
  $1.Arc get arc => $_getN(0);
  @$pb.TagNumber(1)
  set arc($1.Arc value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasArc() => $_has(0);
  @$pb.TagNumber(1)
  void clearArc() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Arc ensureArc() => $_ensure(0);

  /// 分P信息
  @$pb.TagNumber(2)
  $pb.PbList<ViewPage> get pages => $_getList(1);

  /// ("OnwerExt"为源码中拼写错误)
  @$pb.TagNumber(3)
  OnwerExt get ownerExt => $_getN(2);
  @$pb.TagNumber(3)
  set ownerExt(OnwerExt value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOwnerExt() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwnerExt() => $_clearField(3);
  @$pb.TagNumber(3)
  OnwerExt ensureOwnerExt() => $_ensure(2);

  /// 稿件用户操作状态
  @$pb.TagNumber(4)
  ReqUser get reqUser => $_getN(3);
  @$pb.TagNumber(4)
  set reqUser(ReqUser value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReqUser() => $_has(3);
  @$pb.TagNumber(4)
  void clearReqUser() => $_clearField(4);
  @$pb.TagNumber(4)
  ReqUser ensureReqUser() => $_ensure(3);

  /// 充电排行
  @$pb.TagNumber(5)
  ElecRank get elecRank => $_getN(4);
  @$pb.TagNumber(5)
  set elecRank(ElecRank value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasElecRank() => $_has(4);
  @$pb.TagNumber(5)
  void clearElecRank() => $_clearField(5);
  @$pb.TagNumber(5)
  ElecRank ensureElecRank() => $_ensure(4);

  /// 历史观看进度
  @$pb.TagNumber(6)
  History get history => $_getN(5);
  @$pb.TagNumber(6)
  set history(History value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasHistory() => $_has(5);
  @$pb.TagNumber(6)
  void clearHistory() => $_clearField(6);
  @$pb.TagNumber(6)
  History ensureHistory() => $_ensure(5);

  /// 稿件bvid
  @$pb.TagNumber(7)
  $core.String get bvid => $_getSZ(6);
  @$pb.TagNumber(7)
  set bvid($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBvid() => $_has(6);
  @$pb.TagNumber(7)
  void clearBvid() => $_clearField(7);

  /// 获得荣誉信息
  @$pb.TagNumber(8)
  Honor get honor => $_getN(7);
  @$pb.TagNumber(8)
  set honor(Honor value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasHonor() => $_has(7);
  @$pb.TagNumber(8)
  void clearHonor() => $_clearField(8);
  @$pb.TagNumber(8)
  Honor ensureHonor() => $_ensure(7);

  /// 联合投稿成员列表
  @$pb.TagNumber(9)
  $pb.PbList<Staff> get staff => $_getList(8);

  /// UGC视频合集信息
  @$pb.TagNumber(10)
  UgcSeason get ugcSeason => $_getN(9);
  @$pb.TagNumber(10)
  set ugcSeason(UgcSeason value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasUgcSeason() => $_has(9);
  @$pb.TagNumber(10)
  void clearUgcSeason() => $_clearField(10);
  @$pb.TagNumber(10)
  UgcSeason ensureUgcSeason() => $_ensure(9);

  /// 播放页定制tab
  @$pb.TagNumber(11)
  Tab get tab => $_getN(10);
  @$pb.TagNumber(11)
  set tab(Tab value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasTab() => $_has(10);
  @$pb.TagNumber(11)
  void clearTab() => $_clearField(11);
  @$pb.TagNumber(11)
  Tab ensureTab() => $_ensure(10);

  /// 排行榜
  @$pb.TagNumber(12)
  Rank get rank => $_getN(11);
  @$pb.TagNumber(12)
  set rank(Rank value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasRank() => $_has(11);
  @$pb.TagNumber(12)
  void clearRank() => $_clearField(12);
  @$pb.TagNumber(12)
  Rank ensureRank() => $_ensure(11);

  /// 预约模块
  @$pb.TagNumber(13)
  Order get order => $_getN(12);
  @$pb.TagNumber(13)
  set order(Order value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasOrder() => $_has(12);
  @$pb.TagNumber(13)
  void clearOrder() => $_clearField(13);
  @$pb.TagNumber(13)
  Order ensureOrder() => $_ensure(12);

  /// 是否支持点踩
  @$pb.TagNumber(14)
  $core.bool get supportDislike => $_getBF(13);
  @$pb.TagNumber(14)
  set supportDislike($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSupportDislike() => $_has(13);
  @$pb.TagNumber(14)
  void clearSupportDislike() => $_clearField(14);

  /// 相关推荐(运营配置+AI推荐)
  @$pb.TagNumber(15)
  OperationRelate get operationRelate => $_getN(14);
  @$pb.TagNumber(15)
  set operationRelate(OperationRelate value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasOperationRelate() => $_has(14);
  @$pb.TagNumber(15)
  void clearOperationRelate() => $_clearField(15);
  @$pb.TagNumber(15)
  OperationRelate ensureOperationRelate() => $_ensure(14);

  /// 活动页资源包
  @$pb.TagNumber(16)
  ActivityResource get activityResource => $_getN(15);
  @$pb.TagNumber(16)
  set activityResource(ActivityResource value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasActivityResource() => $_has(15);
  @$pb.TagNumber(16)
  void clearActivityResource() => $_clearField(16);
  @$pb.TagNumber(16)
  ActivityResource ensureActivityResource() => $_ensure(15);

  /// 短链接
  @$pb.TagNumber(17)
  $core.String get shortLink => $_getSZ(16);
  @$pb.TagNumber(17)
  set shortLink($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasShortLink() => $_has(16);
  @$pb.TagNumber(17)
  void clearShortLink() => $_clearField(17);

  /// 标签
  @$pb.TagNumber(18)
  Label get label => $_getN(17);
  @$pb.TagNumber(18)
  set label(Label value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasLabel() => $_has(17);
  @$pb.TagNumber(18)
  void clearLabel() => $_clearField(18);
  @$pb.TagNumber(18)
  Label ensureLabel() => $_ensure(17);

  /// 不感兴趣原因
  @$pb.TagNumber(19)
  Dislike get dislike => $_getN(18);
  @$pb.TagNumber(19)
  set dislike(Dislike value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasDislike() => $_has(18);
  @$pb.TagNumber(19)
  void clearDislike() => $_clearField(19);
  @$pb.TagNumber(19)
  Dislike ensureDislike() => $_ensure(18);

  /// 播放图标动画配置档
  @$pb.TagNumber(20)
  PlayerIcon get playerIcon => $_getN(19);
  @$pb.TagNumber(20)
  set playerIcon(PlayerIcon value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasPlayerIcon() => $_has(19);
  @$pb.TagNumber(20)
  void clearPlayerIcon() => $_clearField(20);
  @$pb.TagNumber(20)
  PlayerIcon ensurePlayerIcon() => $_ensure(19);

  /// 分享副标题(已观看xxx次)
  @$pb.TagNumber(21)
  $core.String get shareSubtitle => $_getSZ(20);
  @$pb.TagNumber(21)
  set shareSubtitle($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasShareSubtitle() => $_has(20);
  @$pb.TagNumber(21)
  void clearShareSubtitle() => $_clearField(21);

  /// 广告配置
  @$pb.TagNumber(22)
  CMConfig get cmConfig => $_getN(21);
  @$pb.TagNumber(22)
  set cmConfig(CMConfig value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasCmConfig() => $_has(21);
  @$pb.TagNumber(22)
  void clearCmConfig() => $_clearField(22);
  @$pb.TagNumber(22)
  CMConfig ensureCmConfig() => $_ensure(21);

  /// 免流面板定制
  @$pb.TagNumber(23)
  TFPanelCustomized get tfPanelCustomized => $_getN(22);
  @$pb.TagNumber(23)
  set tfPanelCustomized(TFPanelCustomized value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasTfPanelCustomized() => $_has(22);
  @$pb.TagNumber(23)
  void clearTfPanelCustomized() => $_clearField(23);
  @$pb.TagNumber(23)
  TFPanelCustomized ensureTfPanelCustomized() => $_ensure(22);

  /// 争议信息
  @$pb.TagNumber(24)
  $core.String get argueMsg => $_getSZ(23);
  @$pb.TagNumber(24)
  set argueMsg($core.String value) => $_setString(23, value);
  @$pb.TagNumber(24)
  $core.bool hasArgueMsg() => $_has(23);
  @$pb.TagNumber(24)
  void clearArgueMsg() => $_clearField(24);

  /// 错误码
  /// DEFAULT:正常 CODE404:视频被UP主删除
  @$pb.TagNumber(25)
  ECode get ecode => $_getN(24);
  @$pb.TagNumber(25)
  set ecode(ECode value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasEcode() => $_has(24);
  @$pb.TagNumber(25)
  void clearEcode() => $_clearField(25);

  /// 404页信息
  @$pb.TagNumber(26)
  CustomConfig get customConfig => $_getN(25);
  @$pb.TagNumber(26)
  set customConfig(CustomConfig value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasCustomConfig() => $_has(25);
  @$pb.TagNumber(26)
  void clearCustomConfig() => $_clearField(26);
  @$pb.TagNumber(26)
  CustomConfig ensureCustomConfig() => $_ensure(25);

  /// 评论样式
  @$pb.TagNumber(27)
  $core.String get badgeUrl => $_getSZ(26);
  @$pb.TagNumber(27)
  set badgeUrl($core.String value) => $_setString(26, value);
  @$pb.TagNumber(27)
  $core.bool hasBadgeUrl() => $_has(26);
  @$pb.TagNumber(27)
  void clearBadgeUrl() => $_clearField(27);

  /// 稿件简介v2
  @$pb.TagNumber(28)
  $pb.PbList<DescV2> get descV2 => $_getList(27);

  @$pb.TagNumber(29)
  Config get config => $_getN(28);
  @$pb.TagNumber(29)
  set config(Config value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasConfig() => $_has(28);
  @$pb.TagNumber(29)
  void clearConfig() => $_clearField(29);
  @$pb.TagNumber(29)
  Config ensureConfig() => $_ensure(28);

  @$pb.TagNumber(30)
  Online get online => $_getN(29);
  @$pb.TagNumber(30)
  set online(Online value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasOnline() => $_has(29);
  @$pb.TagNumber(30)
  void clearOnline() => $_clearField(30);
  @$pb.TagNumber(30)
  Online ensureOnline() => $_ensure(29);

  @$pb.TagNumber(31)
  ArcExtra get arcExtra => $_getN(30);
  @$pb.TagNumber(31)
  set arcExtra(ArcExtra value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasArcExtra() => $_has(30);
  @$pb.TagNumber(31)
  void clearArcExtra() => $_clearField(31);
  @$pb.TagNumber(31)
  ArcExtra ensureArcExtra() => $_ensure(30);

  @$pb.TagNumber(32)
  ReplyStyle get replyPreface => $_getN(31);
  @$pb.TagNumber(32)
  set replyPreface(ReplyStyle value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasReplyPreface() => $_has(31);
  @$pb.TagNumber(32)
  void clearReplyPreface() => $_clearField(32);
  @$pb.TagNumber(32)
  ReplyStyle ensureReplyPreface() => $_ensure(31);
}

/// 点击签订契约-请求
class AddContractReq extends $pb.GeneratedMessage {
  factory AddContractReq({
    $fixnum.Int64? aid,
    $fixnum.Int64? upMid,
    $core.String? spmid,
  }) {
    final result = AddContractReq._();
    if (aid != null) result.aid = aid;
    if (upMid != null) result.upMid = upMid;
    if (spmid != null) result.spmid = spmid;
    return result;
  }

  AddContractReq._();

  factory AddContractReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddContractReq()..mergeFromBuffer(data, registry);
  factory AddContractReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddContractReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddContractReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: AddContractReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aInt64(2, _omitFieldNames ? '' : 'upMid')
    ..aOS(3, _omitFieldNames ? '' : 'spmid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddContractReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddContractReq copyWith(void Function(AddContractReq) updates) =>
      super.copyWith((message) => updates(message as AddContractReq))
          as AddContractReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AddContractReq() / AddContractReq.new instead')
  static AddContractReq create() => AddContractReq._();
  static $pb.GeneratedMessage $_createMessage() => AddContractReq._();
  @$core.override
  AddContractReq createEmptyInstance() => AddContractReq._();
  @$core.pragma('dart2js:noInline')
  static AddContractReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddContractReq>(
          AddContractReq.$_createMessage);
  static AddContractReq? _defaultInstance;

  /// 稿件avid
  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  /// UP主mid
  @$pb.TagNumber(2)
  $fixnum.Int64 get upMid => $_getI64(1);
  @$pb.TagNumber(2)
  set upMid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUpMid() => $_has(1);
  @$pb.TagNumber(2)
  void clearUpMid() => $_clearField(2);

  /// 当前页面spm
  @$pb.TagNumber(3)
  $core.String get spmid => $_getSZ(2);
  @$pb.TagNumber(3)
  set spmid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSpmid() => $_has(2);
  @$pb.TagNumber(3)
  void clearSpmid() => $_clearField(3);
}

class AdInfo extends $pb.GeneratedMessage {
  factory AdInfo({
    $fixnum.Int64? creativeId,
    $fixnum.Int64? creativeType,
    CreativeContent? creativeContent,
    $core.String? adCb,
    $core.int? cardType,
    $core.List<$core.int>? extra,
  }) {
    final result = AdInfo._();
    if (creativeId != null) result.creativeId = creativeId;
    if (creativeType != null) result.creativeType = creativeType;
    if (creativeContent != null) result.creativeContent = creativeContent;
    if (adCb != null) result.adCb = adCb;
    if (cardType != null) result.cardType = cardType;
    if (extra != null) result.extra = extra;
    return result;
  }

  AdInfo._();

  factory AdInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AdInfo()..mergeFromBuffer(data, registry);
  factory AdInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AdInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: AdInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'creativeId')
    ..aInt64(2, _omitFieldNames ? '' : 'creativeType')
    ..aOM<CreativeContent>(3, _omitFieldNames ? '' : 'creativeContent',
        subBuilder: CreativeContent.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'adCb')
    ..aI(5, _omitFieldNames ? '' : 'cardType')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'extra', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdInfo copyWith(void Function(AdInfo) updates) =>
      super.copyWith((message) => updates(message as AdInfo)) as AdInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AdInfo() / AdInfo.new instead')
  static AdInfo create() => AdInfo._();
  static $pb.GeneratedMessage $_createMessage() => AdInfo._();
  @$core.override
  AdInfo createEmptyInstance() => AdInfo._();
  @$core.pragma('dart2js:noInline')
  static AdInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdInfo>(AdInfo.$_createMessage);
  static AdInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get creativeId => $_getI64(0);
  @$pb.TagNumber(1)
  set creativeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCreativeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCreativeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get creativeType => $_getI64(1);
  @$pb.TagNumber(2)
  set creativeType($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreativeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreativeType() => $_clearField(2);

  @$pb.TagNumber(3)
  CreativeContent get creativeContent => $_getN(2);
  @$pb.TagNumber(3)
  set creativeContent(CreativeContent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCreativeContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreativeContent() => $_clearField(3);
  @$pb.TagNumber(3)
  CreativeContent ensureCreativeContent() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get adCb => $_getSZ(3);
  @$pb.TagNumber(4)
  set adCb($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAdCb() => $_has(3);
  @$pb.TagNumber(4)
  void clearAdCb() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get cardType => $_getIZ(4);
  @$pb.TagNumber(5)
  set cardType($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCardType() => $_has(4);
  @$pb.TagNumber(5)
  void clearCardType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get extra => $_getN(5);
  @$pb.TagNumber(6)
  set extra($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExtra() => $_has(5);
  @$pb.TagNumber(6)
  void clearExtra() => $_clearField(6);
}

class ArcExtra extends $pb.GeneratedMessage {
  factory ArcExtra({
    $core.String? arcPubLocation,
  }) {
    final result = ArcExtra._();
    if (arcPubLocation != null) result.arcPubLocation = arcPubLocation;
    return result;
  }

  ArcExtra._();

  factory ArcExtra.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArcExtra()..mergeFromBuffer(data, registry);
  factory ArcExtra.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArcExtra()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArcExtra',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ArcExtra.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'arcPubLocation')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArcExtra clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArcExtra copyWith(void Function(ArcExtra) updates) =>
      super.copyWith((message) => updates(message as ArcExtra)) as ArcExtra;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArcExtra() / ArcExtra.new instead')
  static ArcExtra create() => ArcExtra._();
  static $pb.GeneratedMessage $_createMessage() => ArcExtra._();
  @$core.override
  ArcExtra createEmptyInstance() => ArcExtra._();
  @$core.pragma('dart2js:noInline')
  static ArcExtra getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArcExtra>(ArcExtra.$_createMessage);
  static ArcExtra? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get arcPubLocation => $_getSZ(0);
  @$pb.TagNumber(1)
  set arcPubLocation($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasArcPubLocation() => $_has(0);
  @$pb.TagNumber(1)
  void clearArcPubLocation() => $_clearField(1);
}

class ArcsPlayer extends $pb.GeneratedMessage {
  factory ArcsPlayer({
    $fixnum.Int64? aid,
    $core.Iterable<$core.MapEntry<$fixnum.Int64, $core.String>>? playerInfo,
  }) {
    final result = ArcsPlayer._();
    if (aid != null) result.aid = aid;
    if (playerInfo != null) result.playerInfo.addEntries(playerInfo);
    return result;
  }

  ArcsPlayer._();

  factory ArcsPlayer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArcsPlayer()..mergeFromBuffer(data, registry);
  factory ArcsPlayer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArcsPlayer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArcsPlayer',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ArcsPlayer.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..m<$fixnum.Int64, $core.String>(2, _omitFieldNames ? '' : 'playerInfo',
        entryClassName: 'ArcsPlayer.PlayerInfoEntry',
        keyFieldType: $pb.PbFieldType.O6,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bilibili.app.view.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArcsPlayer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArcsPlayer copyWith(void Function(ArcsPlayer) updates) =>
      super.copyWith((message) => updates(message as ArcsPlayer)) as ArcsPlayer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArcsPlayer() / ArcsPlayer.new instead')
  static ArcsPlayer create() => ArcsPlayer._();
  static $pb.GeneratedMessage $_createMessage() => ArcsPlayer._();
  @$core.override
  ArcsPlayer createEmptyInstance() => ArcsPlayer._();
  @$core.pragma('dart2js:noInline')
  static ArcsPlayer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArcsPlayer>(ArcsPlayer.$_createMessage);
  static ArcsPlayer? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$fixnum.Int64, $core.String> get playerInfo => $_getMap(1);
}

class Asset extends $pb.GeneratedMessage {
  factory Asset({
    $core.int? paid,
    $fixnum.Int64? price,
    AssetMsg? msg,
    AssetMsg? previewMsg,
  }) {
    final result = Asset._();
    if (paid != null) result.paid = paid;
    if (price != null) result.price = price;
    if (msg != null) result.msg = msg;
    if (previewMsg != null) result.previewMsg = previewMsg;
    return result;
  }

  Asset._();

  factory Asset.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Asset()..mergeFromBuffer(data, registry);
  factory Asset.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Asset()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Asset',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Asset.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'paid')
    ..aInt64(2, _omitFieldNames ? '' : 'price')
    ..aOM<AssetMsg>(3, _omitFieldNames ? '' : 'msg',
        subBuilder: AssetMsg.$_createMessage)
    ..aOM<AssetMsg>(4, _omitFieldNames ? '' : 'previewMsg',
        subBuilder: AssetMsg.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Asset clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Asset copyWith(void Function(Asset) updates) =>
      super.copyWith((message) => updates(message as Asset)) as Asset;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Asset() / Asset.new instead')
  static Asset create() => Asset._();
  static $pb.GeneratedMessage $_createMessage() => Asset._();
  @$core.override
  Asset createEmptyInstance() => Asset._();
  @$core.pragma('dart2js:noInline')
  static Asset getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Asset>(Asset.$_createMessage);
  static Asset? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get paid => $_getIZ(0);
  @$pb.TagNumber(1)
  set paid($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaid() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaid() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get price => $_getI64(1);
  @$pb.TagNumber(2)
  set price($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPrice() => $_has(1);
  @$pb.TagNumber(2)
  void clearPrice() => $_clearField(2);

  @$pb.TagNumber(3)
  AssetMsg get msg => $_getN(2);
  @$pb.TagNumber(3)
  set msg(AssetMsg value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMsg() => $_has(2);
  @$pb.TagNumber(3)
  void clearMsg() => $_clearField(3);
  @$pb.TagNumber(3)
  AssetMsg ensureMsg() => $_ensure(2);

  @$pb.TagNumber(4)
  AssetMsg get previewMsg => $_getN(3);
  @$pb.TagNumber(4)
  set previewMsg(AssetMsg value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPreviewMsg() => $_has(3);
  @$pb.TagNumber(4)
  void clearPreviewMsg() => $_clearField(4);
  @$pb.TagNumber(4)
  AssetMsg ensurePreviewMsg() => $_ensure(3);
}

class AssetMsg extends $pb.GeneratedMessage {
  factory AssetMsg({
    $core.String? desc1,
    $core.String? desc2,
  }) {
    final result = AssetMsg._();
    if (desc1 != null) result.desc1 = desc1;
    if (desc2 != null) result.desc2 = desc2;
    return result;
  }

  AssetMsg._();

  factory AssetMsg.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AssetMsg()..mergeFromBuffer(data, registry);
  factory AssetMsg.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AssetMsg()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssetMsg',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: AssetMsg.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'desc1')
    ..aOS(2, _omitFieldNames ? '' : 'desc2')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssetMsg clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssetMsg copyWith(void Function(AssetMsg) updates) =>
      super.copyWith((message) => updates(message as AssetMsg)) as AssetMsg;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AssetMsg() / AssetMsg.new instead')
  static AssetMsg create() => AssetMsg._();
  static $pb.GeneratedMessage $_createMessage() => AssetMsg._();
  @$core.override
  AssetMsg createEmptyInstance() => AssetMsg._();
  @$core.pragma('dart2js:noInline')
  static AssetMsg getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssetMsg>(AssetMsg.$_createMessage);
  static AssetMsg? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get desc1 => $_getSZ(0);
  @$pb.TagNumber(1)
  set desc1($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDesc1() => $_has(0);
  @$pb.TagNumber(1)
  void clearDesc1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get desc2 => $_getSZ(1);
  @$pb.TagNumber(2)
  set desc2($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesc2() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesc2() => $_clearField(2);
}

/// 关注按钮卡片
class Attention extends $pb.GeneratedMessage {
  factory Attention({
    $core.int? startTime,
    $core.int? endTime,
    $core.double? posX,
    $core.double? posY,
  }) {
    final result = Attention._();
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (posX != null) result.posX = posX;
    if (posY != null) result.posY = posY;
    return result;
  }

  Attention._();

  factory Attention.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Attention()..mergeFromBuffer(data, registry);
  factory Attention.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Attention()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Attention',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Attention.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'startTime')
    ..aI(2, _omitFieldNames ? '' : 'endTime')
    ..aD(3, _omitFieldNames ? '' : 'posX')
    ..aD(4, _omitFieldNames ? '' : 'posY')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attention clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attention copyWith(void Function(Attention) updates) =>
      super.copyWith((message) => updates(message as Attention)) as Attention;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Attention() / Attention.new instead')
  static Attention create() => Attention._();
  static $pb.GeneratedMessage $_createMessage() => Attention._();
  @$core.override
  Attention createEmptyInstance() => Attention._();
  @$core.pragma('dart2js:noInline')
  static Attention getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Attention>(Attention.$_createMessage);
  static Attention? _defaultInstance;

  /// 开始时间
  @$pb.TagNumber(1)
  $core.int get startTime => $_getIZ(0);
  @$pb.TagNumber(1)
  set startTime($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartTime() => $_clearField(1);

  /// 结束时间
  @$pb.TagNumber(2)
  $core.int get endTime => $_getIZ(1);
  @$pb.TagNumber(2)
  set endTime($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndTime() => $_clearField(2);

  /// 位置x坐标
  @$pb.TagNumber(3)
  $core.double get posX => $_getN(2);
  @$pb.TagNumber(3)
  set posX($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPosX() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosX() => $_clearField(3);

  /// 位置y坐标
  @$pb.TagNumber(4)
  $core.double get posY => $_getN(3);
  @$pb.TagNumber(4)
  set posY($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPosY() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosY() => $_clearField(4);
}

/// 音频稿件信息
class Audio extends $pb.GeneratedMessage {
  factory Audio({
    $core.String? title,
    $core.String? coverUrl,
    $fixnum.Int64? songId,
    $fixnum.Int64? playCount,
    $fixnum.Int64? replyCount,
    $fixnum.Int64? upperId,
    $core.String? entrance,
    $fixnum.Int64? songAttr,
  }) {
    final result = Audio._();
    if (title != null) result.title = title;
    if (coverUrl != null) result.coverUrl = coverUrl;
    if (songId != null) result.songId = songId;
    if (playCount != null) result.playCount = playCount;
    if (replyCount != null) result.replyCount = replyCount;
    if (upperId != null) result.upperId = upperId;
    if (entrance != null) result.entrance = entrance;
    if (songAttr != null) result.songAttr = songAttr;
    return result;
  }

  Audio._();

  factory Audio.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Audio()..mergeFromBuffer(data, registry);
  factory Audio.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Audio()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Audio',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Audio.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'coverUrl')
    ..aInt64(3, _omitFieldNames ? '' : 'songId')
    ..aInt64(4, _omitFieldNames ? '' : 'playCount')
    ..aInt64(5, _omitFieldNames ? '' : 'replyCount')
    ..aInt64(6, _omitFieldNames ? '' : 'upperId')
    ..aOS(7, _omitFieldNames ? '' : 'entrance')
    ..aInt64(8, _omitFieldNames ? '' : 'songAttr')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Audio clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Audio copyWith(void Function(Audio) updates) =>
      super.copyWith((message) => updates(message as Audio)) as Audio;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Audio() / Audio.new instead')
  static Audio create() => Audio._();
  static $pb.GeneratedMessage $_createMessage() => Audio._();
  @$core.override
  Audio createEmptyInstance() => Audio._();
  @$core.pragma('dart2js:noInline')
  static Audio getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Audio>(Audio.$_createMessage);
  static Audio? _defaultInstance;

  /// 音频标题
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 音频封面url
  @$pb.TagNumber(2)
  $core.String get coverUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set coverUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCoverUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearCoverUrl() => $_clearField(2);

  /// 音频auid
  @$pb.TagNumber(3)
  $fixnum.Int64 get songId => $_getI64(2);
  @$pb.TagNumber(3)
  set songId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSongId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSongId() => $_clearField(3);

  /// 音频播放量
  @$pb.TagNumber(4)
  $fixnum.Int64 get playCount => $_getI64(3);
  @$pb.TagNumber(4)
  set playCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlayCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlayCount() => $_clearField(4);

  /// 音频评论数
  @$pb.TagNumber(5)
  $fixnum.Int64 get replyCount => $_getI64(4);
  @$pb.TagNumber(5)
  set replyCount($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReplyCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearReplyCount() => $_clearField(5);

  /// 音频作者UID
  @$pb.TagNumber(6)
  $fixnum.Int64 get upperId => $_getI64(5);
  @$pb.TagNumber(6)
  set upperId($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUpperId() => $_has(5);
  @$pb.TagNumber(6)
  void clearUpperId() => $_clearField(6);

  /// 进入按钮文案
  @$pb.TagNumber(7)
  $core.String get entrance => $_getSZ(6);
  @$pb.TagNumber(7)
  set entrance($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEntrance() => $_has(6);
  @$pb.TagNumber(7)
  void clearEntrance() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get songAttr => $_getI64(7);
  @$pb.TagNumber(8)
  set songAttr($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSongAttr() => $_has(7);
  @$pb.TagNumber(8)
  void clearSongAttr() => $_clearField(8);
}

class BadgeStyle extends $pb.GeneratedMessage {
  factory BadgeStyle({
    $core.String? text,
    $core.String? textColor,
    $core.String? textColorNight,
    $core.String? bgColor,
    $core.String? bgColorNight,
    $core.String? borderColor,
    $core.String? borderColorNight,
    $core.int? bgStyle,
  }) {
    final result = BadgeStyle._();
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    if (bgColor != null) result.bgColor = bgColor;
    if (bgColorNight != null) result.bgColorNight = bgColorNight;
    if (borderColor != null) result.borderColor = borderColor;
    if (borderColorNight != null) result.borderColorNight = borderColorNight;
    if (bgStyle != null) result.bgStyle = bgStyle;
    return result;
  }

  BadgeStyle._();

  factory BadgeStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BadgeStyle()..mergeFromBuffer(data, registry);
  factory BadgeStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BadgeStyle()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BadgeStyle',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BadgeStyle.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'textColor')
    ..aOS(3, _omitFieldNames ? '' : 'textColorNight')
    ..aOS(4, _omitFieldNames ? '' : 'bgColor')
    ..aOS(5, _omitFieldNames ? '' : 'bgColorNight')
    ..aOS(6, _omitFieldNames ? '' : 'borderColor')
    ..aOS(7, _omitFieldNames ? '' : 'borderColorNight')
    ..aI(8, _omitFieldNames ? '' : 'bgStyle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BadgeStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BadgeStyle copyWith(void Function(BadgeStyle) updates) =>
      super.copyWith((message) => updates(message as BadgeStyle)) as BadgeStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BadgeStyle() / BadgeStyle.new instead')
  static BadgeStyle create() => BadgeStyle._();
  static $pb.GeneratedMessage $_createMessage() => BadgeStyle._();
  @$core.override
  BadgeStyle createEmptyInstance() => BadgeStyle._();
  @$core.pragma('dart2js:noInline')
  static BadgeStyle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BadgeStyle>(BadgeStyle.$_createMessage);
  static BadgeStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get textColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set textColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTextColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearTextColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get textColorNight => $_getSZ(2);
  @$pb.TagNumber(3)
  set textColorNight($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTextColorNight() => $_has(2);
  @$pb.TagNumber(3)
  void clearTextColorNight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get bgColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set bgColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBgColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearBgColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get bgColorNight => $_getSZ(4);
  @$pb.TagNumber(5)
  set bgColorNight($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBgColorNight() => $_has(4);
  @$pb.TagNumber(5)
  void clearBgColorNight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get borderColor => $_getSZ(5);
  @$pb.TagNumber(6)
  set borderColor($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBorderColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearBorderColor() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get borderColorNight => $_getSZ(6);
  @$pb.TagNumber(7)
  set borderColorNight($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBorderColorNight() => $_has(6);
  @$pb.TagNumber(7)
  void clearBorderColorNight() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get bgStyle => $_getIZ(7);
  @$pb.TagNumber(8)
  set bgStyle($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBgStyle() => $_has(7);
  @$pb.TagNumber(8)
  void clearBgStyle() => $_clearField(8);
}

/// 视频引用的bgm音频
class Bgm extends $pb.GeneratedMessage {
  factory Bgm({
    $fixnum.Int64? sid,
    $fixnum.Int64? mid,
    $core.String? title,
    $core.String? author,
    $core.String? jumpUrl,
    $core.String? cover,
  }) {
    final result = Bgm._();
    if (sid != null) result.sid = sid;
    if (mid != null) result.mid = mid;
    if (title != null) result.title = title;
    if (author != null) result.author = author;
    if (jumpUrl != null) result.jumpUrl = jumpUrl;
    if (cover != null) result.cover = cover;
    return result;
  }

  Bgm._();

  factory Bgm.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Bgm()..mergeFromBuffer(data, registry);
  factory Bgm.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Bgm()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Bgm',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Bgm.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'sid')
    ..aInt64(2, _omitFieldNames ? '' : 'mid')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'author')
    ..aOS(5, _omitFieldNames ? '' : 'jumpUrl', protoName: 'jumpUrl')
    ..aOS(6, _omitFieldNames ? '' : 'cover')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Bgm clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Bgm copyWith(void Function(Bgm) updates) =>
      super.copyWith((message) => updates(message as Bgm)) as Bgm;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Bgm() / Bgm.new instead')
  static Bgm create() => Bgm._();
  static $pb.GeneratedMessage $_createMessage() => Bgm._();
  @$core.override
  Bgm createEmptyInstance() => Bgm._();
  @$core.pragma('dart2js:noInline')
  static Bgm getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Bgm>(Bgm.$_createMessage);
  static Bgm? _defaultInstance;

  /// 音频auid
  @$pb.TagNumber(1)
  $fixnum.Int64 get sid => $_getI64(0);
  @$pb.TagNumber(1)
  set sid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  /// 音频作者mid
  @$pb.TagNumber(2)
  $fixnum.Int64 get mid => $_getI64(1);
  @$pb.TagNumber(2)
  set mid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMid() => $_has(1);
  @$pb.TagNumber(2)
  void clearMid() => $_clearField(2);

  /// 音频标题
  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  /// 音频作者昵称
  @$pb.TagNumber(4)
  $core.String get author => $_getSZ(3);
  @$pb.TagNumber(4)
  set author($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthor() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthor() => $_clearField(4);

  /// bgm页面url
  @$pb.TagNumber(5)
  $core.String get jumpUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set jumpUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasJumpUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearJumpUrl() => $_clearField(5);

  /// 音频封面url
  @$pb.TagNumber(6)
  $core.String get cover => $_getSZ(5);
  @$pb.TagNumber(6)
  set cover($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCover() => $_has(5);
  @$pb.TagNumber(6)
  void clearCover() => $_clearField(6);
}

/// 收藏合集参数
class BizFavSeasonParam extends $pb.GeneratedMessage {
  factory BizFavSeasonParam({
    $fixnum.Int64? seasonId,
  }) {
    final result = BizFavSeasonParam._();
    if (seasonId != null) result.seasonId = seasonId;
    return result;
  }

  BizFavSeasonParam._();

  factory BizFavSeasonParam.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizFavSeasonParam()..mergeFromBuffer(data, registry);
  factory BizFavSeasonParam.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizFavSeasonParam()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BizFavSeasonParam',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BizFavSeasonParam.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'seasonId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizFavSeasonParam clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizFavSeasonParam copyWith(void Function(BizFavSeasonParam) updates) =>
      super.copyWith((message) => updates(message as BizFavSeasonParam))
          as BizFavSeasonParam;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BizFavSeasonParam() / BizFavSeasonParam.new instead')
  static BizFavSeasonParam create() => BizFavSeasonParam._();
  static $pb.GeneratedMessage $_createMessage() => BizFavSeasonParam._();
  @$core.override
  BizFavSeasonParam createEmptyInstance() => BizFavSeasonParam._();
  @$core.pragma('dart2js:noInline')
  static BizFavSeasonParam getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BizFavSeasonParam>(
          BizFavSeasonParam.$_createMessage);
  static BizFavSeasonParam? _defaultInstance;

  /// 合集id
  @$pb.TagNumber(1)
  $fixnum.Int64 get seasonId => $_getI64(0);
  @$pb.TagNumber(1)
  set seasonId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);
}

class BizFollowVideoParam extends $pb.GeneratedMessage {
  factory BizFollowVideoParam({
    $fixnum.Int64? seasonId,
  }) {
    final result = BizFollowVideoParam._();
    if (seasonId != null) result.seasonId = seasonId;
    return result;
  }

  BizFollowVideoParam._();

  factory BizFollowVideoParam.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizFollowVideoParam()..mergeFromBuffer(data, registry);
  factory BizFollowVideoParam.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizFollowVideoParam()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BizFollowVideoParam',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BizFollowVideoParam.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'seasonId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizFollowVideoParam clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizFollowVideoParam copyWith(void Function(BizFollowVideoParam) updates) =>
      super.copyWith((message) => updates(message as BizFollowVideoParam))
          as BizFollowVideoParam;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use BizFollowVideoParam() / BizFollowVideoParam.new instead')
  static BizFollowVideoParam create() => BizFollowVideoParam._();
  static $pb.GeneratedMessage $_createMessage() => BizFollowVideoParam._();
  @$core.override
  BizFollowVideoParam createEmptyInstance() => BizFollowVideoParam._();
  @$core.pragma('dart2js:noInline')
  static BizFollowVideoParam getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BizFollowVideoParam>(
          BizFollowVideoParam.$_createMessage);
  static BizFollowVideoParam? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seasonId => $_getI64(0);
  @$pb.TagNumber(1)
  set seasonId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);
}

class BizJumpLinkParam extends $pb.GeneratedMessage {
  factory BizJumpLinkParam({
    $core.String? url,
  }) {
    final result = BizJumpLinkParam._();
    if (url != null) result.url = url;
    return result;
  }

  BizJumpLinkParam._();

  factory BizJumpLinkParam.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizJumpLinkParam()..mergeFromBuffer(data, registry);
  factory BizJumpLinkParam.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizJumpLinkParam()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BizJumpLinkParam',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BizJumpLinkParam.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizJumpLinkParam clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizJumpLinkParam copyWith(void Function(BizJumpLinkParam) updates) =>
      super.copyWith((message) => updates(message as BizJumpLinkParam))
          as BizJumpLinkParam;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BizJumpLinkParam() / BizJumpLinkParam.new instead')
  static BizJumpLinkParam create() => BizJumpLinkParam._();
  static $pb.GeneratedMessage $_createMessage() => BizJumpLinkParam._();
  @$core.override
  BizJumpLinkParam createEmptyInstance() => BizJumpLinkParam._();
  @$core.pragma('dart2js:noInline')
  static BizJumpLinkParam getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BizJumpLinkParam>(
          BizJumpLinkParam.$_createMessage);
  static BizJumpLinkParam? _defaultInstance;

  /// 链接
  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);
}

/// 预约活动参数
class BizReserveActivityParam extends $pb.GeneratedMessage {
  factory BizReserveActivityParam({
    $fixnum.Int64? activityId,
    $core.String? from,
    $core.String? type,
    $fixnum.Int64? oid,
    $fixnum.Int64? reserveId,
  }) {
    final result = BizReserveActivityParam._();
    if (activityId != null) result.activityId = activityId;
    if (from != null) result.from = from;
    if (type != null) result.type = type;
    if (oid != null) result.oid = oid;
    if (reserveId != null) result.reserveId = reserveId;
    return result;
  }

  BizReserveActivityParam._();

  factory BizReserveActivityParam.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizReserveActivityParam()..mergeFromBuffer(data, registry);
  factory BizReserveActivityParam.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizReserveActivityParam()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BizReserveActivityParam',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BizReserveActivityParam.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'activityId')
    ..aOS(2, _omitFieldNames ? '' : 'from')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aInt64(4, _omitFieldNames ? '' : 'oid')
    ..aInt64(5, _omitFieldNames ? '' : 'reserveId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizReserveActivityParam clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizReserveActivityParam copyWith(
          void Function(BizReserveActivityParam) updates) =>
      super.copyWith((message) => updates(message as BizReserveActivityParam))
          as BizReserveActivityParam;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BizReserveActivityParam() / BizReserveActivityParam.new instead')
  static BizReserveActivityParam create() => BizReserveActivityParam._();
  static $pb.GeneratedMessage $_createMessage() => BizReserveActivityParam._();
  @$core.override
  BizReserveActivityParam createEmptyInstance() => BizReserveActivityParam._();
  @$core.pragma('dart2js:noInline')
  static BizReserveActivityParam getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BizReserveActivityParam>(
          BizReserveActivityParam.$_createMessage);
  static BizReserveActivityParam? _defaultInstance;

  /// 活动id
  @$pb.TagNumber(1)
  $fixnum.Int64 get activityId => $_getI64(0);
  @$pb.TagNumber(1)
  set activityId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActivityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearActivityId() => $_clearField(1);

  /// 场景
  @$pb.TagNumber(2)
  $core.String get from => $_getSZ(1);
  @$pb.TagNumber(2)
  set from($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  /// 类型
  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  /// 资源id
  @$pb.TagNumber(4)
  $fixnum.Int64 get oid => $_getI64(3);
  @$pb.TagNumber(4)
  set oid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOid() => $_has(3);
  @$pb.TagNumber(4)
  void clearOid() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get reserveId => $_getI64(4);
  @$pb.TagNumber(5)
  set reserveId($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReserveId() => $_has(4);
  @$pb.TagNumber(5)
  void clearReserveId() => $_clearField(5);
}

class BizReserveGameParam extends $pb.GeneratedMessage {
  factory BizReserveGameParam({
    $fixnum.Int64? gameId,
  }) {
    final result = BizReserveGameParam._();
    if (gameId != null) result.gameId = gameId;
    return result;
  }

  BizReserveGameParam._();

  factory BizReserveGameParam.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizReserveGameParam()..mergeFromBuffer(data, registry);
  factory BizReserveGameParam.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BizReserveGameParam()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BizReserveGameParam',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BizReserveGameParam.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'gameId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizReserveGameParam clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BizReserveGameParam copyWith(void Function(BizReserveGameParam) updates) =>
      super.copyWith((message) => updates(message as BizReserveGameParam))
          as BizReserveGameParam;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use BizReserveGameParam() / BizReserveGameParam.new instead')
  static BizReserveGameParam create() => BizReserveGameParam._();
  static $pb.GeneratedMessage $_createMessage() => BizReserveGameParam._();
  @$core.override
  BizReserveGameParam createEmptyInstance() => BizReserveGameParam._();
  @$core.pragma('dart2js:noInline')
  static BizReserveGameParam getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BizReserveGameParam>(
          BizReserveGameParam.$_createMessage);
  static BizReserveGameParam? _defaultInstance;

  /// 游戏id
  @$pb.TagNumber(1)
  $fixnum.Int64 get gameId => $_getI64(0);
  @$pb.TagNumber(1)
  set gameId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGameId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGameId() => $_clearField(1);
}

class Button extends $pb.GeneratedMessage {
  factory Button({
    $core.String? title,
    $core.String? uri,
    $core.String? icon,
  }) {
    final result = Button._();
    if (title != null) result.title = title;
    if (uri != null) result.uri = uri;
    if (icon != null) result.icon = icon;
    return result;
  }

  Button._();

  factory Button.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Button()..mergeFromBuffer(data, registry);
  factory Button.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Button()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Button',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Button.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'uri')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Button clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Button copyWith(void Function(Button) updates) =>
      super.copyWith((message) => updates(message as Button)) as Button;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Button() / Button.new instead')
  static Button create() => Button._();
  static $pb.GeneratedMessage $_createMessage() => Button._();
  @$core.override
  Button createEmptyInstance() => Button._();
  @$core.pragma('dart2js:noInline')
  static Button getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Button>(Button.$_createMessage);
  static Button? _defaultInstance;

  /// 按钮文案
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 跳转uri
  @$pb.TagNumber(2)
  $core.String get uri => $_getSZ(1);
  @$pb.TagNumber(2)
  set uri($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUri() => $_has(1);
  @$pb.TagNumber(2)
  void clearUri() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);
}

class ButtonStyle extends $pb.GeneratedMessage {
  factory ButtonStyle({
    $core.String? text,
    $core.String? textColor,
    $core.String? textColorNight,
    $core.String? bgColor,
    $core.String? bgColorNight,
    $core.String? jumpLink,
  }) {
    final result = ButtonStyle._();
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    if (bgColor != null) result.bgColor = bgColor;
    if (bgColorNight != null) result.bgColorNight = bgColorNight;
    if (jumpLink != null) result.jumpLink = jumpLink;
    return result;
  }

  ButtonStyle._();

  factory ButtonStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ButtonStyle()..mergeFromBuffer(data, registry);
  factory ButtonStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ButtonStyle()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ButtonStyle',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ButtonStyle.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'textColor')
    ..aOS(3, _omitFieldNames ? '' : 'textColorNight')
    ..aOS(4, _omitFieldNames ? '' : 'bgColor')
    ..aOS(5, _omitFieldNames ? '' : 'bgColorNight')
    ..aOS(6, _omitFieldNames ? '' : 'jumpLink')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ButtonStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ButtonStyle copyWith(void Function(ButtonStyle) updates) =>
      super.copyWith((message) => updates(message as ButtonStyle))
          as ButtonStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ButtonStyle() / ButtonStyle.new instead')
  static ButtonStyle create() => ButtonStyle._();
  static $pb.GeneratedMessage $_createMessage() => ButtonStyle._();
  @$core.override
  ButtonStyle createEmptyInstance() => ButtonStyle._();
  @$core.pragma('dart2js:noInline')
  static ButtonStyle getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ButtonStyle>(
          ButtonStyle.$_createMessage);
  static ButtonStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get textColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set textColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTextColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearTextColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get textColorNight => $_getSZ(2);
  @$pb.TagNumber(3)
  set textColorNight($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTextColorNight() => $_has(2);
  @$pb.TagNumber(3)
  void clearTextColorNight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get bgColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set bgColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBgColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearBgColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get bgColorNight => $_getSZ(4);
  @$pb.TagNumber(5)
  set bgColorNight($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBgColorNight() => $_has(4);
  @$pb.TagNumber(5)
  void clearBgColorNight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get jumpLink => $_getSZ(5);
  @$pb.TagNumber(6)
  set jumpLink($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasJumpLink() => $_has(5);
  @$pb.TagNumber(6)
  void clearJumpLink() => $_clearField(6);
}

class BuzzwordConfig extends $pb.GeneratedMessage {
  factory BuzzwordConfig({
    $core.String? name,
    $core.String? schema,
    $core.int? source,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
    $core.bool? followControl,
    $fixnum.Int64? id,
    $fixnum.Int64? buzzwordId,
    $core.int? schemaType,
    $core.String? picture,
  }) {
    final result = BuzzwordConfig._();
    if (name != null) result.name = name;
    if (schema != null) result.schema = schema;
    if (source != null) result.source = source;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    if (followControl != null) result.followControl = followControl;
    if (id != null) result.id = id;
    if (buzzwordId != null) result.buzzwordId = buzzwordId;
    if (schemaType != null) result.schemaType = schemaType;
    if (picture != null) result.picture = picture;
    return result;
  }

  BuzzwordConfig._();

  factory BuzzwordConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BuzzwordConfig()..mergeFromBuffer(data, registry);
  factory BuzzwordConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BuzzwordConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BuzzwordConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: BuzzwordConfig.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'schema')
    ..aI(3, _omitFieldNames ? '' : 'source')
    ..aInt64(4, _omitFieldNames ? '' : 'start')
    ..aInt64(5, _omitFieldNames ? '' : 'end')
    ..aOB(6, _omitFieldNames ? '' : 'followControl')
    ..aInt64(7, _omitFieldNames ? '' : 'id')
    ..aInt64(8, _omitFieldNames ? '' : 'buzzwordId')
    ..aI(9, _omitFieldNames ? '' : 'schemaType')
    ..aOS(10, _omitFieldNames ? '' : 'picture')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuzzwordConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuzzwordConfig copyWith(void Function(BuzzwordConfig) updates) =>
      super.copyWith((message) => updates(message as BuzzwordConfig))
          as BuzzwordConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BuzzwordConfig() / BuzzwordConfig.new instead')
  static BuzzwordConfig create() => BuzzwordConfig._();
  static $pb.GeneratedMessage $_createMessage() => BuzzwordConfig._();
  @$core.override
  BuzzwordConfig createEmptyInstance() => BuzzwordConfig._();
  @$core.pragma('dart2js:noInline')
  static BuzzwordConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BuzzwordConfig>(
          BuzzwordConfig.$_createMessage);
  static BuzzwordConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get schema => $_getSZ(1);
  @$pb.TagNumber(2)
  set schema($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchema() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchema() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get source => $_getIZ(2);
  @$pb.TagNumber(3)
  set source($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get start => $_getI64(3);
  @$pb.TagNumber(4)
  set start($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get end => $_getI64(4);
  @$pb.TagNumber(5)
  set end($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnd() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnd() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get followControl => $_getBF(5);
  @$pb.TagNumber(6)
  set followControl($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFollowControl() => $_has(5);
  @$pb.TagNumber(6)
  void clearFollowControl() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get id => $_getI64(6);
  @$pb.TagNumber(7)
  set id($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasId() => $_has(6);
  @$pb.TagNumber(7)
  void clearId() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get buzzwordId => $_getI64(7);
  @$pb.TagNumber(8)
  set buzzwordId($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBuzzwordId() => $_has(7);
  @$pb.TagNumber(8)
  void clearBuzzwordId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get schemaType => $_getIZ(8);
  @$pb.TagNumber(9)
  set schemaType($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSchemaType() => $_has(8);
  @$pb.TagNumber(9)
  void clearSchemaType() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get picture => $_getSZ(9);
  @$pb.TagNumber(10)
  set picture($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPicture() => $_has(9);
  @$pb.TagNumber(10)
  void clearPicture() => $_clearField(10);
}

class CacheViewReply extends $pb.GeneratedMessage {
  factory CacheViewReply({
    $1.Arc? arc,
    $core.Iterable<ViewPage>? pages,
    OnwerExt? ownerExt,
    ReqUser? reqUser,
    Season? season,
    ElecRank? elecRank,
    History? history,
    Dislike? dislike,
    PlayerIcon? playerIcon,
    $core.String? bvid,
    $core.String? shortLink,
    $core.String? shareSubtitle,
    TFPanelCustomized? tfPanelCustomized,
    Online? online,
  }) {
    final result = CacheViewReply._();
    if (arc != null) result.arc = arc;
    if (pages != null) result.pages.addAll(pages);
    if (ownerExt != null) result.ownerExt = ownerExt;
    if (reqUser != null) result.reqUser = reqUser;
    if (season != null) result.season = season;
    if (elecRank != null) result.elecRank = elecRank;
    if (history != null) result.history = history;
    if (dislike != null) result.dislike = dislike;
    if (playerIcon != null) result.playerIcon = playerIcon;
    if (bvid != null) result.bvid = bvid;
    if (shortLink != null) result.shortLink = shortLink;
    if (shareSubtitle != null) result.shareSubtitle = shareSubtitle;
    if (tfPanelCustomized != null) result.tfPanelCustomized = tfPanelCustomized;
    if (online != null) result.online = online;
    return result;
  }

  CacheViewReply._();

  factory CacheViewReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CacheViewReply()..mergeFromBuffer(data, registry);
  factory CacheViewReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CacheViewReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CacheViewReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CacheViewReply.$_createMessage)
    ..aOM<$1.Arc>(1, _omitFieldNames ? '' : 'arc',
        subBuilder: $1.Arc.$_createMessage)
    ..pPM<ViewPage>(2, _omitFieldNames ? '' : 'pages',
        subBuilder: ViewPage.$_createMessage)
    ..aOM<OnwerExt>(3, _omitFieldNames ? '' : 'ownerExt',
        subBuilder: OnwerExt.$_createMessage)
    ..aOM<ReqUser>(4, _omitFieldNames ? '' : 'reqUser',
        subBuilder: ReqUser.$_createMessage)
    ..aOM<Season>(5, _omitFieldNames ? '' : 'season',
        subBuilder: Season.$_createMessage)
    ..aOM<ElecRank>(6, _omitFieldNames ? '' : 'elecRank',
        subBuilder: ElecRank.$_createMessage)
    ..aOM<History>(7, _omitFieldNames ? '' : 'history',
        subBuilder: History.$_createMessage)
    ..aOM<Dislike>(8, _omitFieldNames ? '' : 'dislike',
        subBuilder: Dislike.$_createMessage)
    ..aOM<PlayerIcon>(9, _omitFieldNames ? '' : 'playerIcon',
        subBuilder: PlayerIcon.$_createMessage)
    ..aOS(10, _omitFieldNames ? '' : 'bvid')
    ..aOS(11, _omitFieldNames ? '' : 'shortLink')
    ..aOS(12, _omitFieldNames ? '' : 'shareSubtitle')
    ..aOM<TFPanelCustomized>(13, _omitFieldNames ? '' : 'tfPanelCustomized',
        subBuilder: TFPanelCustomized.$_createMessage)
    ..aOM<Online>(14, _omitFieldNames ? '' : 'online',
        subBuilder: Online.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CacheViewReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CacheViewReply copyWith(void Function(CacheViewReply) updates) =>
      super.copyWith((message) => updates(message as CacheViewReply))
          as CacheViewReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CacheViewReply() / CacheViewReply.new instead')
  static CacheViewReply create() => CacheViewReply._();
  static $pb.GeneratedMessage $_createMessage() => CacheViewReply._();
  @$core.override
  CacheViewReply createEmptyInstance() => CacheViewReply._();
  @$core.pragma('dart2js:noInline')
  static CacheViewReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CacheViewReply>(
          CacheViewReply.$_createMessage);
  static CacheViewReply? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Arc get arc => $_getN(0);
  @$pb.TagNumber(1)
  set arc($1.Arc value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasArc() => $_has(0);
  @$pb.TagNumber(1)
  void clearArc() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Arc ensureArc() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<ViewPage> get pages => $_getList(1);

  @$pb.TagNumber(3)
  OnwerExt get ownerExt => $_getN(2);
  @$pb.TagNumber(3)
  set ownerExt(OnwerExt value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOwnerExt() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwnerExt() => $_clearField(3);
  @$pb.TagNumber(3)
  OnwerExt ensureOwnerExt() => $_ensure(2);

  @$pb.TagNumber(4)
  ReqUser get reqUser => $_getN(3);
  @$pb.TagNumber(4)
  set reqUser(ReqUser value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReqUser() => $_has(3);
  @$pb.TagNumber(4)
  void clearReqUser() => $_clearField(4);
  @$pb.TagNumber(4)
  ReqUser ensureReqUser() => $_ensure(3);

  @$pb.TagNumber(5)
  Season get season => $_getN(4);
  @$pb.TagNumber(5)
  set season(Season value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSeason() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeason() => $_clearField(5);
  @$pb.TagNumber(5)
  Season ensureSeason() => $_ensure(4);

  @$pb.TagNumber(6)
  ElecRank get elecRank => $_getN(5);
  @$pb.TagNumber(6)
  set elecRank(ElecRank value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasElecRank() => $_has(5);
  @$pb.TagNumber(6)
  void clearElecRank() => $_clearField(6);
  @$pb.TagNumber(6)
  ElecRank ensureElecRank() => $_ensure(5);

  @$pb.TagNumber(7)
  History get history => $_getN(6);
  @$pb.TagNumber(7)
  set history(History value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasHistory() => $_has(6);
  @$pb.TagNumber(7)
  void clearHistory() => $_clearField(7);
  @$pb.TagNumber(7)
  History ensureHistory() => $_ensure(6);

  @$pb.TagNumber(8)
  Dislike get dislike => $_getN(7);
  @$pb.TagNumber(8)
  set dislike(Dislike value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDislike() => $_has(7);
  @$pb.TagNumber(8)
  void clearDislike() => $_clearField(8);
  @$pb.TagNumber(8)
  Dislike ensureDislike() => $_ensure(7);

  @$pb.TagNumber(9)
  PlayerIcon get playerIcon => $_getN(8);
  @$pb.TagNumber(9)
  set playerIcon(PlayerIcon value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasPlayerIcon() => $_has(8);
  @$pb.TagNumber(9)
  void clearPlayerIcon() => $_clearField(9);
  @$pb.TagNumber(9)
  PlayerIcon ensurePlayerIcon() => $_ensure(8);

  @$pb.TagNumber(10)
  $core.String get bvid => $_getSZ(9);
  @$pb.TagNumber(10)
  set bvid($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBvid() => $_has(9);
  @$pb.TagNumber(10)
  void clearBvid() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get shortLink => $_getSZ(10);
  @$pb.TagNumber(11)
  set shortLink($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasShortLink() => $_has(10);
  @$pb.TagNumber(11)
  void clearShortLink() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get shareSubtitle => $_getSZ(11);
  @$pb.TagNumber(12)
  set shareSubtitle($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasShareSubtitle() => $_has(11);
  @$pb.TagNumber(12)
  void clearShareSubtitle() => $_clearField(12);

  @$pb.TagNumber(13)
  TFPanelCustomized get tfPanelCustomized => $_getN(12);
  @$pb.TagNumber(13)
  set tfPanelCustomized(TFPanelCustomized value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasTfPanelCustomized() => $_has(12);
  @$pb.TagNumber(13)
  void clearTfPanelCustomized() => $_clearField(13);
  @$pb.TagNumber(13)
  TFPanelCustomized ensureTfPanelCustomized() => $_ensure(12);

  @$pb.TagNumber(14)
  Online get online => $_getN(13);
  @$pb.TagNumber(14)
  set online(Online value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasOnline() => $_has(13);
  @$pb.TagNumber(14)
  void clearOnline() => $_clearField(14);
  @$pb.TagNumber(14)
  Online ensureOnline() => $_ensure(13);
}

class CacheViewReq extends $pb.GeneratedMessage {
  factory CacheViewReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $core.String? from,
    $core.String? trackid,
    $core.String? adExtra,
    $core.String? spmid,
    $core.String? fromSpmid,
  }) {
    final result = CacheViewReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (from != null) result.from = from;
    if (trackid != null) result.trackid = trackid;
    if (adExtra != null) result.adExtra = adExtra;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    return result;
  }

  CacheViewReq._();

  factory CacheViewReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CacheViewReq()..mergeFromBuffer(data, registry);
  factory CacheViewReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CacheViewReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CacheViewReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CacheViewReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aOS(3, _omitFieldNames ? '' : 'from')
    ..aOS(4, _omitFieldNames ? '' : 'trackid')
    ..aOS(5, _omitFieldNames ? '' : 'adExtra')
    ..aOS(6, _omitFieldNames ? '' : 'spmid')
    ..aOS(7, _omitFieldNames ? '' : 'fromSpmid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CacheViewReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CacheViewReq copyWith(void Function(CacheViewReq) updates) =>
      super.copyWith((message) => updates(message as CacheViewReq))
          as CacheViewReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CacheViewReq() / CacheViewReq.new instead')
  static CacheViewReq create() => CacheViewReq._();
  static $pb.GeneratedMessage $_createMessage() => CacheViewReq._();
  @$core.override
  CacheViewReq createEmptyInstance() => CacheViewReq._();
  @$core.pragma('dart2js:noInline')
  static CacheViewReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CacheViewReq>(
          CacheViewReq.$_createMessage);
  static CacheViewReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get from => $_getSZ(2);
  @$pb.TagNumber(3)
  set from($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get trackid => $_getSZ(3);
  @$pb.TagNumber(4)
  set trackid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTrackid() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrackid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get adExtra => $_getSZ(4);
  @$pb.TagNumber(5)
  set adExtra($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAdExtra() => $_has(4);
  @$pb.TagNumber(5)
  void clearAdExtra() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get spmid => $_getSZ(5);
  @$pb.TagNumber(6)
  set spmid($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSpmid() => $_has(5);
  @$pb.TagNumber(6)
  void clearSpmid() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get fromSpmid => $_getSZ(6);
  @$pb.TagNumber(7)
  set fromSpmid($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFromSpmid() => $_has(6);
  @$pb.TagNumber(7)
  void clearFromSpmid() => $_clearField(7);
}

/// Chronos灰度管理
class Chronos extends $pb.GeneratedMessage {
  factory Chronos({
    $core.String? md5,
    $core.String? file,
    $core.String? sign,
  }) {
    final result = Chronos._();
    if (md5 != null) result.md5 = md5;
    if (file != null) result.file = file;
    if (sign != null) result.sign = sign;
    return result;
  }

  Chronos._();

  factory Chronos.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Chronos()..mergeFromBuffer(data, registry);
  factory Chronos.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Chronos()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Chronos',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Chronos.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'md5')
    ..aOS(2, _omitFieldNames ? '' : 'file')
    ..aOS(3, _omitFieldNames ? '' : 'sign')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Chronos clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Chronos copyWith(void Function(Chronos) updates) =>
      super.copyWith((message) => updates(message as Chronos)) as Chronos;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Chronos() / Chronos.new instead')
  static Chronos create() => Chronos._();
  static $pb.GeneratedMessage $_createMessage() => Chronos._();
  @$core.override
  Chronos createEmptyInstance() => Chronos._();
  @$core.pragma('dart2js:noInline')
  static Chronos getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Chronos>(Chronos.$_createMessage);
  static Chronos? _defaultInstance;

  /// 资源包md5
  @$pb.TagNumber(1)
  $core.String get md5 => $_getSZ(0);
  @$pb.TagNumber(1)
  set md5($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMd5() => $_has(0);
  @$pb.TagNumber(1)
  void clearMd5() => $_clearField(1);

  /// 资源包
  @$pb.TagNumber(2)
  $core.String get file => $_getSZ(1);
  @$pb.TagNumber(2)
  set file($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFile() => $_has(1);
  @$pb.TagNumber(2)
  void clearFile() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sign => $_getSZ(2);
  @$pb.TagNumber(3)
  set sign($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSign() => $_has(2);
  @$pb.TagNumber(3)
  void clearSign() => $_clearField(3);
}

class ChronosPkgReq extends $pb.GeneratedMessage {
  factory ChronosPkgReq({
    $core.String? serviceKey,
    $core.String? engineVersion,
    $core.String? messageProtocol,
  }) {
    final result = ChronosPkgReq._();
    if (serviceKey != null) result.serviceKey = serviceKey;
    if (engineVersion != null) result.engineVersion = engineVersion;
    if (messageProtocol != null) result.messageProtocol = messageProtocol;
    return result;
  }

  ChronosPkgReq._();

  factory ChronosPkgReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChronosPkgReq()..mergeFromBuffer(data, registry);
  factory ChronosPkgReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChronosPkgReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChronosPkgReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ChronosPkgReq.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'serviceKey')
    ..aOS(2, _omitFieldNames ? '' : 'engineVersion')
    ..aOS(3, _omitFieldNames ? '' : 'messageProtocol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChronosPkgReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChronosPkgReq copyWith(void Function(ChronosPkgReq) updates) =>
      super.copyWith((message) => updates(message as ChronosPkgReq))
          as ChronosPkgReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChronosPkgReq() / ChronosPkgReq.new instead')
  static ChronosPkgReq create() => ChronosPkgReq._();
  static $pb.GeneratedMessage $_createMessage() => ChronosPkgReq._();
  @$core.override
  ChronosPkgReq createEmptyInstance() => ChronosPkgReq._();
  @$core.pragma('dart2js:noInline')
  static ChronosPkgReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChronosPkgReq>(
          ChronosPkgReq.$_createMessage);
  static ChronosPkgReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get serviceKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set serviceKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServiceKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearServiceKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get engineVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set engineVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEngineVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearEngineVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get messageProtocol => $_getSZ(2);
  @$pb.TagNumber(3)
  set messageProtocol($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessageProtocol() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessageProtocol() => $_clearField(3);
}

enum ClickActivitySeasonReq_OrderParam { reserve, favSeason, notSet }

/// 点击大型活动页预约-请求
class ClickActivitySeasonReq extends $pb.GeneratedMessage {
  factory ClickActivitySeasonReq({
    BizType? orderType,
    $core.String? spmid,
    BizReserveActivityParam? reserve,
    BizFavSeasonParam? favSeason,
    $fixnum.Int64? action,
  }) {
    final result = ClickActivitySeasonReq._();
    if (orderType != null) result.orderType = orderType;
    if (spmid != null) result.spmid = spmid;
    if (reserve != null) result.reserve = reserve;
    if (favSeason != null) result.favSeason = favSeason;
    if (action != null) result.action = action;
    return result;
  }

  ClickActivitySeasonReq._();

  factory ClickActivitySeasonReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClickActivitySeasonReq()..mergeFromBuffer(data, registry);
  factory ClickActivitySeasonReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClickActivitySeasonReq()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClickActivitySeasonReq_OrderParam>
      _ClickActivitySeasonReq_OrderParamByTag = {
    3: ClickActivitySeasonReq_OrderParam.reserve,
    4: ClickActivitySeasonReq_OrderParam.favSeason,
    0: ClickActivitySeasonReq_OrderParam.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClickActivitySeasonReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ClickActivitySeasonReq.$_createMessage)
    ..oo(0, [3, 4])
    ..aE<BizType>(1, _omitFieldNames ? '' : 'orderType',
        enumValues: BizType.values)
    ..aOS(2, _omitFieldNames ? '' : 'spmid')
    ..aOM<BizReserveActivityParam>(3, _omitFieldNames ? '' : 'reserve',
        subBuilder: BizReserveActivityParam.$_createMessage)
    ..aOM<BizFavSeasonParam>(4, _omitFieldNames ? '' : 'favSeason',
        subBuilder: BizFavSeasonParam.$_createMessage)
    ..aInt64(5, _omitFieldNames ? '' : 'action')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickActivitySeasonReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickActivitySeasonReq copyWith(
          void Function(ClickActivitySeasonReq) updates) =>
      super.copyWith((message) => updates(message as ClickActivitySeasonReq))
          as ClickActivitySeasonReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ClickActivitySeasonReq() / ClickActivitySeasonReq.new instead')
  static ClickActivitySeasonReq create() => ClickActivitySeasonReq._();
  static $pb.GeneratedMessage $_createMessage() => ClickActivitySeasonReq._();
  @$core.override
  ClickActivitySeasonReq createEmptyInstance() => ClickActivitySeasonReq._();
  @$core.pragma('dart2js:noInline')
  static ClickActivitySeasonReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClickActivitySeasonReq>(
          ClickActivitySeasonReq.$_createMessage);
  static ClickActivitySeasonReq? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  ClickActivitySeasonReq_OrderParam whichOrderParam() =>
      _ClickActivitySeasonReq_OrderParamByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearOrderParam() => $_clearField($_whichOneof(0));

  /// 预约类型
  @$pb.TagNumber(1)
  BizType get orderType => $_getN(0);
  @$pb.TagNumber(1)
  set orderType(BizType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOrderType() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrderType() => $_clearField(1);

  /// 当前页面spm
  @$pb.TagNumber(2)
  $core.String get spmid => $_getSZ(1);
  @$pb.TagNumber(2)
  set spmid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSpmid() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpmid() => $_clearField(2);

  /// 预约活动参数
  @$pb.TagNumber(3)
  BizReserveActivityParam get reserve => $_getN(2);
  @$pb.TagNumber(3)
  set reserve(BizReserveActivityParam value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReserve() => $_has(2);
  @$pb.TagNumber(3)
  void clearReserve() => $_clearField(3);
  @$pb.TagNumber(3)
  BizReserveActivityParam ensureReserve() => $_ensure(2);

  /// 收藏合集参数
  @$pb.TagNumber(4)
  BizFavSeasonParam get favSeason => $_getN(3);
  @$pb.TagNumber(4)
  set favSeason(BizFavSeasonParam value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFavSeason() => $_has(3);
  @$pb.TagNumber(4)
  void clearFavSeason() => $_clearField(4);
  @$pb.TagNumber(4)
  BizFavSeasonParam ensureFavSeason() => $_ensure(3);

  /// 操作
  /// 0:操作 1:取消操作
  @$pb.TagNumber(5)
  $fixnum.Int64 get action => $_getI64(4);
  @$pb.TagNumber(5)
  set action($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAction() => $_has(4);
  @$pb.TagNumber(5)
  void clearAction() => $_clearField(5);
}

/// 点击播放器卡片-响应
class ClickPlayerCardReply extends $pb.GeneratedMessage {
  factory ClickPlayerCardReply({
    $core.String? message,
  }) {
    final result = ClickPlayerCardReply._();
    if (message != null) result.message = message;
    return result;
  }

  ClickPlayerCardReply._();

  factory ClickPlayerCardReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClickPlayerCardReply()..mergeFromBuffer(data, registry);
  factory ClickPlayerCardReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClickPlayerCardReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClickPlayerCardReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ClickPlayerCardReply.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickPlayerCardReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickPlayerCardReply copyWith(void Function(ClickPlayerCardReply) updates) =>
      super.copyWith((message) => updates(message as ClickPlayerCardReply))
          as ClickPlayerCardReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ClickPlayerCardReply() / ClickPlayerCardReply.new instead')
  static ClickPlayerCardReply create() => ClickPlayerCardReply._();
  static $pb.GeneratedMessage $_createMessage() => ClickPlayerCardReply._();
  @$core.override
  ClickPlayerCardReply createEmptyInstance() => ClickPlayerCardReply._();
  @$core.pragma('dart2js:noInline')
  static ClickPlayerCardReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClickPlayerCardReply>(
          ClickPlayerCardReply.$_createMessage);
  static ClickPlayerCardReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
}

/// 点击播放器卡片-请求
class ClickPlayerCardReq extends $pb.GeneratedMessage {
  factory ClickPlayerCardReq({
    $fixnum.Int64? id,
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $fixnum.Int64? action,
    $core.String? spmid,
  }) {
    final result = ClickPlayerCardReq._();
    if (id != null) result.id = id;
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (action != null) result.action = action;
    if (spmid != null) result.spmid = spmid;
    return result;
  }

  ClickPlayerCardReq._();

  factory ClickPlayerCardReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClickPlayerCardReq()..mergeFromBuffer(data, registry);
  factory ClickPlayerCardReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClickPlayerCardReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClickPlayerCardReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ClickPlayerCardReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'aid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..aInt64(4, _omitFieldNames ? '' : 'action')
    ..aOS(5, _omitFieldNames ? '' : 'spmid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickPlayerCardReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickPlayerCardReq copyWith(void Function(ClickPlayerCardReq) updates) =>
      super.copyWith((message) => updates(message as ClickPlayerCardReq))
          as ClickPlayerCardReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ClickPlayerCardReq() / ClickPlayerCardReq.new instead')
  static ClickPlayerCardReq create() => ClickPlayerCardReq._();
  static $pb.GeneratedMessage $_createMessage() => ClickPlayerCardReq._();
  @$core.override
  ClickPlayerCardReq createEmptyInstance() => ClickPlayerCardReq._();
  @$core.pragma('dart2js:noInline')
  static ClickPlayerCardReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClickPlayerCardReq>(
          ClickPlayerCardReq.$_createMessage);
  static ClickPlayerCardReq? _defaultInstance;

  /// 卡片id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 稿件avid
  @$pb.TagNumber(2)
  $fixnum.Int64 get aid => $_getI64(1);
  @$pb.TagNumber(2)
  set aid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAid() => $_has(1);
  @$pb.TagNumber(2)
  void clearAid() => $_clearField(2);

  /// 视频cid
  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);

  /// 操作
  /// 0:操作 1:取消操作
  @$pb.TagNumber(4)
  $fixnum.Int64 get action => $_getI64(3);
  @$pb.TagNumber(4)
  set action($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);

  /// 当前页面spm
  @$pb.TagNumber(5)
  $core.String get spmid => $_getSZ(4);
  @$pb.TagNumber(5)
  set spmid($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSpmid() => $_has(4);
  @$pb.TagNumber(5)
  void clearSpmid() => $_clearField(5);
}

/// 广告
class CM extends $pb.GeneratedMessage {
  factory CM({
    $2.Any? sourceContent,
  }) {
    final result = CM._();
    if (sourceContent != null) result.sourceContent = sourceContent;
    return result;
  }

  CM._();

  factory CM.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CM()..mergeFromBuffer(data, registry);
  factory CM.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CM()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CM',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CM.$_createMessage)
    ..aOM<$2.Any>(1, _omitFieldNames ? '' : 'sourceContent',
        subBuilder: $2.Any.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CM clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CM copyWith(void Function(CM) updates) =>
      super.copyWith((message) => updates(message as CM)) as CM;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CM() / CM.new instead')
  static CM create() => CM._();
  static $pb.GeneratedMessage $_createMessage() => CM._();
  @$core.override
  CM createEmptyInstance() => CM._();
  @$core.pragma('dart2js:noInline')
  static CM getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CM>(CM.$_createMessage);
  static CM? _defaultInstance;

  /// 广告数据(需解包)
  @$pb.TagNumber(1)
  $2.Any get sourceContent => $_getN(0);
  @$pb.TagNumber(1)
  set sourceContent($2.Any value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceContent() => $_clearField(1);
  @$pb.TagNumber(1)
  $2.Any ensureSourceContent() => $_ensure(0);
}

/// 广告配置
class CMConfig extends $pb.GeneratedMessage {
  factory CMConfig({
    $2.Any? adsControl,
  }) {
    final result = CMConfig._();
    if (adsControl != null) result.adsControl = adsControl;
    return result;
  }

  CMConfig._();

  factory CMConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CMConfig()..mergeFromBuffer(data, registry);
  factory CMConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CMConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CMConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CMConfig.$_createMessage)
    ..aOM<$2.Any>(1, _omitFieldNames ? '' : 'adsControl',
        subBuilder: $2.Any.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CMConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CMConfig copyWith(void Function(CMConfig) updates) =>
      super.copyWith((message) => updates(message as CMConfig)) as CMConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CMConfig() / CMConfig.new instead')
  static CMConfig create() => CMConfig._();
  static $pb.GeneratedMessage $_createMessage() => CMConfig._();
  @$core.override
  CMConfig createEmptyInstance() => CMConfig._();
  @$core.pragma('dart2js:noInline')
  static CMConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CMConfig>(CMConfig.$_createMessage);
  static CMConfig? _defaultInstance;

  /// 广告配置数据(需要二次解包)
  @$pb.TagNumber(1)
  $2.Any get adsControl => $_getN(0);
  @$pb.TagNumber(1)
  set adsControl($2.Any value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAdsControl() => $_has(0);
  @$pb.TagNumber(1)
  void clearAdsControl() => $_clearField(1);
  @$pb.TagNumber(1)
  $2.Any ensureAdsControl() => $_ensure(0);
}

class CmIpad extends $pb.GeneratedMessage {
  factory CmIpad({
    CM? cm,
    $1.Author? author,
    $1.Stat? stat,
    $fixnum.Int64? duration,
    $fixnum.Int64? aid,
  }) {
    final result = CmIpad._();
    if (cm != null) result.cm = cm;
    if (author != null) result.author = author;
    if (stat != null) result.stat = stat;
    if (duration != null) result.duration = duration;
    if (aid != null) result.aid = aid;
    return result;
  }

  CmIpad._();

  factory CmIpad.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmIpad()..mergeFromBuffer(data, registry);
  factory CmIpad.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmIpad()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmIpad',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CmIpad.$_createMessage)
    ..aOM<CM>(1, _omitFieldNames ? '' : 'cm', subBuilder: CM.$_createMessage)
    ..aOM<$1.Author>(2, _omitFieldNames ? '' : 'author',
        subBuilder: $1.Author.$_createMessage)
    ..aOM<$1.Stat>(3, _omitFieldNames ? '' : 'stat',
        subBuilder: $1.Stat.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'duration')
    ..aInt64(5, _omitFieldNames ? '' : 'aid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmIpad clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmIpad copyWith(void Function(CmIpad) updates) =>
      super.copyWith((message) => updates(message as CmIpad)) as CmIpad;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmIpad() / CmIpad.new instead')
  static CmIpad create() => CmIpad._();
  static $pb.GeneratedMessage $_createMessage() => CmIpad._();
  @$core.override
  CmIpad createEmptyInstance() => CmIpad._();
  @$core.pragma('dart2js:noInline')
  static CmIpad getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmIpad>(CmIpad.$_createMessage);
  static CmIpad? _defaultInstance;

  @$pb.TagNumber(1)
  CM get cm => $_getN(0);
  @$pb.TagNumber(1)
  set cm(CM value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCm() => $_has(0);
  @$pb.TagNumber(1)
  void clearCm() => $_clearField(1);
  @$pb.TagNumber(1)
  CM ensureCm() => $_ensure(0);

  @$pb.TagNumber(2)
  $1.Author get author => $_getN(1);
  @$pb.TagNumber(2)
  set author($1.Author value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthor() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthor() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Author ensureAuthor() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.Stat get stat => $_getN(2);
  @$pb.TagNumber(3)
  set stat($1.Stat value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStat() => $_has(2);
  @$pb.TagNumber(3)
  void clearStat() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Stat ensureStat() => $_ensure(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get duration => $_getI64(3);
  @$pb.TagNumber(4)
  set duration($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearDuration() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get aid => $_getI64(4);
  @$pb.TagNumber(5)
  set aid($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAid() => $_has(4);
  @$pb.TagNumber(5)
  void clearAid() => $_clearField(5);
}

class CoinCustom extends $pb.GeneratedMessage {
  factory CoinCustom({
    $core.String? toast,
  }) {
    final result = CoinCustom._();
    if (toast != null) result.toast = toast;
    return result;
  }

  CoinCustom._();

  factory CoinCustom.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CoinCustom()..mergeFromBuffer(data, registry);
  factory CoinCustom.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CoinCustom()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CoinCustom',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CoinCustom.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'toast')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CoinCustom clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CoinCustom copyWith(void Function(CoinCustom) updates) =>
      super.copyWith((message) => updates(message as CoinCustom)) as CoinCustom;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CoinCustom() / CoinCustom.new instead')
  static CoinCustom create() => CoinCustom._();
  static $pb.GeneratedMessage $_createMessage() => CoinCustom._();
  @$core.override
  CoinCustom createEmptyInstance() => CoinCustom._();
  @$core.pragma('dart2js:noInline')
  static CoinCustom getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CoinCustom>(CoinCustom.$_createMessage);
  static CoinCustom? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get toast => $_getSZ(0);
  @$pb.TagNumber(1)
  set toast($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToast() => $_has(0);
  @$pb.TagNumber(1)
  void clearToast() => $_clearField(1);
}

/// 互动弹幕条目信息
class CommandDm extends $pb.GeneratedMessage {
  factory CommandDm({
    $fixnum.Int64? id,
    $fixnum.Int64? oid,
    $fixnum.Int64? mid,
    $core.String? command,
    $core.String? content,
    $core.int? progress,
    $core.String? ctime,
    $core.String? mtime,
    $core.String? extra,
    $core.String? idStr,
  }) {
    final result = CommandDm._();
    if (id != null) result.id = id;
    if (oid != null) result.oid = oid;
    if (mid != null) result.mid = mid;
    if (command != null) result.command = command;
    if (content != null) result.content = content;
    if (progress != null) result.progress = progress;
    if (ctime != null) result.ctime = ctime;
    if (mtime != null) result.mtime = mtime;
    if (extra != null) result.extra = extra;
    if (idStr != null) result.idStr = idStr;
    return result;
  }

  CommandDm._();

  factory CommandDm.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommandDm()..mergeFromBuffer(data, registry);
  factory CommandDm.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommandDm()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommandDm',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CommandDm.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'oid')
    ..aInt64(3, _omitFieldNames ? '' : 'mid')
    ..aOS(4, _omitFieldNames ? '' : 'command')
    ..aOS(5, _omitFieldNames ? '' : 'content')
    ..aI(6, _omitFieldNames ? '' : 'progress')
    ..aOS(7, _omitFieldNames ? '' : 'ctime')
    ..aOS(8, _omitFieldNames ? '' : 'mtime')
    ..aOS(9, _omitFieldNames ? '' : 'extra')
    ..aOS(10, _omitFieldNames ? '' : 'idStr')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandDm clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandDm copyWith(void Function(CommandDm) updates) =>
      super.copyWith((message) => updates(message as CommandDm)) as CommandDm;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommandDm() / CommandDm.new instead')
  static CommandDm create() => CommandDm._();
  static $pb.GeneratedMessage $_createMessage() => CommandDm._();
  @$core.override
  CommandDm createEmptyInstance() => CommandDm._();
  @$core.pragma('dart2js:noInline')
  static CommandDm getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommandDm>(CommandDm.$_createMessage);
  static CommandDm? _defaultInstance;

  /// 弹幕id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 对象视频cid
  @$pb.TagNumber(2)
  $fixnum.Int64 get oid => $_getI64(1);
  @$pb.TagNumber(2)
  set oid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOid() => $_has(1);
  @$pb.TagNumber(2)
  void clearOid() => $_clearField(2);

  /// 发送者mid
  @$pb.TagNumber(3)
  $fixnum.Int64 get mid => $_getI64(2);
  @$pb.TagNumber(3)
  set mid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMid() => $_has(2);
  @$pb.TagNumber(3)
  void clearMid() => $_clearField(3);

  /// 互动弹幕指令
  @$pb.TagNumber(4)
  $core.String get command => $_getSZ(3);
  @$pb.TagNumber(4)
  set command($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCommand() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommand() => $_clearField(4);

  /// 互动弹幕正文
  @$pb.TagNumber(5)
  $core.String get content => $_getSZ(4);
  @$pb.TagNumber(5)
  set content($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasContent() => $_has(4);
  @$pb.TagNumber(5)
  void clearContent() => $_clearField(5);

  /// 出现时间
  @$pb.TagNumber(6)
  $core.int get progress => $_getIZ(5);
  @$pb.TagNumber(6)
  set progress($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasProgress() => $_has(5);
  @$pb.TagNumber(6)
  void clearProgress() => $_clearField(6);

  /// 创建时间
  @$pb.TagNumber(7)
  $core.String get ctime => $_getSZ(6);
  @$pb.TagNumber(7)
  set ctime($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCtime() => $_has(6);
  @$pb.TagNumber(7)
  void clearCtime() => $_clearField(7);

  /// 发布时间
  @$pb.TagNumber(8)
  $core.String get mtime => $_getSZ(7);
  @$pb.TagNumber(8)
  set mtime($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMtime() => $_has(7);
  @$pb.TagNumber(8)
  void clearMtime() => $_clearField(8);

  /// 扩展json数据
  @$pb.TagNumber(9)
  $core.String get extra => $_getSZ(8);
  @$pb.TagNumber(9)
  set extra($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasExtra() => $_has(8);
  @$pb.TagNumber(9)
  void clearExtra() => $_clearField(9);

  /// 弹幕id str类型
  @$pb.TagNumber(10)
  $core.String get idStr => $_getSZ(9);
  @$pb.TagNumber(10)
  set idStr($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIdStr() => $_has(9);
  @$pb.TagNumber(10)
  void clearIdStr() => $_clearField(10);
}

class Config extends $pb.GeneratedMessage {
  factory Config({
    $core.String? relatesTitle,
    $core.int? relatesStyle,
    $core.int? relateGifExp,
    $core.int? endPageHalf,
    $core.int? endPageFull,
    $core.bool? autoSwindow,
    $core.bool? popupInfo,
    $core.String? abtestSmallWindow,
    $core.int? recThreePointStyle,
    $core.bool? isAbsoluteTime,
    $core.bool? newSwindow,
    $core.bool? relatesBiserial,
    ListenerConfig? listenerConf,
    $core.String? relatesFeedStyle,
    $core.bool? relatesFeedPopup,
    $core.bool? relatesHasNext,
    $core.int? localPlay,
    $core.bool? playStory,
    $core.bool? arcPlayStory,
    $core.String? storyIcon,
    $core.bool? landscapeStory,
    $core.bool? arcLandscapeStory,
    $core.String? landscapeIcon,
    $core.bool? showListenButton,
  }) {
    final result = Config._();
    if (relatesTitle != null) result.relatesTitle = relatesTitle;
    if (relatesStyle != null) result.relatesStyle = relatesStyle;
    if (relateGifExp != null) result.relateGifExp = relateGifExp;
    if (endPageHalf != null) result.endPageHalf = endPageHalf;
    if (endPageFull != null) result.endPageFull = endPageFull;
    if (autoSwindow != null) result.autoSwindow = autoSwindow;
    if (popupInfo != null) result.popupInfo = popupInfo;
    if (abtestSmallWindow != null) result.abtestSmallWindow = abtestSmallWindow;
    if (recThreePointStyle != null)
      result.recThreePointStyle = recThreePointStyle;
    if (isAbsoluteTime != null) result.isAbsoluteTime = isAbsoluteTime;
    if (newSwindow != null) result.newSwindow = newSwindow;
    if (relatesBiserial != null) result.relatesBiserial = relatesBiserial;
    if (listenerConf != null) result.listenerConf = listenerConf;
    if (relatesFeedStyle != null) result.relatesFeedStyle = relatesFeedStyle;
    if (relatesFeedPopup != null) result.relatesFeedPopup = relatesFeedPopup;
    if (relatesHasNext != null) result.relatesHasNext = relatesHasNext;
    if (localPlay != null) result.localPlay = localPlay;
    if (playStory != null) result.playStory = playStory;
    if (arcPlayStory != null) result.arcPlayStory = arcPlayStory;
    if (storyIcon != null) result.storyIcon = storyIcon;
    if (landscapeStory != null) result.landscapeStory = landscapeStory;
    if (arcLandscapeStory != null) result.arcLandscapeStory = arcLandscapeStory;
    if (landscapeIcon != null) result.landscapeIcon = landscapeIcon;
    if (showListenButton != null) result.showListenButton = showListenButton;
    return result;
  }

  Config._();

  factory Config.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Config()..mergeFromBuffer(data, registry);
  factory Config.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Config()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Config.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'relatesTitle')
    ..aI(2, _omitFieldNames ? '' : 'relatesStyle')
    ..aI(3, _omitFieldNames ? '' : 'relateGifExp')
    ..aI(4, _omitFieldNames ? '' : 'endPageHalf')
    ..aI(5, _omitFieldNames ? '' : 'endPageFull')
    ..aOB(6, _omitFieldNames ? '' : 'autoSwindow')
    ..aOB(7, _omitFieldNames ? '' : 'popupInfo')
    ..aOS(8, _omitFieldNames ? '' : 'abtestSmallWindow')
    ..aI(9, _omitFieldNames ? '' : 'recThreePointStyle')
    ..aOB(10, _omitFieldNames ? '' : 'isAbsoluteTime')
    ..aOB(11, _omitFieldNames ? '' : 'newSwindow')
    ..aOB(12, _omitFieldNames ? '' : 'relatesBiserial')
    ..aOM<ListenerConfig>(13, _omitFieldNames ? '' : 'listenerConf',
        subBuilder: ListenerConfig.$_createMessage)
    ..aOS(14, _omitFieldNames ? '' : 'relatesFeedStyle')
    ..aOB(15, _omitFieldNames ? '' : 'relatesFeedPopup')
    ..aOB(16, _omitFieldNames ? '' : 'relatesHasNext')
    ..aI(17, _omitFieldNames ? '' : 'localPlay')
    ..aOB(18, _omitFieldNames ? '' : 'playStory')
    ..aOB(19, _omitFieldNames ? '' : 'arcPlayStory')
    ..aOS(20, _omitFieldNames ? '' : 'storyIcon')
    ..aOB(21, _omitFieldNames ? '' : 'landscapeStory')
    ..aOB(22, _omitFieldNames ? '' : 'arcLandscapeStory')
    ..aOS(23, _omitFieldNames ? '' : 'landscapeIcon')
    ..aOB(24, _omitFieldNames ? '' : 'showListenButton')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config copyWith(void Function(Config) updates) =>
      super.copyWith((message) => updates(message as Config)) as Config;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Config() / Config.new instead')
  static Config create() => Config._();
  static $pb.GeneratedMessage $_createMessage() => Config._();
  @$core.override
  Config createEmptyInstance() => Config._();
  @$core.pragma('dart2js:noInline')
  static Config getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config>(Config.$_createMessage);
  static Config? _defaultInstance;

  /// 下方推荐项标题
  @$pb.TagNumber(1)
  $core.String get relatesTitle => $_getSZ(0);
  @$pb.TagNumber(1)
  set relatesTitle($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelatesTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelatesTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get relatesStyle => $_getIZ(1);
  @$pb.TagNumber(2)
  set relatesStyle($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelatesStyle() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelatesStyle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get relateGifExp => $_getIZ(2);
  @$pb.TagNumber(3)
  set relateGifExp($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRelateGifExp() => $_has(2);
  @$pb.TagNumber(3)
  void clearRelateGifExp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get endPageHalf => $_getIZ(3);
  @$pb.TagNumber(4)
  set endPageHalf($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndPageHalf() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndPageHalf() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get endPageFull => $_getIZ(4);
  @$pb.TagNumber(5)
  set endPageFull($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEndPageFull() => $_has(4);
  @$pb.TagNumber(5)
  void clearEndPageFull() => $_clearField(5);

  /// 退出是否自动小窗
  @$pb.TagNumber(6)
  $core.bool get autoSwindow => $_getBF(5);
  @$pb.TagNumber(6)
  set autoSwindow($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAutoSwindow() => $_has(5);
  @$pb.TagNumber(6)
  void clearAutoSwindow() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get popupInfo => $_getBF(6);
  @$pb.TagNumber(7)
  set popupInfo($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPopupInfo() => $_has(6);
  @$pb.TagNumber(7)
  void clearPopupInfo() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get abtestSmallWindow => $_getSZ(7);
  @$pb.TagNumber(8)
  set abtestSmallWindow($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAbtestSmallWindow() => $_has(7);
  @$pb.TagNumber(8)
  void clearAbtestSmallWindow() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get recThreePointStyle => $_getIZ(8);
  @$pb.TagNumber(9)
  set recThreePointStyle($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRecThreePointStyle() => $_has(8);
  @$pb.TagNumber(9)
  void clearRecThreePointStyle() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isAbsoluteTime => $_getBF(9);
  @$pb.TagNumber(10)
  set isAbsoluteTime($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsAbsoluteTime() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsAbsoluteTime() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get newSwindow => $_getBF(10);
  @$pb.TagNumber(11)
  set newSwindow($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNewSwindow() => $_has(10);
  @$pb.TagNumber(11)
  void clearNewSwindow() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get relatesBiserial => $_getBF(11);
  @$pb.TagNumber(12)
  set relatesBiserial($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasRelatesBiserial() => $_has(11);
  @$pb.TagNumber(12)
  void clearRelatesBiserial() => $_clearField(12);

  @$pb.TagNumber(13)
  ListenerConfig get listenerConf => $_getN(12);
  @$pb.TagNumber(13)
  set listenerConf(ListenerConfig value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasListenerConf() => $_has(12);
  @$pb.TagNumber(13)
  void clearListenerConf() => $_clearField(13);
  @$pb.TagNumber(13)
  ListenerConfig ensureListenerConf() => $_ensure(12);

  @$pb.TagNumber(14)
  $core.String get relatesFeedStyle => $_getSZ(13);
  @$pb.TagNumber(14)
  set relatesFeedStyle($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRelatesFeedStyle() => $_has(13);
  @$pb.TagNumber(14)
  void clearRelatesFeedStyle() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get relatesFeedPopup => $_getBF(14);
  @$pb.TagNumber(15)
  set relatesFeedPopup($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasRelatesFeedPopup() => $_has(14);
  @$pb.TagNumber(15)
  void clearRelatesFeedPopup() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get relatesHasNext => $_getBF(15);
  @$pb.TagNumber(16)
  set relatesHasNext($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasRelatesHasNext() => $_has(15);
  @$pb.TagNumber(16)
  void clearRelatesHasNext() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get localPlay => $_getIZ(16);
  @$pb.TagNumber(17)
  set localPlay($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasLocalPlay() => $_has(16);
  @$pb.TagNumber(17)
  void clearLocalPlay() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.bool get playStory => $_getBF(17);
  @$pb.TagNumber(18)
  set playStory($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(18)
  $core.bool hasPlayStory() => $_has(17);
  @$pb.TagNumber(18)
  void clearPlayStory() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.bool get arcPlayStory => $_getBF(18);
  @$pb.TagNumber(19)
  set arcPlayStory($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(19)
  $core.bool hasArcPlayStory() => $_has(18);
  @$pb.TagNumber(19)
  void clearArcPlayStory() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.String get storyIcon => $_getSZ(19);
  @$pb.TagNumber(20)
  set storyIcon($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasStoryIcon() => $_has(19);
  @$pb.TagNumber(20)
  void clearStoryIcon() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.bool get landscapeStory => $_getBF(20);
  @$pb.TagNumber(21)
  set landscapeStory($core.bool value) => $_setBool(20, value);
  @$pb.TagNumber(21)
  $core.bool hasLandscapeStory() => $_has(20);
  @$pb.TagNumber(21)
  void clearLandscapeStory() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.bool get arcLandscapeStory => $_getBF(21);
  @$pb.TagNumber(22)
  set arcLandscapeStory($core.bool value) => $_setBool(21, value);
  @$pb.TagNumber(22)
  $core.bool hasArcLandscapeStory() => $_has(21);
  @$pb.TagNumber(22)
  void clearArcLandscapeStory() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.String get landscapeIcon => $_getSZ(22);
  @$pb.TagNumber(23)
  set landscapeIcon($core.String value) => $_setString(22, value);
  @$pb.TagNumber(23)
  $core.bool hasLandscapeIcon() => $_has(22);
  @$pb.TagNumber(23)
  void clearLandscapeIcon() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.bool get showListenButton => $_getBF(23);
  @$pb.TagNumber(24)
  set showListenButton($core.bool value) => $_setBool(23, value);
  @$pb.TagNumber(24)
  $core.bool hasShowListenButton() => $_has(23);
  @$pb.TagNumber(24)
  void clearShowListenButton() => $_clearField(24);
}

class ContinuousPlayReply extends $pb.GeneratedMessage {
  factory ContinuousPlayReply({
    $core.Iterable<Relate>? relates,
  }) {
    final result = ContinuousPlayReply._();
    if (relates != null) result.relates.addAll(relates);
    return result;
  }

  ContinuousPlayReply._();

  factory ContinuousPlayReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinuousPlayReply()..mergeFromBuffer(data, registry);
  factory ContinuousPlayReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinuousPlayReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinuousPlayReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ContinuousPlayReply.$_createMessage)
    ..pPM<Relate>(1, _omitFieldNames ? '' : 'relates',
        subBuilder: Relate.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinuousPlayReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinuousPlayReply copyWith(void Function(ContinuousPlayReply) updates) =>
      super.copyWith((message) => updates(message as ContinuousPlayReply))
          as ContinuousPlayReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ContinuousPlayReply() / ContinuousPlayReply.new instead')
  static ContinuousPlayReply create() => ContinuousPlayReply._();
  static $pb.GeneratedMessage $_createMessage() => ContinuousPlayReply._();
  @$core.override
  ContinuousPlayReply createEmptyInstance() => ContinuousPlayReply._();
  @$core.pragma('dart2js:noInline')
  static ContinuousPlayReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContinuousPlayReply>(
          ContinuousPlayReply.$_createMessage);
  static ContinuousPlayReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Relate> get relates => $_getList(0);
}

class ContinuousPlayReq extends $pb.GeneratedMessage {
  factory ContinuousPlayReq({
    $fixnum.Int64? aid,
    $core.String? from,
    $core.String? trackid,
    $core.String? spmid,
    $core.String? fromSpmid,
    $core.int? autoplay,
    $3.PlayerArgs? playerArgs,
    $fixnum.Int64? deviceType,
    $core.String? sessionId,
    $fixnum.Int64? displayId,
  }) {
    final result = ContinuousPlayReq._();
    if (aid != null) result.aid = aid;
    if (from != null) result.from = from;
    if (trackid != null) result.trackid = trackid;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (autoplay != null) result.autoplay = autoplay;
    if (playerArgs != null) result.playerArgs = playerArgs;
    if (deviceType != null) result.deviceType = deviceType;
    if (sessionId != null) result.sessionId = sessionId;
    if (displayId != null) result.displayId = displayId;
    return result;
  }

  ContinuousPlayReq._();

  factory ContinuousPlayReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinuousPlayReq()..mergeFromBuffer(data, registry);
  factory ContinuousPlayReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContinuousPlayReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContinuousPlayReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ContinuousPlayReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'from')
    ..aOS(3, _omitFieldNames ? '' : 'trackid')
    ..aOS(4, _omitFieldNames ? '' : 'spmid')
    ..aOS(5, _omitFieldNames ? '' : 'fromSpmid')
    ..aI(6, _omitFieldNames ? '' : 'autoplay')
    ..aOM<$3.PlayerArgs>(7, _omitFieldNames ? '' : 'playerArgs',
        subBuilder: $3.PlayerArgs.$_createMessage)
    ..aInt64(8, _omitFieldNames ? '' : 'deviceType')
    ..aOS(9, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(10, _omitFieldNames ? '' : 'displayId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinuousPlayReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContinuousPlayReq copyWith(void Function(ContinuousPlayReq) updates) =>
      super.copyWith((message) => updates(message as ContinuousPlayReq))
          as ContinuousPlayReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContinuousPlayReq() / ContinuousPlayReq.new instead')
  static ContinuousPlayReq create() => ContinuousPlayReq._();
  static $pb.GeneratedMessage $_createMessage() => ContinuousPlayReq._();
  @$core.override
  ContinuousPlayReq createEmptyInstance() => ContinuousPlayReq._();
  @$core.pragma('dart2js:noInline')
  static ContinuousPlayReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContinuousPlayReq>(
          ContinuousPlayReq.$_createMessage);
  static ContinuousPlayReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get from => $_getSZ(1);
  @$pb.TagNumber(2)
  set from($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get trackid => $_getSZ(2);
  @$pb.TagNumber(3)
  set trackid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTrackid() => $_has(2);
  @$pb.TagNumber(3)
  void clearTrackid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get spmid => $_getSZ(3);
  @$pb.TagNumber(4)
  set spmid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpmid() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpmid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fromSpmid => $_getSZ(4);
  @$pb.TagNumber(5)
  set fromSpmid($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFromSpmid() => $_has(4);
  @$pb.TagNumber(5)
  void clearFromSpmid() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get autoplay => $_getIZ(5);
  @$pb.TagNumber(6)
  set autoplay($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAutoplay() => $_has(5);
  @$pb.TagNumber(6)
  void clearAutoplay() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.PlayerArgs get playerArgs => $_getN(6);
  @$pb.TagNumber(7)
  set playerArgs($3.PlayerArgs value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPlayerArgs() => $_has(6);
  @$pb.TagNumber(7)
  void clearPlayerArgs() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.PlayerArgs ensurePlayerArgs() => $_ensure(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get deviceType => $_getI64(7);
  @$pb.TagNumber(8)
  set deviceType($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDeviceType() => $_has(7);
  @$pb.TagNumber(8)
  void clearDeviceType() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get sessionId => $_getSZ(8);
  @$pb.TagNumber(9)
  set sessionId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionId() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionId() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get displayId => $_getI64(9);
  @$pb.TagNumber(10)
  set displayId($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDisplayId() => $_has(9);
  @$pb.TagNumber(10)
  void clearDisplayId() => $_clearField(10);
}

/// 契约卡
class ContractCard extends $pb.GeneratedMessage {
  factory ContractCard({
    $core.double? displayProgress,
    $fixnum.Int64? displayAccuracy,
    $fixnum.Int64? displayDuration,
    $core.int? showMode,
    $core.int? pageType,
    UpperInfos? upper,
    $core.int? isFollowDisplay,
    ContractText? text,
    $fixnum.Int64? followDisplayEndDuration,
    $core.int? isPlayDisplay,
    $core.int? isInteractDisplay,
    $core.bool? playDisplaySwitch,
  }) {
    final result = ContractCard._();
    if (displayProgress != null) result.displayProgress = displayProgress;
    if (displayAccuracy != null) result.displayAccuracy = displayAccuracy;
    if (displayDuration != null) result.displayDuration = displayDuration;
    if (showMode != null) result.showMode = showMode;
    if (pageType != null) result.pageType = pageType;
    if (upper != null) result.upper = upper;
    if (isFollowDisplay != null) result.isFollowDisplay = isFollowDisplay;
    if (text != null) result.text = text;
    if (followDisplayEndDuration != null)
      result.followDisplayEndDuration = followDisplayEndDuration;
    if (isPlayDisplay != null) result.isPlayDisplay = isPlayDisplay;
    if (isInteractDisplay != null) result.isInteractDisplay = isInteractDisplay;
    if (playDisplaySwitch != null) result.playDisplaySwitch = playDisplaySwitch;
    return result;
  }

  ContractCard._();

  factory ContractCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContractCard()..mergeFromBuffer(data, registry);
  factory ContractCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContractCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCard',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ContractCard.$_createMessage)
    ..aD(1, _omitFieldNames ? '' : 'displayProgress',
        fieldType: $pb.PbFieldType.OF)
    ..aInt64(2, _omitFieldNames ? '' : 'displayAccuracy')
    ..aInt64(3, _omitFieldNames ? '' : 'displayDuration')
    ..aI(4, _omitFieldNames ? '' : 'showMode')
    ..aI(5, _omitFieldNames ? '' : 'pageType')
    ..aOM<UpperInfos>(6, _omitFieldNames ? '' : 'upper',
        subBuilder: UpperInfos.$_createMessage)
    ..aI(7, _omitFieldNames ? '' : 'isFollowDisplay')
    ..aOM<ContractText>(8, _omitFieldNames ? '' : 'text',
        subBuilder: ContractText.$_createMessage)
    ..aInt64(9, _omitFieldNames ? '' : 'followDisplayEndDuration')
    ..aI(10, _omitFieldNames ? '' : 'isPlayDisplay')
    ..aI(11, _omitFieldNames ? '' : 'isInteractDisplay')
    ..aOB(12, _omitFieldNames ? '' : 'playDisplaySwitch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCard copyWith(void Function(ContractCard) updates) =>
      super.copyWith((message) => updates(message as ContractCard))
          as ContractCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContractCard() / ContractCard.new instead')
  static ContractCard create() => ContractCard._();
  static $pb.GeneratedMessage $_createMessage() => ContractCard._();
  @$core.override
  ContractCard createEmptyInstance() => ContractCard._();
  @$core.pragma('dart2js:noInline')
  static ContractCard getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContractCard>(
          ContractCard.$_createMessage);
  static ContractCard? _defaultInstance;

  /// 需要触发的播放进度百分比
  @$pb.TagNumber(1)
  $core.double get displayProgress => $_getN(0);
  @$pb.TagNumber(1)
  set displayProgress($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDisplayProgress() => $_has(0);
  @$pb.TagNumber(1)
  void clearDisplayProgress() => $_clearField(1);

  /// 触发位置的前后误差(单位ms)
  @$pb.TagNumber(2)
  $fixnum.Int64 get displayAccuracy => $_getI64(1);
  @$pb.TagNumber(2)
  set displayAccuracy($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayAccuracy() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayAccuracy() => $_clearField(2);

  /// 展示持续时间(单位ms)
  @$pb.TagNumber(3)
  $fixnum.Int64 get displayDuration => $_getI64(2);
  @$pb.TagNumber(3)
  set displayDuration($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayDuration() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayDuration() => $_clearField(3);

  /// 弹出模式
  /// 0: 原有模式 1: 半屏弹出 2: 全屏、半屏均弹出
  @$pb.TagNumber(4)
  $core.int get showMode => $_getIZ(3);
  @$pb.TagNumber(4)
  set showMode($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShowMode() => $_has(3);
  @$pb.TagNumber(4)
  void clearShowMode() => $_clearField(4);

  /// 提示页面
  /// 0: 原有页面 1: 6.23版本新页面
  @$pb.TagNumber(5)
  $core.int get pageType => $_getIZ(4);
  @$pb.TagNumber(5)
  set pageType($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPageType() => $_has(4);
  @$pb.TagNumber(5)
  void clearPageType() => $_clearField(5);

  /// UP主信息
  @$pb.TagNumber(6)
  UpperInfos get upper => $_getN(5);
  @$pb.TagNumber(6)
  set upper(UpperInfos value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasUpper() => $_has(5);
  @$pb.TagNumber(6)
  void clearUpper() => $_clearField(6);
  @$pb.TagNumber(6)
  UpperInfos ensureUpper() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.int get isFollowDisplay => $_getIZ(6);
  @$pb.TagNumber(7)
  set isFollowDisplay($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsFollowDisplay() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsFollowDisplay() => $_clearField(7);

  @$pb.TagNumber(8)
  ContractText get text => $_getN(7);
  @$pb.TagNumber(8)
  set text(ContractText value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasText() => $_has(7);
  @$pb.TagNumber(8)
  void clearText() => $_clearField(8);
  @$pb.TagNumber(8)
  ContractText ensureText() => $_ensure(7);

  @$pb.TagNumber(9)
  $fixnum.Int64 get followDisplayEndDuration => $_getI64(8);
  @$pb.TagNumber(9)
  set followDisplayEndDuration($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFollowDisplayEndDuration() => $_has(8);
  @$pb.TagNumber(9)
  void clearFollowDisplayEndDuration() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get isPlayDisplay => $_getIZ(9);
  @$pb.TagNumber(10)
  set isPlayDisplay($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsPlayDisplay() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsPlayDisplay() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get isInteractDisplay => $_getIZ(10);
  @$pb.TagNumber(11)
  set isInteractDisplay($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIsInteractDisplay() => $_has(10);
  @$pb.TagNumber(11)
  void clearIsInteractDisplay() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get playDisplaySwitch => $_getBF(11);
  @$pb.TagNumber(12)
  set playDisplaySwitch($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPlayDisplaySwitch() => $_has(11);
  @$pb.TagNumber(12)
  void clearPlayDisplaySwitch() => $_clearField(12);
}

class ContractText extends $pb.GeneratedMessage {
  factory ContractText({
    $core.String? title,
    $core.String? subtitle,
    $core.String? inlineTitle,
  }) {
    final result = ContractText._();
    if (title != null) result.title = title;
    if (subtitle != null) result.subtitle = subtitle;
    if (inlineTitle != null) result.inlineTitle = inlineTitle;
    return result;
  }

  ContractText._();

  factory ContractText.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContractText()..mergeFromBuffer(data, registry);
  factory ContractText.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContractText()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractText',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ContractText.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'subtitle')
    ..aOS(3, _omitFieldNames ? '' : 'inlineTitle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractText clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractText copyWith(void Function(ContractText) updates) =>
      super.copyWith((message) => updates(message as ContractText))
          as ContractText;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContractText() / ContractText.new instead')
  static ContractText create() => ContractText._();
  static $pb.GeneratedMessage $_createMessage() => ContractText._();
  @$core.override
  ContractText createEmptyInstance() => ContractText._();
  @$core.pragma('dart2js:noInline')
  static ContractText getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContractText>(
          ContractText.$_createMessage);
  static ContractText? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subtitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set subtitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubtitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubtitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get inlineTitle => $_getSZ(2);
  @$pb.TagNumber(3)
  set inlineTitle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInlineTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearInlineTitle() => $_clearField(3);
}

class CreativeContent extends $pb.GeneratedMessage {
  factory CreativeContent({
    $core.String? title,
    $core.String? description,
    $core.String? buttonTitle,
    $fixnum.Int64? videoId,
    $core.String? username,
    $core.String? imageUrl,
    $core.String? imageMd5,
    $core.String? logUrl,
    $core.String? logMd5,
    $core.String? url,
    $core.String? clickUrl,
    $core.String? showUrl,
  }) {
    final result = CreativeContent._();
    if (title != null) result.title = title;
    if (description != null) result.description = description;
    if (buttonTitle != null) result.buttonTitle = buttonTitle;
    if (videoId != null) result.videoId = videoId;
    if (username != null) result.username = username;
    if (imageUrl != null) result.imageUrl = imageUrl;
    if (imageMd5 != null) result.imageMd5 = imageMd5;
    if (logUrl != null) result.logUrl = logUrl;
    if (logMd5 != null) result.logMd5 = logMd5;
    if (url != null) result.url = url;
    if (clickUrl != null) result.clickUrl = clickUrl;
    if (showUrl != null) result.showUrl = showUrl;
    return result;
  }

  CreativeContent._();

  factory CreativeContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreativeContent()..mergeFromBuffer(data, registry);
  factory CreativeContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreativeContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreativeContent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CreativeContent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'buttonTitle')
    ..aInt64(4, _omitFieldNames ? '' : 'videoId')
    ..aOS(5, _omitFieldNames ? '' : 'username')
    ..aOS(6, _omitFieldNames ? '' : 'imageUrl')
    ..aOS(7, _omitFieldNames ? '' : 'imageMd5')
    ..aOS(8, _omitFieldNames ? '' : 'logUrl')
    ..aOS(9, _omitFieldNames ? '' : 'logMd5')
    ..aOS(10, _omitFieldNames ? '' : 'url')
    ..aOS(11, _omitFieldNames ? '' : 'clickUrl')
    ..aOS(12, _omitFieldNames ? '' : 'showUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreativeContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreativeContent copyWith(void Function(CreativeContent) updates) =>
      super.copyWith((message) => updates(message as CreativeContent))
          as CreativeContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CreativeContent() / CreativeContent.new instead')
  static CreativeContent create() => CreativeContent._();
  static $pb.GeneratedMessage $_createMessage() => CreativeContent._();
  @$core.override
  CreativeContent createEmptyInstance() => CreativeContent._();
  @$core.pragma('dart2js:noInline')
  static CreativeContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreativeContent>(
          CreativeContent.$_createMessage);
  static CreativeContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get buttonTitle => $_getSZ(2);
  @$pb.TagNumber(3)
  set buttonTitle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasButtonTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearButtonTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get videoId => $_getI64(3);
  @$pb.TagNumber(4)
  set videoId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVideoId() => $_has(3);
  @$pb.TagNumber(4)
  void clearVideoId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get username => $_getSZ(4);
  @$pb.TagNumber(5)
  set username($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUsername() => $_has(4);
  @$pb.TagNumber(5)
  void clearUsername() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get imageUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set imageUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImageUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearImageUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get imageMd5 => $_getSZ(6);
  @$pb.TagNumber(7)
  set imageMd5($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasImageMd5() => $_has(6);
  @$pb.TagNumber(7)
  void clearImageMd5() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get logUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set logUrl($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLogUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearLogUrl() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get logMd5 => $_getSZ(8);
  @$pb.TagNumber(9)
  set logMd5($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLogMd5() => $_has(8);
  @$pb.TagNumber(9)
  void clearLogMd5() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get url => $_getSZ(9);
  @$pb.TagNumber(10)
  set url($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasUrl() => $_has(9);
  @$pb.TagNumber(10)
  void clearUrl() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get clickUrl => $_getSZ(10);
  @$pb.TagNumber(11)
  set clickUrl($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasClickUrl() => $_has(10);
  @$pb.TagNumber(11)
  void clearClickUrl() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get showUrl => $_getSZ(11);
  @$pb.TagNumber(12)
  set showUrl($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasShowUrl() => $_has(11);
  @$pb.TagNumber(12)
  void clearShowUrl() => $_clearField(12);
}

/// 404页信息
class CustomConfig extends $pb.GeneratedMessage {
  factory CustomConfig({
    $core.String? redirectUrl,
  }) {
    final result = CustomConfig._();
    if (redirectUrl != null) result.redirectUrl = redirectUrl;
    return result;
  }

  CustomConfig._();

  factory CustomConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CustomConfig()..mergeFromBuffer(data, registry);
  factory CustomConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CustomConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: CustomConfig.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'redirectUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomConfig copyWith(void Function(CustomConfig) updates) =>
      super.copyWith((message) => updates(message as CustomConfig))
          as CustomConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CustomConfig() / CustomConfig.new instead')
  static CustomConfig create() => CustomConfig._();
  static $pb.GeneratedMessage $_createMessage() => CustomConfig._();
  @$core.override
  CustomConfig createEmptyInstance() => CustomConfig._();
  @$core.pragma('dart2js:noInline')
  static CustomConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CustomConfig>(
          CustomConfig.$_createMessage);
  static CustomConfig? _defaultInstance;

  /// 重定向页面url
  @$pb.TagNumber(1)
  $core.String get redirectUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set redirectUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRedirectUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearRedirectUrl() => $_clearField(1);
}

/// 特殊稿件简介
class DescV2 extends $pb.GeneratedMessage {
  factory DescV2({
    $core.String? text,
    DescType? type,
    $core.String? uri,
    $fixnum.Int64? rid,
  }) {
    final result = DescV2._();
    if (text != null) result.text = text;
    if (type != null) result.type = type;
    if (uri != null) result.uri = uri;
    if (rid != null) result.rid = rid;
    return result;
  }

  DescV2._();

  factory DescV2.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DescV2()..mergeFromBuffer(data, registry);
  factory DescV2.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DescV2()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DescV2',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: DescV2.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aE<DescType>(2, _omitFieldNames ? '' : 'type',
        enumValues: DescType.values)
    ..aOS(3, _omitFieldNames ? '' : 'uri')
    ..aInt64(4, _omitFieldNames ? '' : 'rid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DescV2 clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DescV2 copyWith(void Function(DescV2) updates) =>
      super.copyWith((message) => updates(message as DescV2)) as DescV2;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DescV2() / DescV2.new instead')
  static DescV2 create() => DescV2._();
  static $pb.GeneratedMessage $_createMessage() => DescV2._();
  @$core.override
  DescV2 createEmptyInstance() => DescV2._();
  @$core.pragma('dart2js:noInline')
  static DescV2 getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DescV2>(DescV2.$_createMessage);
  static DescV2? _defaultInstance;

  /// 文本内容
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// 文本类型
  @$pb.TagNumber(2)
  DescType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(DescType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  /// 点击跳转链接
  @$pb.TagNumber(3)
  $core.String get uri => $_getSZ(2);
  @$pb.TagNumber(3)
  set uri($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUri() => $_has(2);
  @$pb.TagNumber(3)
  void clearUri() => $_clearField(3);

  /// 资源ID
  @$pb.TagNumber(4)
  $fixnum.Int64 get rid => $_getI64(3);
  @$pb.TagNumber(4)
  set rid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRid() => $_has(3);
  @$pb.TagNumber(4)
  void clearRid() => $_clearField(4);
}

/// 不喜欢原因
class Dislike extends $pb.GeneratedMessage {
  factory Dislike({
    $core.String? title,
    $core.String? subtitle,
    $core.Iterable<DislikeReasons>? reasons,
  }) {
    final result = Dislike._();
    if (title != null) result.title = title;
    if (subtitle != null) result.subtitle = subtitle;
    if (reasons != null) result.reasons.addAll(reasons);
    return result;
  }

  Dislike._();

  factory Dislike.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Dislike()..mergeFromBuffer(data, registry);
  factory Dislike.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Dislike()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Dislike',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Dislike.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'subtitle')
    ..pPM<DislikeReasons>(3, _omitFieldNames ? '' : 'reasons',
        subBuilder: DislikeReasons.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Dislike clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Dislike copyWith(void Function(Dislike) updates) =>
      super.copyWith((message) => updates(message as Dislike)) as Dislike;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Dislike() / Dislike.new instead')
  static Dislike create() => Dislike._();
  static $pb.GeneratedMessage $_createMessage() => Dislike._();
  @$core.override
  Dislike createEmptyInstance() => Dislike._();
  @$core.pragma('dart2js:noInline')
  static Dislike getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Dislike>(Dislike.$_createMessage);
  static Dislike? _defaultInstance;

  /// 标题
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subtitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set subtitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubtitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubtitle() => $_clearField(2);

  /// 原因项列表
  @$pb.TagNumber(3)
  $pb.PbList<DislikeReasons> get reasons => $_getList(2);
}

/// 不喜欢原因项
class DislikeReasons extends $pb.GeneratedMessage {
  factory DislikeReasons({
    $fixnum.Int64? id,
    $fixnum.Int64? mid,
    $core.int? rid,
    $fixnum.Int64? tagId,
    $core.String? name,
  }) {
    final result = DislikeReasons._();
    if (id != null) result.id = id;
    if (mid != null) result.mid = mid;
    if (rid != null) result.rid = rid;
    if (tagId != null) result.tagId = tagId;
    if (name != null) result.name = name;
    return result;
  }

  DislikeReasons._();

  factory DislikeReasons.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DislikeReasons()..mergeFromBuffer(data, registry);
  factory DislikeReasons.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DislikeReasons()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DislikeReasons',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: DislikeReasons.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'mid')
    ..aI(3, _omitFieldNames ? '' : 'rid')
    ..aInt64(4, _omitFieldNames ? '' : 'tagId')
    ..aOS(5, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DislikeReasons clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DislikeReasons copyWith(void Function(DislikeReasons) updates) =>
      super.copyWith((message) => updates(message as DislikeReasons))
          as DislikeReasons;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DislikeReasons() / DislikeReasons.new instead')
  static DislikeReasons create() => DislikeReasons._();
  static $pb.GeneratedMessage $_createMessage() => DislikeReasons._();
  @$core.override
  DislikeReasons createEmptyInstance() => DislikeReasons._();
  @$core.pragma('dart2js:noInline')
  static DislikeReasons getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DislikeReasons>(
          DislikeReasons.$_createMessage);
  static DislikeReasons? _defaultInstance;

  /// 类型
  /// 1:全部类型 3:TAG 4:UP主
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 相关UP主mid
  @$pb.TagNumber(2)
  $fixnum.Int64 get mid => $_getI64(1);
  @$pb.TagNumber(2)
  set mid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMid() => $_has(1);
  @$pb.TagNumber(2)
  void clearMid() => $_clearField(2);

  /// 相关分区tid
  @$pb.TagNumber(3)
  $core.int get rid => $_getIZ(2);
  @$pb.TagNumber(3)
  set rid($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRid() => $_has(2);
  @$pb.TagNumber(3)
  void clearRid() => $_clearField(3);

  /// 相关TAG id
  @$pb.TagNumber(4)
  $fixnum.Int64 get tagId => $_getI64(3);
  @$pb.TagNumber(4)
  set tagId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTagId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTagId() => $_clearField(4);

  /// 相关名称
  @$pb.TagNumber(5)
  $core.String get name => $_getSZ(4);
  @$pb.TagNumber(5)
  set name($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasName() => $_has(4);
  @$pb.TagNumber(5)
  void clearName() => $_clearField(5);
}

/// 分P弹幕信息
class DM extends $pb.GeneratedMessage {
  factory DM({
    $core.bool? closed,
    $core.bool? realName,
    $fixnum.Int64? count,
  }) {
    final result = DM._();
    if (closed != null) result.closed = closed;
    if (realName != null) result.realName = realName;
    if (count != null) result.count = count;
    return result;
  }

  DM._();

  factory DM.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DM()..mergeFromBuffer(data, registry);
  factory DM.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DM()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DM',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: DM.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'closed')
    ..aOB(2, _omitFieldNames ? '' : 'realName')
    ..aInt64(3, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DM clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DM copyWith(void Function(DM) updates) =>
      super.copyWith((message) => updates(message as DM)) as DM;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DM() / DM.new instead')
  static DM create() => DM._();
  static $pb.GeneratedMessage $_createMessage() => DM._();
  @$core.override
  DM createEmptyInstance() => DM._();
  @$core.pragma('dart2js:noInline')
  static DM getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DM>(DM.$_createMessage);
  static DM? _defaultInstance;

  /// 分P是否关闭弹幕
  /// 0:正常 1:关闭
  @$pb.TagNumber(1)
  $core.bool get closed => $_getBF(0);
  @$pb.TagNumber(1)
  set closed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClosed() => $_has(0);
  @$pb.TagNumber(1)
  void clearClosed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get realName => $_getBF(1);
  @$pb.TagNumber(2)
  set realName($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealName() => $_clearField(2);

  /// 分P弹幕总数
  @$pb.TagNumber(3)
  $fixnum.Int64 get count => $_getI64(2);
  @$pb.TagNumber(3)
  set count($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearCount() => $_clearField(3);
}

/// 充电排行信息
class ElecRank extends $pb.GeneratedMessage {
  factory ElecRank({
    $core.Iterable<ElecRankItem>? list,
    $fixnum.Int64? count,
    $core.String? text,
  }) {
    final result = ElecRank._();
    if (list != null) result.list.addAll(list);
    if (count != null) result.count = count;
    if (text != null) result.text = text;
    return result;
  }

  ElecRank._();

  factory ElecRank.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ElecRank()..mergeFromBuffer(data, registry);
  factory ElecRank.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ElecRank()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ElecRank',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ElecRank.$_createMessage)
    ..pPM<ElecRankItem>(1, _omitFieldNames ? '' : 'list',
        subBuilder: ElecRankItem.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ElecRank clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ElecRank copyWith(void Function(ElecRank) updates) =>
      super.copyWith((message) => updates(message as ElecRank)) as ElecRank;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ElecRank() / ElecRank.new instead')
  static ElecRank create() => ElecRank._();
  static $pb.GeneratedMessage $_createMessage() => ElecRank._();
  @$core.override
  ElecRank createEmptyInstance() => ElecRank._();
  @$core.pragma('dart2js:noInline')
  static ElecRank getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ElecRank>(ElecRank.$_createMessage);
  static ElecRank? _defaultInstance;

  /// 充电排行列表
  @$pb.TagNumber(1)
  $pb.PbList<ElecRankItem> get list => $_getList(0);

  /// 充电用户数
  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

/// 充电用户信息
class ElecRankItem extends $pb.GeneratedMessage {
  factory ElecRankItem({
    $core.String? avatar,
    $core.String? nickname,
    $core.String? message,
    $fixnum.Int64? mid,
  }) {
    final result = ElecRankItem._();
    if (avatar != null) result.avatar = avatar;
    if (nickname != null) result.nickname = nickname;
    if (message != null) result.message = message;
    if (mid != null) result.mid = mid;
    return result;
  }

  ElecRankItem._();

  factory ElecRankItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ElecRankItem()..mergeFromBuffer(data, registry);
  factory ElecRankItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ElecRankItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ElecRankItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ElecRankItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'avatar')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..aInt64(4, _omitFieldNames ? '' : 'mid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ElecRankItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ElecRankItem copyWith(void Function(ElecRankItem) updates) =>
      super.copyWith((message) => updates(message as ElecRankItem))
          as ElecRankItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ElecRankItem() / ElecRankItem.new instead')
  static ElecRankItem create() => ElecRankItem._();
  static $pb.GeneratedMessage $_createMessage() => ElecRankItem._();
  @$core.override
  ElecRankItem createEmptyInstance() => ElecRankItem._();
  @$core.pragma('dart2js:noInline')
  static ElecRankItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ElecRankItem>(
          ElecRankItem.$_createMessage);
  static ElecRankItem? _defaultInstance;

  /// 用户头像url
  @$pb.TagNumber(1)
  $core.String get avatar => $_getSZ(0);
  @$pb.TagNumber(1)
  set avatar($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAvatar() => $_has(0);
  @$pb.TagNumber(1)
  void clearAvatar() => $_clearField(1);

  /// 用户昵称
  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => $_clearField(2);

  /// 充电留言
  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  /// 用户mid
  @$pb.TagNumber(4)
  $fixnum.Int64 get mid => $_getI64(3);
  @$pb.TagNumber(4)
  set mid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMid() => $_has(3);
  @$pb.TagNumber(4)
  void clearMid() => $_clearField(4);
}

/// 视频合集单话信息
class Episode extends $pb.GeneratedMessage {
  factory Episode({
    $fixnum.Int64? id,
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $core.String? title,
    $core.String? cover,
    $core.String? coverRightText,
    $1.Page? page,
    $1.Stat? stat,
    $core.String? bvid,
    $1.Author? author,
    $core.String? authorDesc,
    BadgeStyle? badgeStyle,
    $core.bool? needPay,
    $core.bool? episodePay,
    $core.bool? freeWatch,
    $core.String? firstFrame,
  }) {
    final result = Episode._();
    if (id != null) result.id = id;
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (title != null) result.title = title;
    if (cover != null) result.cover = cover;
    if (coverRightText != null) result.coverRightText = coverRightText;
    if (page != null) result.page = page;
    if (stat != null) result.stat = stat;
    if (bvid != null) result.bvid = bvid;
    if (author != null) result.author = author;
    if (authorDesc != null) result.authorDesc = authorDesc;
    if (badgeStyle != null) result.badgeStyle = badgeStyle;
    if (needPay != null) result.needPay = needPay;
    if (episodePay != null) result.episodePay = episodePay;
    if (freeWatch != null) result.freeWatch = freeWatch;
    if (firstFrame != null) result.firstFrame = firstFrame;
    return result;
  }

  Episode._();

  factory Episode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Episode()..mergeFromBuffer(data, registry);
  factory Episode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Episode()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Episode',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Episode.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'aid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'cover')
    ..aOS(6, _omitFieldNames ? '' : 'coverRightText',
        protoName: 'coverRightText')
    ..aOM<$1.Page>(7, _omitFieldNames ? '' : 'page',
        subBuilder: $1.Page.$_createMessage)
    ..aOM<$1.Stat>(8, _omitFieldNames ? '' : 'stat',
        subBuilder: $1.Stat.$_createMessage)
    ..aOS(9, _omitFieldNames ? '' : 'bvid')
    ..aOM<$1.Author>(10, _omitFieldNames ? '' : 'author',
        subBuilder: $1.Author.$_createMessage)
    ..aOS(11, _omitFieldNames ? '' : 'authorDesc')
    ..aOM<BadgeStyle>(12, _omitFieldNames ? '' : 'badgeStyle',
        subBuilder: BadgeStyle.$_createMessage)
    ..aOB(13, _omitFieldNames ? '' : 'needPay')
    ..aOB(14, _omitFieldNames ? '' : 'episodePay')
    ..aOB(15, _omitFieldNames ? '' : 'freeWatch')
    ..aOS(16, _omitFieldNames ? '' : 'firstFrame')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Episode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Episode copyWith(void Function(Episode) updates) =>
      super.copyWith((message) => updates(message as Episode)) as Episode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Episode() / Episode.new instead')
  static Episode create() => Episode._();
  static $pb.GeneratedMessage $_createMessage() => Episode._();
  @$core.override
  Episode createEmptyInstance() => Episode._();
  @$core.pragma('dart2js:noInline')
  static Episode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Episode>(Episode.$_createMessage);
  static Episode? _defaultInstance;

  /// 合集单话id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 稿件avid
  @$pb.TagNumber(2)
  $fixnum.Int64 get aid => $_getI64(1);
  @$pb.TagNumber(2)
  set aid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAid() => $_has(1);
  @$pb.TagNumber(2)
  void clearAid() => $_clearField(2);

  /// 视频1P cid
  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);

  /// 稿件标题
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  /// 稿件封面url
  @$pb.TagNumber(5)
  $core.String get cover => $_getSZ(4);
  @$pb.TagNumber(5)
  set cover($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCover() => $_has(4);
  @$pb.TagNumber(5)
  void clearCover() => $_clearField(5);

  /// 投稿时间显示文案
  @$pb.TagNumber(6)
  $core.String get coverRightText => $_getSZ(5);
  @$pb.TagNumber(6)
  set coverRightText($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCoverRightText() => $_has(5);
  @$pb.TagNumber(6)
  void clearCoverRightText() => $_clearField(6);

  /// 视频分P信息
  @$pb.TagNumber(7)
  $1.Page get page => $_getN(6);
  @$pb.TagNumber(7)
  set page($1.Page value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPage() => $_has(6);
  @$pb.TagNumber(7)
  void clearPage() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.Page ensurePage() => $_ensure(6);

  /// 视频状态数
  @$pb.TagNumber(8)
  $1.Stat get stat => $_getN(7);
  @$pb.TagNumber(8)
  set stat($1.Stat value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasStat() => $_has(7);
  @$pb.TagNumber(8)
  void clearStat() => $_clearField(8);
  @$pb.TagNumber(8)
  $1.Stat ensureStat() => $_ensure(7);

  /// 稿件bvid
  @$pb.TagNumber(9)
  $core.String get bvid => $_getSZ(8);
  @$pb.TagNumber(9)
  set bvid($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBvid() => $_has(8);
  @$pb.TagNumber(9)
  void clearBvid() => $_clearField(9);

  /// 稿件UP主信息
  @$pb.TagNumber(10)
  $1.Author get author => $_getN(9);
  @$pb.TagNumber(10)
  set author($1.Author value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasAuthor() => $_has(9);
  @$pb.TagNumber(10)
  void clearAuthor() => $_clearField(10);
  @$pb.TagNumber(10)
  $1.Author ensureAuthor() => $_ensure(9);

  @$pb.TagNumber(11)
  $core.String get authorDesc => $_getSZ(10);
  @$pb.TagNumber(11)
  set authorDesc($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAuthorDesc() => $_has(10);
  @$pb.TagNumber(11)
  void clearAuthorDesc() => $_clearField(11);

  @$pb.TagNumber(12)
  BadgeStyle get badgeStyle => $_getN(11);
  @$pb.TagNumber(12)
  set badgeStyle(BadgeStyle value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasBadgeStyle() => $_has(11);
  @$pb.TagNumber(12)
  void clearBadgeStyle() => $_clearField(12);
  @$pb.TagNumber(12)
  BadgeStyle ensureBadgeStyle() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.bool get needPay => $_getBF(12);
  @$pb.TagNumber(13)
  set needPay($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasNeedPay() => $_has(12);
  @$pb.TagNumber(13)
  void clearNeedPay() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get episodePay => $_getBF(13);
  @$pb.TagNumber(14)
  set episodePay($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEpisodePay() => $_has(13);
  @$pb.TagNumber(14)
  void clearEpisodePay() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get freeWatch => $_getBF(14);
  @$pb.TagNumber(15)
  set freeWatch($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasFreeWatch() => $_has(14);
  @$pb.TagNumber(15)
  void clearFreeWatch() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get firstFrame => $_getSZ(15);
  @$pb.TagNumber(16)
  set firstFrame($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasFirstFrame() => $_has(15);
  @$pb.TagNumber(16)
  void clearFirstFrame() => $_clearField(16);
}

/// 播放器卡片曝光-请求
class ExposePlayerCardReq extends $pb.GeneratedMessage {
  factory ExposePlayerCardReq({
    PlayerCardType? cardType,
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $core.String? spmid,
  }) {
    final result = ExposePlayerCardReq._();
    if (cardType != null) result.cardType = cardType;
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (spmid != null) result.spmid = spmid;
    return result;
  }

  ExposePlayerCardReq._();

  factory ExposePlayerCardReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExposePlayerCardReq()..mergeFromBuffer(data, registry);
  factory ExposePlayerCardReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExposePlayerCardReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExposePlayerCardReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ExposePlayerCardReq.$_createMessage)
    ..aE<PlayerCardType>(1, _omitFieldNames ? '' : 'cardType',
        enumValues: PlayerCardType.values)
    ..aInt64(2, _omitFieldNames ? '' : 'aid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..aOS(4, _omitFieldNames ? '' : 'spmid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExposePlayerCardReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExposePlayerCardReq copyWith(void Function(ExposePlayerCardReq) updates) =>
      super.copyWith((message) => updates(message as ExposePlayerCardReq))
          as ExposePlayerCardReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ExposePlayerCardReq() / ExposePlayerCardReq.new instead')
  static ExposePlayerCardReq create() => ExposePlayerCardReq._();
  static $pb.GeneratedMessage $_createMessage() => ExposePlayerCardReq._();
  @$core.override
  ExposePlayerCardReq createEmptyInstance() => ExposePlayerCardReq._();
  @$core.pragma('dart2js:noInline')
  static ExposePlayerCardReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExposePlayerCardReq>(
          ExposePlayerCardReq.$_createMessage);
  static ExposePlayerCardReq? _defaultInstance;

  /// 卡片类型
  @$pb.TagNumber(1)
  PlayerCardType get cardType => $_getN(0);
  @$pb.TagNumber(1)
  set cardType(PlayerCardType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCardType() => $_has(0);
  @$pb.TagNumber(1)
  void clearCardType() => $_clearField(1);

  /// 稿件avid
  @$pb.TagNumber(2)
  $fixnum.Int64 get aid => $_getI64(1);
  @$pb.TagNumber(2)
  set aid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAid() => $_has(1);
  @$pb.TagNumber(2)
  void clearAid() => $_clearField(2);

  /// 视频cid
  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);

  /// 当前页面spm
  @$pb.TagNumber(4)
  $core.String get spmid => $_getSZ(3);
  @$pb.TagNumber(4)
  set spmid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpmid() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpmid() => $_clearField(4);
}

class FeedViewItem extends $pb.GeneratedMessage {
  factory FeedViewItem({
    ViewReply? view,
    $core.String? goto,
    $core.String? uri,
    $core.String? trackId,
  }) {
    final result = FeedViewItem._();
    if (view != null) result.view = view;
    if (goto != null) result.goto = goto;
    if (uri != null) result.uri = uri;
    if (trackId != null) result.trackId = trackId;
    return result;
  }

  FeedViewItem._();

  factory FeedViewItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FeedViewItem()..mergeFromBuffer(data, registry);
  factory FeedViewItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FeedViewItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FeedViewItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: FeedViewItem.$_createMessage)
    ..aOM<ViewReply>(1, _omitFieldNames ? '' : 'view',
        subBuilder: ViewReply.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'goto')
    ..aOS(3, _omitFieldNames ? '' : 'uri')
    ..aOS(4, _omitFieldNames ? '' : 'trackId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedViewItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedViewItem copyWith(void Function(FeedViewItem) updates) =>
      super.copyWith((message) => updates(message as FeedViewItem))
          as FeedViewItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FeedViewItem() / FeedViewItem.new instead')
  static FeedViewItem create() => FeedViewItem._();
  static $pb.GeneratedMessage $_createMessage() => FeedViewItem._();
  @$core.override
  FeedViewItem createEmptyInstance() => FeedViewItem._();
  @$core.pragma('dart2js:noInline')
  static FeedViewItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FeedViewItem>(
          FeedViewItem.$_createMessage);
  static FeedViewItem? _defaultInstance;

  @$pb.TagNumber(1)
  ViewReply get view => $_getN(0);
  @$pb.TagNumber(1)
  set view(ViewReply value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasView() => $_has(0);
  @$pb.TagNumber(1)
  void clearView() => $_clearField(1);
  @$pb.TagNumber(1)
  ViewReply ensureView() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get goto => $_getSZ(1);
  @$pb.TagNumber(2)
  set goto($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGoto() => $_has(1);
  @$pb.TagNumber(2)
  void clearGoto() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get uri => $_getSZ(2);
  @$pb.TagNumber(3)
  set uri($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUri() => $_has(2);
  @$pb.TagNumber(3)
  void clearUri() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get trackId => $_getSZ(3);
  @$pb.TagNumber(4)
  set trackId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTrackId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrackId() => $_clearField(4);
}

class FeedViewReply extends $pb.GeneratedMessage {
  factory FeedViewReply({
    $core.Iterable<FeedViewItem>? list,
    $core.bool? hasNext,
  }) {
    final result = FeedViewReply._();
    if (list != null) result.list.addAll(list);
    if (hasNext != null) result.hasNext = hasNext;
    return result;
  }

  FeedViewReply._();

  factory FeedViewReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FeedViewReply()..mergeFromBuffer(data, registry);
  factory FeedViewReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FeedViewReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FeedViewReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: FeedViewReply.$_createMessage)
    ..pPM<FeedViewItem>(1, _omitFieldNames ? '' : 'list',
        subBuilder: FeedViewItem.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'hasNext')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedViewReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedViewReply copyWith(void Function(FeedViewReply) updates) =>
      super.copyWith((message) => updates(message as FeedViewReply))
          as FeedViewReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FeedViewReply() / FeedViewReply.new instead')
  static FeedViewReply create() => FeedViewReply._();
  static $pb.GeneratedMessage $_createMessage() => FeedViewReply._();
  @$core.override
  FeedViewReply createEmptyInstance() => FeedViewReply._();
  @$core.pragma('dart2js:noInline')
  static FeedViewReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FeedViewReply>(
          FeedViewReply.$_createMessage);
  static FeedViewReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FeedViewItem> get list => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasNext => $_getBF(1);
  @$pb.TagNumber(2)
  set hasNext($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasNext() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasNext() => $_clearField(2);
}

class FeedViewReq extends $pb.GeneratedMessage {
  factory FeedViewReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $core.String? from,
    $core.String? spmid,
    $core.String? fromSpmid,
    $3.PlayerArgs? playerArgs,
    $fixnum.Int64? displayId,
    $core.String? sessionId,
    $core.String? pageVersion,
    $core.String? fromTrackId,
  }) {
    final result = FeedViewReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (from != null) result.from = from;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (playerArgs != null) result.playerArgs = playerArgs;
    if (displayId != null) result.displayId = displayId;
    if (sessionId != null) result.sessionId = sessionId;
    if (pageVersion != null) result.pageVersion = pageVersion;
    if (fromTrackId != null) result.fromTrackId = fromTrackId;
    return result;
  }

  FeedViewReq._();

  factory FeedViewReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FeedViewReq()..mergeFromBuffer(data, registry);
  factory FeedViewReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FeedViewReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FeedViewReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: FeedViewReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aOS(3, _omitFieldNames ? '' : 'from')
    ..aOS(4, _omitFieldNames ? '' : 'spmid')
    ..aOS(5, _omitFieldNames ? '' : 'fromSpmid')
    ..aOM<$3.PlayerArgs>(6, _omitFieldNames ? '' : 'playerArgs',
        subBuilder: $3.PlayerArgs.$_createMessage)
    ..aInt64(7, _omitFieldNames ? '' : 'displayId')
    ..aOS(8, _omitFieldNames ? '' : 'sessionId')
    ..aOS(9, _omitFieldNames ? '' : 'pageVersion')
    ..aOS(10, _omitFieldNames ? '' : 'fromTrackId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedViewReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedViewReq copyWith(void Function(FeedViewReq) updates) =>
      super.copyWith((message) => updates(message as FeedViewReq))
          as FeedViewReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FeedViewReq() / FeedViewReq.new instead')
  static FeedViewReq create() => FeedViewReq._();
  static $pb.GeneratedMessage $_createMessage() => FeedViewReq._();
  @$core.override
  FeedViewReq createEmptyInstance() => FeedViewReq._();
  @$core.pragma('dart2js:noInline')
  static FeedViewReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FeedViewReq>(
          FeedViewReq.$_createMessage);
  static FeedViewReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get from => $_getSZ(2);
  @$pb.TagNumber(3)
  set from($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get spmid => $_getSZ(3);
  @$pb.TagNumber(4)
  set spmid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpmid() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpmid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fromSpmid => $_getSZ(4);
  @$pb.TagNumber(5)
  set fromSpmid($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFromSpmid() => $_has(4);
  @$pb.TagNumber(5)
  void clearFromSpmid() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.PlayerArgs get playerArgs => $_getN(5);
  @$pb.TagNumber(6)
  set playerArgs($3.PlayerArgs value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlayerArgs() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlayerArgs() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.PlayerArgs ensurePlayerArgs() => $_ensure(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get displayId => $_getI64(6);
  @$pb.TagNumber(7)
  set displayId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDisplayId() => $_has(6);
  @$pb.TagNumber(7)
  void clearDisplayId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sessionId => $_getSZ(7);
  @$pb.TagNumber(8)
  set sessionId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSessionId() => $_has(7);
  @$pb.TagNumber(8)
  void clearSessionId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get pageVersion => $_getSZ(8);
  @$pb.TagNumber(9)
  set pageVersion($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPageVersion() => $_has(8);
  @$pb.TagNumber(9)
  void clearPageVersion() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get fromTrackId => $_getSZ(9);
  @$pb.TagNumber(10)
  set fromTrackId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasFromTrackId() => $_has(9);
  @$pb.TagNumber(10)
  void clearFromTrackId() => $_clearField(10);
}

class GetArcsPlayerReply extends $pb.GeneratedMessage {
  factory GetArcsPlayerReply({
    $core.Iterable<ArcsPlayer>? arcsPlayer,
  }) {
    final result = GetArcsPlayerReply._();
    if (arcsPlayer != null) result.arcsPlayer.addAll(arcsPlayer);
    return result;
  }

  GetArcsPlayerReply._();

  factory GetArcsPlayerReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetArcsPlayerReply()..mergeFromBuffer(data, registry);
  factory GetArcsPlayerReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetArcsPlayerReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetArcsPlayerReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: GetArcsPlayerReply.$_createMessage)
    ..pPM<ArcsPlayer>(1, _omitFieldNames ? '' : 'arcsPlayer',
        subBuilder: ArcsPlayer.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArcsPlayerReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArcsPlayerReply copyWith(void Function(GetArcsPlayerReply) updates) =>
      super.copyWith((message) => updates(message as GetArcsPlayerReply))
          as GetArcsPlayerReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetArcsPlayerReply() / GetArcsPlayerReply.new instead')
  static GetArcsPlayerReply create() => GetArcsPlayerReply._();
  static $pb.GeneratedMessage $_createMessage() => GetArcsPlayerReply._();
  @$core.override
  GetArcsPlayerReply createEmptyInstance() => GetArcsPlayerReply._();
  @$core.pragma('dart2js:noInline')
  static GetArcsPlayerReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetArcsPlayerReply>(
          GetArcsPlayerReply.$_createMessage);
  static GetArcsPlayerReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ArcsPlayer> get arcsPlayer => $_getList(0);
}

class GetArcsPlayerReq extends $pb.GeneratedMessage {
  factory GetArcsPlayerReq({
    $core.Iterable<PlayAv>? playAvs,
    $3.PlayerArgs? playerArgs,
  }) {
    final result = GetArcsPlayerReq._();
    if (playAvs != null) result.playAvs.addAll(playAvs);
    if (playerArgs != null) result.playerArgs = playerArgs;
    return result;
  }

  GetArcsPlayerReq._();

  factory GetArcsPlayerReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetArcsPlayerReq()..mergeFromBuffer(data, registry);
  factory GetArcsPlayerReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetArcsPlayerReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetArcsPlayerReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: GetArcsPlayerReq.$_createMessage)
    ..pPM<PlayAv>(1, _omitFieldNames ? '' : 'playAvs',
        subBuilder: PlayAv.$_createMessage)
    ..aOM<$3.PlayerArgs>(2, _omitFieldNames ? '' : 'playerArgs',
        subBuilder: $3.PlayerArgs.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArcsPlayerReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArcsPlayerReq copyWith(void Function(GetArcsPlayerReq) updates) =>
      super.copyWith((message) => updates(message as GetArcsPlayerReq))
          as GetArcsPlayerReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetArcsPlayerReq() / GetArcsPlayerReq.new instead')
  static GetArcsPlayerReq create() => GetArcsPlayerReq._();
  static $pb.GeneratedMessage $_createMessage() => GetArcsPlayerReq._();
  @$core.override
  GetArcsPlayerReq createEmptyInstance() => GetArcsPlayerReq._();
  @$core.pragma('dart2js:noInline')
  static GetArcsPlayerReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetArcsPlayerReq>(
          GetArcsPlayerReq.$_createMessage);
  static GetArcsPlayerReq? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PlayAv> get playAvs => $_getList(0);

  @$pb.TagNumber(2)
  $3.PlayerArgs get playerArgs => $_getN(1);
  @$pb.TagNumber(2)
  set playerArgs($3.PlayerArgs value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPlayerArgs() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlayerArgs() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.PlayerArgs ensurePlayerArgs() => $_ensure(1);
}

class GoodsInfo extends $pb.GeneratedMessage {
  factory GoodsInfo({
    $core.String? goodsId,
    $core.int? category,
    $fixnum.Int64? goodsPrice,
    PayState? payState,
    $core.String? goodsName,
    $core.String? priceFmt,
  }) {
    final result = GoodsInfo._();
    if (goodsId != null) result.goodsId = goodsId;
    if (category != null) result.category = category;
    if (goodsPrice != null) result.goodsPrice = goodsPrice;
    if (payState != null) result.payState = payState;
    if (goodsName != null) result.goodsName = goodsName;
    if (priceFmt != null) result.priceFmt = priceFmt;
    return result;
  }

  GoodsInfo._();

  factory GoodsInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GoodsInfo()..mergeFromBuffer(data, registry);
  factory GoodsInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GoodsInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GoodsInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: GoodsInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'goodsId')
    ..aI(2, _omitFieldNames ? '' : 'category')
    ..aInt64(3, _omitFieldNames ? '' : 'goodsPrice')
    ..aE<PayState>(4, _omitFieldNames ? '' : 'payState',
        enumValues: PayState.values)
    ..aOS(5, _omitFieldNames ? '' : 'goodsName')
    ..aOS(6, _omitFieldNames ? '' : 'priceFmt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoodsInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoodsInfo copyWith(void Function(GoodsInfo) updates) =>
      super.copyWith((message) => updates(message as GoodsInfo)) as GoodsInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GoodsInfo() / GoodsInfo.new instead')
  static GoodsInfo create() => GoodsInfo._();
  static $pb.GeneratedMessage $_createMessage() => GoodsInfo._();
  @$core.override
  GoodsInfo createEmptyInstance() => GoodsInfo._();
  @$core.pragma('dart2js:noInline')
  static GoodsInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GoodsInfo>(GoodsInfo.$_createMessage);
  static GoodsInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get goodsId => $_getSZ(0);
  @$pb.TagNumber(1)
  set goodsId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGoodsId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGoodsId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get category => $_getIZ(1);
  @$pb.TagNumber(2)
  set category($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCategory() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategory() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get goodsPrice => $_getI64(2);
  @$pb.TagNumber(3)
  set goodsPrice($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGoodsPrice() => $_has(2);
  @$pb.TagNumber(3)
  void clearGoodsPrice() => $_clearField(3);

  @$pb.TagNumber(4)
  PayState get payState => $_getN(3);
  @$pb.TagNumber(4)
  set payState(PayState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPayState() => $_has(3);
  @$pb.TagNumber(4)
  void clearPayState() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get goodsName => $_getSZ(4);
  @$pb.TagNumber(5)
  set goodsName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGoodsName() => $_has(4);
  @$pb.TagNumber(5)
  void clearGoodsName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get priceFmt => $_getSZ(5);
  @$pb.TagNumber(6)
  set priceFmt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPriceFmt() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriceFmt() => $_clearField(6);
}

/// 稿件观看进度
class History extends $pb.GeneratedMessage {
  factory History({
    $fixnum.Int64? cid,
    $fixnum.Int64? progress,
  }) {
    final result = History._();
    if (cid != null) result.cid = cid;
    if (progress != null) result.progress = progress;
    return result;
  }

  History._();

  factory History.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      History()..mergeFromBuffer(data, registry);
  factory History.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      History()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'History',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: History.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'cid')
    ..aInt64(2, _omitFieldNames ? '' : 'progress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  History clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  History copyWith(void Function(History) updates) =>
      super.copyWith((message) => updates(message as History)) as History;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use History() / History.new instead')
  static History create() => History._();
  static $pb.GeneratedMessage $_createMessage() => History._();
  @$core.override
  History createEmptyInstance() => History._();
  @$core.pragma('dart2js:noInline')
  static History getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<History>(History.$_createMessage);
  static History? _defaultInstance;

  /// 播放进度分P cid
  @$pb.TagNumber(1)
  $fixnum.Int64 get cid => $_getI64(0);
  @$pb.TagNumber(1)
  set cid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => $_clearField(1);

  /// 播放进度时间
  /// 0:未观看 -1:已看完 正整数:播放时间进度
  @$pb.TagNumber(2)
  $fixnum.Int64 get progress => $_getI64(1);
  @$pb.TagNumber(2)
  set progress($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);
}

/// 稿件获得荣誉信息
class Honor extends $pb.GeneratedMessage {
  factory Honor({
    $core.String? icon,
    $core.String? iconNight,
    $core.String? text,
    $core.String? textExtra,
    $core.String? textColor,
    $core.String? textColorNight,
    $core.String? bgColor,
    $core.String? bgColorNight,
    $core.String? url,
    $core.String? urlText,
  }) {
    final result = Honor._();
    if (icon != null) result.icon = icon;
    if (iconNight != null) result.iconNight = iconNight;
    if (text != null) result.text = text;
    if (textExtra != null) result.textExtra = textExtra;
    if (textColor != null) result.textColor = textColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    if (bgColor != null) result.bgColor = bgColor;
    if (bgColorNight != null) result.bgColorNight = bgColorNight;
    if (url != null) result.url = url;
    if (urlText != null) result.urlText = urlText;
    return result;
  }

  Honor._();

  factory Honor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Honor()..mergeFromBuffer(data, registry);
  factory Honor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Honor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Honor',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Honor.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'icon')
    ..aOS(2, _omitFieldNames ? '' : 'iconNight')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOS(4, _omitFieldNames ? '' : 'textExtra')
    ..aOS(5, _omitFieldNames ? '' : 'textColor')
    ..aOS(6, _omitFieldNames ? '' : 'textColorNight')
    ..aOS(7, _omitFieldNames ? '' : 'bgColor')
    ..aOS(8, _omitFieldNames ? '' : 'bgColorNight')
    ..aOS(9, _omitFieldNames ? '' : 'url')
    ..aOS(10, _omitFieldNames ? '' : 'urlText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Honor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Honor copyWith(void Function(Honor) updates) =>
      super.copyWith((message) => updates(message as Honor)) as Honor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Honor() / Honor.new instead')
  static Honor create() => Honor._();
  static $pb.GeneratedMessage $_createMessage() => Honor._();
  @$core.override
  Honor createEmptyInstance() => Honor._();
  @$core.pragma('dart2js:noInline')
  static Honor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Honor>(Honor.$_createMessage);
  static Honor? _defaultInstance;

  /// 荣誉栏图标url
  @$pb.TagNumber(1)
  $core.String get icon => $_getSZ(0);
  @$pb.TagNumber(1)
  set icon($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIcon() => $_has(0);
  @$pb.TagNumber(1)
  void clearIcon() => $_clearField(1);

  /// 荣誉栏图标url 夜间模式
  @$pb.TagNumber(2)
  $core.String get iconNight => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconNight($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconNight() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconNight() => $_clearField(2);

  /// 荣誉文案
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  /// 荣誉副文案
  @$pb.TagNumber(4)
  $core.String get textExtra => $_getSZ(3);
  @$pb.TagNumber(4)
  set textExtra($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTextExtra() => $_has(3);
  @$pb.TagNumber(4)
  void clearTextExtra() => $_clearField(4);

  /// 标题颜色
  @$pb.TagNumber(5)
  $core.String get textColor => $_getSZ(4);
  @$pb.TagNumber(5)
  set textColor($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTextColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextColor() => $_clearField(5);

  /// 标题颜色 夜间模式
  @$pb.TagNumber(6)
  $core.String get textColorNight => $_getSZ(5);
  @$pb.TagNumber(6)
  set textColorNight($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTextColorNight() => $_has(5);
  @$pb.TagNumber(6)
  void clearTextColorNight() => $_clearField(6);

  /// 背景颜色
  @$pb.TagNumber(7)
  $core.String get bgColor => $_getSZ(6);
  @$pb.TagNumber(7)
  set bgColor($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBgColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearBgColor() => $_clearField(7);

  /// 背景颜色 夜间模式
  @$pb.TagNumber(8)
  $core.String get bgColorNight => $_getSZ(7);
  @$pb.TagNumber(8)
  set bgColorNight($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBgColorNight() => $_has(7);
  @$pb.TagNumber(8)
  void clearBgColorNight() => $_clearField(8);

  /// 跳转uri
  @$pb.TagNumber(9)
  $core.String get url => $_getSZ(8);
  @$pb.TagNumber(9)
  set url($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUrl() => $_has(8);
  @$pb.TagNumber(9)
  void clearUrl() => $_clearField(9);

  /// 跳转角标文案
  @$pb.TagNumber(10)
  $core.String get urlText => $_getSZ(9);
  @$pb.TagNumber(10)
  set urlText($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasUrlText() => $_has(9);
  @$pb.TagNumber(10)
  void clearUrlText() => $_clearField(10);
}

class IconData extends $pb.GeneratedMessage {
  factory IconData({
    $core.String? metaJson,
    $core.String? spritsImg,
  }) {
    final result = IconData._();
    if (metaJson != null) result.metaJson = metaJson;
    if (spritsImg != null) result.spritsImg = spritsImg;
    return result;
  }

  IconData._();

  factory IconData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IconData()..mergeFromBuffer(data, registry);
  factory IconData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IconData()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IconData',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: IconData.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'metaJson')
    ..aOS(2, _omitFieldNames ? '' : 'spritsImg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconData copyWith(void Function(IconData) updates) =>
      super.copyWith((message) => updates(message as IconData)) as IconData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use IconData() / IconData.new instead')
  static IconData create() => IconData._();
  static $pb.GeneratedMessage $_createMessage() => IconData._();
  @$core.override
  IconData createEmptyInstance() => IconData._();
  @$core.pragma('dart2js:noInline')
  static IconData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IconData>(IconData.$_createMessage);
  static IconData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get metaJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set metaJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMetaJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearMetaJson() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get spritsImg => $_getSZ(1);
  @$pb.TagNumber(2)
  set spritsImg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSpritsImg() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpritsImg() => $_clearField(2);
}

class Interaction extends $pb.GeneratedMessage {
  factory Interaction({
    Node? historyNode,
    $fixnum.Int64? graphVersion,
    $core.String? msg,
    $core.String? evaluation,
    $fixnum.Int64? mark,
  }) {
    final result = Interaction._();
    if (historyNode != null) result.historyNode = historyNode;
    if (graphVersion != null) result.graphVersion = graphVersion;
    if (msg != null) result.msg = msg;
    if (evaluation != null) result.evaluation = evaluation;
    if (mark != null) result.mark = mark;
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
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Interaction.$_createMessage)
    ..aOM<Node>(1, _omitFieldNames ? '' : 'historyNode',
        subBuilder: Node.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'graphVersion')
    ..aOS(3, _omitFieldNames ? '' : 'msg')
    ..aOS(4, _omitFieldNames ? '' : 'evaluation')
    ..aInt64(5, _omitFieldNames ? '' : 'mark')
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

  @$pb.TagNumber(1)
  Node get historyNode => $_getN(0);
  @$pb.TagNumber(1)
  set historyNode(Node value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHistoryNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearHistoryNode() => $_clearField(1);
  @$pb.TagNumber(1)
  Node ensureHistoryNode() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get graphVersion => $_getI64(1);
  @$pb.TagNumber(2)
  set graphVersion($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGraphVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearGraphVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get msg => $_getSZ(2);
  @$pb.TagNumber(3)
  set msg($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMsg() => $_has(2);
  @$pb.TagNumber(3)
  void clearMsg() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get evaluation => $_getSZ(3);
  @$pb.TagNumber(4)
  set evaluation($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEvaluation() => $_has(3);
  @$pb.TagNumber(4)
  void clearEvaluation() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get mark => $_getI64(4);
  @$pb.TagNumber(5)
  set mark($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMark() => $_has(4);
  @$pb.TagNumber(5)
  void clearMark() => $_clearField(5);
}

class Label extends $pb.GeneratedMessage {
  factory Label({
    $core.int? type,
    $core.String? uri,
    $core.String? icon,
    $core.String? iconNight,
    $fixnum.Int64? iconWidth,
    $fixnum.Int64? iconHeight,
    $core.String? lottie,
    $core.String? lottieNight,
  }) {
    final result = Label._();
    if (type != null) result.type = type;
    if (uri != null) result.uri = uri;
    if (icon != null) result.icon = icon;
    if (iconNight != null) result.iconNight = iconNight;
    if (iconWidth != null) result.iconWidth = iconWidth;
    if (iconHeight != null) result.iconHeight = iconHeight;
    if (lottie != null) result.lottie = lottie;
    if (lottieNight != null) result.lottieNight = lottieNight;
    return result;
  }

  Label._();

  factory Label.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Label()..mergeFromBuffer(data, registry);
  factory Label.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Label()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Label',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Label.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'uri')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'iconNight')
    ..aInt64(5, _omitFieldNames ? '' : 'iconWidth')
    ..aInt64(6, _omitFieldNames ? '' : 'iconHeight')
    ..aOS(7, _omitFieldNames ? '' : 'lottie')
    ..aOS(8, _omitFieldNames ? '' : 'lottieNight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Label clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Label copyWith(void Function(Label) updates) =>
      super.copyWith((message) => updates(message as Label)) as Label;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Label() / Label.new instead')
  static Label create() => Label._();
  static $pb.GeneratedMessage $_createMessage() => Label._();
  @$core.override
  Label createEmptyInstance() => Label._();
  @$core.pragma('dart2js:noInline')
  static Label getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Label>(Label.$_createMessage);
  static Label? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get uri => $_getSZ(1);
  @$pb.TagNumber(2)
  set uri($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUri() => $_has(1);
  @$pb.TagNumber(2)
  void clearUri() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get iconNight => $_getSZ(3);
  @$pb.TagNumber(4)
  set iconNight($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIconNight() => $_has(3);
  @$pb.TagNumber(4)
  void clearIconNight() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get iconWidth => $_getI64(4);
  @$pb.TagNumber(5)
  set iconWidth($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIconWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearIconWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get iconHeight => $_getI64(5);
  @$pb.TagNumber(6)
  set iconHeight($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIconHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearIconHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get lottie => $_getSZ(6);
  @$pb.TagNumber(7)
  set lottie($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLottie() => $_has(6);
  @$pb.TagNumber(7)
  void clearLottie() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get lottieNight => $_getSZ(7);
  @$pb.TagNumber(8)
  set lottieNight($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLottieNight() => $_has(7);
  @$pb.TagNumber(8)
  void clearLottieNight() => $_clearField(8);
}

class LikeAnimation extends $pb.GeneratedMessage {
  factory LikeAnimation({
    $core.String? likeIcon,
    $core.String? likedIcon,
    $core.String? likeAnimation,
  }) {
    final result = LikeAnimation._();
    if (likeIcon != null) result.likeIcon = likeIcon;
    if (likedIcon != null) result.likedIcon = likedIcon;
    if (likeAnimation != null) result.likeAnimation = likeAnimation;
    return result;
  }

  LikeAnimation._();

  factory LikeAnimation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LikeAnimation()..mergeFromBuffer(data, registry);
  factory LikeAnimation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LikeAnimation()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LikeAnimation',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: LikeAnimation.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'likeIcon')
    ..aOS(2, _omitFieldNames ? '' : 'likedIcon')
    ..aOS(3, _omitFieldNames ? '' : 'likeAnimation')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LikeAnimation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LikeAnimation copyWith(void Function(LikeAnimation) updates) =>
      super.copyWith((message) => updates(message as LikeAnimation))
          as LikeAnimation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LikeAnimation() / LikeAnimation.new instead')
  static LikeAnimation create() => LikeAnimation._();
  static $pb.GeneratedMessage $_createMessage() => LikeAnimation._();
  @$core.override
  LikeAnimation createEmptyInstance() => LikeAnimation._();
  @$core.pragma('dart2js:noInline')
  static LikeAnimation getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LikeAnimation>(
          LikeAnimation.$_createMessage);
  static LikeAnimation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get likeIcon => $_getSZ(0);
  @$pb.TagNumber(1)
  set likeIcon($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLikeIcon() => $_has(0);
  @$pb.TagNumber(1)
  void clearLikeIcon() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get likedIcon => $_getSZ(1);
  @$pb.TagNumber(2)
  set likedIcon($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLikedIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearLikedIcon() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get likeAnimation => $_getSZ(2);
  @$pb.TagNumber(3)
  set likeAnimation($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLikeAnimation() => $_has(2);
  @$pb.TagNumber(3)
  void clearLikeAnimation() => $_clearField(3);
}

class LikeCustom extends $pb.GeneratedMessage {
  factory LikeCustom({
    $core.bool? likeSwitch,
    $fixnum.Int64? fullToHalfProgress,
    $fixnum.Int64? nonFullProgress,
    $fixnum.Int64? updateCount,
  }) {
    final result = LikeCustom._();
    if (likeSwitch != null) result.likeSwitch = likeSwitch;
    if (fullToHalfProgress != null)
      result.fullToHalfProgress = fullToHalfProgress;
    if (nonFullProgress != null) result.nonFullProgress = nonFullProgress;
    if (updateCount != null) result.updateCount = updateCount;
    return result;
  }

  LikeCustom._();

  factory LikeCustom.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LikeCustom()..mergeFromBuffer(data, registry);
  factory LikeCustom.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LikeCustom()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LikeCustom',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: LikeCustom.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'likeSwitch')
    ..aInt64(2, _omitFieldNames ? '' : 'fullToHalfProgress')
    ..aInt64(3, _omitFieldNames ? '' : 'nonFullProgress')
    ..aInt64(4, _omitFieldNames ? '' : 'updateCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LikeCustom clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LikeCustom copyWith(void Function(LikeCustom) updates) =>
      super.copyWith((message) => updates(message as LikeCustom)) as LikeCustom;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LikeCustom() / LikeCustom.new instead')
  static LikeCustom create() => LikeCustom._();
  static $pb.GeneratedMessage $_createMessage() => LikeCustom._();
  @$core.override
  LikeCustom createEmptyInstance() => LikeCustom._();
  @$core.pragma('dart2js:noInline')
  static LikeCustom getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LikeCustom>(LikeCustom.$_createMessage);
  static LikeCustom? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get likeSwitch => $_getBF(0);
  @$pb.TagNumber(1)
  set likeSwitch($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLikeSwitch() => $_has(0);
  @$pb.TagNumber(1)
  void clearLikeSwitch() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fullToHalfProgress => $_getI64(1);
  @$pb.TagNumber(2)
  set fullToHalfProgress($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFullToHalfProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearFullToHalfProgress() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get nonFullProgress => $_getI64(2);
  @$pb.TagNumber(3)
  set nonFullProgress($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNonFullProgress() => $_has(2);
  @$pb.TagNumber(3)
  void clearNonFullProgress() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get updateCount => $_getI64(3);
  @$pb.TagNumber(4)
  set updateCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdateCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdateCount() => $_clearField(4);
}

class ListenerConfig extends $pb.GeneratedMessage {
  factory ListenerConfig({
    $fixnum.Int64? jumpStyle,
    ListenerGuideBar? guideBar,
  }) {
    final result = ListenerConfig._();
    if (jumpStyle != null) result.jumpStyle = jumpStyle;
    if (guideBar != null) result.guideBar = guideBar;
    return result;
  }

  ListenerConfig._();

  factory ListenerConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenerConfig()..mergeFromBuffer(data, registry);
  factory ListenerConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenerConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListenerConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ListenerConfig.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'jumpStyle')
    ..aOM<ListenerGuideBar>(2, _omitFieldNames ? '' : 'guideBar',
        subBuilder: ListenerGuideBar.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenerConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenerConfig copyWith(void Function(ListenerConfig) updates) =>
      super.copyWith((message) => updates(message as ListenerConfig))
          as ListenerConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListenerConfig() / ListenerConfig.new instead')
  static ListenerConfig create() => ListenerConfig._();
  static $pb.GeneratedMessage $_createMessage() => ListenerConfig._();
  @$core.override
  ListenerConfig createEmptyInstance() => ListenerConfig._();
  @$core.pragma('dart2js:noInline')
  static ListenerConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListenerConfig>(
          ListenerConfig.$_createMessage);
  static ListenerConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get jumpStyle => $_getI64(0);
  @$pb.TagNumber(1)
  set jumpStyle($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJumpStyle() => $_has(0);
  @$pb.TagNumber(1)
  void clearJumpStyle() => $_clearField(1);

  @$pb.TagNumber(2)
  ListenerGuideBar get guideBar => $_getN(1);
  @$pb.TagNumber(2)
  set guideBar(ListenerGuideBar value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasGuideBar() => $_has(1);
  @$pb.TagNumber(2)
  void clearGuideBar() => $_clearField(2);
  @$pb.TagNumber(2)
  ListenerGuideBar ensureGuideBar() => $_ensure(1);
}

class ListenerGuideBar extends $pb.GeneratedMessage {
  factory ListenerGuideBar({
    $fixnum.Int64? showStrategy,
    $core.String? icon,
    $core.String? text,
    $core.String? btnText,
    $fixnum.Int64? showTime,
    $fixnum.Int64? backgroundTime,
  }) {
    final result = ListenerGuideBar._();
    if (showStrategy != null) result.showStrategy = showStrategy;
    if (icon != null) result.icon = icon;
    if (text != null) result.text = text;
    if (btnText != null) result.btnText = btnText;
    if (showTime != null) result.showTime = showTime;
    if (backgroundTime != null) result.backgroundTime = backgroundTime;
    return result;
  }

  ListenerGuideBar._();

  factory ListenerGuideBar.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenerGuideBar()..mergeFromBuffer(data, registry);
  factory ListenerGuideBar.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenerGuideBar()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListenerGuideBar',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ListenerGuideBar.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'showStrategy')
    ..aOS(2, _omitFieldNames ? '' : 'icon')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOS(4, _omitFieldNames ? '' : 'btnText')
    ..aInt64(5, _omitFieldNames ? '' : 'showTime')
    ..aInt64(6, _omitFieldNames ? '' : 'backgroundTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenerGuideBar clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenerGuideBar copyWith(void Function(ListenerGuideBar) updates) =>
      super.copyWith((message) => updates(message as ListenerGuideBar))
          as ListenerGuideBar;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListenerGuideBar() / ListenerGuideBar.new instead')
  static ListenerGuideBar create() => ListenerGuideBar._();
  static $pb.GeneratedMessage $_createMessage() => ListenerGuideBar._();
  @$core.override
  ListenerGuideBar createEmptyInstance() => ListenerGuideBar._();
  @$core.pragma('dart2js:noInline')
  static ListenerGuideBar getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListenerGuideBar>(
          ListenerGuideBar.$_createMessage);
  static ListenerGuideBar? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get showStrategy => $_getI64(0);
  @$pb.TagNumber(1)
  set showStrategy($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShowStrategy() => $_has(0);
  @$pb.TagNumber(1)
  void clearShowStrategy() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get icon => $_getSZ(1);
  @$pb.TagNumber(2)
  set icon($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearIcon() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get btnText => $_getSZ(3);
  @$pb.TagNumber(4)
  set btnText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBtnText() => $_has(3);
  @$pb.TagNumber(4)
  void clearBtnText() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get showTime => $_getI64(4);
  @$pb.TagNumber(5)
  set showTime($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShowTime() => $_has(4);
  @$pb.TagNumber(5)
  void clearShowTime() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get backgroundTime => $_getI64(5);
  @$pb.TagNumber(6)
  set backgroundTime($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBackgroundTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearBackgroundTime() => $_clearField(6);
}

/// 直播信息
class Live extends $pb.GeneratedMessage {
  factory Live({
    $fixnum.Int64? mid,
    $fixnum.Int64? roomid,
    $core.String? uri,
    $core.String? endpageUri,
  }) {
    final result = Live._();
    if (mid != null) result.mid = mid;
    if (roomid != null) result.roomid = roomid;
    if (uri != null) result.uri = uri;
    if (endpageUri != null) result.endpageUri = endpageUri;
    return result;
  }

  Live._();

  factory Live.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Live()..mergeFromBuffer(data, registry);
  factory Live.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Live()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Live',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Live.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'mid')
    ..aInt64(2, _omitFieldNames ? '' : 'roomid')
    ..aOS(3, _omitFieldNames ? '' : 'uri')
    ..aOS(4, _omitFieldNames ? '' : 'endpageUri')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Live clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Live copyWith(void Function(Live) updates) =>
      super.copyWith((message) => updates(message as Live)) as Live;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Live() / Live.new instead')
  static Live create() => Live._();
  static $pb.GeneratedMessage $_createMessage() => Live._();
  @$core.override
  Live createEmptyInstance() => Live._();
  @$core.pragma('dart2js:noInline')
  static Live getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Live>(Live.$_createMessage);
  static Live? _defaultInstance;

  /// 主播UID
  @$pb.TagNumber(1)
  $fixnum.Int64 get mid => $_getI64(0);
  @$pb.TagNumber(1)
  set mid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMid() => $_has(0);
  @$pb.TagNumber(1)
  void clearMid() => $_clearField(1);

  /// 直播间id
  @$pb.TagNumber(2)
  $fixnum.Int64 get roomid => $_getI64(1);
  @$pb.TagNumber(2)
  set roomid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomid() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomid() => $_clearField(2);

  /// 直播间url
  @$pb.TagNumber(3)
  $core.String get uri => $_getSZ(2);
  @$pb.TagNumber(3)
  set uri($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUri() => $_has(2);
  @$pb.TagNumber(3)
  void clearUri() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get endpageUri => $_getSZ(3);
  @$pb.TagNumber(4)
  set endpageUri($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndpageUri() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndpageUri() => $_clearField(4);
}

/// 直播预约信息
class LiveOrderInfo extends $pb.GeneratedMessage {
  factory LiveOrderInfo({
    $fixnum.Int64? sid,
    $core.String? text,
    $fixnum.Int64? livePlanStartTime,
    $core.bool? isFollow,
  }) {
    final result = LiveOrderInfo._();
    if (sid != null) result.sid = sid;
    if (text != null) result.text = text;
    if (livePlanStartTime != null) result.livePlanStartTime = livePlanStartTime;
    if (isFollow != null) result.isFollow = isFollow;
    return result;
  }

  LiveOrderInfo._();

  factory LiveOrderInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LiveOrderInfo()..mergeFromBuffer(data, registry);
  factory LiveOrderInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LiveOrderInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LiveOrderInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: LiveOrderInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'sid')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aInt64(3, _omitFieldNames ? '' : 'livePlanStartTime')
    ..aOB(4, _omitFieldNames ? '' : 'isFollow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LiveOrderInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LiveOrderInfo copyWith(void Function(LiveOrderInfo) updates) =>
      super.copyWith((message) => updates(message as LiveOrderInfo))
          as LiveOrderInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LiveOrderInfo() / LiveOrderInfo.new instead')
  static LiveOrderInfo create() => LiveOrderInfo._();
  static $pb.GeneratedMessage $_createMessage() => LiveOrderInfo._();
  @$core.override
  LiveOrderInfo createEmptyInstance() => LiveOrderInfo._();
  @$core.pragma('dart2js:noInline')
  static LiveOrderInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LiveOrderInfo>(
          LiveOrderInfo.$_createMessage);
  static LiveOrderInfo? _defaultInstance;

  /// 预约id
  @$pb.TagNumber(1)
  $fixnum.Int64 get sid => $_getI64(0);
  @$pb.TagNumber(1)
  set sid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  /// 预约条文案
  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  /// 直播开始时间
  @$pb.TagNumber(3)
  $fixnum.Int64 get livePlanStartTime => $_getI64(2);
  @$pb.TagNumber(3)
  set livePlanStartTime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLivePlanStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearLivePlanStartTime() => $_clearField(3);

  /// 是否预约
  @$pb.TagNumber(4)
  $core.bool get isFollow => $_getBF(3);
  @$pb.TagNumber(4)
  set isFollow($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsFollow() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsFollow() => $_clearField(4);
}

class MaterialLeft extends $pb.GeneratedMessage {
  factory MaterialLeft({
    $core.String? icon,
    $core.String? text,
    $core.String? url,
    $core.String? leftType,
    $core.String? param,
    $core.String? operationalType,
    $core.String? staticIcon,
  }) {
    final result = MaterialLeft._();
    if (icon != null) result.icon = icon;
    if (text != null) result.text = text;
    if (url != null) result.url = url;
    if (leftType != null) result.leftType = leftType;
    if (param != null) result.param = param;
    if (operationalType != null) result.operationalType = operationalType;
    if (staticIcon != null) result.staticIcon = staticIcon;
    return result;
  }

  MaterialLeft._();

  factory MaterialLeft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MaterialLeft()..mergeFromBuffer(data, registry);
  factory MaterialLeft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MaterialLeft()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MaterialLeft',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: MaterialLeft.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'icon')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aOS(3, _omitFieldNames ? '' : 'url')
    ..aOS(4, _omitFieldNames ? '' : 'leftType')
    ..aOS(5, _omitFieldNames ? '' : 'param')
    ..aOS(6, _omitFieldNames ? '' : 'operationalType')
    ..aOS(7, _omitFieldNames ? '' : 'staticIcon')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MaterialLeft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MaterialLeft copyWith(void Function(MaterialLeft) updates) =>
      super.copyWith((message) => updates(message as MaterialLeft))
          as MaterialLeft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MaterialLeft() / MaterialLeft.new instead')
  static MaterialLeft create() => MaterialLeft._();
  static $pb.GeneratedMessage $_createMessage() => MaterialLeft._();
  @$core.override
  MaterialLeft createEmptyInstance() => MaterialLeft._();
  @$core.pragma('dart2js:noInline')
  static MaterialLeft getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MaterialLeft>(
          MaterialLeft.$_createMessage);
  static MaterialLeft? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get icon => $_getSZ(0);
  @$pb.TagNumber(1)
  set icon($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIcon() => $_has(0);
  @$pb.TagNumber(1)
  void clearIcon() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get url => $_getSZ(2);
  @$pb.TagNumber(3)
  set url($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get leftType => $_getSZ(3);
  @$pb.TagNumber(4)
  set leftType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLeftType() => $_has(3);
  @$pb.TagNumber(4)
  void clearLeftType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get param => $_getSZ(4);
  @$pb.TagNumber(5)
  set param($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParam() => $_has(4);
  @$pb.TagNumber(5)
  void clearParam() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get operationalType => $_getSZ(5);
  @$pb.TagNumber(6)
  set operationalType($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOperationalType() => $_has(5);
  @$pb.TagNumber(6)
  void clearOperationalType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get staticIcon => $_getSZ(6);
  @$pb.TagNumber(7)
  set staticIcon($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStaticIcon() => $_has(6);
  @$pb.TagNumber(7)
  void clearStaticIcon() => $_clearField(7);
}

class MaterialRes extends $pb.GeneratedMessage {
  factory MaterialRes({
    $fixnum.Int64? id,
    $core.String? icon,
    $core.String? url,
    MaterialSource? type,
    $core.String? name,
    $core.String? bgColor,
    $core.String? bgPic,
    $core.int? jumpType,
  }) {
    final result = MaterialRes._();
    if (id != null) result.id = id;
    if (icon != null) result.icon = icon;
    if (url != null) result.url = url;
    if (type != null) result.type = type;
    if (name != null) result.name = name;
    if (bgColor != null) result.bgColor = bgColor;
    if (bgPic != null) result.bgPic = bgPic;
    if (jumpType != null) result.jumpType = jumpType;
    return result;
  }

  MaterialRes._();

  factory MaterialRes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MaterialRes()..mergeFromBuffer(data, registry);
  factory MaterialRes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MaterialRes()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MaterialRes',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: MaterialRes.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'icon')
    ..aOS(3, _omitFieldNames ? '' : 'url')
    ..aE<MaterialSource>(4, _omitFieldNames ? '' : 'type',
        enumValues: MaterialSource.values)
    ..aOS(5, _omitFieldNames ? '' : 'name')
    ..aOS(6, _omitFieldNames ? '' : 'bgColor')
    ..aOS(7, _omitFieldNames ? '' : 'bgPic')
    ..aI(8, _omitFieldNames ? '' : 'jumpType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MaterialRes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MaterialRes copyWith(void Function(MaterialRes) updates) =>
      super.copyWith((message) => updates(message as MaterialRes))
          as MaterialRes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MaterialRes() / MaterialRes.new instead')
  static MaterialRes create() => MaterialRes._();
  static $pb.GeneratedMessage $_createMessage() => MaterialRes._();
  @$core.override
  MaterialRes createEmptyInstance() => MaterialRes._();
  @$core.pragma('dart2js:noInline')
  static MaterialRes getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MaterialRes>(
          MaterialRes.$_createMessage);
  static MaterialRes? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get icon => $_getSZ(1);
  @$pb.TagNumber(2)
  set icon($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearIcon() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get url => $_getSZ(2);
  @$pb.TagNumber(3)
  set url($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  MaterialSource get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(MaterialSource value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get name => $_getSZ(4);
  @$pb.TagNumber(5)
  set name($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasName() => $_has(4);
  @$pb.TagNumber(5)
  void clearName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get bgColor => $_getSZ(5);
  @$pb.TagNumber(6)
  set bgColor($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBgColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearBgColor() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get bgPic => $_getSZ(6);
  @$pb.TagNumber(7)
  set bgPic($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBgPic() => $_has(6);
  @$pb.TagNumber(7)
  void clearBgPic() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get jumpType => $_getIZ(7);
  @$pb.TagNumber(8)
  set jumpType($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasJumpType() => $_has(7);
  @$pb.TagNumber(8)
  void clearJumpType() => $_clearField(8);
}

class Node extends $pb.GeneratedMessage {
  factory Node({
    $fixnum.Int64? nodeId,
    $core.String? title,
    $fixnum.Int64? cid,
  }) {
    final result = Node._();
    if (nodeId != null) result.nodeId = nodeId;
    if (title != null) result.title = title;
    if (cid != null) result.cid = cid;
    return result;
  }

  Node._();

  factory Node.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Node()..mergeFromBuffer(data, registry);
  factory Node.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Node()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Node',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Node.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'nodeId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Node clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Node copyWith(void Function(Node) updates) =>
      super.copyWith((message) => updates(message as Node)) as Node;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Node() / Node.new instead')
  static Node create() => Node._();
  static $pb.GeneratedMessage $_createMessage() => Node._();
  @$core.override
  Node createEmptyInstance() => Node._();
  @$core.pragma('dart2js:noInline')
  static Node getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Node>(Node.$_createMessage);
  static Node? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);
}

/// 空回复
class NoReply extends $pb.GeneratedMessage {
  factory NoReply() => NoReply._();

  NoReply._();

  factory NoReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NoReply()..mergeFromBuffer(data, registry);
  factory NoReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NoReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NoReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: NoReply.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoReply copyWith(void Function(NoReply) updates) =>
      super.copyWith((message) => updates(message as NoReply)) as NoReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NoReply() / NoReply.new instead')
  static NoReply create() => NoReply._();
  static $pb.GeneratedMessage $_createMessage() => NoReply._();
  @$core.override
  NoReply createEmptyInstance() => NoReply._();
  @$core.pragma('dart2js:noInline')
  static NoReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NoReply>(NoReply.$_createMessage);
  static NoReply? _defaultInstance;
}

class Notice extends $pb.GeneratedMessage {
  factory Notice({
    $core.String? title,
    $core.String? desc,
  }) {
    final result = Notice._();
    if (title != null) result.title = title;
    if (desc != null) result.desc = desc;
    return result;
  }

  Notice._();

  factory Notice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Notice()..mergeFromBuffer(data, registry);
  factory Notice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Notice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Notice',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Notice.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'desc')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Notice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Notice copyWith(void Function(Notice) updates) =>
      super.copyWith((message) => updates(message as Notice)) as Notice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Notice() / Notice.new instead')
  static Notice create() => Notice._();
  static $pb.GeneratedMessage $_createMessage() => Notice._();
  @$core.override
  Notice createEmptyInstance() => Notice._();
  @$core.pragma('dart2js:noInline')
  static Notice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Notice>(Notice.$_createMessage);
  static Notice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get desc => $_getSZ(1);
  @$pb.TagNumber(2)
  set desc($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesc() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesc() => $_clearField(2);
}

/// 认证信息
class OfficialVerify extends $pb.GeneratedMessage {
  factory OfficialVerify({
    $core.int? type,
    $core.String? desc,
  }) {
    final result = OfficialVerify._();
    if (type != null) result.type = type;
    if (desc != null) result.desc = desc;
    return result;
  }

  OfficialVerify._();

  factory OfficialVerify.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OfficialVerify()..mergeFromBuffer(data, registry);
  factory OfficialVerify.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OfficialVerify()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OfficialVerify',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OfficialVerify.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'desc')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OfficialVerify clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OfficialVerify copyWith(void Function(OfficialVerify) updates) =>
      super.copyWith((message) => updates(message as OfficialVerify))
          as OfficialVerify;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OfficialVerify() / OfficialVerify.new instead')
  static OfficialVerify create() => OfficialVerify._();
  static $pb.GeneratedMessage $_createMessage() => OfficialVerify._();
  @$core.override
  OfficialVerify createEmptyInstance() => OfficialVerify._();
  @$core.pragma('dart2js:noInline')
  static OfficialVerify getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OfficialVerify>(
          OfficialVerify.$_createMessage);
  static OfficialVerify? _defaultInstance;

  /// 认证类型
  /// 0:个人认证 1:官方认证
  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// 认证名称
  @$pb.TagNumber(2)
  $core.String get desc => $_getSZ(1);
  @$pb.TagNumber(2)
  set desc($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesc() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesc() => $_clearField(2);
}

class Online extends $pb.GeneratedMessage {
  factory Online({
    $core.bool? onlineShow,
    $core.String? playerOnlineLogo,
  }) {
    final result = Online._();
    if (onlineShow != null) result.onlineShow = onlineShow;
    if (playerOnlineLogo != null) result.playerOnlineLogo = playerOnlineLogo;
    return result;
  }

  Online._();

  factory Online.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Online()..mergeFromBuffer(data, registry);
  factory Online.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Online()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Online',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Online.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'onlineShow')
    ..aOS(2, _omitFieldNames ? '' : 'playerOnlineLogo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Online clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Online copyWith(void Function(Online) updates) =>
      super.copyWith((message) => updates(message as Online)) as Online;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Online() / Online.new instead')
  static Online create() => Online._();
  static $pb.GeneratedMessage $_createMessage() => Online._();
  @$core.override
  Online createEmptyInstance() => Online._();
  @$core.pragma('dart2js:noInline')
  static Online getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Online>(Online.$_createMessage);
  static Online? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get onlineShow => $_getBF(0);
  @$pb.TagNumber(1)
  set onlineShow($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOnlineShow() => $_has(0);
  @$pb.TagNumber(1)
  void clearOnlineShow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get playerOnlineLogo => $_getSZ(1);
  @$pb.TagNumber(2)
  set playerOnlineLogo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlayerOnlineLogo() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlayerOnlineLogo() => $_clearField(2);
}

/// UP主扩展信息 ("OnwerExt"为源码中拼写错误)
class OnwerExt extends $pb.GeneratedMessage {
  factory OnwerExt({
    OfficialVerify? officialVerify,
    Live? live,
    Vip? vip,
    $core.Iterable<$fixnum.Int64>? assists,
    $fixnum.Int64? fans,
    $core.String? arcCount,
  }) {
    final result = OnwerExt._();
    if (officialVerify != null) result.officialVerify = officialVerify;
    if (live != null) result.live = live;
    if (vip != null) result.vip = vip;
    if (assists != null) result.assists.addAll(assists);
    if (fans != null) result.fans = fans;
    if (arcCount != null) result.arcCount = arcCount;
    return result;
  }

  OnwerExt._();

  factory OnwerExt.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OnwerExt()..mergeFromBuffer(data, registry);
  factory OnwerExt.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OnwerExt()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OnwerExt',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OnwerExt.$_createMessage)
    ..aOM<OfficialVerify>(1, _omitFieldNames ? '' : 'officialVerify',
        subBuilder: OfficialVerify.$_createMessage)
    ..aOM<Live>(2, _omitFieldNames ? '' : 'live',
        subBuilder: Live.$_createMessage)
    ..aOM<Vip>(3, _omitFieldNames ? '' : 'vip', subBuilder: Vip.$_createMessage)
    ..p<$fixnum.Int64>(4, _omitFieldNames ? '' : 'assists', $pb.PbFieldType.K6)
    ..aInt64(5, _omitFieldNames ? '' : 'fans')
    ..aOS(6, _omitFieldNames ? '' : 'arcCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OnwerExt clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OnwerExt copyWith(void Function(OnwerExt) updates) =>
      super.copyWith((message) => updates(message as OnwerExt)) as OnwerExt;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OnwerExt() / OnwerExt.new instead')
  static OnwerExt create() => OnwerExt._();
  static $pb.GeneratedMessage $_createMessage() => OnwerExt._();
  @$core.override
  OnwerExt createEmptyInstance() => OnwerExt._();
  @$core.pragma('dart2js:noInline')
  static OnwerExt getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OnwerExt>(OnwerExt.$_createMessage);
  static OnwerExt? _defaultInstance;

  /// 认证信息
  @$pb.TagNumber(1)
  OfficialVerify get officialVerify => $_getN(0);
  @$pb.TagNumber(1)
  set officialVerify(OfficialVerify value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOfficialVerify() => $_has(0);
  @$pb.TagNumber(1)
  void clearOfficialVerify() => $_clearField(1);
  @$pb.TagNumber(1)
  OfficialVerify ensureOfficialVerify() => $_ensure(0);

  /// 直播信息
  @$pb.TagNumber(2)
  Live get live => $_getN(1);
  @$pb.TagNumber(2)
  set live(Live value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLive() => $_has(1);
  @$pb.TagNumber(2)
  void clearLive() => $_clearField(2);
  @$pb.TagNumber(2)
  Live ensureLive() => $_ensure(1);

  /// 会员信息
  @$pb.TagNumber(3)
  Vip get vip => $_getN(2);
  @$pb.TagNumber(3)
  set vip(Vip value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVip() => $_has(2);
  @$pb.TagNumber(3)
  void clearVip() => $_clearField(3);
  @$pb.TagNumber(3)
  Vip ensureVip() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<$fixnum.Int64> get assists => $_getList(3);

  /// 粉丝数
  @$pb.TagNumber(5)
  $fixnum.Int64 get fans => $_getI64(4);
  @$pb.TagNumber(5)
  set fans($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFans() => $_has(4);
  @$pb.TagNumber(5)
  void clearFans() => $_clearField(5);

  /// 总投稿数
  @$pb.TagNumber(6)
  $core.String get arcCount => $_getSZ(5);
  @$pb.TagNumber(6)
  set arcCount($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasArcCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearArcCount() => $_clearField(6);
}

/// 老运营卡片
class OperationCard extends $pb.GeneratedMessage {
  factory OperationCard({
    $core.int? startTime,
    $core.int? endTime,
    $core.String? icon,
    $core.String? title,
    $core.String? buttonText,
    $core.String? url,
    $core.String? content,
  }) {
    final result = OperationCard._();
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (icon != null) result.icon = icon;
    if (title != null) result.title = title;
    if (buttonText != null) result.buttonText = buttonText;
    if (url != null) result.url = url;
    if (content != null) result.content = content;
    return result;
  }

  OperationCard._();

  factory OperationCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCard()..mergeFromBuffer(data, registry);
  factory OperationCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationCard',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OperationCard.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'startTime')
    ..aI(2, _omitFieldNames ? '' : 'endTime')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'buttonText')
    ..aOS(6, _omitFieldNames ? '' : 'url')
    ..aOS(7, _omitFieldNames ? '' : 'content')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCard copyWith(void Function(OperationCard) updates) =>
      super.copyWith((message) => updates(message as OperationCard))
          as OperationCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OperationCard() / OperationCard.new instead')
  static OperationCard create() => OperationCard._();
  static $pb.GeneratedMessage $_createMessage() => OperationCard._();
  @$core.override
  OperationCard createEmptyInstance() => OperationCard._();
  @$core.pragma('dart2js:noInline')
  static OperationCard getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationCard>(
          OperationCard.$_createMessage);
  static OperationCard? _defaultInstance;

  /// 开始时间(单位为秒)
  @$pb.TagNumber(1)
  $core.int get startTime => $_getIZ(0);
  @$pb.TagNumber(1)
  set startTime($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartTime() => $_clearField(1);

  /// 结束时间(单位为秒)
  @$pb.TagNumber(2)
  $core.int get endTime => $_getIZ(1);
  @$pb.TagNumber(2)
  set endTime($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndTime() => $_clearField(2);

  /// 图标
  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  /// 标题
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  /// 按钮文案
  @$pb.TagNumber(5)
  $core.String get buttonText => $_getSZ(4);
  @$pb.TagNumber(5)
  set buttonText($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasButtonText() => $_has(4);
  @$pb.TagNumber(5)
  void clearButtonText() => $_clearField(5);

  /// 跳转链接
  @$pb.TagNumber(6)
  $core.String get url => $_getSZ(5);
  @$pb.TagNumber(6)
  set url($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearUrl() => $_clearField(6);

  /// 内容描述
  @$pb.TagNumber(7)
  $core.String get content => $_getSZ(6);
  @$pb.TagNumber(7)
  set content($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasContent() => $_has(6);
  @$pb.TagNumber(7)
  void clearContent() => $_clearField(7);
}

enum OperationCardNew_Render { standard, skip, notSet }

enum OperationCardNew_Param { follow, reserve, jump, game, notSet }

/// 内嵌操作按钮卡片
class OperationCardNew extends $pb.GeneratedMessage {
  factory OperationCardNew({
    $fixnum.Int64? id,
    $core.int? from,
    $core.int? to,
    $core.bool? status,
    OperationCardType? cardType,
    StandardCard? standard,
    OperationCard? skip,
    BizType? bizType,
    BizFollowVideoParam? follow,
    BizReserveActivityParam? reserve,
    BizJumpLinkParam? jump,
    BizReserveGameParam? game,
  }) {
    final result = OperationCardNew._();
    if (id != null) result.id = id;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (status != null) result.status = status;
    if (cardType != null) result.cardType = cardType;
    if (standard != null) result.standard = standard;
    if (skip != null) result.skip = skip;
    if (bizType != null) result.bizType = bizType;
    if (follow != null) result.follow = follow;
    if (reserve != null) result.reserve = reserve;
    if (jump != null) result.jump = jump;
    if (game != null) result.game = game;
    return result;
  }

  OperationCardNew._();

  factory OperationCardNew.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCardNew()..mergeFromBuffer(data, registry);
  factory OperationCardNew.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCardNew()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, OperationCardNew_Render>
      _OperationCardNew_RenderByTag = {
    6: OperationCardNew_Render.standard,
    7: OperationCardNew_Render.skip,
    0: OperationCardNew_Render.notSet
  };
  static const $core.Map<$core.int, OperationCardNew_Param>
      _OperationCardNew_ParamByTag = {
    9: OperationCardNew_Param.follow,
    10: OperationCardNew_Param.reserve,
    11: OperationCardNew_Param.jump,
    12: OperationCardNew_Param.game,
    0: OperationCardNew_Param.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationCardNew',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OperationCardNew.$_createMessage)
    ..oo(0, [6, 7])
    ..oo(1, [9, 10, 11, 12])
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'from')
    ..aI(3, _omitFieldNames ? '' : 'to')
    ..aOB(4, _omitFieldNames ? '' : 'status')
    ..aE<OperationCardType>(5, _omitFieldNames ? '' : 'cardType',
        enumValues: OperationCardType.values)
    ..aOM<StandardCard>(6, _omitFieldNames ? '' : 'standard',
        subBuilder: StandardCard.$_createMessage)
    ..aOM<OperationCard>(7, _omitFieldNames ? '' : 'skip',
        subBuilder: OperationCard.$_createMessage)
    ..aE<BizType>(8, _omitFieldNames ? '' : 'bizType',
        enumValues: BizType.values)
    ..aOM<BizFollowVideoParam>(9, _omitFieldNames ? '' : 'follow',
        subBuilder: BizFollowVideoParam.$_createMessage)
    ..aOM<BizReserveActivityParam>(10, _omitFieldNames ? '' : 'reserve',
        subBuilder: BizReserveActivityParam.$_createMessage)
    ..aOM<BizJumpLinkParam>(11, _omitFieldNames ? '' : 'jump',
        subBuilder: BizJumpLinkParam.$_createMessage)
    ..aOM<BizReserveGameParam>(12, _omitFieldNames ? '' : 'game',
        subBuilder: BizReserveGameParam.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCardNew clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCardNew copyWith(void Function(OperationCardNew) updates) =>
      super.copyWith((message) => updates(message as OperationCardNew))
          as OperationCardNew;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OperationCardNew() / OperationCardNew.new instead')
  static OperationCardNew create() => OperationCardNew._();
  static $pb.GeneratedMessage $_createMessage() => OperationCardNew._();
  @$core.override
  OperationCardNew createEmptyInstance() => OperationCardNew._();
  @$core.pragma('dart2js:noInline')
  static OperationCardNew getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationCardNew>(
          OperationCardNew.$_createMessage);
  static OperationCardNew? _defaultInstance;

  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  OperationCardNew_Render whichRender() =>
      _OperationCardNew_RenderByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearRender() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  OperationCardNew_Param whichParam() =>
      _OperationCardNew_ParamByTag[$_whichOneof(1)]!;
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  void clearParam() => $_clearField($_whichOneof(1));

  /// 卡片id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 开始时间
  @$pb.TagNumber(2)
  $core.int get from => $_getIZ(1);
  @$pb.TagNumber(2)
  set from($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  /// 结束时间
  @$pb.TagNumber(3)
  $core.int get to => $_getIZ(2);
  @$pb.TagNumber(3)
  set to($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);

  /// 用户操作态
  /// true已操作 false未操作
  @$pb.TagNumber(4)
  $core.bool get status => $_getBF(3);
  @$pb.TagNumber(4)
  set status($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  /// 卡片类型
  @$pb.TagNumber(5)
  OperationCardType get cardType => $_getN(4);
  @$pb.TagNumber(5)
  set cardType(OperationCardType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCardType() => $_has(4);
  @$pb.TagNumber(5)
  void clearCardType() => $_clearField(5);

  /// 标准卡
  @$pb.TagNumber(6)
  StandardCard get standard => $_getN(5);
  @$pb.TagNumber(6)
  set standard(StandardCard value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStandard() => $_has(5);
  @$pb.TagNumber(6)
  void clearStandard() => $_clearField(6);
  @$pb.TagNumber(6)
  StandardCard ensureStandard() => $_ensure(5);

  /// 老运营卡片(原B剪跳转卡)
  @$pb.TagNumber(7)
  OperationCard get skip => $_getN(6);
  @$pb.TagNumber(7)
  set skip(OperationCard value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSkip() => $_has(6);
  @$pb.TagNumber(7)
  void clearSkip() => $_clearField(7);
  @$pb.TagNumber(7)
  OperationCard ensureSkip() => $_ensure(6);

  @$pb.TagNumber(8)
  BizType get bizType => $_getN(7);
  @$pb.TagNumber(8)
  set bizType(BizType value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasBizType() => $_has(7);
  @$pb.TagNumber(8)
  void clearBizType() => $_clearField(8);

  /// 追番追剧参数
  @$pb.TagNumber(9)
  BizFollowVideoParam get follow => $_getN(8);
  @$pb.TagNumber(9)
  set follow(BizFollowVideoParam value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasFollow() => $_has(8);
  @$pb.TagNumber(9)
  void clearFollow() => $_clearField(9);
  @$pb.TagNumber(9)
  BizFollowVideoParam ensureFollow() => $_ensure(8);

  /// 预约活动参数
  @$pb.TagNumber(10)
  BizReserveActivityParam get reserve => $_getN(9);
  @$pb.TagNumber(10)
  set reserve(BizReserveActivityParam value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasReserve() => $_has(9);
  @$pb.TagNumber(10)
  void clearReserve() => $_clearField(10);
  @$pb.TagNumber(10)
  BizReserveActivityParam ensureReserve() => $_ensure(9);

  /// 跳转参数
  @$pb.TagNumber(11)
  BizJumpLinkParam get jump => $_getN(10);
  @$pb.TagNumber(11)
  set jump(BizJumpLinkParam value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasJump() => $_has(10);
  @$pb.TagNumber(11)
  void clearJump() => $_clearField(11);
  @$pb.TagNumber(11)
  BizJumpLinkParam ensureJump() => $_ensure(10);

  /// 预约游戏参数
  @$pb.TagNumber(12)
  BizReserveGameParam get game => $_getN(11);
  @$pb.TagNumber(12)
  set game(BizReserveGameParam value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasGame() => $_has(11);
  @$pb.TagNumber(12)
  void clearGame() => $_clearField(12);
  @$pb.TagNumber(12)
  BizReserveGameParam ensureGame() => $_ensure(11);
}

enum OperationCardV2_Param {
  bizFollowVideoParam,
  bizReserveActivityParam,
  bizJumpLinkParam,
  bizReserveGameParam,
  notSet
}

class OperationCardV2 extends $pb.GeneratedMessage {
  factory OperationCardV2({
    $fixnum.Int64? id,
    $core.int? from,
    $core.int? to,
    $core.bool? status,
    $core.int? bizType,
    OperationCardV2Content? content,
    BizFollowVideoParam? bizFollowVideoParam,
    BizReserveActivityParam? bizReserveActivityParam,
    BizJumpLinkParam? bizJumpLinkParam,
    BizReserveGameParam? bizReserveGameParam,
  }) {
    final result = OperationCardV2._();
    if (id != null) result.id = id;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (status != null) result.status = status;
    if (bizType != null) result.bizType = bizType;
    if (content != null) result.content = content;
    if (bizFollowVideoParam != null)
      result.bizFollowVideoParam = bizFollowVideoParam;
    if (bizReserveActivityParam != null)
      result.bizReserveActivityParam = bizReserveActivityParam;
    if (bizJumpLinkParam != null) result.bizJumpLinkParam = bizJumpLinkParam;
    if (bizReserveGameParam != null)
      result.bizReserveGameParam = bizReserveGameParam;
    return result;
  }

  OperationCardV2._();

  factory OperationCardV2.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCardV2()..mergeFromBuffer(data, registry);
  factory OperationCardV2.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCardV2()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, OperationCardV2_Param>
      _OperationCardV2_ParamByTag = {
    7: OperationCardV2_Param.bizFollowVideoParam,
    8: OperationCardV2_Param.bizReserveActivityParam,
    9: OperationCardV2_Param.bizJumpLinkParam,
    10: OperationCardV2_Param.bizReserveGameParam,
    0: OperationCardV2_Param.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationCardV2',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OperationCardV2.$_createMessage)
    ..oo(0, [7, 8, 9, 10])
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'from')
    ..aI(3, _omitFieldNames ? '' : 'to')
    ..aOB(4, _omitFieldNames ? '' : 'status')
    ..aI(5, _omitFieldNames ? '' : 'bizType')
    ..aOM<OperationCardV2Content>(6, _omitFieldNames ? '' : 'content',
        subBuilder: OperationCardV2Content.$_createMessage)
    ..aOM<BizFollowVideoParam>(7, _omitFieldNames ? '' : 'BizFollowVideoParam',
        protoName: 'BizFollowVideoParam',
        subBuilder: BizFollowVideoParam.$_createMessage)
    ..aOM<BizReserveActivityParam>(
        8, _omitFieldNames ? '' : 'BizReserveActivityParam',
        protoName: 'BizReserveActivityParam',
        subBuilder: BizReserveActivityParam.$_createMessage)
    ..aOM<BizJumpLinkParam>(9, _omitFieldNames ? '' : 'BizJumpLinkParam',
        protoName: 'BizJumpLinkParam',
        subBuilder: BizJumpLinkParam.$_createMessage)
    ..aOM<BizReserveGameParam>(10, _omitFieldNames ? '' : 'BizReserveGameParam',
        protoName: 'BizReserveGameParam',
        subBuilder: BizReserveGameParam.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCardV2 clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCardV2 copyWith(void Function(OperationCardV2) updates) =>
      super.copyWith((message) => updates(message as OperationCardV2))
          as OperationCardV2;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OperationCardV2() / OperationCardV2.new instead')
  static OperationCardV2 create() => OperationCardV2._();
  static $pb.GeneratedMessage $_createMessage() => OperationCardV2._();
  @$core.override
  OperationCardV2 createEmptyInstance() => OperationCardV2._();
  @$core.pragma('dart2js:noInline')
  static OperationCardV2 getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationCardV2>(
          OperationCardV2.$_createMessage);
  static OperationCardV2? _defaultInstance;

  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  OperationCardV2_Param whichParam() =>
      _OperationCardV2_ParamByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  void clearParam() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get from => $_getIZ(1);
  @$pb.TagNumber(2)
  set from($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get to => $_getIZ(2);
  @$pb.TagNumber(3)
  set to($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get status => $_getBF(3);
  @$pb.TagNumber(4)
  set status($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get bizType => $_getIZ(4);
  @$pb.TagNumber(5)
  set bizType($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBizType() => $_has(4);
  @$pb.TagNumber(5)
  void clearBizType() => $_clearField(5);

  @$pb.TagNumber(6)
  OperationCardV2Content get content => $_getN(5);
  @$pb.TagNumber(6)
  set content(OperationCardV2Content value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasContent() => $_has(5);
  @$pb.TagNumber(6)
  void clearContent() => $_clearField(6);
  @$pb.TagNumber(6)
  OperationCardV2Content ensureContent() => $_ensure(5);

  @$pb.TagNumber(7)
  BizFollowVideoParam get bizFollowVideoParam => $_getN(6);
  @$pb.TagNumber(7)
  set bizFollowVideoParam(BizFollowVideoParam value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasBizFollowVideoParam() => $_has(6);
  @$pb.TagNumber(7)
  void clearBizFollowVideoParam() => $_clearField(7);
  @$pb.TagNumber(7)
  BizFollowVideoParam ensureBizFollowVideoParam() => $_ensure(6);

  @$pb.TagNumber(8)
  BizReserveActivityParam get bizReserveActivityParam => $_getN(7);
  @$pb.TagNumber(8)
  set bizReserveActivityParam(BizReserveActivityParam value) =>
      $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasBizReserveActivityParam() => $_has(7);
  @$pb.TagNumber(8)
  void clearBizReserveActivityParam() => $_clearField(8);
  @$pb.TagNumber(8)
  BizReserveActivityParam ensureBizReserveActivityParam() => $_ensure(7);

  @$pb.TagNumber(9)
  BizJumpLinkParam get bizJumpLinkParam => $_getN(8);
  @$pb.TagNumber(9)
  set bizJumpLinkParam(BizJumpLinkParam value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasBizJumpLinkParam() => $_has(8);
  @$pb.TagNumber(9)
  void clearBizJumpLinkParam() => $_clearField(9);
  @$pb.TagNumber(9)
  BizJumpLinkParam ensureBizJumpLinkParam() => $_ensure(8);

  @$pb.TagNumber(10)
  BizReserveGameParam get bizReserveGameParam => $_getN(9);
  @$pb.TagNumber(10)
  set bizReserveGameParam(BizReserveGameParam value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasBizReserveGameParam() => $_has(9);
  @$pb.TagNumber(10)
  void clearBizReserveGameParam() => $_clearField(10);
  @$pb.TagNumber(10)
  BizReserveGameParam ensureBizReserveGameParam() => $_ensure(9);
}

class OperationCardV2Content extends $pb.GeneratedMessage {
  factory OperationCardV2Content({
    $core.String? title,
    $core.String? subtitle,
    $core.String? icon,
    $core.String? buttonTitle,
    $core.String? buttonSelectedTitle,
    $core.bool? showSelected,
  }) {
    final result = OperationCardV2Content._();
    if (title != null) result.title = title;
    if (subtitle != null) result.subtitle = subtitle;
    if (icon != null) result.icon = icon;
    if (buttonTitle != null) result.buttonTitle = buttonTitle;
    if (buttonSelectedTitle != null)
      result.buttonSelectedTitle = buttonSelectedTitle;
    if (showSelected != null) result.showSelected = showSelected;
    return result;
  }

  OperationCardV2Content._();

  factory OperationCardV2Content.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCardV2Content()..mergeFromBuffer(data, registry);
  factory OperationCardV2Content.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationCardV2Content()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationCardV2Content',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OperationCardV2Content.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'subtitle')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'buttonTitle')
    ..aOS(5, _omitFieldNames ? '' : 'buttonSelectedTitle')
    ..aOB(6, _omitFieldNames ? '' : 'showSelected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCardV2Content clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationCardV2Content copyWith(
          void Function(OperationCardV2Content) updates) =>
      super.copyWith((message) => updates(message as OperationCardV2Content))
          as OperationCardV2Content;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use OperationCardV2Content() / OperationCardV2Content.new instead')
  static OperationCardV2Content create() => OperationCardV2Content._();
  static $pb.GeneratedMessage $_createMessage() => OperationCardV2Content._();
  @$core.override
  OperationCardV2Content createEmptyInstance() => OperationCardV2Content._();
  @$core.pragma('dart2js:noInline')
  static OperationCardV2Content getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OperationCardV2Content>(
          OperationCardV2Content.$_createMessage);
  static OperationCardV2Content? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subtitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set subtitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubtitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubtitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get buttonTitle => $_getSZ(3);
  @$pb.TagNumber(4)
  set buttonTitle($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasButtonTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearButtonTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get buttonSelectedTitle => $_getSZ(4);
  @$pb.TagNumber(5)
  set buttonSelectedTitle($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasButtonSelectedTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearButtonSelectedTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get showSelected => $_getBF(5);
  @$pb.TagNumber(6)
  set showSelected($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasShowSelected() => $_has(5);
  @$pb.TagNumber(6)
  void clearShowSelected() => $_clearField(6);
}

/// 相关推荐(运营配置+AI推荐)
class OperationRelate extends $pb.GeneratedMessage {
  factory OperationRelate({
    $core.String? title,
    $core.Iterable<RelateItem>? relateItem,
    $core.Iterable<Relate>? aiRelateItem,
  }) {
    final result = OperationRelate._();
    if (title != null) result.title = title;
    if (relateItem != null) result.relateItem.addAll(relateItem);
    if (aiRelateItem != null) result.aiRelateItem.addAll(aiRelateItem);
    return result;
  }

  OperationRelate._();

  factory OperationRelate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationRelate()..mergeFromBuffer(data, registry);
  factory OperationRelate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationRelate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationRelate',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: OperationRelate.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..pPM<RelateItem>(2, _omitFieldNames ? '' : 'relateItem',
        subBuilder: RelateItem.$_createMessage)
    ..pPM<Relate>(3, _omitFieldNames ? '' : 'aiRelateItem',
        subBuilder: Relate.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationRelate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationRelate copyWith(void Function(OperationRelate) updates) =>
      super.copyWith((message) => updates(message as OperationRelate))
          as OperationRelate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OperationRelate() / OperationRelate.new instead')
  static OperationRelate create() => OperationRelate._();
  static $pb.GeneratedMessage $_createMessage() => OperationRelate._();
  @$core.override
  OperationRelate createEmptyInstance() => OperationRelate._();
  @$core.pragma('dart2js:noInline')
  static OperationRelate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationRelate>(
          OperationRelate.$_createMessage);
  static OperationRelate? _defaultInstance;

  /// 模块标题
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 相关推荐模块内容
  @$pb.TagNumber(2)
  $pb.PbList<RelateItem> get relateItem => $_getList(1);

  /// AI相关推荐
  @$pb.TagNumber(3)
  $pb.PbList<Relate> get aiRelateItem => $_getList(2);
}

enum Order_OrderParam { reserve, favSeason, notSet }

/// 预约模块
class Order extends $pb.GeneratedMessage {
  factory Order({
    $core.bool? status,
    $core.String? title,
    $core.String? buttonTitle,
    $core.String? buttonSelectedTitle,
    $fixnum.Int64? seasonStatView,
    $fixnum.Int64? seasonStatDanmaku,
    BizType? orderType,
    BizReserveActivityParam? reserve,
    BizFavSeasonParam? favSeason,
    $core.String? intro,
  }) {
    final result = Order._();
    if (status != null) result.status = status;
    if (title != null) result.title = title;
    if (buttonTitle != null) result.buttonTitle = buttonTitle;
    if (buttonSelectedTitle != null)
      result.buttonSelectedTitle = buttonSelectedTitle;
    if (seasonStatView != null) result.seasonStatView = seasonStatView;
    if (seasonStatDanmaku != null) result.seasonStatDanmaku = seasonStatDanmaku;
    if (orderType != null) result.orderType = orderType;
    if (reserve != null) result.reserve = reserve;
    if (favSeason != null) result.favSeason = favSeason;
    if (intro != null) result.intro = intro;
    return result;
  }

  Order._();

  factory Order.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Order()..mergeFromBuffer(data, registry);
  factory Order.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Order()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Order_OrderParam> _Order_OrderParamByTag = {
    8: Order_OrderParam.reserve,
    9: Order_OrderParam.favSeason,
    0: Order_OrderParam.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Order',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Order.$_createMessage)
    ..oo(0, [8, 9])
    ..aOB(1, _omitFieldNames ? '' : 'status')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'buttonTitle')
    ..aOS(4, _omitFieldNames ? '' : 'buttonSelectedTitle')
    ..aInt64(5, _omitFieldNames ? '' : 'seasonStatView')
    ..aInt64(6, _omitFieldNames ? '' : 'seasonStatDanmaku')
    ..aE<BizType>(7, _omitFieldNames ? '' : 'orderType',
        enumValues: BizType.values)
    ..aOM<BizReserveActivityParam>(8, _omitFieldNames ? '' : 'reserve',
        subBuilder: BizReserveActivityParam.$_createMessage)
    ..aOM<BizFavSeasonParam>(9, _omitFieldNames ? '' : 'favSeason',
        subBuilder: BizFavSeasonParam.$_createMessage)
    ..aOS(10, _omitFieldNames ? '' : 'intro')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Order clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Order copyWith(void Function(Order) updates) =>
      super.copyWith((message) => updates(message as Order)) as Order;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Order() / Order.new instead')
  static Order create() => Order._();
  static $pb.GeneratedMessage $_createMessage() => Order._();
  @$core.override
  Order createEmptyInstance() => Order._();
  @$core.pragma('dart2js:noInline')
  static Order getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Order>(Order.$_createMessage);
  static Order? _defaultInstance;

  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  Order_OrderParam whichOrderParam() =>
      _Order_OrderParamByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  void clearOrderParam() => $_clearField($_whichOneof(0));

  /// 用户操作态
  @$pb.TagNumber(1)
  $core.bool get status => $_getBF(0);
  @$pb.TagNumber(1)
  set status($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  /// 模块标题
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// 按钮文字 未操作
  @$pb.TagNumber(3)
  $core.String get buttonTitle => $_getSZ(2);
  @$pb.TagNumber(3)
  set buttonTitle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasButtonTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearButtonTitle() => $_clearField(3);

  /// 按钮文字 已操作
  @$pb.TagNumber(4)
  $core.String get buttonSelectedTitle => $_getSZ(3);
  @$pb.TagNumber(4)
  set buttonSelectedTitle($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasButtonSelectedTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearButtonSelectedTitle() => $_clearField(4);

  /// 合集播放数
  @$pb.TagNumber(5)
  $fixnum.Int64 get seasonStatView => $_getI64(4);
  @$pb.TagNumber(5)
  set seasonStatView($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSeasonStatView() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeasonStatView() => $_clearField(5);

  /// 合集弹幕数
  @$pb.TagNumber(6)
  $fixnum.Int64 get seasonStatDanmaku => $_getI64(5);
  @$pb.TagNumber(6)
  set seasonStatDanmaku($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSeasonStatDanmaku() => $_has(5);
  @$pb.TagNumber(6)
  void clearSeasonStatDanmaku() => $_clearField(6);

  /// 预约类型(点击时透传，直播开始前预约活动，直播开始后收藏合集)
  @$pb.TagNumber(7)
  BizType get orderType => $_getN(6);
  @$pb.TagNumber(7)
  set orderType(BizType value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOrderType() => $_has(6);
  @$pb.TagNumber(7)
  void clearOrderType() => $_clearField(7);

  /// 预约活动参数
  @$pb.TagNumber(8)
  BizReserveActivityParam get reserve => $_getN(7);
  @$pb.TagNumber(8)
  set reserve(BizReserveActivityParam value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasReserve() => $_has(7);
  @$pb.TagNumber(8)
  void clearReserve() => $_clearField(8);
  @$pb.TagNumber(8)
  BizReserveActivityParam ensureReserve() => $_ensure(7);

  /// 收藏合集参数
  @$pb.TagNumber(9)
  BizFavSeasonParam get favSeason => $_getN(8);
  @$pb.TagNumber(9)
  set favSeason(BizFavSeasonParam value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasFavSeason() => $_has(8);
  @$pb.TagNumber(9)
  void clearFavSeason() => $_clearField(9);
  @$pb.TagNumber(9)
  BizFavSeasonParam ensureFavSeason() => $_ensure(8);

  /// 合集简介
  @$pb.TagNumber(10)
  $core.String get intro => $_getSZ(9);
  @$pb.TagNumber(10)
  set intro($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIntro() => $_has(9);
  @$pb.TagNumber(10)
  void clearIntro() => $_clearField(10);
}

/// 游戏礼包信息
class PackInfo extends $pb.GeneratedMessage {
  factory PackInfo({
    $core.String? title,
    $core.String? uri,
  }) {
    final result = PackInfo._();
    if (title != null) result.title = title;
    if (uri != null) result.uri = uri;
    return result;
  }

  PackInfo._();

  factory PackInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PackInfo()..mergeFromBuffer(data, registry);
  factory PackInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PackInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PackInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PackInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'uri')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackInfo copyWith(void Function(PackInfo) updates) =>
      super.copyWith((message) => updates(message as PackInfo)) as PackInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PackInfo() / PackInfo.new instead')
  static PackInfo create() => PackInfo._();
  static $pb.GeneratedMessage $_createMessage() => PackInfo._();
  @$core.override
  PackInfo createEmptyInstance() => PackInfo._();
  @$core.pragma('dart2js:noInline')
  static PackInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PackInfo>(PackInfo.$_createMessage);
  static PackInfo? _defaultInstance;

  /// 礼包标题
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 礼包页uri
  @$pb.TagNumber(2)
  $core.String get uri => $_getSZ(1);
  @$pb.TagNumber(2)
  set uri($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUri() => $_has(1);
  @$pb.TagNumber(2)
  void clearUri() => $_clearField(2);
}

class PlayAv extends $pb.GeneratedMessage {
  factory PlayAv({
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
  }) {
    final result = PlayAv._();
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    return result;
  }

  PlayAv._();

  factory PlayAv.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayAv()..mergeFromBuffer(data, registry);
  factory PlayAv.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayAv()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayAv',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PlayAv.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aInt64(2, _omitFieldNames ? '' : 'cid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayAv clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayAv copyWith(void Function(PlayAv) updates) =>
      super.copyWith((message) => updates(message as PlayAv)) as PlayAv;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayAv() / PlayAv.new instead')
  static PlayAv create() => PlayAv._();
  static $pb.GeneratedMessage $_createMessage() => PlayAv._();
  @$core.override
  PlayAv createEmptyInstance() => PlayAv._();
  @$core.pragma('dart2js:noInline')
  static PlayAv getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayAv>(PlayAv.$_createMessage);
  static PlayAv? _defaultInstance;

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

/// 进度条动画配置
class PlayerIcon extends $pb.GeneratedMessage {
  factory PlayerIcon({
    $core.String? url1,
    $core.String? hash1,
    $core.String? url2,
    $core.String? hash2,
    $core.String? dragLeftPng,
    $core.String? middlePng,
    $core.String? dragRightPng,
    IconData? dragData,
    IconData? nodragData,
  }) {
    final result = PlayerIcon._();
    if (url1 != null) result.url1 = url1;
    if (hash1 != null) result.hash1 = hash1;
    if (url2 != null) result.url2 = url2;
    if (hash2 != null) result.hash2 = hash2;
    if (dragLeftPng != null) result.dragLeftPng = dragLeftPng;
    if (middlePng != null) result.middlePng = middlePng;
    if (dragRightPng != null) result.dragRightPng = dragRightPng;
    if (dragData != null) result.dragData = dragData;
    if (nodragData != null) result.nodragData = nodragData;
    return result;
  }

  PlayerIcon._();

  factory PlayerIcon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayerIcon()..mergeFromBuffer(data, registry);
  factory PlayerIcon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayerIcon()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerIcon',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PlayerIcon.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url1')
    ..aOS(2, _omitFieldNames ? '' : 'hash1')
    ..aOS(3, _omitFieldNames ? '' : 'url2')
    ..aOS(4, _omitFieldNames ? '' : 'hash2')
    ..aOS(5, _omitFieldNames ? '' : 'dragLeftPng')
    ..aOS(6, _omitFieldNames ? '' : 'middlePng')
    ..aOS(7, _omitFieldNames ? '' : 'dragRightPng')
    ..aOM<IconData>(8, _omitFieldNames ? '' : 'dragData',
        subBuilder: IconData.$_createMessage)
    ..aOM<IconData>(9, _omitFieldNames ? '' : 'nodragData',
        subBuilder: IconData.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerIcon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerIcon copyWith(void Function(PlayerIcon) updates) =>
      super.copyWith((message) => updates(message as PlayerIcon)) as PlayerIcon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayerIcon() / PlayerIcon.new instead')
  static PlayerIcon create() => PlayerIcon._();
  static $pb.GeneratedMessage $_createMessage() => PlayerIcon._();
  @$core.override
  PlayerIcon createEmptyInstance() => PlayerIcon._();
  @$core.pragma('dart2js:noInline')
  static PlayerIcon getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayerIcon>(PlayerIcon.$_createMessage);
  static PlayerIcon? _defaultInstance;

  /// 拖动动画配置档url
  @$pb.TagNumber(1)
  $core.String get url1 => $_getSZ(0);
  @$pb.TagNumber(1)
  set url1($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl1() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl1() => $_clearField(1);

  /// 拖动动画配置档hash
  @$pb.TagNumber(2)
  $core.String get hash1 => $_getSZ(1);
  @$pb.TagNumber(2)
  set hash1($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHash1() => $_has(1);
  @$pb.TagNumber(2)
  void clearHash1() => $_clearField(2);

  /// 松手动画配置档url
  @$pb.TagNumber(3)
  $core.String get url2 => $_getSZ(2);
  @$pb.TagNumber(3)
  set url2($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrl2() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrl2() => $_clearField(3);

  /// 松手动画配置档hash
  @$pb.TagNumber(4)
  $core.String get hash2 => $_getSZ(3);
  @$pb.TagNumber(4)
  set hash2($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHash2() => $_has(3);
  @$pb.TagNumber(4)
  void clearHash2() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get dragLeftPng => $_getSZ(4);
  @$pb.TagNumber(5)
  set dragLeftPng($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDragLeftPng() => $_has(4);
  @$pb.TagNumber(5)
  void clearDragLeftPng() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get middlePng => $_getSZ(5);
  @$pb.TagNumber(6)
  set middlePng($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMiddlePng() => $_has(5);
  @$pb.TagNumber(6)
  void clearMiddlePng() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get dragRightPng => $_getSZ(6);
  @$pb.TagNumber(7)
  set dragRightPng($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDragRightPng() => $_has(6);
  @$pb.TagNumber(7)
  void clearDragRightPng() => $_clearField(7);

  @$pb.TagNumber(8)
  IconData get dragData => $_getN(7);
  @$pb.TagNumber(8)
  set dragData(IconData value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDragData() => $_has(7);
  @$pb.TagNumber(8)
  void clearDragData() => $_clearField(8);
  @$pb.TagNumber(8)
  IconData ensureDragData() => $_ensure(7);

  @$pb.TagNumber(9)
  IconData get nodragData => $_getN(8);
  @$pb.TagNumber(9)
  set nodragData(IconData value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasNodragData() => $_has(8);
  @$pb.TagNumber(9)
  void clearNodragData() => $_clearField(9);
  @$pb.TagNumber(9)
  IconData ensureNodragData() => $_ensure(8);
}

class PlayerRelatesReply extends $pb.GeneratedMessage {
  factory PlayerRelatesReply({
    $core.Iterable<Relate>? list,
  }) {
    final result = PlayerRelatesReply._();
    if (list != null) result.list.addAll(list);
    return result;
  }

  PlayerRelatesReply._();

  factory PlayerRelatesReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayerRelatesReply()..mergeFromBuffer(data, registry);
  factory PlayerRelatesReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayerRelatesReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerRelatesReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PlayerRelatesReply.$_createMessage)
    ..pPM<Relate>(1, _omitFieldNames ? '' : 'list',
        subBuilder: Relate.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerRelatesReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerRelatesReply copyWith(void Function(PlayerRelatesReply) updates) =>
      super.copyWith((message) => updates(message as PlayerRelatesReply))
          as PlayerRelatesReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayerRelatesReply() / PlayerRelatesReply.new instead')
  static PlayerRelatesReply create() => PlayerRelatesReply._();
  static $pb.GeneratedMessage $_createMessage() => PlayerRelatesReply._();
  @$core.override
  PlayerRelatesReply createEmptyInstance() => PlayerRelatesReply._();
  @$core.pragma('dart2js:noInline')
  static PlayerRelatesReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayerRelatesReply>(
          PlayerRelatesReply.$_createMessage);
  static PlayerRelatesReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Relate> get list => $_getList(0);
}

class PlayerRelatesReq extends $pb.GeneratedMessage {
  factory PlayerRelatesReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $core.String? from,
    $core.String? spmid,
    $core.String? fromSpmid,
    $3.PlayerArgs? playerArgs,
    $core.String? sessionId,
    $core.String? fromTrackId,
  }) {
    final result = PlayerRelatesReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (from != null) result.from = from;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (playerArgs != null) result.playerArgs = playerArgs;
    if (sessionId != null) result.sessionId = sessionId;
    if (fromTrackId != null) result.fromTrackId = fromTrackId;
    return result;
  }

  PlayerRelatesReq._();

  factory PlayerRelatesReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayerRelatesReq()..mergeFromBuffer(data, registry);
  factory PlayerRelatesReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayerRelatesReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerRelatesReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PlayerRelatesReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aOS(3, _omitFieldNames ? '' : 'from')
    ..aOS(4, _omitFieldNames ? '' : 'spmid')
    ..aOS(5, _omitFieldNames ? '' : 'fromSpmid')
    ..aOM<$3.PlayerArgs>(6, _omitFieldNames ? '' : 'playerArgs',
        subBuilder: $3.PlayerArgs.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'sessionId')
    ..aOS(8, _omitFieldNames ? '' : 'fromTrackId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerRelatesReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerRelatesReq copyWith(void Function(PlayerRelatesReq) updates) =>
      super.copyWith((message) => updates(message as PlayerRelatesReq))
          as PlayerRelatesReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayerRelatesReq() / PlayerRelatesReq.new instead')
  static PlayerRelatesReq create() => PlayerRelatesReq._();
  static $pb.GeneratedMessage $_createMessage() => PlayerRelatesReq._();
  @$core.override
  PlayerRelatesReq createEmptyInstance() => PlayerRelatesReq._();
  @$core.pragma('dart2js:noInline')
  static PlayerRelatesReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayerRelatesReq>(
          PlayerRelatesReq.$_createMessage);
  static PlayerRelatesReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get from => $_getSZ(2);
  @$pb.TagNumber(3)
  set from($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get spmid => $_getSZ(3);
  @$pb.TagNumber(4)
  set spmid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpmid() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpmid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fromSpmid => $_getSZ(4);
  @$pb.TagNumber(5)
  set fromSpmid($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFromSpmid() => $_has(4);
  @$pb.TagNumber(5)
  void clearFromSpmid() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.PlayerArgs get playerArgs => $_getN(5);
  @$pb.TagNumber(6)
  set playerArgs($3.PlayerArgs value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlayerArgs() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlayerArgs() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.PlayerArgs ensurePlayerArgs() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get sessionId => $_getSZ(6);
  @$pb.TagNumber(7)
  set sessionId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSessionId() => $_has(6);
  @$pb.TagNumber(7)
  void clearSessionId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get fromTrackId => $_getSZ(7);
  @$pb.TagNumber(8)
  set fromTrackId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFromTrackId() => $_has(7);
  @$pb.TagNumber(8)
  void clearFromTrackId() => $_clearField(8);
}

class PointMaterial extends $pb.GeneratedMessage {
  factory PointMaterial({
    $core.String? url,
    $core.int? materialSource,
  }) {
    final result = PointMaterial._();
    if (url != null) result.url = url;
    if (materialSource != null) result.materialSource = materialSource;
    return result;
  }

  PointMaterial._();

  factory PointMaterial.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PointMaterial()..mergeFromBuffer(data, registry);
  factory PointMaterial.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PointMaterial()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PointMaterial',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PointMaterial.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aI(2, _omitFieldNames ? '' : 'materialSource')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointMaterial clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointMaterial copyWith(void Function(PointMaterial) updates) =>
      super.copyWith((message) => updates(message as PointMaterial))
          as PointMaterial;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PointMaterial() / PointMaterial.new instead')
  static PointMaterial create() => PointMaterial._();
  static $pb.GeneratedMessage $_createMessage() => PointMaterial._();
  @$core.override
  PointMaterial createEmptyInstance() => PointMaterial._();
  @$core.pragma('dart2js:noInline')
  static PointMaterial getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PointMaterial>(
          PointMaterial.$_createMessage);
  static PointMaterial? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get materialSource => $_getIZ(1);
  @$pb.TagNumber(2)
  set materialSource($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaterialSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaterialSource() => $_clearField(2);
}

class PowerIconStyle extends $pb.GeneratedMessage {
  factory PowerIconStyle({
    $core.String? iconUrl,
    $core.String? iconNightUrl,
    $fixnum.Int64? iconWidth,
    $fixnum.Int64? iconHeight,
  }) {
    final result = PowerIconStyle._();
    if (iconUrl != null) result.iconUrl = iconUrl;
    if (iconNightUrl != null) result.iconNightUrl = iconNightUrl;
    if (iconWidth != null) result.iconWidth = iconWidth;
    if (iconHeight != null) result.iconHeight = iconHeight;
    return result;
  }

  PowerIconStyle._();

  factory PowerIconStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PowerIconStyle()..mergeFromBuffer(data, registry);
  factory PowerIconStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PowerIconStyle()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PowerIconStyle',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PowerIconStyle.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'iconUrl')
    ..aOS(2, _omitFieldNames ? '' : 'iconNightUrl')
    ..aInt64(3, _omitFieldNames ? '' : 'iconWidth')
    ..aInt64(4, _omitFieldNames ? '' : 'iconHeight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PowerIconStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PowerIconStyle copyWith(void Function(PowerIconStyle) updates) =>
      super.copyWith((message) => updates(message as PowerIconStyle))
          as PowerIconStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PowerIconStyle() / PowerIconStyle.new instead')
  static PowerIconStyle create() => PowerIconStyle._();
  static $pb.GeneratedMessage $_createMessage() => PowerIconStyle._();
  @$core.override
  PowerIconStyle createEmptyInstance() => PowerIconStyle._();
  @$core.pragma('dart2js:noInline')
  static PowerIconStyle getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PowerIconStyle>(
          PowerIconStyle.$_createMessage);
  static PowerIconStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get iconUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set iconUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIconUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearIconUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get iconNightUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconNightUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconNightUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconNightUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get iconWidth => $_getI64(2);
  @$pb.TagNumber(3)
  set iconWidth($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIconWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearIconWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get iconHeight => $_getI64(3);
  @$pb.TagNumber(4)
  set iconHeight($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIconHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearIconHeight() => $_clearField(4);
}

class Premiere extends $pb.GeneratedMessage {
  factory Premiere({
    PremiereState? premiereState,
    $fixnum.Int64? startTime,
    $fixnum.Int64? serviceTime,
    $fixnum.Int64? roomId,
  }) {
    final result = Premiere._();
    if (premiereState != null) result.premiereState = premiereState;
    if (startTime != null) result.startTime = startTime;
    if (serviceTime != null) result.serviceTime = serviceTime;
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  Premiere._();

  factory Premiere.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Premiere()..mergeFromBuffer(data, registry);
  factory Premiere.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Premiere()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Premiere',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Premiere.$_createMessage)
    ..aE<PremiereState>(1, _omitFieldNames ? '' : 'premiereState',
        enumValues: PremiereState.values)
    ..aInt64(2, _omitFieldNames ? '' : 'startTime')
    ..aInt64(3, _omitFieldNames ? '' : 'serviceTime')
    ..aInt64(4, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Premiere clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Premiere copyWith(void Function(Premiere) updates) =>
      super.copyWith((message) => updates(message as Premiere)) as Premiere;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Premiere() / Premiere.new instead')
  static Premiere create() => Premiere._();
  static $pb.GeneratedMessage $_createMessage() => Premiere._();
  @$core.override
  Premiere createEmptyInstance() => Premiere._();
  @$core.pragma('dart2js:noInline')
  static Premiere getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Premiere>(Premiere.$_createMessage);
  static Premiere? _defaultInstance;

  @$pb.TagNumber(1)
  PremiereState get premiereState => $_getN(0);
  @$pb.TagNumber(1)
  set premiereState(PremiereState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPremiereState() => $_has(0);
  @$pb.TagNumber(1)
  void clearPremiereState() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get startTime => $_getI64(1);
  @$pb.TagNumber(2)
  set startTime($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartTime() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get serviceTime => $_getI64(2);
  @$pb.TagNumber(3)
  set serviceTime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasServiceTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearServiceTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get roomId => $_getI64(3);
  @$pb.TagNumber(4)
  set roomId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRoomId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRoomId() => $_clearField(4);
}

class PremiereArchiveReply extends $pb.GeneratedMessage {
  factory PremiereArchiveReply({
    Premiere? premiere,
    $core.bool? riskStatus,
    $core.String? riskReason,
  }) {
    final result = PremiereArchiveReply._();
    if (premiere != null) result.premiere = premiere;
    if (riskStatus != null) result.riskStatus = riskStatus;
    if (riskReason != null) result.riskReason = riskReason;
    return result;
  }

  PremiereArchiveReply._();

  factory PremiereArchiveReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereArchiveReply()..mergeFromBuffer(data, registry);
  factory PremiereArchiveReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereArchiveReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PremiereArchiveReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PremiereArchiveReply.$_createMessage)
    ..aOM<Premiere>(1, _omitFieldNames ? '' : 'premiere',
        subBuilder: Premiere.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'riskStatus')
    ..aOS(3, _omitFieldNames ? '' : 'riskReason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereArchiveReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereArchiveReply copyWith(void Function(PremiereArchiveReply) updates) =>
      super.copyWith((message) => updates(message as PremiereArchiveReply))
          as PremiereArchiveReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PremiereArchiveReply() / PremiereArchiveReply.new instead')
  static PremiereArchiveReply create() => PremiereArchiveReply._();
  static $pb.GeneratedMessage $_createMessage() => PremiereArchiveReply._();
  @$core.override
  PremiereArchiveReply createEmptyInstance() => PremiereArchiveReply._();
  @$core.pragma('dart2js:noInline')
  static PremiereArchiveReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PremiereArchiveReply>(
          PremiereArchiveReply.$_createMessage);
  static PremiereArchiveReply? _defaultInstance;

  @$pb.TagNumber(1)
  Premiere get premiere => $_getN(0);
  @$pb.TagNumber(1)
  set premiere(Premiere value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPremiere() => $_has(0);
  @$pb.TagNumber(1)
  void clearPremiere() => $_clearField(1);
  @$pb.TagNumber(1)
  Premiere ensurePremiere() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get riskStatus => $_getBF(1);
  @$pb.TagNumber(2)
  set riskStatus($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRiskStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearRiskStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get riskReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set riskReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRiskReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearRiskReason() => $_clearField(3);
}

class PremiereArchiveReq extends $pb.GeneratedMessage {
  factory PremiereArchiveReq({
    $fixnum.Int64? aid,
  }) {
    final result = PremiereArchiveReq._();
    if (aid != null) result.aid = aid;
    return result;
  }

  PremiereArchiveReq._();

  factory PremiereArchiveReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereArchiveReq()..mergeFromBuffer(data, registry);
  factory PremiereArchiveReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereArchiveReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PremiereArchiveReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PremiereArchiveReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereArchiveReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereArchiveReq copyWith(void Function(PremiereArchiveReq) updates) =>
      super.copyWith((message) => updates(message as PremiereArchiveReq))
          as PremiereArchiveReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PremiereArchiveReq() / PremiereArchiveReq.new instead')
  static PremiereArchiveReq create() => PremiereArchiveReq._();
  static $pb.GeneratedMessage $_createMessage() => PremiereArchiveReq._();
  @$core.override
  PremiereArchiveReq createEmptyInstance() => PremiereArchiveReq._();
  @$core.pragma('dart2js:noInline')
  static PremiereArchiveReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PremiereArchiveReq>(
          PremiereArchiveReq.$_createMessage);
  static PremiereArchiveReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);
}

class PremiereReserve extends $pb.GeneratedMessage {
  factory PremiereReserve({
    $fixnum.Int64? reserveId,
    $fixnum.Int64? count,
    $core.bool? isFollow,
  }) {
    final result = PremiereReserve._();
    if (reserveId != null) result.reserveId = reserveId;
    if (count != null) result.count = count;
    if (isFollow != null) result.isFollow = isFollow;
    return result;
  }

  PremiereReserve._();

  factory PremiereReserve.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereReserve()..mergeFromBuffer(data, registry);
  factory PremiereReserve.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereReserve()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PremiereReserve',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PremiereReserve.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'reserveId')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..aOB(3, _omitFieldNames ? '' : 'isFollow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereReserve clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereReserve copyWith(void Function(PremiereReserve) updates) =>
      super.copyWith((message) => updates(message as PremiereReserve))
          as PremiereReserve;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PremiereReserve() / PremiereReserve.new instead')
  static PremiereReserve create() => PremiereReserve._();
  static $pb.GeneratedMessage $_createMessage() => PremiereReserve._();
  @$core.override
  PremiereReserve createEmptyInstance() => PremiereReserve._();
  @$core.pragma('dart2js:noInline')
  static PremiereReserve getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PremiereReserve>(
          PremiereReserve.$_createMessage);
  static PremiereReserve? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get reserveId => $_getI64(0);
  @$pb.TagNumber(1)
  set reserveId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReserveId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReserveId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isFollow => $_getBF(2);
  @$pb.TagNumber(3)
  set isFollow($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsFollow() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsFollow() => $_clearField(3);
}

class PremiereResource extends $pb.GeneratedMessage {
  factory PremiereResource({
    Premiere? premiere,
    PremiereReserve? reserve,
    PremiereText? text,
  }) {
    final result = PremiereResource._();
    if (premiere != null) result.premiere = premiere;
    if (reserve != null) result.reserve = reserve;
    if (text != null) result.text = text;
    return result;
  }

  PremiereResource._();

  factory PremiereResource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereResource()..mergeFromBuffer(data, registry);
  factory PremiereResource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereResource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PremiereResource',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PremiereResource.$_createMessage)
    ..aOM<Premiere>(1, _omitFieldNames ? '' : 'premiere',
        subBuilder: Premiere.$_createMessage)
    ..aOM<PremiereReserve>(2, _omitFieldNames ? '' : 'reserve',
        subBuilder: PremiereReserve.$_createMessage)
    ..aOM<PremiereText>(3, _omitFieldNames ? '' : 'text',
        subBuilder: PremiereText.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereResource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereResource copyWith(void Function(PremiereResource) updates) =>
      super.copyWith((message) => updates(message as PremiereResource))
          as PremiereResource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PremiereResource() / PremiereResource.new instead')
  static PremiereResource create() => PremiereResource._();
  static $pb.GeneratedMessage $_createMessage() => PremiereResource._();
  @$core.override
  PremiereResource createEmptyInstance() => PremiereResource._();
  @$core.pragma('dart2js:noInline')
  static PremiereResource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PremiereResource>(
          PremiereResource.$_createMessage);
  static PremiereResource? _defaultInstance;

  @$pb.TagNumber(1)
  Premiere get premiere => $_getN(0);
  @$pb.TagNumber(1)
  set premiere(Premiere value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPremiere() => $_has(0);
  @$pb.TagNumber(1)
  void clearPremiere() => $_clearField(1);
  @$pb.TagNumber(1)
  Premiere ensurePremiere() => $_ensure(0);

  @$pb.TagNumber(2)
  PremiereReserve get reserve => $_getN(1);
  @$pb.TagNumber(2)
  set reserve(PremiereReserve value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReserve() => $_has(1);
  @$pb.TagNumber(2)
  void clearReserve() => $_clearField(2);
  @$pb.TagNumber(2)
  PremiereReserve ensureReserve() => $_ensure(1);

  @$pb.TagNumber(3)
  PremiereText get text => $_getN(2);
  @$pb.TagNumber(3)
  set text(PremiereText value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
  @$pb.TagNumber(3)
  PremiereText ensureText() => $_ensure(2);
}

class PremiereText extends $pb.GeneratedMessage {
  factory PremiereText({
    $core.String? title,
    $core.String? subtitle,
    $core.String? onlineText,
    $core.String? onlineIcon,
    $core.String? onlineIconDark,
    $core.String? introTitle,
    $core.String? introIcon,
    $core.String? guidancePulldown,
    $core.String? guidanceEntry,
    $core.String? introIconNight,
  }) {
    final result = PremiereText._();
    if (title != null) result.title = title;
    if (subtitle != null) result.subtitle = subtitle;
    if (onlineText != null) result.onlineText = onlineText;
    if (onlineIcon != null) result.onlineIcon = onlineIcon;
    if (onlineIconDark != null) result.onlineIconDark = onlineIconDark;
    if (introTitle != null) result.introTitle = introTitle;
    if (introIcon != null) result.introIcon = introIcon;
    if (guidancePulldown != null) result.guidancePulldown = guidancePulldown;
    if (guidanceEntry != null) result.guidanceEntry = guidanceEntry;
    if (introIconNight != null) result.introIconNight = introIconNight;
    return result;
  }

  PremiereText._();

  factory PremiereText.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereText()..mergeFromBuffer(data, registry);
  factory PremiereText.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PremiereText()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PremiereText',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PremiereText.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'subtitle')
    ..aOS(3, _omitFieldNames ? '' : 'onlineText')
    ..aOS(4, _omitFieldNames ? '' : 'onlineIcon')
    ..aOS(5, _omitFieldNames ? '' : 'onlineIconDark')
    ..aOS(6, _omitFieldNames ? '' : 'introTitle')
    ..aOS(7, _omitFieldNames ? '' : 'introIcon')
    ..aOS(8, _omitFieldNames ? '' : 'guidancePulldown')
    ..aOS(9, _omitFieldNames ? '' : 'guidanceEntry')
    ..aOS(10, _omitFieldNames ? '' : 'introIconNight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereText clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PremiereText copyWith(void Function(PremiereText) updates) =>
      super.copyWith((message) => updates(message as PremiereText))
          as PremiereText;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PremiereText() / PremiereText.new instead')
  static PremiereText create() => PremiereText._();
  static $pb.GeneratedMessage $_createMessage() => PremiereText._();
  @$core.override
  PremiereText createEmptyInstance() => PremiereText._();
  @$core.pragma('dart2js:noInline')
  static PremiereText getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PremiereText>(
          PremiereText.$_createMessage);
  static PremiereText? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subtitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set subtitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubtitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubtitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get onlineText => $_getSZ(2);
  @$pb.TagNumber(3)
  set onlineText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOnlineText() => $_has(2);
  @$pb.TagNumber(3)
  void clearOnlineText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get onlineIcon => $_getSZ(3);
  @$pb.TagNumber(4)
  set onlineIcon($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOnlineIcon() => $_has(3);
  @$pb.TagNumber(4)
  void clearOnlineIcon() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get onlineIconDark => $_getSZ(4);
  @$pb.TagNumber(5)
  set onlineIconDark($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOnlineIconDark() => $_has(4);
  @$pb.TagNumber(5)
  void clearOnlineIconDark() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get introTitle => $_getSZ(5);
  @$pb.TagNumber(6)
  set introTitle($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIntroTitle() => $_has(5);
  @$pb.TagNumber(6)
  void clearIntroTitle() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get introIcon => $_getSZ(6);
  @$pb.TagNumber(7)
  set introIcon($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIntroIcon() => $_has(6);
  @$pb.TagNumber(7)
  void clearIntroIcon() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get guidancePulldown => $_getSZ(7);
  @$pb.TagNumber(8)
  set guidancePulldown($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasGuidancePulldown() => $_has(7);
  @$pb.TagNumber(8)
  void clearGuidancePulldown() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get guidanceEntry => $_getSZ(8);
  @$pb.TagNumber(9)
  set guidanceEntry($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasGuidanceEntry() => $_has(8);
  @$pb.TagNumber(9)
  void clearGuidanceEntry() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get introIconNight => $_getSZ(9);
  @$pb.TagNumber(10)
  set introIconNight($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIntroIconNight() => $_has(9);
  @$pb.TagNumber(10)
  void clearIntroIconNight() => $_clearField(10);
}

class PullClientAction extends $pb.GeneratedMessage {
  factory PullClientAction({
    $core.String? type,
    $core.bool? pullAction,
    $core.String? params,
  }) {
    final result = PullClientAction._();
    if (type != null) result.type = type;
    if (pullAction != null) result.pullAction = pullAction;
    if (params != null) result.params = params;
    return result;
  }

  PullClientAction._();

  factory PullClientAction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullClientAction()..mergeFromBuffer(data, registry);
  factory PullClientAction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullClientAction()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullClientAction',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: PullClientAction.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..aOB(2, _omitFieldNames ? '' : 'pullAction')
    ..aOS(3, _omitFieldNames ? '' : 'params')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullClientAction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullClientAction copyWith(void Function(PullClientAction) updates) =>
      super.copyWith((message) => updates(message as PullClientAction))
          as PullClientAction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PullClientAction() / PullClientAction.new instead')
  static PullClientAction create() => PullClientAction._();
  static $pb.GeneratedMessage $_createMessage() => PullClientAction._();
  @$core.override
  PullClientAction createEmptyInstance() => PullClientAction._();
  @$core.pragma('dart2js:noInline')
  static PullClientAction getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PullClientAction>(
          PullClientAction.$_createMessage);
  static PullClientAction? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1)
  set type($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get pullAction => $_getBF(1);
  @$pb.TagNumber(2)
  set pullAction($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPullAction() => $_has(1);
  @$pb.TagNumber(2)
  void clearPullAction() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get params => $_getSZ(2);
  @$pb.TagNumber(3)
  set params($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasParams() => $_has(2);
  @$pb.TagNumber(3)
  void clearParams() => $_clearField(3);
}

/// 排行榜
class Rank extends $pb.GeneratedMessage {
  factory Rank({
    $core.String? icon,
    $core.String? iconNight,
    $core.String? text,
  }) {
    final result = Rank._();
    if (icon != null) result.icon = icon;
    if (iconNight != null) result.iconNight = iconNight;
    if (text != null) result.text = text;
    return result;
  }

  Rank._();

  factory Rank.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Rank()..mergeFromBuffer(data, registry);
  factory Rank.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Rank()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Rank',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Rank.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'icon')
    ..aOS(2, _omitFieldNames ? '' : 'iconNight')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rank clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rank copyWith(void Function(Rank) updates) =>
      super.copyWith((message) => updates(message as Rank)) as Rank;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Rank() / Rank.new instead')
  static Rank create() => Rank._();
  static $pb.GeneratedMessage $_createMessage() => Rank._();
  @$core.override
  Rank createEmptyInstance() => Rank._();
  @$core.pragma('dart2js:noInline')
  static Rank getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Rank>(Rank.$_createMessage);
  static Rank? _defaultInstance;

  /// 排行榜icon
  @$pb.TagNumber(1)
  $core.String get icon => $_getSZ(0);
  @$pb.TagNumber(1)
  set icon($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIcon() => $_has(0);
  @$pb.TagNumber(1)
  void clearIcon() => $_clearField(1);

  /// 排行榜icon 夜间模式
  @$pb.TagNumber(2)
  $core.String get iconNight => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconNight($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconNight() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconNight() => $_clearField(2);

  /// 排行榜文案
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

class RankInfo extends $pb.GeneratedMessage {
  factory RankInfo({
    $core.String? iconUrlNight,
    $core.String? iconUrlDay,
    $core.String? bkgNightColor,
    $core.String? bkgDayColor,
    $core.String? fontNightColor,
    $core.String? fontDayColor,
    $core.String? rankContent,
    $core.String? rankLink,
  }) {
    final result = RankInfo._();
    if (iconUrlNight != null) result.iconUrlNight = iconUrlNight;
    if (iconUrlDay != null) result.iconUrlDay = iconUrlDay;
    if (bkgNightColor != null) result.bkgNightColor = bkgNightColor;
    if (bkgDayColor != null) result.bkgDayColor = bkgDayColor;
    if (fontNightColor != null) result.fontNightColor = fontNightColor;
    if (fontDayColor != null) result.fontDayColor = fontDayColor;
    if (rankContent != null) result.rankContent = rankContent;
    if (rankLink != null) result.rankLink = rankLink;
    return result;
  }

  RankInfo._();

  factory RankInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RankInfo()..mergeFromBuffer(data, registry);
  factory RankInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RankInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RankInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RankInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'iconUrlNight')
    ..aOS(2, _omitFieldNames ? '' : 'iconUrlDay')
    ..aOS(3, _omitFieldNames ? '' : 'bkgNightColor')
    ..aOS(4, _omitFieldNames ? '' : 'bkgDayColor')
    ..aOS(5, _omitFieldNames ? '' : 'fontNightColor')
    ..aOS(6, _omitFieldNames ? '' : 'fontDayColor')
    ..aOS(7, _omitFieldNames ? '' : 'rankContent')
    ..aOS(8, _omitFieldNames ? '' : 'rankLink')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RankInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RankInfo copyWith(void Function(RankInfo) updates) =>
      super.copyWith((message) => updates(message as RankInfo)) as RankInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RankInfo() / RankInfo.new instead')
  static RankInfo create() => RankInfo._();
  static $pb.GeneratedMessage $_createMessage() => RankInfo._();
  @$core.override
  RankInfo createEmptyInstance() => RankInfo._();
  @$core.pragma('dart2js:noInline')
  static RankInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RankInfo>(RankInfo.$_createMessage);
  static RankInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get iconUrlNight => $_getSZ(0);
  @$pb.TagNumber(1)
  set iconUrlNight($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIconUrlNight() => $_has(0);
  @$pb.TagNumber(1)
  void clearIconUrlNight() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get iconUrlDay => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconUrlDay($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconUrlDay() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconUrlDay() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get bkgNightColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set bkgNightColor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBkgNightColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearBkgNightColor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get bkgDayColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set bkgDayColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBkgDayColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearBkgDayColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fontNightColor => $_getSZ(4);
  @$pb.TagNumber(5)
  set fontNightColor($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFontNightColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearFontNightColor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get fontDayColor => $_getSZ(5);
  @$pb.TagNumber(6)
  set fontDayColor($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFontDayColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearFontDayColor() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get rankContent => $_getSZ(6);
  @$pb.TagNumber(7)
  set rankContent($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRankContent() => $_has(6);
  @$pb.TagNumber(7)
  void clearRankContent() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get rankLink => $_getSZ(7);
  @$pb.TagNumber(8)
  set rankLink($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRankLink() => $_has(7);
  @$pb.TagNumber(8)
  void clearRankLink() => $_clearField(8);
}

/// 推荐理由样式
class ReasonStyle extends $pb.GeneratedMessage {
  factory ReasonStyle({
    $core.String? text,
    $core.String? textColor,
    $core.String? bgColor,
    $core.String? borderColor,
    $core.String? textColorNight,
    $core.String? bgColorNight,
    $core.String? borderColorNight,
    $core.int? bgStyle,
    $core.int? selected,
  }) {
    final result = ReasonStyle._();
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (bgColor != null) result.bgColor = bgColor;
    if (borderColor != null) result.borderColor = borderColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    if (bgColorNight != null) result.bgColorNight = bgColorNight;
    if (borderColorNight != null) result.borderColorNight = borderColorNight;
    if (bgStyle != null) result.bgStyle = bgStyle;
    if (selected != null) result.selected = selected;
    return result;
  }

  ReasonStyle._();

  factory ReasonStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReasonStyle()..mergeFromBuffer(data, registry);
  factory ReasonStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReasonStyle()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReasonStyle',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ReasonStyle.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'textColor')
    ..aOS(3, _omitFieldNames ? '' : 'bgColor')
    ..aOS(4, _omitFieldNames ? '' : 'borderColor')
    ..aOS(5, _omitFieldNames ? '' : 'textColorNight')
    ..aOS(6, _omitFieldNames ? '' : 'bgColorNight')
    ..aOS(7, _omitFieldNames ? '' : 'borderColorNight')
    ..aI(8, _omitFieldNames ? '' : 'bgStyle')
    ..aI(9, _omitFieldNames ? '' : 'selected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReasonStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReasonStyle copyWith(void Function(ReasonStyle) updates) =>
      super.copyWith((message) => updates(message as ReasonStyle))
          as ReasonStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReasonStyle() / ReasonStyle.new instead')
  static ReasonStyle create() => ReasonStyle._();
  static $pb.GeneratedMessage $_createMessage() => ReasonStyle._();
  @$core.override
  ReasonStyle createEmptyInstance() => ReasonStyle._();
  @$core.pragma('dart2js:noInline')
  static ReasonStyle getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReasonStyle>(
          ReasonStyle.$_createMessage);
  static ReasonStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// 日间模式文字
  @$pb.TagNumber(2)
  $core.String get textColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set textColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTextColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearTextColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get bgColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set bgColor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBgColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearBgColor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get borderColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set borderColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBorderColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearBorderColor() => $_clearField(4);

  /// 夜间模式文字
  @$pb.TagNumber(5)
  $core.String get textColorNight => $_getSZ(4);
  @$pb.TagNumber(5)
  set textColorNight($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTextColorNight() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextColorNight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get bgColorNight => $_getSZ(5);
  @$pb.TagNumber(6)
  set bgColorNight($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBgColorNight() => $_has(5);
  @$pb.TagNumber(6)
  void clearBgColorNight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get borderColorNight => $_getSZ(6);
  @$pb.TagNumber(7)
  set borderColorNight($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBorderColorNight() => $_has(6);
  @$pb.TagNumber(7)
  void clearBorderColorNight() => $_clearField(7);

  /// 1:填充 2:描边 3:填充 + 描边 4:背景不填充 + 背景不描边
  @$pb.TagNumber(8)
  $core.int get bgStyle => $_getIZ(7);
  @$pb.TagNumber(8)
  set bgStyle($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBgStyle() => $_has(7);
  @$pb.TagNumber(8)
  void clearBgStyle() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get selected => $_getIZ(8);
  @$pb.TagNumber(9)
  set selected($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSelected() => $_has(8);
  @$pb.TagNumber(9)
  void clearSelected() => $_clearField(9);
}

class RecDislike extends $pb.GeneratedMessage {
  factory RecDislike({
    $core.String? title,
    $core.String? subTitle,
    $core.String? closedSubTitle,
    $core.String? pasteText,
    $core.String? closedPasteText,
    $core.Iterable<DislikeReasons>? dislikeReason,
    $core.String? toast,
    $core.String? closedToast,
  }) {
    final result = RecDislike._();
    if (title != null) result.title = title;
    if (subTitle != null) result.subTitle = subTitle;
    if (closedSubTitle != null) result.closedSubTitle = closedSubTitle;
    if (pasteText != null) result.pasteText = pasteText;
    if (closedPasteText != null) result.closedPasteText = closedPasteText;
    if (dislikeReason != null) result.dislikeReason.addAll(dislikeReason);
    if (toast != null) result.toast = toast;
    if (closedToast != null) result.closedToast = closedToast;
    return result;
  }

  RecDislike._();

  factory RecDislike.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RecDislike()..mergeFromBuffer(data, registry);
  factory RecDislike.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RecDislike()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecDislike',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RecDislike.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'subTitle')
    ..aOS(3, _omitFieldNames ? '' : 'closedSubTitle')
    ..aOS(4, _omitFieldNames ? '' : 'pasteText')
    ..aOS(5, _omitFieldNames ? '' : 'closedPasteText')
    ..pPM<DislikeReasons>(6, _omitFieldNames ? '' : 'dislikeReason',
        subBuilder: DislikeReasons.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'toast')
    ..aOS(8, _omitFieldNames ? '' : 'closedToast')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecDislike clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecDislike copyWith(void Function(RecDislike) updates) =>
      super.copyWith((message) => updates(message as RecDislike)) as RecDislike;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RecDislike() / RecDislike.new instead')
  static RecDislike create() => RecDislike._();
  static $pb.GeneratedMessage $_createMessage() => RecDislike._();
  @$core.override
  RecDislike createEmptyInstance() => RecDislike._();
  @$core.pragma('dart2js:noInline')
  static RecDislike getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecDislike>(RecDislike.$_createMessage);
  static RecDislike? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get subTitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set subTitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get closedSubTitle => $_getSZ(2);
  @$pb.TagNumber(3)
  set closedSubTitle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClosedSubTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearClosedSubTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get pasteText => $_getSZ(3);
  @$pb.TagNumber(4)
  set pasteText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPasteText() => $_has(3);
  @$pb.TagNumber(4)
  void clearPasteText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get closedPasteText => $_getSZ(4);
  @$pb.TagNumber(5)
  set closedPasteText($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClosedPasteText() => $_has(4);
  @$pb.TagNumber(5)
  void clearClosedPasteText() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<DislikeReasons> get dislikeReason => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get toast => $_getSZ(6);
  @$pb.TagNumber(7)
  set toast($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasToast() => $_has(6);
  @$pb.TagNumber(7)
  void clearToast() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get closedToast => $_getSZ(7);
  @$pb.TagNumber(8)
  set closedToast($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasClosedToast() => $_has(7);
  @$pb.TagNumber(8)
  void clearClosedToast() => $_clearField(8);
}

class RecThreePoint extends $pb.GeneratedMessage {
  factory RecThreePoint({
    RecDislike? dislike,
    RecDislike? feedback,
    $core.bool? watchLater,
  }) {
    final result = RecThreePoint._();
    if (dislike != null) result.dislike = dislike;
    if (feedback != null) result.feedback = feedback;
    if (watchLater != null) result.watchLater = watchLater;
    return result;
  }

  RecThreePoint._();

  factory RecThreePoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RecThreePoint()..mergeFromBuffer(data, registry);
  factory RecThreePoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RecThreePoint()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecThreePoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RecThreePoint.$_createMessage)
    ..aOM<RecDislike>(1, _omitFieldNames ? '' : 'dislike',
        subBuilder: RecDislike.$_createMessage)
    ..aOM<RecDislike>(2, _omitFieldNames ? '' : 'feedback',
        subBuilder: RecDislike.$_createMessage)
    ..aOB(3, _omitFieldNames ? '' : 'watchLater')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecThreePoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecThreePoint copyWith(void Function(RecThreePoint) updates) =>
      super.copyWith((message) => updates(message as RecThreePoint))
          as RecThreePoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RecThreePoint() / RecThreePoint.new instead')
  static RecThreePoint create() => RecThreePoint._();
  static $pb.GeneratedMessage $_createMessage() => RecThreePoint._();
  @$core.override
  RecThreePoint createEmptyInstance() => RecThreePoint._();
  @$core.pragma('dart2js:noInline')
  static RecThreePoint getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RecThreePoint>(
          RecThreePoint.$_createMessage);
  static RecThreePoint? _defaultInstance;

  @$pb.TagNumber(1)
  RecDislike get dislike => $_getN(0);
  @$pb.TagNumber(1)
  set dislike(RecDislike value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDislike() => $_has(0);
  @$pb.TagNumber(1)
  void clearDislike() => $_clearField(1);
  @$pb.TagNumber(1)
  RecDislike ensureDislike() => $_ensure(0);

  @$pb.TagNumber(2)
  RecDislike get feedback => $_getN(1);
  @$pb.TagNumber(2)
  set feedback(RecDislike value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFeedback() => $_has(1);
  @$pb.TagNumber(2)
  void clearFeedback() => $_clearField(2);
  @$pb.TagNumber(2)
  RecDislike ensureFeedback() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.bool get watchLater => $_getBF(2);
  @$pb.TagNumber(3)
  set watchLater($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWatchLater() => $_has(2);
  @$pb.TagNumber(3)
  void clearWatchLater() => $_clearField(3);
}

class RefreshPage extends $pb.GeneratedMessage {
  factory RefreshPage({
    $core.int? refreshable,
    $core.int? refreshIcon,
    $core.String? refreshText,
    $core.double? refreshShow,
  }) {
    final result = RefreshPage._();
    if (refreshable != null) result.refreshable = refreshable;
    if (refreshIcon != null) result.refreshIcon = refreshIcon;
    if (refreshText != null) result.refreshText = refreshText;
    if (refreshShow != null) result.refreshShow = refreshShow;
    return result;
  }

  RefreshPage._();

  factory RefreshPage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshPage()..mergeFromBuffer(data, registry);
  factory RefreshPage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshPage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshPage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RefreshPage.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'refreshable')
    ..aI(2, _omitFieldNames ? '' : 'refreshIcon')
    ..aOS(3, _omitFieldNames ? '' : 'refreshText')
    ..aD(4, _omitFieldNames ? '' : 'refreshShow', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshPage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshPage copyWith(void Function(RefreshPage) updates) =>
      super.copyWith((message) => updates(message as RefreshPage))
          as RefreshPage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RefreshPage() / RefreshPage.new instead')
  static RefreshPage create() => RefreshPage._();
  static $pb.GeneratedMessage $_createMessage() => RefreshPage._();
  @$core.override
  RefreshPage createEmptyInstance() => RefreshPage._();
  @$core.pragma('dart2js:noInline')
  static RefreshPage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshPage>(
          RefreshPage.$_createMessage);
  static RefreshPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get refreshable => $_getIZ(0);
  @$pb.TagNumber(1)
  set refreshable($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefreshable() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefreshable() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get refreshIcon => $_getIZ(1);
  @$pb.TagNumber(2)
  set refreshIcon($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefreshIcon() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefreshIcon() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get refreshText => $_getSZ(2);
  @$pb.TagNumber(3)
  set refreshText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefreshText() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefreshText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get refreshShow => $_getN(3);
  @$pb.TagNumber(4)
  set refreshShow($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRefreshShow() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefreshShow() => $_clearField(4);
}

/// 相关推荐项
class Relate extends $pb.GeneratedMessage {
  factory Relate({
    $fixnum.Int64? aid,
    $core.String? pic,
    $core.String? title,
    $1.Author? author,
    $1.Stat? stat,
    $fixnum.Int64? duration,
    $core.String? goto,
    $core.String? param,
    $core.String? uri,
    $core.String? jumpUrl,
    $core.double? rating,
    $core.String? reserve,
    $core.String? from,
    $core.String? desc,
    $core.String? rcmdReason,
    $core.String? badge,
    $fixnum.Int64? cid,
    $core.int? seasonType,
    $core.int? ratingCount,
    $core.String? tagName,
    PackInfo? packInfo,
    Notice? notice,
    Button? button,
    $core.String? trackid,
    $core.int? newCard,
    ReasonStyle? rcmdReasonStyle,
    $core.String? coverGif,
    CM? cm,
    $fixnum.Int64? reserveStatus,
    $core.String? rcmdReasonExtra,
    RecThreePoint? recThreePoint,
    $core.String? uniqueId,
    $fixnum.Int64? materialId,
    $fixnum.Int64? fromSourceType,
    $core.String? fromSourceId,
    $1.Dimension? dimension,
    $core.String? cover,
    ReasonStyle? badgeStyle,
    PowerIconStyle? powerIconStyle,
    $core.String? reserveStatusText,
    $core.String? dislikeReportData,
    RankInfo? rankInfoGame,
    $core.String? firstFrame,
  }) {
    final result = Relate._();
    if (aid != null) result.aid = aid;
    if (pic != null) result.pic = pic;
    if (title != null) result.title = title;
    if (author != null) result.author = author;
    if (stat != null) result.stat = stat;
    if (duration != null) result.duration = duration;
    if (goto != null) result.goto = goto;
    if (param != null) result.param = param;
    if (uri != null) result.uri = uri;
    if (jumpUrl != null) result.jumpUrl = jumpUrl;
    if (rating != null) result.rating = rating;
    if (reserve != null) result.reserve = reserve;
    if (from != null) result.from = from;
    if (desc != null) result.desc = desc;
    if (rcmdReason != null) result.rcmdReason = rcmdReason;
    if (badge != null) result.badge = badge;
    if (cid != null) result.cid = cid;
    if (seasonType != null) result.seasonType = seasonType;
    if (ratingCount != null) result.ratingCount = ratingCount;
    if (tagName != null) result.tagName = tagName;
    if (packInfo != null) result.packInfo = packInfo;
    if (notice != null) result.notice = notice;
    if (button != null) result.button = button;
    if (trackid != null) result.trackid = trackid;
    if (newCard != null) result.newCard = newCard;
    if (rcmdReasonStyle != null) result.rcmdReasonStyle = rcmdReasonStyle;
    if (coverGif != null) result.coverGif = coverGif;
    if (cm != null) result.cm = cm;
    if (reserveStatus != null) result.reserveStatus = reserveStatus;
    if (rcmdReasonExtra != null) result.rcmdReasonExtra = rcmdReasonExtra;
    if (recThreePoint != null) result.recThreePoint = recThreePoint;
    if (uniqueId != null) result.uniqueId = uniqueId;
    if (materialId != null) result.materialId = materialId;
    if (fromSourceType != null) result.fromSourceType = fromSourceType;
    if (fromSourceId != null) result.fromSourceId = fromSourceId;
    if (dimension != null) result.dimension = dimension;
    if (cover != null) result.cover = cover;
    if (badgeStyle != null) result.badgeStyle = badgeStyle;
    if (powerIconStyle != null) result.powerIconStyle = powerIconStyle;
    if (reserveStatusText != null) result.reserveStatusText = reserveStatusText;
    if (dislikeReportData != null) result.dislikeReportData = dislikeReportData;
    if (rankInfoGame != null) result.rankInfoGame = rankInfoGame;
    if (firstFrame != null) result.firstFrame = firstFrame;
    return result;
  }

  Relate._();

  factory Relate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Relate()..mergeFromBuffer(data, registry);
  factory Relate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Relate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Relate',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Relate.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'pic')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOM<$1.Author>(4, _omitFieldNames ? '' : 'author',
        subBuilder: $1.Author.$_createMessage)
    ..aOM<$1.Stat>(5, _omitFieldNames ? '' : 'stat',
        subBuilder: $1.Stat.$_createMessage)
    ..aInt64(6, _omitFieldNames ? '' : 'duration')
    ..aOS(7, _omitFieldNames ? '' : 'goto')
    ..aOS(8, _omitFieldNames ? '' : 'param')
    ..aOS(9, _omitFieldNames ? '' : 'uri')
    ..aOS(10, _omitFieldNames ? '' : 'jumpUrl')
    ..aD(11, _omitFieldNames ? '' : 'rating')
    ..aOS(12, _omitFieldNames ? '' : 'reserve')
    ..aOS(13, _omitFieldNames ? '' : 'from')
    ..aOS(14, _omitFieldNames ? '' : 'desc')
    ..aOS(15, _omitFieldNames ? '' : 'rcmdReason')
    ..aOS(16, _omitFieldNames ? '' : 'badge')
    ..aInt64(17, _omitFieldNames ? '' : 'cid')
    ..aI(18, _omitFieldNames ? '' : 'seasonType')
    ..aI(19, _omitFieldNames ? '' : 'ratingCount')
    ..aOS(20, _omitFieldNames ? '' : 'tagName')
    ..aOM<PackInfo>(21, _omitFieldNames ? '' : 'packInfo',
        subBuilder: PackInfo.$_createMessage)
    ..aOM<Notice>(22, _omitFieldNames ? '' : 'notice',
        subBuilder: Notice.$_createMessage)
    ..aOM<Button>(23, _omitFieldNames ? '' : 'button',
        subBuilder: Button.$_createMessage)
    ..aOS(24, _omitFieldNames ? '' : 'trackid')
    ..aI(25, _omitFieldNames ? '' : 'newCard')
    ..aOM<ReasonStyle>(26, _omitFieldNames ? '' : 'rcmdReasonStyle',
        subBuilder: ReasonStyle.$_createMessage)
    ..aOS(27, _omitFieldNames ? '' : 'coverGif')
    ..aOM<CM>(28, _omitFieldNames ? '' : 'cm', subBuilder: CM.$_createMessage)
    ..aInt64(29, _omitFieldNames ? '' : 'reserveStatus')
    ..aOS(30, _omitFieldNames ? '' : 'rcmdReasonExtra')
    ..aOM<RecThreePoint>(31, _omitFieldNames ? '' : 'recThreePoint',
        subBuilder: RecThreePoint.$_createMessage)
    ..aOS(32, _omitFieldNames ? '' : 'uniqueId')
    ..aInt64(33, _omitFieldNames ? '' : 'materialId')
    ..aInt64(34, _omitFieldNames ? '' : 'fromSourceType')
    ..aOS(35, _omitFieldNames ? '' : 'fromSourceId')
    ..aOM<$1.Dimension>(36, _omitFieldNames ? '' : 'dimension',
        subBuilder: $1.Dimension.$_createMessage)
    ..aOS(37, _omitFieldNames ? '' : 'cover')
    ..aOM<ReasonStyle>(38, _omitFieldNames ? '' : 'badgeStyle',
        subBuilder: ReasonStyle.$_createMessage)
    ..aOM<PowerIconStyle>(39, _omitFieldNames ? '' : 'powerIconStyle',
        subBuilder: PowerIconStyle.$_createMessage)
    ..aOS(40, _omitFieldNames ? '' : 'reserveStatusText')
    ..aOS(41, _omitFieldNames ? '' : 'dislikeReportData')
    ..aOM<RankInfo>(42, _omitFieldNames ? '' : 'rankInfoGame',
        subBuilder: RankInfo.$_createMessage)
    ..aOS(43, _omitFieldNames ? '' : 'firstFrame')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Relate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Relate copyWith(void Function(Relate) updates) =>
      super.copyWith((message) => updates(message as Relate)) as Relate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Relate() / Relate.new instead')
  static Relate create() => Relate._();
  static $pb.GeneratedMessage $_createMessage() => Relate._();
  @$core.override
  Relate createEmptyInstance() => Relate._();
  @$core.pragma('dart2js:noInline')
  static Relate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Relate>(Relate.$_createMessage);
  static Relate? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  /// 封面url
  @$pb.TagNumber(2)
  $core.String get pic => $_getSZ(1);
  @$pb.TagNumber(2)
  set pic($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPic() => $_has(1);
  @$pb.TagNumber(2)
  void clearPic() => $_clearField(2);

  /// 标题
  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  /// UP主信息
  @$pb.TagNumber(4)
  $1.Author get author => $_getN(3);
  @$pb.TagNumber(4)
  set author($1.Author value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthor() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthor() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Author ensureAuthor() => $_ensure(3);

  /// 稿件状态数
  @$pb.TagNumber(5)
  $1.Stat get stat => $_getN(4);
  @$pb.TagNumber(5)
  set stat($1.Stat value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStat() => $_has(4);
  @$pb.TagNumber(5)
  void clearStat() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.Stat ensureStat() => $_ensure(4);

  /// 时长
  @$pb.TagNumber(6)
  $fixnum.Int64 get duration => $_getI64(5);
  @$pb.TagNumber(6)
  set duration($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDuration() => $_has(5);
  @$pb.TagNumber(6)
  void clearDuration() => $_clearField(6);

  /// 跳转类型
  /// special:pgc视频 av:稿件视频 cm:广告 game:游戏
  @$pb.TagNumber(7)
  $core.String get goto => $_getSZ(6);
  @$pb.TagNumber(7)
  set goto($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGoto() => $_has(6);
  @$pb.TagNumber(7)
  void clearGoto() => $_clearField(7);

  /// 参数（如av号等）
  @$pb.TagNumber(8)
  $core.String get param => $_getSZ(7);
  @$pb.TagNumber(8)
  set param($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasParam() => $_has(7);
  @$pb.TagNumber(8)
  void clearParam() => $_clearField(8);

  /// 跳转uri
  @$pb.TagNumber(9)
  $core.String get uri => $_getSZ(8);
  @$pb.TagNumber(9)
  set uri($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUri() => $_has(8);
  @$pb.TagNumber(9)
  void clearUri() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get jumpUrl => $_getSZ(9);
  @$pb.TagNumber(10)
  set jumpUrl($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasJumpUrl() => $_has(9);
  @$pb.TagNumber(10)
  void clearJumpUrl() => $_clearField(10);

  /// 评分
  @$pb.TagNumber(11)
  $core.double get rating => $_getN(10);
  @$pb.TagNumber(11)
  set rating($core.double value) => $_setDouble(10, value);
  @$pb.TagNumber(11)
  $core.bool hasRating() => $_has(10);
  @$pb.TagNumber(11)
  void clearRating() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get reserve => $_getSZ(11);
  @$pb.TagNumber(12)
  set reserve($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReserve() => $_has(11);
  @$pb.TagNumber(12)
  void clearReserve() => $_clearField(12);

  /// 来源标识
  /// operation:管理员添加
  @$pb.TagNumber(13)
  $core.String get from => $_getSZ(12);
  @$pb.TagNumber(13)
  set from($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasFrom() => $_has(12);
  @$pb.TagNumber(13)
  void clearFrom() => $_clearField(13);

  /// 备注
  @$pb.TagNumber(14)
  $core.String get desc => $_getSZ(13);
  @$pb.TagNumber(14)
  set desc($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasDesc() => $_has(13);
  @$pb.TagNumber(14)
  void clearDesc() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get rcmdReason => $_getSZ(14);
  @$pb.TagNumber(15)
  set rcmdReason($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasRcmdReason() => $_has(14);
  @$pb.TagNumber(15)
  void clearRcmdReason() => $_clearField(15);

  /// 标志文字
  @$pb.TagNumber(16)
  $core.String get badge => $_getSZ(15);
  @$pb.TagNumber(16)
  set badge($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasBadge() => $_has(15);
  @$pb.TagNumber(16)
  void clearBadge() => $_clearField(16);

  /// 1P cid
  @$pb.TagNumber(17)
  $fixnum.Int64 get cid => $_getI64(16);
  @$pb.TagNumber(17)
  set cid($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasCid() => $_has(16);
  @$pb.TagNumber(17)
  void clearCid() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get seasonType => $_getIZ(17);
  @$pb.TagNumber(18)
  set seasonType($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasSeasonType() => $_has(17);
  @$pb.TagNumber(18)
  void clearSeasonType() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.int get ratingCount => $_getIZ(18);
  @$pb.TagNumber(19)
  set ratingCount($core.int value) => $_setSignedInt32(18, value);
  @$pb.TagNumber(19)
  $core.bool hasRatingCount() => $_has(18);
  @$pb.TagNumber(19)
  void clearRatingCount() => $_clearField(19);

  /// 标签文案
  @$pb.TagNumber(20)
  $core.String get tagName => $_getSZ(19);
  @$pb.TagNumber(20)
  set tagName($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasTagName() => $_has(19);
  @$pb.TagNumber(20)
  void clearTagName() => $_clearField(20);

  /// 游戏礼包信息
  @$pb.TagNumber(21)
  PackInfo get packInfo => $_getN(20);
  @$pb.TagNumber(21)
  set packInfo(PackInfo value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasPackInfo() => $_has(20);
  @$pb.TagNumber(21)
  void clearPackInfo() => $_clearField(21);
  @$pb.TagNumber(21)
  PackInfo ensurePackInfo() => $_ensure(20);

  @$pb.TagNumber(22)
  Notice get notice => $_getN(21);
  @$pb.TagNumber(22)
  set notice(Notice value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasNotice() => $_has(21);
  @$pb.TagNumber(22)
  void clearNotice() => $_clearField(22);
  @$pb.TagNumber(22)
  Notice ensureNotice() => $_ensure(21);

  /// 按钮信息
  @$pb.TagNumber(23)
  Button get button => $_getN(22);
  @$pb.TagNumber(23)
  set button(Button value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasButton() => $_has(22);
  @$pb.TagNumber(23)
  void clearButton() => $_clearField(23);
  @$pb.TagNumber(23)
  Button ensureButton() => $_ensure(22);

  /// spm追踪id
  @$pb.TagNumber(24)
  $core.String get trackid => $_getSZ(23);
  @$pb.TagNumber(24)
  set trackid($core.String value) => $_setString(23, value);
  @$pb.TagNumber(24)
  $core.bool hasTrackid() => $_has(23);
  @$pb.TagNumber(24)
  void clearTrackid() => $_clearField(24);

  /// 游戏卡片新样式
  @$pb.TagNumber(25)
  $core.int get newCard => $_getIZ(24);
  @$pb.TagNumber(25)
  set newCard($core.int value) => $_setSignedInt32(24, value);
  @$pb.TagNumber(25)
  $core.bool hasNewCard() => $_has(24);
  @$pb.TagNumber(25)
  void clearNewCard() => $_clearField(25);

  /// 推荐理由样式
  @$pb.TagNumber(26)
  ReasonStyle get rcmdReasonStyle => $_getN(25);
  @$pb.TagNumber(26)
  set rcmdReasonStyle(ReasonStyle value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasRcmdReasonStyle() => $_has(25);
  @$pb.TagNumber(26)
  void clearRcmdReasonStyle() => $_clearField(26);
  @$pb.TagNumber(26)
  ReasonStyle ensureRcmdReasonStyle() => $_ensure(25);

  @$pb.TagNumber(27)
  $core.String get coverGif => $_getSZ(26);
  @$pb.TagNumber(27)
  set coverGif($core.String value) => $_setString(26, value);
  @$pb.TagNumber(27)
  $core.bool hasCoverGif() => $_has(26);
  @$pb.TagNumber(27)
  void clearCoverGif() => $_clearField(27);

  /// 广告
  @$pb.TagNumber(28)
  CM get cm => $_getN(27);
  @$pb.TagNumber(28)
  set cm(CM value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasCm() => $_has(27);
  @$pb.TagNumber(28)
  void clearCm() => $_clearField(28);
  @$pb.TagNumber(28)
  CM ensureCm() => $_ensure(27);

  /// 游戏卡字段
  /// 0:下载 1:预约(跳过详情) 2:预约 3:测试 4:测试+预约 5:跳过详情页
  @$pb.TagNumber(29)
  $fixnum.Int64 get reserveStatus => $_getI64(28);
  @$pb.TagNumber(29)
  set reserveStatus($fixnum.Int64 value) => $_setInt64(28, value);
  @$pb.TagNumber(29)
  $core.bool hasReserveStatus() => $_has(28);
  @$pb.TagNumber(29)
  void clearReserveStatus() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.String get rcmdReasonExtra => $_getSZ(29);
  @$pb.TagNumber(30)
  set rcmdReasonExtra($core.String value) => $_setString(29, value);
  @$pb.TagNumber(30)
  $core.bool hasRcmdReasonExtra() => $_has(29);
  @$pb.TagNumber(30)
  void clearRcmdReasonExtra() => $_clearField(30);

  @$pb.TagNumber(31)
  RecThreePoint get recThreePoint => $_getN(30);
  @$pb.TagNumber(31)
  set recThreePoint(RecThreePoint value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasRecThreePoint() => $_has(30);
  @$pb.TagNumber(31)
  void clearRecThreePoint() => $_clearField(31);
  @$pb.TagNumber(31)
  RecThreePoint ensureRecThreePoint() => $_ensure(30);

  @$pb.TagNumber(32)
  $core.String get uniqueId => $_getSZ(31);
  @$pb.TagNumber(32)
  set uniqueId($core.String value) => $_setString(31, value);
  @$pb.TagNumber(32)
  $core.bool hasUniqueId() => $_has(31);
  @$pb.TagNumber(32)
  void clearUniqueId() => $_clearField(32);

  @$pb.TagNumber(33)
  $fixnum.Int64 get materialId => $_getI64(32);
  @$pb.TagNumber(33)
  set materialId($fixnum.Int64 value) => $_setInt64(32, value);
  @$pb.TagNumber(33)
  $core.bool hasMaterialId() => $_has(32);
  @$pb.TagNumber(33)
  void clearMaterialId() => $_clearField(33);

  @$pb.TagNumber(34)
  $fixnum.Int64 get fromSourceType => $_getI64(33);
  @$pb.TagNumber(34)
  set fromSourceType($fixnum.Int64 value) => $_setInt64(33, value);
  @$pb.TagNumber(34)
  $core.bool hasFromSourceType() => $_has(33);
  @$pb.TagNumber(34)
  void clearFromSourceType() => $_clearField(34);

  @$pb.TagNumber(35)
  $core.String get fromSourceId => $_getSZ(34);
  @$pb.TagNumber(35)
  set fromSourceId($core.String value) => $_setString(34, value);
  @$pb.TagNumber(35)
  $core.bool hasFromSourceId() => $_has(34);
  @$pb.TagNumber(35)
  void clearFromSourceId() => $_clearField(35);

  @$pb.TagNumber(36)
  $1.Dimension get dimension => $_getN(35);
  @$pb.TagNumber(36)
  set dimension($1.Dimension value) => $_setField(36, value);
  @$pb.TagNumber(36)
  $core.bool hasDimension() => $_has(35);
  @$pb.TagNumber(36)
  void clearDimension() => $_clearField(36);
  @$pb.TagNumber(36)
  $1.Dimension ensureDimension() => $_ensure(35);

  @$pb.TagNumber(37)
  $core.String get cover => $_getSZ(36);
  @$pb.TagNumber(37)
  set cover($core.String value) => $_setString(36, value);
  @$pb.TagNumber(37)
  $core.bool hasCover() => $_has(36);
  @$pb.TagNumber(37)
  void clearCover() => $_clearField(37);

  @$pb.TagNumber(38)
  ReasonStyle get badgeStyle => $_getN(37);
  @$pb.TagNumber(38)
  set badgeStyle(ReasonStyle value) => $_setField(38, value);
  @$pb.TagNumber(38)
  $core.bool hasBadgeStyle() => $_has(37);
  @$pb.TagNumber(38)
  void clearBadgeStyle() => $_clearField(38);
  @$pb.TagNumber(38)
  ReasonStyle ensureBadgeStyle() => $_ensure(37);

  @$pb.TagNumber(39)
  PowerIconStyle get powerIconStyle => $_getN(38);
  @$pb.TagNumber(39)
  set powerIconStyle(PowerIconStyle value) => $_setField(39, value);
  @$pb.TagNumber(39)
  $core.bool hasPowerIconStyle() => $_has(38);
  @$pb.TagNumber(39)
  void clearPowerIconStyle() => $_clearField(39);
  @$pb.TagNumber(39)
  PowerIconStyle ensurePowerIconStyle() => $_ensure(38);

  @$pb.TagNumber(40)
  $core.String get reserveStatusText => $_getSZ(39);
  @$pb.TagNumber(40)
  set reserveStatusText($core.String value) => $_setString(39, value);
  @$pb.TagNumber(40)
  $core.bool hasReserveStatusText() => $_has(39);
  @$pb.TagNumber(40)
  void clearReserveStatusText() => $_clearField(40);

  @$pb.TagNumber(41)
  $core.String get dislikeReportData => $_getSZ(40);
  @$pb.TagNumber(41)
  set dislikeReportData($core.String value) => $_setString(40, value);
  @$pb.TagNumber(41)
  $core.bool hasDislikeReportData() => $_has(40);
  @$pb.TagNumber(41)
  void clearDislikeReportData() => $_clearField(41);

  @$pb.TagNumber(42)
  RankInfo get rankInfoGame => $_getN(41);
  @$pb.TagNumber(42)
  set rankInfoGame(RankInfo value) => $_setField(42, value);
  @$pb.TagNumber(42)
  $core.bool hasRankInfoGame() => $_has(41);
  @$pb.TagNumber(42)
  void clearRankInfoGame() => $_clearField(42);
  @$pb.TagNumber(42)
  RankInfo ensureRankInfoGame() => $_ensure(41);

  @$pb.TagNumber(43)
  $core.String get firstFrame => $_getSZ(42);
  @$pb.TagNumber(43)
  set firstFrame($core.String value) => $_setString(42, value);
  @$pb.TagNumber(43)
  $core.bool hasFirstFrame() => $_has(42);
  @$pb.TagNumber(43)
  void clearFirstFrame() => $_clearField(43);
}

/// 相关推荐内容
class RelateItem extends $pb.GeneratedMessage {
  factory RelateItem({
    $core.String? url,
    $core.String? cover,
  }) {
    final result = RelateItem._();
    if (url != null) result.url = url;
    if (cover != null) result.cover = cover;
    return result;
  }

  RelateItem._();

  factory RelateItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelateItem()..mergeFromBuffer(data, registry);
  factory RelateItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelateItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelateItem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RelateItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'cover')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelateItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelateItem copyWith(void Function(RelateItem) updates) =>
      super.copyWith((message) => updates(message as RelateItem)) as RelateItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RelateItem() / RelateItem.new instead')
  static RelateItem create() => RelateItem._();
  static $pb.GeneratedMessage $_createMessage() => RelateItem._();
  @$core.override
  RelateItem createEmptyInstance() => RelateItem._();
  @$core.pragma('dart2js:noInline')
  static RelateItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelateItem>(RelateItem.$_createMessage);
  static RelateItem? _defaultInstance;

  /// 跳链
  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  /// 封面
  @$pb.TagNumber(2)
  $core.String get cover => $_getSZ(1);
  @$pb.TagNumber(2)
  set cover($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCover() => $_has(1);
  @$pb.TagNumber(2)
  void clearCover() => $_clearField(2);
}

/// 播放页推荐IFS-响应
class RelatesFeedReply extends $pb.GeneratedMessage {
  factory RelatesFeedReply({
    $core.Iterable<Relate>? list,
    $core.bool? hasNext,
    $4.PaginationReply? pagination,
  }) {
    final result = RelatesFeedReply._();
    if (list != null) result.list.addAll(list);
    if (hasNext != null) result.hasNext = hasNext;
    if (pagination != null) result.pagination = pagination;
    return result;
  }

  RelatesFeedReply._();

  factory RelatesFeedReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelatesFeedReply()..mergeFromBuffer(data, registry);
  factory RelatesFeedReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelatesFeedReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelatesFeedReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RelatesFeedReply.$_createMessage)
    ..pPM<Relate>(1, _omitFieldNames ? '' : 'list',
        subBuilder: Relate.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'hasNext')
    ..aOM<$4.PaginationReply>(3, _omitFieldNames ? '' : 'pagination',
        subBuilder: $4.PaginationReply.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatesFeedReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatesFeedReply copyWith(void Function(RelatesFeedReply) updates) =>
      super.copyWith((message) => updates(message as RelatesFeedReply))
          as RelatesFeedReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RelatesFeedReply() / RelatesFeedReply.new instead')
  static RelatesFeedReply create() => RelatesFeedReply._();
  static $pb.GeneratedMessage $_createMessage() => RelatesFeedReply._();
  @$core.override
  RelatesFeedReply createEmptyInstance() => RelatesFeedReply._();
  @$core.pragma('dart2js:noInline')
  static RelatesFeedReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RelatesFeedReply>(
          RelatesFeedReply.$_createMessage);
  static RelatesFeedReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Relate> get list => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasNext => $_getBF(1);
  @$pb.TagNumber(2)
  set hasNext($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasNext() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasNext() => $_clearField(2);

  @$pb.TagNumber(3)
  $4.PaginationReply get pagination => $_getN(2);
  @$pb.TagNumber(3)
  set pagination($4.PaginationReply value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPagination() => $_has(2);
  @$pb.TagNumber(3)
  void clearPagination() => $_clearField(3);
  @$pb.TagNumber(3)
  $4.PaginationReply ensurePagination() => $_ensure(2);
}

/// 播放页推荐IFS-请求
class RelatesFeedReq extends $pb.GeneratedMessage {
  factory RelatesFeedReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $core.String? from,
    $core.String? spmid,
    $core.String? fromSpmid,
    $3.PlayerArgs? playerArgs,
    $fixnum.Int64? relatesPage,
    $core.String? sessionId,
    $core.int? autoplay,
    $core.String? fromTrackId,
    $core.String? bizExtra,
    $fixnum.Int64? deviceType,
    $core.String? adExtra,
    $4.Pagination? pagination,
    $core.int? refreshNum,
  }) {
    final result = RelatesFeedReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (from != null) result.from = from;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (playerArgs != null) result.playerArgs = playerArgs;
    if (relatesPage != null) result.relatesPage = relatesPage;
    if (sessionId != null) result.sessionId = sessionId;
    if (autoplay != null) result.autoplay = autoplay;
    if (fromTrackId != null) result.fromTrackId = fromTrackId;
    if (bizExtra != null) result.bizExtra = bizExtra;
    if (deviceType != null) result.deviceType = deviceType;
    if (adExtra != null) result.adExtra = adExtra;
    if (pagination != null) result.pagination = pagination;
    if (refreshNum != null) result.refreshNum = refreshNum;
    return result;
  }

  RelatesFeedReq._();

  factory RelatesFeedReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelatesFeedReq()..mergeFromBuffer(data, registry);
  factory RelatesFeedReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelatesFeedReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelatesFeedReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RelatesFeedReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aOS(3, _omitFieldNames ? '' : 'from')
    ..aOS(4, _omitFieldNames ? '' : 'spmid')
    ..aOS(5, _omitFieldNames ? '' : 'fromSpmid')
    ..aOM<$3.PlayerArgs>(6, _omitFieldNames ? '' : 'playerArgs',
        subBuilder: $3.PlayerArgs.$_createMessage)
    ..aInt64(7, _omitFieldNames ? '' : 'relatesPage')
    ..aOS(8, _omitFieldNames ? '' : 'sessionId')
    ..aI(9, _omitFieldNames ? '' : 'autoplay')
    ..aOS(10, _omitFieldNames ? '' : 'fromTrackId')
    ..aOS(11, _omitFieldNames ? '' : 'bizExtra')
    ..aInt64(12, _omitFieldNames ? '' : 'deviceType')
    ..aOS(13, _omitFieldNames ? '' : 'adExtra')
    ..aOM<$4.Pagination>(14, _omitFieldNames ? '' : 'pagination',
        subBuilder: $4.Pagination.$_createMessage)
    ..aI(15, _omitFieldNames ? '' : 'refreshNum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatesFeedReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelatesFeedReq copyWith(void Function(RelatesFeedReq) updates) =>
      super.copyWith((message) => updates(message as RelatesFeedReq))
          as RelatesFeedReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RelatesFeedReq() / RelatesFeedReq.new instead')
  static RelatesFeedReq create() => RelatesFeedReq._();
  static $pb.GeneratedMessage $_createMessage() => RelatesFeedReq._();
  @$core.override
  RelatesFeedReq createEmptyInstance() => RelatesFeedReq._();
  @$core.pragma('dart2js:noInline')
  static RelatesFeedReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RelatesFeedReq>(
          RelatesFeedReq.$_createMessage);
  static RelatesFeedReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get from => $_getSZ(2);
  @$pb.TagNumber(3)
  set from($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get spmid => $_getSZ(3);
  @$pb.TagNumber(4)
  set spmid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpmid() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpmid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get fromSpmid => $_getSZ(4);
  @$pb.TagNumber(5)
  set fromSpmid($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFromSpmid() => $_has(4);
  @$pb.TagNumber(5)
  void clearFromSpmid() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.PlayerArgs get playerArgs => $_getN(5);
  @$pb.TagNumber(6)
  set playerArgs($3.PlayerArgs value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlayerArgs() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlayerArgs() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.PlayerArgs ensurePlayerArgs() => $_ensure(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get relatesPage => $_getI64(6);
  @$pb.TagNumber(7)
  set relatesPage($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRelatesPage() => $_has(6);
  @$pb.TagNumber(7)
  void clearRelatesPage() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sessionId => $_getSZ(7);
  @$pb.TagNumber(8)
  set sessionId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSessionId() => $_has(7);
  @$pb.TagNumber(8)
  void clearSessionId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get autoplay => $_getIZ(8);
  @$pb.TagNumber(9)
  set autoplay($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAutoplay() => $_has(8);
  @$pb.TagNumber(9)
  void clearAutoplay() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get fromTrackId => $_getSZ(9);
  @$pb.TagNumber(10)
  set fromTrackId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasFromTrackId() => $_has(9);
  @$pb.TagNumber(10)
  void clearFromTrackId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get bizExtra => $_getSZ(10);
  @$pb.TagNumber(11)
  set bizExtra($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasBizExtra() => $_has(10);
  @$pb.TagNumber(11)
  void clearBizExtra() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get deviceType => $_getI64(11);
  @$pb.TagNumber(12)
  set deviceType($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDeviceType() => $_has(11);
  @$pb.TagNumber(12)
  void clearDeviceType() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get adExtra => $_getSZ(12);
  @$pb.TagNumber(13)
  set adExtra($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAdExtra() => $_has(12);
  @$pb.TagNumber(13)
  void clearAdExtra() => $_clearField(13);

  @$pb.TagNumber(14)
  $4.Pagination get pagination => $_getN(13);
  @$pb.TagNumber(14)
  set pagination($4.Pagination value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasPagination() => $_has(13);
  @$pb.TagNumber(14)
  void clearPagination() => $_clearField(14);
  @$pb.TagNumber(14)
  $4.Pagination ensurePagination() => $_ensure(13);

  @$pb.TagNumber(15)
  $core.int get refreshNum => $_getIZ(14);
  @$pb.TagNumber(15)
  set refreshNum($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasRefreshNum() => $_has(14);
  @$pb.TagNumber(15)
  void clearRefreshNum() => $_clearField(15);
}

class RelateTab extends $pb.GeneratedMessage {
  factory RelateTab({
    $core.String? id,
    $core.String? title,
  }) {
    final result = RelateTab._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    return result;
  }

  RelateTab._();

  factory RelateTab.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelateTab()..mergeFromBuffer(data, registry);
  factory RelateTab.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RelateTab()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelateTab',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: RelateTab.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelateTab clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelateTab copyWith(void Function(RelateTab) updates) =>
      super.copyWith((message) => updates(message as RelateTab)) as RelateTab;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RelateTab() / RelateTab.new instead')
  static RelateTab create() => RelateTab._();
  static $pb.GeneratedMessage $_createMessage() => RelateTab._();
  @$core.override
  RelateTab createEmptyInstance() => RelateTab._();
  @$core.pragma('dart2js:noInline')
  static RelateTab getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelateTab>(RelateTab.$_createMessage);
  static RelateTab? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);
}

class ReplyStyle extends $pb.GeneratedMessage {
  factory ReplyStyle({
    $core.String? badgeUrl,
    $core.String? badgeText,
    $fixnum.Int64? badgeType,
  }) {
    final result = ReplyStyle._();
    if (badgeUrl != null) result.badgeUrl = badgeUrl;
    if (badgeText != null) result.badgeText = badgeText;
    if (badgeType != null) result.badgeType = badgeType;
    return result;
  }

  ReplyStyle._();

  factory ReplyStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReplyStyle()..mergeFromBuffer(data, registry);
  factory ReplyStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReplyStyle()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplyStyle',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ReplyStyle.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'badgeUrl')
    ..aOS(2, _omitFieldNames ? '' : 'badgeText')
    ..aInt64(3, _omitFieldNames ? '' : 'badgeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyStyle copyWith(void Function(ReplyStyle) updates) =>
      super.copyWith((message) => updates(message as ReplyStyle)) as ReplyStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReplyStyle() / ReplyStyle.new instead')
  static ReplyStyle create() => ReplyStyle._();
  static $pb.GeneratedMessage $_createMessage() => ReplyStyle._();
  @$core.override
  ReplyStyle createEmptyInstance() => ReplyStyle._();
  @$core.pragma('dart2js:noInline')
  static ReplyStyle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplyStyle>(ReplyStyle.$_createMessage);
  static ReplyStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get badgeUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set badgeUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBadgeUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearBadgeUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get badgeText => $_getSZ(1);
  @$pb.TagNumber(2)
  set badgeText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBadgeText() => $_has(1);
  @$pb.TagNumber(2)
  void clearBadgeText() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get badgeType => $_getI64(2);
  @$pb.TagNumber(3)
  set badgeType($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBadgeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearBadgeType() => $_clearField(3);
}

/// 用户操作状态
class ReqUser extends $pb.GeneratedMessage {
  factory ReqUser({
    $core.int? attention,
    $core.int? guestAttention,
    $core.int? favorite,
    $core.int? like,
    $core.int? dislike,
    $core.int? coin,
    $core.int? attentionLevel,
    $core.int? favSeason,
    Button? elecPlusBtn,
  }) {
    final result = ReqUser._();
    if (attention != null) result.attention = attention;
    if (guestAttention != null) result.guestAttention = guestAttention;
    if (favorite != null) result.favorite = favorite;
    if (like != null) result.like = like;
    if (dislike != null) result.dislike = dislike;
    if (coin != null) result.coin = coin;
    if (attentionLevel != null) result.attentionLevel = attentionLevel;
    if (favSeason != null) result.favSeason = favSeason;
    if (elecPlusBtn != null) result.elecPlusBtn = elecPlusBtn;
    return result;
  }

  ReqUser._();

  factory ReqUser.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReqUser()..mergeFromBuffer(data, registry);
  factory ReqUser.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReqUser()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReqUser',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ReqUser.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'attention')
    ..aI(2, _omitFieldNames ? '' : 'guestAttention')
    ..aI(3, _omitFieldNames ? '' : 'favorite')
    ..aI(4, _omitFieldNames ? '' : 'like')
    ..aI(5, _omitFieldNames ? '' : 'dislike')
    ..aI(6, _omitFieldNames ? '' : 'coin')
    ..aI(7, _omitFieldNames ? '' : 'attentionLevel')
    ..aI(8, _omitFieldNames ? '' : 'favSeason')
    ..aOM<Button>(9, _omitFieldNames ? '' : 'elecPlusBtn',
        subBuilder: Button.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReqUser clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReqUser copyWith(void Function(ReqUser) updates) =>
      super.copyWith((message) => updates(message as ReqUser)) as ReqUser;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReqUser() / ReqUser.new instead')
  static ReqUser create() => ReqUser._();
  static $pb.GeneratedMessage $_createMessage() => ReqUser._();
  @$core.override
  ReqUser createEmptyInstance() => ReqUser._();
  @$core.pragma('dart2js:noInline')
  static ReqUser getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReqUser>(ReqUser.$_createMessage);
  static ReqUser? _defaultInstance;

  /// 用户是否关注UP
  @$pb.TagNumber(1)
  $core.int get attention => $_getIZ(0);
  @$pb.TagNumber(1)
  set attention($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttention() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttention() => $_clearField(1);

  /// UP是否关注用户
  @$pb.TagNumber(2)
  $core.int get guestAttention => $_getIZ(1);
  @$pb.TagNumber(2)
  set guestAttention($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGuestAttention() => $_has(1);
  @$pb.TagNumber(2)
  void clearGuestAttention() => $_clearField(2);

  /// 是否收藏
  @$pb.TagNumber(3)
  $core.int get favorite => $_getIZ(2);
  @$pb.TagNumber(3)
  set favorite($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFavorite() => $_has(2);
  @$pb.TagNumber(3)
  void clearFavorite() => $_clearField(3);

  /// 是否点赞
  @$pb.TagNumber(4)
  $core.int get like => $_getIZ(3);
  @$pb.TagNumber(4)
  set like($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLike() => $_has(3);
  @$pb.TagNumber(4)
  void clearLike() => $_clearField(4);

  /// 是否点踩
  @$pb.TagNumber(5)
  $core.int get dislike => $_getIZ(4);
  @$pb.TagNumber(5)
  set dislike($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDislike() => $_has(4);
  @$pb.TagNumber(5)
  void clearDislike() => $_clearField(5);

  /// 是否投币
  @$pb.TagNumber(6)
  $core.int get coin => $_getIZ(5);
  @$pb.TagNumber(6)
  set coin($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCoin() => $_has(5);
  @$pb.TagNumber(6)
  void clearCoin() => $_clearField(6);

  /// 关注等级
  @$pb.TagNumber(7)
  $core.int get attentionLevel => $_getIZ(6);
  @$pb.TagNumber(7)
  set attentionLevel($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAttentionLevel() => $_has(6);
  @$pb.TagNumber(7)
  void clearAttentionLevel() => $_clearField(7);

  /// 是否收藏合集
  @$pb.TagNumber(8)
  $core.int get favSeason => $_getIZ(7);
  @$pb.TagNumber(8)
  set favSeason($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFavSeason() => $_has(7);
  @$pb.TagNumber(8)
  void clearFavSeason() => $_clearField(8);

  @$pb.TagNumber(9)
  Button get elecPlusBtn => $_getN(8);
  @$pb.TagNumber(9)
  set elecPlusBtn(Button value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasElecPlusBtn() => $_has(8);
  @$pb.TagNumber(9)
  void clearElecPlusBtn() => $_clearField(9);
  @$pb.TagNumber(9)
  Button ensureElecPlusBtn() => $_ensure(8);
}

class ReserveReply extends $pb.GeneratedMessage {
  factory ReserveReply({
    $fixnum.Int64? reserveId,
  }) {
    final result = ReserveReply._();
    if (reserveId != null) result.reserveId = reserveId;
    return result;
  }

  ReserveReply._();

  factory ReserveReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReserveReply()..mergeFromBuffer(data, registry);
  factory ReserveReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReserveReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReserveReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ReserveReply.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'reserveId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveReply copyWith(void Function(ReserveReply) updates) =>
      super.copyWith((message) => updates(message as ReserveReply))
          as ReserveReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReserveReply() / ReserveReply.new instead')
  static ReserveReply create() => ReserveReply._();
  static $pb.GeneratedMessage $_createMessage() => ReserveReply._();
  @$core.override
  ReserveReply createEmptyInstance() => ReserveReply._();
  @$core.pragma('dart2js:noInline')
  static ReserveReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReserveReply>(
          ReserveReply.$_createMessage);
  static ReserveReply? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get reserveId => $_getI64(0);
  @$pb.TagNumber(1)
  set reserveId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReserveId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReserveId() => $_clearField(1);
}

class ReserveReq extends $pb.GeneratedMessage {
  factory ReserveReq({
    $fixnum.Int64? reserveId,
    $fixnum.Int64? reserveAction,
    $fixnum.Int64? upId,
  }) {
    final result = ReserveReq._();
    if (reserveId != null) result.reserveId = reserveId;
    if (reserveAction != null) result.reserveAction = reserveAction;
    if (upId != null) result.upId = upId;
    return result;
  }

  ReserveReq._();

  factory ReserveReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReserveReq()..mergeFromBuffer(data, registry);
  factory ReserveReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReserveReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReserveReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ReserveReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'reserveId')
    ..aInt64(2, _omitFieldNames ? '' : 'reserveAction')
    ..aInt64(3, _omitFieldNames ? '' : 'upId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveReq copyWith(void Function(ReserveReq) updates) =>
      super.copyWith((message) => updates(message as ReserveReq)) as ReserveReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReserveReq() / ReserveReq.new instead')
  static ReserveReq create() => ReserveReq._();
  static $pb.GeneratedMessage $_createMessage() => ReserveReq._();
  @$core.override
  ReserveReq createEmptyInstance() => ReserveReq._();
  @$core.pragma('dart2js:noInline')
  static ReserveReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReserveReq>(ReserveReq.$_createMessage);
  static ReserveReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get reserveId => $_getI64(0);
  @$pb.TagNumber(1)
  set reserveId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReserveId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReserveId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get reserveAction => $_getI64(1);
  @$pb.TagNumber(2)
  set reserveAction($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReserveAction() => $_has(1);
  @$pb.TagNumber(2)
  void clearReserveAction() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get upId => $_getI64(2);
  @$pb.TagNumber(3)
  set upId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpId() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpId() => $_clearField(3);
}

class Restriction extends $pb.GeneratedMessage {
  factory Restriction({
    $core.bool? isTeenagers,
    $core.bool? isLessons,
    $core.bool? isReview,
    $core.bool? disableRcmd,
  }) {
    final result = Restriction._();
    if (isTeenagers != null) result.isTeenagers = isTeenagers;
    if (isLessons != null) result.isLessons = isLessons;
    if (isReview != null) result.isReview = isReview;
    if (disableRcmd != null) result.disableRcmd = disableRcmd;
    return result;
  }

  Restriction._();

  factory Restriction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Restriction()..mergeFromBuffer(data, registry);
  factory Restriction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Restriction()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Restriction',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Restriction.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'isTeenagers')
    ..aOB(2, _omitFieldNames ? '' : 'isLessons')
    ..aOB(3, _omitFieldNames ? '' : 'isReview')
    ..aOB(4, _omitFieldNames ? '' : 'disableRcmd')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Restriction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Restriction copyWith(void Function(Restriction) updates) =>
      super.copyWith((message) => updates(message as Restriction))
          as Restriction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Restriction() / Restriction.new instead')
  static Restriction create() => Restriction._();
  static $pb.GeneratedMessage $_createMessage() => Restriction._();
  @$core.override
  Restriction createEmptyInstance() => Restriction._();
  @$core.pragma('dart2js:noInline')
  static Restriction getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Restriction>(
          Restriction.$_createMessage);
  static Restriction? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isTeenagers => $_getBF(0);
  @$pb.TagNumber(1)
  set isTeenagers($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsTeenagers() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsTeenagers() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isLessons => $_getBF(1);
  @$pb.TagNumber(2)
  set isLessons($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsLessons() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsLessons() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isReview => $_getBF(2);
  @$pb.TagNumber(3)
  set isReview($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsReview() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsReview() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get disableRcmd => $_getBF(3);
  @$pb.TagNumber(4)
  set disableRcmd($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDisableRcmd() => $_has(3);
  @$pb.TagNumber(4)
  void clearDisableRcmd() => $_clearField(4);
}

/// 剧集信息
class Season extends $pb.GeneratedMessage {
  factory Season({
    $core.String? allowDownload,
    $fixnum.Int64? seasonId,
    $core.int? isJump,
    $core.String? title,
    $core.String? cover,
    $core.int? isFinish,
    $fixnum.Int64? newestEpId,
    $core.String? newestEpIndex,
    $fixnum.Int64? totalCount,
    $core.int? weekday,
    UserSeason? userSeason,
    SeasonPlayer? player,
    $core.String? ogvPlayurl,
  }) {
    final result = Season._();
    if (allowDownload != null) result.allowDownload = allowDownload;
    if (seasonId != null) result.seasonId = seasonId;
    if (isJump != null) result.isJump = isJump;
    if (title != null) result.title = title;
    if (cover != null) result.cover = cover;
    if (isFinish != null) result.isFinish = isFinish;
    if (newestEpId != null) result.newestEpId = newestEpId;
    if (newestEpIndex != null) result.newestEpIndex = newestEpIndex;
    if (totalCount != null) result.totalCount = totalCount;
    if (weekday != null) result.weekday = weekday;
    if (userSeason != null) result.userSeason = userSeason;
    if (player != null) result.player = player;
    if (ogvPlayurl != null) result.ogvPlayurl = ogvPlayurl;
    return result;
  }

  Season._();

  factory Season.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Season()..mergeFromBuffer(data, registry);
  factory Season.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Season()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Season',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Season.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'allowDownload')
    ..aInt64(2, _omitFieldNames ? '' : 'seasonId')
    ..aI(3, _omitFieldNames ? '' : 'isJump')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'cover')
    ..aI(6, _omitFieldNames ? '' : 'isFinish')
    ..aInt64(7, _omitFieldNames ? '' : 'newestEpId')
    ..aOS(8, _omitFieldNames ? '' : 'newestEpIndex')
    ..aInt64(9, _omitFieldNames ? '' : 'totalCount')
    ..aI(10, _omitFieldNames ? '' : 'weekday')
    ..aOM<UserSeason>(11, _omitFieldNames ? '' : 'userSeason',
        subBuilder: UserSeason.$_createMessage)
    ..aOM<SeasonPlayer>(12, _omitFieldNames ? '' : 'player',
        subBuilder: SeasonPlayer.$_createMessage)
    ..aOS(13, _omitFieldNames ? '' : 'ogvPlayurl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Season clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Season copyWith(void Function(Season) updates) =>
      super.copyWith((message) => updates(message as Season)) as Season;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Season() / Season.new instead')
  static Season create() => Season._();
  static $pb.GeneratedMessage $_createMessage() => Season._();
  @$core.override
  Season createEmptyInstance() => Season._();
  @$core.pragma('dart2js:noInline')
  static Season getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Season>(Season.$_createMessage);
  static Season? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get allowDownload => $_getSZ(0);
  @$pb.TagNumber(1)
  set allowDownload($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllowDownload() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllowDownload() => $_clearField(1);

  /// 剧集ssid
  @$pb.TagNumber(2)
  $fixnum.Int64 get seasonId => $_getI64(1);
  @$pb.TagNumber(2)
  set seasonId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeasonId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeasonId() => $_clearField(2);

  /// 是否重定向跳转
  @$pb.TagNumber(3)
  $core.int get isJump => $_getIZ(2);
  @$pb.TagNumber(3)
  set isJump($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsJump() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsJump() => $_clearField(3);

  /// 剧集标题
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  /// 剧集封面url
  @$pb.TagNumber(5)
  $core.String get cover => $_getSZ(4);
  @$pb.TagNumber(5)
  set cover($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCover() => $_has(4);
  @$pb.TagNumber(5)
  void clearCover() => $_clearField(5);

  /// 剧集是否完结
  @$pb.TagNumber(6)
  $core.int get isFinish => $_getIZ(5);
  @$pb.TagNumber(6)
  set isFinish($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsFinish() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsFinish() => $_clearField(6);

  /// 最新一话epid
  @$pb.TagNumber(7)
  $fixnum.Int64 get newestEpId => $_getI64(6);
  @$pb.TagNumber(7)
  set newestEpId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNewestEpId() => $_has(6);
  @$pb.TagNumber(7)
  void clearNewestEpId() => $_clearField(7);

  /// 最新一话标题
  @$pb.TagNumber(8)
  $core.String get newestEpIndex => $_getSZ(7);
  @$pb.TagNumber(8)
  set newestEpIndex($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNewestEpIndex() => $_has(7);
  @$pb.TagNumber(8)
  void clearNewestEpIndex() => $_clearField(8);

  /// 总集数
  @$pb.TagNumber(9)
  $fixnum.Int64 get totalCount => $_getI64(8);
  @$pb.TagNumber(9)
  set totalCount($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTotalCount() => $_has(8);
  @$pb.TagNumber(9)
  void clearTotalCount() => $_clearField(9);

  /// 更新星期日
  @$pb.TagNumber(10)
  $core.int get weekday => $_getIZ(9);
  @$pb.TagNumber(10)
  set weekday($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasWeekday() => $_has(9);
  @$pb.TagNumber(10)
  void clearWeekday() => $_clearField(10);

  /// 用户追番标志
  @$pb.TagNumber(11)
  UserSeason get userSeason => $_getN(10);
  @$pb.TagNumber(11)
  set userSeason(UserSeason value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasUserSeason() => $_has(10);
  @$pb.TagNumber(11)
  void clearUserSeason() => $_clearField(11);
  @$pb.TagNumber(11)
  UserSeason ensureUserSeason() => $_ensure(10);

  @$pb.TagNumber(12)
  SeasonPlayer get player => $_getN(11);
  @$pb.TagNumber(12)
  set player(SeasonPlayer value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasPlayer() => $_has(11);
  @$pb.TagNumber(12)
  void clearPlayer() => $_clearField(12);
  @$pb.TagNumber(12)
  SeasonPlayer ensurePlayer() => $_ensure(11);

  /// 单集页面url
  @$pb.TagNumber(13)
  $core.String get ogvPlayurl => $_getSZ(12);
  @$pb.TagNumber(13)
  set ogvPlayurl($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasOgvPlayurl() => $_has(12);
  @$pb.TagNumber(13)
  void clearOgvPlayurl() => $_clearField(13);
}

class SeasonActivityRecordReply extends $pb.GeneratedMessage {
  factory SeasonActivityRecordReply({
    UgcSeasonActivity? activity,
  }) {
    final result = SeasonActivityRecordReply._();
    if (activity != null) result.activity = activity;
    return result;
  }

  SeasonActivityRecordReply._();

  factory SeasonActivityRecordReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonActivityRecordReply()..mergeFromBuffer(data, registry);
  factory SeasonActivityRecordReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonActivityRecordReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonActivityRecordReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonActivityRecordReply.$_createMessage)
    ..aOM<UgcSeasonActivity>(1, _omitFieldNames ? '' : 'activity',
        subBuilder: UgcSeasonActivity.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonActivityRecordReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonActivityRecordReply copyWith(
          void Function(SeasonActivityRecordReply) updates) =>
      super.copyWith((message) => updates(message as SeasonActivityRecordReply))
          as SeasonActivityRecordReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SeasonActivityRecordReply() / SeasonActivityRecordReply.new instead')
  static SeasonActivityRecordReply create() => SeasonActivityRecordReply._();
  static $pb.GeneratedMessage $_createMessage() =>
      SeasonActivityRecordReply._();
  @$core.override
  SeasonActivityRecordReply createEmptyInstance() =>
      SeasonActivityRecordReply._();
  @$core.pragma('dart2js:noInline')
  static SeasonActivityRecordReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonActivityRecordReply>(
          SeasonActivityRecordReply.$_createMessage);
  static SeasonActivityRecordReply? _defaultInstance;

  @$pb.TagNumber(1)
  UgcSeasonActivity get activity => $_getN(0);
  @$pb.TagNumber(1)
  set activity(UgcSeasonActivity value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasActivity() => $_has(0);
  @$pb.TagNumber(1)
  void clearActivity() => $_clearField(1);
  @$pb.TagNumber(1)
  UgcSeasonActivity ensureActivity() => $_ensure(0);
}

class SeasonActivityRecordReq extends $pb.GeneratedMessage {
  factory SeasonActivityRecordReq({
    $fixnum.Int64? seasonId,
    $fixnum.Int64? activityId,
    $core.int? action,
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $fixnum.Int64? scene,
    $core.String? spmid,
  }) {
    final result = SeasonActivityRecordReq._();
    if (seasonId != null) result.seasonId = seasonId;
    if (activityId != null) result.activityId = activityId;
    if (action != null) result.action = action;
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (scene != null) result.scene = scene;
    if (spmid != null) result.spmid = spmid;
    return result;
  }

  SeasonActivityRecordReq._();

  factory SeasonActivityRecordReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonActivityRecordReq()..mergeFromBuffer(data, registry);
  factory SeasonActivityRecordReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonActivityRecordReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonActivityRecordReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonActivityRecordReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'seasonId')
    ..aInt64(2, _omitFieldNames ? '' : 'activityId')
    ..aI(3, _omitFieldNames ? '' : 'action')
    ..aInt64(4, _omitFieldNames ? '' : 'aid')
    ..aInt64(5, _omitFieldNames ? '' : 'cid')
    ..aInt64(6, _omitFieldNames ? '' : 'scene')
    ..aOS(7, _omitFieldNames ? '' : 'spmid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonActivityRecordReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonActivityRecordReq copyWith(
          void Function(SeasonActivityRecordReq) updates) =>
      super.copyWith((message) => updates(message as SeasonActivityRecordReq))
          as SeasonActivityRecordReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SeasonActivityRecordReq() / SeasonActivityRecordReq.new instead')
  static SeasonActivityRecordReq create() => SeasonActivityRecordReq._();
  static $pb.GeneratedMessage $_createMessage() => SeasonActivityRecordReq._();
  @$core.override
  SeasonActivityRecordReq createEmptyInstance() => SeasonActivityRecordReq._();
  @$core.pragma('dart2js:noInline')
  static SeasonActivityRecordReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonActivityRecordReq>(
          SeasonActivityRecordReq.$_createMessage);
  static SeasonActivityRecordReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seasonId => $_getI64(0);
  @$pb.TagNumber(1)
  set seasonId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get activityId => $_getI64(1);
  @$pb.TagNumber(2)
  set activityId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActivityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearActivityId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get action => $_getIZ(2);
  @$pb.TagNumber(3)
  set action($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAction() => $_has(2);
  @$pb.TagNumber(3)
  void clearAction() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get aid => $_getI64(3);
  @$pb.TagNumber(4)
  set aid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAid() => $_has(3);
  @$pb.TagNumber(4)
  void clearAid() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get cid => $_getI64(4);
  @$pb.TagNumber(5)
  set cid($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCid() => $_has(4);
  @$pb.TagNumber(5)
  void clearCid() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get scene => $_getI64(5);
  @$pb.TagNumber(6)
  set scene($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScene() => $_has(5);
  @$pb.TagNumber(6)
  void clearScene() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get spmid => $_getSZ(6);
  @$pb.TagNumber(7)
  set spmid($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSpmid() => $_has(6);
  @$pb.TagNumber(7)
  void clearSpmid() => $_clearField(7);
}

class SeasonPlayer extends $pb.GeneratedMessage {
  factory SeasonPlayer({
    $fixnum.Int64? aid,
    $core.String? vid,
    $fixnum.Int64? cid,
    $core.String? from,
  }) {
    final result = SeasonPlayer._();
    if (aid != null) result.aid = aid;
    if (vid != null) result.vid = vid;
    if (cid != null) result.cid = cid;
    if (from != null) result.from = from;
    return result;
  }

  SeasonPlayer._();

  factory SeasonPlayer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonPlayer()..mergeFromBuffer(data, registry);
  factory SeasonPlayer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonPlayer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonPlayer',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonPlayer.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'vid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..aOS(4, _omitFieldNames ? '' : 'from')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonPlayer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonPlayer copyWith(void Function(SeasonPlayer) updates) =>
      super.copyWith((message) => updates(message as SeasonPlayer))
          as SeasonPlayer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeasonPlayer() / SeasonPlayer.new instead')
  static SeasonPlayer create() => SeasonPlayer._();
  static $pb.GeneratedMessage $_createMessage() => SeasonPlayer._();
  @$core.override
  SeasonPlayer createEmptyInstance() => SeasonPlayer._();
  @$core.pragma('dart2js:noInline')
  static SeasonPlayer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SeasonPlayer>(
          SeasonPlayer.$_createMessage);
  static SeasonPlayer? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get vid => $_getSZ(1);
  @$pb.TagNumber(2)
  set vid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVid() => $_has(1);
  @$pb.TagNumber(2)
  void clearVid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get from => $_getSZ(3);
  @$pb.TagNumber(4)
  set from($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFrom() => $_has(3);
  @$pb.TagNumber(4)
  void clearFrom() => $_clearField(4);
}

/// 合集详情页-响应
class SeasonReply extends $pb.GeneratedMessage {
  factory SeasonReply({
    UgcSeason? season,
  }) {
    final result = SeasonReply._();
    if (season != null) result.season = season;
    return result;
  }

  SeasonReply._();

  factory SeasonReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonReply()..mergeFromBuffer(data, registry);
  factory SeasonReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonReply.$_createMessage)
    ..aOM<UgcSeason>(1, _omitFieldNames ? '' : 'season',
        subBuilder: UgcSeason.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonReply copyWith(void Function(SeasonReply) updates) =>
      super.copyWith((message) => updates(message as SeasonReply))
          as SeasonReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeasonReply() / SeasonReply.new instead')
  static SeasonReply create() => SeasonReply._();
  static $pb.GeneratedMessage $_createMessage() => SeasonReply._();
  @$core.override
  SeasonReply createEmptyInstance() => SeasonReply._();
  @$core.pragma('dart2js:noInline')
  static SeasonReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SeasonReply>(
          SeasonReply.$_createMessage);
  static SeasonReply? _defaultInstance;

  /// 合集信息
  @$pb.TagNumber(1)
  UgcSeason get season => $_getN(0);
  @$pb.TagNumber(1)
  set season(UgcSeason value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSeason() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeason() => $_clearField(1);
  @$pb.TagNumber(1)
  UgcSeason ensureSeason() => $_ensure(0);
}

/// 合集详情页-请求
class SeasonReq extends $pb.GeneratedMessage {
  factory SeasonReq({
    $fixnum.Int64? seasonId,
  }) {
    final result = SeasonReq._();
    if (seasonId != null) result.seasonId = seasonId;
    return result;
  }

  SeasonReq._();

  factory SeasonReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonReq()..mergeFromBuffer(data, registry);
  factory SeasonReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'seasonId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonReq copyWith(void Function(SeasonReq) updates) =>
      super.copyWith((message) => updates(message as SeasonReq)) as SeasonReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeasonReq() / SeasonReq.new instead')
  static SeasonReq create() => SeasonReq._();
  static $pb.GeneratedMessage $_createMessage() => SeasonReq._();
  @$core.override
  SeasonReq createEmptyInstance() => SeasonReq._();
  @$core.pragma('dart2js:noInline')
  static SeasonReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonReq>(SeasonReq.$_createMessage);
  static SeasonReq? _defaultInstance;

  /// 合集id
  @$pb.TagNumber(1)
  $fixnum.Int64 get seasonId => $_getI64(0);
  @$pb.TagNumber(1)
  set seasonId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);
}

class SeasonShow extends $pb.GeneratedMessage {
  factory SeasonShow({
    $core.String? buttonText,
    $core.String? joinText,
    $core.String? ruleText,
    $core.String? checkinText,
    $core.String? checkinPrompt,
  }) {
    final result = SeasonShow._();
    if (buttonText != null) result.buttonText = buttonText;
    if (joinText != null) result.joinText = joinText;
    if (ruleText != null) result.ruleText = ruleText;
    if (checkinText != null) result.checkinText = checkinText;
    if (checkinPrompt != null) result.checkinPrompt = checkinPrompt;
    return result;
  }

  SeasonShow._();

  factory SeasonShow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonShow()..mergeFromBuffer(data, registry);
  factory SeasonShow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonShow()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonShow',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonShow.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'buttonText')
    ..aOS(2, _omitFieldNames ? '' : 'joinText')
    ..aOS(3, _omitFieldNames ? '' : 'ruleText')
    ..aOS(4, _omitFieldNames ? '' : 'checkinText')
    ..aOS(5, _omitFieldNames ? '' : 'checkinPrompt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonShow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonShow copyWith(void Function(SeasonShow) updates) =>
      super.copyWith((message) => updates(message as SeasonShow)) as SeasonShow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SeasonShow() / SeasonShow.new instead')
  static SeasonShow create() => SeasonShow._();
  static $pb.GeneratedMessage $_createMessage() => SeasonShow._();
  @$core.override
  SeasonShow createEmptyInstance() => SeasonShow._();
  @$core.pragma('dart2js:noInline')
  static SeasonShow getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonShow>(SeasonShow.$_createMessage);
  static SeasonShow? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buttonText => $_getSZ(0);
  @$pb.TagNumber(1)
  set buttonText($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasButtonText() => $_has(0);
  @$pb.TagNumber(1)
  void clearButtonText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get joinText => $_getSZ(1);
  @$pb.TagNumber(2)
  set joinText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJoinText() => $_has(1);
  @$pb.TagNumber(2)
  void clearJoinText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get ruleText => $_getSZ(2);
  @$pb.TagNumber(3)
  set ruleText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRuleText() => $_has(2);
  @$pb.TagNumber(3)
  void clearRuleText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get checkinText => $_getSZ(3);
  @$pb.TagNumber(4)
  set checkinText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCheckinText() => $_has(3);
  @$pb.TagNumber(4)
  void clearCheckinText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get checkinPrompt => $_getSZ(4);
  @$pb.TagNumber(5)
  set checkinPrompt($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCheckinPrompt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCheckinPrompt() => $_clearField(5);
}

class SeasonWidgetExposeReply extends $pb.GeneratedMessage {
  factory SeasonWidgetExposeReply({
    $fixnum.Int64? seasonId,
    $fixnum.Int64? activityId,
  }) {
    final result = SeasonWidgetExposeReply._();
    if (seasonId != null) result.seasonId = seasonId;
    if (activityId != null) result.activityId = activityId;
    return result;
  }

  SeasonWidgetExposeReply._();

  factory SeasonWidgetExposeReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonWidgetExposeReply()..mergeFromBuffer(data, registry);
  factory SeasonWidgetExposeReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonWidgetExposeReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonWidgetExposeReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonWidgetExposeReply.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'seasonId')
    ..aInt64(2, _omitFieldNames ? '' : 'activityId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonWidgetExposeReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonWidgetExposeReply copyWith(
          void Function(SeasonWidgetExposeReply) updates) =>
      super.copyWith((message) => updates(message as SeasonWidgetExposeReply))
          as SeasonWidgetExposeReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SeasonWidgetExposeReply() / SeasonWidgetExposeReply.new instead')
  static SeasonWidgetExposeReply create() => SeasonWidgetExposeReply._();
  static $pb.GeneratedMessage $_createMessage() => SeasonWidgetExposeReply._();
  @$core.override
  SeasonWidgetExposeReply createEmptyInstance() => SeasonWidgetExposeReply._();
  @$core.pragma('dart2js:noInline')
  static SeasonWidgetExposeReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonWidgetExposeReply>(
          SeasonWidgetExposeReply.$_createMessage);
  static SeasonWidgetExposeReply? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seasonId => $_getI64(0);
  @$pb.TagNumber(1)
  set seasonId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get activityId => $_getI64(1);
  @$pb.TagNumber(2)
  set activityId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActivityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearActivityId() => $_clearField(2);
}

class SeasonWidgetExposeReq extends $pb.GeneratedMessage {
  factory SeasonWidgetExposeReq({
    $fixnum.Int64? mid,
    $core.int? type,
    $fixnum.Int64? seasonId,
    $fixnum.Int64? activityId,
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $fixnum.Int64? scene,
  }) {
    final result = SeasonWidgetExposeReq._();
    if (mid != null) result.mid = mid;
    if (type != null) result.type = type;
    if (seasonId != null) result.seasonId = seasonId;
    if (activityId != null) result.activityId = activityId;
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (scene != null) result.scene = scene;
    return result;
  }

  SeasonWidgetExposeReq._();

  factory SeasonWidgetExposeReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonWidgetExposeReq()..mergeFromBuffer(data, registry);
  factory SeasonWidgetExposeReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SeasonWidgetExposeReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeasonWidgetExposeReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SeasonWidgetExposeReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'mid')
    ..aI(2, _omitFieldNames ? '' : 'type')
    ..aInt64(3, _omitFieldNames ? '' : 'seasonId')
    ..aInt64(4, _omitFieldNames ? '' : 'activityId')
    ..aInt64(5, _omitFieldNames ? '' : 'aid')
    ..aInt64(6, _omitFieldNames ? '' : 'cid')
    ..aInt64(7, _omitFieldNames ? '' : 'scene')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonWidgetExposeReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeasonWidgetExposeReq copyWith(
          void Function(SeasonWidgetExposeReq) updates) =>
      super.copyWith((message) => updates(message as SeasonWidgetExposeReq))
          as SeasonWidgetExposeReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SeasonWidgetExposeReq() / SeasonWidgetExposeReq.new instead')
  static SeasonWidgetExposeReq create() => SeasonWidgetExposeReq._();
  static $pb.GeneratedMessage $_createMessage() => SeasonWidgetExposeReq._();
  @$core.override
  SeasonWidgetExposeReq createEmptyInstance() => SeasonWidgetExposeReq._();
  @$core.pragma('dart2js:noInline')
  static SeasonWidgetExposeReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeasonWidgetExposeReq>(
          SeasonWidgetExposeReq.$_createMessage);
  static SeasonWidgetExposeReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get mid => $_getI64(0);
  @$pb.TagNumber(1)
  set mid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMid() => $_has(0);
  @$pb.TagNumber(1)
  void clearMid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get type => $_getIZ(1);
  @$pb.TagNumber(2)
  set type($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get seasonId => $_getI64(2);
  @$pb.TagNumber(3)
  set seasonId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSeasonId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeasonId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get activityId => $_getI64(3);
  @$pb.TagNumber(4)
  set activityId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActivityId() => $_has(3);
  @$pb.TagNumber(4)
  void clearActivityId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get aid => $_getI64(4);
  @$pb.TagNumber(5)
  set aid($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAid() => $_has(4);
  @$pb.TagNumber(5)
  void clearAid() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get cid => $_getI64(5);
  @$pb.TagNumber(6)
  set cid($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCid() => $_has(5);
  @$pb.TagNumber(6)
  void clearCid() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get scene => $_getI64(6);
  @$pb.TagNumber(7)
  set scene($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasScene() => $_has(6);
  @$pb.TagNumber(7)
  void clearScene() => $_clearField(7);
}

/// 视频合集小节信息
class Section extends $pb.GeneratedMessage {
  factory Section({
    $fixnum.Int64? id,
    $core.String? title,
    $fixnum.Int64? type,
    $core.Iterable<Episode>? episodes,
  }) {
    final result = Section._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (type != null) result.type = type;
    if (episodes != null) result.episodes.addAll(episodes);
    return result;
  }

  Section._();

  factory Section.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Section()..mergeFromBuffer(data, registry);
  factory Section.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Section()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Section',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Section.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aInt64(3, _omitFieldNames ? '' : 'type')
    ..pPM<Episode>(4, _omitFieldNames ? '' : 'episodes',
        subBuilder: Episode.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Section clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Section copyWith(void Function(Section) updates) =>
      super.copyWith((message) => updates(message as Section)) as Section;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Section() / Section.new instead')
  static Section create() => Section._();
  static $pb.GeneratedMessage $_createMessage() => Section._();
  @$core.override
  Section createEmptyInstance() => Section._();
  @$core.pragma('dart2js:noInline')
  static Section getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Section>(Section.$_createMessage);
  static Section? _defaultInstance;

  /// 小节id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 小节标题
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// 小节类型
  /// 0:其他 1:正片
  @$pb.TagNumber(3)
  $fixnum.Int64 get type => $_getI64(2);
  @$pb.TagNumber(3)
  set type($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  /// 单话列表
  @$pb.TagNumber(4)
  $pb.PbList<Episode> get episodes => $_getList(3);
}

/// 短视频下载-响应
class ShortFormVideoDownloadReply extends $pb.GeneratedMessage {
  factory ShortFormVideoDownloadReply({
    $core.bool? hasDownloadUrl,
    $core.String? downloadUrl_2,
    $core.String? md5,
    $fixnum.Int64? size,
    $core.String? backupDownloadUrl,
  }) {
    final result = ShortFormVideoDownloadReply._();
    if (hasDownloadUrl != null) result.hasDownloadUrl = hasDownloadUrl;
    if (downloadUrl_2 != null) result.downloadUrl_2 = downloadUrl_2;
    if (md5 != null) result.md5 = md5;
    if (size != null) result.size = size;
    if (backupDownloadUrl != null) result.backupDownloadUrl = backupDownloadUrl;
    return result;
  }

  ShortFormVideoDownloadReply._();

  factory ShortFormVideoDownloadReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShortFormVideoDownloadReply()..mergeFromBuffer(data, registry);
  factory ShortFormVideoDownloadReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShortFormVideoDownloadReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShortFormVideoDownloadReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ShortFormVideoDownloadReply.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'hasDownloadUrl')
    ..aOS(2, _omitFieldNames ? '' : 'downloadUrl')
    ..aOS(3, _omitFieldNames ? '' : 'md5')
    ..aInt64(4, _omitFieldNames ? '' : 'size')
    ..aOS(5, _omitFieldNames ? '' : 'backupDownloadUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShortFormVideoDownloadReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShortFormVideoDownloadReply copyWith(
          void Function(ShortFormVideoDownloadReply) updates) =>
      super.copyWith(
              (message) => updates(message as ShortFormVideoDownloadReply))
          as ShortFormVideoDownloadReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ShortFormVideoDownloadReply() / ShortFormVideoDownloadReply.new instead')
  static ShortFormVideoDownloadReply create() =>
      ShortFormVideoDownloadReply._();
  static $pb.GeneratedMessage $_createMessage() =>
      ShortFormVideoDownloadReply._();
  @$core.override
  ShortFormVideoDownloadReply createEmptyInstance() =>
      ShortFormVideoDownloadReply._();
  @$core.pragma('dart2js:noInline')
  static ShortFormVideoDownloadReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShortFormVideoDownloadReply>(
          ShortFormVideoDownloadReply.$_createMessage);
  static ShortFormVideoDownloadReply? _defaultInstance;

  /// 是否有下载分享按钮
  @$pb.TagNumber(1)
  $core.bool get hasDownloadUrl => $_getBF(0);
  @$pb.TagNumber(1)
  set hasDownloadUrl($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHasDownloadUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearHasDownloadUrl() => $_clearField(1);

  /// 下载url
  @$pb.TagNumber(2)
  $core.String get downloadUrl_2 => $_getSZ(1);
  @$pb.TagNumber(2)
  set downloadUrl_2($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDownloadUrl_2() => $_has(1);
  @$pb.TagNumber(2)
  void clearDownloadUrl_2() => $_clearField(2);

  /// 文件md5
  @$pb.TagNumber(3)
  $core.String get md5 => $_getSZ(2);
  @$pb.TagNumber(3)
  set md5($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMd5() => $_has(2);
  @$pb.TagNumber(3)
  void clearMd5() => $_clearField(3);

  /// 文件大小(单位为Byte)
  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get backupDownloadUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set backupDownloadUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBackupDownloadUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearBackupDownloadUrl() => $_clearField(5);
}

/// 短视频下载-请求
class ShortFormVideoDownloadReq extends $pb.GeneratedMessage {
  factory ShortFormVideoDownloadReq({
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $fixnum.Int64? mid,
    $core.String? buvid,
    $core.String? mobiApp,
    $fixnum.Int64? build,
    $core.String? device,
    $core.String? platform,
    $core.String? spmid,
    Restriction? restriction,
    $core.String? tfIsp,
  }) {
    final result = ShortFormVideoDownloadReq._();
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (mid != null) result.mid = mid;
    if (buvid != null) result.buvid = buvid;
    if (mobiApp != null) result.mobiApp = mobiApp;
    if (build != null) result.build = build;
    if (device != null) result.device = device;
    if (platform != null) result.platform = platform;
    if (spmid != null) result.spmid = spmid;
    if (restriction != null) result.restriction = restriction;
    if (tfIsp != null) result.tfIsp = tfIsp;
    return result;
  }

  ShortFormVideoDownloadReq._();

  factory ShortFormVideoDownloadReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShortFormVideoDownloadReq()..mergeFromBuffer(data, registry);
  factory ShortFormVideoDownloadReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShortFormVideoDownloadReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShortFormVideoDownloadReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ShortFormVideoDownloadReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aInt64(2, _omitFieldNames ? '' : 'cid')
    ..aInt64(3, _omitFieldNames ? '' : 'mid')
    ..aOS(4, _omitFieldNames ? '' : 'buvid')
    ..aOS(5, _omitFieldNames ? '' : 'mobiApp')
    ..aInt64(6, _omitFieldNames ? '' : 'build')
    ..aOS(7, _omitFieldNames ? '' : 'device')
    ..aOS(8, _omitFieldNames ? '' : 'platform')
    ..aOS(9, _omitFieldNames ? '' : 'spmid')
    ..aOM<Restriction>(10, _omitFieldNames ? '' : 'restriction',
        subBuilder: Restriction.$_createMessage)
    ..aOS(11, _omitFieldNames ? '' : 'tfIsp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShortFormVideoDownloadReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShortFormVideoDownloadReq copyWith(
          void Function(ShortFormVideoDownloadReq) updates) =>
      super.copyWith((message) => updates(message as ShortFormVideoDownloadReq))
          as ShortFormVideoDownloadReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ShortFormVideoDownloadReq() / ShortFormVideoDownloadReq.new instead')
  static ShortFormVideoDownloadReq create() => ShortFormVideoDownloadReq._();
  static $pb.GeneratedMessage $_createMessage() =>
      ShortFormVideoDownloadReq._();
  @$core.override
  ShortFormVideoDownloadReq createEmptyInstance() =>
      ShortFormVideoDownloadReq._();
  @$core.pragma('dart2js:noInline')
  static ShortFormVideoDownloadReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShortFormVideoDownloadReq>(
          ShortFormVideoDownloadReq.$_createMessage);
  static ShortFormVideoDownloadReq? _defaultInstance;

  /// 稿件avid
  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  /// 视频cid
  @$pb.TagNumber(2)
  $fixnum.Int64 get cid => $_getI64(1);
  @$pb.TagNumber(2)
  set cid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => $_clearField(2);

  /// 用户mid
  @$pb.TagNumber(3)
  $fixnum.Int64 get mid => $_getI64(2);
  @$pb.TagNumber(3)
  set mid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMid() => $_has(2);
  @$pb.TagNumber(3)
  void clearMid() => $_clearField(3);

  /// 设备buvid
  @$pb.TagNumber(4)
  $core.String get buvid => $_getSZ(3);
  @$pb.TagNumber(4)
  set buvid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBuvid() => $_has(3);
  @$pb.TagNumber(4)
  void clearBuvid() => $_clearField(4);

  /// 移动端包类型
  @$pb.TagNumber(5)
  $core.String get mobiApp => $_getSZ(4);
  @$pb.TagNumber(5)
  set mobiApp($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMobiApp() => $_has(4);
  @$pb.TagNumber(5)
  void clearMobiApp() => $_clearField(5);

  /// 移动端版本号
  @$pb.TagNumber(6)
  $fixnum.Int64 get build => $_getI64(5);
  @$pb.TagNumber(6)
  set build($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBuild() => $_has(5);
  @$pb.TagNumber(6)
  void clearBuild() => $_clearField(6);

  /// 运行设备
  @$pb.TagNumber(7)
  $core.String get device => $_getSZ(6);
  @$pb.TagNumber(7)
  set device($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDevice() => $_has(6);
  @$pb.TagNumber(7)
  void clearDevice() => $_clearField(7);

  /// 平台
  @$pb.TagNumber(8)
  $core.String get platform => $_getSZ(7);
  @$pb.TagNumber(8)
  set platform($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPlatform() => $_has(7);
  @$pb.TagNumber(8)
  void clearPlatform() => $_clearField(8);

  /// 当前页面spm
  @$pb.TagNumber(9)
  $core.String get spmid => $_getSZ(8);
  @$pb.TagNumber(9)
  set spmid($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSpmid() => $_has(8);
  @$pb.TagNumber(9)
  void clearSpmid() => $_clearField(9);

  @$pb.TagNumber(10)
  Restriction get restriction => $_getN(9);
  @$pb.TagNumber(10)
  set restriction(Restriction value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasRestriction() => $_has(9);
  @$pb.TagNumber(10)
  void clearRestriction() => $_clearField(10);
  @$pb.TagNumber(10)
  Restriction ensureRestriction() => $_ensure(9);

  @$pb.TagNumber(11)
  $core.String get tfIsp => $_getSZ(10);
  @$pb.TagNumber(11)
  set tfIsp($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTfIsp() => $_has(10);
  @$pb.TagNumber(11)
  void clearTfIsp() => $_clearField(11);
}

class SpecialCell extends $pb.GeneratedMessage {
  factory SpecialCell({
    $core.String? icon,
    $core.String? iconNight,
    $core.String? text,
    $core.String? textColor,
    $core.String? textColorNight,
    $core.String? jumpUrl,
    $core.String? cellType,
    $core.String? cellBgcolor,
    $core.String? cellBgcolorNight,
    $core.String? param,
    $core.String? pageTitle,
    $core.String? jumpType,
    $core.String? endIcon,
    $core.String? endIconNight,
    $fixnum.Int64? notesCount,
  }) {
    final result = SpecialCell._();
    if (icon != null) result.icon = icon;
    if (iconNight != null) result.iconNight = iconNight;
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (textColorNight != null) result.textColorNight = textColorNight;
    if (jumpUrl != null) result.jumpUrl = jumpUrl;
    if (cellType != null) result.cellType = cellType;
    if (cellBgcolor != null) result.cellBgcolor = cellBgcolor;
    if (cellBgcolorNight != null) result.cellBgcolorNight = cellBgcolorNight;
    if (param != null) result.param = param;
    if (pageTitle != null) result.pageTitle = pageTitle;
    if (jumpType != null) result.jumpType = jumpType;
    if (endIcon != null) result.endIcon = endIcon;
    if (endIconNight != null) result.endIconNight = endIconNight;
    if (notesCount != null) result.notesCount = notesCount;
    return result;
  }

  SpecialCell._();

  factory SpecialCell.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SpecialCell()..mergeFromBuffer(data, registry);
  factory SpecialCell.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SpecialCell()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SpecialCell',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: SpecialCell.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'icon')
    ..aOS(2, _omitFieldNames ? '' : 'iconNight')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOS(4, _omitFieldNames ? '' : 'textColor')
    ..aOS(5, _omitFieldNames ? '' : 'textColorNight')
    ..aOS(6, _omitFieldNames ? '' : 'jumpUrl')
    ..aOS(7, _omitFieldNames ? '' : 'cellType')
    ..aOS(8, _omitFieldNames ? '' : 'cellBgcolor')
    ..aOS(9, _omitFieldNames ? '' : 'cellBgcolorNight')
    ..aOS(10, _omitFieldNames ? '' : 'param')
    ..aOS(11, _omitFieldNames ? '' : 'pageTitle')
    ..aOS(12, _omitFieldNames ? '' : 'jumpType')
    ..aOS(13, _omitFieldNames ? '' : 'endIcon')
    ..aOS(14, _omitFieldNames ? '' : 'endIconNight')
    ..aInt64(15, _omitFieldNames ? '' : 'notesCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SpecialCell clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SpecialCell copyWith(void Function(SpecialCell) updates) =>
      super.copyWith((message) => updates(message as SpecialCell))
          as SpecialCell;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SpecialCell() / SpecialCell.new instead')
  static SpecialCell create() => SpecialCell._();
  static $pb.GeneratedMessage $_createMessage() => SpecialCell._();
  @$core.override
  SpecialCell createEmptyInstance() => SpecialCell._();
  @$core.pragma('dart2js:noInline')
  static SpecialCell getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpecialCell>(
          SpecialCell.$_createMessage);
  static SpecialCell? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get icon => $_getSZ(0);
  @$pb.TagNumber(1)
  set icon($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIcon() => $_has(0);
  @$pb.TagNumber(1)
  void clearIcon() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get iconNight => $_getSZ(1);
  @$pb.TagNumber(2)
  set iconNight($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconNight() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconNight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get textColor => $_getSZ(3);
  @$pb.TagNumber(4)
  set textColor($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTextColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearTextColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get textColorNight => $_getSZ(4);
  @$pb.TagNumber(5)
  set textColorNight($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTextColorNight() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextColorNight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get jumpUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set jumpUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasJumpUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearJumpUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get cellType => $_getSZ(6);
  @$pb.TagNumber(7)
  set cellType($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCellType() => $_has(6);
  @$pb.TagNumber(7)
  void clearCellType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get cellBgcolor => $_getSZ(7);
  @$pb.TagNumber(8)
  set cellBgcolor($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCellBgcolor() => $_has(7);
  @$pb.TagNumber(8)
  void clearCellBgcolor() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get cellBgcolorNight => $_getSZ(8);
  @$pb.TagNumber(9)
  set cellBgcolorNight($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCellBgcolorNight() => $_has(8);
  @$pb.TagNumber(9)
  void clearCellBgcolorNight() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get param => $_getSZ(9);
  @$pb.TagNumber(10)
  set param($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasParam() => $_has(9);
  @$pb.TagNumber(10)
  void clearParam() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get pageTitle => $_getSZ(10);
  @$pb.TagNumber(11)
  set pageTitle($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPageTitle() => $_has(10);
  @$pb.TagNumber(11)
  void clearPageTitle() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get jumpType => $_getSZ(11);
  @$pb.TagNumber(12)
  set jumpType($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasJumpType() => $_has(11);
  @$pb.TagNumber(12)
  void clearJumpType() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get endIcon => $_getSZ(12);
  @$pb.TagNumber(13)
  set endIcon($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasEndIcon() => $_has(12);
  @$pb.TagNumber(13)
  void clearEndIcon() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get endIconNight => $_getSZ(13);
  @$pb.TagNumber(14)
  set endIconNight($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEndIconNight() => $_has(13);
  @$pb.TagNumber(14)
  void clearEndIconNight() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get notesCount => $_getI64(14);
  @$pb.TagNumber(15)
  set notesCount($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasNotesCount() => $_has(14);
  @$pb.TagNumber(15)
  void clearNotesCount() => $_clearField(15);
}

/// 合作成员信息
class Staff extends $pb.GeneratedMessage {
  factory Staff({
    $fixnum.Int64? mid,
    $core.String? title,
    $core.String? face,
    $core.String? name,
    OfficialVerify? officialVerify,
    Vip? vip,
    $core.int? attention,
    $core.int? labelStyle,
  }) {
    final result = Staff._();
    if (mid != null) result.mid = mid;
    if (title != null) result.title = title;
    if (face != null) result.face = face;
    if (name != null) result.name = name;
    if (officialVerify != null) result.officialVerify = officialVerify;
    if (vip != null) result.vip = vip;
    if (attention != null) result.attention = attention;
    if (labelStyle != null) result.labelStyle = labelStyle;
    return result;
  }

  Staff._();

  factory Staff.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Staff()..mergeFromBuffer(data, registry);
  factory Staff.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Staff()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Staff',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Staff.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'mid')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'face')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOM<OfficialVerify>(5, _omitFieldNames ? '' : 'officialVerify',
        subBuilder: OfficialVerify.$_createMessage)
    ..aOM<Vip>(6, _omitFieldNames ? '' : 'vip', subBuilder: Vip.$_createMessage)
    ..aI(7, _omitFieldNames ? '' : 'attention')
    ..aI(8, _omitFieldNames ? '' : 'labelStyle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Staff clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Staff copyWith(void Function(Staff) updates) =>
      super.copyWith((message) => updates(message as Staff)) as Staff;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Staff() / Staff.new instead')
  static Staff create() => Staff._();
  static $pb.GeneratedMessage $_createMessage() => Staff._();
  @$core.override
  Staff createEmptyInstance() => Staff._();
  @$core.pragma('dart2js:noInline')
  static Staff getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Staff>(Staff.$_createMessage);
  static Staff? _defaultInstance;

  /// 成员mid
  @$pb.TagNumber(1)
  $fixnum.Int64 get mid => $_getI64(0);
  @$pb.TagNumber(1)
  set mid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMid() => $_has(0);
  @$pb.TagNumber(1)
  void clearMid() => $_clearField(1);

  /// 成员角色
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// 成员头像url
  @$pb.TagNumber(3)
  $core.String get face => $_getSZ(2);
  @$pb.TagNumber(3)
  set face($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFace() => $_has(2);
  @$pb.TagNumber(3)
  void clearFace() => $_clearField(3);

  /// 成员昵称
  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  /// 成员官方信息
  @$pb.TagNumber(5)
  OfficialVerify get officialVerify => $_getN(4);
  @$pb.TagNumber(5)
  set officialVerify(OfficialVerify value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasOfficialVerify() => $_has(4);
  @$pb.TagNumber(5)
  void clearOfficialVerify() => $_clearField(5);
  @$pb.TagNumber(5)
  OfficialVerify ensureOfficialVerify() => $_ensure(4);

  /// 成员会员信息
  @$pb.TagNumber(6)
  Vip get vip => $_getN(5);
  @$pb.TagNumber(6)
  set vip(Vip value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasVip() => $_has(5);
  @$pb.TagNumber(6)
  void clearVip() => $_clearField(6);
  @$pb.TagNumber(6)
  Vip ensureVip() => $_ensure(5);

  /// 是否关注该成员
  @$pb.TagNumber(7)
  $core.int get attention => $_getIZ(6);
  @$pb.TagNumber(7)
  set attention($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAttention() => $_has(6);
  @$pb.TagNumber(7)
  void clearAttention() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get labelStyle => $_getIZ(7);
  @$pb.TagNumber(8)
  set labelStyle($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLabelStyle() => $_has(7);
  @$pb.TagNumber(8)
  void clearLabelStyle() => $_clearField(8);
}

/// 标准卡
class StandardCard extends $pb.GeneratedMessage {
  factory StandardCard({
    $core.String? title,
    $core.String? buttonTitle,
    $core.String? buttonSelectedTitle,
    $core.bool? showSelected,
  }) {
    final result = StandardCard._();
    if (title != null) result.title = title;
    if (buttonTitle != null) result.buttonTitle = buttonTitle;
    if (buttonSelectedTitle != null)
      result.buttonSelectedTitle = buttonSelectedTitle;
    if (showSelected != null) result.showSelected = showSelected;
    return result;
  }

  StandardCard._();

  factory StandardCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StandardCard()..mergeFromBuffer(data, registry);
  factory StandardCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StandardCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StandardCard',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: StandardCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'buttonTitle')
    ..aOS(3, _omitFieldNames ? '' : 'buttonSelectedTitle')
    ..aOB(4, _omitFieldNames ? '' : 'showSelected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StandardCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StandardCard copyWith(void Function(StandardCard) updates) =>
      super.copyWith((message) => updates(message as StandardCard))
          as StandardCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StandardCard() / StandardCard.new instead')
  static StandardCard create() => StandardCard._();
  static $pb.GeneratedMessage $_createMessage() => StandardCard._();
  @$core.override
  StandardCard createEmptyInstance() => StandardCard._();
  @$core.pragma('dart2js:noInline')
  static StandardCard getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StandardCard>(
          StandardCard.$_createMessage);
  static StandardCard? _defaultInstance;

  /// 卡片文案
  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// 按钮文字 未操作
  @$pb.TagNumber(2)
  $core.String get buttonTitle => $_getSZ(1);
  @$pb.TagNumber(2)
  set buttonTitle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasButtonTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearButtonTitle() => $_clearField(2);

  /// 按钮文字 已操作
  @$pb.TagNumber(3)
  $core.String get buttonSelectedTitle => $_getSZ(2);
  @$pb.TagNumber(3)
  set buttonSelectedTitle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasButtonSelectedTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearButtonSelectedTitle() => $_clearField(3);

  /// 已操作态是否显示
  @$pb.TagNumber(4)
  $core.bool get showSelected => $_getBF(3);
  @$pb.TagNumber(4)
  set showSelected($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShowSelected() => $_has(3);
  @$pb.TagNumber(4)
  void clearShowSelected() => $_clearField(4);
}

/// 免流子面板定制化配置
class subTFPanel extends $pb.GeneratedMessage {
  factory subTFPanel({
    $core.String? rightBtnImg,
    $core.String? rightBtnText,
    $core.String? rightBtnTextColor,
    $core.String? rightBtnLink,
    $core.String? mainLabel,
    $core.String? operator,
  }) {
    final result = subTFPanel._();
    if (rightBtnImg != null) result.rightBtnImg = rightBtnImg;
    if (rightBtnText != null) result.rightBtnText = rightBtnText;
    if (rightBtnTextColor != null) result.rightBtnTextColor = rightBtnTextColor;
    if (rightBtnLink != null) result.rightBtnLink = rightBtnLink;
    if (mainLabel != null) result.mainLabel = mainLabel;
    if (operator != null) result.operator = operator;
    return result;
  }

  subTFPanel._();

  factory subTFPanel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      subTFPanel()..mergeFromBuffer(data, registry);
  factory subTFPanel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      subTFPanel()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'subTFPanel',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: subTFPanel.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'rightBtnImg')
    ..aOS(2, _omitFieldNames ? '' : 'rightBtnText')
    ..aOS(3, _omitFieldNames ? '' : 'rightBtnTextColor')
    ..aOS(4, _omitFieldNames ? '' : 'rightBtnLink')
    ..aOS(5, _omitFieldNames ? '' : 'mainLabel')
    ..aOS(6, _omitFieldNames ? '' : 'operator')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  subTFPanel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  subTFPanel copyWith(void Function(subTFPanel) updates) =>
      super.copyWith((message) => updates(message as subTFPanel)) as subTFPanel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use subTFPanel() / subTFPanel.new instead')
  static subTFPanel create() => subTFPanel._();
  static $pb.GeneratedMessage $_createMessage() => subTFPanel._();
  @$core.override
  subTFPanel createEmptyInstance() => subTFPanel._();
  @$core.pragma('dart2js:noInline')
  static subTFPanel getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<subTFPanel>(subTFPanel.$_createMessage);
  static subTFPanel? _defaultInstance;

  /// 右侧按钮素材
  @$pb.TagNumber(1)
  $core.String get rightBtnImg => $_getSZ(0);
  @$pb.TagNumber(1)
  set rightBtnImg($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRightBtnImg() => $_has(0);
  @$pb.TagNumber(1)
  void clearRightBtnImg() => $_clearField(1);

  /// 右侧按钮文案
  @$pb.TagNumber(2)
  $core.String get rightBtnText => $_getSZ(1);
  @$pb.TagNumber(2)
  set rightBtnText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRightBtnText() => $_has(1);
  @$pb.TagNumber(2)
  void clearRightBtnText() => $_clearField(2);

  /// 右侧按钮字体颜色
  @$pb.TagNumber(3)
  $core.String get rightBtnTextColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set rightBtnTextColor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRightBtnTextColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearRightBtnTextColor() => $_clearField(3);

  /// 右侧按钮跳转链接
  @$pb.TagNumber(4)
  $core.String get rightBtnLink => $_getSZ(3);
  @$pb.TagNumber(4)
  set rightBtnLink($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRightBtnLink() => $_has(3);
  @$pb.TagNumber(4)
  void clearRightBtnLink() => $_clearField(4);

  /// 中心主文案内容
  @$pb.TagNumber(5)
  $core.String get mainLabel => $_getSZ(4);
  @$pb.TagNumber(5)
  set mainLabel($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMainLabel() => $_has(4);
  @$pb.TagNumber(5)
  void clearMainLabel() => $_clearField(5);

  /// 运营商
  @$pb.TagNumber(6)
  $core.String get operator => $_getSZ(5);
  @$pb.TagNumber(6)
  set operator($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOperator() => $_has(5);
  @$pb.TagNumber(6)
  void clearOperator() => $_clearField(6);
}

/// TAB
class Tab extends $pb.GeneratedMessage {
  factory Tab({
    $core.String? background,
    TabOtype? otype,
    $fixnum.Int64? oid,
    $core.String? uri,
    TabStyle? style,
    $core.String? text,
    $core.String? textColor,
    $core.String? textColorSelected,
    $core.String? pic,
    $fixnum.Int64? id,
    $2.Any? adTabInfo,
  }) {
    final result = Tab._();
    if (background != null) result.background = background;
    if (otype != null) result.otype = otype;
    if (oid != null) result.oid = oid;
    if (uri != null) result.uri = uri;
    if (style != null) result.style = style;
    if (text != null) result.text = text;
    if (textColor != null) result.textColor = textColor;
    if (textColorSelected != null) result.textColorSelected = textColorSelected;
    if (pic != null) result.pic = pic;
    if (id != null) result.id = id;
    if (adTabInfo != null) result.adTabInfo = adTabInfo;
    return result;
  }

  Tab._();

  factory Tab.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Tab()..mergeFromBuffer(data, registry);
  factory Tab.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Tab()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Tab',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Tab.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'background')
    ..aE<TabOtype>(2, _omitFieldNames ? '' : 'otype',
        enumValues: TabOtype.values)
    ..aInt64(3, _omitFieldNames ? '' : 'oid')
    ..aOS(4, _omitFieldNames ? '' : 'uri')
    ..aE<TabStyle>(5, _omitFieldNames ? '' : 'style',
        enumValues: TabStyle.values)
    ..aOS(6, _omitFieldNames ? '' : 'text')
    ..aOS(7, _omitFieldNames ? '' : 'textColor')
    ..aOS(8, _omitFieldNames ? '' : 'textColorSelected')
    ..aOS(9, _omitFieldNames ? '' : 'pic')
    ..aInt64(10, _omitFieldNames ? '' : 'id')
    ..aOM<$2.Any>(11, _omitFieldNames ? '' : 'adTabInfo',
        subBuilder: $2.Any.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tab clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tab copyWith(void Function(Tab) updates) =>
      super.copyWith((message) => updates(message as Tab)) as Tab;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Tab() / Tab.new instead')
  static Tab create() => Tab._();
  static $pb.GeneratedMessage $_createMessage() => Tab._();
  @$core.override
  Tab createEmptyInstance() => Tab._();
  @$core.pragma('dart2js:noInline')
  static Tab getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Tab>(Tab.$_createMessage);
  static Tab? _defaultInstance;

  /// 背景图片
  @$pb.TagNumber(1)
  $core.String get background => $_getSZ(0);
  @$pb.TagNumber(1)
  set background($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackground() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackground() => $_clearField(1);

  /// 跳转类型
  @$pb.TagNumber(2)
  TabOtype get otype => $_getN(1);
  @$pb.TagNumber(2)
  set otype(TabOtype value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOtype() => $_has(1);
  @$pb.TagNumber(2)
  void clearOtype() => $_clearField(2);

  /// 类型id
  @$pb.TagNumber(3)
  $fixnum.Int64 get oid => $_getI64(2);
  @$pb.TagNumber(3)
  set oid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOid() => $_has(2);
  @$pb.TagNumber(3)
  void clearOid() => $_clearField(3);

  /// 跳转url
  @$pb.TagNumber(4)
  $core.String get uri => $_getSZ(3);
  @$pb.TagNumber(4)
  set uri($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUri() => $_has(3);
  @$pb.TagNumber(4)
  void clearUri() => $_clearField(4);

  /// 样式
  @$pb.TagNumber(5)
  TabStyle get style => $_getN(4);
  @$pb.TagNumber(5)
  set style(TabStyle value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStyle() => $_has(4);
  @$pb.TagNumber(5)
  void clearStyle() => $_clearField(5);

  /// 文字
  @$pb.TagNumber(6)
  $core.String get text => $_getSZ(5);
  @$pb.TagNumber(6)
  set text($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasText() => $_has(5);
  @$pb.TagNumber(6)
  void clearText() => $_clearField(6);

  /// 未选中态字色
  @$pb.TagNumber(7)
  $core.String get textColor => $_getSZ(6);
  @$pb.TagNumber(7)
  set textColor($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTextColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearTextColor() => $_clearField(7);

  /// 选中态字色
  @$pb.TagNumber(8)
  $core.String get textColorSelected => $_getSZ(7);
  @$pb.TagNumber(8)
  set textColorSelected($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTextColorSelected() => $_has(7);
  @$pb.TagNumber(8)
  void clearTextColorSelected() => $_clearField(8);

  /// 图片
  @$pb.TagNumber(9)
  $core.String get pic => $_getSZ(8);
  @$pb.TagNumber(9)
  set pic($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPic() => $_has(8);
  @$pb.TagNumber(9)
  void clearPic() => $_clearField(9);

  /// 后台配置自增
  @$pb.TagNumber(10)
  $fixnum.Int64 get id => $_getI64(9);
  @$pb.TagNumber(10)
  set id($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasId() => $_has(9);
  @$pb.TagNumber(10)
  void clearId() => $_clearField(10);

  @$pb.TagNumber(11)
  $2.Any get adTabInfo => $_getN(10);
  @$pb.TagNumber(11)
  set adTabInfo($2.Any value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasAdTabInfo() => $_has(10);
  @$pb.TagNumber(11)
  void clearAdTabInfo() => $_clearField(11);
  @$pb.TagNumber(11)
  $2.Any ensureAdTabInfo() => $_ensure(10);
}

/// TAG信息
class Tag extends $pb.GeneratedMessage {
  factory Tag({
    $fixnum.Int64? id,
    $core.String? name,
    $fixnum.Int64? likes,
    $fixnum.Int64? hates,
    $core.int? liked,
    $core.int? hated,
    $core.String? uri,
    $core.String? tagType,
  }) {
    final result = Tag._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (likes != null) result.likes = likes;
    if (hates != null) result.hates = hates;
    if (liked != null) result.liked = liked;
    if (hated != null) result.hated = hated;
    if (uri != null) result.uri = uri;
    if (tagType != null) result.tagType = tagType;
    return result;
  }

  Tag._();

  factory Tag.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Tag()..mergeFromBuffer(data, registry);
  factory Tag.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Tag()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Tag',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Tag.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'likes')
    ..aInt64(4, _omitFieldNames ? '' : 'hates')
    ..aI(5, _omitFieldNames ? '' : 'liked')
    ..aI(6, _omitFieldNames ? '' : 'hated')
    ..aOS(7, _omitFieldNames ? '' : 'uri')
    ..aOS(8, _omitFieldNames ? '' : 'tagType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tag clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Tag copyWith(void Function(Tag) updates) =>
      super.copyWith((message) => updates(message as Tag)) as Tag;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Tag() / Tag.new instead')
  static Tag create() => Tag._();
  static $pb.GeneratedMessage $_createMessage() => Tag._();
  @$core.override
  Tag createEmptyInstance() => Tag._();
  @$core.pragma('dart2js:noInline')
  static Tag getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Tag>(Tag.$_createMessage);
  static Tag? _defaultInstance;

  /// TAD id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// TAG名
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get likes => $_getI64(2);
  @$pb.TagNumber(3)
  set likes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLikes() => $_has(2);
  @$pb.TagNumber(3)
  void clearLikes() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get hates => $_getI64(3);
  @$pb.TagNumber(4)
  set hates($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHates() => $_has(3);
  @$pb.TagNumber(4)
  void clearHates() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get liked => $_getIZ(4);
  @$pb.TagNumber(5)
  set liked($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLiked() => $_has(4);
  @$pb.TagNumber(5)
  void clearLiked() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get hated => $_getIZ(5);
  @$pb.TagNumber(6)
  set hated($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHated() => $_has(5);
  @$pb.TagNumber(6)
  void clearHated() => $_clearField(6);

  /// TAG页面uri
  @$pb.TagNumber(7)
  $core.String get uri => $_getSZ(6);
  @$pb.TagNumber(7)
  set uri($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUri() => $_has(6);
  @$pb.TagNumber(7)
  void clearUri() => $_clearField(7);

  /// TAG类型
  /// common:普通 new:话题 act:活动
  @$pb.TagNumber(8)
  $core.String get tagType => $_getSZ(7);
  @$pb.TagNumber(8)
  set tagType($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTagType() => $_has(7);
  @$pb.TagNumber(8)
  void clearTagType() => $_clearField(8);
}

/// 免流面板定制
class TFPanelCustomized extends $pb.GeneratedMessage {
  factory TFPanelCustomized({
    $core.String? rightBtnImg,
    $core.String? rightBtnText,
    $core.String? rightBtnTextColor,
    $core.String? rightBtnLink,
    $core.String? mainLabel,
    $core.String? operator,
    $core.Iterable<$core.MapEntry<$core.String, subTFPanel>>? subPanel,
  }) {
    final result = TFPanelCustomized._();
    if (rightBtnImg != null) result.rightBtnImg = rightBtnImg;
    if (rightBtnText != null) result.rightBtnText = rightBtnText;
    if (rightBtnTextColor != null) result.rightBtnTextColor = rightBtnTextColor;
    if (rightBtnLink != null) result.rightBtnLink = rightBtnLink;
    if (mainLabel != null) result.mainLabel = mainLabel;
    if (operator != null) result.operator = operator;
    if (subPanel != null) result.subPanel.addEntries(subPanel);
    return result;
  }

  TFPanelCustomized._();

  factory TFPanelCustomized.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TFPanelCustomized()..mergeFromBuffer(data, registry);
  factory TFPanelCustomized.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TFPanelCustomized()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TFPanelCustomized',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: TFPanelCustomized.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'rightBtnImg')
    ..aOS(2, _omitFieldNames ? '' : 'rightBtnText')
    ..aOS(3, _omitFieldNames ? '' : 'rightBtnTextColor')
    ..aOS(4, _omitFieldNames ? '' : 'rightBtnLink')
    ..aOS(5, _omitFieldNames ? '' : 'mainLabel')
    ..aOS(6, _omitFieldNames ? '' : 'operator')
    ..m<$core.String, subTFPanel>(7, _omitFieldNames ? '' : 'subPanel',
        entryClassName: 'TFPanelCustomized.SubPanelEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: subTFPanel.$_createMessage,
        valueDefaultOrMaker: subTFPanel.getDefault,
        packageName: const $pb.PackageName('bilibili.app.view.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TFPanelCustomized clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TFPanelCustomized copyWith(void Function(TFPanelCustomized) updates) =>
      super.copyWith((message) => updates(message as TFPanelCustomized))
          as TFPanelCustomized;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TFPanelCustomized() / TFPanelCustomized.new instead')
  static TFPanelCustomized create() => TFPanelCustomized._();
  static $pb.GeneratedMessage $_createMessage() => TFPanelCustomized._();
  @$core.override
  TFPanelCustomized createEmptyInstance() => TFPanelCustomized._();
  @$core.pragma('dart2js:noInline')
  static TFPanelCustomized getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TFPanelCustomized>(
          TFPanelCustomized.$_createMessage);
  static TFPanelCustomized? _defaultInstance;

  /// 右侧按钮素材
  @$pb.TagNumber(1)
  $core.String get rightBtnImg => $_getSZ(0);
  @$pb.TagNumber(1)
  set rightBtnImg($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRightBtnImg() => $_has(0);
  @$pb.TagNumber(1)
  void clearRightBtnImg() => $_clearField(1);

  /// 右侧按钮文案
  @$pb.TagNumber(2)
  $core.String get rightBtnText => $_getSZ(1);
  @$pb.TagNumber(2)
  set rightBtnText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRightBtnText() => $_has(1);
  @$pb.TagNumber(2)
  void clearRightBtnText() => $_clearField(2);

  /// 右侧按钮字体颜色
  @$pb.TagNumber(3)
  $core.String get rightBtnTextColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set rightBtnTextColor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRightBtnTextColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearRightBtnTextColor() => $_clearField(3);

  /// 右侧按钮跳转链接
  @$pb.TagNumber(4)
  $core.String get rightBtnLink => $_getSZ(3);
  @$pb.TagNumber(4)
  set rightBtnLink($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRightBtnLink() => $_has(3);
  @$pb.TagNumber(4)
  void clearRightBtnLink() => $_clearField(4);

  /// 中心主文案内容
  @$pb.TagNumber(5)
  $core.String get mainLabel => $_getSZ(4);
  @$pb.TagNumber(5)
  set mainLabel($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMainLabel() => $_has(4);
  @$pb.TagNumber(5)
  void clearMainLabel() => $_clearField(5);

  /// 运营商(cm ct cu)
  @$pb.TagNumber(6)
  $core.String get operator => $_getSZ(5);
  @$pb.TagNumber(6)
  set operator($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOperator() => $_has(5);
  @$pb.TagNumber(6)
  void clearOperator() => $_clearField(6);

  /// 子面板定制化配置
  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, subTFPanel> get subPanel => $_getMap(6);
}

/// TAG图标信息
class TIcon extends $pb.GeneratedMessage {
  factory TIcon({
    $core.String? icon,
  }) {
    final result = TIcon._();
    if (icon != null) result.icon = icon;
    return result;
  }

  TIcon._();

  factory TIcon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TIcon()..mergeFromBuffer(data, registry);
  factory TIcon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TIcon()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TIcon',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: TIcon.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'icon')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TIcon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TIcon copyWith(void Function(TIcon) updates) =>
      super.copyWith((message) => updates(message as TIcon)) as TIcon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TIcon() / TIcon.new instead')
  static TIcon create() => TIcon._();
  static $pb.GeneratedMessage $_createMessage() => TIcon._();
  @$core.override
  TIcon createEmptyInstance() => TIcon._();
  @$core.pragma('dart2js:noInline')
  static TIcon getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TIcon>(TIcon.$_createMessage);
  static TIcon? _defaultInstance;

  /// TAG图标url
  @$pb.TagNumber(1)
  $core.String get icon => $_getSZ(0);
  @$pb.TagNumber(1)
  set icon($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIcon() => $_has(0);
  @$pb.TagNumber(1)
  void clearIcon() => $_clearField(1);
}

/// UGC视频合集信息
class UgcSeason extends $pb.GeneratedMessage {
  factory UgcSeason({
    $fixnum.Int64? id,
    $core.String? title,
    $core.String? cover,
    $core.String? intro,
    $core.Iterable<Section>? sections,
    UgcSeasonStat? stat,
    $core.String? labelText,
    $core.String? labelTextColor,
    $core.String? labelBgColor,
    $core.String? labelTextNightColor,
    $core.String? labelBgNightColor,
    $core.String? descRight,
    $fixnum.Int64? epCount,
    SeasonType? seasonType,
    $core.bool? showContinualButton,
    $fixnum.Int64? epNum,
    $core.bool? seasonPay,
    GoodsInfo? goodsInfo,
    ButtonStyle? payButton,
    $core.String? labelTextNew,
    UgcSeasonActivity? activity,
    $core.Iterable<$core.String>? seasonAbility,
  }) {
    final result = UgcSeason._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (cover != null) result.cover = cover;
    if (intro != null) result.intro = intro;
    if (sections != null) result.sections.addAll(sections);
    if (stat != null) result.stat = stat;
    if (labelText != null) result.labelText = labelText;
    if (labelTextColor != null) result.labelTextColor = labelTextColor;
    if (labelBgColor != null) result.labelBgColor = labelBgColor;
    if (labelTextNightColor != null)
      result.labelTextNightColor = labelTextNightColor;
    if (labelBgNightColor != null) result.labelBgNightColor = labelBgNightColor;
    if (descRight != null) result.descRight = descRight;
    if (epCount != null) result.epCount = epCount;
    if (seasonType != null) result.seasonType = seasonType;
    if (showContinualButton != null)
      result.showContinualButton = showContinualButton;
    if (epNum != null) result.epNum = epNum;
    if (seasonPay != null) result.seasonPay = seasonPay;
    if (goodsInfo != null) result.goodsInfo = goodsInfo;
    if (payButton != null) result.payButton = payButton;
    if (labelTextNew != null) result.labelTextNew = labelTextNew;
    if (activity != null) result.activity = activity;
    if (seasonAbility != null) result.seasonAbility.addAll(seasonAbility);
    return result;
  }

  UgcSeason._();

  factory UgcSeason.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UgcSeason()..mergeFromBuffer(data, registry);
  factory UgcSeason.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UgcSeason()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UgcSeason',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UgcSeason.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'cover')
    ..aOS(4, _omitFieldNames ? '' : 'intro')
    ..pPM<Section>(5, _omitFieldNames ? '' : 'sections',
        subBuilder: Section.$_createMessage)
    ..aOM<UgcSeasonStat>(6, _omitFieldNames ? '' : 'stat',
        subBuilder: UgcSeasonStat.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'labelText')
    ..aOS(8, _omitFieldNames ? '' : 'labelTextColor')
    ..aOS(9, _omitFieldNames ? '' : 'labelBgColor')
    ..aOS(10, _omitFieldNames ? '' : 'labelTextNightColor')
    ..aOS(11, _omitFieldNames ? '' : 'labelBgNightColor')
    ..aOS(12, _omitFieldNames ? '' : 'descRight', protoName: 'descRight')
    ..aInt64(13, _omitFieldNames ? '' : 'epCount')
    ..aE<SeasonType>(14, _omitFieldNames ? '' : 'seasonType',
        enumValues: SeasonType.values)
    ..aOB(15, _omitFieldNames ? '' : 'showContinualButton')
    ..aInt64(16, _omitFieldNames ? '' : 'epNum')
    ..aOB(17, _omitFieldNames ? '' : 'seasonPay')
    ..aOM<GoodsInfo>(18, _omitFieldNames ? '' : 'goodsInfo',
        subBuilder: GoodsInfo.$_createMessage)
    ..aOM<ButtonStyle>(19, _omitFieldNames ? '' : 'payButton',
        subBuilder: ButtonStyle.$_createMessage)
    ..aOS(20, _omitFieldNames ? '' : 'labelTextNew')
    ..aOM<UgcSeasonActivity>(21, _omitFieldNames ? '' : 'activity',
        subBuilder: UgcSeasonActivity.$_createMessage)
    ..pPS(22, _omitFieldNames ? '' : 'seasonAbility')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UgcSeason clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UgcSeason copyWith(void Function(UgcSeason) updates) =>
      super.copyWith((message) => updates(message as UgcSeason)) as UgcSeason;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UgcSeason() / UgcSeason.new instead')
  static UgcSeason create() => UgcSeason._();
  static $pb.GeneratedMessage $_createMessage() => UgcSeason._();
  @$core.override
  UgcSeason createEmptyInstance() => UgcSeason._();
  @$core.pragma('dart2js:noInline')
  static UgcSeason getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UgcSeason>(UgcSeason.$_createMessage);
  static UgcSeason? _defaultInstance;

  /// 合集id
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// 合集标题
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// 合集封面url
  @$pb.TagNumber(3)
  $core.String get cover => $_getSZ(2);
  @$pb.TagNumber(3)
  set cover($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCover() => $_has(2);
  @$pb.TagNumber(3)
  void clearCover() => $_clearField(3);

  /// 合集简介
  @$pb.TagNumber(4)
  $core.String get intro => $_getSZ(3);
  @$pb.TagNumber(4)
  set intro($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIntro() => $_has(3);
  @$pb.TagNumber(4)
  void clearIntro() => $_clearField(4);

  /// 小节列表
  @$pb.TagNumber(5)
  $pb.PbList<Section> get sections => $_getList(4);

  /// 合集状态数
  @$pb.TagNumber(6)
  UgcSeasonStat get stat => $_getN(5);
  @$pb.TagNumber(6)
  set stat(UgcSeasonStat value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStat() => $_has(5);
  @$pb.TagNumber(6)
  void clearStat() => $_clearField(6);
  @$pb.TagNumber(6)
  UgcSeasonStat ensureStat() => $_ensure(5);

  /// 标签字色
  @$pb.TagNumber(7)
  $core.String get labelText => $_getSZ(6);
  @$pb.TagNumber(7)
  set labelText($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLabelText() => $_has(6);
  @$pb.TagNumber(7)
  void clearLabelText() => $_clearField(7);

  /// 标签背景色
  @$pb.TagNumber(8)
  $core.String get labelTextColor => $_getSZ(7);
  @$pb.TagNumber(8)
  set labelTextColor($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLabelTextColor() => $_has(7);
  @$pb.TagNumber(8)
  void clearLabelTextColor() => $_clearField(8);

  /// 标签夜间字色
  @$pb.TagNumber(9)
  $core.String get labelBgColor => $_getSZ(8);
  @$pb.TagNumber(9)
  set labelBgColor($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLabelBgColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearLabelBgColor() => $_clearField(9);

  /// 标签夜间背景色
  @$pb.TagNumber(10)
  $core.String get labelTextNightColor => $_getSZ(9);
  @$pb.TagNumber(10)
  set labelTextNightColor($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLabelTextNightColor() => $_has(9);
  @$pb.TagNumber(10)
  void clearLabelTextNightColor() => $_clearField(10);

  /// 右侧描述文案
  @$pb.TagNumber(11)
  $core.String get labelBgNightColor => $_getSZ(10);
  @$pb.TagNumber(11)
  set labelBgNightColor($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLabelBgNightColor() => $_has(10);
  @$pb.TagNumber(11)
  void clearLabelBgNightColor() => $_clearField(11);

  /// 按钮文案
  @$pb.TagNumber(12)
  $core.String get descRight => $_getSZ(11);
  @$pb.TagNumber(12)
  set descRight($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDescRight() => $_has(11);
  @$pb.TagNumber(12)
  void clearDescRight() => $_clearField(12);

  /// 分集总数
  @$pb.TagNumber(13)
  $fixnum.Int64 get epCount => $_getI64(12);
  @$pb.TagNumber(13)
  set epCount($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasEpCount() => $_has(12);
  @$pb.TagNumber(13)
  void clearEpCount() => $_clearField(13);

  /// 合集类型
  @$pb.TagNumber(14)
  SeasonType get seasonType => $_getN(13);
  @$pb.TagNumber(14)
  set seasonType(SeasonType value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasSeasonType() => $_has(13);
  @$pb.TagNumber(14)
  void clearSeasonType() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get showContinualButton => $_getBF(14);
  @$pb.TagNumber(15)
  set showContinualButton($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasShowContinualButton() => $_has(14);
  @$pb.TagNumber(15)
  void clearShowContinualButton() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get epNum => $_getI64(15);
  @$pb.TagNumber(16)
  set epNum($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasEpNum() => $_has(15);
  @$pb.TagNumber(16)
  void clearEpNum() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get seasonPay => $_getBF(16);
  @$pb.TagNumber(17)
  set seasonPay($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(17)
  $core.bool hasSeasonPay() => $_has(16);
  @$pb.TagNumber(17)
  void clearSeasonPay() => $_clearField(17);

  @$pb.TagNumber(18)
  GoodsInfo get goodsInfo => $_getN(17);
  @$pb.TagNumber(18)
  set goodsInfo(GoodsInfo value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasGoodsInfo() => $_has(17);
  @$pb.TagNumber(18)
  void clearGoodsInfo() => $_clearField(18);
  @$pb.TagNumber(18)
  GoodsInfo ensureGoodsInfo() => $_ensure(17);

  @$pb.TagNumber(19)
  ButtonStyle get payButton => $_getN(18);
  @$pb.TagNumber(19)
  set payButton(ButtonStyle value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasPayButton() => $_has(18);
  @$pb.TagNumber(19)
  void clearPayButton() => $_clearField(19);
  @$pb.TagNumber(19)
  ButtonStyle ensurePayButton() => $_ensure(18);

  @$pb.TagNumber(20)
  $core.String get labelTextNew => $_getSZ(19);
  @$pb.TagNumber(20)
  set labelTextNew($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasLabelTextNew() => $_has(19);
  @$pb.TagNumber(20)
  void clearLabelTextNew() => $_clearField(20);

  @$pb.TagNumber(21)
  UgcSeasonActivity get activity => $_getN(20);
  @$pb.TagNumber(21)
  set activity(UgcSeasonActivity value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasActivity() => $_has(20);
  @$pb.TagNumber(21)
  void clearActivity() => $_clearField(21);
  @$pb.TagNumber(21)
  UgcSeasonActivity ensureActivity() => $_ensure(20);

  @$pb.TagNumber(22)
  $pb.PbList<$core.String> get seasonAbility => $_getList(21);
}

class UgcSeasonActivity extends $pb.GeneratedMessage {
  factory UgcSeasonActivity({
    $core.int? type,
    $fixnum.Int64? oid,
    $fixnum.Int64? activityId,
    $core.String? title,
    $core.String? intro,
    $core.int? dayCount,
    $core.int? userCount,
    $fixnum.Int64? joinDeadline,
    $fixnum.Int64? activityDeadline,
    $core.int? checkinViewTime,
    $core.bool? newActivity,
    UserActivity? userActivity,
    SeasonShow? seasonShow,
  }) {
    final result = UgcSeasonActivity._();
    if (type != null) result.type = type;
    if (oid != null) result.oid = oid;
    if (activityId != null) result.activityId = activityId;
    if (title != null) result.title = title;
    if (intro != null) result.intro = intro;
    if (dayCount != null) result.dayCount = dayCount;
    if (userCount != null) result.userCount = userCount;
    if (joinDeadline != null) result.joinDeadline = joinDeadline;
    if (activityDeadline != null) result.activityDeadline = activityDeadline;
    if (checkinViewTime != null) result.checkinViewTime = checkinViewTime;
    if (newActivity != null) result.newActivity = newActivity;
    if (userActivity != null) result.userActivity = userActivity;
    if (seasonShow != null) result.seasonShow = seasonShow;
    return result;
  }

  UgcSeasonActivity._();

  factory UgcSeasonActivity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UgcSeasonActivity()..mergeFromBuffer(data, registry);
  factory UgcSeasonActivity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UgcSeasonActivity()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UgcSeasonActivity',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UgcSeasonActivity.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aInt64(2, _omitFieldNames ? '' : 'oid')
    ..aInt64(3, _omitFieldNames ? '' : 'activityId')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'intro')
    ..aI(6, _omitFieldNames ? '' : 'dayCount')
    ..aI(7, _omitFieldNames ? '' : 'userCount')
    ..aInt64(8, _omitFieldNames ? '' : 'joinDeadline')
    ..aInt64(9, _omitFieldNames ? '' : 'activityDeadline')
    ..aI(10, _omitFieldNames ? '' : 'checkinViewTime')
    ..aOB(11, _omitFieldNames ? '' : 'newActivity')
    ..aOM<UserActivity>(12, _omitFieldNames ? '' : 'userActivity',
        subBuilder: UserActivity.$_createMessage)
    ..aOM<SeasonShow>(13, _omitFieldNames ? '' : 'seasonShow',
        subBuilder: SeasonShow.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UgcSeasonActivity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UgcSeasonActivity copyWith(void Function(UgcSeasonActivity) updates) =>
      super.copyWith((message) => updates(message as UgcSeasonActivity))
          as UgcSeasonActivity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UgcSeasonActivity() / UgcSeasonActivity.new instead')
  static UgcSeasonActivity create() => UgcSeasonActivity._();
  static $pb.GeneratedMessage $_createMessage() => UgcSeasonActivity._();
  @$core.override
  UgcSeasonActivity createEmptyInstance() => UgcSeasonActivity._();
  @$core.pragma('dart2js:noInline')
  static UgcSeasonActivity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UgcSeasonActivity>(
          UgcSeasonActivity.$_createMessage);
  static UgcSeasonActivity? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get oid => $_getI64(1);
  @$pb.TagNumber(2)
  set oid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOid() => $_has(1);
  @$pb.TagNumber(2)
  void clearOid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get activityId => $_getI64(2);
  @$pb.TagNumber(3)
  set activityId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActivityId() => $_has(2);
  @$pb.TagNumber(3)
  void clearActivityId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get intro => $_getSZ(4);
  @$pb.TagNumber(5)
  set intro($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIntro() => $_has(4);
  @$pb.TagNumber(5)
  void clearIntro() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get dayCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set dayCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDayCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearDayCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get userCount => $_getIZ(6);
  @$pb.TagNumber(7)
  set userCount($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUserCount() => $_has(6);
  @$pb.TagNumber(7)
  void clearUserCount() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get joinDeadline => $_getI64(7);
  @$pb.TagNumber(8)
  set joinDeadline($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasJoinDeadline() => $_has(7);
  @$pb.TagNumber(8)
  void clearJoinDeadline() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get activityDeadline => $_getI64(8);
  @$pb.TagNumber(9)
  set activityDeadline($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasActivityDeadline() => $_has(8);
  @$pb.TagNumber(9)
  void clearActivityDeadline() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get checkinViewTime => $_getIZ(9);
  @$pb.TagNumber(10)
  set checkinViewTime($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCheckinViewTime() => $_has(9);
  @$pb.TagNumber(10)
  void clearCheckinViewTime() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get newActivity => $_getBF(10);
  @$pb.TagNumber(11)
  set newActivity($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNewActivity() => $_has(10);
  @$pb.TagNumber(11)
  void clearNewActivity() => $_clearField(11);

  @$pb.TagNumber(12)
  UserActivity get userActivity => $_getN(11);
  @$pb.TagNumber(12)
  set userActivity(UserActivity value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUserActivity() => $_has(11);
  @$pb.TagNumber(12)
  void clearUserActivity() => $_clearField(12);
  @$pb.TagNumber(12)
  UserActivity ensureUserActivity() => $_ensure(11);

  @$pb.TagNumber(13)
  SeasonShow get seasonShow => $_getN(12);
  @$pb.TagNumber(13)
  set seasonShow(SeasonShow value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasSeasonShow() => $_has(12);
  @$pb.TagNumber(13)
  void clearSeasonShow() => $_clearField(13);
  @$pb.TagNumber(13)
  SeasonShow ensureSeasonShow() => $_ensure(12);
}

/// ugc视频合集状态数
class UgcSeasonStat extends $pb.GeneratedMessage {
  factory UgcSeasonStat({
    $fixnum.Int64? seasonId,
    $core.int? view,
    $core.int? danmaku,
    $core.int? reply,
    $core.int? fav,
    $core.int? coin,
    $core.int? share,
    $core.int? nowRank,
    $core.int? hisRank,
    $core.int? like,
  }) {
    final result = UgcSeasonStat._();
    if (seasonId != null) result.seasonId = seasonId;
    if (view != null) result.view = view;
    if (danmaku != null) result.danmaku = danmaku;
    if (reply != null) result.reply = reply;
    if (fav != null) result.fav = fav;
    if (coin != null) result.coin = coin;
    if (share != null) result.share = share;
    if (nowRank != null) result.nowRank = nowRank;
    if (hisRank != null) result.hisRank = hisRank;
    if (like != null) result.like = like;
    return result;
  }

  UgcSeasonStat._();

  factory UgcSeasonStat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UgcSeasonStat()..mergeFromBuffer(data, registry);
  factory UgcSeasonStat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UgcSeasonStat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UgcSeasonStat',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UgcSeasonStat.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'seasonId')
    ..aI(2, _omitFieldNames ? '' : 'view')
    ..aI(3, _omitFieldNames ? '' : 'danmaku')
    ..aI(4, _omitFieldNames ? '' : 'reply')
    ..aI(5, _omitFieldNames ? '' : 'fav')
    ..aI(6, _omitFieldNames ? '' : 'coin')
    ..aI(7, _omitFieldNames ? '' : 'share')
    ..aI(8, _omitFieldNames ? '' : 'nowRank')
    ..aI(9, _omitFieldNames ? '' : 'hisRank')
    ..aI(10, _omitFieldNames ? '' : 'like')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UgcSeasonStat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UgcSeasonStat copyWith(void Function(UgcSeasonStat) updates) =>
      super.copyWith((message) => updates(message as UgcSeasonStat))
          as UgcSeasonStat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UgcSeasonStat() / UgcSeasonStat.new instead')
  static UgcSeasonStat create() => UgcSeasonStat._();
  static $pb.GeneratedMessage $_createMessage() => UgcSeasonStat._();
  @$core.override
  UgcSeasonStat createEmptyInstance() => UgcSeasonStat._();
  @$core.pragma('dart2js:noInline')
  static UgcSeasonStat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UgcSeasonStat>(
          UgcSeasonStat.$_createMessage);
  static UgcSeasonStat? _defaultInstance;

  /// 合集id
  @$pb.TagNumber(1)
  $fixnum.Int64 get seasonId => $_getI64(0);
  @$pb.TagNumber(1)
  set seasonId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeasonId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeasonId() => $_clearField(1);

  /// 观看数
  @$pb.TagNumber(2)
  $core.int get view => $_getIZ(1);
  @$pb.TagNumber(2)
  set view($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasView() => $_has(1);
  @$pb.TagNumber(2)
  void clearView() => $_clearField(2);

  /// 弹幕数
  @$pb.TagNumber(3)
  $core.int get danmaku => $_getIZ(2);
  @$pb.TagNumber(3)
  set danmaku($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDanmaku() => $_has(2);
  @$pb.TagNumber(3)
  void clearDanmaku() => $_clearField(3);

  /// 评论数
  @$pb.TagNumber(4)
  $core.int get reply => $_getIZ(3);
  @$pb.TagNumber(4)
  set reply($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReply() => $_has(3);
  @$pb.TagNumber(4)
  void clearReply() => $_clearField(4);

  /// 收藏数
  @$pb.TagNumber(5)
  $core.int get fav => $_getIZ(4);
  @$pb.TagNumber(5)
  set fav($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFav() => $_has(4);
  @$pb.TagNumber(5)
  void clearFav() => $_clearField(5);

  /// 投币数
  @$pb.TagNumber(6)
  $core.int get coin => $_getIZ(5);
  @$pb.TagNumber(6)
  set coin($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCoin() => $_has(5);
  @$pb.TagNumber(6)
  void clearCoin() => $_clearField(6);

  /// 分享数
  @$pb.TagNumber(7)
  $core.int get share => $_getIZ(6);
  @$pb.TagNumber(7)
  set share($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasShare() => $_has(6);
  @$pb.TagNumber(7)
  void clearShare() => $_clearField(7);

  /// 当前排名
  @$pb.TagNumber(8)
  $core.int get nowRank => $_getIZ(7);
  @$pb.TagNumber(8)
  set nowRank($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNowRank() => $_has(7);
  @$pb.TagNumber(8)
  void clearNowRank() => $_clearField(8);

  /// 历史最高排名
  @$pb.TagNumber(9)
  $core.int get hisRank => $_getIZ(8);
  @$pb.TagNumber(9)
  set hisRank($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHisRank() => $_has(8);
  @$pb.TagNumber(9)
  void clearHisRank() => $_clearField(9);

  /// 总计点赞
  @$pb.TagNumber(10)
  $core.int get like => $_getIZ(9);
  @$pb.TagNumber(10)
  set like($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLike() => $_has(9);
  @$pb.TagNumber(10)
  void clearLike() => $_clearField(10);
}

class UpAct extends $pb.GeneratedMessage {
  factory UpAct({
    $fixnum.Int64? sid,
    $fixnum.Int64? mid,
    $core.String? title,
    $core.String? statement,
    $core.String? image,
    $core.String? url,
    $core.String? button,
  }) {
    final result = UpAct._();
    if (sid != null) result.sid = sid;
    if (mid != null) result.mid = mid;
    if (title != null) result.title = title;
    if (statement != null) result.statement = statement;
    if (image != null) result.image = image;
    if (url != null) result.url = url;
    if (button != null) result.button = button;
    return result;
  }

  UpAct._();

  factory UpAct.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpAct()..mergeFromBuffer(data, registry);
  factory UpAct.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpAct()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpAct',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UpAct.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'sid')
    ..aInt64(2, _omitFieldNames ? '' : 'mid')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'statement')
    ..aOS(5, _omitFieldNames ? '' : 'image')
    ..aOS(6, _omitFieldNames ? '' : 'url')
    ..aOS(7, _omitFieldNames ? '' : 'button')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpAct clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpAct copyWith(void Function(UpAct) updates) =>
      super.copyWith((message) => updates(message as UpAct)) as UpAct;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpAct() / UpAct.new instead')
  static UpAct create() => UpAct._();
  static $pb.GeneratedMessage $_createMessage() => UpAct._();
  @$core.override
  UpAct createEmptyInstance() => UpAct._();
  @$core.pragma('dart2js:noInline')
  static UpAct getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpAct>(UpAct.$_createMessage);
  static UpAct? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sid => $_getI64(0);
  @$pb.TagNumber(1)
  set sid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get mid => $_getI64(1);
  @$pb.TagNumber(2)
  set mid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMid() => $_has(1);
  @$pb.TagNumber(2)
  void clearMid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get statement => $_getSZ(3);
  @$pb.TagNumber(4)
  set statement($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatement() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatement() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get image => $_getSZ(4);
  @$pb.TagNumber(5)
  set image($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasImage() => $_has(4);
  @$pb.TagNumber(5)
  void clearImage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get url => $_getSZ(5);
  @$pb.TagNumber(6)
  set url($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get button => $_getSZ(6);
  @$pb.TagNumber(7)
  set button($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasButton() => $_has(6);
  @$pb.TagNumber(7)
  void clearButton() => $_clearField(7);
}

class UpLikeImg extends $pb.GeneratedMessage {
  factory UpLikeImg({
    $core.String? preImg,
    $core.String? sucImg,
    $core.String? content,
    $fixnum.Int64? type,
  }) {
    final result = UpLikeImg._();
    if (preImg != null) result.preImg = preImg;
    if (sucImg != null) result.sucImg = sucImg;
    if (content != null) result.content = content;
    if (type != null) result.type = type;
    return result;
  }

  UpLikeImg._();

  factory UpLikeImg.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpLikeImg()..mergeFromBuffer(data, registry);
  factory UpLikeImg.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpLikeImg()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpLikeImg',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UpLikeImg.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'preImg')
    ..aOS(2, _omitFieldNames ? '' : 'sucImg')
    ..aOS(3, _omitFieldNames ? '' : 'content')
    ..aInt64(4, _omitFieldNames ? '' : 'type')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpLikeImg clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpLikeImg copyWith(void Function(UpLikeImg) updates) =>
      super.copyWith((message) => updates(message as UpLikeImg)) as UpLikeImg;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpLikeImg() / UpLikeImg.new instead')
  static UpLikeImg create() => UpLikeImg._();
  static $pb.GeneratedMessage $_createMessage() => UpLikeImg._();
  @$core.override
  UpLikeImg createEmptyInstance() => UpLikeImg._();
  @$core.pragma('dart2js:noInline')
  static UpLikeImg getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpLikeImg>(UpLikeImg.$_createMessage);
  static UpLikeImg? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get preImg => $_getSZ(0);
  @$pb.TagNumber(1)
  set preImg($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPreImg() => $_has(0);
  @$pb.TagNumber(1)
  void clearPreImg() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sucImg => $_getSZ(1);
  @$pb.TagNumber(2)
  set sucImg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSucImg() => $_has(1);
  @$pb.TagNumber(2)
  void clearSucImg() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get type => $_getI64(3);
  @$pb.TagNumber(4)
  set type($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);
}

/// UP主信息
class UpperInfos extends $pb.GeneratedMessage {
  factory UpperInfos({
    $fixnum.Int64? fansCount,
    $fixnum.Int64? arcCountLastHalfYear,
    $fixnum.Int64? firstUpDates,
    $fixnum.Int64? totalPlayCount,
  }) {
    final result = UpperInfos._();
    if (fansCount != null) result.fansCount = fansCount;
    if (arcCountLastHalfYear != null)
      result.arcCountLastHalfYear = arcCountLastHalfYear;
    if (firstUpDates != null) result.firstUpDates = firstUpDates;
    if (totalPlayCount != null) result.totalPlayCount = totalPlayCount;
    return result;
  }

  UpperInfos._();

  factory UpperInfos.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpperInfos()..mergeFromBuffer(data, registry);
  factory UpperInfos.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpperInfos()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpperInfos',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UpperInfos.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'fansCount')
    ..aInt64(2, _omitFieldNames ? '' : 'arcCountLastHalfYear')
    ..aInt64(3, _omitFieldNames ? '' : 'firstUpDates')
    ..aInt64(4, _omitFieldNames ? '' : 'totalPlayCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpperInfos clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpperInfos copyWith(void Function(UpperInfos) updates) =>
      super.copyWith((message) => updates(message as UpperInfos)) as UpperInfos;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpperInfos() / UpperInfos.new instead')
  static UpperInfos create() => UpperInfos._();
  static $pb.GeneratedMessage $_createMessage() => UpperInfos._();
  @$core.override
  UpperInfos createEmptyInstance() => UpperInfos._();
  @$core.pragma('dart2js:noInline')
  static UpperInfos getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpperInfos>(UpperInfos.$_createMessage);
  static UpperInfos? _defaultInstance;

  /// 粉丝数
  @$pb.TagNumber(1)
  $fixnum.Int64 get fansCount => $_getI64(0);
  @$pb.TagNumber(1)
  set fansCount($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFansCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearFansCount() => $_clearField(1);

  /// 近半年投稿数
  @$pb.TagNumber(2)
  $fixnum.Int64 get arcCountLastHalfYear => $_getI64(1);
  @$pb.TagNumber(2)
  set arcCountLastHalfYear($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasArcCountLastHalfYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearArcCountLastHalfYear() => $_clearField(2);

  /// 成为UP主时间
  @$pb.TagNumber(3)
  $fixnum.Int64 get firstUpDates => $_getI64(2);
  @$pb.TagNumber(3)
  set firstUpDates($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstUpDates() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstUpDates() => $_clearField(3);

  /// 总播放量
  @$pb.TagNumber(4)
  $fixnum.Int64 get totalPlayCount => $_getI64(3);
  @$pb.TagNumber(4)
  set totalPlayCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalPlayCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalPlayCount() => $_clearField(4);
}

class UserActivity extends $pb.GeneratedMessage {
  factory UserActivity({
    $core.int? userState,
    $fixnum.Int64? lastCheckinDate,
    $core.int? checkinToday,
    $core.int? userDayCount,
    $core.int? userViewTime,
    $core.String? portrait,
  }) {
    final result = UserActivity._();
    if (userState != null) result.userState = userState;
    if (lastCheckinDate != null) result.lastCheckinDate = lastCheckinDate;
    if (checkinToday != null) result.checkinToday = checkinToday;
    if (userDayCount != null) result.userDayCount = userDayCount;
    if (userViewTime != null) result.userViewTime = userViewTime;
    if (portrait != null) result.portrait = portrait;
    return result;
  }

  UserActivity._();

  factory UserActivity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserActivity()..mergeFromBuffer(data, registry);
  factory UserActivity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserActivity()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserActivity',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UserActivity.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'userState')
    ..aInt64(2, _omitFieldNames ? '' : 'lastCheckinDate')
    ..aI(3, _omitFieldNames ? '' : 'checkinToday')
    ..aI(4, _omitFieldNames ? '' : 'userDayCount')
    ..aI(5, _omitFieldNames ? '' : 'userViewTime')
    ..aOS(6, _omitFieldNames ? '' : 'portrait')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserActivity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserActivity copyWith(void Function(UserActivity) updates) =>
      super.copyWith((message) => updates(message as UserActivity))
          as UserActivity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserActivity() / UserActivity.new instead')
  static UserActivity create() => UserActivity._();
  static $pb.GeneratedMessage $_createMessage() => UserActivity._();
  @$core.override
  UserActivity createEmptyInstance() => UserActivity._();
  @$core.pragma('dart2js:noInline')
  static UserActivity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserActivity>(
          UserActivity.$_createMessage);
  static UserActivity? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get userState => $_getIZ(0);
  @$pb.TagNumber(1)
  set userState($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserState() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserState() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get lastCheckinDate => $_getI64(1);
  @$pb.TagNumber(2)
  set lastCheckinDate($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastCheckinDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastCheckinDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get checkinToday => $_getIZ(2);
  @$pb.TagNumber(3)
  set checkinToday($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCheckinToday() => $_has(2);
  @$pb.TagNumber(3)
  void clearCheckinToday() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get userDayCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set userDayCount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUserDayCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearUserDayCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get userViewTime => $_getIZ(4);
  @$pb.TagNumber(5)
  set userViewTime($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUserViewTime() => $_has(4);
  @$pb.TagNumber(5)
  void clearUserViewTime() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get portrait => $_getSZ(5);
  @$pb.TagNumber(6)
  set portrait($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPortrait() => $_has(5);
  @$pb.TagNumber(6)
  void clearPortrait() => $_clearField(6);
}

/// 用户装扮信息
class UserGarb extends $pb.GeneratedMessage {
  factory UserGarb({
    $core.String? urlImageAniCut,
    $core.String? likeToast,
  }) {
    final result = UserGarb._();
    if (urlImageAniCut != null) result.urlImageAniCut = urlImageAniCut;
    if (likeToast != null) result.likeToast = likeToast;
    return result;
  }

  UserGarb._();

  factory UserGarb.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserGarb()..mergeFromBuffer(data, registry);
  factory UserGarb.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserGarb()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserGarb',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UserGarb.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'urlImageAniCut')
    ..aOS(2, _omitFieldNames ? '' : 'likeToast')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserGarb clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserGarb copyWith(void Function(UserGarb) updates) =>
      super.copyWith((message) => updates(message as UserGarb)) as UserGarb;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserGarb() / UserGarb.new instead')
  static UserGarb create() => UserGarb._();
  static $pb.GeneratedMessage $_createMessage() => UserGarb._();
  @$core.override
  UserGarb createEmptyInstance() => UserGarb._();
  @$core.pragma('dart2js:noInline')
  static UserGarb getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserGarb>(UserGarb.$_createMessage);
  static UserGarb? _defaultInstance;

  /// 点赞动画url
  @$pb.TagNumber(1)
  $core.String get urlImageAniCut => $_getSZ(0);
  @$pb.TagNumber(1)
  set urlImageAniCut($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrlImageAniCut() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrlImageAniCut() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get likeToast => $_getSZ(1);
  @$pb.TagNumber(2)
  set likeToast($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLikeToast() => $_has(1);
  @$pb.TagNumber(2)
  void clearLikeToast() => $_clearField(2);
}

/// 用户追番标志
class UserSeason extends $pb.GeneratedMessage {
  factory UserSeason({
    $core.String? attention,
  }) {
    final result = UserSeason._();
    if (attention != null) result.attention = attention;
    return result;
  }

  UserSeason._();

  factory UserSeason.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserSeason()..mergeFromBuffer(data, registry);
  factory UserSeason.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserSeason()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserSeason',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: UserSeason.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'attention')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserSeason clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserSeason copyWith(void Function(UserSeason) updates) =>
      super.copyWith((message) => updates(message as UserSeason)) as UserSeason;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserSeason() / UserSeason.new instead')
  static UserSeason create() => UserSeason._();
  static $pb.GeneratedMessage $_createMessage() => UserSeason._();
  @$core.override
  UserSeason createEmptyInstance() => UserSeason._();
  @$core.pragma('dart2js:noInline')
  static UserSeason getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserSeason>(UserSeason.$_createMessage);
  static UserSeason? _defaultInstance;

  /// 关注状态
  /// 0:未关注 1:已关注
  @$pb.TagNumber(1)
  $core.String get attention => $_getSZ(0);
  @$pb.TagNumber(1)
  set attention($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttention() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttention() => $_clearField(1);
}

/// 视频引导信息
class VideoGuide extends $pb.GeneratedMessage {
  factory VideoGuide({
    $core.Iterable<Attention>? attention,
    $core.Iterable<CommandDm>? commandDms,
    $core.Iterable<OperationCard>? operationCard,
    $core.Iterable<OperationCardNew>? operationCardNew,
    ContractCard? contractCard,
    $core.Iterable<OperationCardV2>? cardsSecond,
  }) {
    final result = VideoGuide._();
    if (attention != null) result.attention.addAll(attention);
    if (commandDms != null) result.commandDms.addAll(commandDms);
    if (operationCard != null) result.operationCard.addAll(operationCard);
    if (operationCardNew != null)
      result.operationCardNew.addAll(operationCardNew);
    if (contractCard != null) result.contractCard = contractCard;
    if (cardsSecond != null) result.cardsSecond.addAll(cardsSecond);
    return result;
  }

  VideoGuide._();

  factory VideoGuide.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoGuide()..mergeFromBuffer(data, registry);
  factory VideoGuide.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoGuide()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VideoGuide',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: VideoGuide.$_createMessage)
    ..pPM<Attention>(1, _omitFieldNames ? '' : 'attention',
        subBuilder: Attention.$_createMessage)
    ..pPM<CommandDm>(2, _omitFieldNames ? '' : 'commandDms',
        protoName: 'commandDms', subBuilder: CommandDm.$_createMessage)
    ..pPM<OperationCard>(3, _omitFieldNames ? '' : 'operationCard',
        subBuilder: OperationCard.$_createMessage)
    ..pPM<OperationCardNew>(4, _omitFieldNames ? '' : 'operationCardNew',
        subBuilder: OperationCardNew.$_createMessage)
    ..aOM<ContractCard>(5, _omitFieldNames ? '' : 'contractCard',
        subBuilder: ContractCard.$_createMessage)
    ..pPM<OperationCardV2>(6, _omitFieldNames ? '' : 'cardsSecond',
        subBuilder: OperationCardV2.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoGuide clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoGuide copyWith(void Function(VideoGuide) updates) =>
      super.copyWith((message) => updates(message as VideoGuide)) as VideoGuide;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VideoGuide() / VideoGuide.new instead')
  static VideoGuide create() => VideoGuide._();
  static $pb.GeneratedMessage $_createMessage() => VideoGuide._();
  @$core.override
  VideoGuide createEmptyInstance() => VideoGuide._();
  @$core.pragma('dart2js:noInline')
  static VideoGuide getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VideoGuide>(VideoGuide.$_createMessage);
  static VideoGuide? _defaultInstance;

  /// 关注按钮卡片
  @$pb.TagNumber(1)
  $pb.PbList<Attention> get attention => $_getList(0);

  /// 互动弹幕
  @$pb.TagNumber(2)
  $pb.PbList<CommandDm> get commandDms => $_getList(1);

  /// 运营卡片
  @$pb.TagNumber(3)
  $pb.PbList<OperationCard> get operationCard => $_getList(2);

  /// 运营卡片新版
  @$pb.TagNumber(4)
  $pb.PbList<OperationCardNew> get operationCardNew => $_getList(3);

  /// 契约卡
  @$pb.TagNumber(5)
  ContractCard get contractCard => $_getN(4);
  @$pb.TagNumber(5)
  set contractCard(ContractCard value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasContractCard() => $_has(4);
  @$pb.TagNumber(5)
  void clearContractCard() => $_clearField(5);
  @$pb.TagNumber(5)
  ContractCard ensureContractCard() => $_ensure(4);

  @$pb.TagNumber(6)
  $pb.PbList<OperationCardV2> get cardsSecond => $_getList(5);
}

class VideoPoint extends $pb.GeneratedMessage {
  factory VideoPoint({
    $core.int? type,
    $fixnum.Int64? from,
    $fixnum.Int64? to,
    $core.String? content,
    $core.String? cover,
    $core.String? logoUrl,
  }) {
    final result = VideoPoint._();
    if (type != null) result.type = type;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (content != null) result.content = content;
    if (cover != null) result.cover = cover;
    if (logoUrl != null) result.logoUrl = logoUrl;
    return result;
  }

  VideoPoint._();

  factory VideoPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoPoint()..mergeFromBuffer(data, registry);
  factory VideoPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoPoint()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VideoPoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: VideoPoint.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aInt64(2, _omitFieldNames ? '' : 'from')
    ..aInt64(3, _omitFieldNames ? '' : 'to')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aOS(5, _omitFieldNames ? '' : 'cover')
    ..aOS(6, _omitFieldNames ? '' : 'logoUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoPoint copyWith(void Function(VideoPoint) updates) =>
      super.copyWith((message) => updates(message as VideoPoint)) as VideoPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VideoPoint() / VideoPoint.new instead')
  static VideoPoint create() => VideoPoint._();
  static $pb.GeneratedMessage $_createMessage() => VideoPoint._();
  @$core.override
  VideoPoint createEmptyInstance() => VideoPoint._();
  @$core.pragma('dart2js:noInline')
  static VideoPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VideoPoint>(VideoPoint.$_createMessage);
  static VideoPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get from => $_getI64(1);
  @$pb.TagNumber(2)
  set from($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get to => $_getI64(2);
  @$pb.TagNumber(3)
  set to($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get cover => $_getSZ(4);
  @$pb.TagNumber(5)
  set cover($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCover() => $_has(4);
  @$pb.TagNumber(5)
  void clearCover() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get logoUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set logoUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLogoUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearLogoUrl() => $_clearField(6);
}

class VideoShot extends $pb.GeneratedMessage {
  factory VideoShot({
    $core.String? pvData,
    $core.int? imgXLen,
    $core.int? imgYLen,
    $core.int? imgXSize,
    $core.int? imgYSize,
    $core.Iterable<$core.String>? image,
  }) {
    final result = VideoShot._();
    if (pvData != null) result.pvData = pvData;
    if (imgXLen != null) result.imgXLen = imgXLen;
    if (imgYLen != null) result.imgYLen = imgYLen;
    if (imgXSize != null) result.imgXSize = imgXSize;
    if (imgYSize != null) result.imgYSize = imgYSize;
    if (image != null) result.image.addAll(image);
    return result;
  }

  VideoShot._();

  factory VideoShot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoShot()..mergeFromBuffer(data, registry);
  factory VideoShot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VideoShot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VideoShot',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: VideoShot.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pvData')
    ..aI(2, _omitFieldNames ? '' : 'imgXLen')
    ..aI(3, _omitFieldNames ? '' : 'imgYLen')
    ..aI(4, _omitFieldNames ? '' : 'imgXSize')
    ..aI(5, _omitFieldNames ? '' : 'imgYSize')
    ..pPS(6, _omitFieldNames ? '' : 'image')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoShot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VideoShot copyWith(void Function(VideoShot) updates) =>
      super.copyWith((message) => updates(message as VideoShot)) as VideoShot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VideoShot() / VideoShot.new instead')
  static VideoShot create() => VideoShot._();
  static $pb.GeneratedMessage $_createMessage() => VideoShot._();
  @$core.override
  VideoShot createEmptyInstance() => VideoShot._();
  @$core.pragma('dart2js:noInline')
  static VideoShot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VideoShot>(VideoShot.$_createMessage);
  static VideoShot? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pvData => $_getSZ(0);
  @$pb.TagNumber(1)
  set pvData($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPvData() => $_has(0);
  @$pb.TagNumber(1)
  void clearPvData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get imgXLen => $_getIZ(1);
  @$pb.TagNumber(2)
  set imgXLen($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasImgXLen() => $_has(1);
  @$pb.TagNumber(2)
  void clearImgXLen() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get imgYLen => $_getIZ(2);
  @$pb.TagNumber(3)
  set imgYLen($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasImgYLen() => $_has(2);
  @$pb.TagNumber(3)
  void clearImgYLen() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get imgXSize => $_getIZ(3);
  @$pb.TagNumber(4)
  set imgXSize($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasImgXSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearImgXSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get imgYSize => $_getIZ(4);
  @$pb.TagNumber(5)
  set imgYSize($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasImgYSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearImgYSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get image => $_getList(5);
}

class ViewMaterial extends $pb.GeneratedMessage {
  factory ViewMaterial({
    $fixnum.Int64? oid,
    $fixnum.Int64? mid,
    $core.String? title,
    $core.String? author,
    $core.String? jumpUrl,
  }) {
    final result = ViewMaterial._();
    if (oid != null) result.oid = oid;
    if (mid != null) result.mid = mid;
    if (title != null) result.title = title;
    if (author != null) result.author = author;
    if (jumpUrl != null) result.jumpUrl = jumpUrl;
    return result;
  }

  ViewMaterial._();

  factory ViewMaterial.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewMaterial()..mergeFromBuffer(data, registry);
  factory ViewMaterial.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewMaterial()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewMaterial',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewMaterial.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'oid')
    ..aInt64(2, _omitFieldNames ? '' : 'mid')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'author')
    ..aOS(5, _omitFieldNames ? '' : 'jumpUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewMaterial clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewMaterial copyWith(void Function(ViewMaterial) updates) =>
      super.copyWith((message) => updates(message as ViewMaterial))
          as ViewMaterial;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewMaterial() / ViewMaterial.new instead')
  static ViewMaterial create() => ViewMaterial._();
  static $pb.GeneratedMessage $_createMessage() => ViewMaterial._();
  @$core.override
  ViewMaterial createEmptyInstance() => ViewMaterial._();
  @$core.pragma('dart2js:noInline')
  static ViewMaterial getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ViewMaterial>(
          ViewMaterial.$_createMessage);
  static ViewMaterial? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get oid => $_getI64(0);
  @$pb.TagNumber(1)
  set oid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOid() => $_has(0);
  @$pb.TagNumber(1)
  void clearOid() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get mid => $_getI64(1);
  @$pb.TagNumber(2)
  set mid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMid() => $_has(1);
  @$pb.TagNumber(2)
  void clearMid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get author => $_getSZ(3);
  @$pb.TagNumber(4)
  set author($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthor() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get jumpUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set jumpUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasJumpUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearJumpUrl() => $_clearField(5);
}

class ViewMaterialReply extends $pb.GeneratedMessage {
  factory ViewMaterialReply({
    $core.Iterable<MaterialRes>? materialRes,
    MaterialLeft? materialLeft,
  }) {
    final result = ViewMaterialReply._();
    if (materialRes != null) result.materialRes.addAll(materialRes);
    if (materialLeft != null) result.materialLeft = materialLeft;
    return result;
  }

  ViewMaterialReply._();

  factory ViewMaterialReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewMaterialReply()..mergeFromBuffer(data, registry);
  factory ViewMaterialReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewMaterialReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewMaterialReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewMaterialReply.$_createMessage)
    ..pPM<MaterialRes>(1, _omitFieldNames ? '' : 'materialRes',
        subBuilder: MaterialRes.$_createMessage)
    ..aOM<MaterialLeft>(2, _omitFieldNames ? '' : 'materialLeft',
        subBuilder: MaterialLeft.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewMaterialReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewMaterialReply copyWith(void Function(ViewMaterialReply) updates) =>
      super.copyWith((message) => updates(message as ViewMaterialReply))
          as ViewMaterialReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewMaterialReply() / ViewMaterialReply.new instead')
  static ViewMaterialReply create() => ViewMaterialReply._();
  static $pb.GeneratedMessage $_createMessage() => ViewMaterialReply._();
  @$core.override
  ViewMaterialReply createEmptyInstance() => ViewMaterialReply._();
  @$core.pragma('dart2js:noInline')
  static ViewMaterialReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ViewMaterialReply>(
          ViewMaterialReply.$_createMessage);
  static ViewMaterialReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MaterialRes> get materialRes => $_getList(0);

  @$pb.TagNumber(2)
  MaterialLeft get materialLeft => $_getN(1);
  @$pb.TagNumber(2)
  set materialLeft(MaterialLeft value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMaterialLeft() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaterialLeft() => $_clearField(2);
  @$pb.TagNumber(2)
  MaterialLeft ensureMaterialLeft() => $_ensure(1);
}

class ViewMaterialReq extends $pb.GeneratedMessage {
  factory ViewMaterialReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $fixnum.Int64? cid,
  }) {
    final result = ViewMaterialReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (cid != null) result.cid = cid;
    return result;
  }

  ViewMaterialReq._();

  factory ViewMaterialReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewMaterialReq()..mergeFromBuffer(data, registry);
  factory ViewMaterialReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewMaterialReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewMaterialReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewMaterialReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewMaterialReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewMaterialReq copyWith(void Function(ViewMaterialReq) updates) =>
      super.copyWith((message) => updates(message as ViewMaterialReq))
          as ViewMaterialReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewMaterialReq() / ViewMaterialReq.new instead')
  static ViewMaterialReq create() => ViewMaterialReq._();
  static $pb.GeneratedMessage $_createMessage() => ViewMaterialReq._();
  @$core.override
  ViewMaterialReq createEmptyInstance() => ViewMaterialReq._();
  @$core.pragma('dart2js:noInline')
  static ViewMaterialReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ViewMaterialReq>(
          ViewMaterialReq.$_createMessage);
  static ViewMaterialReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);
}

/// 分P信息
class ViewPage extends $pb.GeneratedMessage {
  factory ViewPage({
    $1.Page? page,
    Audio? audio,
    DM? dm,
    $core.String? downloadTitle,
    $core.String? downloadSubtitle,
  }) {
    final result = ViewPage._();
    if (page != null) result.page = page;
    if (audio != null) result.audio = audio;
    if (dm != null) result.dm = dm;
    if (downloadTitle != null) result.downloadTitle = downloadTitle;
    if (downloadSubtitle != null) result.downloadSubtitle = downloadSubtitle;
    return result;
  }

  ViewPage._();

  factory ViewPage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewPage()..mergeFromBuffer(data, registry);
  factory ViewPage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewPage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewPage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewPage.$_createMessage)
    ..aOM<$1.Page>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $1.Page.$_createMessage)
    ..aOM<Audio>(2, _omitFieldNames ? '' : 'audio',
        subBuilder: Audio.$_createMessage)
    ..aOM<DM>(3, _omitFieldNames ? '' : 'dm', subBuilder: DM.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'downloadTitle')
    ..aOS(5, _omitFieldNames ? '' : 'downloadSubtitle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewPage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewPage copyWith(void Function(ViewPage) updates) =>
      super.copyWith((message) => updates(message as ViewPage)) as ViewPage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewPage() / ViewPage.new instead')
  static ViewPage create() => ViewPage._();
  static $pb.GeneratedMessage $_createMessage() => ViewPage._();
  @$core.override
  ViewPage createEmptyInstance() => ViewPage._();
  @$core.pragma('dart2js:noInline')
  static ViewPage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ViewPage>(ViewPage.$_createMessage);
  static ViewPage? _defaultInstance;

  /// 分P基本信息
  @$pb.TagNumber(1)
  $1.Page get page => $_getN(0);
  @$pb.TagNumber(1)
  set page($1.Page value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Page ensurePage() => $_ensure(0);

  /// 分P对应的音频稿件
  @$pb.TagNumber(2)
  Audio get audio => $_getN(1);
  @$pb.TagNumber(2)
  set audio(Audio value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAudio() => $_has(1);
  @$pb.TagNumber(2)
  void clearAudio() => $_clearField(2);
  @$pb.TagNumber(2)
  Audio ensureAudio() => $_ensure(1);

  /// 分P弹幕信息
  @$pb.TagNumber(3)
  DM get dm => $_getN(2);
  @$pb.TagNumber(3)
  set dm(DM value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDm() => $_has(2);
  @$pb.TagNumber(3)
  void clearDm() => $_clearField(3);
  @$pb.TagNumber(3)
  DM ensureDm() => $_ensure(2);

  /// 下载文案
  @$pb.TagNumber(4)
  $core.String get downloadTitle => $_getSZ(3);
  @$pb.TagNumber(4)
  set downloadTitle($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDownloadTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearDownloadTitle() => $_clearField(4);

  /// 分P完整标题(视频标题+分P标题)
  @$pb.TagNumber(5)
  $core.String get downloadSubtitle => $_getSZ(4);
  @$pb.TagNumber(5)
  set downloadSubtitle($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDownloadSubtitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearDownloadSubtitle() => $_clearField(5);
}

/// 稿件播放中数据-回复
class ViewProgressReply extends $pb.GeneratedMessage {
  factory ViewProgressReply({
    VideoGuide? videoGuide,
    Chronos? chronos,
    VideoShot? arcShot,
    $core.Iterable<VideoPoint>? points,
    PointMaterial? pointMaterial,
    $core.bool? pointPermanent,
    $core.Iterable<BuzzwordConfig>? buzzwordPeriods,
  }) {
    final result = ViewProgressReply._();
    if (videoGuide != null) result.videoGuide = videoGuide;
    if (chronos != null) result.chronos = chronos;
    if (arcShot != null) result.arcShot = arcShot;
    if (points != null) result.points.addAll(points);
    if (pointMaterial != null) result.pointMaterial = pointMaterial;
    if (pointPermanent != null) result.pointPermanent = pointPermanent;
    if (buzzwordPeriods != null) result.buzzwordPeriods.addAll(buzzwordPeriods);
    return result;
  }

  ViewProgressReply._();

  factory ViewProgressReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewProgressReply()..mergeFromBuffer(data, registry);
  factory ViewProgressReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewProgressReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewProgressReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewProgressReply.$_createMessage)
    ..aOM<VideoGuide>(1, _omitFieldNames ? '' : 'videoGuide',
        subBuilder: VideoGuide.$_createMessage)
    ..aOM<Chronos>(2, _omitFieldNames ? '' : 'chronos',
        subBuilder: Chronos.$_createMessage)
    ..aOM<VideoShot>(3, _omitFieldNames ? '' : 'arcShot',
        subBuilder: VideoShot.$_createMessage)
    ..pPM<VideoPoint>(4, _omitFieldNames ? '' : 'points',
        subBuilder: VideoPoint.$_createMessage)
    ..aOM<PointMaterial>(5, _omitFieldNames ? '' : 'pointMaterial',
        subBuilder: PointMaterial.$_createMessage)
    ..aOB(6, _omitFieldNames ? '' : 'pointPermanent')
    ..pPM<BuzzwordConfig>(7, _omitFieldNames ? '' : 'buzzwordPeriods',
        subBuilder: BuzzwordConfig.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewProgressReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewProgressReply copyWith(void Function(ViewProgressReply) updates) =>
      super.copyWith((message) => updates(message as ViewProgressReply))
          as ViewProgressReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewProgressReply() / ViewProgressReply.new instead')
  static ViewProgressReply create() => ViewProgressReply._();
  static $pb.GeneratedMessage $_createMessage() => ViewProgressReply._();
  @$core.override
  ViewProgressReply createEmptyInstance() => ViewProgressReply._();
  @$core.pragma('dart2js:noInline')
  static ViewProgressReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ViewProgressReply>(
          ViewProgressReply.$_createMessage);
  static ViewProgressReply? _defaultInstance;

  /// 视频引导信息
  @$pb.TagNumber(1)
  VideoGuide get videoGuide => $_getN(0);
  @$pb.TagNumber(1)
  set videoGuide(VideoGuide value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVideoGuide() => $_has(0);
  @$pb.TagNumber(1)
  void clearVideoGuide() => $_clearField(1);
  @$pb.TagNumber(1)
  VideoGuide ensureVideoGuide() => $_ensure(0);

  /// Chronos灰度管理
  @$pb.TagNumber(2)
  Chronos get chronos => $_getN(1);
  @$pb.TagNumber(2)
  set chronos(Chronos value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasChronos() => $_has(1);
  @$pb.TagNumber(2)
  void clearChronos() => $_clearField(2);
  @$pb.TagNumber(2)
  Chronos ensureChronos() => $_ensure(1);

  /// 视频快照
  @$pb.TagNumber(3)
  VideoShot get arcShot => $_getN(2);
  @$pb.TagNumber(3)
  set arcShot(VideoShot value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasArcShot() => $_has(2);
  @$pb.TagNumber(3)
  void clearArcShot() => $_clearField(3);
  @$pb.TagNumber(3)
  VideoShot ensureArcShot() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<VideoPoint> get points => $_getList(3);

  @$pb.TagNumber(5)
  PointMaterial get pointMaterial => $_getN(4);
  @$pb.TagNumber(5)
  set pointMaterial(PointMaterial value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPointMaterial() => $_has(4);
  @$pb.TagNumber(5)
  void clearPointMaterial() => $_clearField(5);
  @$pb.TagNumber(5)
  PointMaterial ensurePointMaterial() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.bool get pointPermanent => $_getBF(5);
  @$pb.TagNumber(6)
  set pointPermanent($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPointPermanent() => $_has(5);
  @$pb.TagNumber(6)
  void clearPointPermanent() => $_clearField(6);

  /// 名词解释列表
  @$pb.TagNumber(7)
  $pb.PbList<BuzzwordConfig> get buzzwordPeriods => $_getList(6);
}

/// 稿件播放中数据-请求
class ViewProgressReq extends $pb.GeneratedMessage {
  factory ViewProgressReq({
    $fixnum.Int64? aid,
    $fixnum.Int64? cid,
    $fixnum.Int64? upMid,
    $core.String? engineVersion,
    $core.String? messageProtocol,
    $core.String? serviceKey,
  }) {
    final result = ViewProgressReq._();
    if (aid != null) result.aid = aid;
    if (cid != null) result.cid = cid;
    if (upMid != null) result.upMid = upMid;
    if (engineVersion != null) result.engineVersion = engineVersion;
    if (messageProtocol != null) result.messageProtocol = messageProtocol;
    if (serviceKey != null) result.serviceKey = serviceKey;
    return result;
  }

  ViewProgressReq._();

  factory ViewProgressReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewProgressReq()..mergeFromBuffer(data, registry);
  factory ViewProgressReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewProgressReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewProgressReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewProgressReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aInt64(2, _omitFieldNames ? '' : 'cid')
    ..aInt64(3, _omitFieldNames ? '' : 'upMid')
    ..aOS(4, _omitFieldNames ? '' : 'engineVersion')
    ..aOS(5, _omitFieldNames ? '' : 'messageProtocol')
    ..aOS(6, _omitFieldNames ? '' : 'serviceKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewProgressReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewProgressReq copyWith(void Function(ViewProgressReq) updates) =>
      super.copyWith((message) => updates(message as ViewProgressReq))
          as ViewProgressReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewProgressReq() / ViewProgressReq.new instead')
  static ViewProgressReq create() => ViewProgressReq._();
  static $pb.GeneratedMessage $_createMessage() => ViewProgressReq._();
  @$core.override
  ViewProgressReq createEmptyInstance() => ViewProgressReq._();
  @$core.pragma('dart2js:noInline')
  static ViewProgressReq getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ViewProgressReq>(
          ViewProgressReq.$_createMessage);
  static ViewProgressReq? _defaultInstance;

  /// 稿件avid
  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  /// 视频cid
  @$pb.TagNumber(2)
  $fixnum.Int64 get cid => $_getI64(1);
  @$pb.TagNumber(2)
  set cid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => $_clearField(2);

  /// UP主mid
  @$pb.TagNumber(3)
  $fixnum.Int64 get upMid => $_getI64(2);
  @$pb.TagNumber(3)
  set upMid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpMid() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpMid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get engineVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set engineVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEngineVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearEngineVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get messageProtocol => $_getSZ(4);
  @$pb.TagNumber(5)
  set messageProtocol($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessageProtocol() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageProtocol() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get serviceKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set serviceKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasServiceKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearServiceKey() => $_clearField(6);
}

/// 视频页信息-响应
class ViewReply extends $pb.GeneratedMessage {
  factory ViewReply({
    $1.Arc? arc,
    $core.Iterable<ViewPage>? pages,
    OnwerExt? ownerExt,
    ReqUser? reqUser,
    $core.Iterable<Tag>? tag,
    $core.Iterable<$core.MapEntry<$core.String, TIcon>>? tIcon,
    Season? season,
    ElecRank? elecRank,
    History? history,
    $core.Iterable<Relate>? relates,
    Dislike? dislike,
    PlayerIcon? playerIcon,
    $core.String? vipActive,
    $core.String? bvid,
    Honor? honor,
    $core.Iterable<RelateTab>? relateTab,
    $core.String? activityUrl,
    $core.Iterable<Bgm>? bgm,
    $core.Iterable<Staff>? staff,
    $core.String? argueMsg,
    $core.String? shortLink,
    $core.int? playParam,
    Label? label,
    UgcSeason? ugcSeason,
    Config? config,
    $core.String? shareSubtitle,
    Interaction? interaction,
    ECode? ecode,
    CustomConfig? customConfig,
    $core.Iterable<CM>? cms,
    CMConfig? cmConfig,
    Tab? tab,
    Rank? rank,
    TFPanelCustomized? tfPanelCustomized,
    UpAct? upAct,
    UserGarb? userGarb,
    ActivitySeason? activitySeason,
    $core.String? badgeUrl,
    LiveOrderInfo? liveOrderInfo,
    $core.Iterable<DescV2>? descV2,
    CmIpad? cmIpad,
    $core.Iterable<ViewMaterial>? sticker,
    UpLikeImg? upLikeImg,
    LikeCustom? likeCustom,
    $core.Iterable<Tag>? descTag,
    SpecialCell? specialCell,
    Online? online,
    $2.Any? cmUnderPlayer,
    $core.Iterable<ViewMaterial>? videoSource,
    $core.Iterable<SpecialCell>? specialCellNew,
    PremiereResource? premiere,
    $core.bool? refreshSpecialCell,
    MaterialLeft? materialLeft,
    $fixnum.Int64? notesCount,
    PullClientAction? pullAction,
    ArcExtra? arcExtra,
    $4.PaginationReply? pagination,
    LikeAnimation? likeAnimation,
    ReplyStyle? replyPreface,
    RefreshPage? refreshPage,
    CoinCustom? coinCustom,
  }) {
    final result = ViewReply._();
    if (arc != null) result.arc = arc;
    if (pages != null) result.pages.addAll(pages);
    if (ownerExt != null) result.ownerExt = ownerExt;
    if (reqUser != null) result.reqUser = reqUser;
    if (tag != null) result.tag.addAll(tag);
    if (tIcon != null) result.tIcon.addEntries(tIcon);
    if (season != null) result.season = season;
    if (elecRank != null) result.elecRank = elecRank;
    if (history != null) result.history = history;
    if (relates != null) result.relates.addAll(relates);
    if (dislike != null) result.dislike = dislike;
    if (playerIcon != null) result.playerIcon = playerIcon;
    if (vipActive != null) result.vipActive = vipActive;
    if (bvid != null) result.bvid = bvid;
    if (honor != null) result.honor = honor;
    if (relateTab != null) result.relateTab.addAll(relateTab);
    if (activityUrl != null) result.activityUrl = activityUrl;
    if (bgm != null) result.bgm.addAll(bgm);
    if (staff != null) result.staff.addAll(staff);
    if (argueMsg != null) result.argueMsg = argueMsg;
    if (shortLink != null) result.shortLink = shortLink;
    if (playParam != null) result.playParam = playParam;
    if (label != null) result.label = label;
    if (ugcSeason != null) result.ugcSeason = ugcSeason;
    if (config != null) result.config = config;
    if (shareSubtitle != null) result.shareSubtitle = shareSubtitle;
    if (interaction != null) result.interaction = interaction;
    if (ecode != null) result.ecode = ecode;
    if (customConfig != null) result.customConfig = customConfig;
    if (cms != null) result.cms.addAll(cms);
    if (cmConfig != null) result.cmConfig = cmConfig;
    if (tab != null) result.tab = tab;
    if (rank != null) result.rank = rank;
    if (tfPanelCustomized != null) result.tfPanelCustomized = tfPanelCustomized;
    if (upAct != null) result.upAct = upAct;
    if (userGarb != null) result.userGarb = userGarb;
    if (activitySeason != null) result.activitySeason = activitySeason;
    if (badgeUrl != null) result.badgeUrl = badgeUrl;
    if (liveOrderInfo != null) result.liveOrderInfo = liveOrderInfo;
    if (descV2 != null) result.descV2.addAll(descV2);
    if (cmIpad != null) result.cmIpad = cmIpad;
    if (sticker != null) result.sticker.addAll(sticker);
    if (upLikeImg != null) result.upLikeImg = upLikeImg;
    if (likeCustom != null) result.likeCustom = likeCustom;
    if (descTag != null) result.descTag.addAll(descTag);
    if (specialCell != null) result.specialCell = specialCell;
    if (online != null) result.online = online;
    if (cmUnderPlayer != null) result.cmUnderPlayer = cmUnderPlayer;
    if (videoSource != null) result.videoSource.addAll(videoSource);
    if (specialCellNew != null) result.specialCellNew.addAll(specialCellNew);
    if (premiere != null) result.premiere = premiere;
    if (refreshSpecialCell != null)
      result.refreshSpecialCell = refreshSpecialCell;
    if (materialLeft != null) result.materialLeft = materialLeft;
    if (notesCount != null) result.notesCount = notesCount;
    if (pullAction != null) result.pullAction = pullAction;
    if (arcExtra != null) result.arcExtra = arcExtra;
    if (pagination != null) result.pagination = pagination;
    if (likeAnimation != null) result.likeAnimation = likeAnimation;
    if (replyPreface != null) result.replyPreface = replyPreface;
    if (refreshPage != null) result.refreshPage = refreshPage;
    if (coinCustom != null) result.coinCustom = coinCustom;
    return result;
  }

  ViewReply._();

  factory ViewReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewReply()..mergeFromBuffer(data, registry);
  factory ViewReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewReply.$_createMessage)
    ..aOM<$1.Arc>(1, _omitFieldNames ? '' : 'arc',
        subBuilder: $1.Arc.$_createMessage)
    ..pPM<ViewPage>(2, _omitFieldNames ? '' : 'pages',
        subBuilder: ViewPage.$_createMessage)
    ..aOM<OnwerExt>(3, _omitFieldNames ? '' : 'ownerExt',
        subBuilder: OnwerExt.$_createMessage)
    ..aOM<ReqUser>(4, _omitFieldNames ? '' : 'reqUser',
        subBuilder: ReqUser.$_createMessage)
    ..pPM<Tag>(5, _omitFieldNames ? '' : 'tag', subBuilder: Tag.$_createMessage)
    ..m<$core.String, TIcon>(6, _omitFieldNames ? '' : 'tIcon',
        entryClassName: 'ViewReply.TIconEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: TIcon.$_createMessage,
        valueDefaultOrMaker: TIcon.getDefault,
        packageName: const $pb.PackageName('bilibili.app.view.v1'))
    ..aOM<Season>(7, _omitFieldNames ? '' : 'season',
        subBuilder: Season.$_createMessage)
    ..aOM<ElecRank>(8, _omitFieldNames ? '' : 'elecRank',
        subBuilder: ElecRank.$_createMessage)
    ..aOM<History>(9, _omitFieldNames ? '' : 'history',
        subBuilder: History.$_createMessage)
    ..pPM<Relate>(10, _omitFieldNames ? '' : 'relates',
        subBuilder: Relate.$_createMessage)
    ..aOM<Dislike>(11, _omitFieldNames ? '' : 'dislike',
        subBuilder: Dislike.$_createMessage)
    ..aOM<PlayerIcon>(12, _omitFieldNames ? '' : 'playerIcon',
        subBuilder: PlayerIcon.$_createMessage)
    ..aOS(13, _omitFieldNames ? '' : 'vipActive')
    ..aOS(14, _omitFieldNames ? '' : 'bvid')
    ..aOM<Honor>(15, _omitFieldNames ? '' : 'honor',
        subBuilder: Honor.$_createMessage)
    ..pPM<RelateTab>(16, _omitFieldNames ? '' : 'relateTab',
        subBuilder: RelateTab.$_createMessage)
    ..aOS(17, _omitFieldNames ? '' : 'activityUrl')
    ..pPM<Bgm>(18, _omitFieldNames ? '' : 'bgm',
        subBuilder: Bgm.$_createMessage)
    ..pPM<Staff>(19, _omitFieldNames ? '' : 'staff',
        subBuilder: Staff.$_createMessage)
    ..aOS(20, _omitFieldNames ? '' : 'argueMsg')
    ..aOS(21, _omitFieldNames ? '' : 'shortLink')
    ..aI(22, _omitFieldNames ? '' : 'playParam')
    ..aOM<Label>(23, _omitFieldNames ? '' : 'label',
        subBuilder: Label.$_createMessage)
    ..aOM<UgcSeason>(24, _omitFieldNames ? '' : 'ugcSeason',
        subBuilder: UgcSeason.$_createMessage)
    ..aOM<Config>(25, _omitFieldNames ? '' : 'config',
        subBuilder: Config.$_createMessage)
    ..aOS(26, _omitFieldNames ? '' : 'shareSubtitle')
    ..aOM<Interaction>(27, _omitFieldNames ? '' : 'interaction',
        subBuilder: Interaction.$_createMessage)
    ..aE<ECode>(28, _omitFieldNames ? '' : 'ecode', enumValues: ECode.values)
    ..aOM<CustomConfig>(29, _omitFieldNames ? '' : 'customConfig',
        subBuilder: CustomConfig.$_createMessage)
    ..pPM<CM>(30, _omitFieldNames ? '' : 'cms', subBuilder: CM.$_createMessage)
    ..aOM<CMConfig>(31, _omitFieldNames ? '' : 'cmConfig',
        subBuilder: CMConfig.$_createMessage)
    ..aOM<Tab>(32, _omitFieldNames ? '' : 'tab',
        subBuilder: Tab.$_createMessage)
    ..aOM<Rank>(33, _omitFieldNames ? '' : 'rank',
        subBuilder: Rank.$_createMessage)
    ..aOM<TFPanelCustomized>(34, _omitFieldNames ? '' : 'tfPanelCustomized',
        subBuilder: TFPanelCustomized.$_createMessage)
    ..aOM<UpAct>(35, _omitFieldNames ? '' : 'upAct',
        subBuilder: UpAct.$_createMessage)
    ..aOM<UserGarb>(36, _omitFieldNames ? '' : 'userGarb',
        subBuilder: UserGarb.$_createMessage)
    ..aOM<ActivitySeason>(37, _omitFieldNames ? '' : 'activitySeason',
        subBuilder: ActivitySeason.$_createMessage)
    ..aOS(38, _omitFieldNames ? '' : 'badgeUrl')
    ..aOM<LiveOrderInfo>(39, _omitFieldNames ? '' : 'liveOrderInfo',
        subBuilder: LiveOrderInfo.$_createMessage)
    ..pPM<DescV2>(40, _omitFieldNames ? '' : 'descV2',
        subBuilder: DescV2.$_createMessage)
    ..aOM<CmIpad>(41, _omitFieldNames ? '' : 'cmIpad',
        subBuilder: CmIpad.$_createMessage)
    ..pPM<ViewMaterial>(42, _omitFieldNames ? '' : 'sticker',
        subBuilder: ViewMaterial.$_createMessage)
    ..aOM<UpLikeImg>(43, _omitFieldNames ? '' : 'upLikeImg',
        subBuilder: UpLikeImg.$_createMessage)
    ..aOM<LikeCustom>(44, _omitFieldNames ? '' : 'likeCustom',
        subBuilder: LikeCustom.$_createMessage)
    ..pPM<Tag>(45, _omitFieldNames ? '' : 'descTag',
        subBuilder: Tag.$_createMessage)
    ..aOM<SpecialCell>(46, _omitFieldNames ? '' : 'specialCell',
        subBuilder: SpecialCell.$_createMessage)
    ..aOM<Online>(47, _omitFieldNames ? '' : 'online',
        subBuilder: Online.$_createMessage)
    ..aOM<$2.Any>(48, _omitFieldNames ? '' : 'cmUnderPlayer',
        subBuilder: $2.Any.$_createMessage)
    ..pPM<ViewMaterial>(49, _omitFieldNames ? '' : 'videoSource',
        subBuilder: ViewMaterial.$_createMessage)
    ..pPM<SpecialCell>(50, _omitFieldNames ? '' : 'specialCellNew',
        subBuilder: SpecialCell.$_createMessage)
    ..aOM<PremiereResource>(51, _omitFieldNames ? '' : 'premiere',
        subBuilder: PremiereResource.$_createMessage)
    ..aOB(52, _omitFieldNames ? '' : 'refreshSpecialCell')
    ..aOM<MaterialLeft>(53, _omitFieldNames ? '' : 'materialLeft',
        subBuilder: MaterialLeft.$_createMessage)
    ..aInt64(54, _omitFieldNames ? '' : 'notesCount')
    ..aOM<PullClientAction>(55, _omitFieldNames ? '' : 'pullAction',
        subBuilder: PullClientAction.$_createMessage)
    ..aOM<ArcExtra>(56, _omitFieldNames ? '' : 'arcExtra',
        subBuilder: ArcExtra.$_createMessage)
    ..aOM<$4.PaginationReply>(57, _omitFieldNames ? '' : 'pagination',
        subBuilder: $4.PaginationReply.$_createMessage)
    ..aOM<LikeAnimation>(58, _omitFieldNames ? '' : 'likeAnimation',
        subBuilder: LikeAnimation.$_createMessage)
    ..aOM<ReplyStyle>(59, _omitFieldNames ? '' : 'replyPreface',
        subBuilder: ReplyStyle.$_createMessage)
    ..aOM<RefreshPage>(60, _omitFieldNames ? '' : 'refreshPage',
        subBuilder: RefreshPage.$_createMessage)
    ..aOM<CoinCustom>(61, _omitFieldNames ? '' : 'coinCustom',
        subBuilder: CoinCustom.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewReply copyWith(void Function(ViewReply) updates) =>
      super.copyWith((message) => updates(message as ViewReply)) as ViewReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewReply() / ViewReply.new instead')
  static ViewReply create() => ViewReply._();
  static $pb.GeneratedMessage $_createMessage() => ViewReply._();
  @$core.override
  ViewReply createEmptyInstance() => ViewReply._();
  @$core.pragma('dart2js:noInline')
  static ViewReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ViewReply>(ViewReply.$_createMessage);
  static ViewReply? _defaultInstance;

  /// 稿件信息
  @$pb.TagNumber(1)
  $1.Arc get arc => $_getN(0);
  @$pb.TagNumber(1)
  set arc($1.Arc value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasArc() => $_has(0);
  @$pb.TagNumber(1)
  void clearArc() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Arc ensureArc() => $_ensure(0);

  /// 分P信息
  @$pb.TagNumber(2)
  $pb.PbList<ViewPage> get pages => $_getList(1);

  /// UP主扩展信息 ("OnwerExt"为源码中拼写错误)
  @$pb.TagNumber(3)
  OnwerExt get ownerExt => $_getN(2);
  @$pb.TagNumber(3)
  set ownerExt(OnwerExt value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOwnerExt() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwnerExt() => $_clearField(3);
  @$pb.TagNumber(3)
  OnwerExt ensureOwnerExt() => $_ensure(2);

  /// 稿件用户操作状态
  @$pb.TagNumber(4)
  ReqUser get reqUser => $_getN(3);
  @$pb.TagNumber(4)
  set reqUser(ReqUser value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReqUser() => $_has(3);
  @$pb.TagNumber(4)
  void clearReqUser() => $_clearField(4);
  @$pb.TagNumber(4)
  ReqUser ensureReqUser() => $_ensure(3);

  /// 稿件TAG
  @$pb.TagNumber(5)
  $pb.PbList<Tag> get tag => $_getList(4);

  /// TAG对应的图标
  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, TIcon> get tIcon => $_getMap(5);

  /// 稿件映射的PGC剧集信息
  @$pb.TagNumber(7)
  Season get season => $_getN(6);
  @$pb.TagNumber(7)
  set season(Season value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSeason() => $_has(6);
  @$pb.TagNumber(7)
  void clearSeason() => $_clearField(7);
  @$pb.TagNumber(7)
  Season ensureSeason() => $_ensure(6);

  /// 充电排行
  @$pb.TagNumber(8)
  ElecRank get elecRank => $_getN(7);
  @$pb.TagNumber(8)
  set elecRank(ElecRank value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasElecRank() => $_has(7);
  @$pb.TagNumber(8)
  void clearElecRank() => $_clearField(8);
  @$pb.TagNumber(8)
  ElecRank ensureElecRank() => $_ensure(7);

  /// 历史观看进度
  @$pb.TagNumber(9)
  History get history => $_getN(8);
  @$pb.TagNumber(9)
  set history(History value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasHistory() => $_has(8);
  @$pb.TagNumber(9)
  void clearHistory() => $_clearField(9);
  @$pb.TagNumber(9)
  History ensureHistory() => $_ensure(8);

  /// 视频相关推荐列表
  @$pb.TagNumber(10)
  $pb.PbList<Relate> get relates => $_getList(9);

  /// 不感兴趣原因
  @$pb.TagNumber(11)
  Dislike get dislike => $_getN(10);
  @$pb.TagNumber(11)
  set dislike(Dislike value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasDislike() => $_has(10);
  @$pb.TagNumber(11)
  void clearDislike() => $_clearField(11);
  @$pb.TagNumber(11)
  Dislike ensureDislike() => $_ensure(10);

  /// 播放图标动画配置档
  @$pb.TagNumber(12)
  PlayerIcon get playerIcon => $_getN(11);
  @$pb.TagNumber(12)
  set playerIcon(PlayerIcon value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasPlayerIcon() => $_has(11);
  @$pb.TagNumber(12)
  void clearPlayerIcon() => $_clearField(12);
  @$pb.TagNumber(12)
  PlayerIcon ensurePlayerIcon() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.String get vipActive => $_getSZ(12);
  @$pb.TagNumber(13)
  set vipActive($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasVipActive() => $_has(12);
  @$pb.TagNumber(13)
  void clearVipActive() => $_clearField(13);

  /// 稿件bvid
  @$pb.TagNumber(14)
  $core.String get bvid => $_getSZ(13);
  @$pb.TagNumber(14)
  set bvid($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasBvid() => $_has(13);
  @$pb.TagNumber(14)
  void clearBvid() => $_clearField(14);

  /// 获得荣誉信息
  @$pb.TagNumber(15)
  Honor get honor => $_getN(14);
  @$pb.TagNumber(15)
  set honor(Honor value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasHonor() => $_has(14);
  @$pb.TagNumber(15)
  void clearHonor() => $_clearField(15);
  @$pb.TagNumber(15)
  Honor ensureHonor() => $_ensure(14);

  /// 相关推荐顶部tab
  @$pb.TagNumber(16)
  $pb.PbList<RelateTab> get relateTab => $_getList(15);

  /// 参与的活动页面url
  @$pb.TagNumber(17)
  $core.String get activityUrl => $_getSZ(16);
  @$pb.TagNumber(17)
  set activityUrl($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasActivityUrl() => $_has(16);
  @$pb.TagNumber(17)
  void clearActivityUrl() => $_clearField(17);

  /// 稿件引用bgm列表
  @$pb.TagNumber(18)
  $pb.PbList<Bgm> get bgm => $_getList(17);

  /// 联合投稿成员列表
  @$pb.TagNumber(19)
  $pb.PbList<Staff> get staff => $_getList(18);

  /// 争议信息
  @$pb.TagNumber(20)
  $core.String get argueMsg => $_getSZ(19);
  @$pb.TagNumber(20)
  set argueMsg($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasArgueMsg() => $_has(19);
  @$pb.TagNumber(20)
  void clearArgueMsg() => $_clearField(20);

  /// 短链接
  @$pb.TagNumber(21)
  $core.String get shortLink => $_getSZ(20);
  @$pb.TagNumber(21)
  set shortLink($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasShortLink() => $_has(20);
  @$pb.TagNumber(21)
  void clearShortLink() => $_clearField(21);

  /// 播放实验
  /// 1:相关推荐自动播放
  @$pb.TagNumber(22)
  $core.int get playParam => $_getIZ(21);
  @$pb.TagNumber(22)
  set playParam($core.int value) => $_setSignedInt32(21, value);
  @$pb.TagNumber(22)
  $core.bool hasPlayParam() => $_has(21);
  @$pb.TagNumber(22)
  void clearPlayParam() => $_clearField(22);

  /// 标签
  @$pb.TagNumber(23)
  Label get label => $_getN(22);
  @$pb.TagNumber(23)
  set label(Label value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasLabel() => $_has(22);
  @$pb.TagNumber(23)
  void clearLabel() => $_clearField(23);
  @$pb.TagNumber(23)
  Label ensureLabel() => $_ensure(22);

  /// UGC视频合集信息
  @$pb.TagNumber(24)
  UgcSeason get ugcSeason => $_getN(23);
  @$pb.TagNumber(24)
  set ugcSeason(UgcSeason value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasUgcSeason() => $_has(23);
  @$pb.TagNumber(24)
  void clearUgcSeason() => $_clearField(24);
  @$pb.TagNumber(24)
  UgcSeason ensureUgcSeason() => $_ensure(23);

  /// 配置信息
  @$pb.TagNumber(25)
  Config get config => $_getN(24);
  @$pb.TagNumber(25)
  set config(Config value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasConfig() => $_has(24);
  @$pb.TagNumber(25)
  void clearConfig() => $_clearField(25);
  @$pb.TagNumber(25)
  Config ensureConfig() => $_ensure(24);

  /// 分享副标题(已观看xxx次)
  @$pb.TagNumber(26)
  $core.String get shareSubtitle => $_getSZ(25);
  @$pb.TagNumber(26)
  set shareSubtitle($core.String value) => $_setString(25, value);
  @$pb.TagNumber(26)
  $core.bool hasShareSubtitle() => $_has(25);
  @$pb.TagNumber(26)
  void clearShareSubtitle() => $_clearField(26);

  /// 互动视频信息
  @$pb.TagNumber(27)
  Interaction get interaction => $_getN(26);
  @$pb.TagNumber(27)
  set interaction(Interaction value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasInteraction() => $_has(26);
  @$pb.TagNumber(27)
  void clearInteraction() => $_clearField(27);
  @$pb.TagNumber(27)
  Interaction ensureInteraction() => $_ensure(26);

  /// 错误码
  /// DEFAULT:正常 CODE404:视频被UP主删除
  @$pb.TagNumber(28)
  ECode get ecode => $_getN(27);
  @$pb.TagNumber(28)
  set ecode(ECode value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasEcode() => $_has(27);
  @$pb.TagNumber(28)
  void clearEcode() => $_clearField(28);

  /// 404页信息
  @$pb.TagNumber(29)
  CustomConfig get customConfig => $_getN(28);
  @$pb.TagNumber(29)
  set customConfig(CustomConfig value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasCustomConfig() => $_has(28);
  @$pb.TagNumber(29)
  void clearCustomConfig() => $_clearField(29);
  @$pb.TagNumber(29)
  CustomConfig ensureCustomConfig() => $_ensure(28);

  /// 广告
  @$pb.TagNumber(30)
  $pb.PbList<CM> get cms => $_getList(29);

  /// 广告配置
  @$pb.TagNumber(31)
  CMConfig get cmConfig => $_getN(30);
  @$pb.TagNumber(31)
  set cmConfig(CMConfig value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasCmConfig() => $_has(30);
  @$pb.TagNumber(31)
  void clearCmConfig() => $_clearField(31);
  @$pb.TagNumber(31)
  CMConfig ensureCmConfig() => $_ensure(30);

  /// 播放页定制tab
  @$pb.TagNumber(32)
  Tab get tab => $_getN(31);
  @$pb.TagNumber(32)
  set tab(Tab value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasTab() => $_has(31);
  @$pb.TagNumber(32)
  void clearTab() => $_clearField(32);
  @$pb.TagNumber(32)
  Tab ensureTab() => $_ensure(31);

  /// 排行榜
  @$pb.TagNumber(33)
  Rank get rank => $_getN(32);
  @$pb.TagNumber(33)
  set rank(Rank value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasRank() => $_has(32);
  @$pb.TagNumber(33)
  void clearRank() => $_clearField(33);
  @$pb.TagNumber(33)
  Rank ensureRank() => $_ensure(32);

  /// 免流面板定制
  @$pb.TagNumber(34)
  TFPanelCustomized get tfPanelCustomized => $_getN(33);
  @$pb.TagNumber(34)
  set tfPanelCustomized(TFPanelCustomized value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasTfPanelCustomized() => $_has(33);
  @$pb.TagNumber(34)
  void clearTfPanelCustomized() => $_clearField(34);
  @$pb.TagNumber(34)
  TFPanelCustomized ensureTfPanelCustomized() => $_ensure(33);

  /// UP主发起活动
  @$pb.TagNumber(35)
  UpAct get upAct => $_getN(34);
  @$pb.TagNumber(35)
  set upAct(UpAct value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasUpAct() => $_has(34);
  @$pb.TagNumber(35)
  void clearUpAct() => $_clearField(35);
  @$pb.TagNumber(35)
  UpAct ensureUpAct() => $_ensure(34);

  /// 用户装扮
  @$pb.TagNumber(36)
  UserGarb get userGarb => $_getN(35);
  @$pb.TagNumber(36)
  set userGarb(UserGarb value) => $_setField(36, value);
  @$pb.TagNumber(36)
  $core.bool hasUserGarb() => $_has(35);
  @$pb.TagNumber(36)
  void clearUserGarb() => $_clearField(36);
  @$pb.TagNumber(36)
  UserGarb ensureUserGarb() => $_ensure(35);

  /// 大型活动合集
  @$pb.TagNumber(37)
  ActivitySeason get activitySeason => $_getN(36);
  @$pb.TagNumber(37)
  set activitySeason(ActivitySeason value) => $_setField(37, value);
  @$pb.TagNumber(37)
  $core.bool hasActivitySeason() => $_has(36);
  @$pb.TagNumber(37)
  void clearActivitySeason() => $_clearField(37);
  @$pb.TagNumber(37)
  ActivitySeason ensureActivitySeason() => $_ensure(36);

  /// 评论样式
  @$pb.TagNumber(38)
  $core.String get badgeUrl => $_getSZ(37);
  @$pb.TagNumber(38)
  set badgeUrl($core.String value) => $_setString(37, value);
  @$pb.TagNumber(38)
  $core.bool hasBadgeUrl() => $_has(37);
  @$pb.TagNumber(38)
  void clearBadgeUrl() => $_clearField(38);

  /// 直播预约信息
  @$pb.TagNumber(39)
  LiveOrderInfo get liveOrderInfo => $_getN(38);
  @$pb.TagNumber(39)
  set liveOrderInfo(LiveOrderInfo value) => $_setField(39, value);
  @$pb.TagNumber(39)
  $core.bool hasLiveOrderInfo() => $_has(38);
  @$pb.TagNumber(39)
  void clearLiveOrderInfo() => $_clearField(39);
  @$pb.TagNumber(39)
  LiveOrderInfo ensureLiveOrderInfo() => $_ensure(38);

  /// 稿件简介v2
  @$pb.TagNumber(40)
  $pb.PbList<DescV2> get descV2 => $_getList(39);

  @$pb.TagNumber(41)
  CmIpad get cmIpad => $_getN(40);
  @$pb.TagNumber(41)
  set cmIpad(CmIpad value) => $_setField(41, value);
  @$pb.TagNumber(41)
  $core.bool hasCmIpad() => $_has(40);
  @$pb.TagNumber(41)
  void clearCmIpad() => $_clearField(41);
  @$pb.TagNumber(41)
  CmIpad ensureCmIpad() => $_ensure(40);

  @$pb.TagNumber(42)
  $pb.PbList<ViewMaterial> get sticker => $_getList(41);

  @$pb.TagNumber(43)
  UpLikeImg get upLikeImg => $_getN(42);
  @$pb.TagNumber(43)
  set upLikeImg(UpLikeImg value) => $_setField(43, value);
  @$pb.TagNumber(43)
  $core.bool hasUpLikeImg() => $_has(42);
  @$pb.TagNumber(43)
  void clearUpLikeImg() => $_clearField(43);
  @$pb.TagNumber(43)
  UpLikeImg ensureUpLikeImg() => $_ensure(42);

  @$pb.TagNumber(44)
  LikeCustom get likeCustom => $_getN(43);
  @$pb.TagNumber(44)
  set likeCustom(LikeCustom value) => $_setField(44, value);
  @$pb.TagNumber(44)
  $core.bool hasLikeCustom() => $_has(43);
  @$pb.TagNumber(44)
  void clearLikeCustom() => $_clearField(44);
  @$pb.TagNumber(44)
  LikeCustom ensureLikeCustom() => $_ensure(43);

  @$pb.TagNumber(45)
  $pb.PbList<Tag> get descTag => $_getList(44);

  @$pb.TagNumber(46)
  SpecialCell get specialCell => $_getN(45);
  @$pb.TagNumber(46)
  set specialCell(SpecialCell value) => $_setField(46, value);
  @$pb.TagNumber(46)
  $core.bool hasSpecialCell() => $_has(45);
  @$pb.TagNumber(46)
  void clearSpecialCell() => $_clearField(46);
  @$pb.TagNumber(46)
  SpecialCell ensureSpecialCell() => $_ensure(45);

  @$pb.TagNumber(47)
  Online get online => $_getN(46);
  @$pb.TagNumber(47)
  set online(Online value) => $_setField(47, value);
  @$pb.TagNumber(47)
  $core.bool hasOnline() => $_has(46);
  @$pb.TagNumber(47)
  void clearOnline() => $_clearField(47);
  @$pb.TagNumber(47)
  Online ensureOnline() => $_ensure(46);

  @$pb.TagNumber(48)
  $2.Any get cmUnderPlayer => $_getN(47);
  @$pb.TagNumber(48)
  set cmUnderPlayer($2.Any value) => $_setField(48, value);
  @$pb.TagNumber(48)
  $core.bool hasCmUnderPlayer() => $_has(47);
  @$pb.TagNumber(48)
  void clearCmUnderPlayer() => $_clearField(48);
  @$pb.TagNumber(48)
  $2.Any ensureCmUnderPlayer() => $_ensure(47);

  @$pb.TagNumber(49)
  $pb.PbList<ViewMaterial> get videoSource => $_getList(48);

  @$pb.TagNumber(50)
  $pb.PbList<SpecialCell> get specialCellNew => $_getList(49);

  @$pb.TagNumber(51)
  PremiereResource get premiere => $_getN(50);
  @$pb.TagNumber(51)
  set premiere(PremiereResource value) => $_setField(51, value);
  @$pb.TagNumber(51)
  $core.bool hasPremiere() => $_has(50);
  @$pb.TagNumber(51)
  void clearPremiere() => $_clearField(51);
  @$pb.TagNumber(51)
  PremiereResource ensurePremiere() => $_ensure(50);

  @$pb.TagNumber(52)
  $core.bool get refreshSpecialCell => $_getBF(51);
  @$pb.TagNumber(52)
  set refreshSpecialCell($core.bool value) => $_setBool(51, value);
  @$pb.TagNumber(52)
  $core.bool hasRefreshSpecialCell() => $_has(51);
  @$pb.TagNumber(52)
  void clearRefreshSpecialCell() => $_clearField(52);

  @$pb.TagNumber(53)
  MaterialLeft get materialLeft => $_getN(52);
  @$pb.TagNumber(53)
  set materialLeft(MaterialLeft value) => $_setField(53, value);
  @$pb.TagNumber(53)
  $core.bool hasMaterialLeft() => $_has(52);
  @$pb.TagNumber(53)
  void clearMaterialLeft() => $_clearField(53);
  @$pb.TagNumber(53)
  MaterialLeft ensureMaterialLeft() => $_ensure(52);

  @$pb.TagNumber(54)
  $fixnum.Int64 get notesCount => $_getI64(53);
  @$pb.TagNumber(54)
  set notesCount($fixnum.Int64 value) => $_setInt64(53, value);
  @$pb.TagNumber(54)
  $core.bool hasNotesCount() => $_has(53);
  @$pb.TagNumber(54)
  void clearNotesCount() => $_clearField(54);

  @$pb.TagNumber(55)
  PullClientAction get pullAction => $_getN(54);
  @$pb.TagNumber(55)
  set pullAction(PullClientAction value) => $_setField(55, value);
  @$pb.TagNumber(55)
  $core.bool hasPullAction() => $_has(54);
  @$pb.TagNumber(55)
  void clearPullAction() => $_clearField(55);
  @$pb.TagNumber(55)
  PullClientAction ensurePullAction() => $_ensure(54);

  @$pb.TagNumber(56)
  ArcExtra get arcExtra => $_getN(55);
  @$pb.TagNumber(56)
  set arcExtra(ArcExtra value) => $_setField(56, value);
  @$pb.TagNumber(56)
  $core.bool hasArcExtra() => $_has(55);
  @$pb.TagNumber(56)
  void clearArcExtra() => $_clearField(56);
  @$pb.TagNumber(56)
  ArcExtra ensureArcExtra() => $_ensure(55);

  @$pb.TagNumber(57)
  $4.PaginationReply get pagination => $_getN(56);
  @$pb.TagNumber(57)
  set pagination($4.PaginationReply value) => $_setField(57, value);
  @$pb.TagNumber(57)
  $core.bool hasPagination() => $_has(56);
  @$pb.TagNumber(57)
  void clearPagination() => $_clearField(57);
  @$pb.TagNumber(57)
  $4.PaginationReply ensurePagination() => $_ensure(56);

  @$pb.TagNumber(58)
  LikeAnimation get likeAnimation => $_getN(57);
  @$pb.TagNumber(58)
  set likeAnimation(LikeAnimation value) => $_setField(58, value);
  @$pb.TagNumber(58)
  $core.bool hasLikeAnimation() => $_has(57);
  @$pb.TagNumber(58)
  void clearLikeAnimation() => $_clearField(58);
  @$pb.TagNumber(58)
  LikeAnimation ensureLikeAnimation() => $_ensure(57);

  @$pb.TagNumber(59)
  ReplyStyle get replyPreface => $_getN(58);
  @$pb.TagNumber(59)
  set replyPreface(ReplyStyle value) => $_setField(59, value);
  @$pb.TagNumber(59)
  $core.bool hasReplyPreface() => $_has(58);
  @$pb.TagNumber(59)
  void clearReplyPreface() => $_clearField(59);
  @$pb.TagNumber(59)
  ReplyStyle ensureReplyPreface() => $_ensure(58);

  @$pb.TagNumber(60)
  RefreshPage get refreshPage => $_getN(59);
  @$pb.TagNumber(60)
  set refreshPage(RefreshPage value) => $_setField(60, value);
  @$pb.TagNumber(60)
  $core.bool hasRefreshPage() => $_has(59);
  @$pb.TagNumber(60)
  void clearRefreshPage() => $_clearField(60);
  @$pb.TagNumber(60)
  RefreshPage ensureRefreshPage() => $_ensure(59);

  @$pb.TagNumber(61)
  CoinCustom get coinCustom => $_getN(60);
  @$pb.TagNumber(61)
  set coinCustom(CoinCustom value) => $_setField(61, value);
  @$pb.TagNumber(61)
  $core.bool hasCoinCustom() => $_has(60);
  @$pb.TagNumber(61)
  void clearCoinCustom() => $_clearField(61);
  @$pb.TagNumber(61)
  CoinCustom ensureCoinCustom() => $_ensure(60);
}

/// 视频页详情页-请求
class ViewReq extends $pb.GeneratedMessage {
  factory ViewReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $core.String? from,
    $core.String? trackid,
    $core.String? adExtra,
    $core.int? qn,
    $core.int? fnver,
    $core.int? fnval,
    $core.int? forceHost,
    $core.int? fourk,
    $core.String? spmid,
    $core.String? fromSpmid,
    $core.int? autoplay,
    $3.PlayerArgs? playerArgs,
    $core.String? pageVersion,
    $core.String? bizExtra,
    $fixnum.Int64? deviceType,
    $fixnum.Int64? relatesPage,
    $core.String? sessionId,
    $core.int? inFeedPlay,
    $core.String? playMode,
    $4.Pagination? pagination,
    $core.int? refresh,
    $core.int? refreshNum,
  }) {
    final result = ViewReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (from != null) result.from = from;
    if (trackid != null) result.trackid = trackid;
    if (adExtra != null) result.adExtra = adExtra;
    if (qn != null) result.qn = qn;
    if (fnver != null) result.fnver = fnver;
    if (fnval != null) result.fnval = fnval;
    if (forceHost != null) result.forceHost = forceHost;
    if (fourk != null) result.fourk = fourk;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (autoplay != null) result.autoplay = autoplay;
    if (playerArgs != null) result.playerArgs = playerArgs;
    if (pageVersion != null) result.pageVersion = pageVersion;
    if (bizExtra != null) result.bizExtra = bizExtra;
    if (deviceType != null) result.deviceType = deviceType;
    if (relatesPage != null) result.relatesPage = relatesPage;
    if (sessionId != null) result.sessionId = sessionId;
    if (inFeedPlay != null) result.inFeedPlay = inFeedPlay;
    if (playMode != null) result.playMode = playMode;
    if (pagination != null) result.pagination = pagination;
    if (refresh != null) result.refresh = refresh;
    if (refreshNum != null) result.refreshNum = refreshNum;
    return result;
  }

  ViewReq._();

  factory ViewReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewReq()..mergeFromBuffer(data, registry);
  factory ViewReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aOS(3, _omitFieldNames ? '' : 'from')
    ..aOS(4, _omitFieldNames ? '' : 'trackid')
    ..aOS(5, _omitFieldNames ? '' : 'adExtra')
    ..aI(6, _omitFieldNames ? '' : 'qn')
    ..aI(7, _omitFieldNames ? '' : 'fnver')
    ..aI(8, _omitFieldNames ? '' : 'fnval')
    ..aI(9, _omitFieldNames ? '' : 'forceHost')
    ..aI(10, _omitFieldNames ? '' : 'fourk')
    ..aOS(11, _omitFieldNames ? '' : 'spmid')
    ..aOS(12, _omitFieldNames ? '' : 'fromSpmid')
    ..aI(13, _omitFieldNames ? '' : 'autoplay')
    ..aOM<$3.PlayerArgs>(14, _omitFieldNames ? '' : 'playerArgs',
        subBuilder: $3.PlayerArgs.$_createMessage)
    ..aOS(15, _omitFieldNames ? '' : 'pageVersion')
    ..aOS(16, _omitFieldNames ? '' : 'bizExtra')
    ..aInt64(17, _omitFieldNames ? '' : 'deviceType')
    ..aInt64(18, _omitFieldNames ? '' : 'relatesPage')
    ..aOS(19, _omitFieldNames ? '' : 'sessionId')
    ..aI(20, _omitFieldNames ? '' : 'inFeedPlay')
    ..aOS(21, _omitFieldNames ? '' : 'playMode')
    ..aOM<$4.Pagination>(22, _omitFieldNames ? '' : 'pagination',
        subBuilder: $4.Pagination.$_createMessage)
    ..aI(23, _omitFieldNames ? '' : 'refresh')
    ..aI(24, _omitFieldNames ? '' : 'refreshNum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewReq copyWith(void Function(ViewReq) updates) =>
      super.copyWith((message) => updates(message as ViewReq)) as ViewReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewReq() / ViewReq.new instead')
  static ViewReq create() => ViewReq._();
  static $pb.GeneratedMessage $_createMessage() => ViewReq._();
  @$core.override
  ViewReq createEmptyInstance() => ViewReq._();
  @$core.pragma('dart2js:noInline')
  static ViewReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ViewReq>(ViewReq.$_createMessage);
  static ViewReq? _defaultInstance;

  /// 稿件avid(av/bv任选其一)
  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  /// 稿件bvid(av/bv任选其一)
  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  /// 来源
  @$pb.TagNumber(3)
  $core.String get from => $_getSZ(2);
  @$pb.TagNumber(3)
  set from($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  /// AI trackid
  @$pb.TagNumber(4)
  $core.String get trackid => $_getSZ(3);
  @$pb.TagNumber(4)
  set trackid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTrackid() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrackid() => $_clearField(4);

  /// 广告扩展数据
  @$pb.TagNumber(5)
  $core.String get adExtra => $_getSZ(4);
  @$pb.TagNumber(5)
  set adExtra($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAdExtra() => $_has(4);
  @$pb.TagNumber(5)
  void clearAdExtra() => $_clearField(5);

  /// 清晰度(旧版)
  @$pb.TagNumber(6)
  $core.int get qn => $_getIZ(5);
  @$pb.TagNumber(6)
  set qn($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasQn() => $_has(5);
  @$pb.TagNumber(6)
  void clearQn() => $_clearField(6);

  /// 流版本(旧版)
  @$pb.TagNumber(7)
  $core.int get fnver => $_getIZ(6);
  @$pb.TagNumber(7)
  set fnver($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFnver() => $_has(6);
  @$pb.TagNumber(7)
  void clearFnver() => $_clearField(7);

  /// 流类型(旧版)
  @$pb.TagNumber(8)
  $core.int get fnval => $_getIZ(7);
  @$pb.TagNumber(8)
  set fnval($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFnval() => $_has(7);
  @$pb.TagNumber(8)
  void clearFnval() => $_clearField(8);

  /// 是否强制使用域名(旧版)
  @$pb.TagNumber(9)
  $core.int get forceHost => $_getIZ(8);
  @$pb.TagNumber(9)
  set forceHost($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasForceHost() => $_has(8);
  @$pb.TagNumber(9)
  void clearForceHost() => $_clearField(9);

  /// 是否允许4K(旧版)
  @$pb.TagNumber(10)
  $core.int get fourk => $_getIZ(9);
  @$pb.TagNumber(10)
  set fourk($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasFourk() => $_has(9);
  @$pb.TagNumber(10)
  void clearFourk() => $_clearField(10);

  /// 当前页面spm
  @$pb.TagNumber(11)
  $core.String get spmid => $_getSZ(10);
  @$pb.TagNumber(11)
  set spmid($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSpmid() => $_has(10);
  @$pb.TagNumber(11)
  void clearSpmid() => $_clearField(11);

  /// 上一页面spm
  @$pb.TagNumber(12)
  $core.String get fromSpmid => $_getSZ(11);
  @$pb.TagNumber(12)
  set fromSpmid($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasFromSpmid() => $_has(11);
  @$pb.TagNumber(12)
  void clearFromSpmid() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get autoplay => $_getIZ(12);
  @$pb.TagNumber(13)
  set autoplay($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAutoplay() => $_has(12);
  @$pb.TagNumber(13)
  void clearAutoplay() => $_clearField(13);

  /// 视频秒开参数
  @$pb.TagNumber(14)
  $3.PlayerArgs get playerArgs => $_getN(13);
  @$pb.TagNumber(14)
  set playerArgs($3.PlayerArgs value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasPlayerArgs() => $_has(13);
  @$pb.TagNumber(14)
  void clearPlayerArgs() => $_clearField(14);
  @$pb.TagNumber(14)
  $3.PlayerArgs ensurePlayerArgs() => $_ensure(13);

  @$pb.TagNumber(15)
  $core.String get pageVersion => $_getSZ(14);
  @$pb.TagNumber(15)
  set pageVersion($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasPageVersion() => $_has(14);
  @$pb.TagNumber(15)
  void clearPageVersion() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get bizExtra => $_getSZ(15);
  @$pb.TagNumber(16)
  set bizExtra($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasBizExtra() => $_has(15);
  @$pb.TagNumber(16)
  void clearBizExtra() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get deviceType => $_getI64(16);
  @$pb.TagNumber(17)
  set deviceType($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasDeviceType() => $_has(16);
  @$pb.TagNumber(17)
  void clearDeviceType() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get relatesPage => $_getI64(17);
  @$pb.TagNumber(18)
  set relatesPage($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasRelatesPage() => $_has(17);
  @$pb.TagNumber(18)
  void clearRelatesPage() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get sessionId => $_getSZ(18);
  @$pb.TagNumber(19)
  set sessionId($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasSessionId() => $_has(18);
  @$pb.TagNumber(19)
  void clearSessionId() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.int get inFeedPlay => $_getIZ(19);
  @$pb.TagNumber(20)
  set inFeedPlay($core.int value) => $_setSignedInt32(19, value);
  @$pb.TagNumber(20)
  $core.bool hasInFeedPlay() => $_has(19);
  @$pb.TagNumber(20)
  void clearInFeedPlay() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get playMode => $_getSZ(20);
  @$pb.TagNumber(21)
  set playMode($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasPlayMode() => $_has(20);
  @$pb.TagNumber(21)
  void clearPlayMode() => $_clearField(21);

  @$pb.TagNumber(22)
  $4.Pagination get pagination => $_getN(21);
  @$pb.TagNumber(22)
  set pagination($4.Pagination value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasPagination() => $_has(21);
  @$pb.TagNumber(22)
  void clearPagination() => $_clearField(22);
  @$pb.TagNumber(22)
  $4.Pagination ensurePagination() => $_ensure(21);

  @$pb.TagNumber(23)
  $core.int get refresh => $_getIZ(22);
  @$pb.TagNumber(23)
  set refresh($core.int value) => $_setSignedInt32(22, value);
  @$pb.TagNumber(23)
  $core.bool hasRefresh() => $_has(22);
  @$pb.TagNumber(23)
  void clearRefresh() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.int get refreshNum => $_getIZ(23);
  @$pb.TagNumber(24)
  set refreshNum($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(24)
  $core.bool hasRefreshNum() => $_has(23);
  @$pb.TagNumber(24)
  void clearRefreshNum() => $_clearField(24);
}

class ViewTagReply extends $pb.GeneratedMessage {
  factory ViewTagReply({
    $core.Iterable<SpecialCell>? specialCellNew,
    MaterialLeft? materialLeft,
  }) {
    final result = ViewTagReply._();
    if (specialCellNew != null) result.specialCellNew.addAll(specialCellNew);
    if (materialLeft != null) result.materialLeft = materialLeft;
    return result;
  }

  ViewTagReply._();

  factory ViewTagReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewTagReply()..mergeFromBuffer(data, registry);
  factory ViewTagReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewTagReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewTagReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewTagReply.$_createMessage)
    ..pPM<SpecialCell>(1, _omitFieldNames ? '' : 'specialCellNew',
        subBuilder: SpecialCell.$_createMessage)
    ..aOM<MaterialLeft>(2, _omitFieldNames ? '' : 'materialLeft',
        subBuilder: MaterialLeft.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewTagReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewTagReply copyWith(void Function(ViewTagReply) updates) =>
      super.copyWith((message) => updates(message as ViewTagReply))
          as ViewTagReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewTagReply() / ViewTagReply.new instead')
  static ViewTagReply create() => ViewTagReply._();
  static $pb.GeneratedMessage $_createMessage() => ViewTagReply._();
  @$core.override
  ViewTagReply createEmptyInstance() => ViewTagReply._();
  @$core.pragma('dart2js:noInline')
  static ViewTagReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ViewTagReply>(
          ViewTagReply.$_createMessage);
  static ViewTagReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SpecialCell> get specialCellNew => $_getList(0);

  @$pb.TagNumber(2)
  MaterialLeft get materialLeft => $_getN(1);
  @$pb.TagNumber(2)
  set materialLeft(MaterialLeft value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMaterialLeft() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaterialLeft() => $_clearField(2);
  @$pb.TagNumber(2)
  MaterialLeft ensureMaterialLeft() => $_ensure(1);
}

class ViewTagReq extends $pb.GeneratedMessage {
  factory ViewTagReq({
    $fixnum.Int64? aid,
    $core.String? bvid,
    $fixnum.Int64? cid,
    $core.String? spmid,
  }) {
    final result = ViewTagReq._();
    if (aid != null) result.aid = aid;
    if (bvid != null) result.bvid = bvid;
    if (cid != null) result.cid = cid;
    if (spmid != null) result.spmid = spmid;
    return result;
  }

  ViewTagReq._();

  factory ViewTagReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewTagReq()..mergeFromBuffer(data, registry);
  factory ViewTagReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ViewTagReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewTagReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: ViewTagReq.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'aid')
    ..aOS(2, _omitFieldNames ? '' : 'bvid')
    ..aInt64(3, _omitFieldNames ? '' : 'cid')
    ..aOS(4, _omitFieldNames ? '' : 'spmid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewTagReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewTagReq copyWith(void Function(ViewTagReq) updates) =>
      super.copyWith((message) => updates(message as ViewTagReq)) as ViewTagReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ViewTagReq() / ViewTagReq.new instead')
  static ViewTagReq create() => ViewTagReq._();
  static $pb.GeneratedMessage $_createMessage() => ViewTagReq._();
  @$core.override
  ViewTagReq createEmptyInstance() => ViewTagReq._();
  @$core.pragma('dart2js:noInline')
  static ViewTagReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ViewTagReq>(ViewTagReq.$_createMessage);
  static ViewTagReq? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get aid => $_getI64(0);
  @$pb.TagNumber(1)
  set aid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bvid => $_getSZ(1);
  @$pb.TagNumber(2)
  set bvid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBvid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBvid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get cid => $_getI64(2);
  @$pb.TagNumber(3)
  set cid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCid() => $_has(2);
  @$pb.TagNumber(3)
  void clearCid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get spmid => $_getSZ(3);
  @$pb.TagNumber(4)
  set spmid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpmid() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpmid() => $_clearField(4);
}

/// 会员信息
class Vip extends $pb.GeneratedMessage {
  factory Vip({
    $core.int? type,
    $fixnum.Int64? dueDate,
    $core.String? dueRemark,
    $core.int? accessStatus,
    $core.int? vipStatus,
    $core.String? vipStatusWarn,
    $core.int? themeType,
    VipLabel? label,
  }) {
    final result = Vip._();
    if (type != null) result.type = type;
    if (dueDate != null) result.dueDate = dueDate;
    if (dueRemark != null) result.dueRemark = dueRemark;
    if (accessStatus != null) result.accessStatus = accessStatus;
    if (vipStatus != null) result.vipStatus = vipStatus;
    if (vipStatusWarn != null) result.vipStatusWarn = vipStatusWarn;
    if (themeType != null) result.themeType = themeType;
    if (label != null) result.label = label;
    return result;
  }

  Vip._();

  factory Vip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Vip()..mergeFromBuffer(data, registry);
  factory Vip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Vip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Vip',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: Vip.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aInt64(2, _omitFieldNames ? '' : 'dueDate')
    ..aOS(3, _omitFieldNames ? '' : 'dueRemark')
    ..aI(4, _omitFieldNames ? '' : 'accessStatus')
    ..aI(5, _omitFieldNames ? '' : 'vipStatus')
    ..aOS(6, _omitFieldNames ? '' : 'vipStatusWarn')
    ..aI(7, _omitFieldNames ? '' : 'themeType')
    ..aOM<VipLabel>(8, _omitFieldNames ? '' : 'label',
        subBuilder: VipLabel.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Vip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Vip copyWith(void Function(Vip) updates) =>
      super.copyWith((message) => updates(message as Vip)) as Vip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Vip() / Vip.new instead')
  static Vip create() => Vip._();
  static $pb.GeneratedMessage $_createMessage() => Vip._();
  @$core.override
  Vip createEmptyInstance() => Vip._();
  @$core.pragma('dart2js:noInline')
  static Vip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Vip>(Vip.$_createMessage);
  static Vip? _defaultInstance;

  /// 会员类型
  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// 到期时间
  @$pb.TagNumber(2)
  $fixnum.Int64 get dueDate => $_getI64(1);
  @$pb.TagNumber(2)
  set dueDate($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDueDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearDueDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get dueRemark => $_getSZ(2);
  @$pb.TagNumber(3)
  set dueRemark($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDueRemark() => $_has(2);
  @$pb.TagNumber(3)
  void clearDueRemark() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get accessStatus => $_getIZ(3);
  @$pb.TagNumber(4)
  set accessStatus($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAccessStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearAccessStatus() => $_clearField(4);

  /// 会员状态
  @$pb.TagNumber(5)
  $core.int get vipStatus => $_getIZ(4);
  @$pb.TagNumber(5)
  set vipStatus($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVipStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearVipStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get vipStatusWarn => $_getSZ(5);
  @$pb.TagNumber(6)
  set vipStatusWarn($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVipStatusWarn() => $_has(5);
  @$pb.TagNumber(6)
  void clearVipStatusWarn() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get themeType => $_getIZ(6);
  @$pb.TagNumber(7)
  set themeType($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasThemeType() => $_has(6);
  @$pb.TagNumber(7)
  void clearThemeType() => $_clearField(7);

  @$pb.TagNumber(8)
  VipLabel get label => $_getN(7);
  @$pb.TagNumber(8)
  set label(VipLabel value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasLabel() => $_has(7);
  @$pb.TagNumber(8)
  void clearLabel() => $_clearField(8);
  @$pb.TagNumber(8)
  VipLabel ensureLabel() => $_ensure(7);
}

/// 会员类型标签
class VipLabel extends $pb.GeneratedMessage {
  factory VipLabel({
    $core.String? path,
    $core.String? text,
    $core.String? labelTheme,
  }) {
    final result = VipLabel._();
    if (path != null) result.path = path;
    if (text != null) result.text = text;
    if (labelTheme != null) result.labelTheme = labelTheme;
    return result;
  }

  VipLabel._();

  factory VipLabel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VipLabel()..mergeFromBuffer(data, registry);
  factory VipLabel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VipLabel()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VipLabel',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.view.v1'),
      createEmptyInstance: VipLabel.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aOS(3, _omitFieldNames ? '' : 'labelTheme')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VipLabel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VipLabel copyWith(void Function(VipLabel) updates) =>
      super.copyWith((message) => updates(message as VipLabel)) as VipLabel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VipLabel() / VipLabel.new instead')
  static VipLabel create() => VipLabel._();
  static $pb.GeneratedMessage $_createMessage() => VipLabel._();
  @$core.override
  VipLabel createEmptyInstance() => VipLabel._();
  @$core.pragma('dart2js:noInline')
  static VipLabel getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VipLabel>(VipLabel.$_createMessage);
  static VipLabel? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get labelTheme => $_getSZ(2);
  @$pb.TagNumber(3)
  set labelTheme($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLabelTheme() => $_has(2);
  @$pb.TagNumber(3)
  void clearLabelTheme() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
