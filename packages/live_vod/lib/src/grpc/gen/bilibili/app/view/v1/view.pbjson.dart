// This is a generated file - do not edit.
//
// Generated from bilibili/app/view/v1/view.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use bizTypeDescriptor instead')
const BizType$json = {
  '1': 'BizType',
  '2': [
    {'1': 'BizTypeNone', '2': 0},
    {'1': 'BizTypeFollowVideo', '2': 1},
    {'1': 'BizTypeReserveActivity', '2': 2},
    {'1': 'BizTypeJumpLink', '2': 3},
    {'1': 'BizTypeFavSeason', '2': 4},
    {'1': 'BizTypeReserveGame', '2': 5},
  ],
};

/// Descriptor for `BizType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List bizTypeDescriptor = $convert.base64Decode(
    'CgdCaXpUeXBlEg8KC0JpelR5cGVOb25lEAASFgoSQml6VHlwZUZvbGxvd1ZpZGVvEAESGgoWQm'
    'l6VHlwZVJlc2VydmVBY3Rpdml0eRACEhMKD0JpelR5cGVKdW1wTGluaxADEhQKEEJpelR5cGVG'
    'YXZTZWFzb24QBBIWChJCaXpUeXBlUmVzZXJ2ZUdhbWUQBQ==');

@$core.Deprecated('Use categoryDescriptor instead')
const Category$json = {
  '1': 'Category',
  '2': [
    {'1': 'CategoryUnknown', '2': 0},
    {'1': 'CategorySeason', '2': 1},
  ],
};

/// Descriptor for `Category`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List categoryDescriptor = $convert.base64Decode(
    'CghDYXRlZ29yeRITCg9DYXRlZ29yeVVua25vd24QABISCg5DYXRlZ29yeVNlYXNvbhAB');

@$core.Deprecated('Use descTypeDescriptor instead')
const DescType$json = {
  '1': 'DescType',
  '2': [
    {'1': 'DescTypeUnknown', '2': 0},
    {'1': 'DescTypeText', '2': 1},
    {'1': 'DescTypeAt', '2': 2},
  ],
};

/// Descriptor for `DescType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List descTypeDescriptor = $convert.base64Decode(
    'CghEZXNjVHlwZRITCg9EZXNjVHlwZVVua25vd24QABIQCgxEZXNjVHlwZVRleHQQARIOCgpEZX'
    'NjVHlwZUF0EAI=');

@$core.Deprecated('Use eCodeDescriptor instead')
const ECode$json = {
  '1': 'ECode',
  '2': [
    {'1': 'DEFAULT', '2': 0},
    {'1': 'CODE404', '2': 1},
  ],
};

/// Descriptor for `ECode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List eCodeDescriptor =
    $convert.base64Decode('CgVFQ29kZRILCgdERUZBVUxUEAASCwoHQ09ERTQwNBAB');

@$core.Deprecated('Use materialSourceDescriptor instead')
const MaterialSource$json = {
  '1': 'MaterialSource',
  '2': [
    {'1': 'Default', '2': 0},
    {'1': 'BiJian', '2': 1},
  ],
};

/// Descriptor for `MaterialSource`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List materialSourceDescriptor = $convert
    .base64Decode('Cg5NYXRlcmlhbFNvdXJjZRILCgdEZWZhdWx0EAASCgoGQmlKaWFuEAE=');

@$core.Deprecated('Use operationCardTypeDescriptor instead')
const OperationCardType$json = {
  '1': 'OperationCardType',
  '2': [
    {'1': 'CardTypeNone', '2': 0},
    {'1': 'CardTypeStandard', '2': 1},
    {'1': 'CardTypeSkip', '2': 2},
  ],
};

/// Descriptor for `OperationCardType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List operationCardTypeDescriptor = $convert.base64Decode(
    'ChFPcGVyYXRpb25DYXJkVHlwZRIQCgxDYXJkVHlwZU5vbmUQABIUChBDYXJkVHlwZVN0YW5kYX'
    'JkEAESEAoMQ2FyZFR5cGVTa2lwEAI=');

@$core.Deprecated('Use payStateDescriptor instead')
const PayState$json = {
  '1': 'PayState',
  '2': [
    {'1': 'PayStateUnknown', '2': 0},
    {'1': 'PayStateActive', '2': 1},
  ],
};

/// Descriptor for `PayState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List payStateDescriptor = $convert.base64Decode(
    'CghQYXlTdGF0ZRITCg9QYXlTdGF0ZVVua25vd24QABISCg5QYXlTdGF0ZUFjdGl2ZRAB');

@$core.Deprecated('Use playerCardTypeDescriptor instead')
const PlayerCardType$json = {
  '1': 'PlayerCardType',
  '2': [
    {'1': 'PlayerCardTypeNone_VALUE', '2': 0},
    {'1': 'PlayerCardTypeAttention_VALUE', '2': 1},
    {'1': 'PlayerCardTypeOperation_VALUE', '2': 2},
    {'1': 'PlayerCardTypeContract_VALUE', '2': 3},
  ],
};

/// Descriptor for `PlayerCardType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List playerCardTypeDescriptor = $convert.base64Decode(
    'Cg5QbGF5ZXJDYXJkVHlwZRIcChhQbGF5ZXJDYXJkVHlwZU5vbmVfVkFMVUUQABIhCh1QbGF5ZX'
    'JDYXJkVHlwZUF0dGVudGlvbl9WQUxVRRABEiEKHVBsYXllckNhcmRUeXBlT3BlcmF0aW9uX1ZB'
    'TFVFEAISIAocUGxheWVyQ2FyZFR5cGVDb250cmFjdF9WQUxVRRAD');

@$core.Deprecated('Use premiereStateDescriptor instead')
const PremiereState$json = {
  '1': 'PremiereState',
  '2': [
    {'1': 'premiere_none', '2': 0},
    {'1': 'premiere_before', '2': 1},
    {'1': 'premiere_in', '2': 2},
    {'1': 'premiere_after', '2': 3},
  ],
};

/// Descriptor for `PremiereState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List premiereStateDescriptor = $convert.base64Decode(
    'Cg1QcmVtaWVyZVN0YXRlEhEKDXByZW1pZXJlX25vbmUQABITCg9wcmVtaWVyZV9iZWZvcmUQAR'
    'IPCgtwcmVtaWVyZV9pbhACEhIKDnByZW1pZXJlX2FmdGVyEAM=');

@$core.Deprecated('Use seasonTypeDescriptor instead')
const SeasonType$json = {
  '1': 'SeasonType',
  '2': [
    {'1': 'Unknown', '2': 0},
    {'1': 'Base', '2': 1},
    {'1': 'Good', '2': 2},
  ],
};

/// Descriptor for `SeasonType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List seasonTypeDescriptor = $convert.base64Decode(
    'CgpTZWFzb25UeXBlEgsKB1Vua25vd24QABIICgRCYXNlEAESCAoER29vZBAC');

@$core.Deprecated('Use tabOtypeDescriptor instead')
const TabOtype$json = {
  '1': 'TabOtype',
  '2': [
    {'1': 'UnknownOtype', '2': 0},
    {'1': 'URL', '2': 1},
    {'1': 'TopicNA', '2': 2},
    {'1': 'CmURI', '2': 3},
  ],
};

/// Descriptor for `TabOtype`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tabOtypeDescriptor = $convert.base64Decode(
    'CghUYWJPdHlwZRIQCgxVbmtub3duT3R5cGUQABIHCgNVUkwQARILCgdUb3BpY05BEAISCQoFQ2'
    '1VUkkQAw==');

@$core.Deprecated('Use tabStyleDescriptor instead')
const TabStyle$json = {
  '1': 'TabStyle',
  '2': [
    {'1': 'UnknownStyle', '2': 0},
    {'1': 'Text', '2': 1},
    {'1': 'Pic', '2': 2},
  ],
};

/// Descriptor for `TabStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tabStyleDescriptor = $convert.base64Decode(
    'CghUYWJTdHlsZRIQCgxVbmtub3duU3R5bGUQABIICgRUZXh0EAESBwoDUGljEAI=');

@$core.Deprecated('Use activityResourceDescriptor instead')
const ActivityResource$json = {
  '1': 'ActivityResource',
  '2': [
    {'1': 'mod_pool_name', '3': 1, '4': 1, '5': 9, '10': 'modPoolName'},
    {'1': 'mod_resource_name', '3': 2, '4': 1, '5': 9, '10': 'modResourceName'},
    {'1': 'bg_color', '3': 3, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'selected_bg_color', '3': 4, '4': 1, '5': 9, '10': 'selectedBgColor'},
    {'1': 'text_color', '3': 5, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'light_text_color', '3': 6, '4': 1, '5': 9, '10': 'lightTextColor'},
    {'1': 'dark_text_color', '3': 7, '4': 1, '5': 9, '10': 'darkTextColor'},
    {'1': 'divider_color', '3': 8, '4': 1, '5': 9, '10': 'dividerColor'},
  ],
};

/// Descriptor for `ActivityResource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activityResourceDescriptor = $convert.base64Decode(
    'ChBBY3Rpdml0eVJlc291cmNlEiIKDW1vZF9wb29sX25hbWUYASABKAlSC21vZFBvb2xOYW1lEi'
    'oKEW1vZF9yZXNvdXJjZV9uYW1lGAIgASgJUg9tb2RSZXNvdXJjZU5hbWUSGQoIYmdfY29sb3IY'
    'AyABKAlSB2JnQ29sb3ISKgoRc2VsZWN0ZWRfYmdfY29sb3IYBCABKAlSD3NlbGVjdGVkQmdDb2'
    'xvchIdCgp0ZXh0X2NvbG9yGAUgASgJUgl0ZXh0Q29sb3ISKAoQbGlnaHRfdGV4dF9jb2xvchgG'
    'IAEoCVIObGlnaHRUZXh0Q29sb3ISJgoPZGFya190ZXh0X2NvbG9yGAcgASgJUg1kYXJrVGV4dE'
    'NvbG9yEiMKDWRpdmlkZXJfY29sb3IYCCABKAlSDGRpdmlkZXJDb2xvcg==');

@$core.Deprecated('Use activitySeasonDescriptor instead')
const ActivitySeason$json = {
  '1': 'ActivitySeason',
  '2': [
    {
      '1': 'arc',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Arc',
      '10': 'arc'
    },
    {
      '1': 'pages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewPage',
      '10': 'pages'
    },
    {
      '1': 'owner_ext',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OnwerExt',
      '10': 'ownerExt'
    },
    {
      '1': 'req_user',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReqUser',
      '10': 'reqUser'
    },
    {
      '1': 'elec_rank',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ElecRank',
      '10': 'elecRank'
    },
    {
      '1': 'history',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.History',
      '10': 'history'
    },
    {'1': 'bvid', '3': 7, '4': 1, '5': 9, '10': 'bvid'},
    {
      '1': 'honor',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Honor',
      '10': 'honor'
    },
    {
      '1': 'staff',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Staff',
      '10': 'staff'
    },
    {
      '1': 'ugc_season',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UgcSeason',
      '10': 'ugcSeason'
    },
    {
      '1': 'tab',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Tab',
      '10': 'tab'
    },
    {
      '1': 'rank',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Rank',
      '10': 'rank'
    },
    {
      '1': 'order',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Order',
      '10': 'order'
    },
    {'1': 'support_dislike', '3': 14, '4': 1, '5': 8, '10': 'supportDislike'},
    {
      '1': 'operation_relate',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OperationRelate',
      '10': 'operationRelate'
    },
    {
      '1': 'activity_resource',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ActivityResource',
      '10': 'activityResource'
    },
    {'1': 'short_link', '3': 17, '4': 1, '5': 9, '10': 'shortLink'},
    {
      '1': 'label',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Label',
      '10': 'label'
    },
    {
      '1': 'dislike',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Dislike',
      '10': 'dislike'
    },
    {
      '1': 'player_icon',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PlayerIcon',
      '10': 'playerIcon'
    },
    {'1': 'share_subtitle', '3': 21, '4': 1, '5': 9, '10': 'shareSubtitle'},
    {
      '1': 'cm_config',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CMConfig',
      '10': 'cmConfig'
    },
    {
      '1': 'tf_panel_customized',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.TFPanelCustomized',
      '10': 'tfPanelCustomized'
    },
    {'1': 'argue_msg', '3': 24, '4': 1, '5': 9, '10': 'argueMsg'},
    {
      '1': 'ecode',
      '3': 25,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.ECode',
      '10': 'ecode'
    },
    {
      '1': 'custom_config',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CustomConfig',
      '10': 'customConfig'
    },
    {'1': 'badge_url', '3': 27, '4': 1, '5': 9, '10': 'badgeUrl'},
    {
      '1': 'desc_v2',
      '3': 28,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.DescV2',
      '10': 'descV2'
    },
    {
      '1': 'config',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Config',
      '10': 'config'
    },
    {
      '1': 'online',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Online',
      '10': 'online'
    },
    {
      '1': 'arc_extra',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ArcExtra',
      '10': 'arcExtra'
    },
    {
      '1': 'reply_preface',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReplyStyle',
      '10': 'replyPreface'
    },
  ],
};

/// Descriptor for `ActivitySeason`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activitySeasonDescriptor = $convert.base64Decode(
    'Cg5BY3Rpdml0eVNlYXNvbhIuCgNhcmMYASABKAsyHC5iaWxpYmlsaS5hcHAuYXJjaGl2ZS52MS'
    '5BcmNSA2FyYxI0CgVwYWdlcxgCIAMoCzIeLmJpbGliaWxpLmFwcC52aWV3LnYxLlZpZXdQYWdl'
    'UgVwYWdlcxI7Cglvd25lcl9leHQYAyABKAsyHi5iaWxpYmlsaS5hcHAudmlldy52MS5Pbndlck'
    'V4dFIIb3duZXJFeHQSOAoIcmVxX3VzZXIYBCABKAsyHS5iaWxpYmlsaS5hcHAudmlldy52MS5S'
    'ZXFVc2VyUgdyZXFVc2VyEjsKCWVsZWNfcmFuaxgFIAEoCzIeLmJpbGliaWxpLmFwcC52aWV3Ln'
    'YxLkVsZWNSYW5rUghlbGVjUmFuaxI3CgdoaXN0b3J5GAYgASgLMh0uYmlsaWJpbGkuYXBwLnZp'
    'ZXcudjEuSGlzdG9yeVIHaGlzdG9yeRISCgRidmlkGAcgASgJUgRidmlkEjEKBWhvbm9yGAggAS'
    'gLMhsuYmlsaWJpbGkuYXBwLnZpZXcudjEuSG9ub3JSBWhvbm9yEjEKBXN0YWZmGAkgAygLMhsu'
    'YmlsaWJpbGkuYXBwLnZpZXcudjEuU3RhZmZSBXN0YWZmEj4KCnVnY19zZWFzb24YCiABKAsyHy'
    '5iaWxpYmlsaS5hcHAudmlldy52MS5VZ2NTZWFzb25SCXVnY1NlYXNvbhIrCgN0YWIYCyABKAsy'
    'GS5iaWxpYmlsaS5hcHAudmlldy52MS5UYWJSA3RhYhIuCgRyYW5rGAwgASgLMhouYmlsaWJpbG'
    'kuYXBwLnZpZXcudjEuUmFua1IEcmFuaxIxCgVvcmRlchgNIAEoCzIbLmJpbGliaWxpLmFwcC52'
    'aWV3LnYxLk9yZGVyUgVvcmRlchInCg9zdXBwb3J0X2Rpc2xpa2UYDiABKAhSDnN1cHBvcnREaX'
    'NsaWtlElAKEG9wZXJhdGlvbl9yZWxhdGUYDyABKAsyJS5iaWxpYmlsaS5hcHAudmlldy52MS5P'
    'cGVyYXRpb25SZWxhdGVSD29wZXJhdGlvblJlbGF0ZRJTChFhY3Rpdml0eV9yZXNvdXJjZRgQIA'
    'EoCzImLmJpbGliaWxpLmFwcC52aWV3LnYxLkFjdGl2aXR5UmVzb3VyY2VSEGFjdGl2aXR5UmVz'
    'b3VyY2USHQoKc2hvcnRfbGluaxgRIAEoCVIJc2hvcnRMaW5rEjEKBWxhYmVsGBIgASgLMhsuYm'
    'lsaWJpbGkuYXBwLnZpZXcudjEuTGFiZWxSBWxhYmVsEjcKB2Rpc2xpa2UYEyABKAsyHS5iaWxp'
    'YmlsaS5hcHAudmlldy52MS5EaXNsaWtlUgdkaXNsaWtlEkEKC3BsYXllcl9pY29uGBQgASgLMi'
    'AuYmlsaWJpbGkuYXBwLnZpZXcudjEuUGxheWVySWNvblIKcGxheWVySWNvbhIlCg5zaGFyZV9z'
    'dWJ0aXRsZRgVIAEoCVINc2hhcmVTdWJ0aXRsZRI7CgljbV9jb25maWcYFiABKAsyHi5iaWxpYm'
    'lsaS5hcHAudmlldy52MS5DTUNvbmZpZ1IIY21Db25maWcSVwoTdGZfcGFuZWxfY3VzdG9taXpl'
    'ZBgXIAEoCzInLmJpbGliaWxpLmFwcC52aWV3LnYxLlRGUGFuZWxDdXN0b21pemVkUhF0ZlBhbm'
    'VsQ3VzdG9taXplZBIbCglhcmd1ZV9tc2cYGCABKAlSCGFyZ3VlTXNnEjEKBWVjb2RlGBkgASgO'
    'MhsuYmlsaWJpbGkuYXBwLnZpZXcudjEuRUNvZGVSBWVjb2RlEkcKDWN1c3RvbV9jb25maWcYGi'
    'ABKAsyIi5iaWxpYmlsaS5hcHAudmlldy52MS5DdXN0b21Db25maWdSDGN1c3RvbUNvbmZpZxIb'
    'CgliYWRnZV91cmwYGyABKAlSCGJhZGdlVXJsEjUKB2Rlc2NfdjIYHCADKAsyHC5iaWxpYmlsaS'
    '5hcHAudmlldy52MS5EZXNjVjJSBmRlc2NWMhI0CgZjb25maWcYHSABKAsyHC5iaWxpYmlsaS5h'
    'cHAudmlldy52MS5Db25maWdSBmNvbmZpZxI0CgZvbmxpbmUYHiABKAsyHC5iaWxpYmlsaS5hcH'
    'Audmlldy52MS5PbmxpbmVSBm9ubGluZRI7CglhcmNfZXh0cmEYHyABKAsyHi5iaWxpYmlsaS5h'
    'cHAudmlldy52MS5BcmNFeHRyYVIIYXJjRXh0cmESRQoNcmVwbHlfcHJlZmFjZRggIAEoCzIgLm'
    'JpbGliaWxpLmFwcC52aWV3LnYxLlJlcGx5U3R5bGVSDHJlcGx5UHJlZmFjZQ==');

@$core.Deprecated('Use addContractReqDescriptor instead')
const AddContractReq$json = {
  '1': 'AddContractReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'up_mid', '3': 2, '4': 1, '5': 3, '10': 'upMid'},
    {'1': 'spmid', '3': 3, '4': 1, '5': 9, '10': 'spmid'},
  ],
};

/// Descriptor for `AddContractReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addContractReqDescriptor = $convert.base64Decode(
    'Cg5BZGRDb250cmFjdFJlcRIQCgNhaWQYASABKANSA2FpZBIVCgZ1cF9taWQYAiABKANSBXVwTW'
    'lkEhQKBXNwbWlkGAMgASgJUgVzcG1pZA==');

@$core.Deprecated('Use adInfoDescriptor instead')
const AdInfo$json = {
  '1': 'AdInfo',
  '2': [
    {'1': 'creative_id', '3': 1, '4': 1, '5': 3, '10': 'creativeId'},
    {'1': 'creative_type', '3': 2, '4': 1, '5': 3, '10': 'creativeType'},
    {
      '1': 'creative_content',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CreativeContent',
      '10': 'creativeContent'
    },
    {'1': 'ad_cb', '3': 4, '4': 1, '5': 9, '10': 'adCb'},
    {'1': 'card_type', '3': 5, '4': 1, '5': 5, '10': 'cardType'},
    {'1': 'extra', '3': 6, '4': 1, '5': 12, '10': 'extra'},
  ],
};

/// Descriptor for `AdInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adInfoDescriptor = $convert.base64Decode(
    'CgZBZEluZm8SHwoLY3JlYXRpdmVfaWQYASABKANSCmNyZWF0aXZlSWQSIwoNY3JlYXRpdmVfdH'
    'lwZRgCIAEoA1IMY3JlYXRpdmVUeXBlElAKEGNyZWF0aXZlX2NvbnRlbnQYAyABKAsyJS5iaWxp'
    'YmlsaS5hcHAudmlldy52MS5DcmVhdGl2ZUNvbnRlbnRSD2NyZWF0aXZlQ29udGVudBITCgVhZF'
    '9jYhgEIAEoCVIEYWRDYhIbCgljYXJkX3R5cGUYBSABKAVSCGNhcmRUeXBlEhQKBWV4dHJhGAYg'
    'ASgMUgVleHRyYQ==');

@$core.Deprecated('Use arcExtraDescriptor instead')
const ArcExtra$json = {
  '1': 'ArcExtra',
  '2': [
    {'1': 'arc_pub_location', '3': 1, '4': 1, '5': 9, '10': 'arcPubLocation'},
  ],
};

/// Descriptor for `ArcExtra`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arcExtraDescriptor = $convert.base64Decode(
    'CghBcmNFeHRyYRIoChBhcmNfcHViX2xvY2F0aW9uGAEgASgJUg5hcmNQdWJMb2NhdGlvbg==');

@$core.Deprecated('Use arcsPlayerDescriptor instead')
const ArcsPlayer$json = {
  '1': 'ArcsPlayer',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {
      '1': 'player_info',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ArcsPlayer.PlayerInfoEntry',
      '10': 'playerInfo'
    },
  ],
  '3': [ArcsPlayer_PlayerInfoEntry$json],
};

@$core.Deprecated('Use arcsPlayerDescriptor instead')
const ArcsPlayer_PlayerInfoEntry$json = {
  '1': 'PlayerInfoEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 3, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ArcsPlayer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arcsPlayerDescriptor = $convert.base64Decode(
    'CgpBcmNzUGxheWVyEhAKA2FpZBgBIAEoA1IDYWlkElEKC3BsYXllcl9pbmZvGAIgAygLMjAuYm'
    'lsaWJpbGkuYXBwLnZpZXcudjEuQXJjc1BsYXllci5QbGF5ZXJJbmZvRW50cnlSCnBsYXllcklu'
    'Zm8aPQoPUGxheWVySW5mb0VudHJ5EhAKA2tleRgBIAEoA1IDa2V5EhQKBXZhbHVlGAIgASgJUg'
    'V2YWx1ZToCOAE=');

@$core.Deprecated('Use assetDescriptor instead')
const Asset$json = {
  '1': 'Asset',
  '2': [
    {'1': 'paid', '3': 1, '4': 1, '5': 5, '10': 'paid'},
    {'1': 'price', '3': 2, '4': 1, '5': 3, '10': 'price'},
    {
      '1': 'msg',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.AssetMsg',
      '10': 'msg'
    },
    {
      '1': 'preview_msg',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.AssetMsg',
      '10': 'previewMsg'
    },
  ],
};

/// Descriptor for `Asset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetDescriptor = $convert.base64Decode(
    'CgVBc3NldBISCgRwYWlkGAEgASgFUgRwYWlkEhQKBXByaWNlGAIgASgDUgVwcmljZRIwCgNtc2'
    'cYAyABKAsyHi5iaWxpYmlsaS5hcHAudmlldy52MS5Bc3NldE1zZ1IDbXNnEj8KC3ByZXZpZXdf'
    'bXNnGAQgASgLMh4uYmlsaWJpbGkuYXBwLnZpZXcudjEuQXNzZXRNc2dSCnByZXZpZXdNc2c=');

@$core.Deprecated('Use assetMsgDescriptor instead')
const AssetMsg$json = {
  '1': 'AssetMsg',
  '2': [
    {'1': 'desc1', '3': 1, '4': 1, '5': 9, '10': 'desc1'},
    {'1': 'desc2', '3': 2, '4': 1, '5': 9, '10': 'desc2'},
  ],
};

/// Descriptor for `AssetMsg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetMsgDescriptor = $convert.base64Decode(
    'CghBc3NldE1zZxIUCgVkZXNjMRgBIAEoCVIFZGVzYzESFAoFZGVzYzIYAiABKAlSBWRlc2My');

@$core.Deprecated('Use attentionDescriptor instead')
const Attention$json = {
  '1': 'Attention',
  '2': [
    {'1': 'start_time', '3': 1, '4': 1, '5': 5, '10': 'startTime'},
    {'1': 'end_time', '3': 2, '4': 1, '5': 5, '10': 'endTime'},
    {'1': 'pos_x', '3': 3, '4': 1, '5': 1, '10': 'posX'},
    {'1': 'pos_y', '3': 4, '4': 1, '5': 1, '10': 'posY'},
  ],
};

/// Descriptor for `Attention`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attentionDescriptor = $convert.base64Decode(
    'CglBdHRlbnRpb24SHQoKc3RhcnRfdGltZRgBIAEoBVIJc3RhcnRUaW1lEhkKCGVuZF90aW1lGA'
    'IgASgFUgdlbmRUaW1lEhMKBXBvc194GAMgASgBUgRwb3NYEhMKBXBvc195GAQgASgBUgRwb3NZ');

@$core.Deprecated('Use audioDescriptor instead')
const Audio$json = {
  '1': 'Audio',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cover_url', '3': 2, '4': 1, '5': 9, '10': 'coverUrl'},
    {'1': 'song_id', '3': 3, '4': 1, '5': 3, '10': 'songId'},
    {'1': 'play_count', '3': 4, '4': 1, '5': 3, '10': 'playCount'},
    {'1': 'reply_count', '3': 5, '4': 1, '5': 3, '10': 'replyCount'},
    {'1': 'upper_id', '3': 6, '4': 1, '5': 3, '10': 'upperId'},
    {'1': 'entrance', '3': 7, '4': 1, '5': 9, '10': 'entrance'},
    {'1': 'song_attr', '3': 8, '4': 1, '5': 3, '10': 'songAttr'},
  ],
};

/// Descriptor for `Audio`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioDescriptor = $convert.base64Decode(
    'CgVBdWRpbxIUCgV0aXRsZRgBIAEoCVIFdGl0bGUSGwoJY292ZXJfdXJsGAIgASgJUghjb3Zlcl'
    'VybBIXCgdzb25nX2lkGAMgASgDUgZzb25nSWQSHQoKcGxheV9jb3VudBgEIAEoA1IJcGxheUNv'
    'dW50Eh8KC3JlcGx5X2NvdW50GAUgASgDUgpyZXBseUNvdW50EhkKCHVwcGVyX2lkGAYgASgDUg'
    'd1cHBlcklkEhoKCGVudHJhbmNlGAcgASgJUghlbnRyYW5jZRIbCglzb25nX2F0dHIYCCABKANS'
    'CHNvbmdBdHRy');

@$core.Deprecated('Use badgeStyleDescriptor instead')
const BadgeStyle$json = {
  '1': 'BadgeStyle',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 2, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_color_night', '3': 3, '4': 1, '5': 9, '10': 'textColorNight'},
    {'1': 'bg_color', '3': 4, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'bg_color_night', '3': 5, '4': 1, '5': 9, '10': 'bgColorNight'},
    {'1': 'border_color', '3': 6, '4': 1, '5': 9, '10': 'borderColor'},
    {
      '1': 'border_color_night',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'borderColorNight'
    },
    {'1': 'bg_style', '3': 8, '4': 1, '5': 5, '10': 'bgStyle'},
  ],
};

/// Descriptor for `BadgeStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List badgeStyleDescriptor = $convert.base64Decode(
    'CgpCYWRnZVN0eWxlEhIKBHRleHQYASABKAlSBHRleHQSHQoKdGV4dF9jb2xvchgCIAEoCVIJdG'
    'V4dENvbG9yEigKEHRleHRfY29sb3JfbmlnaHQYAyABKAlSDnRleHRDb2xvck5pZ2h0EhkKCGJn'
    'X2NvbG9yGAQgASgJUgdiZ0NvbG9yEiQKDmJnX2NvbG9yX25pZ2h0GAUgASgJUgxiZ0NvbG9yTm'
    'lnaHQSIQoMYm9yZGVyX2NvbG9yGAYgASgJUgtib3JkZXJDb2xvchIsChJib3JkZXJfY29sb3Jf'
    'bmlnaHQYByABKAlSEGJvcmRlckNvbG9yTmlnaHQSGQoIYmdfc3R5bGUYCCABKAVSB2JnU3R5bG'
    'U=');

@$core.Deprecated('Use bgmDescriptor instead')
const Bgm$json = {
  '1': 'Bgm',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 3, '10': 'sid'},
    {'1': 'mid', '3': 2, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'author', '3': 4, '4': 1, '5': 9, '10': 'author'},
    {'1': 'jumpUrl', '3': 5, '4': 1, '5': 9, '10': 'jumpUrl'},
    {'1': 'cover', '3': 6, '4': 1, '5': 9, '10': 'cover'},
  ],
};

/// Descriptor for `Bgm`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bgmDescriptor = $convert.base64Decode(
    'CgNCZ20SEAoDc2lkGAEgASgDUgNzaWQSEAoDbWlkGAIgASgDUgNtaWQSFAoFdGl0bGUYAyABKA'
    'lSBXRpdGxlEhYKBmF1dGhvchgEIAEoCVIGYXV0aG9yEhgKB2p1bXBVcmwYBSABKAlSB2p1bXBV'
    'cmwSFAoFY292ZXIYBiABKAlSBWNvdmVy');

@$core.Deprecated('Use bizFavSeasonParamDescriptor instead')
const BizFavSeasonParam$json = {
  '1': 'BizFavSeasonParam',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
  ],
};

/// Descriptor for `BizFavSeasonParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bizFavSeasonParamDescriptor = $convert.base64Decode(
    'ChFCaXpGYXZTZWFzb25QYXJhbRIbCglzZWFzb25faWQYASABKANSCHNlYXNvbklk');

@$core.Deprecated('Use bizFollowVideoParamDescriptor instead')
const BizFollowVideoParam$json = {
  '1': 'BizFollowVideoParam',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
  ],
};

/// Descriptor for `BizFollowVideoParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bizFollowVideoParamDescriptor =
    $convert.base64Decode(
        'ChNCaXpGb2xsb3dWaWRlb1BhcmFtEhsKCXNlYXNvbl9pZBgBIAEoA1IIc2Vhc29uSWQ=');

@$core.Deprecated('Use bizJumpLinkParamDescriptor instead')
const BizJumpLinkParam$json = {
  '1': 'BizJumpLinkParam',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `BizJumpLinkParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bizJumpLinkParamDescriptor =
    $convert.base64Decode('ChBCaXpKdW1wTGlua1BhcmFtEhAKA3VybBgBIAEoCVIDdXJs');

@$core.Deprecated('Use bizReserveActivityParamDescriptor instead')
const BizReserveActivityParam$json = {
  '1': 'BizReserveActivityParam',
  '2': [
    {'1': 'activity_id', '3': 1, '4': 1, '5': 3, '10': 'activityId'},
    {'1': 'from', '3': 2, '4': 1, '5': 9, '10': 'from'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'oid', '3': 4, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'reserve_id', '3': 5, '4': 1, '5': 3, '10': 'reserveId'},
  ],
};

/// Descriptor for `BizReserveActivityParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bizReserveActivityParamDescriptor = $convert.base64Decode(
    'ChdCaXpSZXNlcnZlQWN0aXZpdHlQYXJhbRIfCgthY3Rpdml0eV9pZBgBIAEoA1IKYWN0aXZpdH'
    'lJZBISCgRmcm9tGAIgASgJUgRmcm9tEhIKBHR5cGUYAyABKAlSBHR5cGUSEAoDb2lkGAQgASgD'
    'UgNvaWQSHQoKcmVzZXJ2ZV9pZBgFIAEoA1IJcmVzZXJ2ZUlk');

@$core.Deprecated('Use bizReserveGameParamDescriptor instead')
const BizReserveGameParam$json = {
  '1': 'BizReserveGameParam',
  '2': [
    {'1': 'game_id', '3': 1, '4': 1, '5': 3, '10': 'gameId'},
  ],
};

/// Descriptor for `BizReserveGameParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bizReserveGameParamDescriptor =
    $convert.base64Decode(
        'ChNCaXpSZXNlcnZlR2FtZVBhcmFtEhcKB2dhbWVfaWQYASABKANSBmdhbWVJZA==');

@$core.Deprecated('Use buttonDescriptor instead')
const Button$json = {
  '1': 'Button',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'uri', '3': 2, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
  ],
};

/// Descriptor for `Button`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buttonDescriptor = $convert.base64Decode(
    'CgZCdXR0b24SFAoFdGl0bGUYASABKAlSBXRpdGxlEhAKA3VyaRgCIAEoCVIDdXJpEhIKBGljb2'
    '4YAyABKAlSBGljb24=');

@$core.Deprecated('Use buttonStyleDescriptor instead')
const ButtonStyle$json = {
  '1': 'ButtonStyle',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 2, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_color_night', '3': 3, '4': 1, '5': 9, '10': 'textColorNight'},
    {'1': 'bg_color', '3': 4, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'bg_color_night', '3': 5, '4': 1, '5': 9, '10': 'bgColorNight'},
    {'1': 'jump_link', '3': 6, '4': 1, '5': 9, '10': 'jumpLink'},
  ],
};

/// Descriptor for `ButtonStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buttonStyleDescriptor = $convert.base64Decode(
    'CgtCdXR0b25TdHlsZRISCgR0ZXh0GAEgASgJUgR0ZXh0Eh0KCnRleHRfY29sb3IYAiABKAlSCX'
    'RleHRDb2xvchIoChB0ZXh0X2NvbG9yX25pZ2h0GAMgASgJUg50ZXh0Q29sb3JOaWdodBIZCghi'
    'Z19jb2xvchgEIAEoCVIHYmdDb2xvchIkCg5iZ19jb2xvcl9uaWdodBgFIAEoCVIMYmdDb2xvck'
    '5pZ2h0EhsKCWp1bXBfbGluaxgGIAEoCVIIanVtcExpbms=');

@$core.Deprecated('Use buzzwordConfigDescriptor instead')
const BuzzwordConfig$json = {
  '1': 'BuzzwordConfig',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'schema', '3': 2, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'source', '3': 3, '4': 1, '5': 5, '10': 'source'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 5, '4': 1, '5': 3, '10': 'end'},
    {'1': 'follow_control', '3': 6, '4': 1, '5': 8, '10': 'followControl'},
    {'1': 'id', '3': 7, '4': 1, '5': 3, '10': 'id'},
    {'1': 'buzzword_id', '3': 8, '4': 1, '5': 3, '10': 'buzzwordId'},
    {'1': 'schema_type', '3': 9, '4': 1, '5': 5, '10': 'schemaType'},
    {'1': 'picture', '3': 10, '4': 1, '5': 9, '10': 'picture'},
  ],
};

/// Descriptor for `BuzzwordConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buzzwordConfigDescriptor = $convert.base64Decode(
    'Cg5CdXp6d29yZENvbmZpZxISCgRuYW1lGAEgASgJUgRuYW1lEhYKBnNjaGVtYRgCIAEoCVIGc2'
    'NoZW1hEhYKBnNvdXJjZRgDIAEoBVIGc291cmNlEhQKBXN0YXJ0GAQgASgDUgVzdGFydBIQCgNl'
    'bmQYBSABKANSA2VuZBIlCg5mb2xsb3dfY29udHJvbBgGIAEoCFINZm9sbG93Q29udHJvbBIOCg'
    'JpZBgHIAEoA1ICaWQSHwoLYnV6endvcmRfaWQYCCABKANSCmJ1enp3b3JkSWQSHwoLc2NoZW1h'
    'X3R5cGUYCSABKAVSCnNjaGVtYVR5cGUSGAoHcGljdHVyZRgKIAEoCVIHcGljdHVyZQ==');

@$core.Deprecated('Use cacheViewReplyDescriptor instead')
const CacheViewReply$json = {
  '1': 'CacheViewReply',
  '2': [
    {
      '1': 'arc',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Arc',
      '10': 'arc'
    },
    {
      '1': 'pages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewPage',
      '10': 'pages'
    },
    {
      '1': 'owner_ext',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OnwerExt',
      '10': 'ownerExt'
    },
    {
      '1': 'req_user',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReqUser',
      '10': 'reqUser'
    },
    {
      '1': 'season',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Season',
      '10': 'season'
    },
    {
      '1': 'elec_rank',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ElecRank',
      '10': 'elecRank'
    },
    {
      '1': 'history',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.History',
      '10': 'history'
    },
    {
      '1': 'dislike',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Dislike',
      '10': 'dislike'
    },
    {
      '1': 'player_icon',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PlayerIcon',
      '10': 'playerIcon'
    },
    {'1': 'bvid', '3': 10, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'short_link', '3': 11, '4': 1, '5': 9, '10': 'shortLink'},
    {'1': 'share_subtitle', '3': 12, '4': 1, '5': 9, '10': 'shareSubtitle'},
    {
      '1': 'tf_panel_customized',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.TFPanelCustomized',
      '10': 'tfPanelCustomized'
    },
    {
      '1': 'online',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Online',
      '10': 'online'
    },
  ],
};

/// Descriptor for `CacheViewReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cacheViewReplyDescriptor = $convert.base64Decode(
    'Cg5DYWNoZVZpZXdSZXBseRIuCgNhcmMYASABKAsyHC5iaWxpYmlsaS5hcHAuYXJjaGl2ZS52MS'
    '5BcmNSA2FyYxI0CgVwYWdlcxgCIAMoCzIeLmJpbGliaWxpLmFwcC52aWV3LnYxLlZpZXdQYWdl'
    'UgVwYWdlcxI7Cglvd25lcl9leHQYAyABKAsyHi5iaWxpYmlsaS5hcHAudmlldy52MS5Pbndlck'
    'V4dFIIb3duZXJFeHQSOAoIcmVxX3VzZXIYBCABKAsyHS5iaWxpYmlsaS5hcHAudmlldy52MS5S'
    'ZXFVc2VyUgdyZXFVc2VyEjQKBnNlYXNvbhgFIAEoCzIcLmJpbGliaWxpLmFwcC52aWV3LnYxLl'
    'NlYXNvblIGc2Vhc29uEjsKCWVsZWNfcmFuaxgGIAEoCzIeLmJpbGliaWxpLmFwcC52aWV3LnYx'
    'LkVsZWNSYW5rUghlbGVjUmFuaxI3CgdoaXN0b3J5GAcgASgLMh0uYmlsaWJpbGkuYXBwLnZpZX'
    'cudjEuSGlzdG9yeVIHaGlzdG9yeRI3CgdkaXNsaWtlGAggASgLMh0uYmlsaWJpbGkuYXBwLnZp'
    'ZXcudjEuRGlzbGlrZVIHZGlzbGlrZRJBCgtwbGF5ZXJfaWNvbhgJIAEoCzIgLmJpbGliaWxpLm'
    'FwcC52aWV3LnYxLlBsYXllckljb25SCnBsYXllckljb24SEgoEYnZpZBgKIAEoCVIEYnZpZBId'
    'CgpzaG9ydF9saW5rGAsgASgJUglzaG9ydExpbmsSJQoOc2hhcmVfc3VidGl0bGUYDCABKAlSDX'
    'NoYXJlU3VidGl0bGUSVwoTdGZfcGFuZWxfY3VzdG9taXplZBgNIAEoCzInLmJpbGliaWxpLmFw'
    'cC52aWV3LnYxLlRGUGFuZWxDdXN0b21pemVkUhF0ZlBhbmVsQ3VzdG9taXplZBI0CgZvbmxpbm'
    'UYDiABKAsyHC5iaWxpYmlsaS5hcHAudmlldy52MS5PbmxpbmVSBm9ubGluZQ==');

@$core.Deprecated('Use cacheViewReqDescriptor instead')
const CacheViewReq$json = {
  '1': 'CacheViewReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'from', '3': 3, '4': 1, '5': 9, '10': 'from'},
    {'1': 'trackid', '3': 4, '4': 1, '5': 9, '10': 'trackid'},
    {'1': 'ad_extra', '3': 5, '4': 1, '5': 9, '10': 'adExtra'},
    {'1': 'spmid', '3': 6, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 7, '4': 1, '5': 9, '10': 'fromSpmid'},
  ],
};

/// Descriptor for `CacheViewReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cacheViewReqDescriptor = $convert.base64Decode(
    'CgxDYWNoZVZpZXdSZXESEAoDYWlkGAEgASgDUgNhaWQSEgoEYnZpZBgCIAEoCVIEYnZpZBISCg'
    'Rmcm9tGAMgASgJUgRmcm9tEhgKB3RyYWNraWQYBCABKAlSB3RyYWNraWQSGQoIYWRfZXh0cmEY'
    'BSABKAlSB2FkRXh0cmESFAoFc3BtaWQYBiABKAlSBXNwbWlkEh0KCmZyb21fc3BtaWQYByABKA'
    'lSCWZyb21TcG1pZA==');

@$core.Deprecated('Use chronosDescriptor instead')
const Chronos$json = {
  '1': 'Chronos',
  '2': [
    {'1': 'md5', '3': 1, '4': 1, '5': 9, '10': 'md5'},
    {'1': 'file', '3': 2, '4': 1, '5': 9, '10': 'file'},
    {'1': 'sign', '3': 3, '4': 1, '5': 9, '10': 'sign'},
  ],
};

/// Descriptor for `Chronos`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chronosDescriptor = $convert.base64Decode(
    'CgdDaHJvbm9zEhAKA21kNRgBIAEoCVIDbWQ1EhIKBGZpbGUYAiABKAlSBGZpbGUSEgoEc2lnbh'
    'gDIAEoCVIEc2lnbg==');

@$core.Deprecated('Use chronosPkgReqDescriptor instead')
const ChronosPkgReq$json = {
  '1': 'ChronosPkgReq',
  '2': [
    {'1': 'service_key', '3': 1, '4': 1, '5': 9, '10': 'serviceKey'},
    {'1': 'engine_version', '3': 2, '4': 1, '5': 9, '10': 'engineVersion'},
    {'1': 'message_protocol', '3': 3, '4': 1, '5': 9, '10': 'messageProtocol'},
  ],
};

/// Descriptor for `ChronosPkgReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chronosPkgReqDescriptor = $convert.base64Decode(
    'Cg1DaHJvbm9zUGtnUmVxEh8KC3NlcnZpY2Vfa2V5GAEgASgJUgpzZXJ2aWNlS2V5EiUKDmVuZ2'
    'luZV92ZXJzaW9uGAIgASgJUg1lbmdpbmVWZXJzaW9uEikKEG1lc3NhZ2VfcHJvdG9jb2wYAyAB'
    'KAlSD21lc3NhZ2VQcm90b2NvbA==');

@$core.Deprecated('Use clickActivitySeasonReqDescriptor instead')
const ClickActivitySeasonReq$json = {
  '1': 'ClickActivitySeasonReq',
  '2': [
    {
      '1': 'order_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.BizType',
      '10': 'orderType'
    },
    {'1': 'spmid', '3': 2, '4': 1, '5': 9, '10': 'spmid'},
    {
      '1': 'reserve',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizReserveActivityParam',
      '9': 0,
      '10': 'reserve'
    },
    {
      '1': 'fav_season',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizFavSeasonParam',
      '9': 0,
      '10': 'favSeason'
    },
    {'1': 'action', '3': 5, '4': 1, '5': 3, '10': 'action'},
  ],
  '8': [
    {'1': 'order_param'},
  ],
};

/// Descriptor for `ClickActivitySeasonReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickActivitySeasonReqDescriptor = $convert.base64Decode(
    'ChZDbGlja0FjdGl2aXR5U2Vhc29uUmVxEjwKCm9yZGVyX3R5cGUYASABKA4yHS5iaWxpYmlsaS'
    '5hcHAudmlldy52MS5CaXpUeXBlUglvcmRlclR5cGUSFAoFc3BtaWQYAiABKAlSBXNwbWlkEkkK'
    'B3Jlc2VydmUYAyABKAsyLS5iaWxpYmlsaS5hcHAudmlldy52MS5CaXpSZXNlcnZlQWN0aXZpdH'
    'lQYXJhbUgAUgdyZXNlcnZlEkgKCmZhdl9zZWFzb24YBCABKAsyJy5iaWxpYmlsaS5hcHAudmll'
    'dy52MS5CaXpGYXZTZWFzb25QYXJhbUgAUglmYXZTZWFzb24SFgoGYWN0aW9uGAUgASgDUgZhY3'
    'Rpb25CDQoLb3JkZXJfcGFyYW0=');

@$core.Deprecated('Use clickPlayerCardReplyDescriptor instead')
const ClickPlayerCardReply$json = {
  '1': 'ClickPlayerCardReply',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ClickPlayerCardReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickPlayerCardReplyDescriptor =
    $convert.base64Decode(
        'ChRDbGlja1BsYXllckNhcmRSZXBseRIYCgdtZXNzYWdlGAEgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use clickPlayerCardReqDescriptor instead')
const ClickPlayerCardReq$json = {
  '1': 'ClickPlayerCardReq',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'aid', '3': 2, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'action', '3': 4, '4': 1, '5': 3, '10': 'action'},
    {'1': 'spmid', '3': 5, '4': 1, '5': 9, '10': 'spmid'},
  ],
};

/// Descriptor for `ClickPlayerCardReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickPlayerCardReqDescriptor = $convert.base64Decode(
    'ChJDbGlja1BsYXllckNhcmRSZXESDgoCaWQYASABKANSAmlkEhAKA2FpZBgCIAEoA1IDYWlkEh'
    'AKA2NpZBgDIAEoA1IDY2lkEhYKBmFjdGlvbhgEIAEoA1IGYWN0aW9uEhQKBXNwbWlkGAUgASgJ'
    'UgVzcG1pZA==');

@$core.Deprecated('Use cMDescriptor instead')
const CM$json = {
  '1': 'CM',
  '2': [
    {
      '1': 'source_content',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'sourceContent'
    },
  ],
};

/// Descriptor for `CM`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cMDescriptor = $convert.base64Decode(
    'CgJDTRI7Cg5zb3VyY2VfY29udGVudBgBIAEoCzIULmdvb2dsZS5wcm90b2J1Zi5BbnlSDXNvdX'
    'JjZUNvbnRlbnQ=');

@$core.Deprecated('Use cMConfigDescriptor instead')
const CMConfig$json = {
  '1': 'CMConfig',
  '2': [
    {
      '1': 'ads_control',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'adsControl'
    },
  ],
};

/// Descriptor for `CMConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cMConfigDescriptor = $convert.base64Decode(
    'CghDTUNvbmZpZxI1CgthZHNfY29udHJvbBgBIAEoCzIULmdvb2dsZS5wcm90b2J1Zi5BbnlSCm'
    'Fkc0NvbnRyb2w=');

@$core.Deprecated('Use cmIpadDescriptor instead')
const CmIpad$json = {
  '1': 'CmIpad',
  '2': [
    {
      '1': 'cm',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CM',
      '10': 'cm'
    },
    {
      '1': 'author',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Author',
      '10': 'author'
    },
    {
      '1': 'stat',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Stat',
      '10': 'stat'
    },
    {'1': 'duration', '3': 4, '4': 1, '5': 3, '10': 'duration'},
    {'1': 'aid', '3': 5, '4': 1, '5': 3, '10': 'aid'},
  ],
};

/// Descriptor for `CmIpad`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cmIpadDescriptor = $convert.base64Decode(
    'CgZDbUlwYWQSKAoCY20YASABKAsyGC5iaWxpYmlsaS5hcHAudmlldy52MS5DTVICY20SNwoGYX'
    'V0aG9yGAIgASgLMh8uYmlsaWJpbGkuYXBwLmFyY2hpdmUudjEuQXV0aG9yUgZhdXRob3ISMQoE'
    'c3RhdBgDIAEoCzIdLmJpbGliaWxpLmFwcC5hcmNoaXZlLnYxLlN0YXRSBHN0YXQSGgoIZHVyYX'
    'Rpb24YBCABKANSCGR1cmF0aW9uEhAKA2FpZBgFIAEoA1IDYWlk');

@$core.Deprecated('Use coinCustomDescriptor instead')
const CoinCustom$json = {
  '1': 'CoinCustom',
  '2': [
    {'1': 'toast', '3': 1, '4': 1, '5': 9, '10': 'toast'},
  ],
};

/// Descriptor for `CoinCustom`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List coinCustomDescriptor =
    $convert.base64Decode('CgpDb2luQ3VzdG9tEhQKBXRvYXN0GAEgASgJUgV0b2FzdA==');

@$core.Deprecated('Use commandDmDescriptor instead')
const CommandDm$json = {
  '1': 'CommandDm',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'mid', '3': 3, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'command', '3': 4, '4': 1, '5': 9, '10': 'command'},
    {'1': 'content', '3': 5, '4': 1, '5': 9, '10': 'content'},
    {'1': 'progress', '3': 6, '4': 1, '5': 5, '10': 'progress'},
    {'1': 'ctime', '3': 7, '4': 1, '5': 9, '10': 'ctime'},
    {'1': 'mtime', '3': 8, '4': 1, '5': 9, '10': 'mtime'},
    {'1': 'extra', '3': 9, '4': 1, '5': 9, '10': 'extra'},
    {'1': 'id_str', '3': 10, '4': 1, '5': 9, '10': 'idStr'},
  ],
};

/// Descriptor for `CommandDm`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandDmDescriptor = $convert.base64Decode(
    'CglDb21tYW5kRG0SDgoCaWQYASABKANSAmlkEhAKA29pZBgCIAEoA1IDb2lkEhAKA21pZBgDIA'
    'EoA1IDbWlkEhgKB2NvbW1hbmQYBCABKAlSB2NvbW1hbmQSGAoHY29udGVudBgFIAEoCVIHY29u'
    'dGVudBIaCghwcm9ncmVzcxgGIAEoBVIIcHJvZ3Jlc3MSFAoFY3RpbWUYByABKAlSBWN0aW1lEh'
    'QKBW10aW1lGAggASgJUgVtdGltZRIUCgVleHRyYRgJIAEoCVIFZXh0cmESFQoGaWRfc3RyGAog'
    'ASgJUgVpZFN0cg==');

@$core.Deprecated('Use configDescriptor instead')
const Config$json = {
  '1': 'Config',
  '2': [
    {'1': 'relates_title', '3': 1, '4': 1, '5': 9, '10': 'relatesTitle'},
    {'1': 'relates_style', '3': 2, '4': 1, '5': 5, '10': 'relatesStyle'},
    {'1': 'relate_gif_exp', '3': 3, '4': 1, '5': 5, '10': 'relateGifExp'},
    {'1': 'end_page_half', '3': 4, '4': 1, '5': 5, '10': 'endPageHalf'},
    {'1': 'end_page_full', '3': 5, '4': 1, '5': 5, '10': 'endPageFull'},
    {'1': 'auto_swindow', '3': 6, '4': 1, '5': 8, '10': 'autoSwindow'},
    {'1': 'popup_info', '3': 7, '4': 1, '5': 8, '10': 'popupInfo'},
    {
      '1': 'abtest_small_window',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'abtestSmallWindow'
    },
    {
      '1': 'rec_three_point_style',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'recThreePointStyle'
    },
    {'1': 'is_absolute_time', '3': 10, '4': 1, '5': 8, '10': 'isAbsoluteTime'},
    {'1': 'new_swindow', '3': 11, '4': 1, '5': 8, '10': 'newSwindow'},
    {'1': 'relates_biserial', '3': 12, '4': 1, '5': 8, '10': 'relatesBiserial'},
    {
      '1': 'listener_conf',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ListenerConfig',
      '10': 'listenerConf'
    },
    {
      '1': 'relates_feed_style',
      '3': 14,
      '4': 1,
      '5': 9,
      '10': 'relatesFeedStyle'
    },
    {
      '1': 'relates_feed_popup',
      '3': 15,
      '4': 1,
      '5': 8,
      '10': 'relatesFeedPopup'
    },
    {'1': 'relates_has_next', '3': 16, '4': 1, '5': 8, '10': 'relatesHasNext'},
    {'1': 'local_play', '3': 17, '4': 1, '5': 5, '10': 'localPlay'},
    {'1': 'play_story', '3': 18, '4': 1, '5': 8, '10': 'playStory'},
    {'1': 'arc_play_story', '3': 19, '4': 1, '5': 8, '10': 'arcPlayStory'},
    {'1': 'story_icon', '3': 20, '4': 1, '5': 9, '10': 'storyIcon'},
    {'1': 'landscape_story', '3': 21, '4': 1, '5': 8, '10': 'landscapeStory'},
    {
      '1': 'arc_landscape_story',
      '3': 22,
      '4': 1,
      '5': 8,
      '10': 'arcLandscapeStory'
    },
    {'1': 'landscape_icon', '3': 23, '4': 1, '5': 9, '10': 'landscapeIcon'},
    {
      '1': 'show_listen_button',
      '3': 24,
      '4': 1,
      '5': 8,
      '10': 'showListenButton'
    },
  ],
};

/// Descriptor for `Config`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configDescriptor = $convert.base64Decode(
    'CgZDb25maWcSIwoNcmVsYXRlc190aXRsZRgBIAEoCVIMcmVsYXRlc1RpdGxlEiMKDXJlbGF0ZX'
    'Nfc3R5bGUYAiABKAVSDHJlbGF0ZXNTdHlsZRIkCg5yZWxhdGVfZ2lmX2V4cBgDIAEoBVIMcmVs'
    'YXRlR2lmRXhwEiIKDWVuZF9wYWdlX2hhbGYYBCABKAVSC2VuZFBhZ2VIYWxmEiIKDWVuZF9wYW'
    'dlX2Z1bGwYBSABKAVSC2VuZFBhZ2VGdWxsEiEKDGF1dG9fc3dpbmRvdxgGIAEoCFILYXV0b1N3'
    'aW5kb3cSHQoKcG9wdXBfaW5mbxgHIAEoCFIJcG9wdXBJbmZvEi4KE2FidGVzdF9zbWFsbF93aW'
    '5kb3cYCCABKAlSEWFidGVzdFNtYWxsV2luZG93EjEKFXJlY190aHJlZV9wb2ludF9zdHlsZRgJ'
    'IAEoBVIScmVjVGhyZWVQb2ludFN0eWxlEigKEGlzX2Fic29sdXRlX3RpbWUYCiABKAhSDmlzQW'
    'Jzb2x1dGVUaW1lEh8KC25ld19zd2luZG93GAsgASgIUgpuZXdTd2luZG93EikKEHJlbGF0ZXNf'
    'YmlzZXJpYWwYDCABKAhSD3JlbGF0ZXNCaXNlcmlhbBJJCg1saXN0ZW5lcl9jb25mGA0gASgLMi'
    'QuYmlsaWJpbGkuYXBwLnZpZXcudjEuTGlzdGVuZXJDb25maWdSDGxpc3RlbmVyQ29uZhIsChJy'
    'ZWxhdGVzX2ZlZWRfc3R5bGUYDiABKAlSEHJlbGF0ZXNGZWVkU3R5bGUSLAoScmVsYXRlc19mZW'
    'VkX3BvcHVwGA8gASgIUhByZWxhdGVzRmVlZFBvcHVwEigKEHJlbGF0ZXNfaGFzX25leHQYECAB'
    'KAhSDnJlbGF0ZXNIYXNOZXh0Eh0KCmxvY2FsX3BsYXkYESABKAVSCWxvY2FsUGxheRIdCgpwbG'
    'F5X3N0b3J5GBIgASgIUglwbGF5U3RvcnkSJAoOYXJjX3BsYXlfc3RvcnkYEyABKAhSDGFyY1Bs'
    'YXlTdG9yeRIdCgpzdG9yeV9pY29uGBQgASgJUglzdG9yeUljb24SJwoPbGFuZHNjYXBlX3N0b3'
    'J5GBUgASgIUg5sYW5kc2NhcGVTdG9yeRIuChNhcmNfbGFuZHNjYXBlX3N0b3J5GBYgASgIUhFh'
    'cmNMYW5kc2NhcGVTdG9yeRIlCg5sYW5kc2NhcGVfaWNvbhgXIAEoCVINbGFuZHNjYXBlSWNvbh'
    'IsChJzaG93X2xpc3Rlbl9idXR0b24YGCABKAhSEHNob3dMaXN0ZW5CdXR0b24=');

@$core.Deprecated('Use continuousPlayReplyDescriptor instead')
const ContinuousPlayReply$json = {
  '1': 'ContinuousPlayReply',
  '2': [
    {
      '1': 'relates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Relate',
      '10': 'relates'
    },
  ],
};

/// Descriptor for `ContinuousPlayReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List continuousPlayReplyDescriptor = $convert.base64Decode(
    'ChNDb250aW51b3VzUGxheVJlcGx5EjYKB3JlbGF0ZXMYASADKAsyHC5iaWxpYmlsaS5hcHAudm'
    'lldy52MS5SZWxhdGVSB3JlbGF0ZXM=');

@$core.Deprecated('Use continuousPlayReqDescriptor instead')
const ContinuousPlayReq$json = {
  '1': 'ContinuousPlayReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'from', '3': 2, '4': 1, '5': 9, '10': 'from'},
    {'1': 'trackid', '3': 3, '4': 1, '5': 9, '10': 'trackid'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 5, '4': 1, '5': 9, '10': 'fromSpmid'},
    {'1': 'autoplay', '3': 6, '4': 1, '5': 5, '10': 'autoplay'},
    {
      '1': 'player_args',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.middleware.v1.PlayerArgs',
      '10': 'playerArgs'
    },
    {'1': 'device_type', '3': 8, '4': 1, '5': 3, '10': 'deviceType'},
    {'1': 'session_id', '3': 9, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'display_id', '3': 10, '4': 1, '5': 3, '10': 'displayId'},
  ],
};

/// Descriptor for `ContinuousPlayReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List continuousPlayReqDescriptor = $convert.base64Decode(
    'ChFDb250aW51b3VzUGxheVJlcRIQCgNhaWQYASABKANSA2FpZBISCgRmcm9tGAIgASgJUgRmcm'
    '9tEhgKB3RyYWNraWQYAyABKAlSB3RyYWNraWQSFAoFc3BtaWQYBCABKAlSBXNwbWlkEh0KCmZy'
    'b21fc3BtaWQYBSABKAlSCWZyb21TcG1pZBIaCghhdXRvcGxheRgGIAEoBVIIYXV0b3BsYXkSTw'
    'oLcGxheWVyX2FyZ3MYByABKAsyLi5iaWxpYmlsaS5hcHAuYXJjaGl2ZS5taWRkbGV3YXJlLnYx'
    'LlBsYXllckFyZ3NSCnBsYXllckFyZ3MSHwoLZGV2aWNlX3R5cGUYCCABKANSCmRldmljZVR5cG'
    'USHQoKc2Vzc2lvbl9pZBgJIAEoCVIJc2Vzc2lvbklkEh0KCmRpc3BsYXlfaWQYCiABKANSCWRp'
    'c3BsYXlJZA==');

@$core.Deprecated('Use contractCardDescriptor instead')
const ContractCard$json = {
  '1': 'ContractCard',
  '2': [
    {'1': 'display_progress', '3': 1, '4': 1, '5': 2, '10': 'displayProgress'},
    {'1': 'display_accuracy', '3': 2, '4': 1, '5': 3, '10': 'displayAccuracy'},
    {'1': 'display_duration', '3': 3, '4': 1, '5': 3, '10': 'displayDuration'},
    {'1': 'show_mode', '3': 4, '4': 1, '5': 5, '10': 'showMode'},
    {'1': 'page_type', '3': 5, '4': 1, '5': 5, '10': 'pageType'},
    {
      '1': 'upper',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UpperInfos',
      '10': 'upper'
    },
    {'1': 'is_follow_display', '3': 7, '4': 1, '5': 5, '10': 'isFollowDisplay'},
    {
      '1': 'text',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ContractText',
      '10': 'text'
    },
    {
      '1': 'follow_display_end_duration',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'followDisplayEndDuration'
    },
    {'1': 'is_play_display', '3': 10, '4': 1, '5': 5, '10': 'isPlayDisplay'},
    {
      '1': 'is_interact_display',
      '3': 11,
      '4': 1,
      '5': 5,
      '10': 'isInteractDisplay'
    },
    {
      '1': 'play_display_switch',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'playDisplaySwitch'
    },
  ],
};

/// Descriptor for `ContractCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contractCardDescriptor = $convert.base64Decode(
    'CgxDb250cmFjdENhcmQSKQoQZGlzcGxheV9wcm9ncmVzcxgBIAEoAlIPZGlzcGxheVByb2dyZX'
    'NzEikKEGRpc3BsYXlfYWNjdXJhY3kYAiABKANSD2Rpc3BsYXlBY2N1cmFjeRIpChBkaXNwbGF5'
    'X2R1cmF0aW9uGAMgASgDUg9kaXNwbGF5RHVyYXRpb24SGwoJc2hvd19tb2RlGAQgASgFUghzaG'
    '93TW9kZRIbCglwYWdlX3R5cGUYBSABKAVSCHBhZ2VUeXBlEjYKBXVwcGVyGAYgASgLMiAuYmls'
    'aWJpbGkuYXBwLnZpZXcudjEuVXBwZXJJbmZvc1IFdXBwZXISKgoRaXNfZm9sbG93X2Rpc3BsYX'
    'kYByABKAVSD2lzRm9sbG93RGlzcGxheRI2CgR0ZXh0GAggASgLMiIuYmlsaWJpbGkuYXBwLnZp'
    'ZXcudjEuQ29udHJhY3RUZXh0UgR0ZXh0Ej0KG2ZvbGxvd19kaXNwbGF5X2VuZF9kdXJhdGlvbh'
    'gJIAEoA1IYZm9sbG93RGlzcGxheUVuZER1cmF0aW9uEiYKD2lzX3BsYXlfZGlzcGxheRgKIAEo'
    'BVINaXNQbGF5RGlzcGxheRIuChNpc19pbnRlcmFjdF9kaXNwbGF5GAsgASgFUhFpc0ludGVyYW'
    'N0RGlzcGxheRIuChNwbGF5X2Rpc3BsYXlfc3dpdGNoGAwgASgIUhFwbGF5RGlzcGxheVN3aXRj'
    'aA==');

@$core.Deprecated('Use contractTextDescriptor instead')
const ContractText$json = {
  '1': 'ContractText',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'subtitle', '3': 2, '4': 1, '5': 9, '10': 'subtitle'},
    {'1': 'inline_title', '3': 3, '4': 1, '5': 9, '10': 'inlineTitle'},
  ],
};

/// Descriptor for `ContractText`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contractTextDescriptor = $convert.base64Decode(
    'CgxDb250cmFjdFRleHQSFAoFdGl0bGUYASABKAlSBXRpdGxlEhoKCHN1YnRpdGxlGAIgASgJUg'
    'hzdWJ0aXRsZRIhCgxpbmxpbmVfdGl0bGUYAyABKAlSC2lubGluZVRpdGxl');

@$core.Deprecated('Use creativeContentDescriptor instead')
const CreativeContent$json = {
  '1': 'CreativeContent',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'button_title', '3': 3, '4': 1, '5': 9, '10': 'buttonTitle'},
    {'1': 'video_id', '3': 4, '4': 1, '5': 3, '10': 'videoId'},
    {'1': 'username', '3': 5, '4': 1, '5': 9, '10': 'username'},
    {'1': 'image_url', '3': 6, '4': 1, '5': 9, '10': 'imageUrl'},
    {'1': 'image_md5', '3': 7, '4': 1, '5': 9, '10': 'imageMd5'},
    {'1': 'log_url', '3': 8, '4': 1, '5': 9, '10': 'logUrl'},
    {'1': 'log_md5', '3': 9, '4': 1, '5': 9, '10': 'logMd5'},
    {'1': 'url', '3': 10, '4': 1, '5': 9, '10': 'url'},
    {'1': 'click_url', '3': 11, '4': 1, '5': 9, '10': 'clickUrl'},
    {'1': 'show_url', '3': 12, '4': 1, '5': 9, '10': 'showUrl'},
  ],
};

/// Descriptor for `CreativeContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List creativeContentDescriptor = $convert.base64Decode(
    'Cg9DcmVhdGl2ZUNvbnRlbnQSFAoFdGl0bGUYASABKAlSBXRpdGxlEiAKC2Rlc2NyaXB0aW9uGA'
    'IgASgJUgtkZXNjcmlwdGlvbhIhCgxidXR0b25fdGl0bGUYAyABKAlSC2J1dHRvblRpdGxlEhkK'
    'CHZpZGVvX2lkGAQgASgDUgd2aWRlb0lkEhoKCHVzZXJuYW1lGAUgASgJUgh1c2VybmFtZRIbCg'
    'lpbWFnZV91cmwYBiABKAlSCGltYWdlVXJsEhsKCWltYWdlX21kNRgHIAEoCVIIaW1hZ2VNZDUS'
    'FwoHbG9nX3VybBgIIAEoCVIGbG9nVXJsEhcKB2xvZ19tZDUYCSABKAlSBmxvZ01kNRIQCgN1cm'
    'wYCiABKAlSA3VybBIbCgljbGlja191cmwYCyABKAlSCGNsaWNrVXJsEhkKCHNob3dfdXJsGAwg'
    'ASgJUgdzaG93VXJs');

@$core.Deprecated('Use customConfigDescriptor instead')
const CustomConfig$json = {
  '1': 'CustomConfig',
  '2': [
    {'1': 'redirect_url', '3': 1, '4': 1, '5': 9, '10': 'redirectUrl'},
  ],
};

/// Descriptor for `CustomConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List customConfigDescriptor = $convert.base64Decode(
    'CgxDdXN0b21Db25maWcSIQoMcmVkaXJlY3RfdXJsGAEgASgJUgtyZWRpcmVjdFVybA==');

@$core.Deprecated('Use descV2Descriptor instead')
const DescV2$json = {
  '1': 'DescV2',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.DescType',
      '10': 'type'
    },
    {'1': 'uri', '3': 3, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'rid', '3': 4, '4': 1, '5': 3, '10': 'rid'},
  ],
};

/// Descriptor for `DescV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List descV2Descriptor = $convert.base64Decode(
    'CgZEZXNjVjISEgoEdGV4dBgBIAEoCVIEdGV4dBIyCgR0eXBlGAIgASgOMh4uYmlsaWJpbGkuYX'
    'BwLnZpZXcudjEuRGVzY1R5cGVSBHR5cGUSEAoDdXJpGAMgASgJUgN1cmkSEAoDcmlkGAQgASgD'
    'UgNyaWQ=');

@$core.Deprecated('Use dislikeDescriptor instead')
const Dislike$json = {
  '1': 'Dislike',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'subtitle', '3': 2, '4': 1, '5': 9, '10': 'subtitle'},
    {
      '1': 'reasons',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.DislikeReasons',
      '10': 'reasons'
    },
  ],
};

/// Descriptor for `Dislike`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dislikeDescriptor = $convert.base64Decode(
    'CgdEaXNsaWtlEhQKBXRpdGxlGAEgASgJUgV0aXRsZRIaCghzdWJ0aXRsZRgCIAEoCVIIc3VidG'
    'l0bGUSPgoHcmVhc29ucxgDIAMoCzIkLmJpbGliaWxpLmFwcC52aWV3LnYxLkRpc2xpa2VSZWFz'
    'b25zUgdyZWFzb25z');

@$core.Deprecated('Use dislikeReasonsDescriptor instead')
const DislikeReasons$json = {
  '1': 'DislikeReasons',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'mid', '3': 2, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'rid', '3': 3, '4': 1, '5': 5, '10': 'rid'},
    {'1': 'tag_id', '3': 4, '4': 1, '5': 3, '10': 'tagId'},
    {'1': 'name', '3': 5, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `DislikeReasons`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dislikeReasonsDescriptor = $convert.base64Decode(
    'Cg5EaXNsaWtlUmVhc29ucxIOCgJpZBgBIAEoA1ICaWQSEAoDbWlkGAIgASgDUgNtaWQSEAoDcm'
    'lkGAMgASgFUgNyaWQSFQoGdGFnX2lkGAQgASgDUgV0YWdJZBISCgRuYW1lGAUgASgJUgRuYW1l');

@$core.Deprecated('Use dMDescriptor instead')
const DM$json = {
  '1': 'DM',
  '2': [
    {'1': 'closed', '3': 1, '4': 1, '5': 8, '10': 'closed'},
    {'1': 'real_name', '3': 2, '4': 1, '5': 8, '10': 'realName'},
    {'1': 'count', '3': 3, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `DM`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dMDescriptor = $convert.base64Decode(
    'CgJETRIWCgZjbG9zZWQYASABKAhSBmNsb3NlZBIbCglyZWFsX25hbWUYAiABKAhSCHJlYWxOYW'
    '1lEhQKBWNvdW50GAMgASgDUgVjb3VudA==');

@$core.Deprecated('Use elecRankDescriptor instead')
const ElecRank$json = {
  '1': 'ElecRank',
  '2': [
    {
      '1': 'list',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ElecRankItem',
      '10': 'list'
    },
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `ElecRank`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List elecRankDescriptor = $convert.base64Decode(
    'CghFbGVjUmFuaxI2CgRsaXN0GAEgAygLMiIuYmlsaWJpbGkuYXBwLnZpZXcudjEuRWxlY1Jhbm'
    'tJdGVtUgRsaXN0EhQKBWNvdW50GAIgASgDUgVjb3VudBISCgR0ZXh0GAMgASgJUgR0ZXh0');

@$core.Deprecated('Use elecRankItemDescriptor instead')
const ElecRankItem$json = {
  '1': 'ElecRankItem',
  '2': [
    {'1': 'avatar', '3': 1, '4': 1, '5': 9, '10': 'avatar'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {'1': 'mid', '3': 4, '4': 1, '5': 3, '10': 'mid'},
  ],
};

/// Descriptor for `ElecRankItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List elecRankItemDescriptor = $convert.base64Decode(
    'CgxFbGVjUmFua0l0ZW0SFgoGYXZhdGFyGAEgASgJUgZhdmF0YXISGgoIbmlja25hbWUYAiABKA'
    'lSCG5pY2tuYW1lEhgKB21lc3NhZ2UYAyABKAlSB21lc3NhZ2USEAoDbWlkGAQgASgDUgNtaWQ=');

@$core.Deprecated('Use episodeDescriptor instead')
const Episode$json = {
  '1': 'Episode',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'aid', '3': 2, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cover', '3': 5, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'coverRightText', '3': 6, '4': 1, '5': 9, '10': 'coverRightText'},
    {
      '1': 'page',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Page',
      '10': 'page'
    },
    {
      '1': 'stat',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Stat',
      '10': 'stat'
    },
    {'1': 'bvid', '3': 9, '4': 1, '5': 9, '10': 'bvid'},
    {
      '1': 'author',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Author',
      '10': 'author'
    },
    {'1': 'author_desc', '3': 11, '4': 1, '5': 9, '10': 'authorDesc'},
    {
      '1': 'badge_style',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BadgeStyle',
      '10': 'badgeStyle'
    },
    {'1': 'need_pay', '3': 13, '4': 1, '5': 8, '10': 'needPay'},
    {'1': 'episode_pay', '3': 14, '4': 1, '5': 8, '10': 'episodePay'},
    {'1': 'free_watch', '3': 15, '4': 1, '5': 8, '10': 'freeWatch'},
    {'1': 'first_frame', '3': 16, '4': 1, '5': 9, '10': 'firstFrame'},
  ],
};

/// Descriptor for `Episode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List episodeDescriptor = $convert.base64Decode(
    'CgdFcGlzb2RlEg4KAmlkGAEgASgDUgJpZBIQCgNhaWQYAiABKANSA2FpZBIQCgNjaWQYAyABKA'
    'NSA2NpZBIUCgV0aXRsZRgEIAEoCVIFdGl0bGUSFAoFY292ZXIYBSABKAlSBWNvdmVyEiYKDmNv'
    'dmVyUmlnaHRUZXh0GAYgASgJUg5jb3ZlclJpZ2h0VGV4dBIxCgRwYWdlGAcgASgLMh0uYmlsaW'
    'JpbGkuYXBwLmFyY2hpdmUudjEuUGFnZVIEcGFnZRIxCgRzdGF0GAggASgLMh0uYmlsaWJpbGku'
    'YXBwLmFyY2hpdmUudjEuU3RhdFIEc3RhdBISCgRidmlkGAkgASgJUgRidmlkEjcKBmF1dGhvch'
    'gKIAEoCzIfLmJpbGliaWxpLmFwcC5hcmNoaXZlLnYxLkF1dGhvclIGYXV0aG9yEh8KC2F1dGhv'
    'cl9kZXNjGAsgASgJUgphdXRob3JEZXNjEkEKC2JhZGdlX3N0eWxlGAwgASgLMiAuYmlsaWJpbG'
    'kuYXBwLnZpZXcudjEuQmFkZ2VTdHlsZVIKYmFkZ2VTdHlsZRIZCghuZWVkX3BheRgNIAEoCFIH'
    'bmVlZFBheRIfCgtlcGlzb2RlX3BheRgOIAEoCFIKZXBpc29kZVBheRIdCgpmcmVlX3dhdGNoGA'
    '8gASgIUglmcmVlV2F0Y2gSHwoLZmlyc3RfZnJhbWUYECABKAlSCmZpcnN0RnJhbWU=');

@$core.Deprecated('Use exposePlayerCardReqDescriptor instead')
const ExposePlayerCardReq$json = {
  '1': 'ExposePlayerCardReq',
  '2': [
    {
      '1': 'card_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.PlayerCardType',
      '10': 'cardType'
    },
    {'1': 'aid', '3': 2, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
  ],
};

/// Descriptor for `ExposePlayerCardReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exposePlayerCardReqDescriptor = $convert.base64Decode(
    'ChNFeHBvc2VQbGF5ZXJDYXJkUmVxEkEKCWNhcmRfdHlwZRgBIAEoDjIkLmJpbGliaWxpLmFwcC'
    '52aWV3LnYxLlBsYXllckNhcmRUeXBlUghjYXJkVHlwZRIQCgNhaWQYAiABKANSA2FpZBIQCgNj'
    'aWQYAyABKANSA2NpZBIUCgVzcG1pZBgEIAEoCVIFc3BtaWQ=');

@$core.Deprecated('Use feedViewItemDescriptor instead')
const FeedViewItem$json = {
  '1': 'FeedViewItem',
  '2': [
    {
      '1': 'view',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewReply',
      '10': 'view'
    },
    {'1': 'goto', '3': 2, '4': 1, '5': 9, '10': 'goto'},
    {'1': 'uri', '3': 3, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'track_id', '3': 4, '4': 1, '5': 9, '10': 'trackId'},
  ],
};

/// Descriptor for `FeedViewItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feedViewItemDescriptor = $convert.base64Decode(
    'CgxGZWVkVmlld0l0ZW0SMwoEdmlldxgBIAEoCzIfLmJpbGliaWxpLmFwcC52aWV3LnYxLlZpZX'
    'dSZXBseVIEdmlldxISCgRnb3RvGAIgASgJUgRnb3RvEhAKA3VyaRgDIAEoCVIDdXJpEhkKCHRy'
    'YWNrX2lkGAQgASgJUgd0cmFja0lk');

@$core.Deprecated('Use feedViewReplyDescriptor instead')
const FeedViewReply$json = {
  '1': 'FeedViewReply',
  '2': [
    {
      '1': 'list',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.FeedViewItem',
      '10': 'list'
    },
    {'1': 'has_next', '3': 2, '4': 1, '5': 8, '10': 'hasNext'},
  ],
};

/// Descriptor for `FeedViewReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feedViewReplyDescriptor = $convert.base64Decode(
    'Cg1GZWVkVmlld1JlcGx5EjYKBGxpc3QYASADKAsyIi5iaWxpYmlsaS5hcHAudmlldy52MS5GZW'
    'VkVmlld0l0ZW1SBGxpc3QSGQoIaGFzX25leHQYAiABKAhSB2hhc05leHQ=');

@$core.Deprecated('Use feedViewReqDescriptor instead')
const FeedViewReq$json = {
  '1': 'FeedViewReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'from', '3': 3, '4': 1, '5': 9, '10': 'from'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 5, '4': 1, '5': 9, '10': 'fromSpmid'},
    {
      '1': 'player_args',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.middleware.v1.PlayerArgs',
      '10': 'playerArgs'
    },
    {'1': 'display_id', '3': 7, '4': 1, '5': 3, '10': 'displayId'},
    {'1': 'session_id', '3': 8, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'page_version', '3': 9, '4': 1, '5': 9, '10': 'pageVersion'},
    {'1': 'from_track_id', '3': 10, '4': 1, '5': 9, '10': 'fromTrackId'},
  ],
};

/// Descriptor for `FeedViewReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feedViewReqDescriptor = $convert.base64Decode(
    'CgtGZWVkVmlld1JlcRIQCgNhaWQYASABKANSA2FpZBISCgRidmlkGAIgASgJUgRidmlkEhIKBG'
    'Zyb20YAyABKAlSBGZyb20SFAoFc3BtaWQYBCABKAlSBXNwbWlkEh0KCmZyb21fc3BtaWQYBSAB'
    'KAlSCWZyb21TcG1pZBJPCgtwbGF5ZXJfYXJncxgGIAEoCzIuLmJpbGliaWxpLmFwcC5hcmNoaX'
    'ZlLm1pZGRsZXdhcmUudjEuUGxheWVyQXJnc1IKcGxheWVyQXJncxIdCgpkaXNwbGF5X2lkGAcg'
    'ASgDUglkaXNwbGF5SWQSHQoKc2Vzc2lvbl9pZBgIIAEoCVIJc2Vzc2lvbklkEiEKDHBhZ2Vfdm'
    'Vyc2lvbhgJIAEoCVILcGFnZVZlcnNpb24SIgoNZnJvbV90cmFja19pZBgKIAEoCVILZnJvbVRy'
    'YWNrSWQ=');

@$core.Deprecated('Use getArcsPlayerReplyDescriptor instead')
const GetArcsPlayerReply$json = {
  '1': 'GetArcsPlayerReply',
  '2': [
    {
      '1': 'arcs_player',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ArcsPlayer',
      '10': 'arcsPlayer'
    },
  ],
};

/// Descriptor for `GetArcsPlayerReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArcsPlayerReplyDescriptor = $convert.base64Decode(
    'ChJHZXRBcmNzUGxheWVyUmVwbHkSQQoLYXJjc19wbGF5ZXIYASADKAsyIC5iaWxpYmlsaS5hcH'
    'Audmlldy52MS5BcmNzUGxheWVyUgphcmNzUGxheWVy');

@$core.Deprecated('Use getArcsPlayerReqDescriptor instead')
const GetArcsPlayerReq$json = {
  '1': 'GetArcsPlayerReq',
  '2': [
    {
      '1': 'play_avs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.PlayAv',
      '10': 'playAvs'
    },
    {
      '1': 'player_args',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.middleware.v1.PlayerArgs',
      '10': 'playerArgs'
    },
  ],
};

/// Descriptor for `GetArcsPlayerReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArcsPlayerReqDescriptor = $convert.base64Decode(
    'ChBHZXRBcmNzUGxheWVyUmVxEjcKCHBsYXlfYXZzGAEgAygLMhwuYmlsaWJpbGkuYXBwLnZpZX'
    'cudjEuUGxheUF2UgdwbGF5QXZzEk8KC3BsYXllcl9hcmdzGAIgASgLMi4uYmlsaWJpbGkuYXBw'
    'LmFyY2hpdmUubWlkZGxld2FyZS52MS5QbGF5ZXJBcmdzUgpwbGF5ZXJBcmdz');

@$core.Deprecated('Use goodsInfoDescriptor instead')
const GoodsInfo$json = {
  '1': 'GoodsInfo',
  '2': [
    {'1': 'goods_id', '3': 1, '4': 1, '5': 9, '10': 'goodsId'},
    {'1': 'category', '3': 2, '4': 1, '5': 5, '10': 'category'},
    {'1': 'goods_price', '3': 3, '4': 1, '5': 3, '10': 'goodsPrice'},
    {
      '1': 'pay_state',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.PayState',
      '10': 'payState'
    },
    {'1': 'goods_name', '3': 5, '4': 1, '5': 9, '10': 'goodsName'},
    {'1': 'price_fmt', '3': 6, '4': 1, '5': 9, '10': 'priceFmt'},
  ],
};

/// Descriptor for `GoodsInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List goodsInfoDescriptor = $convert.base64Decode(
    'CglHb29kc0luZm8SGQoIZ29vZHNfaWQYASABKAlSB2dvb2RzSWQSGgoIY2F0ZWdvcnkYAiABKA'
    'VSCGNhdGVnb3J5Eh8KC2dvb2RzX3ByaWNlGAMgASgDUgpnb29kc1ByaWNlEjsKCXBheV9zdGF0'
    'ZRgEIAEoDjIeLmJpbGliaWxpLmFwcC52aWV3LnYxLlBheVN0YXRlUghwYXlTdGF0ZRIdCgpnb2'
    '9kc19uYW1lGAUgASgJUglnb29kc05hbWUSGwoJcHJpY2VfZm10GAYgASgJUghwcmljZUZtdA==');

@$core.Deprecated('Use historyDescriptor instead')
const History$json = {
  '1': 'History',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'progress', '3': 2, '4': 1, '5': 3, '10': 'progress'},
  ],
};

/// Descriptor for `History`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyDescriptor = $convert.base64Decode(
    'CgdIaXN0b3J5EhAKA2NpZBgBIAEoA1IDY2lkEhoKCHByb2dyZXNzGAIgASgDUghwcm9ncmVzcw'
    '==');

@$core.Deprecated('Use honorDescriptor instead')
const Honor$json = {
  '1': 'Honor',
  '2': [
    {'1': 'icon', '3': 1, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'icon_night', '3': 2, '4': 1, '5': 9, '10': 'iconNight'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_extra', '3': 4, '4': 1, '5': 9, '10': 'textExtra'},
    {'1': 'text_color', '3': 5, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_color_night', '3': 6, '4': 1, '5': 9, '10': 'textColorNight'},
    {'1': 'bg_color', '3': 7, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'bg_color_night', '3': 8, '4': 1, '5': 9, '10': 'bgColorNight'},
    {'1': 'url', '3': 9, '4': 1, '5': 9, '10': 'url'},
    {'1': 'url_text', '3': 10, '4': 1, '5': 9, '10': 'urlText'},
  ],
};

/// Descriptor for `Honor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List honorDescriptor = $convert.base64Decode(
    'CgVIb25vchISCgRpY29uGAEgASgJUgRpY29uEh0KCmljb25fbmlnaHQYAiABKAlSCWljb25OaW'
    'dodBISCgR0ZXh0GAMgASgJUgR0ZXh0Eh0KCnRleHRfZXh0cmEYBCABKAlSCXRleHRFeHRyYRId'
    'Cgp0ZXh0X2NvbG9yGAUgASgJUgl0ZXh0Q29sb3ISKAoQdGV4dF9jb2xvcl9uaWdodBgGIAEoCV'
    'IOdGV4dENvbG9yTmlnaHQSGQoIYmdfY29sb3IYByABKAlSB2JnQ29sb3ISJAoOYmdfY29sb3Jf'
    'bmlnaHQYCCABKAlSDGJnQ29sb3JOaWdodBIQCgN1cmwYCSABKAlSA3VybBIZCgh1cmxfdGV4dB'
    'gKIAEoCVIHdXJsVGV4dA==');

@$core.Deprecated('Use iconDataDescriptor instead')
const IconData$json = {
  '1': 'IconData',
  '2': [
    {'1': 'meta_json', '3': 1, '4': 1, '5': 9, '10': 'metaJson'},
    {'1': 'sprits_img', '3': 2, '4': 1, '5': 9, '10': 'spritsImg'},
  ],
};

/// Descriptor for `IconData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconDataDescriptor = $convert.base64Decode(
    'CghJY29uRGF0YRIbCgltZXRhX2pzb24YASABKAlSCG1ldGFKc29uEh0KCnNwcml0c19pbWcYAi'
    'ABKAlSCXNwcml0c0ltZw==');

@$core.Deprecated('Use interactionDescriptor instead')
const Interaction$json = {
  '1': 'Interaction',
  '2': [
    {
      '1': 'history_node',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Node',
      '10': 'historyNode'
    },
    {'1': 'graph_version', '3': 2, '4': 1, '5': 3, '10': 'graphVersion'},
    {'1': 'msg', '3': 3, '4': 1, '5': 9, '10': 'msg'},
    {'1': 'evaluation', '3': 4, '4': 1, '5': 9, '10': 'evaluation'},
    {'1': 'mark', '3': 5, '4': 1, '5': 3, '10': 'mark'},
  ],
};

/// Descriptor for `Interaction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interactionDescriptor = $convert.base64Decode(
    'CgtJbnRlcmFjdGlvbhI9CgxoaXN0b3J5X25vZGUYASABKAsyGi5iaWxpYmlsaS5hcHAudmlldy'
    '52MS5Ob2RlUgtoaXN0b3J5Tm9kZRIjCg1ncmFwaF92ZXJzaW9uGAIgASgDUgxncmFwaFZlcnNp'
    'b24SEAoDbXNnGAMgASgJUgNtc2cSHgoKZXZhbHVhdGlvbhgEIAEoCVIKZXZhbHVhdGlvbhISCg'
    'RtYXJrGAUgASgDUgRtYXJr');

@$core.Deprecated('Use labelDescriptor instead')
const Label$json = {
  '1': 'Label',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'uri', '3': 2, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'icon_night', '3': 4, '4': 1, '5': 9, '10': 'iconNight'},
    {'1': 'icon_width', '3': 5, '4': 1, '5': 3, '10': 'iconWidth'},
    {'1': 'icon_height', '3': 6, '4': 1, '5': 3, '10': 'iconHeight'},
    {'1': 'lottie', '3': 7, '4': 1, '5': 9, '10': 'lottie'},
    {'1': 'lottie_night', '3': 8, '4': 1, '5': 9, '10': 'lottieNight'},
  ],
};

/// Descriptor for `Label`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List labelDescriptor = $convert.base64Decode(
    'CgVMYWJlbBISCgR0eXBlGAEgASgFUgR0eXBlEhAKA3VyaRgCIAEoCVIDdXJpEhIKBGljb24YAy'
    'ABKAlSBGljb24SHQoKaWNvbl9uaWdodBgEIAEoCVIJaWNvbk5pZ2h0Eh0KCmljb25fd2lkdGgY'
    'BSABKANSCWljb25XaWR0aBIfCgtpY29uX2hlaWdodBgGIAEoA1IKaWNvbkhlaWdodBIWCgZsb3'
    'R0aWUYByABKAlSBmxvdHRpZRIhCgxsb3R0aWVfbmlnaHQYCCABKAlSC2xvdHRpZU5pZ2h0');

@$core.Deprecated('Use likeAnimationDescriptor instead')
const LikeAnimation$json = {
  '1': 'LikeAnimation',
  '2': [
    {'1': 'like_icon', '3': 1, '4': 1, '5': 9, '10': 'likeIcon'},
    {'1': 'liked_icon', '3': 2, '4': 1, '5': 9, '10': 'likedIcon'},
    {'1': 'like_animation', '3': 3, '4': 1, '5': 9, '10': 'likeAnimation'},
  ],
};

/// Descriptor for `LikeAnimation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List likeAnimationDescriptor = $convert.base64Decode(
    'Cg1MaWtlQW5pbWF0aW9uEhsKCWxpa2VfaWNvbhgBIAEoCVIIbGlrZUljb24SHQoKbGlrZWRfaW'
    'NvbhgCIAEoCVIJbGlrZWRJY29uEiUKDmxpa2VfYW5pbWF0aW9uGAMgASgJUg1saWtlQW5pbWF0'
    'aW9u');

@$core.Deprecated('Use likeCustomDescriptor instead')
const LikeCustom$json = {
  '1': 'LikeCustom',
  '2': [
    {'1': 'like_switch', '3': 1, '4': 1, '5': 8, '10': 'likeSwitch'},
    {
      '1': 'full_to_half_progress',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'fullToHalfProgress'
    },
    {'1': 'non_full_progress', '3': 3, '4': 1, '5': 3, '10': 'nonFullProgress'},
    {'1': 'update_count', '3': 4, '4': 1, '5': 3, '10': 'updateCount'},
  ],
};

/// Descriptor for `LikeCustom`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List likeCustomDescriptor = $convert.base64Decode(
    'CgpMaWtlQ3VzdG9tEh8KC2xpa2Vfc3dpdGNoGAEgASgIUgpsaWtlU3dpdGNoEjEKFWZ1bGxfdG'
    '9faGFsZl9wcm9ncmVzcxgCIAEoA1ISZnVsbFRvSGFsZlByb2dyZXNzEioKEW5vbl9mdWxsX3By'
    'b2dyZXNzGAMgASgDUg9ub25GdWxsUHJvZ3Jlc3MSIQoMdXBkYXRlX2NvdW50GAQgASgDUgt1cG'
    'RhdGVDb3VudA==');

@$core.Deprecated('Use listenerConfigDescriptor instead')
const ListenerConfig$json = {
  '1': 'ListenerConfig',
  '2': [
    {'1': 'jump_style', '3': 1, '4': 1, '5': 3, '10': 'jumpStyle'},
    {
      '1': 'guide_bar',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ListenerGuideBar',
      '10': 'guideBar'
    },
  ],
};

/// Descriptor for `ListenerConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listenerConfigDescriptor = $convert.base64Decode(
    'Cg5MaXN0ZW5lckNvbmZpZxIdCgpqdW1wX3N0eWxlGAEgASgDUglqdW1wU3R5bGUSQwoJZ3VpZG'
    'VfYmFyGAIgASgLMiYuYmlsaWJpbGkuYXBwLnZpZXcudjEuTGlzdGVuZXJHdWlkZUJhclIIZ3Vp'
    'ZGVCYXI=');

@$core.Deprecated('Use listenerGuideBarDescriptor instead')
const ListenerGuideBar$json = {
  '1': 'ListenerGuideBar',
  '2': [
    {'1': 'show_strategy', '3': 1, '4': 1, '5': 3, '10': 'showStrategy'},
    {'1': 'icon', '3': 2, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'btn_text', '3': 4, '4': 1, '5': 9, '10': 'btnText'},
    {'1': 'show_time', '3': 5, '4': 1, '5': 3, '10': 'showTime'},
    {'1': 'background_time', '3': 6, '4': 1, '5': 3, '10': 'backgroundTime'},
  ],
};

/// Descriptor for `ListenerGuideBar`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listenerGuideBarDescriptor = $convert.base64Decode(
    'ChBMaXN0ZW5lckd1aWRlQmFyEiMKDXNob3dfc3RyYXRlZ3kYASABKANSDHNob3dTdHJhdGVneR'
    'ISCgRpY29uGAIgASgJUgRpY29uEhIKBHRleHQYAyABKAlSBHRleHQSGQoIYnRuX3RleHQYBCAB'
    'KAlSB2J0blRleHQSGwoJc2hvd190aW1lGAUgASgDUghzaG93VGltZRInCg9iYWNrZ3JvdW5kX3'
    'RpbWUYBiABKANSDmJhY2tncm91bmRUaW1l');

@$core.Deprecated('Use liveDescriptor instead')
const Live$json = {
  '1': 'Live',
  '2': [
    {'1': 'mid', '3': 1, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'roomid', '3': 2, '4': 1, '5': 3, '10': 'roomid'},
    {'1': 'uri', '3': 3, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'endpage_uri', '3': 4, '4': 1, '5': 9, '10': 'endpageUri'},
  ],
};

/// Descriptor for `Live`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List liveDescriptor = $convert.base64Decode(
    'CgRMaXZlEhAKA21pZBgBIAEoA1IDbWlkEhYKBnJvb21pZBgCIAEoA1IGcm9vbWlkEhAKA3VyaR'
    'gDIAEoCVIDdXJpEh8KC2VuZHBhZ2VfdXJpGAQgASgJUgplbmRwYWdlVXJp');

@$core.Deprecated('Use liveOrderInfoDescriptor instead')
const LiveOrderInfo$json = {
  '1': 'LiveOrderInfo',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 3, '10': 'sid'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'live_plan_start_time',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'livePlanStartTime'
    },
    {'1': 'is_follow', '3': 4, '4': 1, '5': 8, '10': 'isFollow'},
  ],
};

/// Descriptor for `LiveOrderInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List liveOrderInfoDescriptor = $convert.base64Decode(
    'Cg1MaXZlT3JkZXJJbmZvEhAKA3NpZBgBIAEoA1IDc2lkEhIKBHRleHQYAiABKAlSBHRleHQSLw'
    'oUbGl2ZV9wbGFuX3N0YXJ0X3RpbWUYAyABKANSEWxpdmVQbGFuU3RhcnRUaW1lEhsKCWlzX2Zv'
    'bGxvdxgEIAEoCFIIaXNGb2xsb3c=');

@$core.Deprecated('Use materialLeftDescriptor instead')
const MaterialLeft$json = {
  '1': 'MaterialLeft',
  '2': [
    {'1': 'icon', '3': 1, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'url', '3': 3, '4': 1, '5': 9, '10': 'url'},
    {'1': 'left_type', '3': 4, '4': 1, '5': 9, '10': 'leftType'},
    {'1': 'param', '3': 5, '4': 1, '5': 9, '10': 'param'},
    {'1': 'operational_type', '3': 6, '4': 1, '5': 9, '10': 'operationalType'},
    {'1': 'static_icon', '3': 7, '4': 1, '5': 9, '10': 'staticIcon'},
  ],
};

/// Descriptor for `MaterialLeft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List materialLeftDescriptor = $convert.base64Decode(
    'CgxNYXRlcmlhbExlZnQSEgoEaWNvbhgBIAEoCVIEaWNvbhISCgR0ZXh0GAIgASgJUgR0ZXh0Eh'
    'AKA3VybBgDIAEoCVIDdXJsEhsKCWxlZnRfdHlwZRgEIAEoCVIIbGVmdFR5cGUSFAoFcGFyYW0Y'
    'BSABKAlSBXBhcmFtEikKEG9wZXJhdGlvbmFsX3R5cGUYBiABKAlSD29wZXJhdGlvbmFsVHlwZR'
    'IfCgtzdGF0aWNfaWNvbhgHIAEoCVIKc3RhdGljSWNvbg==');

@$core.Deprecated('Use materialResDescriptor instead')
const MaterialRes$json = {
  '1': 'MaterialRes',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'icon', '3': 2, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'url', '3': 3, '4': 1, '5': 9, '10': 'url'},
    {
      '1': 'type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.MaterialSource',
      '10': 'type'
    },
    {'1': 'name', '3': 5, '4': 1, '5': 9, '10': 'name'},
    {'1': 'bg_color', '3': 6, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'bg_pic', '3': 7, '4': 1, '5': 9, '10': 'bgPic'},
    {'1': 'jump_type', '3': 8, '4': 1, '5': 5, '10': 'jumpType'},
  ],
};

/// Descriptor for `MaterialRes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List materialResDescriptor = $convert.base64Decode(
    'CgtNYXRlcmlhbFJlcxIOCgJpZBgBIAEoA1ICaWQSEgoEaWNvbhgCIAEoCVIEaWNvbhIQCgN1cm'
    'wYAyABKAlSA3VybBI4CgR0eXBlGAQgASgOMiQuYmlsaWJpbGkuYXBwLnZpZXcudjEuTWF0ZXJp'
    'YWxTb3VyY2VSBHR5cGUSEgoEbmFtZRgFIAEoCVIEbmFtZRIZCghiZ19jb2xvchgGIAEoCVIHYm'
    'dDb2xvchIVCgZiZ19waWMYByABKAlSBWJnUGljEhsKCWp1bXBfdHlwZRgIIAEoBVIIanVtcFR5'
    'cGU=');

@$core.Deprecated('Use nodeDescriptor instead')
const Node$json = {
  '1': 'Node',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 3, '10': 'nodeId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
  ],
};

/// Descriptor for `Node`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeDescriptor = $convert.base64Decode(
    'CgROb2RlEhcKB25vZGVfaWQYASABKANSBm5vZGVJZBIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSEA'
    'oDY2lkGAMgASgDUgNjaWQ=');

@$core.Deprecated('Use noReplyDescriptor instead')
const NoReply$json = {
  '1': 'NoReply',
};

/// Descriptor for `NoReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List noReplyDescriptor =
    $convert.base64Decode('CgdOb1JlcGx5');

@$core.Deprecated('Use noticeDescriptor instead')
const Notice$json = {
  '1': 'Notice',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'desc', '3': 2, '4': 1, '5': 9, '10': 'desc'},
  ],
};

/// Descriptor for `Notice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List noticeDescriptor = $convert.base64Decode(
    'CgZOb3RpY2USFAoFdGl0bGUYASABKAlSBXRpdGxlEhIKBGRlc2MYAiABKAlSBGRlc2M=');

@$core.Deprecated('Use officialVerifyDescriptor instead')
const OfficialVerify$json = {
  '1': 'OfficialVerify',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'desc', '3': 2, '4': 1, '5': 9, '10': 'desc'},
  ],
};

/// Descriptor for `OfficialVerify`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List officialVerifyDescriptor = $convert.base64Decode(
    'Cg5PZmZpY2lhbFZlcmlmeRISCgR0eXBlGAEgASgFUgR0eXBlEhIKBGRlc2MYAiABKAlSBGRlc2'
    'M=');

@$core.Deprecated('Use onlineDescriptor instead')
const Online$json = {
  '1': 'Online',
  '2': [
    {'1': 'online_show', '3': 1, '4': 1, '5': 8, '10': 'onlineShow'},
    {
      '1': 'player_online_logo',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'playerOnlineLogo'
    },
  ],
};

/// Descriptor for `Online`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onlineDescriptor = $convert.base64Decode(
    'CgZPbmxpbmUSHwoLb25saW5lX3Nob3cYASABKAhSCm9ubGluZVNob3cSLAoScGxheWVyX29ubG'
    'luZV9sb2dvGAIgASgJUhBwbGF5ZXJPbmxpbmVMb2dv');

@$core.Deprecated('Use onwerExtDescriptor instead')
const OnwerExt$json = {
  '1': 'OnwerExt',
  '2': [
    {
      '1': 'official_verify',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OfficialVerify',
      '10': 'officialVerify'
    },
    {
      '1': 'live',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Live',
      '10': 'live'
    },
    {
      '1': 'vip',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Vip',
      '10': 'vip'
    },
    {'1': 'assists', '3': 4, '4': 3, '5': 3, '10': 'assists'},
    {'1': 'fans', '3': 5, '4': 1, '5': 3, '10': 'fans'},
    {'1': 'arc_count', '3': 6, '4': 1, '5': 9, '10': 'arcCount'},
  ],
};

/// Descriptor for `OnwerExt`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onwerExtDescriptor = $convert.base64Decode(
    'CghPbndlckV4dBJNCg9vZmZpY2lhbF92ZXJpZnkYASABKAsyJC5iaWxpYmlsaS5hcHAudmlldy'
    '52MS5PZmZpY2lhbFZlcmlmeVIOb2ZmaWNpYWxWZXJpZnkSLgoEbGl2ZRgCIAEoCzIaLmJpbGli'
    'aWxpLmFwcC52aWV3LnYxLkxpdmVSBGxpdmUSKwoDdmlwGAMgASgLMhkuYmlsaWJpbGkuYXBwLn'
    'ZpZXcudjEuVmlwUgN2aXASGAoHYXNzaXN0cxgEIAMoA1IHYXNzaXN0cxISCgRmYW5zGAUgASgD'
    'UgRmYW5zEhsKCWFyY19jb3VudBgGIAEoCVIIYXJjQ291bnQ=');

@$core.Deprecated('Use operationCardDescriptor instead')
const OperationCard$json = {
  '1': 'OperationCard',
  '2': [
    {'1': 'start_time', '3': 1, '4': 1, '5': 5, '10': 'startTime'},
    {'1': 'end_time', '3': 2, '4': 1, '5': 5, '10': 'endTime'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'button_text', '3': 5, '4': 1, '5': 9, '10': 'buttonText'},
    {'1': 'url', '3': 6, '4': 1, '5': 9, '10': 'url'},
    {'1': 'content', '3': 7, '4': 1, '5': 9, '10': 'content'},
  ],
};

/// Descriptor for `OperationCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationCardDescriptor = $convert.base64Decode(
    'Cg1PcGVyYXRpb25DYXJkEh0KCnN0YXJ0X3RpbWUYASABKAVSCXN0YXJ0VGltZRIZCghlbmRfdG'
    'ltZRgCIAEoBVIHZW5kVGltZRISCgRpY29uGAMgASgJUgRpY29uEhQKBXRpdGxlGAQgASgJUgV0'
    'aXRsZRIfCgtidXR0b25fdGV4dBgFIAEoCVIKYnV0dG9uVGV4dBIQCgN1cmwYBiABKAlSA3VybB'
    'IYCgdjb250ZW50GAcgASgJUgdjb250ZW50');

@$core.Deprecated('Use operationCardNewDescriptor instead')
const OperationCardNew$json = {
  '1': 'OperationCardNew',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'from', '3': 2, '4': 1, '5': 5, '10': 'from'},
    {'1': 'to', '3': 3, '4': 1, '5': 5, '10': 'to'},
    {'1': 'status', '3': 4, '4': 1, '5': 8, '10': 'status'},
    {
      '1': 'card_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.OperationCardType',
      '10': 'cardType'
    },
    {
      '1': 'standard',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.StandardCard',
      '9': 0,
      '10': 'standard'
    },
    {
      '1': 'skip',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OperationCard',
      '9': 0,
      '10': 'skip'
    },
    {
      '1': 'biz_type',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.BizType',
      '10': 'bizType'
    },
    {
      '1': 'follow',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizFollowVideoParam',
      '9': 1,
      '10': 'follow'
    },
    {
      '1': 'reserve',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizReserveActivityParam',
      '9': 1,
      '10': 'reserve'
    },
    {
      '1': 'jump',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizJumpLinkParam',
      '9': 1,
      '10': 'jump'
    },
    {
      '1': 'game',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizReserveGameParam',
      '9': 1,
      '10': 'game'
    },
  ],
  '8': [
    {'1': 'render'},
    {'1': 'param'},
  ],
};

/// Descriptor for `OperationCardNew`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationCardNewDescriptor = $convert.base64Decode(
    'ChBPcGVyYXRpb25DYXJkTmV3Eg4KAmlkGAEgASgDUgJpZBISCgRmcm9tGAIgASgFUgRmcm9tEg'
    '4KAnRvGAMgASgFUgJ0bxIWCgZzdGF0dXMYBCABKAhSBnN0YXR1cxJECgljYXJkX3R5cGUYBSAB'
    'KA4yJy5iaWxpYmlsaS5hcHAudmlldy52MS5PcGVyYXRpb25DYXJkVHlwZVIIY2FyZFR5cGUSQA'
    'oIc3RhbmRhcmQYBiABKAsyIi5iaWxpYmlsaS5hcHAudmlldy52MS5TdGFuZGFyZENhcmRIAFII'
    'c3RhbmRhcmQSOQoEc2tpcBgHIAEoCzIjLmJpbGliaWxpLmFwcC52aWV3LnYxLk9wZXJhdGlvbk'
    'NhcmRIAFIEc2tpcBI4CghiaXpfdHlwZRgIIAEoDjIdLmJpbGliaWxpLmFwcC52aWV3LnYxLkJp'
    'elR5cGVSB2JpelR5cGUSQwoGZm9sbG93GAkgASgLMikuYmlsaWJpbGkuYXBwLnZpZXcudjEuQm'
    'l6Rm9sbG93VmlkZW9QYXJhbUgBUgZmb2xsb3cSSQoHcmVzZXJ2ZRgKIAEoCzItLmJpbGliaWxp'
    'LmFwcC52aWV3LnYxLkJpelJlc2VydmVBY3Rpdml0eVBhcmFtSAFSB3Jlc2VydmUSPAoEanVtcB'
    'gLIAEoCzImLmJpbGliaWxpLmFwcC52aWV3LnYxLkJpekp1bXBMaW5rUGFyYW1IAVIEanVtcBI/'
    'CgRnYW1lGAwgASgLMikuYmlsaWJpbGkuYXBwLnZpZXcudjEuQml6UmVzZXJ2ZUdhbWVQYXJhbU'
    'gBUgRnYW1lQggKBnJlbmRlckIHCgVwYXJhbQ==');

@$core.Deprecated('Use operationCardV2Descriptor instead')
const OperationCardV2$json = {
  '1': 'OperationCardV2',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'from', '3': 2, '4': 1, '5': 5, '10': 'from'},
    {'1': 'to', '3': 3, '4': 1, '5': 5, '10': 'to'},
    {'1': 'status', '3': 4, '4': 1, '5': 8, '10': 'status'},
    {'1': 'biz_type', '3': 5, '4': 1, '5': 5, '10': 'bizType'},
    {
      '1': 'content',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OperationCardV2Content',
      '10': 'content'
    },
    {
      '1': 'BizFollowVideoParam',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizFollowVideoParam',
      '9': 0,
      '10': 'BizFollowVideoParam'
    },
    {
      '1': 'BizReserveActivityParam',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizReserveActivityParam',
      '9': 0,
      '10': 'BizReserveActivityParam'
    },
    {
      '1': 'BizJumpLinkParam',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizJumpLinkParam',
      '9': 0,
      '10': 'BizJumpLinkParam'
    },
    {
      '1': 'BizReserveGameParam',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizReserveGameParam',
      '9': 0,
      '10': 'BizReserveGameParam'
    },
  ],
  '8': [
    {'1': 'param'},
  ],
};

/// Descriptor for `OperationCardV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationCardV2Descriptor = $convert.base64Decode(
    'Cg9PcGVyYXRpb25DYXJkVjISDgoCaWQYASABKANSAmlkEhIKBGZyb20YAiABKAVSBGZyb20SDg'
    'oCdG8YAyABKAVSAnRvEhYKBnN0YXR1cxgEIAEoCFIGc3RhdHVzEhkKCGJpel90eXBlGAUgASgF'
    'UgdiaXpUeXBlEkYKB2NvbnRlbnQYBiABKAsyLC5iaWxpYmlsaS5hcHAudmlldy52MS5PcGVyYX'
    'Rpb25DYXJkVjJDb250ZW50Ugdjb250ZW50El0KE0JpekZvbGxvd1ZpZGVvUGFyYW0YByABKAsy'
    'KS5iaWxpYmlsaS5hcHAudmlldy52MS5CaXpGb2xsb3dWaWRlb1BhcmFtSABSE0JpekZvbGxvd1'
    'ZpZGVvUGFyYW0SaQoXQml6UmVzZXJ2ZUFjdGl2aXR5UGFyYW0YCCABKAsyLS5iaWxpYmlsaS5h'
    'cHAudmlldy52MS5CaXpSZXNlcnZlQWN0aXZpdHlQYXJhbUgAUhdCaXpSZXNlcnZlQWN0aXZpdH'
    'lQYXJhbRJUChBCaXpKdW1wTGlua1BhcmFtGAkgASgLMiYuYmlsaWJpbGkuYXBwLnZpZXcudjEu'
    'Qml6SnVtcExpbmtQYXJhbUgAUhBCaXpKdW1wTGlua1BhcmFtEl0KE0JpelJlc2VydmVHYW1lUG'
    'FyYW0YCiABKAsyKS5iaWxpYmlsaS5hcHAudmlldy52MS5CaXpSZXNlcnZlR2FtZVBhcmFtSABS'
    'E0JpelJlc2VydmVHYW1lUGFyYW1CBwoFcGFyYW0=');

@$core.Deprecated('Use operationCardV2ContentDescriptor instead')
const OperationCardV2Content$json = {
  '1': 'OperationCardV2Content',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'subtitle', '3': 2, '4': 1, '5': 9, '10': 'subtitle'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'button_title', '3': 4, '4': 1, '5': 9, '10': 'buttonTitle'},
    {
      '1': 'button_selected_title',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'buttonSelectedTitle'
    },
    {'1': 'show_selected', '3': 6, '4': 1, '5': 8, '10': 'showSelected'},
  ],
};

/// Descriptor for `OperationCardV2Content`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationCardV2ContentDescriptor = $convert.base64Decode(
    'ChZPcGVyYXRpb25DYXJkVjJDb250ZW50EhQKBXRpdGxlGAEgASgJUgV0aXRsZRIaCghzdWJ0aX'
    'RsZRgCIAEoCVIIc3VidGl0bGUSEgoEaWNvbhgDIAEoCVIEaWNvbhIhCgxidXR0b25fdGl0bGUY'
    'BCABKAlSC2J1dHRvblRpdGxlEjIKFWJ1dHRvbl9zZWxlY3RlZF90aXRsZRgFIAEoCVITYnV0dG'
    '9uU2VsZWN0ZWRUaXRsZRIjCg1zaG93X3NlbGVjdGVkGAYgASgIUgxzaG93U2VsZWN0ZWQ=');

@$core.Deprecated('Use operationRelateDescriptor instead')
const OperationRelate$json = {
  '1': 'OperationRelate',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'relate_item',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.RelateItem',
      '10': 'relateItem'
    },
    {
      '1': 'ai_relate_item',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Relate',
      '10': 'aiRelateItem'
    },
  ],
};

/// Descriptor for `OperationRelate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationRelateDescriptor = $convert.base64Decode(
    'Cg9PcGVyYXRpb25SZWxhdGUSFAoFdGl0bGUYASABKAlSBXRpdGxlEkEKC3JlbGF0ZV9pdGVtGA'
    'IgAygLMiAuYmlsaWJpbGkuYXBwLnZpZXcudjEuUmVsYXRlSXRlbVIKcmVsYXRlSXRlbRJCCg5h'
    'aV9yZWxhdGVfaXRlbRgDIAMoCzIcLmJpbGliaWxpLmFwcC52aWV3LnYxLlJlbGF0ZVIMYWlSZW'
    'xhdGVJdGVt');

@$core.Deprecated('Use orderDescriptor instead')
const Order$json = {
  '1': 'Order',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 8, '10': 'status'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'button_title', '3': 3, '4': 1, '5': 9, '10': 'buttonTitle'},
    {
      '1': 'button_selected_title',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'buttonSelectedTitle'
    },
    {'1': 'season_stat_view', '3': 5, '4': 1, '5': 3, '10': 'seasonStatView'},
    {
      '1': 'season_stat_danmaku',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'seasonStatDanmaku'
    },
    {
      '1': 'order_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.BizType',
      '10': 'orderType'
    },
    {
      '1': 'reserve',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizReserveActivityParam',
      '9': 0,
      '10': 'reserve'
    },
    {
      '1': 'fav_season',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.BizFavSeasonParam',
      '9': 0,
      '10': 'favSeason'
    },
    {'1': 'intro', '3': 10, '4': 1, '5': 9, '10': 'intro'},
  ],
  '8': [
    {'1': 'order_param'},
  ],
};

/// Descriptor for `Order`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List orderDescriptor = $convert.base64Decode(
    'CgVPcmRlchIWCgZzdGF0dXMYASABKAhSBnN0YXR1cxIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSIQ'
    'oMYnV0dG9uX3RpdGxlGAMgASgJUgtidXR0b25UaXRsZRIyChVidXR0b25fc2VsZWN0ZWRfdGl0'
    'bGUYBCABKAlSE2J1dHRvblNlbGVjdGVkVGl0bGUSKAoQc2Vhc29uX3N0YXRfdmlldxgFIAEoA1'
    'IOc2Vhc29uU3RhdFZpZXcSLgoTc2Vhc29uX3N0YXRfZGFubWFrdRgGIAEoA1IRc2Vhc29uU3Rh'
    'dERhbm1ha3USPAoKb3JkZXJfdHlwZRgHIAEoDjIdLmJpbGliaWxpLmFwcC52aWV3LnYxLkJpel'
    'R5cGVSCW9yZGVyVHlwZRJJCgdyZXNlcnZlGAggASgLMi0uYmlsaWJpbGkuYXBwLnZpZXcudjEu'
    'Qml6UmVzZXJ2ZUFjdGl2aXR5UGFyYW1IAFIHcmVzZXJ2ZRJICgpmYXZfc2Vhc29uGAkgASgLMi'
    'cuYmlsaWJpbGkuYXBwLnZpZXcudjEuQml6RmF2U2Vhc29uUGFyYW1IAFIJZmF2U2Vhc29uEhQK'
    'BWludHJvGAogASgJUgVpbnRyb0INCgtvcmRlcl9wYXJhbQ==');

@$core.Deprecated('Use packInfoDescriptor instead')
const PackInfo$json = {
  '1': 'PackInfo',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'uri', '3': 2, '4': 1, '5': 9, '10': 'uri'},
  ],
};

/// Descriptor for `PackInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List packInfoDescriptor = $convert.base64Decode(
    'CghQYWNrSW5mbxIUCgV0aXRsZRgBIAEoCVIFdGl0bGUSEAoDdXJpGAIgASgJUgN1cmk=');

@$core.Deprecated('Use playAvDescriptor instead')
const PlayAv$json = {
  '1': 'PlayAv',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
  ],
};

/// Descriptor for `PlayAv`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playAvDescriptor = $convert.base64Decode(
    'CgZQbGF5QXYSEAoDYWlkGAEgASgDUgNhaWQSEAoDY2lkGAIgASgDUgNjaWQ=');

@$core.Deprecated('Use playerIconDescriptor instead')
const PlayerIcon$json = {
  '1': 'PlayerIcon',
  '2': [
    {'1': 'url1', '3': 1, '4': 1, '5': 9, '10': 'url1'},
    {'1': 'hash1', '3': 2, '4': 1, '5': 9, '10': 'hash1'},
    {'1': 'url2', '3': 3, '4': 1, '5': 9, '10': 'url2'},
    {'1': 'hash2', '3': 4, '4': 1, '5': 9, '10': 'hash2'},
    {'1': 'drag_left_png', '3': 5, '4': 1, '5': 9, '10': 'dragLeftPng'},
    {'1': 'middle_png', '3': 6, '4': 1, '5': 9, '10': 'middlePng'},
    {'1': 'drag_right_png', '3': 7, '4': 1, '5': 9, '10': 'dragRightPng'},
    {
      '1': 'drag_data',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.IconData',
      '10': 'dragData'
    },
    {
      '1': 'nodrag_data',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.IconData',
      '10': 'nodragData'
    },
  ],
};

/// Descriptor for `PlayerIcon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerIconDescriptor = $convert.base64Decode(
    'CgpQbGF5ZXJJY29uEhIKBHVybDEYASABKAlSBHVybDESFAoFaGFzaDEYAiABKAlSBWhhc2gxEh'
    'IKBHVybDIYAyABKAlSBHVybDISFAoFaGFzaDIYBCABKAlSBWhhc2gyEiIKDWRyYWdfbGVmdF9w'
    'bmcYBSABKAlSC2RyYWdMZWZ0UG5nEh0KCm1pZGRsZV9wbmcYBiABKAlSCW1pZGRsZVBuZxIkCg'
    '5kcmFnX3JpZ2h0X3BuZxgHIAEoCVIMZHJhZ1JpZ2h0UG5nEjsKCWRyYWdfZGF0YRgIIAEoCzIe'
    'LmJpbGliaWxpLmFwcC52aWV3LnYxLkljb25EYXRhUghkcmFnRGF0YRI/Cgtub2RyYWdfZGF0YR'
    'gJIAEoCzIeLmJpbGliaWxpLmFwcC52aWV3LnYxLkljb25EYXRhUgpub2RyYWdEYXRh');

@$core.Deprecated('Use playerRelatesReplyDescriptor instead')
const PlayerRelatesReply$json = {
  '1': 'PlayerRelatesReply',
  '2': [
    {
      '1': 'list',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Relate',
      '10': 'list'
    },
  ],
};

/// Descriptor for `PlayerRelatesReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerRelatesReplyDescriptor = $convert.base64Decode(
    'ChJQbGF5ZXJSZWxhdGVzUmVwbHkSMAoEbGlzdBgBIAMoCzIcLmJpbGliaWxpLmFwcC52aWV3Ln'
    'YxLlJlbGF0ZVIEbGlzdA==');

@$core.Deprecated('Use playerRelatesReqDescriptor instead')
const PlayerRelatesReq$json = {
  '1': 'PlayerRelatesReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'from', '3': 3, '4': 1, '5': 9, '10': 'from'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 5, '4': 1, '5': 9, '10': 'fromSpmid'},
    {
      '1': 'player_args',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.middleware.v1.PlayerArgs',
      '10': 'playerArgs'
    },
    {'1': 'session_id', '3': 7, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'from_track_id', '3': 8, '4': 1, '5': 9, '10': 'fromTrackId'},
  ],
};

/// Descriptor for `PlayerRelatesReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerRelatesReqDescriptor = $convert.base64Decode(
    'ChBQbGF5ZXJSZWxhdGVzUmVxEhAKA2FpZBgBIAEoA1IDYWlkEhIKBGJ2aWQYAiABKAlSBGJ2aW'
    'QSEgoEZnJvbRgDIAEoCVIEZnJvbRIUCgVzcG1pZBgEIAEoCVIFc3BtaWQSHQoKZnJvbV9zcG1p'
    'ZBgFIAEoCVIJZnJvbVNwbWlkEk8KC3BsYXllcl9hcmdzGAYgASgLMi4uYmlsaWJpbGkuYXBwLm'
    'FyY2hpdmUubWlkZGxld2FyZS52MS5QbGF5ZXJBcmdzUgpwbGF5ZXJBcmdzEh0KCnNlc3Npb25f'
    'aWQYByABKAlSCXNlc3Npb25JZBIiCg1mcm9tX3RyYWNrX2lkGAggASgJUgtmcm9tVHJhY2tJZA'
    '==');

@$core.Deprecated('Use pointMaterialDescriptor instead')
const PointMaterial$json = {
  '1': 'PointMaterial',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'material_source', '3': 2, '4': 1, '5': 5, '10': 'materialSource'},
  ],
};

/// Descriptor for `PointMaterial`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pointMaterialDescriptor = $convert.base64Decode(
    'Cg1Qb2ludE1hdGVyaWFsEhAKA3VybBgBIAEoCVIDdXJsEicKD21hdGVyaWFsX3NvdXJjZRgCIA'
    'EoBVIObWF0ZXJpYWxTb3VyY2U=');

@$core.Deprecated('Use powerIconStyleDescriptor instead')
const PowerIconStyle$json = {
  '1': 'PowerIconStyle',
  '2': [
    {'1': 'icon_url', '3': 1, '4': 1, '5': 9, '10': 'iconUrl'},
    {'1': 'icon_night_url', '3': 2, '4': 1, '5': 9, '10': 'iconNightUrl'},
    {'1': 'icon_width', '3': 3, '4': 1, '5': 3, '10': 'iconWidth'},
    {'1': 'icon_height', '3': 4, '4': 1, '5': 3, '10': 'iconHeight'},
  ],
};

/// Descriptor for `PowerIconStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List powerIconStyleDescriptor = $convert.base64Decode(
    'Cg5Qb3dlckljb25TdHlsZRIZCghpY29uX3VybBgBIAEoCVIHaWNvblVybBIkCg5pY29uX25pZ2'
    'h0X3VybBgCIAEoCVIMaWNvbk5pZ2h0VXJsEh0KCmljb25fd2lkdGgYAyABKANSCWljb25XaWR0'
    'aBIfCgtpY29uX2hlaWdodBgEIAEoA1IKaWNvbkhlaWdodA==');

@$core.Deprecated('Use premiereDescriptor instead')
const Premiere$json = {
  '1': 'Premiere',
  '2': [
    {
      '1': 'premiere_state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.PremiereState',
      '10': 'premiereState'
    },
    {'1': 'start_time', '3': 2, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'service_time', '3': 3, '4': 1, '5': 3, '10': 'serviceTime'},
    {'1': 'room_id', '3': 4, '4': 1, '5': 3, '10': 'roomId'},
  ],
};

/// Descriptor for `Premiere`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List premiereDescriptor = $convert.base64Decode(
    'CghQcmVtaWVyZRJKCg5wcmVtaWVyZV9zdGF0ZRgBIAEoDjIjLmJpbGliaWxpLmFwcC52aWV3Ln'
    'YxLlByZW1pZXJlU3RhdGVSDXByZW1pZXJlU3RhdGUSHQoKc3RhcnRfdGltZRgCIAEoA1IJc3Rh'
    'cnRUaW1lEiEKDHNlcnZpY2VfdGltZRgDIAEoA1ILc2VydmljZVRpbWUSFwoHcm9vbV9pZBgEIA'
    'EoA1IGcm9vbUlk');

@$core.Deprecated('Use premiereArchiveReplyDescriptor instead')
const PremiereArchiveReply$json = {
  '1': 'PremiereArchiveReply',
  '2': [
    {
      '1': 'premiere',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Premiere',
      '10': 'premiere'
    },
    {'1': 'risk_status', '3': 2, '4': 1, '5': 8, '10': 'riskStatus'},
    {'1': 'risk_reason', '3': 3, '4': 1, '5': 9, '10': 'riskReason'},
  ],
};

/// Descriptor for `PremiereArchiveReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List premiereArchiveReplyDescriptor = $convert.base64Decode(
    'ChRQcmVtaWVyZUFyY2hpdmVSZXBseRI6CghwcmVtaWVyZRgBIAEoCzIeLmJpbGliaWxpLmFwcC'
    '52aWV3LnYxLlByZW1pZXJlUghwcmVtaWVyZRIfCgtyaXNrX3N0YXR1cxgCIAEoCFIKcmlza1N0'
    'YXR1cxIfCgtyaXNrX3JlYXNvbhgDIAEoCVIKcmlza1JlYXNvbg==');

@$core.Deprecated('Use premiereArchiveReqDescriptor instead')
const PremiereArchiveReq$json = {
  '1': 'PremiereArchiveReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
  ],
};

/// Descriptor for `PremiereArchiveReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List premiereArchiveReqDescriptor = $convert
    .base64Decode('ChJQcmVtaWVyZUFyY2hpdmVSZXESEAoDYWlkGAEgASgDUgNhaWQ=');

@$core.Deprecated('Use premiereReserveDescriptor instead')
const PremiereReserve$json = {
  '1': 'PremiereReserve',
  '2': [
    {'1': 'reserve_id', '3': 1, '4': 1, '5': 3, '10': 'reserveId'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
    {'1': 'is_follow', '3': 3, '4': 1, '5': 8, '10': 'isFollow'},
  ],
};

/// Descriptor for `PremiereReserve`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List premiereReserveDescriptor = $convert.base64Decode(
    'Cg9QcmVtaWVyZVJlc2VydmUSHQoKcmVzZXJ2ZV9pZBgBIAEoA1IJcmVzZXJ2ZUlkEhQKBWNvdW'
    '50GAIgASgDUgVjb3VudBIbCglpc19mb2xsb3cYAyABKAhSCGlzRm9sbG93');

@$core.Deprecated('Use premiereResourceDescriptor instead')
const PremiereResource$json = {
  '1': 'PremiereResource',
  '2': [
    {
      '1': 'premiere',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Premiere',
      '10': 'premiere'
    },
    {
      '1': 'reserve',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PremiereReserve',
      '10': 'reserve'
    },
    {
      '1': 'text',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PremiereText',
      '10': 'text'
    },
  ],
};

/// Descriptor for `PremiereResource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List premiereResourceDescriptor = $convert.base64Decode(
    'ChBQcmVtaWVyZVJlc291cmNlEjoKCHByZW1pZXJlGAEgASgLMh4uYmlsaWJpbGkuYXBwLnZpZX'
    'cudjEuUHJlbWllcmVSCHByZW1pZXJlEj8KB3Jlc2VydmUYAiABKAsyJS5iaWxpYmlsaS5hcHAu'
    'dmlldy52MS5QcmVtaWVyZVJlc2VydmVSB3Jlc2VydmUSNgoEdGV4dBgDIAEoCzIiLmJpbGliaW'
    'xpLmFwcC52aWV3LnYxLlByZW1pZXJlVGV4dFIEdGV4dA==');

@$core.Deprecated('Use premiereTextDescriptor instead')
const PremiereText$json = {
  '1': 'PremiereText',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'subtitle', '3': 2, '4': 1, '5': 9, '10': 'subtitle'},
    {'1': 'online_text', '3': 3, '4': 1, '5': 9, '10': 'onlineText'},
    {'1': 'online_icon', '3': 4, '4': 1, '5': 9, '10': 'onlineIcon'},
    {'1': 'online_icon_dark', '3': 5, '4': 1, '5': 9, '10': 'onlineIconDark'},
    {'1': 'intro_title', '3': 6, '4': 1, '5': 9, '10': 'introTitle'},
    {'1': 'intro_icon', '3': 7, '4': 1, '5': 9, '10': 'introIcon'},
    {
      '1': 'guidance_pulldown',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'guidancePulldown'
    },
    {'1': 'guidance_entry', '3': 9, '4': 1, '5': 9, '10': 'guidanceEntry'},
    {'1': 'intro_icon_night', '3': 10, '4': 1, '5': 9, '10': 'introIconNight'},
  ],
};

/// Descriptor for `PremiereText`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List premiereTextDescriptor = $convert.base64Decode(
    'CgxQcmVtaWVyZVRleHQSFAoFdGl0bGUYASABKAlSBXRpdGxlEhoKCHN1YnRpdGxlGAIgASgJUg'
    'hzdWJ0aXRsZRIfCgtvbmxpbmVfdGV4dBgDIAEoCVIKb25saW5lVGV4dBIfCgtvbmxpbmVfaWNv'
    'bhgEIAEoCVIKb25saW5lSWNvbhIoChBvbmxpbmVfaWNvbl9kYXJrGAUgASgJUg5vbmxpbmVJY2'
    '9uRGFyaxIfCgtpbnRyb190aXRsZRgGIAEoCVIKaW50cm9UaXRsZRIdCgppbnRyb19pY29uGAcg'
    'ASgJUglpbnRyb0ljb24SKwoRZ3VpZGFuY2VfcHVsbGRvd24YCCABKAlSEGd1aWRhbmNlUHVsbG'
    'Rvd24SJQoOZ3VpZGFuY2VfZW50cnkYCSABKAlSDWd1aWRhbmNlRW50cnkSKAoQaW50cm9faWNv'
    'bl9uaWdodBgKIAEoCVIOaW50cm9JY29uTmlnaHQ=');

@$core.Deprecated('Use pullClientActionDescriptor instead')
const PullClientAction$json = {
  '1': 'PullClientAction',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {'1': 'pull_action', '3': 2, '4': 1, '5': 8, '10': 'pullAction'},
    {'1': 'params', '3': 3, '4': 1, '5': 9, '10': 'params'},
  ],
};

/// Descriptor for `PullClientAction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullClientActionDescriptor = $convert.base64Decode(
    'ChBQdWxsQ2xpZW50QWN0aW9uEhIKBHR5cGUYASABKAlSBHR5cGUSHwoLcHVsbF9hY3Rpb24YAi'
    'ABKAhSCnB1bGxBY3Rpb24SFgoGcGFyYW1zGAMgASgJUgZwYXJhbXM=');

@$core.Deprecated('Use rankDescriptor instead')
const Rank$json = {
  '1': 'Rank',
  '2': [
    {'1': 'icon', '3': 1, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'icon_night', '3': 2, '4': 1, '5': 9, '10': 'iconNight'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `Rank`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rankDescriptor = $convert.base64Decode(
    'CgRSYW5rEhIKBGljb24YASABKAlSBGljb24SHQoKaWNvbl9uaWdodBgCIAEoCVIJaWNvbk5pZ2'
    'h0EhIKBHRleHQYAyABKAlSBHRleHQ=');

@$core.Deprecated('Use rankInfoDescriptor instead')
const RankInfo$json = {
  '1': 'RankInfo',
  '2': [
    {'1': 'icon_url_night', '3': 1, '4': 1, '5': 9, '10': 'iconUrlNight'},
    {'1': 'icon_url_day', '3': 2, '4': 1, '5': 9, '10': 'iconUrlDay'},
    {'1': 'bkg_night_color', '3': 3, '4': 1, '5': 9, '10': 'bkgNightColor'},
    {'1': 'bkg_day_color', '3': 4, '4': 1, '5': 9, '10': 'bkgDayColor'},
    {'1': 'font_night_color', '3': 5, '4': 1, '5': 9, '10': 'fontNightColor'},
    {'1': 'font_day_color', '3': 6, '4': 1, '5': 9, '10': 'fontDayColor'},
    {'1': 'rank_content', '3': 7, '4': 1, '5': 9, '10': 'rankContent'},
    {'1': 'rank_link', '3': 8, '4': 1, '5': 9, '10': 'rankLink'},
  ],
};

/// Descriptor for `RankInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rankInfoDescriptor = $convert.base64Decode(
    'CghSYW5rSW5mbxIkCg5pY29uX3VybF9uaWdodBgBIAEoCVIMaWNvblVybE5pZ2h0EiAKDGljb2'
    '5fdXJsX2RheRgCIAEoCVIKaWNvblVybERheRImCg9ia2dfbmlnaHRfY29sb3IYAyABKAlSDWJr'
    'Z05pZ2h0Q29sb3ISIgoNYmtnX2RheV9jb2xvchgEIAEoCVILYmtnRGF5Q29sb3ISKAoQZm9udF'
    '9uaWdodF9jb2xvchgFIAEoCVIOZm9udE5pZ2h0Q29sb3ISJAoOZm9udF9kYXlfY29sb3IYBiAB'
    'KAlSDGZvbnREYXlDb2xvchIhCgxyYW5rX2NvbnRlbnQYByABKAlSC3JhbmtDb250ZW50EhsKCX'
    'JhbmtfbGluaxgIIAEoCVIIcmFua0xpbms=');

@$core.Deprecated('Use reasonStyleDescriptor instead')
const ReasonStyle$json = {
  '1': 'ReasonStyle',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 2, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'bg_color', '3': 3, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'border_color', '3': 4, '4': 1, '5': 9, '10': 'borderColor'},
    {'1': 'text_color_night', '3': 5, '4': 1, '5': 9, '10': 'textColorNight'},
    {'1': 'bg_color_night', '3': 6, '4': 1, '5': 9, '10': 'bgColorNight'},
    {
      '1': 'border_color_night',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'borderColorNight'
    },
    {'1': 'bg_style', '3': 8, '4': 1, '5': 5, '10': 'bgStyle'},
    {'1': 'selected', '3': 9, '4': 1, '5': 5, '10': 'selected'},
  ],
};

/// Descriptor for `ReasonStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reasonStyleDescriptor = $convert.base64Decode(
    'CgtSZWFzb25TdHlsZRISCgR0ZXh0GAEgASgJUgR0ZXh0Eh0KCnRleHRfY29sb3IYAiABKAlSCX'
    'RleHRDb2xvchIZCghiZ19jb2xvchgDIAEoCVIHYmdDb2xvchIhCgxib3JkZXJfY29sb3IYBCAB'
    'KAlSC2JvcmRlckNvbG9yEigKEHRleHRfY29sb3JfbmlnaHQYBSABKAlSDnRleHRDb2xvck5pZ2'
    'h0EiQKDmJnX2NvbG9yX25pZ2h0GAYgASgJUgxiZ0NvbG9yTmlnaHQSLAoSYm9yZGVyX2NvbG9y'
    'X25pZ2h0GAcgASgJUhBib3JkZXJDb2xvck5pZ2h0EhkKCGJnX3N0eWxlGAggASgFUgdiZ1N0eW'
    'xlEhoKCHNlbGVjdGVkGAkgASgFUghzZWxlY3RlZA==');

@$core.Deprecated('Use recDislikeDescriptor instead')
const RecDislike$json = {
  '1': 'RecDislike',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'sub_title', '3': 2, '4': 1, '5': 9, '10': 'subTitle'},
    {'1': 'closed_sub_title', '3': 3, '4': 1, '5': 9, '10': 'closedSubTitle'},
    {'1': 'paste_text', '3': 4, '4': 1, '5': 9, '10': 'pasteText'},
    {'1': 'closed_paste_text', '3': 5, '4': 1, '5': 9, '10': 'closedPasteText'},
    {
      '1': 'dislike_reason',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.DislikeReasons',
      '10': 'dislikeReason'
    },
    {'1': 'toast', '3': 7, '4': 1, '5': 9, '10': 'toast'},
    {'1': 'closed_toast', '3': 8, '4': 1, '5': 9, '10': 'closedToast'},
  ],
};

/// Descriptor for `RecDislike`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recDislikeDescriptor = $convert.base64Decode(
    'CgpSZWNEaXNsaWtlEhQKBXRpdGxlGAEgASgJUgV0aXRsZRIbCglzdWJfdGl0bGUYAiABKAlSCH'
    'N1YlRpdGxlEigKEGNsb3NlZF9zdWJfdGl0bGUYAyABKAlSDmNsb3NlZFN1YlRpdGxlEh0KCnBh'
    'c3RlX3RleHQYBCABKAlSCXBhc3RlVGV4dBIqChFjbG9zZWRfcGFzdGVfdGV4dBgFIAEoCVIPY2'
    'xvc2VkUGFzdGVUZXh0EksKDmRpc2xpa2VfcmVhc29uGAYgAygLMiQuYmlsaWJpbGkuYXBwLnZp'
    'ZXcudjEuRGlzbGlrZVJlYXNvbnNSDWRpc2xpa2VSZWFzb24SFAoFdG9hc3QYByABKAlSBXRvYX'
    'N0EiEKDGNsb3NlZF90b2FzdBgIIAEoCVILY2xvc2VkVG9hc3Q=');

@$core.Deprecated('Use recThreePointDescriptor instead')
const RecThreePoint$json = {
  '1': 'RecThreePoint',
  '2': [
    {
      '1': 'dislike',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.RecDislike',
      '10': 'dislike'
    },
    {
      '1': 'feedback',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.RecDislike',
      '10': 'feedback'
    },
    {'1': 'watch_later', '3': 3, '4': 1, '5': 8, '10': 'watchLater'},
  ],
};

/// Descriptor for `RecThreePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recThreePointDescriptor = $convert.base64Decode(
    'Cg1SZWNUaHJlZVBvaW50EjoKB2Rpc2xpa2UYASABKAsyIC5iaWxpYmlsaS5hcHAudmlldy52MS'
    '5SZWNEaXNsaWtlUgdkaXNsaWtlEjwKCGZlZWRiYWNrGAIgASgLMiAuYmlsaWJpbGkuYXBwLnZp'
    'ZXcudjEuUmVjRGlzbGlrZVIIZmVlZGJhY2sSHwoLd2F0Y2hfbGF0ZXIYAyABKAhSCndhdGNoTG'
    'F0ZXI=');

@$core.Deprecated('Use refreshPageDescriptor instead')
const RefreshPage$json = {
  '1': 'RefreshPage',
  '2': [
    {'1': 'refreshable', '3': 1, '4': 1, '5': 5, '10': 'refreshable'},
    {'1': 'refresh_icon', '3': 2, '4': 1, '5': 5, '10': 'refreshIcon'},
    {'1': 'refresh_text', '3': 3, '4': 1, '5': 9, '10': 'refreshText'},
    {'1': 'refresh_show', '3': 4, '4': 1, '5': 2, '10': 'refreshShow'},
  ],
};

/// Descriptor for `RefreshPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshPageDescriptor = $convert.base64Decode(
    'CgtSZWZyZXNoUGFnZRIgCgtyZWZyZXNoYWJsZRgBIAEoBVILcmVmcmVzaGFibGUSIQoMcmVmcm'
    'VzaF9pY29uGAIgASgFUgtyZWZyZXNoSWNvbhIhCgxyZWZyZXNoX3RleHQYAyABKAlSC3JlZnJl'
    'c2hUZXh0EiEKDHJlZnJlc2hfc2hvdxgEIAEoAlILcmVmcmVzaFNob3c=');

@$core.Deprecated('Use relateDescriptor instead')
const Relate$json = {
  '1': 'Relate',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'pic', '3': 2, '4': 1, '5': 9, '10': 'pic'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'author',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Author',
      '10': 'author'
    },
    {
      '1': 'stat',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Stat',
      '10': 'stat'
    },
    {'1': 'duration', '3': 6, '4': 1, '5': 3, '10': 'duration'},
    {'1': 'goto', '3': 7, '4': 1, '5': 9, '10': 'goto'},
    {'1': 'param', '3': 8, '4': 1, '5': 9, '10': 'param'},
    {'1': 'uri', '3': 9, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'jump_url', '3': 10, '4': 1, '5': 9, '10': 'jumpUrl'},
    {'1': 'rating', '3': 11, '4': 1, '5': 1, '10': 'rating'},
    {'1': 'reserve', '3': 12, '4': 1, '5': 9, '10': 'reserve'},
    {'1': 'from', '3': 13, '4': 1, '5': 9, '10': 'from'},
    {'1': 'desc', '3': 14, '4': 1, '5': 9, '10': 'desc'},
    {'1': 'rcmd_reason', '3': 15, '4': 1, '5': 9, '10': 'rcmdReason'},
    {'1': 'badge', '3': 16, '4': 1, '5': 9, '10': 'badge'},
    {'1': 'cid', '3': 17, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'season_type', '3': 18, '4': 1, '5': 5, '10': 'seasonType'},
    {'1': 'rating_count', '3': 19, '4': 1, '5': 5, '10': 'ratingCount'},
    {'1': 'tag_name', '3': 20, '4': 1, '5': 9, '10': 'tagName'},
    {
      '1': 'pack_info',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PackInfo',
      '10': 'packInfo'
    },
    {
      '1': 'notice',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Notice',
      '10': 'notice'
    },
    {
      '1': 'button',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Button',
      '10': 'button'
    },
    {'1': 'trackid', '3': 24, '4': 1, '5': 9, '10': 'trackid'},
    {'1': 'new_card', '3': 25, '4': 1, '5': 5, '10': 'newCard'},
    {
      '1': 'rcmd_reason_style',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReasonStyle',
      '10': 'rcmdReasonStyle'
    },
    {'1': 'cover_gif', '3': 27, '4': 1, '5': 9, '10': 'coverGif'},
    {
      '1': 'cm',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CM',
      '10': 'cm'
    },
    {'1': 'reserve_status', '3': 29, '4': 1, '5': 3, '10': 'reserveStatus'},
    {
      '1': 'rcmd_reason_extra',
      '3': 30,
      '4': 1,
      '5': 9,
      '10': 'rcmdReasonExtra'
    },
    {
      '1': 'rec_three_point',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.RecThreePoint',
      '10': 'recThreePoint'
    },
    {'1': 'unique_id', '3': 32, '4': 1, '5': 9, '10': 'uniqueId'},
    {'1': 'material_id', '3': 33, '4': 1, '5': 3, '10': 'materialId'},
    {'1': 'from_source_type', '3': 34, '4': 1, '5': 3, '10': 'fromSourceType'},
    {'1': 'from_source_id', '3': 35, '4': 1, '5': 9, '10': 'fromSourceId'},
    {
      '1': 'dimension',
      '3': 36,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Dimension',
      '10': 'dimension'
    },
    {'1': 'cover', '3': 37, '4': 1, '5': 9, '10': 'cover'},
    {
      '1': 'badge_style',
      '3': 38,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReasonStyle',
      '10': 'badgeStyle'
    },
    {
      '1': 'power_icon_style',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PowerIconStyle',
      '10': 'powerIconStyle'
    },
    {
      '1': 'reserve_status_text',
      '3': 40,
      '4': 1,
      '5': 9,
      '10': 'reserveStatusText'
    },
    {
      '1': 'dislike_report_data',
      '3': 41,
      '4': 1,
      '5': 9,
      '10': 'dislikeReportData'
    },
    {
      '1': 'rank_info_game',
      '3': 42,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.RankInfo',
      '10': 'rankInfoGame'
    },
    {'1': 'first_frame', '3': 43, '4': 1, '5': 9, '10': 'firstFrame'},
  ],
};

/// Descriptor for `Relate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relateDescriptor = $convert.base64Decode(
    'CgZSZWxhdGUSEAoDYWlkGAEgASgDUgNhaWQSEAoDcGljGAIgASgJUgNwaWMSFAoFdGl0bGUYAy'
    'ABKAlSBXRpdGxlEjcKBmF1dGhvchgEIAEoCzIfLmJpbGliaWxpLmFwcC5hcmNoaXZlLnYxLkF1'
    'dGhvclIGYXV0aG9yEjEKBHN0YXQYBSABKAsyHS5iaWxpYmlsaS5hcHAuYXJjaGl2ZS52MS5TdG'
    'F0UgRzdGF0EhoKCGR1cmF0aW9uGAYgASgDUghkdXJhdGlvbhISCgRnb3RvGAcgASgJUgRnb3Rv'
    'EhQKBXBhcmFtGAggASgJUgVwYXJhbRIQCgN1cmkYCSABKAlSA3VyaRIZCghqdW1wX3VybBgKIA'
    'EoCVIHanVtcFVybBIWCgZyYXRpbmcYCyABKAFSBnJhdGluZxIYCgdyZXNlcnZlGAwgASgJUgdy'
    'ZXNlcnZlEhIKBGZyb20YDSABKAlSBGZyb20SEgoEZGVzYxgOIAEoCVIEZGVzYxIfCgtyY21kX3'
    'JlYXNvbhgPIAEoCVIKcmNtZFJlYXNvbhIUCgViYWRnZRgQIAEoCVIFYmFkZ2USEAoDY2lkGBEg'
    'ASgDUgNjaWQSHwoLc2Vhc29uX3R5cGUYEiABKAVSCnNlYXNvblR5cGUSIQoMcmF0aW5nX2NvdW'
    '50GBMgASgFUgtyYXRpbmdDb3VudBIZCgh0YWdfbmFtZRgUIAEoCVIHdGFnTmFtZRI7CglwYWNr'
    'X2luZm8YFSABKAsyHi5iaWxpYmlsaS5hcHAudmlldy52MS5QYWNrSW5mb1IIcGFja0luZm8SNA'
    'oGbm90aWNlGBYgASgLMhwuYmlsaWJpbGkuYXBwLnZpZXcudjEuTm90aWNlUgZub3RpY2USNAoG'
    'YnV0dG9uGBcgASgLMhwuYmlsaWJpbGkuYXBwLnZpZXcudjEuQnV0dG9uUgZidXR0b24SGAoHdH'
    'JhY2tpZBgYIAEoCVIHdHJhY2tpZBIZCghuZXdfY2FyZBgZIAEoBVIHbmV3Q2FyZBJNChFyY21k'
    'X3JlYXNvbl9zdHlsZRgaIAEoCzIhLmJpbGliaWxpLmFwcC52aWV3LnYxLlJlYXNvblN0eWxlUg'
    '9yY21kUmVhc29uU3R5bGUSGwoJY292ZXJfZ2lmGBsgASgJUghjb3ZlckdpZhIoCgJjbRgcIAEo'
    'CzIYLmJpbGliaWxpLmFwcC52aWV3LnYxLkNNUgJjbRIlCg5yZXNlcnZlX3N0YXR1cxgdIAEoA1'
    'INcmVzZXJ2ZVN0YXR1cxIqChFyY21kX3JlYXNvbl9leHRyYRgeIAEoCVIPcmNtZFJlYXNvbkV4'
    'dHJhEksKD3JlY190aHJlZV9wb2ludBgfIAEoCzIjLmJpbGliaWxpLmFwcC52aWV3LnYxLlJlY1'
    'RocmVlUG9pbnRSDXJlY1RocmVlUG9pbnQSGwoJdW5pcXVlX2lkGCAgASgJUgh1bmlxdWVJZBIf'
    'CgttYXRlcmlhbF9pZBghIAEoA1IKbWF0ZXJpYWxJZBIoChBmcm9tX3NvdXJjZV90eXBlGCIgAS'
    'gDUg5mcm9tU291cmNlVHlwZRIkCg5mcm9tX3NvdXJjZV9pZBgjIAEoCVIMZnJvbVNvdXJjZUlk'
    'EkAKCWRpbWVuc2lvbhgkIAEoCzIiLmJpbGliaWxpLmFwcC5hcmNoaXZlLnYxLkRpbWVuc2lvbl'
    'IJZGltZW5zaW9uEhQKBWNvdmVyGCUgASgJUgVjb3ZlchJCCgtiYWRnZV9zdHlsZRgmIAEoCzIh'
    'LmJpbGliaWxpLmFwcC52aWV3LnYxLlJlYXNvblN0eWxlUgpiYWRnZVN0eWxlEk4KEHBvd2VyX2'
    'ljb25fc3R5bGUYJyABKAsyJC5iaWxpYmlsaS5hcHAudmlldy52MS5Qb3dlckljb25TdHlsZVIO'
    'cG93ZXJJY29uU3R5bGUSLgoTcmVzZXJ2ZV9zdGF0dXNfdGV4dBgoIAEoCVIRcmVzZXJ2ZVN0YX'
    'R1c1RleHQSLgoTZGlzbGlrZV9yZXBvcnRfZGF0YRgpIAEoCVIRZGlzbGlrZVJlcG9ydERhdGES'
    'RAoOcmFua19pbmZvX2dhbWUYKiABKAsyHi5iaWxpYmlsaS5hcHAudmlldy52MS5SYW5rSW5mb1'
    'IMcmFua0luZm9HYW1lEh8KC2ZpcnN0X2ZyYW1lGCsgASgJUgpmaXJzdEZyYW1l');

@$core.Deprecated('Use relateItemDescriptor instead')
const RelateItem$json = {
  '1': 'RelateItem',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'cover', '3': 2, '4': 1, '5': 9, '10': 'cover'},
  ],
};

/// Descriptor for `RelateItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relateItemDescriptor = $convert.base64Decode(
    'CgpSZWxhdGVJdGVtEhAKA3VybBgBIAEoCVIDdXJsEhQKBWNvdmVyGAIgASgJUgVjb3Zlcg==');

@$core.Deprecated('Use relatesFeedReplyDescriptor instead')
const RelatesFeedReply$json = {
  '1': 'RelatesFeedReply',
  '2': [
    {
      '1': 'list',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Relate',
      '10': 'list'
    },
    {'1': 'has_next', '3': 2, '4': 1, '5': 8, '10': 'hasNext'},
    {
      '1': 'pagination',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pagination.PaginationReply',
      '10': 'pagination'
    },
  ],
};

/// Descriptor for `RelatesFeedReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatesFeedReplyDescriptor = $convert.base64Decode(
    'ChBSZWxhdGVzRmVlZFJlcGx5EjAKBGxpc3QYASADKAsyHC5iaWxpYmlsaS5hcHAudmlldy52MS'
    '5SZWxhdGVSBGxpc3QSGQoIaGFzX25leHQYAiABKAhSB2hhc05leHQSRAoKcGFnaW5hdGlvbhgD'
    'IAEoCzIkLmJpbGliaWxpLnBhZ2luYXRpb24uUGFnaW5hdGlvblJlcGx5UgpwYWdpbmF0aW9u');

@$core.Deprecated('Use relatesFeedReqDescriptor instead')
const RelatesFeedReq$json = {
  '1': 'RelatesFeedReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'from', '3': 3, '4': 1, '5': 9, '10': 'from'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 5, '4': 1, '5': 9, '10': 'fromSpmid'},
    {
      '1': 'player_args',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.middleware.v1.PlayerArgs',
      '10': 'playerArgs'
    },
    {'1': 'relates_page', '3': 7, '4': 1, '5': 3, '10': 'relatesPage'},
    {'1': 'session_id', '3': 8, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'autoplay', '3': 9, '4': 1, '5': 5, '10': 'autoplay'},
    {'1': 'from_track_id', '3': 10, '4': 1, '5': 9, '10': 'fromTrackId'},
    {'1': 'biz_extra', '3': 11, '4': 1, '5': 9, '10': 'bizExtra'},
    {'1': 'device_type', '3': 12, '4': 1, '5': 3, '10': 'deviceType'},
    {'1': 'ad_extra', '3': 13, '4': 1, '5': 9, '10': 'adExtra'},
    {
      '1': 'pagination',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pagination.Pagination',
      '10': 'pagination'
    },
    {'1': 'refresh_num', '3': 15, '4': 1, '5': 5, '10': 'refreshNum'},
  ],
};

/// Descriptor for `RelatesFeedReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatesFeedReqDescriptor = $convert.base64Decode(
    'Cg5SZWxhdGVzRmVlZFJlcRIQCgNhaWQYASABKANSA2FpZBISCgRidmlkGAIgASgJUgRidmlkEh'
    'IKBGZyb20YAyABKAlSBGZyb20SFAoFc3BtaWQYBCABKAlSBXNwbWlkEh0KCmZyb21fc3BtaWQY'
    'BSABKAlSCWZyb21TcG1pZBJPCgtwbGF5ZXJfYXJncxgGIAEoCzIuLmJpbGliaWxpLmFwcC5hcm'
    'NoaXZlLm1pZGRsZXdhcmUudjEuUGxheWVyQXJnc1IKcGxheWVyQXJncxIhCgxyZWxhdGVzX3Bh'
    'Z2UYByABKANSC3JlbGF0ZXNQYWdlEh0KCnNlc3Npb25faWQYCCABKAlSCXNlc3Npb25JZBIaCg'
    'hhdXRvcGxheRgJIAEoBVIIYXV0b3BsYXkSIgoNZnJvbV90cmFja19pZBgKIAEoCVILZnJvbVRy'
    'YWNrSWQSGwoJYml6X2V4dHJhGAsgASgJUghiaXpFeHRyYRIfCgtkZXZpY2VfdHlwZRgMIAEoA1'
    'IKZGV2aWNlVHlwZRIZCghhZF9leHRyYRgNIAEoCVIHYWRFeHRyYRI/CgpwYWdpbmF0aW9uGA4g'
    'ASgLMh8uYmlsaWJpbGkucGFnaW5hdGlvbi5QYWdpbmF0aW9uUgpwYWdpbmF0aW9uEh8KC3JlZn'
    'Jlc2hfbnVtGA8gASgFUgpyZWZyZXNoTnVt');

@$core.Deprecated('Use relateTabDescriptor instead')
const RelateTab$json = {
  '1': 'RelateTab',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
  ],
};

/// Descriptor for `RelateTab`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relateTabDescriptor = $convert.base64Decode(
    'CglSZWxhdGVUYWISDgoCaWQYASABKAlSAmlkEhQKBXRpdGxlGAIgASgJUgV0aXRsZQ==');

@$core.Deprecated('Use replyStyleDescriptor instead')
const ReplyStyle$json = {
  '1': 'ReplyStyle',
  '2': [
    {'1': 'badge_url', '3': 1, '4': 1, '5': 9, '10': 'badgeUrl'},
    {'1': 'badge_text', '3': 2, '4': 1, '5': 9, '10': 'badgeText'},
    {'1': 'badge_type', '3': 3, '4': 1, '5': 3, '10': 'badgeType'},
  ],
};

/// Descriptor for `ReplyStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replyStyleDescriptor = $convert.base64Decode(
    'CgpSZXBseVN0eWxlEhsKCWJhZGdlX3VybBgBIAEoCVIIYmFkZ2VVcmwSHQoKYmFkZ2VfdGV4dB'
    'gCIAEoCVIJYmFkZ2VUZXh0Eh0KCmJhZGdlX3R5cGUYAyABKANSCWJhZGdlVHlwZQ==');

@$core.Deprecated('Use reqUserDescriptor instead')
const ReqUser$json = {
  '1': 'ReqUser',
  '2': [
    {'1': 'attention', '3': 1, '4': 1, '5': 5, '10': 'attention'},
    {'1': 'guest_attention', '3': 2, '4': 1, '5': 5, '10': 'guestAttention'},
    {'1': 'favorite', '3': 3, '4': 1, '5': 5, '10': 'favorite'},
    {'1': 'like', '3': 4, '4': 1, '5': 5, '10': 'like'},
    {'1': 'dislike', '3': 5, '4': 1, '5': 5, '10': 'dislike'},
    {'1': 'coin', '3': 6, '4': 1, '5': 5, '10': 'coin'},
    {'1': 'attention_level', '3': 7, '4': 1, '5': 5, '10': 'attentionLevel'},
    {'1': 'fav_season', '3': 8, '4': 1, '5': 5, '10': 'favSeason'},
    {
      '1': 'elec_plus_btn',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Button',
      '10': 'elecPlusBtn'
    },
  ],
};

/// Descriptor for `ReqUser`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reqUserDescriptor = $convert.base64Decode(
    'CgdSZXFVc2VyEhwKCWF0dGVudGlvbhgBIAEoBVIJYXR0ZW50aW9uEicKD2d1ZXN0X2F0dGVudG'
    'lvbhgCIAEoBVIOZ3Vlc3RBdHRlbnRpb24SGgoIZmF2b3JpdGUYAyABKAVSCGZhdm9yaXRlEhIK'
    'BGxpa2UYBCABKAVSBGxpa2USGAoHZGlzbGlrZRgFIAEoBVIHZGlzbGlrZRISCgRjb2luGAYgAS'
    'gFUgRjb2luEicKD2F0dGVudGlvbl9sZXZlbBgHIAEoBVIOYXR0ZW50aW9uTGV2ZWwSHQoKZmF2'
    'X3NlYXNvbhgIIAEoBVIJZmF2U2Vhc29uEkAKDWVsZWNfcGx1c19idG4YCSABKAsyHC5iaWxpYm'
    'lsaS5hcHAudmlldy52MS5CdXR0b25SC2VsZWNQbHVzQnRu');

@$core.Deprecated('Use reserveReplyDescriptor instead')
const ReserveReply$json = {
  '1': 'ReserveReply',
  '2': [
    {'1': 'reserve_id', '3': 1, '4': 1, '5': 3, '10': 'reserveId'},
  ],
};

/// Descriptor for `ReserveReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reserveReplyDescriptor = $convert.base64Decode(
    'CgxSZXNlcnZlUmVwbHkSHQoKcmVzZXJ2ZV9pZBgBIAEoA1IJcmVzZXJ2ZUlk');

@$core.Deprecated('Use reserveReqDescriptor instead')
const ReserveReq$json = {
  '1': 'ReserveReq',
  '2': [
    {'1': 'reserve_id', '3': 1, '4': 1, '5': 3, '10': 'reserveId'},
    {'1': 'reserve_action', '3': 2, '4': 1, '5': 3, '10': 'reserveAction'},
    {'1': 'up_id', '3': 3, '4': 1, '5': 3, '10': 'upId'},
  ],
};

/// Descriptor for `ReserveReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reserveReqDescriptor = $convert.base64Decode(
    'CgpSZXNlcnZlUmVxEh0KCnJlc2VydmVfaWQYASABKANSCXJlc2VydmVJZBIlCg5yZXNlcnZlX2'
    'FjdGlvbhgCIAEoA1INcmVzZXJ2ZUFjdGlvbhITCgV1cF9pZBgDIAEoA1IEdXBJZA==');

@$core.Deprecated('Use restrictionDescriptor instead')
const Restriction$json = {
  '1': 'Restriction',
  '2': [
    {'1': 'is_teenagers', '3': 1, '4': 1, '5': 8, '10': 'isTeenagers'},
    {'1': 'is_lessons', '3': 2, '4': 1, '5': 8, '10': 'isLessons'},
    {'1': 'is_review', '3': 3, '4': 1, '5': 8, '10': 'isReview'},
    {'1': 'disable_rcmd', '3': 4, '4': 1, '5': 8, '10': 'disableRcmd'},
  ],
};

/// Descriptor for `Restriction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restrictionDescriptor = $convert.base64Decode(
    'CgtSZXN0cmljdGlvbhIhCgxpc190ZWVuYWdlcnMYASABKAhSC2lzVGVlbmFnZXJzEh0KCmlzX2'
    'xlc3NvbnMYAiABKAhSCWlzTGVzc29ucxIbCglpc19yZXZpZXcYAyABKAhSCGlzUmV2aWV3EiEK'
    'DGRpc2FibGVfcmNtZBgEIAEoCFILZGlzYWJsZVJjbWQ=');

@$core.Deprecated('Use seasonDescriptor instead')
const Season$json = {
  '1': 'Season',
  '2': [
    {'1': 'allow_download', '3': 1, '4': 1, '5': 9, '10': 'allowDownload'},
    {'1': 'season_id', '3': 2, '4': 1, '5': 3, '10': 'seasonId'},
    {'1': 'is_jump', '3': 3, '4': 1, '5': 5, '10': 'isJump'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cover', '3': 5, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'is_finish', '3': 6, '4': 1, '5': 5, '10': 'isFinish'},
    {'1': 'newest_ep_id', '3': 7, '4': 1, '5': 3, '10': 'newestEpId'},
    {'1': 'newest_ep_index', '3': 8, '4': 1, '5': 9, '10': 'newestEpIndex'},
    {'1': 'total_count', '3': 9, '4': 1, '5': 3, '10': 'totalCount'},
    {'1': 'weekday', '3': 10, '4': 1, '5': 5, '10': 'weekday'},
    {
      '1': 'user_season',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UserSeason',
      '10': 'userSeason'
    },
    {
      '1': 'player',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.SeasonPlayer',
      '10': 'player'
    },
    {'1': 'ogv_playurl', '3': 13, '4': 1, '5': 9, '10': 'ogvPlayurl'},
  ],
};

/// Descriptor for `Season`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonDescriptor = $convert.base64Decode(
    'CgZTZWFzb24SJQoOYWxsb3dfZG93bmxvYWQYASABKAlSDWFsbG93RG93bmxvYWQSGwoJc2Vhc2'
    '9uX2lkGAIgASgDUghzZWFzb25JZBIXCgdpc19qdW1wGAMgASgFUgZpc0p1bXASFAoFdGl0bGUY'
    'BCABKAlSBXRpdGxlEhQKBWNvdmVyGAUgASgJUgVjb3ZlchIbCglpc19maW5pc2gYBiABKAVSCG'
    'lzRmluaXNoEiAKDG5ld2VzdF9lcF9pZBgHIAEoA1IKbmV3ZXN0RXBJZBImCg9uZXdlc3RfZXBf'
    'aW5kZXgYCCABKAlSDW5ld2VzdEVwSW5kZXgSHwoLdG90YWxfY291bnQYCSABKANSCnRvdGFsQ2'
    '91bnQSGAoHd2Vla2RheRgKIAEoBVIHd2Vla2RheRJBCgt1c2VyX3NlYXNvbhgLIAEoCzIgLmJp'
    'bGliaWxpLmFwcC52aWV3LnYxLlVzZXJTZWFzb25SCnVzZXJTZWFzb24SOgoGcGxheWVyGAwgAS'
    'gLMiIuYmlsaWJpbGkuYXBwLnZpZXcudjEuU2Vhc29uUGxheWVyUgZwbGF5ZXISHwoLb2d2X3Bs'
    'YXl1cmwYDSABKAlSCm9ndlBsYXl1cmw=');

@$core.Deprecated('Use seasonActivityRecordReplyDescriptor instead')
const SeasonActivityRecordReply$json = {
  '1': 'SeasonActivityRecordReply',
  '2': [
    {
      '1': 'activity',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UgcSeasonActivity',
      '10': 'activity'
    },
  ],
};

/// Descriptor for `SeasonActivityRecordReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonActivityRecordReplyDescriptor =
    $convert.base64Decode(
        'ChlTZWFzb25BY3Rpdml0eVJlY29yZFJlcGx5EkMKCGFjdGl2aXR5GAEgASgLMicuYmlsaWJpbG'
        'kuYXBwLnZpZXcudjEuVWdjU2Vhc29uQWN0aXZpdHlSCGFjdGl2aXR5');

@$core.Deprecated('Use seasonActivityRecordReqDescriptor instead')
const SeasonActivityRecordReq$json = {
  '1': 'SeasonActivityRecordReq',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
    {'1': 'activity_id', '3': 2, '4': 1, '5': 3, '10': 'activityId'},
    {'1': 'action', '3': 3, '4': 1, '5': 5, '10': 'action'},
    {'1': 'aid', '3': 4, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 5, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'scene', '3': 6, '4': 1, '5': 3, '10': 'scene'},
    {'1': 'spmid', '3': 7, '4': 1, '5': 9, '10': 'spmid'},
  ],
};

/// Descriptor for `SeasonActivityRecordReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonActivityRecordReqDescriptor = $convert.base64Decode(
    'ChdTZWFzb25BY3Rpdml0eVJlY29yZFJlcRIbCglzZWFzb25faWQYASABKANSCHNlYXNvbklkEh'
    '8KC2FjdGl2aXR5X2lkGAIgASgDUgphY3Rpdml0eUlkEhYKBmFjdGlvbhgDIAEoBVIGYWN0aW9u'
    'EhAKA2FpZBgEIAEoA1IDYWlkEhAKA2NpZBgFIAEoA1IDY2lkEhQKBXNjZW5lGAYgASgDUgVzY2'
    'VuZRIUCgVzcG1pZBgHIAEoCVIFc3BtaWQ=');

@$core.Deprecated('Use seasonPlayerDescriptor instead')
const SeasonPlayer$json = {
  '1': 'SeasonPlayer',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'vid', '3': 2, '4': 1, '5': 9, '10': 'vid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'from', '3': 4, '4': 1, '5': 9, '10': 'from'},
  ],
};

/// Descriptor for `SeasonPlayer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonPlayerDescriptor = $convert.base64Decode(
    'CgxTZWFzb25QbGF5ZXISEAoDYWlkGAEgASgDUgNhaWQSEAoDdmlkGAIgASgJUgN2aWQSEAoDY2'
    'lkGAMgASgDUgNjaWQSEgoEZnJvbRgEIAEoCVIEZnJvbQ==');

@$core.Deprecated('Use seasonReplyDescriptor instead')
const SeasonReply$json = {
  '1': 'SeasonReply',
  '2': [
    {
      '1': 'season',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UgcSeason',
      '10': 'season'
    },
  ],
};

/// Descriptor for `SeasonReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonReplyDescriptor = $convert.base64Decode(
    'CgtTZWFzb25SZXBseRI3CgZzZWFzb24YASABKAsyHy5iaWxpYmlsaS5hcHAudmlldy52MS5VZ2'
    'NTZWFzb25SBnNlYXNvbg==');

@$core.Deprecated('Use seasonReqDescriptor instead')
const SeasonReq$json = {
  '1': 'SeasonReq',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
  ],
};

/// Descriptor for `SeasonReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonReqDescriptor = $convert
    .base64Decode('CglTZWFzb25SZXESGwoJc2Vhc29uX2lkGAEgASgDUghzZWFzb25JZA==');

@$core.Deprecated('Use seasonShowDescriptor instead')
const SeasonShow$json = {
  '1': 'SeasonShow',
  '2': [
    {'1': 'button_text', '3': 1, '4': 1, '5': 9, '10': 'buttonText'},
    {'1': 'join_text', '3': 2, '4': 1, '5': 9, '10': 'joinText'},
    {'1': 'rule_text', '3': 3, '4': 1, '5': 9, '10': 'ruleText'},
    {'1': 'checkin_text', '3': 4, '4': 1, '5': 9, '10': 'checkinText'},
    {'1': 'checkin_prompt', '3': 5, '4': 1, '5': 9, '10': 'checkinPrompt'},
  ],
};

/// Descriptor for `SeasonShow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonShowDescriptor = $convert.base64Decode(
    'CgpTZWFzb25TaG93Eh8KC2J1dHRvbl90ZXh0GAEgASgJUgpidXR0b25UZXh0EhsKCWpvaW5fdG'
    'V4dBgCIAEoCVIIam9pblRleHQSGwoJcnVsZV90ZXh0GAMgASgJUghydWxlVGV4dBIhCgxjaGVj'
    'a2luX3RleHQYBCABKAlSC2NoZWNraW5UZXh0EiUKDmNoZWNraW5fcHJvbXB0GAUgASgJUg1jaG'
    'Vja2luUHJvbXB0');

@$core.Deprecated('Use seasonWidgetExposeReplyDescriptor instead')
const SeasonWidgetExposeReply$json = {
  '1': 'SeasonWidgetExposeReply',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
    {'1': 'activity_id', '3': 2, '4': 1, '5': 3, '10': 'activityId'},
  ],
};

/// Descriptor for `SeasonWidgetExposeReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonWidgetExposeReplyDescriptor =
    $convert.base64Decode(
        'ChdTZWFzb25XaWRnZXRFeHBvc2VSZXBseRIbCglzZWFzb25faWQYASABKANSCHNlYXNvbklkEh'
        '8KC2FjdGl2aXR5X2lkGAIgASgDUgphY3Rpdml0eUlk');

@$core.Deprecated('Use seasonWidgetExposeReqDescriptor instead')
const SeasonWidgetExposeReq$json = {
  '1': 'SeasonWidgetExposeReq',
  '2': [
    {'1': 'mid', '3': 1, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'type', '3': 2, '4': 1, '5': 5, '10': 'type'},
    {'1': 'season_id', '3': 3, '4': 1, '5': 3, '10': 'seasonId'},
    {'1': 'activity_id', '3': 4, '4': 1, '5': 3, '10': 'activityId'},
    {'1': 'aid', '3': 5, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 6, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'scene', '3': 7, '4': 1, '5': 3, '10': 'scene'},
  ],
};

/// Descriptor for `SeasonWidgetExposeReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonWidgetExposeReqDescriptor = $convert.base64Decode(
    'ChVTZWFzb25XaWRnZXRFeHBvc2VSZXESEAoDbWlkGAEgASgDUgNtaWQSEgoEdHlwZRgCIAEoBV'
    'IEdHlwZRIbCglzZWFzb25faWQYAyABKANSCHNlYXNvbklkEh8KC2FjdGl2aXR5X2lkGAQgASgD'
    'UgphY3Rpdml0eUlkEhAKA2FpZBgFIAEoA1IDYWlkEhAKA2NpZBgGIAEoA1IDY2lkEhQKBXNjZW'
    '5lGAcgASgDUgVzY2VuZQ==');

@$core.Deprecated('Use sectionDescriptor instead')
const Section$json = {
  '1': 'Section',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'type', '3': 3, '4': 1, '5': 3, '10': 'type'},
    {
      '1': 'episodes',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Episode',
      '10': 'episodes'
    },
  ],
};

/// Descriptor for `Section`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sectionDescriptor = $convert.base64Decode(
    'CgdTZWN0aW9uEg4KAmlkGAEgASgDUgJpZBIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSEgoEdHlwZR'
    'gDIAEoA1IEdHlwZRI5CghlcGlzb2RlcxgEIAMoCzIdLmJpbGliaWxpLmFwcC52aWV3LnYxLkVw'
    'aXNvZGVSCGVwaXNvZGVz');

@$core.Deprecated('Use shortFormVideoDownloadReplyDescriptor instead')
const ShortFormVideoDownloadReply$json = {
  '1': 'ShortFormVideoDownloadReply',
  '2': [
    {'1': 'has_download_url', '3': 1, '4': 1, '5': 8, '10': 'hasDownloadUrl'},
    {'1': 'download_url', '3': 2, '4': 1, '5': 9, '10': 'downloadUrl'},
    {'1': 'md5', '3': 3, '4': 1, '5': 9, '10': 'md5'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
    {
      '1': 'backup_download_url',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'backupDownloadUrl'
    },
  ],
};

/// Descriptor for `ShortFormVideoDownloadReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shortFormVideoDownloadReplyDescriptor = $convert.base64Decode(
    'ChtTaG9ydEZvcm1WaWRlb0Rvd25sb2FkUmVwbHkSKAoQaGFzX2Rvd25sb2FkX3VybBgBIAEoCF'
    'IOaGFzRG93bmxvYWRVcmwSIQoMZG93bmxvYWRfdXJsGAIgASgJUgtkb3dubG9hZFVybBIQCgNt'
    'ZDUYAyABKAlSA21kNRISCgRzaXplGAQgASgDUgRzaXplEi4KE2JhY2t1cF9kb3dubG9hZF91cm'
    'wYBSABKAlSEWJhY2t1cERvd25sb2FkVXJs');

@$core.Deprecated('Use shortFormVideoDownloadReqDescriptor instead')
const ShortFormVideoDownloadReq$json = {
  '1': 'ShortFormVideoDownloadReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'mid', '3': 3, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'buvid', '3': 4, '4': 1, '5': 9, '10': 'buvid'},
    {'1': 'mobi_app', '3': 5, '4': 1, '5': 9, '10': 'mobiApp'},
    {'1': 'build', '3': 6, '4': 1, '5': 3, '10': 'build'},
    {'1': 'device', '3': 7, '4': 1, '5': 9, '10': 'device'},
    {'1': 'platform', '3': 8, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'spmid', '3': 9, '4': 1, '5': 9, '10': 'spmid'},
    {
      '1': 'restriction',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Restriction',
      '10': 'restriction'
    },
    {'1': 'tf_isp', '3': 11, '4': 1, '5': 9, '10': 'tfIsp'},
  ],
};

/// Descriptor for `ShortFormVideoDownloadReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shortFormVideoDownloadReqDescriptor = $convert.base64Decode(
    'ChlTaG9ydEZvcm1WaWRlb0Rvd25sb2FkUmVxEhAKA2FpZBgBIAEoA1IDYWlkEhAKA2NpZBgCIA'
    'EoA1IDY2lkEhAKA21pZBgDIAEoA1IDbWlkEhQKBWJ1dmlkGAQgASgJUgVidXZpZBIZCghtb2Jp'
    'X2FwcBgFIAEoCVIHbW9iaUFwcBIUCgVidWlsZBgGIAEoA1IFYnVpbGQSFgoGZGV2aWNlGAcgAS'
    'gJUgZkZXZpY2USGgoIcGxhdGZvcm0YCCABKAlSCHBsYXRmb3JtEhQKBXNwbWlkGAkgASgJUgVz'
    'cG1pZBJDCgtyZXN0cmljdGlvbhgKIAEoCzIhLmJpbGliaWxpLmFwcC52aWV3LnYxLlJlc3RyaW'
    'N0aW9uUgtyZXN0cmljdGlvbhIVCgZ0Zl9pc3AYCyABKAlSBXRmSXNw');

@$core.Deprecated('Use specialCellDescriptor instead')
const SpecialCell$json = {
  '1': 'SpecialCell',
  '2': [
    {'1': 'icon', '3': 1, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'icon_night', '3': 2, '4': 1, '5': 9, '10': 'iconNight'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 4, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_color_night', '3': 5, '4': 1, '5': 9, '10': 'textColorNight'},
    {'1': 'jump_url', '3': 6, '4': 1, '5': 9, '10': 'jumpUrl'},
    {'1': 'cell_type', '3': 7, '4': 1, '5': 9, '10': 'cellType'},
    {'1': 'cell_bgcolor', '3': 8, '4': 1, '5': 9, '10': 'cellBgcolor'},
    {
      '1': 'cell_bgcolor_night',
      '3': 9,
      '4': 1,
      '5': 9,
      '10': 'cellBgcolorNight'
    },
    {'1': 'param', '3': 10, '4': 1, '5': 9, '10': 'param'},
    {'1': 'page_title', '3': 11, '4': 1, '5': 9, '10': 'pageTitle'},
    {'1': 'jump_type', '3': 12, '4': 1, '5': 9, '10': 'jumpType'},
    {'1': 'end_icon', '3': 13, '4': 1, '5': 9, '10': 'endIcon'},
    {'1': 'end_icon_night', '3': 14, '4': 1, '5': 9, '10': 'endIconNight'},
    {'1': 'notes_count', '3': 15, '4': 1, '5': 3, '10': 'notesCount'},
  ],
};

/// Descriptor for `SpecialCell`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List specialCellDescriptor = $convert.base64Decode(
    'CgtTcGVjaWFsQ2VsbBISCgRpY29uGAEgASgJUgRpY29uEh0KCmljb25fbmlnaHQYAiABKAlSCW'
    'ljb25OaWdodBISCgR0ZXh0GAMgASgJUgR0ZXh0Eh0KCnRleHRfY29sb3IYBCABKAlSCXRleHRD'
    'b2xvchIoChB0ZXh0X2NvbG9yX25pZ2h0GAUgASgJUg50ZXh0Q29sb3JOaWdodBIZCghqdW1wX3'
    'VybBgGIAEoCVIHanVtcFVybBIbCgljZWxsX3R5cGUYByABKAlSCGNlbGxUeXBlEiEKDGNlbGxf'
    'Ymdjb2xvchgIIAEoCVILY2VsbEJnY29sb3ISLAoSY2VsbF9iZ2NvbG9yX25pZ2h0GAkgASgJUh'
    'BjZWxsQmdjb2xvck5pZ2h0EhQKBXBhcmFtGAogASgJUgVwYXJhbRIdCgpwYWdlX3RpdGxlGAsg'
    'ASgJUglwYWdlVGl0bGUSGwoJanVtcF90eXBlGAwgASgJUghqdW1wVHlwZRIZCghlbmRfaWNvbh'
    'gNIAEoCVIHZW5kSWNvbhIkCg5lbmRfaWNvbl9uaWdodBgOIAEoCVIMZW5kSWNvbk5pZ2h0Eh8K'
    'C25vdGVzX2NvdW50GA8gASgDUgpub3Rlc0NvdW50');

@$core.Deprecated('Use staffDescriptor instead')
const Staff$json = {
  '1': 'Staff',
  '2': [
    {'1': 'mid', '3': 1, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'face', '3': 3, '4': 1, '5': 9, '10': 'face'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'official_verify',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OfficialVerify',
      '10': 'officialVerify'
    },
    {
      '1': 'vip',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Vip',
      '10': 'vip'
    },
    {'1': 'attention', '3': 7, '4': 1, '5': 5, '10': 'attention'},
    {'1': 'label_style', '3': 8, '4': 1, '5': 5, '10': 'labelStyle'},
  ],
};

/// Descriptor for `Staff`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List staffDescriptor = $convert.base64Decode(
    'CgVTdGFmZhIQCgNtaWQYASABKANSA21pZBIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSEgoEZmFjZR'
    'gDIAEoCVIEZmFjZRISCgRuYW1lGAQgASgJUgRuYW1lEk0KD29mZmljaWFsX3ZlcmlmeRgFIAEo'
    'CzIkLmJpbGliaWxpLmFwcC52aWV3LnYxLk9mZmljaWFsVmVyaWZ5Ug5vZmZpY2lhbFZlcmlmeR'
    'IrCgN2aXAYBiABKAsyGS5iaWxpYmlsaS5hcHAudmlldy52MS5WaXBSA3ZpcBIcCglhdHRlbnRp'
    'b24YByABKAVSCWF0dGVudGlvbhIfCgtsYWJlbF9zdHlsZRgIIAEoBVIKbGFiZWxTdHlsZQ==');

@$core.Deprecated('Use standardCardDescriptor instead')
const StandardCard$json = {
  '1': 'StandardCard',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'button_title', '3': 2, '4': 1, '5': 9, '10': 'buttonTitle'},
    {
      '1': 'button_selected_title',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'buttonSelectedTitle'
    },
    {'1': 'show_selected', '3': 4, '4': 1, '5': 8, '10': 'showSelected'},
  ],
};

/// Descriptor for `StandardCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List standardCardDescriptor = $convert.base64Decode(
    'CgxTdGFuZGFyZENhcmQSFAoFdGl0bGUYASABKAlSBXRpdGxlEiEKDGJ1dHRvbl90aXRsZRgCIA'
    'EoCVILYnV0dG9uVGl0bGUSMgoVYnV0dG9uX3NlbGVjdGVkX3RpdGxlGAMgASgJUhNidXR0b25T'
    'ZWxlY3RlZFRpdGxlEiMKDXNob3dfc2VsZWN0ZWQYBCABKAhSDHNob3dTZWxlY3RlZA==');

@$core.Deprecated('Use subTFPanelDescriptor instead')
const subTFPanel$json = {
  '1': 'subTFPanel',
  '2': [
    {'1': 'right_btn_img', '3': 1, '4': 1, '5': 9, '10': 'rightBtnImg'},
    {'1': 'right_btn_text', '3': 2, '4': 1, '5': 9, '10': 'rightBtnText'},
    {
      '1': 'right_btn_text_color',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'rightBtnTextColor'
    },
    {'1': 'right_btn_link', '3': 4, '4': 1, '5': 9, '10': 'rightBtnLink'},
    {'1': 'main_label', '3': 5, '4': 1, '5': 9, '10': 'mainLabel'},
    {'1': 'operator', '3': 6, '4': 1, '5': 9, '10': 'operator'},
  ],
};

/// Descriptor for `subTFPanel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subTFPanelDescriptor = $convert.base64Decode(
    'CgpzdWJURlBhbmVsEiIKDXJpZ2h0X2J0bl9pbWcYASABKAlSC3JpZ2h0QnRuSW1nEiQKDnJpZ2'
    'h0X2J0bl90ZXh0GAIgASgJUgxyaWdodEJ0blRleHQSLwoUcmlnaHRfYnRuX3RleHRfY29sb3IY'
    'AyABKAlSEXJpZ2h0QnRuVGV4dENvbG9yEiQKDnJpZ2h0X2J0bl9saW5rGAQgASgJUgxyaWdodE'
    'J0bkxpbmsSHQoKbWFpbl9sYWJlbBgFIAEoCVIJbWFpbkxhYmVsEhoKCG9wZXJhdG9yGAYgASgJ'
    'UghvcGVyYXRvcg==');

@$core.Deprecated('Use tabDescriptor instead')
const Tab$json = {
  '1': 'Tab',
  '2': [
    {'1': 'background', '3': 1, '4': 1, '5': 9, '10': 'background'},
    {
      '1': 'otype',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.TabOtype',
      '10': 'otype'
    },
    {'1': 'oid', '3': 3, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'uri', '3': 4, '4': 1, '5': 9, '10': 'uri'},
    {
      '1': 'style',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.TabStyle',
      '10': 'style'
    },
    {'1': 'text', '3': 6, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 7, '4': 1, '5': 9, '10': 'textColor'},
    {
      '1': 'text_color_selected',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'textColorSelected'
    },
    {'1': 'pic', '3': 9, '4': 1, '5': 9, '10': 'pic'},
    {'1': 'id', '3': 10, '4': 1, '5': 3, '10': 'id'},
    {
      '1': 'ad_tab_info',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'adTabInfo'
    },
  ],
};

/// Descriptor for `Tab`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tabDescriptor = $convert.base64Decode(
    'CgNUYWISHgoKYmFja2dyb3VuZBgBIAEoCVIKYmFja2dyb3VuZBI0CgVvdHlwZRgCIAEoDjIeLm'
    'JpbGliaWxpLmFwcC52aWV3LnYxLlRhYk90eXBlUgVvdHlwZRIQCgNvaWQYAyABKANSA29pZBIQ'
    'CgN1cmkYBCABKAlSA3VyaRI0CgVzdHlsZRgFIAEoDjIeLmJpbGliaWxpLmFwcC52aWV3LnYxLl'
    'RhYlN0eWxlUgVzdHlsZRISCgR0ZXh0GAYgASgJUgR0ZXh0Eh0KCnRleHRfY29sb3IYByABKAlS'
    'CXRleHRDb2xvchIuChN0ZXh0X2NvbG9yX3NlbGVjdGVkGAggASgJUhF0ZXh0Q29sb3JTZWxlY3'
    'RlZBIQCgNwaWMYCSABKAlSA3BpYxIOCgJpZBgKIAEoA1ICaWQSNAoLYWRfdGFiX2luZm8YCyAB'
    'KAsyFC5nb29nbGUucHJvdG9idWYuQW55UglhZFRhYkluZm8=');

@$core.Deprecated('Use tagDescriptor instead')
const Tag$json = {
  '1': 'Tag',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'likes', '3': 3, '4': 1, '5': 3, '10': 'likes'},
    {'1': 'hates', '3': 4, '4': 1, '5': 3, '10': 'hates'},
    {'1': 'liked', '3': 5, '4': 1, '5': 5, '10': 'liked'},
    {'1': 'hated', '3': 6, '4': 1, '5': 5, '10': 'hated'},
    {'1': 'uri', '3': 7, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'tag_type', '3': 8, '4': 1, '5': 9, '10': 'tagType'},
  ],
};

/// Descriptor for `Tag`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tagDescriptor = $convert.base64Decode(
    'CgNUYWcSDgoCaWQYASABKANSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFAoFbGlrZXMYAyABKA'
    'NSBWxpa2VzEhQKBWhhdGVzGAQgASgDUgVoYXRlcxIUCgVsaWtlZBgFIAEoBVIFbGlrZWQSFAoF'
    'aGF0ZWQYBiABKAVSBWhhdGVkEhAKA3VyaRgHIAEoCVIDdXJpEhkKCHRhZ190eXBlGAggASgJUg'
    'd0YWdUeXBl');

@$core.Deprecated('Use tFPanelCustomizedDescriptor instead')
const TFPanelCustomized$json = {
  '1': 'TFPanelCustomized',
  '2': [
    {'1': 'right_btn_img', '3': 1, '4': 1, '5': 9, '10': 'rightBtnImg'},
    {'1': 'right_btn_text', '3': 2, '4': 1, '5': 9, '10': 'rightBtnText'},
    {
      '1': 'right_btn_text_color',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'rightBtnTextColor'
    },
    {'1': 'right_btn_link', '3': 4, '4': 1, '5': 9, '10': 'rightBtnLink'},
    {'1': 'main_label', '3': 5, '4': 1, '5': 9, '10': 'mainLabel'},
    {'1': 'operator', '3': 6, '4': 1, '5': 9, '10': 'operator'},
    {
      '1': 'sub_panel',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.TFPanelCustomized.SubPanelEntry',
      '10': 'subPanel'
    },
  ],
  '3': [TFPanelCustomized_SubPanelEntry$json],
};

@$core.Deprecated('Use tFPanelCustomizedDescriptor instead')
const TFPanelCustomized_SubPanelEntry$json = {
  '1': 'SubPanelEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.subTFPanel',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `TFPanelCustomized`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tFPanelCustomizedDescriptor = $convert.base64Decode(
    'ChFURlBhbmVsQ3VzdG9taXplZBIiCg1yaWdodF9idG5faW1nGAEgASgJUgtyaWdodEJ0bkltZx'
    'IkCg5yaWdodF9idG5fdGV4dBgCIAEoCVIMcmlnaHRCdG5UZXh0Ei8KFHJpZ2h0X2J0bl90ZXh0'
    'X2NvbG9yGAMgASgJUhFyaWdodEJ0blRleHRDb2xvchIkCg5yaWdodF9idG5fbGluaxgEIAEoCV'
    'IMcmlnaHRCdG5MaW5rEh0KCm1haW5fbGFiZWwYBSABKAlSCW1haW5MYWJlbBIaCghvcGVyYXRv'
    'chgGIAEoCVIIb3BlcmF0b3ISUgoJc3ViX3BhbmVsGAcgAygLMjUuYmlsaWJpbGkuYXBwLnZpZX'
    'cudjEuVEZQYW5lbEN1c3RvbWl6ZWQuU3ViUGFuZWxFbnRyeVIIc3ViUGFuZWwaXQoNU3ViUGFu'
    'ZWxFbnRyeRIQCgNrZXkYASABKAlSA2tleRI2CgV2YWx1ZRgCIAEoCzIgLmJpbGliaWxpLmFwcC'
    '52aWV3LnYxLnN1YlRGUGFuZWxSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use tIconDescriptor instead')
const TIcon$json = {
  '1': 'TIcon',
  '2': [
    {'1': 'icon', '3': 1, '4': 1, '5': 9, '10': 'icon'},
  ],
};

/// Descriptor for `TIcon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tIconDescriptor =
    $convert.base64Decode('CgVUSWNvbhISCgRpY29uGAEgASgJUgRpY29u');

@$core.Deprecated('Use ugcSeasonDescriptor instead')
const UgcSeason$json = {
  '1': 'UgcSeason',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cover', '3': 3, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'intro', '3': 4, '4': 1, '5': 9, '10': 'intro'},
    {
      '1': 'sections',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Section',
      '10': 'sections'
    },
    {
      '1': 'stat',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UgcSeasonStat',
      '10': 'stat'
    },
    {'1': 'label_text', '3': 7, '4': 1, '5': 9, '10': 'labelText'},
    {'1': 'label_text_color', '3': 8, '4': 1, '5': 9, '10': 'labelTextColor'},
    {'1': 'label_bg_color', '3': 9, '4': 1, '5': 9, '10': 'labelBgColor'},
    {
      '1': 'label_text_night_color',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'labelTextNightColor'
    },
    {
      '1': 'label_bg_night_color',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'labelBgNightColor'
    },
    {'1': 'descRight', '3': 12, '4': 1, '5': 9, '10': 'descRight'},
    {'1': 'ep_count', '3': 13, '4': 1, '5': 3, '10': 'epCount'},
    {
      '1': 'season_type',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.SeasonType',
      '10': 'seasonType'
    },
    {
      '1': 'show_continual_button',
      '3': 15,
      '4': 1,
      '5': 8,
      '10': 'showContinualButton'
    },
    {'1': 'ep_num', '3': 16, '4': 1, '5': 3, '10': 'epNum'},
    {'1': 'season_pay', '3': 17, '4': 1, '5': 8, '10': 'seasonPay'},
    {
      '1': 'goods_info',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.GoodsInfo',
      '10': 'goodsInfo'
    },
    {
      '1': 'pay_button',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ButtonStyle',
      '10': 'payButton'
    },
    {'1': 'label_text_new', '3': 20, '4': 1, '5': 9, '10': 'labelTextNew'},
    {
      '1': 'activity',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UgcSeasonActivity',
      '10': 'activity'
    },
    {'1': 'season_ability', '3': 22, '4': 3, '5': 9, '10': 'seasonAbility'},
  ],
};

/// Descriptor for `UgcSeason`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ugcSeasonDescriptor = $convert.base64Decode(
    'CglVZ2NTZWFzb24SDgoCaWQYASABKANSAmlkEhQKBXRpdGxlGAIgASgJUgV0aXRsZRIUCgVjb3'
    'ZlchgDIAEoCVIFY292ZXISFAoFaW50cm8YBCABKAlSBWludHJvEjkKCHNlY3Rpb25zGAUgAygL'
    'Mh0uYmlsaWJpbGkuYXBwLnZpZXcudjEuU2VjdGlvblIIc2VjdGlvbnMSNwoEc3RhdBgGIAEoCz'
    'IjLmJpbGliaWxpLmFwcC52aWV3LnYxLlVnY1NlYXNvblN0YXRSBHN0YXQSHQoKbGFiZWxfdGV4'
    'dBgHIAEoCVIJbGFiZWxUZXh0EigKEGxhYmVsX3RleHRfY29sb3IYCCABKAlSDmxhYmVsVGV4dE'
    'NvbG9yEiQKDmxhYmVsX2JnX2NvbG9yGAkgASgJUgxsYWJlbEJnQ29sb3ISMwoWbGFiZWxfdGV4'
    'dF9uaWdodF9jb2xvchgKIAEoCVITbGFiZWxUZXh0TmlnaHRDb2xvchIvChRsYWJlbF9iZ19uaW'
    'dodF9jb2xvchgLIAEoCVIRbGFiZWxCZ05pZ2h0Q29sb3ISHAoJZGVzY1JpZ2h0GAwgASgJUglk'
    'ZXNjUmlnaHQSGQoIZXBfY291bnQYDSABKANSB2VwQ291bnQSQQoLc2Vhc29uX3R5cGUYDiABKA'
    '4yIC5iaWxpYmlsaS5hcHAudmlldy52MS5TZWFzb25UeXBlUgpzZWFzb25UeXBlEjIKFXNob3df'
    'Y29udGludWFsX2J1dHRvbhgPIAEoCFITc2hvd0NvbnRpbnVhbEJ1dHRvbhIVCgZlcF9udW0YEC'
    'ABKANSBWVwTnVtEh0KCnNlYXNvbl9wYXkYESABKAhSCXNlYXNvblBheRI+Cgpnb29kc19pbmZv'
    'GBIgASgLMh8uYmlsaWJpbGkuYXBwLnZpZXcudjEuR29vZHNJbmZvUglnb29kc0luZm8SQAoKcG'
    'F5X2J1dHRvbhgTIAEoCzIhLmJpbGliaWxpLmFwcC52aWV3LnYxLkJ1dHRvblN0eWxlUglwYXlC'
    'dXR0b24SJAoObGFiZWxfdGV4dF9uZXcYFCABKAlSDGxhYmVsVGV4dE5ldxJDCghhY3Rpdml0eR'
    'gVIAEoCzInLmJpbGliaWxpLmFwcC52aWV3LnYxLlVnY1NlYXNvbkFjdGl2aXR5UghhY3Rpdml0'
    'eRIlCg5zZWFzb25fYWJpbGl0eRgWIAMoCVINc2Vhc29uQWJpbGl0eQ==');

@$core.Deprecated('Use ugcSeasonActivityDescriptor instead')
const UgcSeasonActivity$json = {
  '1': 'UgcSeasonActivity',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'activity_id', '3': 3, '4': 1, '5': 3, '10': 'activityId'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'intro', '3': 5, '4': 1, '5': 9, '10': 'intro'},
    {'1': 'day_count', '3': 6, '4': 1, '5': 5, '10': 'dayCount'},
    {'1': 'user_count', '3': 7, '4': 1, '5': 5, '10': 'userCount'},
    {'1': 'join_deadline', '3': 8, '4': 1, '5': 3, '10': 'joinDeadline'},
    {
      '1': 'activity_deadline',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'activityDeadline'
    },
    {
      '1': 'checkin_view_time',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'checkinViewTime'
    },
    {'1': 'new_activity', '3': 11, '4': 1, '5': 8, '10': 'newActivity'},
    {
      '1': 'user_activity',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UserActivity',
      '10': 'userActivity'
    },
    {
      '1': 'season_show',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.SeasonShow',
      '10': 'seasonShow'
    },
  ],
};

/// Descriptor for `UgcSeasonActivity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ugcSeasonActivityDescriptor = $convert.base64Decode(
    'ChFVZ2NTZWFzb25BY3Rpdml0eRISCgR0eXBlGAEgASgFUgR0eXBlEhAKA29pZBgCIAEoA1IDb2'
    'lkEh8KC2FjdGl2aXR5X2lkGAMgASgDUgphY3Rpdml0eUlkEhQKBXRpdGxlGAQgASgJUgV0aXRs'
    'ZRIUCgVpbnRybxgFIAEoCVIFaW50cm8SGwoJZGF5X2NvdW50GAYgASgFUghkYXlDb3VudBIdCg'
    'p1c2VyX2NvdW50GAcgASgFUgl1c2VyQ291bnQSIwoNam9pbl9kZWFkbGluZRgIIAEoA1IMam9p'
    'bkRlYWRsaW5lEisKEWFjdGl2aXR5X2RlYWRsaW5lGAkgASgDUhBhY3Rpdml0eURlYWRsaW5lEi'
    'oKEWNoZWNraW5fdmlld190aW1lGAogASgFUg9jaGVja2luVmlld1RpbWUSIQoMbmV3X2FjdGl2'
    'aXR5GAsgASgIUgtuZXdBY3Rpdml0eRJHCg11c2VyX2FjdGl2aXR5GAwgASgLMiIuYmlsaWJpbG'
    'kuYXBwLnZpZXcudjEuVXNlckFjdGl2aXR5Ugx1c2VyQWN0aXZpdHkSQQoLc2Vhc29uX3Nob3cY'
    'DSABKAsyIC5iaWxpYmlsaS5hcHAudmlldy52MS5TZWFzb25TaG93UgpzZWFzb25TaG93');

@$core.Deprecated('Use ugcSeasonStatDescriptor instead')
const UgcSeasonStat$json = {
  '1': 'UgcSeasonStat',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
    {'1': 'view', '3': 2, '4': 1, '5': 5, '10': 'view'},
    {'1': 'danmaku', '3': 3, '4': 1, '5': 5, '10': 'danmaku'},
    {'1': 'reply', '3': 4, '4': 1, '5': 5, '10': 'reply'},
    {'1': 'fav', '3': 5, '4': 1, '5': 5, '10': 'fav'},
    {'1': 'coin', '3': 6, '4': 1, '5': 5, '10': 'coin'},
    {'1': 'share', '3': 7, '4': 1, '5': 5, '10': 'share'},
    {'1': 'now_rank', '3': 8, '4': 1, '5': 5, '10': 'nowRank'},
    {'1': 'his_rank', '3': 9, '4': 1, '5': 5, '10': 'hisRank'},
    {'1': 'like', '3': 10, '4': 1, '5': 5, '10': 'like'},
  ],
};

/// Descriptor for `UgcSeasonStat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ugcSeasonStatDescriptor = $convert.base64Decode(
    'Cg1VZ2NTZWFzb25TdGF0EhsKCXNlYXNvbl9pZBgBIAEoA1IIc2Vhc29uSWQSEgoEdmlldxgCIA'
    'EoBVIEdmlldxIYCgdkYW5tYWt1GAMgASgFUgdkYW5tYWt1EhQKBXJlcGx5GAQgASgFUgVyZXBs'
    'eRIQCgNmYXYYBSABKAVSA2ZhdhISCgRjb2luGAYgASgFUgRjb2luEhQKBXNoYXJlGAcgASgFUg'
    'VzaGFyZRIZCghub3dfcmFuaxgIIAEoBVIHbm93UmFuaxIZCghoaXNfcmFuaxgJIAEoBVIHaGlz'
    'UmFuaxISCgRsaWtlGAogASgFUgRsaWtl');

@$core.Deprecated('Use upActDescriptor instead')
const UpAct$json = {
  '1': 'UpAct',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 3, '10': 'sid'},
    {'1': 'mid', '3': 2, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'statement', '3': 4, '4': 1, '5': 9, '10': 'statement'},
    {'1': 'image', '3': 5, '4': 1, '5': 9, '10': 'image'},
    {'1': 'url', '3': 6, '4': 1, '5': 9, '10': 'url'},
    {'1': 'button', '3': 7, '4': 1, '5': 9, '10': 'button'},
  ],
};

/// Descriptor for `UpAct`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upActDescriptor = $convert.base64Decode(
    'CgVVcEFjdBIQCgNzaWQYASABKANSA3NpZBIQCgNtaWQYAiABKANSA21pZBIUCgV0aXRsZRgDIA'
    'EoCVIFdGl0bGUSHAoJc3RhdGVtZW50GAQgASgJUglzdGF0ZW1lbnQSFAoFaW1hZ2UYBSABKAlS'
    'BWltYWdlEhAKA3VybBgGIAEoCVIDdXJsEhYKBmJ1dHRvbhgHIAEoCVIGYnV0dG9u');

@$core.Deprecated('Use upLikeImgDescriptor instead')
const UpLikeImg$json = {
  '1': 'UpLikeImg',
  '2': [
    {'1': 'pre_img', '3': 1, '4': 1, '5': 9, '10': 'preImg'},
    {'1': 'suc_img', '3': 2, '4': 1, '5': 9, '10': 'sucImg'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'type', '3': 4, '4': 1, '5': 3, '10': 'type'},
  ],
};

/// Descriptor for `UpLikeImg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upLikeImgDescriptor = $convert.base64Decode(
    'CglVcExpa2VJbWcSFwoHcHJlX2ltZxgBIAEoCVIGcHJlSW1nEhcKB3N1Y19pbWcYAiABKAlSBn'
    'N1Y0ltZxIYCgdjb250ZW50GAMgASgJUgdjb250ZW50EhIKBHR5cGUYBCABKANSBHR5cGU=');

@$core.Deprecated('Use upperInfosDescriptor instead')
const UpperInfos$json = {
  '1': 'UpperInfos',
  '2': [
    {'1': 'fans_count', '3': 1, '4': 1, '5': 3, '10': 'fansCount'},
    {
      '1': 'arc_count_last_half_year',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'arcCountLastHalfYear'
    },
    {'1': 'first_up_dates', '3': 3, '4': 1, '5': 3, '10': 'firstUpDates'},
    {'1': 'total_play_count', '3': 4, '4': 1, '5': 3, '10': 'totalPlayCount'},
  ],
};

/// Descriptor for `UpperInfos`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upperInfosDescriptor = $convert.base64Decode(
    'CgpVcHBlckluZm9zEh0KCmZhbnNfY291bnQYASABKANSCWZhbnNDb3VudBI2ChhhcmNfY291bn'
    'RfbGFzdF9oYWxmX3llYXIYAiABKANSFGFyY0NvdW50TGFzdEhhbGZZZWFyEiQKDmZpcnN0X3Vw'
    'X2RhdGVzGAMgASgDUgxmaXJzdFVwRGF0ZXMSKAoQdG90YWxfcGxheV9jb3VudBgEIAEoA1IOdG'
    '90YWxQbGF5Q291bnQ=');

@$core.Deprecated('Use userActivityDescriptor instead')
const UserActivity$json = {
  '1': 'UserActivity',
  '2': [
    {'1': 'user_state', '3': 1, '4': 1, '5': 5, '10': 'userState'},
    {'1': 'last_checkin_date', '3': 2, '4': 1, '5': 3, '10': 'lastCheckinDate'},
    {'1': 'checkin_today', '3': 3, '4': 1, '5': 5, '10': 'checkinToday'},
    {'1': 'user_day_count', '3': 4, '4': 1, '5': 5, '10': 'userDayCount'},
    {'1': 'user_view_time', '3': 5, '4': 1, '5': 5, '10': 'userViewTime'},
    {'1': 'portrait', '3': 6, '4': 1, '5': 9, '10': 'portrait'},
  ],
};

/// Descriptor for `UserActivity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userActivityDescriptor = $convert.base64Decode(
    'CgxVc2VyQWN0aXZpdHkSHQoKdXNlcl9zdGF0ZRgBIAEoBVIJdXNlclN0YXRlEioKEWxhc3RfY2'
    'hlY2tpbl9kYXRlGAIgASgDUg9sYXN0Q2hlY2tpbkRhdGUSIwoNY2hlY2tpbl90b2RheRgDIAEo'
    'BVIMY2hlY2tpblRvZGF5EiQKDnVzZXJfZGF5X2NvdW50GAQgASgFUgx1c2VyRGF5Q291bnQSJA'
    'oOdXNlcl92aWV3X3RpbWUYBSABKAVSDHVzZXJWaWV3VGltZRIaCghwb3J0cmFpdBgGIAEoCVII'
    'cG9ydHJhaXQ=');

@$core.Deprecated('Use userGarbDescriptor instead')
const UserGarb$json = {
  '1': 'UserGarb',
  '2': [
    {'1': 'url_image_ani_cut', '3': 1, '4': 1, '5': 9, '10': 'urlImageAniCut'},
    {'1': 'like_toast', '3': 2, '4': 1, '5': 9, '10': 'likeToast'},
  ],
};

/// Descriptor for `UserGarb`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userGarbDescriptor = $convert.base64Decode(
    'CghVc2VyR2FyYhIpChF1cmxfaW1hZ2VfYW5pX2N1dBgBIAEoCVIOdXJsSW1hZ2VBbmlDdXQSHQ'
    'oKbGlrZV90b2FzdBgCIAEoCVIJbGlrZVRvYXN0');

@$core.Deprecated('Use userSeasonDescriptor instead')
const UserSeason$json = {
  '1': 'UserSeason',
  '2': [
    {'1': 'attention', '3': 1, '4': 1, '5': 9, '10': 'attention'},
  ],
};

/// Descriptor for `UserSeason`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userSeasonDescriptor = $convert
    .base64Decode('CgpVc2VyU2Vhc29uEhwKCWF0dGVudGlvbhgBIAEoCVIJYXR0ZW50aW9u');

@$core.Deprecated('Use videoGuideDescriptor instead')
const VideoGuide$json = {
  '1': 'VideoGuide',
  '2': [
    {
      '1': 'attention',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Attention',
      '10': 'attention'
    },
    {
      '1': 'commandDms',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.CommandDm',
      '10': 'commandDms'
    },
    {
      '1': 'operation_card',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.OperationCard',
      '10': 'operationCard'
    },
    {
      '1': 'operation_card_new',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.OperationCardNew',
      '10': 'operationCardNew'
    },
    {
      '1': 'contract_card',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ContractCard',
      '10': 'contractCard'
    },
    {
      '1': 'cards_second',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.OperationCardV2',
      '10': 'cardsSecond'
    },
  ],
};

/// Descriptor for `VideoGuide`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoGuideDescriptor = $convert.base64Decode(
    'CgpWaWRlb0d1aWRlEj0KCWF0dGVudGlvbhgBIAMoCzIfLmJpbGliaWxpLmFwcC52aWV3LnYxLk'
    'F0dGVudGlvblIJYXR0ZW50aW9uEj8KCmNvbW1hbmREbXMYAiADKAsyHy5iaWxpYmlsaS5hcHAu'
    'dmlldy52MS5Db21tYW5kRG1SCmNvbW1hbmREbXMSSgoOb3BlcmF0aW9uX2NhcmQYAyADKAsyIy'
    '5iaWxpYmlsaS5hcHAudmlldy52MS5PcGVyYXRpb25DYXJkUg1vcGVyYXRpb25DYXJkElQKEm9w'
    'ZXJhdGlvbl9jYXJkX25ldxgEIAMoCzImLmJpbGliaWxpLmFwcC52aWV3LnYxLk9wZXJhdGlvbk'
    'NhcmROZXdSEG9wZXJhdGlvbkNhcmROZXcSRwoNY29udHJhY3RfY2FyZBgFIAEoCzIiLmJpbGli'
    'aWxpLmFwcC52aWV3LnYxLkNvbnRyYWN0Q2FyZFIMY29udHJhY3RDYXJkEkgKDGNhcmRzX3NlY2'
    '9uZBgGIAMoCzIlLmJpbGliaWxpLmFwcC52aWV3LnYxLk9wZXJhdGlvbkNhcmRWMlILY2FyZHNT'
    'ZWNvbmQ=');

@$core.Deprecated('Use videoPointDescriptor instead')
const VideoPoint$json = {
  '1': 'VideoPoint',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'from', '3': 2, '4': 1, '5': 3, '10': 'from'},
    {'1': 'to', '3': 3, '4': 1, '5': 3, '10': 'to'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'cover', '3': 5, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'logo_url', '3': 6, '4': 1, '5': 9, '10': 'logoUrl'},
  ],
};

/// Descriptor for `VideoPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoPointDescriptor = $convert.base64Decode(
    'CgpWaWRlb1BvaW50EhIKBHR5cGUYASABKAVSBHR5cGUSEgoEZnJvbRgCIAEoA1IEZnJvbRIOCg'
    'J0bxgDIAEoA1ICdG8SGAoHY29udGVudBgEIAEoCVIHY29udGVudBIUCgVjb3ZlchgFIAEoCVIF'
    'Y292ZXISGQoIbG9nb191cmwYBiABKAlSB2xvZ29Vcmw=');

@$core.Deprecated('Use videoShotDescriptor instead')
const VideoShot$json = {
  '1': 'VideoShot',
  '2': [
    {'1': 'pv_data', '3': 1, '4': 1, '5': 9, '10': 'pvData'},
    {'1': 'img_x_len', '3': 2, '4': 1, '5': 5, '10': 'imgXLen'},
    {'1': 'img_y_len', '3': 3, '4': 1, '5': 5, '10': 'imgYLen'},
    {'1': 'img_x_size', '3': 4, '4': 1, '5': 5, '10': 'imgXSize'},
    {'1': 'img_y_size', '3': 5, '4': 1, '5': 5, '10': 'imgYSize'},
    {'1': 'image', '3': 6, '4': 3, '5': 9, '10': 'image'},
  ],
};

/// Descriptor for `VideoShot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoShotDescriptor = $convert.base64Decode(
    'CglWaWRlb1Nob3QSFwoHcHZfZGF0YRgBIAEoCVIGcHZEYXRhEhoKCWltZ194X2xlbhgCIAEoBV'
    'IHaW1nWExlbhIaCglpbWdfeV9sZW4YAyABKAVSB2ltZ1lMZW4SHAoKaW1nX3hfc2l6ZRgEIAEo'
    'BVIIaW1nWFNpemUSHAoKaW1nX3lfc2l6ZRgFIAEoBVIIaW1nWVNpemUSFAoFaW1hZ2UYBiADKA'
    'lSBWltYWdl');

@$core.Deprecated('Use viewMaterialDescriptor instead')
const ViewMaterial$json = {
  '1': 'ViewMaterial',
  '2': [
    {'1': 'oid', '3': 1, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'mid', '3': 2, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'author', '3': 4, '4': 1, '5': 9, '10': 'author'},
    {'1': 'jump_url', '3': 5, '4': 1, '5': 9, '10': 'jumpUrl'},
  ],
};

/// Descriptor for `ViewMaterial`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewMaterialDescriptor = $convert.base64Decode(
    'CgxWaWV3TWF0ZXJpYWwSEAoDb2lkGAEgASgDUgNvaWQSEAoDbWlkGAIgASgDUgNtaWQSFAoFdG'
    'l0bGUYAyABKAlSBXRpdGxlEhYKBmF1dGhvchgEIAEoCVIGYXV0aG9yEhkKCGp1bXBfdXJsGAUg'
    'ASgJUgdqdW1wVXJs');

@$core.Deprecated('Use viewMaterialReplyDescriptor instead')
const ViewMaterialReply$json = {
  '1': 'ViewMaterialReply',
  '2': [
    {
      '1': 'material_res',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.MaterialRes',
      '10': 'materialRes'
    },
    {
      '1': 'material_left',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.MaterialLeft',
      '10': 'materialLeft'
    },
  ],
};

/// Descriptor for `ViewMaterialReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewMaterialReplyDescriptor = $convert.base64Decode(
    'ChFWaWV3TWF0ZXJpYWxSZXBseRJECgxtYXRlcmlhbF9yZXMYASADKAsyIS5iaWxpYmlsaS5hcH'
    'Audmlldy52MS5NYXRlcmlhbFJlc1ILbWF0ZXJpYWxSZXMSRwoNbWF0ZXJpYWxfbGVmdBgCIAEo'
    'CzIiLmJpbGliaWxpLmFwcC52aWV3LnYxLk1hdGVyaWFsTGVmdFIMbWF0ZXJpYWxMZWZ0');

@$core.Deprecated('Use viewMaterialReqDescriptor instead')
const ViewMaterialReq$json = {
  '1': 'ViewMaterialReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
  ],
};

/// Descriptor for `ViewMaterialReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewMaterialReqDescriptor = $convert.base64Decode(
    'Cg9WaWV3TWF0ZXJpYWxSZXESEAoDYWlkGAEgASgDUgNhaWQSEgoEYnZpZBgCIAEoCVIEYnZpZB'
    'IQCgNjaWQYAyABKANSA2NpZA==');

@$core.Deprecated('Use viewPageDescriptor instead')
const ViewPage$json = {
  '1': 'ViewPage',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Page',
      '10': 'page'
    },
    {
      '1': 'audio',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Audio',
      '10': 'audio'
    },
    {
      '1': 'dm',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.DM',
      '10': 'dm'
    },
    {'1': 'download_title', '3': 4, '4': 1, '5': 9, '10': 'downloadTitle'},
    {
      '1': 'download_subtitle',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'downloadSubtitle'
    },
  ],
};

/// Descriptor for `ViewPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewPageDescriptor = $convert.base64Decode(
    'CghWaWV3UGFnZRIxCgRwYWdlGAEgASgLMh0uYmlsaWJpbGkuYXBwLmFyY2hpdmUudjEuUGFnZV'
    'IEcGFnZRIxCgVhdWRpbxgCIAEoCzIbLmJpbGliaWxpLmFwcC52aWV3LnYxLkF1ZGlvUgVhdWRp'
    'bxIoCgJkbRgDIAEoCzIYLmJpbGliaWxpLmFwcC52aWV3LnYxLkRNUgJkbRIlCg5kb3dubG9hZF'
    '90aXRsZRgEIAEoCVINZG93bmxvYWRUaXRsZRIrChFkb3dubG9hZF9zdWJ0aXRsZRgFIAEoCVIQ'
    'ZG93bmxvYWRTdWJ0aXRsZQ==');

@$core.Deprecated('Use viewProgressReplyDescriptor instead')
const ViewProgressReply$json = {
  '1': 'ViewProgressReply',
  '2': [
    {
      '1': 'video_guide',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.VideoGuide',
      '10': 'videoGuide'
    },
    {
      '1': 'chronos',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Chronos',
      '10': 'chronos'
    },
    {
      '1': 'arc_shot',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.VideoShot',
      '10': 'arcShot'
    },
    {
      '1': 'points',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.VideoPoint',
      '10': 'points'
    },
    {
      '1': 'point_material',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PointMaterial',
      '10': 'pointMaterial'
    },
    {'1': 'point_permanent', '3': 6, '4': 1, '5': 8, '10': 'pointPermanent'},
    {
      '1': 'buzzword_periods',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.BuzzwordConfig',
      '10': 'buzzwordPeriods'
    },
  ],
};

/// Descriptor for `ViewProgressReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewProgressReplyDescriptor = $convert.base64Decode(
    'ChFWaWV3UHJvZ3Jlc3NSZXBseRJBCgt2aWRlb19ndWlkZRgBIAEoCzIgLmJpbGliaWxpLmFwcC'
    '52aWV3LnYxLlZpZGVvR3VpZGVSCnZpZGVvR3VpZGUSNwoHY2hyb25vcxgCIAEoCzIdLmJpbGli'
    'aWxpLmFwcC52aWV3LnYxLkNocm9ub3NSB2Nocm9ub3MSOgoIYXJjX3Nob3QYAyABKAsyHy5iaW'
    'xpYmlsaS5hcHAudmlldy52MS5WaWRlb1Nob3RSB2FyY1Nob3QSOAoGcG9pbnRzGAQgAygLMiAu'
    'YmlsaWJpbGkuYXBwLnZpZXcudjEuVmlkZW9Qb2ludFIGcG9pbnRzEkoKDnBvaW50X21hdGVyaW'
    'FsGAUgASgLMiMuYmlsaWJpbGkuYXBwLnZpZXcudjEuUG9pbnRNYXRlcmlhbFINcG9pbnRNYXRl'
    'cmlhbBInCg9wb2ludF9wZXJtYW5lbnQYBiABKAhSDnBvaW50UGVybWFuZW50Ek8KEGJ1enp3b3'
    'JkX3BlcmlvZHMYByADKAsyJC5iaWxpYmlsaS5hcHAudmlldy52MS5CdXp6d29yZENvbmZpZ1IP'
    'YnV6endvcmRQZXJpb2Rz');

@$core.Deprecated('Use viewProgressReqDescriptor instead')
const ViewProgressReq$json = {
  '1': 'ViewProgressReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'up_mid', '3': 3, '4': 1, '5': 3, '10': 'upMid'},
    {'1': 'engine_version', '3': 4, '4': 1, '5': 9, '10': 'engineVersion'},
    {'1': 'message_protocol', '3': 5, '4': 1, '5': 9, '10': 'messageProtocol'},
    {'1': 'service_key', '3': 6, '4': 1, '5': 9, '10': 'serviceKey'},
  ],
};

/// Descriptor for `ViewProgressReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewProgressReqDescriptor = $convert.base64Decode(
    'Cg9WaWV3UHJvZ3Jlc3NSZXESEAoDYWlkGAEgASgDUgNhaWQSEAoDY2lkGAIgASgDUgNjaWQSFQ'
    'oGdXBfbWlkGAMgASgDUgV1cE1pZBIlCg5lbmdpbmVfdmVyc2lvbhgEIAEoCVINZW5naW5lVmVy'
    'c2lvbhIpChBtZXNzYWdlX3Byb3RvY29sGAUgASgJUg9tZXNzYWdlUHJvdG9jb2wSHwoLc2Vydm'
    'ljZV9rZXkYBiABKAlSCnNlcnZpY2VLZXk=');

@$core.Deprecated('Use viewReplyDescriptor instead')
const ViewReply$json = {
  '1': 'ViewReply',
  '2': [
    {
      '1': 'arc',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.v1.Arc',
      '10': 'arc'
    },
    {
      '1': 'pages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewPage',
      '10': 'pages'
    },
    {
      '1': 'owner_ext',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.OnwerExt',
      '10': 'ownerExt'
    },
    {
      '1': 'req_user',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReqUser',
      '10': 'reqUser'
    },
    {
      '1': 'tag',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Tag',
      '10': 'tag'
    },
    {
      '1': 't_icon',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewReply.TIconEntry',
      '10': 'tIcon'
    },
    {
      '1': 'season',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Season',
      '10': 'season'
    },
    {
      '1': 'elec_rank',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ElecRank',
      '10': 'elecRank'
    },
    {
      '1': 'history',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.History',
      '10': 'history'
    },
    {
      '1': 'relates',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Relate',
      '10': 'relates'
    },
    {
      '1': 'dislike',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Dislike',
      '10': 'dislike'
    },
    {
      '1': 'player_icon',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PlayerIcon',
      '10': 'playerIcon'
    },
    {'1': 'vip_active', '3': 13, '4': 1, '5': 9, '10': 'vipActive'},
    {'1': 'bvid', '3': 14, '4': 1, '5': 9, '10': 'bvid'},
    {
      '1': 'honor',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Honor',
      '10': 'honor'
    },
    {
      '1': 'relate_tab',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.RelateTab',
      '10': 'relateTab'
    },
    {'1': 'activity_url', '3': 17, '4': 1, '5': 9, '10': 'activityUrl'},
    {
      '1': 'bgm',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Bgm',
      '10': 'bgm'
    },
    {
      '1': 'staff',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Staff',
      '10': 'staff'
    },
    {'1': 'argue_msg', '3': 20, '4': 1, '5': 9, '10': 'argueMsg'},
    {'1': 'short_link', '3': 21, '4': 1, '5': 9, '10': 'shortLink'},
    {'1': 'play_param', '3': 22, '4': 1, '5': 5, '10': 'playParam'},
    {
      '1': 'label',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Label',
      '10': 'label'
    },
    {
      '1': 'ugc_season',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UgcSeason',
      '10': 'ugcSeason'
    },
    {
      '1': 'config',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Config',
      '10': 'config'
    },
    {'1': 'share_subtitle', '3': 26, '4': 1, '5': 9, '10': 'shareSubtitle'},
    {
      '1': 'interaction',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Interaction',
      '10': 'interaction'
    },
    {
      '1': 'ecode',
      '3': 28,
      '4': 1,
      '5': 14,
      '6': '.bilibili.app.view.v1.ECode',
      '10': 'ecode'
    },
    {
      '1': 'custom_config',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CustomConfig',
      '10': 'customConfig'
    },
    {
      '1': 'cms',
      '3': 30,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.CM',
      '10': 'cms'
    },
    {
      '1': 'cm_config',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CMConfig',
      '10': 'cmConfig'
    },
    {
      '1': 'tab',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Tab',
      '10': 'tab'
    },
    {
      '1': 'rank',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Rank',
      '10': 'rank'
    },
    {
      '1': 'tf_panel_customized',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.TFPanelCustomized',
      '10': 'tfPanelCustomized'
    },
    {
      '1': 'up_act',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UpAct',
      '10': 'upAct'
    },
    {
      '1': 'user_garb',
      '3': 36,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UserGarb',
      '10': 'userGarb'
    },
    {
      '1': 'activity_season',
      '3': 37,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ActivitySeason',
      '10': 'activitySeason'
    },
    {'1': 'badge_url', '3': 38, '4': 1, '5': 9, '10': 'badgeUrl'},
    {
      '1': 'live_order_info',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.LiveOrderInfo',
      '10': 'liveOrderInfo'
    },
    {
      '1': 'desc_v2',
      '3': 40,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.DescV2',
      '10': 'descV2'
    },
    {
      '1': 'cm_ipad',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CmIpad',
      '10': 'cmIpad'
    },
    {
      '1': 'sticker',
      '3': 42,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewMaterial',
      '10': 'sticker'
    },
    {
      '1': 'up_like_img',
      '3': 43,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.UpLikeImg',
      '10': 'upLikeImg'
    },
    {
      '1': 'like_custom',
      '3': 44,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.LikeCustom',
      '10': 'likeCustom'
    },
    {
      '1': 'desc_tag',
      '3': 45,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.Tag',
      '10': 'descTag'
    },
    {
      '1': 'special_cell',
      '3': 46,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.SpecialCell',
      '10': 'specialCell'
    },
    {
      '1': 'online',
      '3': 47,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.Online',
      '10': 'online'
    },
    {
      '1': 'cm_under_player',
      '3': 48,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'cmUnderPlayer'
    },
    {
      '1': 'video_source',
      '3': 49,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.ViewMaterial',
      '10': 'videoSource'
    },
    {
      '1': 'special_cell_new',
      '3': 50,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.SpecialCell',
      '10': 'specialCellNew'
    },
    {
      '1': 'premiere',
      '3': 51,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PremiereResource',
      '10': 'premiere'
    },
    {
      '1': 'refresh_special_cell',
      '3': 52,
      '4': 1,
      '5': 8,
      '10': 'refreshSpecialCell'
    },
    {
      '1': 'material_left',
      '3': 53,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.MaterialLeft',
      '10': 'materialLeft'
    },
    {'1': 'notes_count', '3': 54, '4': 1, '5': 3, '10': 'notesCount'},
    {
      '1': 'pull_action',
      '3': 55,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.PullClientAction',
      '10': 'pullAction'
    },
    {
      '1': 'arc_extra',
      '3': 56,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ArcExtra',
      '10': 'arcExtra'
    },
    {
      '1': 'pagination',
      '3': 57,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pagination.PaginationReply',
      '10': 'pagination'
    },
    {
      '1': 'like_animation',
      '3': 58,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.LikeAnimation',
      '10': 'likeAnimation'
    },
    {
      '1': 'reply_preface',
      '3': 59,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.ReplyStyle',
      '10': 'replyPreface'
    },
    {
      '1': 'refresh_page',
      '3': 60,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.RefreshPage',
      '10': 'refreshPage'
    },
    {
      '1': 'coin_custom',
      '3': 61,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.CoinCustom',
      '10': 'coinCustom'
    },
  ],
  '3': [ViewReply_TIconEntry$json],
};

@$core.Deprecated('Use viewReplyDescriptor instead')
const ViewReply_TIconEntry$json = {
  '1': 'TIconEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.TIcon',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `ViewReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewReplyDescriptor = $convert.base64Decode(
    'CglWaWV3UmVwbHkSLgoDYXJjGAEgASgLMhwuYmlsaWJpbGkuYXBwLmFyY2hpdmUudjEuQXJjUg'
    'NhcmMSNAoFcGFnZXMYAiADKAsyHi5iaWxpYmlsaS5hcHAudmlldy52MS5WaWV3UGFnZVIFcGFn'
    'ZXMSOwoJb3duZXJfZXh0GAMgASgLMh4uYmlsaWJpbGkuYXBwLnZpZXcudjEuT253ZXJFeHRSCG'
    '93bmVyRXh0EjgKCHJlcV91c2VyGAQgASgLMh0uYmlsaWJpbGkuYXBwLnZpZXcudjEuUmVxVXNl'
    'clIHcmVxVXNlchIrCgN0YWcYBSADKAsyGS5iaWxpYmlsaS5hcHAudmlldy52MS5UYWdSA3RhZx'
    'JBCgZ0X2ljb24YBiADKAsyKi5iaWxpYmlsaS5hcHAudmlldy52MS5WaWV3UmVwbHkuVEljb25F'
    'bnRyeVIFdEljb24SNAoGc2Vhc29uGAcgASgLMhwuYmlsaWJpbGkuYXBwLnZpZXcudjEuU2Vhc2'
    '9uUgZzZWFzb24SOwoJZWxlY19yYW5rGAggASgLMh4uYmlsaWJpbGkuYXBwLnZpZXcudjEuRWxl'
    'Y1JhbmtSCGVsZWNSYW5rEjcKB2hpc3RvcnkYCSABKAsyHS5iaWxpYmlsaS5hcHAudmlldy52MS'
    '5IaXN0b3J5UgdoaXN0b3J5EjYKB3JlbGF0ZXMYCiADKAsyHC5iaWxpYmlsaS5hcHAudmlldy52'
    'MS5SZWxhdGVSB3JlbGF0ZXMSNwoHZGlzbGlrZRgLIAEoCzIdLmJpbGliaWxpLmFwcC52aWV3Ln'
    'YxLkRpc2xpa2VSB2Rpc2xpa2USQQoLcGxheWVyX2ljb24YDCABKAsyIC5iaWxpYmlsaS5hcHAu'
    'dmlldy52MS5QbGF5ZXJJY29uUgpwbGF5ZXJJY29uEh0KCnZpcF9hY3RpdmUYDSABKAlSCXZpcE'
    'FjdGl2ZRISCgRidmlkGA4gASgJUgRidmlkEjEKBWhvbm9yGA8gASgLMhsuYmlsaWJpbGkuYXBw'
    'LnZpZXcudjEuSG9ub3JSBWhvbm9yEj4KCnJlbGF0ZV90YWIYECADKAsyHy5iaWxpYmlsaS5hcH'
    'Audmlldy52MS5SZWxhdGVUYWJSCXJlbGF0ZVRhYhIhCgxhY3Rpdml0eV91cmwYESABKAlSC2Fj'
    'dGl2aXR5VXJsEisKA2JnbRgSIAMoCzIZLmJpbGliaWxpLmFwcC52aWV3LnYxLkJnbVIDYmdtEj'
    'EKBXN0YWZmGBMgAygLMhsuYmlsaWJpbGkuYXBwLnZpZXcudjEuU3RhZmZSBXN0YWZmEhsKCWFy'
    'Z3VlX21zZxgUIAEoCVIIYXJndWVNc2cSHQoKc2hvcnRfbGluaxgVIAEoCVIJc2hvcnRMaW5rEh'
    '0KCnBsYXlfcGFyYW0YFiABKAVSCXBsYXlQYXJhbRIxCgVsYWJlbBgXIAEoCzIbLmJpbGliaWxp'
    'LmFwcC52aWV3LnYxLkxhYmVsUgVsYWJlbBI+Cgp1Z2Nfc2Vhc29uGBggASgLMh8uYmlsaWJpbG'
    'kuYXBwLnZpZXcudjEuVWdjU2Vhc29uUgl1Z2NTZWFzb24SNAoGY29uZmlnGBkgASgLMhwuYmls'
    'aWJpbGkuYXBwLnZpZXcudjEuQ29uZmlnUgZjb25maWcSJQoOc2hhcmVfc3VidGl0bGUYGiABKA'
    'lSDXNoYXJlU3VidGl0bGUSQwoLaW50ZXJhY3Rpb24YGyABKAsyIS5iaWxpYmlsaS5hcHAudmll'
    'dy52MS5JbnRlcmFjdGlvblILaW50ZXJhY3Rpb24SMQoFZWNvZGUYHCABKA4yGy5iaWxpYmlsaS'
    '5hcHAudmlldy52MS5FQ29kZVIFZWNvZGUSRwoNY3VzdG9tX2NvbmZpZxgdIAEoCzIiLmJpbGli'
    'aWxpLmFwcC52aWV3LnYxLkN1c3RvbUNvbmZpZ1IMY3VzdG9tQ29uZmlnEioKA2NtcxgeIAMoCz'
    'IYLmJpbGliaWxpLmFwcC52aWV3LnYxLkNNUgNjbXMSOwoJY21fY29uZmlnGB8gASgLMh4uYmls'
    'aWJpbGkuYXBwLnZpZXcudjEuQ01Db25maWdSCGNtQ29uZmlnEisKA3RhYhggIAEoCzIZLmJpbG'
    'liaWxpLmFwcC52aWV3LnYxLlRhYlIDdGFiEi4KBHJhbmsYISABKAsyGi5iaWxpYmlsaS5hcHAu'
    'dmlldy52MS5SYW5rUgRyYW5rElcKE3RmX3BhbmVsX2N1c3RvbWl6ZWQYIiABKAsyJy5iaWxpYm'
    'lsaS5hcHAudmlldy52MS5URlBhbmVsQ3VzdG9taXplZFIRdGZQYW5lbEN1c3RvbWl6ZWQSMgoG'
    'dXBfYWN0GCMgASgLMhsuYmlsaWJpbGkuYXBwLnZpZXcudjEuVXBBY3RSBXVwQWN0EjsKCXVzZX'
    'JfZ2FyYhgkIAEoCzIeLmJpbGliaWxpLmFwcC52aWV3LnYxLlVzZXJHYXJiUgh1c2VyR2FyYhJN'
    'Cg9hY3Rpdml0eV9zZWFzb24YJSABKAsyJC5iaWxpYmlsaS5hcHAudmlldy52MS5BY3Rpdml0eV'
    'NlYXNvblIOYWN0aXZpdHlTZWFzb24SGwoJYmFkZ2VfdXJsGCYgASgJUghiYWRnZVVybBJLCg9s'
    'aXZlX29yZGVyX2luZm8YJyABKAsyIy5iaWxpYmlsaS5hcHAudmlldy52MS5MaXZlT3JkZXJJbm'
    'ZvUg1saXZlT3JkZXJJbmZvEjUKB2Rlc2NfdjIYKCADKAsyHC5iaWxpYmlsaS5hcHAudmlldy52'
    'MS5EZXNjVjJSBmRlc2NWMhI1CgdjbV9pcGFkGCkgASgLMhwuYmlsaWJpbGkuYXBwLnZpZXcudj'
    'EuQ21JcGFkUgZjbUlwYWQSPAoHc3RpY2tlchgqIAMoCzIiLmJpbGliaWxpLmFwcC52aWV3LnYx'
    'LlZpZXdNYXRlcmlhbFIHc3RpY2tlchI/Cgt1cF9saWtlX2ltZxgrIAEoCzIfLmJpbGliaWxpLm'
    'FwcC52aWV3LnYxLlVwTGlrZUltZ1IJdXBMaWtlSW1nEkEKC2xpa2VfY3VzdG9tGCwgASgLMiAu'
    'YmlsaWJpbGkuYXBwLnZpZXcudjEuTGlrZUN1c3RvbVIKbGlrZUN1c3RvbRI0CghkZXNjX3RhZx'
    'gtIAMoCzIZLmJpbGliaWxpLmFwcC52aWV3LnYxLlRhZ1IHZGVzY1RhZxJECgxzcGVjaWFsX2Nl'
    'bGwYLiABKAsyIS5iaWxpYmlsaS5hcHAudmlldy52MS5TcGVjaWFsQ2VsbFILc3BlY2lhbENlbG'
    'wSNAoGb25saW5lGC8gASgLMhwuYmlsaWJpbGkuYXBwLnZpZXcudjEuT25saW5lUgZvbmxpbmUS'
    'PAoPY21fdW5kZXJfcGxheWVyGDAgASgLMhQuZ29vZ2xlLnByb3RvYnVmLkFueVINY21VbmRlcl'
    'BsYXllchJFCgx2aWRlb19zb3VyY2UYMSADKAsyIi5iaWxpYmlsaS5hcHAudmlldy52MS5WaWV3'
    'TWF0ZXJpYWxSC3ZpZGVvU291cmNlEksKEHNwZWNpYWxfY2VsbF9uZXcYMiADKAsyIS5iaWxpYm'
    'lsaS5hcHAudmlldy52MS5TcGVjaWFsQ2VsbFIOc3BlY2lhbENlbGxOZXcSQgoIcHJlbWllcmUY'
    'MyABKAsyJi5iaWxpYmlsaS5hcHAudmlldy52MS5QcmVtaWVyZVJlc291cmNlUghwcmVtaWVyZR'
    'IwChRyZWZyZXNoX3NwZWNpYWxfY2VsbBg0IAEoCFIScmVmcmVzaFNwZWNpYWxDZWxsEkcKDW1h'
    'dGVyaWFsX2xlZnQYNSABKAsyIi5iaWxpYmlsaS5hcHAudmlldy52MS5NYXRlcmlhbExlZnRSDG'
    '1hdGVyaWFsTGVmdBIfCgtub3Rlc19jb3VudBg2IAEoA1IKbm90ZXNDb3VudBJHCgtwdWxsX2Fj'
    'dGlvbhg3IAEoCzImLmJpbGliaWxpLmFwcC52aWV3LnYxLlB1bGxDbGllbnRBY3Rpb25SCnB1bG'
    'xBY3Rpb24SOwoJYXJjX2V4dHJhGDggASgLMh4uYmlsaWJpbGkuYXBwLnZpZXcudjEuQXJjRXh0'
    'cmFSCGFyY0V4dHJhEkQKCnBhZ2luYXRpb24YOSABKAsyJC5iaWxpYmlsaS5wYWdpbmF0aW9uLl'
    'BhZ2luYXRpb25SZXBseVIKcGFnaW5hdGlvbhJKCg5saWtlX2FuaW1hdGlvbhg6IAEoCzIjLmJp'
    'bGliaWxpLmFwcC52aWV3LnYxLkxpa2VBbmltYXRpb25SDWxpa2VBbmltYXRpb24SRQoNcmVwbH'
    'lfcHJlZmFjZRg7IAEoCzIgLmJpbGliaWxpLmFwcC52aWV3LnYxLlJlcGx5U3R5bGVSDHJlcGx5'
    'UHJlZmFjZRJECgxyZWZyZXNoX3BhZ2UYPCABKAsyIS5iaWxpYmlsaS5hcHAudmlldy52MS5SZW'
    'ZyZXNoUGFnZVILcmVmcmVzaFBhZ2USQQoLY29pbl9jdXN0b20YPSABKAsyIC5iaWxpYmlsaS5h'
    'cHAudmlldy52MS5Db2luQ3VzdG9tUgpjb2luQ3VzdG9tGlUKClRJY29uRW50cnkSEAoDa2V5GA'
    'EgASgJUgNrZXkSMQoFdmFsdWUYAiABKAsyGy5iaWxpYmlsaS5hcHAudmlldy52MS5USWNvblIF'
    'dmFsdWU6AjgB');

@$core.Deprecated('Use viewReqDescriptor instead')
const ViewReq$json = {
  '1': 'ViewReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'from', '3': 3, '4': 1, '5': 9, '10': 'from'},
    {'1': 'trackid', '3': 4, '4': 1, '5': 9, '10': 'trackid'},
    {'1': 'ad_extra', '3': 5, '4': 1, '5': 9, '10': 'adExtra'},
    {'1': 'qn', '3': 6, '4': 1, '5': 5, '10': 'qn'},
    {'1': 'fnver', '3': 7, '4': 1, '5': 5, '10': 'fnver'},
    {'1': 'fnval', '3': 8, '4': 1, '5': 5, '10': 'fnval'},
    {'1': 'force_host', '3': 9, '4': 1, '5': 5, '10': 'forceHost'},
    {'1': 'fourk', '3': 10, '4': 1, '5': 5, '10': 'fourk'},
    {'1': 'spmid', '3': 11, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 12, '4': 1, '5': 9, '10': 'fromSpmid'},
    {'1': 'autoplay', '3': 13, '4': 1, '5': 5, '10': 'autoplay'},
    {
      '1': 'player_args',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.archive.middleware.v1.PlayerArgs',
      '10': 'playerArgs'
    },
    {'1': 'page_version', '3': 15, '4': 1, '5': 9, '10': 'pageVersion'},
    {'1': 'biz_extra', '3': 16, '4': 1, '5': 9, '10': 'bizExtra'},
    {'1': 'device_type', '3': 17, '4': 1, '5': 3, '10': 'deviceType'},
    {'1': 'relates_page', '3': 18, '4': 1, '5': 3, '10': 'relatesPage'},
    {'1': 'session_id', '3': 19, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'in_feed_play', '3': 20, '4': 1, '5': 5, '10': 'inFeedPlay'},
    {'1': 'play_mode', '3': 21, '4': 1, '5': 9, '10': 'playMode'},
    {
      '1': 'pagination',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pagination.Pagination',
      '10': 'pagination'
    },
    {'1': 'refresh', '3': 23, '4': 1, '5': 5, '10': 'refresh'},
    {'1': 'refresh_num', '3': 24, '4': 1, '5': 5, '10': 'refreshNum'},
  ],
};

/// Descriptor for `ViewReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewReqDescriptor = $convert.base64Decode(
    'CgdWaWV3UmVxEhAKA2FpZBgBIAEoA1IDYWlkEhIKBGJ2aWQYAiABKAlSBGJ2aWQSEgoEZnJvbR'
    'gDIAEoCVIEZnJvbRIYCgd0cmFja2lkGAQgASgJUgd0cmFja2lkEhkKCGFkX2V4dHJhGAUgASgJ'
    'UgdhZEV4dHJhEg4KAnFuGAYgASgFUgJxbhIUCgVmbnZlchgHIAEoBVIFZm52ZXISFAoFZm52YW'
    'wYCCABKAVSBWZudmFsEh0KCmZvcmNlX2hvc3QYCSABKAVSCWZvcmNlSG9zdBIUCgVmb3VyaxgK'
    'IAEoBVIFZm91cmsSFAoFc3BtaWQYCyABKAlSBXNwbWlkEh0KCmZyb21fc3BtaWQYDCABKAlSCW'
    'Zyb21TcG1pZBIaCghhdXRvcGxheRgNIAEoBVIIYXV0b3BsYXkSTwoLcGxheWVyX2FyZ3MYDiAB'
    'KAsyLi5iaWxpYmlsaS5hcHAuYXJjaGl2ZS5taWRkbGV3YXJlLnYxLlBsYXllckFyZ3NSCnBsYX'
    'llckFyZ3MSIQoMcGFnZV92ZXJzaW9uGA8gASgJUgtwYWdlVmVyc2lvbhIbCgliaXpfZXh0cmEY'
    'ECABKAlSCGJpekV4dHJhEh8KC2RldmljZV90eXBlGBEgASgDUgpkZXZpY2VUeXBlEiEKDHJlbG'
    'F0ZXNfcGFnZRgSIAEoA1ILcmVsYXRlc1BhZ2USHQoKc2Vzc2lvbl9pZBgTIAEoCVIJc2Vzc2lv'
    'bklkEiAKDGluX2ZlZWRfcGxheRgUIAEoBVIKaW5GZWVkUGxheRIbCglwbGF5X21vZGUYFSABKA'
    'lSCHBsYXlNb2RlEj8KCnBhZ2luYXRpb24YFiABKAsyHy5iaWxpYmlsaS5wYWdpbmF0aW9uLlBh'
    'Z2luYXRpb25SCnBhZ2luYXRpb24SGAoHcmVmcmVzaBgXIAEoBVIHcmVmcmVzaBIfCgtyZWZyZX'
    'NoX251bRgYIAEoBVIKcmVmcmVzaE51bQ==');

@$core.Deprecated('Use viewTagReplyDescriptor instead')
const ViewTagReply$json = {
  '1': 'ViewTagReply',
  '2': [
    {
      '1': 'special_cell_new',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.view.v1.SpecialCell',
      '10': 'specialCellNew'
    },
    {
      '1': 'material_left',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.MaterialLeft',
      '10': 'materialLeft'
    },
  ],
};

/// Descriptor for `ViewTagReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewTagReplyDescriptor = $convert.base64Decode(
    'CgxWaWV3VGFnUmVwbHkSSwoQc3BlY2lhbF9jZWxsX25ldxgBIAMoCzIhLmJpbGliaWxpLmFwcC'
    '52aWV3LnYxLlNwZWNpYWxDZWxsUg5zcGVjaWFsQ2VsbE5ldxJHCg1tYXRlcmlhbF9sZWZ0GAIg'
    'ASgLMiIuYmlsaWJpbGkuYXBwLnZpZXcudjEuTWF0ZXJpYWxMZWZ0UgxtYXRlcmlhbExlZnQ=');

@$core.Deprecated('Use viewTagReqDescriptor instead')
const ViewTagReq$json = {
  '1': 'ViewTagReq',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'bvid', '3': 2, '4': 1, '5': 9, '10': 'bvid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
  ],
};

/// Descriptor for `ViewTagReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewTagReqDescriptor = $convert.base64Decode(
    'CgpWaWV3VGFnUmVxEhAKA2FpZBgBIAEoA1IDYWlkEhIKBGJ2aWQYAiABKAlSBGJ2aWQSEAoDY2'
    'lkGAMgASgDUgNjaWQSFAoFc3BtaWQYBCABKAlSBXNwbWlk');

@$core.Deprecated('Use vipDescriptor instead')
const Vip$json = {
  '1': 'Vip',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'due_date', '3': 2, '4': 1, '5': 3, '10': 'dueDate'},
    {'1': 'due_remark', '3': 3, '4': 1, '5': 9, '10': 'dueRemark'},
    {'1': 'access_status', '3': 4, '4': 1, '5': 5, '10': 'accessStatus'},
    {'1': 'vip_status', '3': 5, '4': 1, '5': 5, '10': 'vipStatus'},
    {'1': 'vip_status_warn', '3': 6, '4': 1, '5': 9, '10': 'vipStatusWarn'},
    {'1': 'theme_type', '3': 7, '4': 1, '5': 5, '10': 'themeType'},
    {
      '1': 'label',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.app.view.v1.VipLabel',
      '10': 'label'
    },
  ],
};

/// Descriptor for `Vip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vipDescriptor = $convert.base64Decode(
    'CgNWaXASEgoEdHlwZRgBIAEoBVIEdHlwZRIZCghkdWVfZGF0ZRgCIAEoA1IHZHVlRGF0ZRIdCg'
    'pkdWVfcmVtYXJrGAMgASgJUglkdWVSZW1hcmsSIwoNYWNjZXNzX3N0YXR1cxgEIAEoBVIMYWNj'
    'ZXNzU3RhdHVzEh0KCnZpcF9zdGF0dXMYBSABKAVSCXZpcFN0YXR1cxImCg92aXBfc3RhdHVzX3'
    'dhcm4YBiABKAlSDXZpcFN0YXR1c1dhcm4SHQoKdGhlbWVfdHlwZRgHIAEoBVIJdGhlbWVUeXBl'
    'EjQKBWxhYmVsGAggASgLMh4uYmlsaWJpbGkuYXBwLnZpZXcudjEuVmlwTGFiZWxSBWxhYmVs');

@$core.Deprecated('Use vipLabelDescriptor instead')
const VipLabel$json = {
  '1': 'VipLabel',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'label_theme', '3': 3, '4': 1, '5': 9, '10': 'labelTheme'},
  ],
};

/// Descriptor for `VipLabel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vipLabelDescriptor = $convert.base64Decode(
    'CghWaXBMYWJlbBISCgRwYXRoGAEgASgJUgRwYXRoEhIKBHRleHQYAiABKAlSBHRleHQSHwoLbG'
    'FiZWxfdGhlbWUYAyABKAlSCmxhYmVsVGhlbWU=');
