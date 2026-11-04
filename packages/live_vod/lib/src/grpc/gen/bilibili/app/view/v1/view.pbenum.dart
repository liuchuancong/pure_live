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

import 'package:protobuf/protobuf.dart' as $pb;

/// 业务类型
class BizType extends $pb.ProtobufEnum {
  static const BizType BizTypeNone =
      BizType._(0, _omitEnumNames ? '' : 'BizTypeNone');
  static const BizType BizTypeFollowVideo =
      BizType._(1, _omitEnumNames ? '' : 'BizTypeFollowVideo');
  static const BizType BizTypeReserveActivity =
      BizType._(2, _omitEnumNames ? '' : 'BizTypeReserveActivity');
  static const BizType BizTypeJumpLink =
      BizType._(3, _omitEnumNames ? '' : 'BizTypeJumpLink');
  static const BizType BizTypeFavSeason =
      BizType._(4, _omitEnumNames ? '' : 'BizTypeFavSeason');
  static const BizType BizTypeReserveGame =
      BizType._(5, _omitEnumNames ? '' : 'BizTypeReserveGame');

  static const $core.List<BizType> values = <BizType>[
    BizTypeNone,
    BizTypeFollowVideo,
    BizTypeReserveActivity,
    BizTypeJumpLink,
    BizTypeFavSeason,
    BizTypeReserveGame,
  ];

  static final $core.List<BizType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static BizType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BizType._(super.value, super.name);
}

class Category extends $pb.ProtobufEnum {
  static const Category CategoryUnknown =
      Category._(0, _omitEnumNames ? '' : 'CategoryUnknown');
  static const Category CategorySeason =
      Category._(1, _omitEnumNames ? '' : 'CategorySeason');

  static const $core.List<Category> values = <Category>[
    CategoryUnknown,
    CategorySeason,
  ];

  static final $core.List<Category?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Category? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Category._(super.value, super.name);
}

/// 枚举-文本类型
class DescType extends $pb.ProtobufEnum {
  static const DescType DescTypeUnknown =
      DescType._(0, _omitEnumNames ? '' : 'DescTypeUnknown');
  static const DescType DescTypeText =
      DescType._(1, _omitEnumNames ? '' : 'DescTypeText');
  static const DescType DescTypeAt =
      DescType._(2, _omitEnumNames ? '' : 'DescTypeAt');

  static const $core.List<DescType> values = <DescType>[
    DescTypeUnknown,
    DescTypeText,
    DescTypeAt,
  ];

  static final $core.List<DescType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DescType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DescType._(super.value, super.name);
}

/// 错误代码
class ECode extends $pb.ProtobufEnum {
  static const ECode DEFAULT = ECode._(0, _omitEnumNames ? '' : 'DEFAULT');
  static const ECode CODE404 = ECode._(1, _omitEnumNames ? '' : 'CODE404');

  static const $core.List<ECode> values = <ECode>[
    DEFAULT,
    CODE404,
  ];

  static final $core.List<ECode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ECode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ECode._(super.value, super.name);
}

class MaterialSource extends $pb.ProtobufEnum {
  static const MaterialSource Default =
      MaterialSource._(0, _omitEnumNames ? '' : 'Default');
  static const MaterialSource BiJian =
      MaterialSource._(1, _omitEnumNames ? '' : 'BiJian');

  static const $core.List<MaterialSource> values = <MaterialSource>[
    Default,
    BiJian,
  ];

  static final $core.List<MaterialSource?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static MaterialSource? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MaterialSource._(super.value, super.name);
}

/// 卡片样式
class OperationCardType extends $pb.ProtobufEnum {
  static const OperationCardType CardTypeNone =
      OperationCardType._(0, _omitEnumNames ? '' : 'CardTypeNone');
  static const OperationCardType CardTypeStandard =
      OperationCardType._(1, _omitEnumNames ? '' : 'CardTypeStandard');
  static const OperationCardType CardTypeSkip =
      OperationCardType._(2, _omitEnumNames ? '' : 'CardTypeSkip');

  static const $core.List<OperationCardType> values = <OperationCardType>[
    CardTypeNone,
    CardTypeStandard,
    CardTypeSkip,
  ];

  static final $core.List<OperationCardType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static OperationCardType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const OperationCardType._(super.value, super.name);
}

class PayState extends $pb.ProtobufEnum {
  static const PayState PayStateUnknown =
      PayState._(0, _omitEnumNames ? '' : 'PayStateUnknown');
  static const PayState PayStateActive =
      PayState._(1, _omitEnumNames ? '' : 'PayStateActive');

  static const $core.List<PayState> values = <PayState>[
    PayStateUnknown,
    PayStateActive,
  ];

  static final $core.List<PayState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PayState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PayState._(super.value, super.name);
}

/// 卡片类型
class PlayerCardType extends $pb.ProtobufEnum {
  static const PlayerCardType PlayerCardTypeNone_VALUE =
      PlayerCardType._(0, _omitEnumNames ? '' : 'PlayerCardTypeNone_VALUE');
  static const PlayerCardType PlayerCardTypeAttention_VALUE = PlayerCardType._(
      1, _omitEnumNames ? '' : 'PlayerCardTypeAttention_VALUE');
  static const PlayerCardType PlayerCardTypeOperation_VALUE = PlayerCardType._(
      2, _omitEnumNames ? '' : 'PlayerCardTypeOperation_VALUE');
  static const PlayerCardType PlayerCardTypeContract_VALUE =
      PlayerCardType._(3, _omitEnumNames ? '' : 'PlayerCardTypeContract_VALUE');

  static const $core.List<PlayerCardType> values = <PlayerCardType>[
    PlayerCardTypeNone_VALUE,
    PlayerCardTypeAttention_VALUE,
    PlayerCardTypeOperation_VALUE,
    PlayerCardTypeContract_VALUE,
  ];

  static final $core.List<PlayerCardType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PlayerCardType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlayerCardType._(super.value, super.name);
}

class PremiereState extends $pb.ProtobufEnum {
  static const PremiereState premiere_none =
      PremiereState._(0, _omitEnumNames ? '' : 'premiere_none');
  static const PremiereState premiere_before =
      PremiereState._(1, _omitEnumNames ? '' : 'premiere_before');
  static const PremiereState premiere_in =
      PremiereState._(2, _omitEnumNames ? '' : 'premiere_in');
  static const PremiereState premiere_after =
      PremiereState._(3, _omitEnumNames ? '' : 'premiere_after');

  static const $core.List<PremiereState> values = <PremiereState>[
    premiere_none,
    premiere_before,
    premiere_in,
    premiere_after,
  ];

  static final $core.List<PremiereState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PremiereState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PremiereState._(super.value, super.name);
}

class SeasonType extends $pb.ProtobufEnum {
  static const SeasonType Unknown =
      SeasonType._(0, _omitEnumNames ? '' : 'Unknown');
  static const SeasonType Base = SeasonType._(1, _omitEnumNames ? '' : 'Base');
  static const SeasonType Good = SeasonType._(2, _omitEnumNames ? '' : 'Good');

  static const $core.List<SeasonType> values = <SeasonType>[
    Unknown,
    Base,
    Good,
  ];

  static final $core.List<SeasonType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SeasonType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SeasonType._(super.value, super.name);
}

/// TAB跳转类型
class TabOtype extends $pb.ProtobufEnum {
  static const TabOtype UnknownOtype =
      TabOtype._(0, _omitEnumNames ? '' : 'UnknownOtype');
  static const TabOtype URL = TabOtype._(1, _omitEnumNames ? '' : 'URL');
  static const TabOtype TopicNA =
      TabOtype._(2, _omitEnumNames ? '' : 'TopicNA');
  static const TabOtype CmURI = TabOtype._(3, _omitEnumNames ? '' : 'CmURI');

  static const $core.List<TabOtype> values = <TabOtype>[
    UnknownOtype,
    URL,
    TopicNA,
    CmURI,
  ];

  static final $core.List<TabOtype?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TabOtype? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TabOtype._(super.value, super.name);
}

/// TAB样式
class TabStyle extends $pb.ProtobufEnum {
  static const TabStyle UnknownStyle =
      TabStyle._(0, _omitEnumNames ? '' : 'UnknownStyle');
  static const TabStyle Text = TabStyle._(1, _omitEnumNames ? '' : 'Text');
  static const TabStyle Pic = TabStyle._(2, _omitEnumNames ? '' : 'Pic');

  static const $core.List<TabStyle> values = <TabStyle>[
    UnknownStyle,
    Text,
    Pic,
  ];

  static final $core.List<TabStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TabStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TabStyle._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
