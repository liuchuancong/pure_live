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

import 'package:protobuf/protobuf.dart' as $pb;

/// 跳过片头/片尾配置: Clip类型
class ClipType extends $pb.ProtobufEnum {
  static const ClipType NT_UNKNOWN =
      ClipType._(0, _omitEnumNames ? '' : 'NT_UNKNOWN');
  static const ClipType CLIP_TYPE_OP =
      ClipType._(1, _omitEnumNames ? '' : 'CLIP_TYPE_OP');
  static const ClipType CLIP_TYPE_ED =
      ClipType._(2, _omitEnumNames ? '' : 'CLIP_TYPE_ED');
  static const ClipType CLIP_TYPE_HE =
      ClipType._(3, _omitEnumNames ? '' : 'CLIP_TYPE_HE');
  static const ClipType CLIP_TYPE_MULTI_VIEW =
      ClipType._(4, _omitEnumNames ? '' : 'CLIP_TYPE_MULTI_VIEW');
  static const ClipType CLIP_TYPE_AD =
      ClipType._(5, _omitEnumNames ? '' : 'CLIP_TYPE_AD');

  static const $core.List<ClipType> values = <ClipType>[
    NT_UNKNOWN,
    CLIP_TYPE_OP,
    CLIP_TYPE_ED,
    CLIP_TYPE_HE,
    CLIP_TYPE_MULTI_VIEW,
    CLIP_TYPE_AD,
  ];

  static final $core.List<ClipType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ClipType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ClipType._(super.value, super.name);
}

/// 编码类型
class CodeType extends $pb.ProtobufEnum {
  static const CodeType NOCODE = CodeType._(0, _omitEnumNames ? '' : 'NOCODE');
  static const CodeType CODE264 =
      CodeType._(1, _omitEnumNames ? '' : 'CODE264');
  static const CodeType CODE265 =
      CodeType._(2, _omitEnumNames ? '' : 'CODE265');

  static const $core.List<CodeType> values = <CodeType>[
    NOCODE,
    CODE264,
    CODE265,
  ];

  static final $core.List<CodeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static CodeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CodeType._(super.value, super.name);
}

/// DRM技术类型
class DrmTechType extends $pb.ProtobufEnum {
  static const DrmTechType NON = DrmTechType._(0, _omitEnumNames ? '' : 'NON');
  static const DrmTechType FAIR_PLAY =
      DrmTechType._(1, _omitEnumNames ? '' : 'FAIR_PLAY');
  static const DrmTechType WIDE_VINE =
      DrmTechType._(2, _omitEnumNames ? '' : 'WIDE_VINE');
  static const DrmTechType BILI_DRM =
      DrmTechType._(3, _omitEnumNames ? '' : 'BILI_DRM');

  static const $core.List<DrmTechType> values = <DrmTechType>[
    NON,
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

class EpPublicityVideoType extends $pb.ProtobufEnum {
  static const EpPublicityVideoType PRE =
      EpPublicityVideoType._(0, _omitEnumNames ? '' : 'PRE');
  static const EpPublicityVideoType INLINE =
      EpPublicityVideoType._(1, _omitEnumNames ? '' : 'INLINE');

  static const $core.List<EpPublicityVideoType> values = <EpPublicityVideoType>[
    PRE,
    INLINE,
  ];

  static final $core.List<EpPublicityVideoType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static EpPublicityVideoType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EpPublicityVideoType._(super.value, super.name);
}

class InlineScene extends $pb.ProtobufEnum {
  static const InlineScene UNKNOWN =
      InlineScene._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const InlineScene RELATED_EP =
      InlineScene._(1, _omitEnumNames ? '' : 'RELATED_EP');
  static const InlineScene HE = InlineScene._(2, _omitEnumNames ? '' : 'HE');
  static const InlineScene SKIP =
      InlineScene._(3, _omitEnumNames ? '' : 'SKIP');

  static const $core.List<InlineScene> values = <InlineScene>[
    UNKNOWN,
    RELATED_EP,
    HE,
    SKIP,
  ];

  static final $core.List<InlineScene?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static InlineScene? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const InlineScene._(super.value, super.name);
}

class InlineType extends $pb.ProtobufEnum {
  static const InlineType TYPE_UNKNOWN =
      InlineType._(0, _omitEnumNames ? '' : 'TYPE_UNKNOWN');
  static const InlineType TYPE_WHOLE =
      InlineType._(1, _omitEnumNames ? '' : 'TYPE_WHOLE');
  static const InlineType TYPE_HE_CLIP =
      InlineType._(2, _omitEnumNames ? '' : 'TYPE_HE_CLIP');
  static const InlineType TYPE_PREVIEW =
      InlineType._(3, _omitEnumNames ? '' : 'TYPE_PREVIEW');

  static const $core.List<InlineType> values = <InlineType>[
    TYPE_UNKNOWN,
    TYPE_WHOLE,
    TYPE_HE_CLIP,
    TYPE_PREVIEW,
  ];

  static final $core.List<InlineType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static InlineType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const InlineType._(super.value, super.name);
}

/// 限制操作类型
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

/// DRM 安全等级
class SecurityLevel extends $pb.ProtobufEnum {
  static const SecurityLevel LEVEL_UNKNOWN =
      SecurityLevel._(0, _omitEnumNames ? '' : 'LEVEL_UNKNOWN');
  static const SecurityLevel LEVEL_L1 =
      SecurityLevel._(1, _omitEnumNames ? '' : 'LEVEL_L1');
  static const SecurityLevel LEVEL_L2 =
      SecurityLevel._(2, _omitEnumNames ? '' : 'LEVEL_L2');
  static const SecurityLevel LEVEL_L3 =
      SecurityLevel._(3, _omitEnumNames ? '' : 'LEVEL_L3');

  static const $core.List<SecurityLevel> values = <SecurityLevel>[
    LEVEL_UNKNOWN,
    LEVEL_L1,
    LEVEL_L2,
    LEVEL_L3,
  ];

  static final $core.List<SecurityLevel?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SecurityLevel? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SecurityLevel._(super.value, super.name);
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

class EpPublicityVideo_Type extends $pb.ProtobufEnum {
  static const EpPublicityVideo_Type DATA_NOT_SET =
      EpPublicityVideo_Type._(0, _omitEnumNames ? '' : 'DATA_NOT_SET');
  static const EpPublicityVideo_Type EP_PRE_VIDEO =
      EpPublicityVideo_Type._(2, _omitEnumNames ? '' : 'EP_PRE_VIDEO');
  static const EpPublicityVideo_Type EP_INLINE =
      EpPublicityVideo_Type._(3, _omitEnumNames ? '' : 'EP_INLINE');

  static const $core.List<EpPublicityVideo_Type> values =
      <EpPublicityVideo_Type>[
    DATA_NOT_SET,
    EP_PRE_VIDEO,
    EP_INLINE,
  ];

  static final $core.List<EpPublicityVideo_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static EpPublicityVideo_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EpPublicityVideo_Type._(super.value, super.name);
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
