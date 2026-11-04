// This is a generated file - do not edit.
//
// Generated from bilibili/playershared/playershared.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ArcType extends $pb.ProtobufEnum {
  static const ArcType ARC_TYPE_NORMAL =
      ArcType._(0, _omitEnumNames ? '' : 'ARC_TYPE_NORMAL');
  static const ArcType ARC_TYPE_INTERACT =
      ArcType._(1, _omitEnumNames ? '' : 'ARC_TYPE_INTERACT');

  static const $core.List<ArcType> values = <ArcType>[
    ARC_TYPE_NORMAL,
    ARC_TYPE_INTERACT,
  ];

  static final $core.List<ArcType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ArcType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ArcType._(super.value, super.name);
}

class BizType extends $pb.ProtobufEnum {
  static const BizType BIZ_TYPE_UNKNOWN =
      BizType._(0, _omitEnumNames ? '' : 'BIZ_TYPE_UNKNOWN');
  static const BizType BIZ_TYPE_UGC =
      BizType._(1, _omitEnumNames ? '' : 'BIZ_TYPE_UGC');
  static const BizType BIZ_TYPE_PGC =
      BizType._(2, _omitEnumNames ? '' : 'BIZ_TYPE_PGC');
  static const BizType BIZ_TYPE_PUGV =
      BizType._(3, _omitEnumNames ? '' : 'BIZ_TYPE_PUGV');

  static const $core.List<BizType> values = <BizType>[
    BIZ_TYPE_UNKNOWN,
    BIZ_TYPE_UGC,
    BIZ_TYPE_PGC,
    BIZ_TYPE_PUGV,
  ];

  static final $core.List<BizType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static BizType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BizType._(super.value, super.name);
}

class ButtonAction extends $pb.ProtobufEnum {
  static const ButtonAction BUTTON_UNKNOWN =
      ButtonAction._(0, _omitEnumNames ? '' : 'BUTTON_UNKNOWN');
  static const ButtonAction PAY =
      ButtonAction._(1, _omitEnumNames ? '' : 'PAY');
  static const ButtonAction VIP =
      ButtonAction._(2, _omitEnumNames ? '' : 'VIP');
  static const ButtonAction PACK =
      ButtonAction._(3, _omitEnumNames ? '' : 'PACK');
  static const ButtonAction LINK =
      ButtonAction._(4, _omitEnumNames ? '' : 'LINK');
  static const ButtonAction COUPON =
      ButtonAction._(5, _omitEnumNames ? '' : 'COUPON');
  static const ButtonAction DEMAND =
      ButtonAction._(6, _omitEnumNames ? '' : 'DEMAND');
  static const ButtonAction DEMAND_PACK =
      ButtonAction._(7, _omitEnumNames ? '' : 'DEMAND_PACK');
  static const ButtonAction FOLLOW =
      ButtonAction._(8, _omitEnumNames ? '' : 'FOLLOW');
  static const ButtonAction APPOINTMENT =
      ButtonAction._(9, _omitEnumNames ? '' : 'APPOINTMENT');
  static const ButtonAction VIP_FREE =
      ButtonAction._(10, _omitEnumNames ? '' : 'VIP_FREE');
  static const ButtonAction TASK =
      ButtonAction._(11, _omitEnumNames ? '' : 'TASK');
  static const ButtonAction CHARGINGPLUS =
      ButtonAction._(12, _omitEnumNames ? '' : 'CHARGINGPLUS');
  static const ButtonAction BP = ButtonAction._(13, _omitEnumNames ? '' : 'BP');
  static const ButtonAction PRE_SELL =
      ButtonAction._(14, _omitEnumNames ? '' : 'PRE_SELL');

  static const $core.List<ButtonAction> values = <ButtonAction>[
    BUTTON_UNKNOWN,
    PAY,
    VIP,
    PACK,
    LINK,
    COUPON,
    DEMAND,
    DEMAND_PACK,
    FOLLOW,
    APPOINTMENT,
    VIP_FREE,
    TASK,
    CHARGINGPLUS,
    BP,
    PRE_SELL,
  ];

  static final $core.List<ButtonAction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static ButtonAction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ButtonAction._(super.value, super.name);
}

/// 视频编码
class CodeType extends $pb.ProtobufEnum {
  static const CodeType NOCODE = CodeType._(0, _omitEnumNames ? '' : 'NOCODE');
  static const CodeType CODE264 =
      CodeType._(1, _omitEnumNames ? '' : 'CODE264');
  static const CodeType CODE265 =
      CodeType._(2, _omitEnumNames ? '' : 'CODE265');
  static const CodeType CODEAV1 =
      CodeType._(3, _omitEnumNames ? '' : 'CODEAV1');

  static const $core.List<CodeType> values = <CodeType>[
    NOCODE,
    CODE264,
    CODE265,
    CODEAV1,
  ];

  static final $core.List<CodeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CodeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CodeType._(super.value, super.name);
}

/// 功能类型
class ConfType extends $pb.ProtobufEnum {
  static const ConfType NoType = ConfType._(0, _omitEnumNames ? '' : 'NoType');
  static const ConfType FLIPCONF =
      ConfType._(1, _omitEnumNames ? '' : 'FLIPCONF');
  static const ConfType CASTCONF =
      ConfType._(2, _omitEnumNames ? '' : 'CASTCONF');
  static const ConfType FEEDBACK =
      ConfType._(3, _omitEnumNames ? '' : 'FEEDBACK');
  static const ConfType SUBTITLE =
      ConfType._(4, _omitEnumNames ? '' : 'SUBTITLE');
  static const ConfType PLAYBACKRATE =
      ConfType._(5, _omitEnumNames ? '' : 'PLAYBACKRATE');
  static const ConfType TIMEUP = ConfType._(6, _omitEnumNames ? '' : 'TIMEUP');
  static const ConfType PLAYBACKMODE =
      ConfType._(7, _omitEnumNames ? '' : 'PLAYBACKMODE');
  static const ConfType SCALEMODE =
      ConfType._(8, _omitEnumNames ? '' : 'SCALEMODE');
  static const ConfType BACKGROUNDPLAY =
      ConfType._(9, _omitEnumNames ? '' : 'BACKGROUNDPLAY');
  static const ConfType LIKE = ConfType._(10, _omitEnumNames ? '' : 'LIKE');
  static const ConfType DISLIKE =
      ConfType._(11, _omitEnumNames ? '' : 'DISLIKE');
  static const ConfType COIN = ConfType._(12, _omitEnumNames ? '' : 'COIN');
  static const ConfType ELEC = ConfType._(13, _omitEnumNames ? '' : 'ELEC');
  static const ConfType SHARE = ConfType._(14, _omitEnumNames ? '' : 'SHARE');
  static const ConfType SCREENSHOT =
      ConfType._(15, _omitEnumNames ? '' : 'SCREENSHOT');
  static const ConfType LOCKSCREEN =
      ConfType._(16, _omitEnumNames ? '' : 'LOCKSCREEN');
  static const ConfType RECOMMEND =
      ConfType._(17, _omitEnumNames ? '' : 'RECOMMEND');
  static const ConfType PLAYBACKSPEED =
      ConfType._(18, _omitEnumNames ? '' : 'PLAYBACKSPEED');
  static const ConfType DEFINITION =
      ConfType._(19, _omitEnumNames ? '' : 'DEFINITION');
  static const ConfType SELECTIONS =
      ConfType._(20, _omitEnumNames ? '' : 'SELECTIONS');
  static const ConfType NEXT = ConfType._(21, _omitEnumNames ? '' : 'NEXT');
  static const ConfType EDITDM = ConfType._(22, _omitEnumNames ? '' : 'EDITDM');
  static const ConfType SMALLWINDOW =
      ConfType._(23, _omitEnumNames ? '' : 'SMALLWINDOW');
  static const ConfType SHAKE = ConfType._(24, _omitEnumNames ? '' : 'SHAKE');
  static const ConfType OUTERDM =
      ConfType._(25, _omitEnumNames ? '' : 'OUTERDM');
  static const ConfType INNERDM =
      ConfType._(26, _omitEnumNames ? '' : 'INNERDM');
  static const ConfType PANORAMA =
      ConfType._(27, _omitEnumNames ? '' : 'PANORAMA');
  static const ConfType DOLBY = ConfType._(28, _omitEnumNames ? '' : 'DOLBY');
  static const ConfType COLORFILTER =
      ConfType._(29, _omitEnumNames ? '' : 'COLORFILTER');
  static const ConfType LOSSLESS =
      ConfType._(30, _omitEnumNames ? '' : 'LOSSLESS');
  static const ConfType FREYAENTER =
      ConfType._(31, _omitEnumNames ? '' : 'FREYAENTER');
  static const ConfType FREYAFULLENTER =
      ConfType._(32, _omitEnumNames ? '' : 'FREYAFULLENTER');
  static const ConfType SKIPOPED =
      ConfType._(33, _omitEnumNames ? '' : 'SKIPOPED');
  static const ConfType RECORDSCREEN =
      ConfType._(34, _omitEnumNames ? '' : 'RECORDSCREEN');
  static const ConfType DUBBING =
      ConfType._(35, _omitEnumNames ? '' : 'DUBBING');
  static const ConfType LISTEN = ConfType._(36, _omitEnumNames ? '' : 'LISTEN');

  static const $core.List<ConfType> values = <ConfType>[
    NoType,
    FLIPCONF,
    CASTCONF,
    FEEDBACK,
    SUBTITLE,
    PLAYBACKRATE,
    TIMEUP,
    PLAYBACKMODE,
    SCALEMODE,
    BACKGROUNDPLAY,
    LIKE,
    DISLIKE,
    COIN,
    ELEC,
    SHARE,
    SCREENSHOT,
    LOCKSCREEN,
    RECOMMEND,
    PLAYBACKSPEED,
    DEFINITION,
    SELECTIONS,
    NEXT,
    EDITDM,
    SMALLWINDOW,
    SHAKE,
    OUTERDM,
    INNERDM,
    PANORAMA,
    DOLBY,
    COLORFILTER,
    LOSSLESS,
    FREYAENTER,
    FREYAFULLENTER,
    SKIPOPED,
    RECORDSCREEN,
    DUBBING,
    LISTEN,
  ];

  static final $core.List<ConfType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 36);
  static ConfType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ConfType._(super.value, super.name);
}

/// DRM类型
class DrmTechType extends $pb.ProtobufEnum {
  static const DrmTechType UNKNOWN_DRM =
      DrmTechType._(0, _omitEnumNames ? '' : 'UNKNOWN_DRM');
  static const DrmTechType FAIR_PLAY =
      DrmTechType._(1, _omitEnumNames ? '' : 'FAIR_PLAY');
  static const DrmTechType WIDE_VINE =
      DrmTechType._(2, _omitEnumNames ? '' : 'WIDE_VINE');

  /// 哔哩哔哩自研DRM
  static const DrmTechType BILI_DRM =
      DrmTechType._(3, _omitEnumNames ? '' : 'BILI_DRM');

  static const $core.List<DrmTechType> values = <DrmTechType>[
    UNKNOWN_DRM,
    FAIR_PLAY,
    WIDE_VINE,
    BILI_DRM,
  ];

  static final $core.List<DrmTechType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static DrmTechType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DrmTechType._(super.value, super.name);
}

class Effects extends $pb.ProtobufEnum {
  static const Effects EFFECTS_UNKNOWN =
      Effects._(0, _omitEnumNames ? '' : 'EFFECTS_UNKNOWN');
  static const Effects GAUSSIAN_BLUR =
      Effects._(1, _omitEnumNames ? '' : 'GAUSSIAN_BLUR');
  static const Effects HALF_ALPHA =
      Effects._(2, _omitEnumNames ? '' : 'HALF_ALPHA');

  static const $core.List<Effects> values = <Effects>[
    EFFECTS_UNKNOWN,
    GAUSSIAN_BLUR,
    HALF_ALPHA,
  ];

  static final $core.List<Effects?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Effects? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Effects._(super.value, super.name);
}

class ExtDataType extends $pb.ProtobufEnum {
  static const ExtDataType EXT_DATA_TYPE_UNKNOWN =
      ExtDataType._(0, _omitEnumNames ? '' : 'EXT_DATA_TYPE_UNKNOWN');
  static const ExtDataType PLAY_LIST =
      ExtDataType._(1, _omitEnumNames ? '' : 'PLAY_LIST');

  static const $core.List<ExtDataType> values = <ExtDataType>[
    EXT_DATA_TYPE_UNKNOWN,
    PLAY_LIST,
  ];

  static final $core.List<ExtDataType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ExtDataType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExtDataType._(super.value, super.name);
}

class GuideStyle extends $pb.ProtobufEnum {
  static const GuideStyle STYLE_UNKNOWN =
      GuideStyle._(0, _omitEnumNames ? '' : 'STYLE_UNKNOWN');
  static const GuideStyle HORIZONTAL_IMAGE =
      GuideStyle._(1, _omitEnumNames ? '' : 'HORIZONTAL_IMAGE');
  static const GuideStyle VERTICAL_TEXT =
      GuideStyle._(2, _omitEnumNames ? '' : 'VERTICAL_TEXT');
  static const GuideStyle SIMPLE_TEXT =
      GuideStyle._(3, _omitEnumNames ? '' : 'SIMPLE_TEXT');
  static const GuideStyle CHARGING_TEXT =
      GuideStyle._(4, _omitEnumNames ? '' : 'CHARGING_TEXT');

  static const $core.List<GuideStyle> values = <GuideStyle>[
    STYLE_UNKNOWN,
    HORIZONTAL_IMAGE,
    VERTICAL_TEXT,
    SIMPLE_TEXT,
    CHARGING_TEXT,
  ];

  static final $core.List<GuideStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static GuideStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GuideStyle._(super.value, super.name);
}

class LimitActionType extends $pb.ProtobufEnum {
  static const LimitActionType LAT_UNKNOWN =
      LimitActionType._(0, _omitEnumNames ? '' : 'LAT_UNKNOWN');
  static const LimitActionType SHOW_LIMIT_DIALOG =
      LimitActionType._(1, _omitEnumNames ? '' : 'SHOW_LIMIT_DIALOG');
  static const LimitActionType SKIP_CURRENT_EP =
      LimitActionType._(2, _omitEnumNames ? '' : 'SKIP_CURRENT_EP');

  static const $core.List<LimitActionType> values = <LimitActionType>[
    LAT_UNKNOWN,
    SHOW_LIMIT_DIALOG,
    SKIP_CURRENT_EP,
  ];

  static final $core.List<LimitActionType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static LimitActionType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LimitActionType._(super.value, super.name);
}

/// 错误码
class PlayErr extends $pb.ProtobufEnum {
  static const PlayErr NoErr = PlayErr._(0, _omitEnumNames ? '' : 'NoErr');
  static const PlayErr WithMultiDeviceLoginErr =
      PlayErr._(1, _omitEnumNames ? '' : 'WithMultiDeviceLoginErr');

  static const $core.List<PlayErr> values = <PlayErr>[
    NoErr,
    WithMultiDeviceLoginErr,
  ];

  static final $core.List<PlayErr?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PlayErr? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlayErr._(super.value, super.name);
}

class ShowStyleType extends $pb.ProtobufEnum {
  static const ShowStyleType SHOW_STYLE_TYPE_UNKNOWN =
      ShowStyleType._(0, _omitEnumNames ? '' : 'SHOW_STYLE_TYPE_UNKNOWN');
  static const ShowStyleType SHOW_STYLE_TYPE_ORDINARY =
      ShowStyleType._(1, _omitEnumNames ? '' : 'SHOW_STYLE_TYPE_ORDINARY');
  static const ShowStyleType SHOW_STYLE_TYPE_RESIDENT =
      ShowStyleType._(2, _omitEnumNames ? '' : 'SHOW_STYLE_TYPE_RESIDENT');

  static const $core.List<ShowStyleType> values = <ShowStyleType>[
    SHOW_STYLE_TYPE_UNKNOWN,
    SHOW_STYLE_TYPE_ORDINARY,
    SHOW_STYLE_TYPE_RESIDENT,
  ];

  static final $core.List<ShowStyleType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ShowStyleType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ShowStyleType._(super.value, super.name);
}

class ToastType extends $pb.ProtobufEnum {
  static const ToastType TOAST_TYPE_UNKNOWN =
      ToastType._(0, _omitEnumNames ? '' : 'TOAST_TYPE_UNKNOWN');
  static const ToastType VIP_CONTENT_REMIND =
      ToastType._(1, _omitEnumNames ? '' : 'VIP_CONTENT_REMIND');
  static const ToastType VIP_DEFINITION_REMIND =
      ToastType._(2, _omitEnumNames ? '' : 'VIP_DEFINITION_REMIND');
  static const ToastType VIP_DEFINITION_GUIDE =
      ToastType._(3, _omitEnumNames ? '' : 'VIP_DEFINITION_GUIDE');
  static const ToastType OGV_VIDEO_START_TOAST =
      ToastType._(4, _omitEnumNames ? '' : 'OGV_VIDEO_START_TOAST');
  static const ToastType CHARGING_TOAST =
      ToastType._(5, _omitEnumNames ? '' : 'CHARGING_TOAST');

  static const $core.List<ToastType> values = <ToastType>[
    TOAST_TYPE_UNKNOWN,
    VIP_CONTENT_REMIND,
    VIP_DEFINITION_REMIND,
    VIP_DEFINITION_GUIDE,
    OGV_VIDEO_START_TOAST,
    CHARGING_TOAST,
  ];

  static final $core.List<ToastType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ToastType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ToastType._(super.value, super.name);
}

class UnsupportScene extends $pb.ProtobufEnum {
  static const UnsupportScene UNKNOWN_SCENE =
      UnsupportScene._(0, _omitEnumNames ? '' : 'UNKNOWN_SCENE');
  static const UnsupportScene PREMIERE =
      UnsupportScene._(1, _omitEnumNames ? '' : 'PREMIERE');

  static const $core.List<UnsupportScene> values = <UnsupportScene>[
    UNKNOWN_SCENE,
    PREMIERE,
  ];

  static final $core.List<UnsupportScene?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static UnsupportScene? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UnsupportScene._(super.value, super.name);
}

/// 杜比类型
class DolbyItem_Type extends $pb.ProtobufEnum {
  static const DolbyItem_Type NONE =
      DolbyItem_Type._(0, _omitEnumNames ? '' : 'NONE');
  static const DolbyItem_Type COMMON =
      DolbyItem_Type._(1, _omitEnumNames ? '' : 'COMMON');
  static const DolbyItem_Type ATMOS =
      DolbyItem_Type._(2, _omitEnumNames ? '' : 'ATMOS');

  static const $core.List<DolbyItem_Type> values = <DolbyItem_Type>[
    NONE,
    COMMON,
    ATMOS,
  ];

  static final $core.List<DolbyItem_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DolbyItem_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DolbyItem_Type._(super.value, super.name);
}

class Scheme_ActionType extends $pb.ProtobufEnum {
  static const Scheme_ActionType UNKNOWN =
      Scheme_ActionType._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const Scheme_ActionType SHOW_TOAST =
      Scheme_ActionType._(1, _omitEnumNames ? '' : 'SHOW_TOAST');

  static const $core.List<Scheme_ActionType> values = <Scheme_ActionType>[
    UNKNOWN,
    SHOW_TOAST,
  ];

  static final $core.List<Scheme_ActionType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Scheme_ActionType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Scheme_ActionType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
