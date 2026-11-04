// This is a generated file - do not edit.
//
// Generated from bilibili/pgc/gateway/player/v2/playurl.proto.

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

@$core.Deprecated('Use clipTypeDescriptor instead')
const ClipType$json = {
  '1': 'ClipType',
  '2': [
    {'1': 'NT_UNKNOWN', '2': 0},
    {'1': 'CLIP_TYPE_OP', '2': 1},
    {'1': 'CLIP_TYPE_ED', '2': 2},
    {'1': 'CLIP_TYPE_HE', '2': 3},
    {'1': 'CLIP_TYPE_MULTI_VIEW', '2': 4},
    {'1': 'CLIP_TYPE_AD', '2': 5},
  ],
};

/// Descriptor for `ClipType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List clipTypeDescriptor = $convert.base64Decode(
    'CghDbGlwVHlwZRIOCgpOVF9VTktOT1dOEAASEAoMQ0xJUF9UWVBFX09QEAESEAoMQ0xJUF9UWV'
    'BFX0VEEAISEAoMQ0xJUF9UWVBFX0hFEAMSGAoUQ0xJUF9UWVBFX01VTFRJX1ZJRVcQBBIQCgxD'
    'TElQX1RZUEVfQUQQBQ==');

@$core.Deprecated('Use codeTypeDescriptor instead')
const CodeType$json = {
  '1': 'CodeType',
  '2': [
    {'1': 'NOCODE', '2': 0},
    {'1': 'CODE264', '2': 1},
    {'1': 'CODE265', '2': 2},
  ],
};

/// Descriptor for `CodeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List codeTypeDescriptor = $convert.base64Decode(
    'CghDb2RlVHlwZRIKCgZOT0NPREUQABILCgdDT0RFMjY0EAESCwoHQ09ERTI2NRAC');

@$core.Deprecated('Use drmTechTypeDescriptor instead')
const DrmTechType$json = {
  '1': 'DrmTechType',
  '2': [
    {'1': 'NON', '2': 0},
    {'1': 'FAIR_PLAY', '2': 1},
    {'1': 'WIDE_VINE', '2': 2},
    {'1': 'BILI_DRM', '2': 3},
  ],
};

/// Descriptor for `DrmTechType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List drmTechTypeDescriptor = $convert.base64Decode(
    'CgtEcm1UZWNoVHlwZRIHCgNOT04QABINCglGQUlSX1BMQVkQARINCglXSURFX1ZJTkUQAhIMCg'
    'hCSUxJX0RSTRAD');

@$core.Deprecated('Use epPublicityVideoTypeDescriptor instead')
const EpPublicityVideoType$json = {
  '1': 'EpPublicityVideoType',
  '2': [
    {'1': 'PRE', '2': 0},
    {'1': 'INLINE', '2': 1},
  ],
};

/// Descriptor for `EpPublicityVideoType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List epPublicityVideoTypeDescriptor =
    $convert.base64Decode(
        'ChRFcFB1YmxpY2l0eVZpZGVvVHlwZRIHCgNQUkUQABIKCgZJTkxJTkUQAQ==');

@$core.Deprecated('Use inlineSceneDescriptor instead')
const InlineScene$json = {
  '1': 'InlineScene',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'RELATED_EP', '2': 1},
    {'1': 'HE', '2': 2},
    {'1': 'SKIP', '2': 3},
  ],
};

/// Descriptor for `InlineScene`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List inlineSceneDescriptor = $convert.base64Decode(
    'CgtJbmxpbmVTY2VuZRILCgdVTktOT1dOEAASDgoKUkVMQVRFRF9FUBABEgYKAkhFEAISCAoEU0'
    'tJUBAD');

@$core.Deprecated('Use inlineTypeDescriptor instead')
const InlineType$json = {
  '1': 'InlineType',
  '2': [
    {'1': 'TYPE_UNKNOWN', '2': 0},
    {'1': 'TYPE_WHOLE', '2': 1},
    {'1': 'TYPE_HE_CLIP', '2': 2},
    {'1': 'TYPE_PREVIEW', '2': 3},
  ],
};

/// Descriptor for `InlineType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List inlineTypeDescriptor = $convert.base64Decode(
    'CgpJbmxpbmVUeXBlEhAKDFRZUEVfVU5LTk9XThAAEg4KClRZUEVfV0hPTEUQARIQCgxUWVBFX0'
    'hFX0NMSVAQAhIQCgxUWVBFX1BSRVZJRVcQAw==');

@$core.Deprecated('Use limitActionTypeDescriptor instead')
const LimitActionType$json = {
  '1': 'LimitActionType',
  '2': [
    {'1': 'LAT_UNKNOWN', '2': 0},
    {'1': 'SHOW_LIMIT_DIALOG', '2': 1},
    {'1': 'SKIP_CURRENT_EP', '2': 2},
  ],
};

/// Descriptor for `LimitActionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List limitActionTypeDescriptor = $convert.base64Decode(
    'Cg9MaW1pdEFjdGlvblR5cGUSDwoLTEFUX1VOS05PV04QABIVChFTSE9XX0xJTUlUX0RJQUxPRx'
    'ABEhMKD1NLSVBfQ1VSUkVOVF9FUBAC');

@$core.Deprecated('Use playErrDescriptor instead')
const PlayErr$json = {
  '1': 'PlayErr',
  '2': [
    {'1': 'NoErr', '2': 0},
    {'1': 'WithMultiDeviceLoginErr', '2': 1},
  ],
};

/// Descriptor for `PlayErr`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List playErrDescriptor = $convert.base64Decode(
    'CgdQbGF5RXJyEgkKBU5vRXJyEAASGwoXV2l0aE11bHRpRGV2aWNlTG9naW5FcnIQAQ==');

@$core.Deprecated('Use securityLevelDescriptor instead')
const SecurityLevel$json = {
  '1': 'SecurityLevel',
  '2': [
    {'1': 'LEVEL_UNKNOWN', '2': 0},
    {'1': 'LEVEL_L1', '2': 1},
    {'1': 'LEVEL_L2', '2': 2},
    {'1': 'LEVEL_L3', '2': 3},
  ],
};

/// Descriptor for `SecurityLevel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List securityLevelDescriptor = $convert.base64Decode(
    'Cg1TZWN1cml0eUxldmVsEhEKDUxFVkVMX1VOS05PV04QABIMCghMRVZFTF9MMRABEgwKCExFVk'
    'VMX0wyEAISDAoITEVWRUxfTDMQAw==');

@$core.Deprecated('Use animationDescriptor instead')
const Animation$json = {
  '1': 'Animation',
  '2': [
    {
      '1': 'qn_svga_animation_map',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Animation.QnSvgaAnimationMapEntry',
      '10': 'qnSvgaAnimationMap'
    },
  ],
  '3': [Animation_QnSvgaAnimationMapEntry$json],
};

@$core.Deprecated('Use animationDescriptor instead')
const Animation_QnSvgaAnimationMapEntry$json = {
  '1': 'QnSvgaAnimationMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Animation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List animationDescriptor = $convert.base64Decode(
    'CglBbmltYXRpb24SdAoVcW5fc3ZnYV9hbmltYXRpb25fbWFwGAEgAygLMkEuYmlsaWJpbGkucG'
    'djLmdhdGV3YXkucGxheWVyLnYyLkFuaW1hdGlvbi5RblN2Z2FBbmltYXRpb25NYXBFbnRyeVIS'
    'cW5TdmdhQW5pbWF0aW9uTWFwGkUKF1FuU3ZnYUFuaW1hdGlvbk1hcEVudHJ5EhAKA2tleRgBIA'
    'EoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use audioMaterialProtoDescriptor instead')
const AudioMaterialProto$json = {
  '1': 'AudioMaterialProto',
  '2': [
    {'1': 'audio_id', '3': 1, '4': 1, '5': 9, '10': 'audioId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'edition', '3': 3, '4': 1, '5': 9, '10': 'edition'},
    {'1': 'person_id', '3': 4, '4': 1, '5': 4, '10': 'personId'},
    {'1': 'person_name', '3': 5, '4': 1, '5': 9, '10': 'personName'},
    {'1': 'person_avatar', '3': 6, '4': 1, '5': 9, '10': 'personAvatar'},
    {
      '1': 'audio',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DashItem',
      '10': 'audio'
    },
  ],
};

/// Descriptor for `AudioMaterialProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioMaterialProtoDescriptor = $convert.base64Decode(
    'ChJBdWRpb01hdGVyaWFsUHJvdG8SGQoIYXVkaW9faWQYASABKAlSB2F1ZGlvSWQSFAoFdGl0bG'
    'UYAiABKAlSBXRpdGxlEhgKB2VkaXRpb24YAyABKAlSB2VkaXRpb24SGwoJcGVyc29uX2lkGAQg'
    'ASgEUghwZXJzb25JZBIfCgtwZXJzb25fbmFtZRgFIAEoCVIKcGVyc29uTmFtZRIjCg1wZXJzb2'
    '5fYXZhdGFyGAYgASgJUgxwZXJzb25BdmF0YXISPgoFYXVkaW8YByADKAsyKC5iaWxpYmlsaS5w'
    'Z2MuZ2F0ZXdheS5wbGF5ZXIudjIuRGFzaEl0ZW1SBWF1ZGlv');

@$core.Deprecated('Use badgeInfoDescriptor instead')
const BadgeInfo$json = {
  '1': 'BadgeInfo',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'bg_color', '3': 2, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'bg_color_night', '3': 3, '4': 1, '5': 9, '10': 'bgColorNight'},
    {'1': 'text_color', '3': 4, '4': 1, '5': 9, '10': 'textColor'},
    {
      '1': 'bg_gradient_color',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.GradientColor',
      '10': 'bgGradientColor'
    },
    {'1': 'img', '3': 6, '4': 1, '5': 9, '10': 'img'},
  ],
};

/// Descriptor for `BadgeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List badgeInfoDescriptor = $convert.base64Decode(
    'CglCYWRnZUluZm8SEgoEdGV4dBgBIAEoCVIEdGV4dBIZCghiZ19jb2xvchgCIAEoCVIHYmdDb2'
    'xvchIkCg5iZ19jb2xvcl9uaWdodBgDIAEoCVIMYmdDb2xvck5pZ2h0Eh0KCnRleHRfY29sb3IY'
    'BCABKAlSCXRleHRDb2xvchJZChFiZ19ncmFkaWVudF9jb2xvchgFIAEoCzItLmJpbGliaWxpLn'
    'BnYy5nYXRld2F5LnBsYXllci52Mi5HcmFkaWVudENvbG9yUg9iZ0dyYWRpZW50Q29sb3ISEAoD'
    'aW1nGAYgASgJUgNpbWc=');

@$core.Deprecated('Use bottomDisplayDescriptor instead')
const BottomDisplay$json = {
  '1': 'BottomDisplay',
  '2': [
    {
      '1': 'title',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'title'
    },
    {'1': 'icon', '3': 2, '4': 1, '5': 9, '10': 'icon'},
  ],
};

/// Descriptor for `BottomDisplay`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bottomDisplayDescriptor = $convert.base64Decode(
    'Cg1Cb3R0b21EaXNwbGF5Ej4KBXRpdGxlGAEgASgLMiguYmlsaWJpbGkucGdjLmdhdGV3YXkucG'
    'xheWVyLnYyLlRleHRJbmZvUgV0aXRsZRISCgRpY29uGAIgASgJUgRpY29u');

@$core.Deprecated('Use buttonInfoDescriptor instead')
const ButtonInfo$json = {
  '1': 'ButtonInfo',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 2, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_color_night', '3': 3, '4': 1, '5': 9, '10': 'textColorNight'},
    {'1': 'bg_color', '3': 4, '4': 1, '5': 9, '10': 'bgColor'},
    {'1': 'bg_color_night', '3': 5, '4': 1, '5': 9, '10': 'bgColorNight'},
    {'1': 'link', '3': 6, '4': 1, '5': 9, '10': 'link'},
    {'1': 'action_type', '3': 7, '4': 1, '5': 9, '10': 'actionType'},
    {
      '1': 'badge_info',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.BadgeInfo',
      '10': 'badgeInfo'
    },
    {
      '1': 'report',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Report',
      '10': 'report'
    },
    {
      '1': 'left_strikethrough_text',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'leftStrikethroughText'
    },
    {
      '1': 'simple_text_info',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'simpleTextInfo'
    },
    {'1': 'simple_bg_color', '3': 12, '4': 1, '5': 9, '10': 'simpleBgColor'},
    {
      '1': 'simple_bg_color_night',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'simpleBgColorNight'
    },
    {
      '1': 'bg_gradient_color',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.GradientColor',
      '10': 'bgGradientColor'
    },
    {
      '1': 'order_report_params',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo.OrderReportParamsEntry',
      '10': 'orderReportParams'
    },
    {
      '1': 'task_param',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TaskParam',
      '10': 'taskParam'
    },
    {'1': 'pc_link', '3': 17, '4': 1, '5': 9, '10': 'pcLink'},
  ],
  '3': [ButtonInfo_OrderReportParamsEntry$json],
};

@$core.Deprecated('Use buttonInfoDescriptor instead')
const ButtonInfo_OrderReportParamsEntry$json = {
  '1': 'OrderReportParamsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ButtonInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buttonInfoDescriptor = $convert.base64Decode(
    'CgpCdXR0b25JbmZvEhIKBHRleHQYASABKAlSBHRleHQSHQoKdGV4dF9jb2xvchgCIAEoCVIJdG'
    'V4dENvbG9yEigKEHRleHRfY29sb3JfbmlnaHQYAyABKAlSDnRleHRDb2xvck5pZ2h0EhkKCGJn'
    'X2NvbG9yGAQgASgJUgdiZ0NvbG9yEiQKDmJnX2NvbG9yX25pZ2h0GAUgASgJUgxiZ0NvbG9yTm'
    'lnaHQSEgoEbGluaxgGIAEoCVIEbGluaxIfCgthY3Rpb25fdHlwZRgHIAEoCVIKYWN0aW9uVHlw'
    'ZRJICgpiYWRnZV9pbmZvGAggASgLMikuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLk'
    'JhZGdlSW5mb1IJYmFkZ2VJbmZvEj4KBnJlcG9ydBgJIAEoCzImLmJpbGliaWxpLnBnYy5nYXRl'
    'd2F5LnBsYXllci52Mi5SZXBvcnRSBnJlcG9ydBI2ChdsZWZ0X3N0cmlrZXRocm91Z2hfdGV4dB'
    'gKIAEoCVIVbGVmdFN0cmlrZXRocm91Z2hUZXh0ElIKEHNpbXBsZV90ZXh0X2luZm8YCyABKAsy'
    'KC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVGV4dEluZm9SDnNpbXBsZVRleHRJbm'
    'ZvEiYKD3NpbXBsZV9iZ19jb2xvchgMIAEoCVINc2ltcGxlQmdDb2xvchIxChVzaW1wbGVfYmdf'
    'Y29sb3JfbmlnaHQYDSABKAlSEnNpbXBsZUJnQ29sb3JOaWdodBJZChFiZ19ncmFkaWVudF9jb2'
    'xvchgOIAEoCzItLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5HcmFkaWVudENvbG9y'
    'Ug9iZ0dyYWRpZW50Q29sb3IScQoTb3JkZXJfcmVwb3J0X3BhcmFtcxgPIAMoCzJBLmJpbGliaW'
    'xpLnBnYy5nYXRld2F5LnBsYXllci52Mi5CdXR0b25JbmZvLk9yZGVyUmVwb3J0UGFyYW1zRW50'
    'cnlSEW9yZGVyUmVwb3J0UGFyYW1zEkgKCnRhc2tfcGFyYW0YECABKAsyKS5iaWxpYmlsaS5wZ2'
    'MuZ2F0ZXdheS5wbGF5ZXIudjIuVGFza1BhcmFtUgl0YXNrUGFyYW0SFwoHcGNfbGluaxgRIAEo'
    'CVIGcGNMaW5rGkQKFk9yZGVyUmVwb3J0UGFyYW1zRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFA'
    'oFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use castTipsDescriptor instead')
const CastTips$json = {
  '1': 'CastTips',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `CastTips`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List castTipsDescriptor = $convert.base64Decode(
    'CghDYXN0VGlwcxISCgRjb2RlGAEgASgFUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2'
    'U=');

@$core.Deprecated('Use clipInfoDescriptor instead')
const ClipInfo$json = {
  '1': 'ClipInfo',
  '2': [
    {'1': 'material_no', '3': 1, '4': 1, '5': 3, '10': 'materialNo'},
    {'1': 'start', '3': 2, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 3, '4': 1, '5': 5, '10': 'end'},
    {
      '1': 'clip_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.ClipType',
      '10': 'clipType'
    },
    {'1': 'toast_text', '3': 5, '4': 1, '5': 9, '10': 'toastText'},
    {
      '1': 'multi_view',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.MultiView',
      '10': 'multiView'
    },
  ],
};

/// Descriptor for `ClipInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipInfoDescriptor = $convert.base64Decode(
    'CghDbGlwSW5mbxIfCgttYXRlcmlhbF9ubxgBIAEoA1IKbWF0ZXJpYWxObxIUCgVzdGFydBgCIA'
    'EoBVIFc3RhcnQSEAoDZW5kGAMgASgFUgNlbmQSRQoJY2xpcF90eXBlGAQgASgOMiguYmlsaWJp'
    'bGkucGdjLmdhdGV3YXkucGxheWVyLnYyLkNsaXBUeXBlUghjbGlwVHlwZRIdCgp0b2FzdF90ZX'
    'h0GAUgASgJUgl0b2FzdFRleHQSSAoKbXVsdGlfdmlldxgGIAEoCzIpLmJpbGliaWxpLnBnYy5n'
    'YXRld2F5LnBsYXllci52Mi5NdWx0aVZpZXdSCW11bHRpVmlldw==');

@$core.Deprecated('Use continuePlayInfoDescriptor instead')
const ContinuePlayInfo$json = {
  '1': 'ContinuePlayInfo',
  '2': [
    {
      '1': 'continue_play_ep_id',
      '3': 1,
      '4': 1,
      '5': 3,
      '10': 'continuePlayEpId'
    },
  ],
};

/// Descriptor for `ContinuePlayInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List continuePlayInfoDescriptor = $convert.base64Decode(
    'ChBDb250aW51ZVBsYXlJbmZvEi0KE2NvbnRpbnVlX3BsYXlfZXBfaWQYASABKANSEGNvbnRpbn'
    'VlUGxheUVwSWQ=');

@$core.Deprecated('Use couponDescriptor instead')
const Coupon$json = {
  '1': 'Coupon',
  '2': [
    {'1': 'coupon_token', '3': 1, '4': 1, '5': 9, '10': 'couponToken'},
    {'1': 'type', '3': 2, '4': 1, '5': 3, '10': 'type'},
    {'1': 'value', '3': 3, '4': 1, '5': 9, '10': 'value'},
    {'1': 'use_desc', '3': 4, '4': 1, '5': 9, '10': 'useDesc'},
    {'1': 'title', '3': 5, '4': 1, '5': 9, '10': 'title'},
    {'1': 'desc', '3': 6, '4': 1, '5': 9, '10': 'desc'},
    {'1': 'pay_button_text', '3': 7, '4': 1, '5': 9, '10': 'payButtonText'},
    {
      '1': 'pay_button_text_line_through',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'payButtonTextLineThrough'
    },
    {'1': 'real_amount', '3': 9, '4': 1, '5': 9, '10': 'realAmount'},
    {
      '1': 'expire_time',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expireTime'
    },
    {'1': 'otype', '3': 11, '4': 1, '5': 3, '10': 'otype'},
    {'1': 'amount', '3': 12, '4': 1, '5': 9, '10': 'amount'},
  ],
};

/// Descriptor for `Coupon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List couponDescriptor = $convert.base64Decode(
    'CgZDb3Vwb24SIQoMY291cG9uX3Rva2VuGAEgASgJUgtjb3Vwb25Ub2tlbhISCgR0eXBlGAIgAS'
    'gDUgR0eXBlEhQKBXZhbHVlGAMgASgJUgV2YWx1ZRIZCgh1c2VfZGVzYxgEIAEoCVIHdXNlRGVz'
    'YxIUCgV0aXRsZRgFIAEoCVIFdGl0bGUSEgoEZGVzYxgGIAEoCVIEZGVzYxImCg9wYXlfYnV0dG'
    '9uX3RleHQYByABKAlSDXBheUJ1dHRvblRleHQSPgoccGF5X2J1dHRvbl90ZXh0X2xpbmVfdGhy'
    'b3VnaBgIIAEoCVIYcGF5QnV0dG9uVGV4dExpbmVUaHJvdWdoEh8KC3JlYWxfYW1vdW50GAkgAS'
    'gJUgpyZWFsQW1vdW50EjsKC2V4cGlyZV90aW1lGAogASgLMhouZ29vZ2xlLnByb3RvYnVmLlRp'
    'bWVzdGFtcFIKZXhwaXJlVGltZRIUCgVvdHlwZRgLIAEoA1IFb3R5cGUSFgoGYW1vdW50GAwgAS'
    'gJUgZhbW91bnQ=');

@$core.Deprecated('Use couponInfoDescriptor instead')
const CouponInfo$json = {
  '1': 'CouponInfo',
  '2': [
    {
      '1': 'toast',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.CouponToast',
      '10': 'toast'
    },
    {
      '1': 'pop_win',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PopWin',
      '10': 'popWin'
    },
  ],
};

/// Descriptor for `CouponInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List couponInfoDescriptor = $convert.base64Decode(
    'CgpDb3Vwb25JbmZvEkEKBXRvYXN0GAEgASgLMisuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheW'
    'VyLnYyLkNvdXBvblRvYXN0UgV0b2FzdBI/Cgdwb3Bfd2luGAIgASgLMiYuYmlsaWJpbGkucGdj'
    'LmdhdGV3YXkucGxheWVyLnYyLlBvcFdpblIGcG9wV2lu');

@$core.Deprecated('Use couponTextInfoDescriptor instead')
const CouponTextInfo$json = {
  '1': 'CouponTextInfo',
  '2': [
    {'1': 'positive_preview', '3': 1, '4': 1, '5': 9, '10': 'positivePreview'},
    {'1': 'section', '3': 2, '4': 1, '5': 9, '10': 'section'},
  ],
};

/// Descriptor for `CouponTextInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List couponTextInfoDescriptor = $convert.base64Decode(
    'Cg5Db3Vwb25UZXh0SW5mbxIpChBwb3NpdGl2ZV9wcmV2aWV3GAEgASgJUg9wb3NpdGl2ZVByZX'
    'ZpZXcSGAoHc2VjdGlvbhgCIAEoCVIHc2VjdGlvbg==');

@$core.Deprecated('Use couponToastDescriptor instead')
const CouponToast$json = {
  '1': 'CouponToast',
  '2': [
    {
      '1': 'text_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.CouponTextInfo',
      '10': 'textInfo'
    },
    {
      '1': 'button',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'button'
    },
  ],
};

/// Descriptor for `CouponToast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List couponToastDescriptor = $convert.base64Decode(
    'CgtDb3Vwb25Ub2FzdBJLCgl0ZXh0X2luZm8YASABKAsyLi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS'
    '5wbGF5ZXIudjIuQ291cG9uVGV4dEluZm9SCHRleHRJbmZvEkIKBmJ1dHRvbhgCIAEoCzIqLmJp'
    'bGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5CdXR0b25JbmZvUgZidXR0b24=');

@$core.Deprecated('Use dashItemDescriptor instead')
const DashItem$json = {
  '1': 'DashItem',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 13, '10': 'id'},
    {'1': 'base_url', '3': 2, '4': 1, '5': 9, '10': 'baseUrl'},
    {'1': 'backup_url', '3': 3, '4': 3, '5': 9, '10': 'backupUrl'},
    {'1': 'bandwidth', '3': 4, '4': 1, '5': 13, '10': 'bandwidth'},
    {'1': 'codecid', '3': 5, '4': 1, '5': 13, '10': 'codecid'},
    {'1': 'md5', '3': 6, '4': 1, '5': 9, '10': 'md5'},
    {'1': 'size', '3': 7, '4': 1, '5': 4, '10': 'size'},
    {'1': 'frame_rate', '3': 8, '4': 1, '5': 9, '10': 'frameRate'},
    {'1': 'widevine_pssh', '3': 9, '4': 1, '5': 9, '10': 'widevinePssh'},
  ],
};

/// Descriptor for `DashItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dashItemDescriptor = $convert.base64Decode(
    'CghEYXNoSXRlbRIOCgJpZBgBIAEoDVICaWQSGQoIYmFzZV91cmwYAiABKAlSB2Jhc2VVcmwSHQ'
    'oKYmFja3VwX3VybBgDIAMoCVIJYmFja3VwVXJsEhwKCWJhbmR3aWR0aBgEIAEoDVIJYmFuZHdp'
    'ZHRoEhgKB2NvZGVjaWQYBSABKA1SB2NvZGVjaWQSEAoDbWQ1GAYgASgJUgNtZDUSEgoEc2l6ZR'
    'gHIAEoBFIEc2l6ZRIdCgpmcmFtZV9yYXRlGAggASgJUglmcmFtZVJhdGUSIwoNd2lkZXZpbmVf'
    'cHNzaBgJIAEoCVIMd2lkZXZpbmVQc3No');

@$core.Deprecated('Use dashVideoDescriptor instead')
const DashVideo$json = {
  '1': 'DashVideo',
  '2': [
    {'1': 'base_url', '3': 1, '4': 1, '5': 9, '10': 'baseUrl'},
    {'1': 'backup_url', '3': 2, '4': 3, '5': 9, '10': 'backupUrl'},
    {'1': 'bandwidth', '3': 3, '4': 1, '5': 13, '10': 'bandwidth'},
    {'1': 'codecid', '3': 4, '4': 1, '5': 13, '10': 'codecid'},
    {'1': 'md5', '3': 5, '4': 1, '5': 9, '10': 'md5'},
    {'1': 'size', '3': 6, '4': 1, '5': 4, '10': 'size'},
    {'1': 'audio_id', '3': 7, '4': 1, '5': 13, '10': 'audioId'},
    {'1': 'no_rexcode', '3': 8, '4': 1, '5': 8, '10': 'noRexcode'},
    {'1': 'frame_rate', '3': 9, '4': 1, '5': 9, '10': 'frameRate'},
    {'1': 'width', '3': 10, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 11, '4': 1, '5': 5, '10': 'height'},
    {'1': 'widevine_pssh', '3': 12, '4': 1, '5': 9, '10': 'widevinePssh'},
  ],
};

/// Descriptor for `DashVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dashVideoDescriptor = $convert.base64Decode(
    'CglEYXNoVmlkZW8SGQoIYmFzZV91cmwYASABKAlSB2Jhc2VVcmwSHQoKYmFja3VwX3VybBgCIA'
    'MoCVIJYmFja3VwVXJsEhwKCWJhbmR3aWR0aBgDIAEoDVIJYmFuZHdpZHRoEhgKB2NvZGVjaWQY'
    'BCABKA1SB2NvZGVjaWQSEAoDbWQ1GAUgASgJUgNtZDUSEgoEc2l6ZRgGIAEoBFIEc2l6ZRIZCg'
    'hhdWRpb19pZBgHIAEoDVIHYXVkaW9JZBIdCgpub19yZXhjb2RlGAggASgIUglub1JleGNvZGUS'
    'HQoKZnJhbWVfcmF0ZRgJIAEoCVIJZnJhbWVSYXRlEhQKBXdpZHRoGAogASgFUgV3aWR0aBIWCg'
    'ZoZWlnaHQYCyABKAVSBmhlaWdodBIjCg13aWRldmluZV9wc3NoGAwgASgJUgx3aWRldmluZVBz'
    'c2g=');

@$core.Deprecated('Use dataControlDescriptor instead')
const DataControl$json = {
  '1': 'DataControl',
  '2': [
    {
      '1': 'need_watch_progress',
      '3': 1,
      '4': 1,
      '5': 8,
      '10': 'needWatchProgress'
    },
  ],
};

/// Descriptor for `DataControl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataControlDescriptor = $convert.base64Decode(
    'CgtEYXRhQ29udHJvbBIuChNuZWVkX3dhdGNoX3Byb2dyZXNzGAEgASgIUhFuZWVkV2F0Y2hQcm'
    '9ncmVzcw==');

@$core.Deprecated('Use dialogDescriptor instead')
const Dialog$json = {
  '1': 'Dialog',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 3, '10': 'code'},
    {'1': 'msg', '3': 2, '4': 1, '5': 9, '10': 'msg'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'style_type', '3': 4, '4': 1, '5': 9, '10': 'styleType'},
    {
      '1': 'config',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DialogConfig',
      '10': 'config'
    },
    {
      '1': 'title',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'title'
    },
    {
      '1': 'subtitle',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'subtitle'
    },
    {
      '1': 'image',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ImageInfo',
      '10': 'image'
    },
    {
      '1': 'button',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'button'
    },
    {
      '1': 'bottom_desc',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'bottomDesc'
    },
    {
      '1': 'report',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Report',
      '10': 'report'
    },
    {'1': 'count_down_sec', '3': 12, '4': 1, '5': 5, '10': 'countDownSec'},
    {
      '1': 'right_bottom_desc',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'rightBottomDesc'
    },
    {
      '1': 'bottom_display',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.BottomDisplay',
      '10': 'bottomDisplay'
    },
    {
      '1': 'play_list',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayList',
      '10': 'playList'
    },
  ],
};

/// Descriptor for `Dialog`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dialogDescriptor = $convert.base64Decode(
    'CgZEaWFsb2cSEgoEY29kZRgBIAEoA1IEY29kZRIQCgNtc2cYAiABKAlSA21zZxISCgR0eXBlGA'
    'MgASgJUgR0eXBlEh0KCnN0eWxlX3R5cGUYBCABKAlSCXN0eWxlVHlwZRJECgZjb25maWcYBSAB'
    'KAsyLC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuRGlhbG9nQ29uZmlnUgZjb25maW'
    'cSPgoFdGl0bGUYBiABKAsyKC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVGV4dElu'
    'Zm9SBXRpdGxlEkQKCHN1YnRpdGxlGAcgASgLMiguYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheW'
    'VyLnYyLlRleHRJbmZvUghzdWJ0aXRsZRI/CgVpbWFnZRgIIAEoCzIpLmJpbGliaWxpLnBnYy5n'
    'YXRld2F5LnBsYXllci52Mi5JbWFnZUluZm9SBWltYWdlEkIKBmJ1dHRvbhgJIAMoCzIqLmJpbG'
    'liaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5CdXR0b25JbmZvUgZidXR0b24SSwoLYm90dG9t'
    'X2Rlc2MYCiABKAsyKi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuQnV0dG9uSW5mb1'
    'IKYm90dG9tRGVzYxI+CgZyZXBvcnQYCyABKAsyJi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5'
    'ZXIudjIuUmVwb3J0UgZyZXBvcnQSJAoOY291bnRfZG93bl9zZWMYDCABKAVSDGNvdW50RG93bl'
    'NlYxJUChFyaWdodF9ib3R0b21fZGVzYxgNIAEoCzIoLmJpbGliaWxpLnBnYy5nYXRld2F5LnBs'
    'YXllci52Mi5UZXh0SW5mb1IPcmlnaHRCb3R0b21EZXNjElQKDmJvdHRvbV9kaXNwbGF5GA4gAy'
    'gLMi0uYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLkJvdHRvbURpc3BsYXlSDWJvdHRv'
    'bURpc3BsYXkSRQoJcGxheV9saXN0GA8gAygLMiguYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheW'
    'VyLnYyLlBsYXlMaXN0UghwbGF5TGlzdA==');

@$core.Deprecated('Use dialogConfigDescriptor instead')
const DialogConfig$json = {
  '1': 'DialogConfig',
  '2': [
    {'1': 'is_show_cover', '3': 1, '4': 1, '5': 8, '10': 'isShowCover'},
    {
      '1': 'is_orientation_enable',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'isOrientationEnable'
    },
    {
      '1': 'is_nested_scroll_enable',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'isNestedScrollEnable'
    },
    {
      '1': 'is_force_halfscreen_enable',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'isForceHalfscreenEnable'
    },
    {
      '1': 'is_background_translucent_enable',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'isBackgroundTranslucentEnable'
    },
  ],
};

/// Descriptor for `DialogConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dialogConfigDescriptor = $convert.base64Decode(
    'CgxEaWFsb2dDb25maWcSIgoNaXNfc2hvd19jb3ZlchgBIAEoCFILaXNTaG93Q292ZXISMgoVaX'
    'Nfb3JpZW50YXRpb25fZW5hYmxlGAIgASgIUhNpc09yaWVudGF0aW9uRW5hYmxlEjUKF2lzX25l'
    'c3RlZF9zY3JvbGxfZW5hYmxlGAMgASgIUhRpc05lc3RlZFNjcm9sbEVuYWJsZRI7Chppc19mb3'
    'JjZV9oYWxmc2NyZWVuX2VuYWJsZRgEIAEoCFIXaXNGb3JjZUhhbGZzY3JlZW5FbmFibGUSRwog'
    'aXNfYmFja2dyb3VuZF90cmFuc2x1Y2VudF9lbmFibGUYBSABKAhSHWlzQmFja2dyb3VuZFRyYW'
    '5zbHVjZW50RW5hYmxl');

@$core.Deprecated('Use dimensionDescriptor instead')
const Dimension$json = {
  '1': 'Dimension',
  '2': [
    {'1': 'width', '3': 1, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 2, '4': 1, '5': 5, '10': 'height'},
    {'1': 'rotate', '3': 3, '4': 1, '5': 5, '10': 'rotate'},
  ],
};

/// Descriptor for `Dimension`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dimensionDescriptor = $convert.base64Decode(
    'CglEaW1lbnNpb24SFAoFd2lkdGgYASABKAVSBXdpZHRoEhYKBmhlaWdodBgCIAEoBVIGaGVpZ2'
    'h0EhYKBnJvdGF0ZRgDIAEoBVIGcm90YXRl');

@$core.Deprecated('Use dolbyItemDescriptor instead')
const DolbyItem$json = {
  '1': 'DolbyItem',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.DolbyItem.Type',
      '10': 'type'
    },
    {
      '1': 'audio',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DashItem',
      '10': 'audio'
    },
  ],
  '4': [DolbyItem_Type$json],
};

@$core.Deprecated('Use dolbyItemDescriptor instead')
const DolbyItem_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'NONE', '2': 0},
    {'1': 'COMMON', '2': 1},
    {'1': 'ATMOS', '2': 2},
  ],
};

/// Descriptor for `DolbyItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dolbyItemDescriptor = $convert.base64Decode(
    'CglEb2xieUl0ZW0SQgoEdHlwZRgBIAEoDjIuLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci'
    '52Mi5Eb2xieUl0ZW0uVHlwZVIEdHlwZRI+CgVhdWRpbxgCIAEoCzIoLmJpbGliaWxpLnBnYy5n'
    'YXRld2F5LnBsYXllci52Mi5EYXNoSXRlbVIFYXVkaW8iJwoEVHlwZRIICgROT05FEAASCgoGQ0'
    '9NTU9OEAESCQoFQVRNT1MQAg==');

@$core.Deprecated('Use endPageDescriptor instead')
const EndPage$json = {
  '1': 'EndPage',
  '2': [
    {
      '1': 'dialog',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Dialog',
      '10': 'dialog'
    },
    {'1': 'hide', '3': 2, '4': 1, '5': 8, '10': 'hide'},
  ],
};

/// Descriptor for `EndPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endPageDescriptor = $convert.base64Decode(
    'CgdFbmRQYWdlEj4KBmRpYWxvZxgBIAEoCzImLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci'
    '52Mi5EaWFsb2dSBmRpYWxvZxISCgRoaWRlGAIgASgIUgRoaWRl');

@$core.Deprecated('Use epInlineVideoDescriptor instead')
const EpInlineVideo$json = {
  '1': 'EpInlineVideo',
  '2': [
    {'1': 'material_no', '3': 1, '4': 1, '5': 3, '10': 'materialNo'},
    {'1': 'aid', '3': 2, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
  ],
};

/// Descriptor for `EpInlineVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List epInlineVideoDescriptor = $convert.base64Decode(
    'Cg1FcElubGluZVZpZGVvEh8KC21hdGVyaWFsX25vGAEgASgDUgptYXRlcmlhbE5vEhAKA2FpZB'
    'gCIAEoA1IDYWlkEhAKA2NpZBgDIAEoA1IDY2lk');

@$core.Deprecated('Use episodeAdvertisementInfoDescriptor instead')
const EpisodeAdvertisementInfo$json = {
  '1': 'EpisodeAdvertisementInfo',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'link', '3': 3, '4': 1, '5': 9, '10': 'link'},
    {
      '1': 'follow_video_bnt_flag',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'followVideoBntFlag'
    },
    {'1': 'next_video_title', '3': 5, '4': 1, '5': 9, '10': 'nextVideoTitle'},
    {'1': 'next_video_link', '3': 6, '4': 1, '5': 9, '10': 'nextVideoLink'},
    {'1': 'cid', '3': 7, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'season_id', '3': 8, '4': 1, '5': 5, '10': 'seasonId'},
    {'1': 'follow', '3': 9, '4': 1, '5': 5, '10': 'follow'},
  ],
};

/// Descriptor for `EpisodeAdvertisementInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List episodeAdvertisementInfoDescriptor = $convert.base64Decode(
    'ChhFcGlzb2RlQWR2ZXJ0aXNlbWVudEluZm8SEAoDYWlkGAEgASgDUgNhaWQSFAoFdGl0bGUYAi'
    'ABKAlSBXRpdGxlEhIKBGxpbmsYAyABKAlSBGxpbmsSMQoVZm9sbG93X3ZpZGVvX2JudF9mbGFn'
    'GAQgASgFUhJmb2xsb3dWaWRlb0JudEZsYWcSKAoQbmV4dF92aWRlb190aXRsZRgFIAEoCVIObm'
    'V4dFZpZGVvVGl0bGUSJgoPbmV4dF92aWRlb19saW5rGAYgASgJUg1uZXh0VmlkZW9MaW5rEhAK'
    'A2NpZBgHIAEoA1IDY2lkEhsKCXNlYXNvbl9pZBgIIAEoBVIIc2Vhc29uSWQSFgoGZm9sbG93GA'
    'kgASgFUgZmb2xsb3c=');

@$core.Deprecated('Use episodeInfoDescriptor instead')
const EpisodeInfo$json = {
  '1': 'EpisodeInfo',
  '2': [
    {'1': 'ep_id', '3': 1, '4': 1, '5': 5, '10': 'epId'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'aid', '3': 3, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'ep_status', '3': 4, '4': 1, '5': 3, '10': 'epStatus'},
    {
      '1': 'season_info',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.SeasonInfo',
      '10': 'seasonInfo'
    },
    {'1': 'cover', '3': 6, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'title', '3': 7, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'interaction',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Interaction',
      '10': 'interaction'
    },
    {'1': 'long_title', '3': 9, '4': 1, '5': 9, '10': 'longTitle'},
  ],
};

/// Descriptor for `EpisodeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List episodeInfoDescriptor = $convert.base64Decode(
    'CgtFcGlzb2RlSW5mbxITCgVlcF9pZBgBIAEoBVIEZXBJZBIQCgNjaWQYAiABKANSA2NpZBIQCg'
    'NhaWQYAyABKANSA2FpZBIbCgllcF9zdGF0dXMYBCABKANSCGVwU3RhdHVzEksKC3NlYXNvbl9p'
    'bmZvGAUgASgLMiouYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlNlYXNvbkluZm9SCn'
    'NlYXNvbkluZm8SFAoFY292ZXIYBiABKAlSBWNvdmVyEhQKBXRpdGxlGAcgASgJUgV0aXRsZRJN'
    'CgtpbnRlcmFjdGlvbhgIIAEoCzIrLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5Jbn'
    'RlcmFjdGlvblILaW50ZXJhY3Rpb24SHQoKbG9uZ190aXRsZRgJIAEoCVIJbG9uZ1RpdGxl');

@$core.Deprecated('Use epPreVideoDescriptor instead')
const EpPreVideo$json = {
  '1': 'EpPreVideo',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
  ],
};

/// Descriptor for `EpPreVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List epPreVideoDescriptor = $convert.base64Decode(
    'CgpFcFByZVZpZGVvEhAKA2FpZBgBIAEoA1IDYWlkEhAKA2NpZBgCIAEoA1IDY2lk');

@$core.Deprecated('Use epPublicityVideoDescriptor instead')
const EpPublicityVideo$json = {
  '1': 'EpPublicityVideo',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.EpPublicityVideo.Type',
      '10': 'type'
    },
    {
      '1': 'ep_pre_video',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.EpPreVideo',
      '9': 0,
      '10': 'epPreVideo'
    },
    {
      '1': 'ep_inline_video',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.EpInlineVideo',
      '9': 0,
      '10': 'epInlineVideo'
    },
  ],
  '4': [EpPublicityVideo_Type$json],
  '8': [
    {'1': 'data'},
  ],
};

@$core.Deprecated('Use epPublicityVideoDescriptor instead')
const EpPublicityVideo_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'DATA_NOT_SET', '2': 0},
    {'1': 'EP_PRE_VIDEO', '2': 2},
    {'1': 'EP_INLINE', '2': 3},
  ],
};

/// Descriptor for `EpPublicityVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List epPublicityVideoDescriptor = $convert.base64Decode(
    'ChBFcFB1YmxpY2l0eVZpZGVvEkkKBHR5cGUYASABKA4yNS5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS'
    '5wbGF5ZXIudjIuRXBQdWJsaWNpdHlWaWRlby5UeXBlUgR0eXBlEk4KDGVwX3ByZV92aWRlbxgC'
    'IAEoCzIqLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5FcFByZVZpZGVvSABSCmVwUH'
    'JlVmlkZW8SVwoPZXBfaW5saW5lX3ZpZGVvGAMgASgLMi0uYmlsaWJpbGkucGdjLmdhdGV3YXku'
    'cGxheWVyLnYyLkVwSW5saW5lVmlkZW9IAFINZXBJbmxpbmVWaWRlbyI5CgRUeXBlEhAKDERBVE'
    'FfTk9UX1NFVBAAEhAKDEVQX1BSRV9WSURFTxACEg0KCUVQX0lOTElORRADQgYKBGRhdGE=');

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {
      '1': 'shake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Shake',
      '10': 'shake'
    },
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBI7CgVzaGFrZRgBIAEoCzIlLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi'
    '5TaGFrZVIFc2hha2U=');

@$core.Deprecated('Use freyaConfigDescriptor instead')
const FreyaConfig$json = {
  '1': 'FreyaConfig',
  '2': [
    {'1': 'desc', '3': 1, '4': 1, '5': 9, '10': 'desc'},
    {'1': 'type', '3': 2, '4': 1, '5': 5, '10': 'type'},
    {'1': 'issued_cnt', '3': 3, '4': 1, '5': 5, '10': 'issuedCnt'},
    {'1': 'is_always_show', '3': 4, '4': 1, '5': 8, '10': 'isAlwaysShow'},
    {'1': 'screen_number', '3': 5, '4': 1, '5': 5, '10': 'screenNumber'},
    {
      '1': 'full_screen_number',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'fullScreenNumber'
    },
  ],
};

/// Descriptor for `FreyaConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List freyaConfigDescriptor = $convert.base64Decode(
    'CgtGcmV5YUNvbmZpZxISCgRkZXNjGAEgASgJUgRkZXNjEhIKBHR5cGUYAiABKAVSBHR5cGUSHQ'
    'oKaXNzdWVkX2NudBgDIAEoBVIJaXNzdWVkQ250EiQKDmlzX2Fsd2F5c19zaG93GAQgASgIUgxp'
    'c0Fsd2F5c1Nob3cSIwoNc2NyZWVuX251bWJlchgFIAEoBVIMc2NyZWVuTnVtYmVyEiwKEmZ1bG'
    'xfc2NyZWVuX251bWJlchgGIAEoBVIQZnVsbFNjcmVlbk51bWJlcg==');

@$core.Deprecated('Use gradientColorDescriptor instead')
const GradientColor$json = {
  '1': 'GradientColor',
  '2': [
    {'1': 'start_color', '3': 1, '4': 1, '5': 9, '10': 'startColor'},
    {'1': 'end_color', '3': 2, '4': 1, '5': 9, '10': 'endColor'},
  ],
};

/// Descriptor for `GradientColor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gradientColorDescriptor = $convert.base64Decode(
    'Cg1HcmFkaWVudENvbG9yEh8KC3N0YXJ0X2NvbG9yGAEgASgJUgpzdGFydENvbG9yEhsKCWVuZF'
    '9jb2xvchgCIAEoCVIIZW5kQ29sb3I=');

@$core.Deprecated('Use highDefinitionTrialInfoDescriptor instead')
const HighDefinitionTrialInfo$json = {
  '1': 'HighDefinitionTrialInfo',
  '2': [
    {'1': 'trial_able', '3': 1, '4': 1, '5': 8, '10': 'trialAble'},
    {'1': 'remaining_times', '3': 2, '4': 1, '5': 5, '10': 'remainingTimes'},
    {'1': 'start', '3': 3, '4': 1, '5': 5, '10': 'start'},
    {'1': 'time_length', '3': 4, '4': 1, '5': 5, '10': 'timeLength'},
    {
      '1': 'start_toast',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast',
      '10': 'startToast'
    },
    {
      '1': 'end_toast',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast',
      '10': 'endToast'
    },
    {
      '1': 'report',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Report',
      '10': 'report'
    },
    {
      '1': 'quality_open_tip_btn',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'qualityOpenTipBtn'
    },
    {
      '1': 'no_longer_trial_btn',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'noLongerTrialBtn'
    },
  ],
};

/// Descriptor for `HighDefinitionTrialInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List highDefinitionTrialInfoDescriptor = $convert.base64Decode(
    'ChdIaWdoRGVmaW5pdGlvblRyaWFsSW5mbxIdCgp0cmlhbF9hYmxlGAEgASgIUgl0cmlhbEFibG'
    'USJwoPcmVtYWluaW5nX3RpbWVzGAIgASgFUg5yZW1haW5pbmdUaW1lcxIUCgVzdGFydBgDIAEo'
    'BVIFc3RhcnQSHwoLdGltZV9sZW5ndGgYBCABKAVSCnRpbWVMZW5ndGgSRgoLc3RhcnRfdG9hc3'
    'QYBSABKAsyJS5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVG9hc3RSCnN0YXJ0VG9h'
    'c3QSQgoJZW5kX3RvYXN0GAYgASgLMiUuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLl'
    'RvYXN0UghlbmRUb2FzdBI+CgZyZXBvcnQYByABKAsyJi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5w'
    'bGF5ZXIudjIuUmVwb3J0UgZyZXBvcnQSWwoUcXVhbGl0eV9vcGVuX3RpcF9idG4YCCABKAsyKi'
    '5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuQnV0dG9uSW5mb1IRcXVhbGl0eU9wZW5U'
    'aXBCdG4SWQoTbm9fbG9uZ2VyX3RyaWFsX2J0bhgJIAEoCzIqLmJpbGliaWxpLnBnYy5nYXRld2'
    'F5LnBsYXllci52Mi5CdXR0b25JbmZvUhBub0xvbmdlclRyaWFsQnRu');

@$core.Deprecated('Use historyNodeDescriptor instead')
const HistoryNode$json = {
  '1': 'HistoryNode',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 3, '10': 'nodeId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
  ],
};

/// Descriptor for `HistoryNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyNodeDescriptor = $convert.base64Decode(
    'CgtIaXN0b3J5Tm9kZRIXCgdub2RlX2lkGAEgASgDUgZub2RlSWQSFAoFdGl0bGUYAiABKAlSBX'
    'RpdGxlEhAKA2NpZBgDIAEoA1IDY2lk');

@$core.Deprecated('Use imageInfoDescriptor instead')
const ImageInfo$json = {
  '1': 'ImageInfo',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `ImageInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageInfoDescriptor =
    $convert.base64Decode('CglJbWFnZUluZm8SEAoDdXJsGAEgASgJUgN1cmw=');

@$core.Deprecated('Use interactionDescriptor instead')
const Interaction$json = {
  '1': 'Interaction',
  '2': [
    {
      '1': 'history_node',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.HistoryNode',
      '10': 'historyNode'
    },
    {'1': 'graph_version', '3': 2, '4': 1, '5': 3, '10': 'graphVersion'},
    {'1': 'msg', '3': 3, '4': 1, '5': 9, '10': 'msg'},
    {'1': 'is_interaction', '3': 4, '4': 1, '5': 8, '10': 'isInteraction'},
  ],
};

/// Descriptor for `Interaction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interactionDescriptor = $convert.base64Decode(
    'CgtJbnRlcmFjdGlvbhJOCgxoaXN0b3J5X25vZGUYASABKAsyKy5iaWxpYmlsaS5wZ2MuZ2F0ZX'
    'dheS5wbGF5ZXIudjIuSGlzdG9yeU5vZGVSC2hpc3RvcnlOb2RlEiMKDWdyYXBoX3ZlcnNpb24Y'
    'AiABKANSDGdyYXBoVmVyc2lvbhIQCgNtc2cYAyABKAlSA21zZxIlCg5pc19pbnRlcmFjdGlvbh'
    'gEIAEoCFINaXNJbnRlcmFjdGlvbg==');

@$core.Deprecated('Use multiViewDescriptor instead')
const MultiView$json = {
  '1': 'MultiView',
  '2': [
    {'1': 'button_material', '3': 1, '4': 1, '5': 9, '10': 'buttonMaterial'},
    {'1': 'ep_id', '3': 2, '4': 1, '5': 3, '10': 'epId'},
    {'1': 'cid', '3': 3, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'avid', '3': 4, '4': 1, '5': 3, '10': 'avid'},
  ],
};

/// Descriptor for `MultiView`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List multiViewDescriptor = $convert.base64Decode(
    'CglNdWx0aVZpZXcSJwoPYnV0dG9uX21hdGVyaWFsGAEgASgJUg5idXR0b25NYXRlcmlhbBITCg'
    'VlcF9pZBgCIAEoA1IEZXBJZBIQCgNjaWQYAyABKANSA2NpZBISCgRhdmlkGAQgASgDUgRhdmlk');

@$core.Deprecated('Use payTipDescriptor instead')
const PayTip$json = {
  '1': 'PayTip',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'type', '3': 4, '4': 1, '5': 5, '10': 'type'},
    {'1': 'show_type', '3': 5, '4': 1, '5': 5, '10': 'showType'},
    {'1': 'img', '3': 6, '4': 1, '5': 9, '10': 'img'},
    {'1': 'bg_day_color', '3': 7, '4': 1, '5': 9, '10': 'bgDayColor'},
    {'1': 'bg_night_color', '3': 8, '4': 1, '5': 9, '10': 'bgNightColor'},
    {'1': 'bg_line_color', '3': 9, '4': 1, '5': 9, '10': 'bgLineColor'},
    {
      '1': 'bg_night_line_color',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'bgNightLineColor'
    },
    {'1': 'text_color', '3': 11, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_night_color', '3': 12, '4': 1, '5': 9, '10': 'textNightColor'},
    {'1': 'view_start_time', '3': 13, '4': 1, '5': 3, '10': 'viewStartTime'},
    {
      '1': 'button',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'button'
    },
    {'1': 'url_open_type', '3': 15, '4': 1, '5': 5, '10': 'urlOpenType'},
    {
      '1': 'report',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Report',
      '10': 'report'
    },
    {'1': 'angle_style', '3': 17, '4': 1, '5': 5, '10': 'angleStyle'},
    {'1': 'report_type', '3': 18, '4': 1, '5': 5, '10': 'reportType'},
    {
      '1': 'order_report_params',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PayTip.OrderReportParamsEntry',
      '10': 'orderReportParams'
    },
    {'1': 'giant_screen_img', '3': 20, '4': 1, '5': 9, '10': 'giantScreenImg'},
  ],
  '3': [PayTip_OrderReportParamsEntry$json],
};

@$core.Deprecated('Use payTipDescriptor instead')
const PayTip_OrderReportParamsEntry$json = {
  '1': 'OrderReportParamsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `PayTip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payTipDescriptor = $convert.base64Decode(
    'CgZQYXlUaXASFAoFdGl0bGUYASABKAlSBXRpdGxlEhAKA3VybBgCIAEoCVIDdXJsEhIKBGljb2'
    '4YAyABKAlSBGljb24SEgoEdHlwZRgEIAEoBVIEdHlwZRIbCglzaG93X3R5cGUYBSABKAVSCHNo'
    'b3dUeXBlEhAKA2ltZxgGIAEoCVIDaW1nEiAKDGJnX2RheV9jb2xvchgHIAEoCVIKYmdEYXlDb2'
    'xvchIkCg5iZ19uaWdodF9jb2xvchgIIAEoCVIMYmdOaWdodENvbG9yEiIKDWJnX2xpbmVfY29s'
    'b3IYCSABKAlSC2JnTGluZUNvbG9yEi0KE2JnX25pZ2h0X2xpbmVfY29sb3IYCiABKAlSEGJnTm'
    'lnaHRMaW5lQ29sb3ISHQoKdGV4dF9jb2xvchgLIAEoCVIJdGV4dENvbG9yEigKEHRleHRfbmln'
    'aHRfY29sb3IYDCABKAlSDnRleHROaWdodENvbG9yEiYKD3ZpZXdfc3RhcnRfdGltZRgNIAEoA1'
    'INdmlld1N0YXJ0VGltZRJCCgZidXR0b24YDiADKAsyKi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5w'
    'bGF5ZXIudjIuQnV0dG9uSW5mb1IGYnV0dG9uEiIKDXVybF9vcGVuX3R5cGUYDyABKAVSC3VybE'
    '9wZW5UeXBlEj4KBnJlcG9ydBgQIAEoCzImLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52'
    'Mi5SZXBvcnRSBnJlcG9ydBIfCgthbmdsZV9zdHlsZRgRIAEoBVIKYW5nbGVTdHlsZRIfCgtyZX'
    'BvcnRfdHlwZRgSIAEoBVIKcmVwb3J0VHlwZRJtChNvcmRlcl9yZXBvcnRfcGFyYW1zGBMgAygL'
    'Mj0uYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlBheVRpcC5PcmRlclJlcG9ydFBhcm'
    'Ftc0VudHJ5UhFvcmRlclJlcG9ydFBhcmFtcxIoChBnaWFudF9zY3JlZW5faW1nGBQgASgJUg5n'
    'aWFudFNjcmVlbkltZxpEChZPcmRlclJlcG9ydFBhcmFtc0VudHJ5EhAKA2tleRgBIAEoCVIDa2'
    'V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use playAbilityConfDescriptor instead')
const PlayAbilityConf$json = {
  '1': 'PlayAbilityConf',
  '2': [
    {
      '1': 'background_play_disable',
      '3': 1,
      '4': 1,
      '5': 8,
      '10': 'backgroundPlayDisable'
    },
    {'1': 'flip_disable', '3': 2, '4': 1, '5': 8, '10': 'flipDisable'},
    {'1': 'cast_disable', '3': 3, '4': 1, '5': 8, '10': 'castDisable'},
    {'1': 'feedback_disable', '3': 4, '4': 1, '5': 8, '10': 'feedbackDisable'},
    {'1': 'subtitle_disable', '3': 5, '4': 1, '5': 8, '10': 'subtitleDisable'},
    {
      '1': 'playback_rate_disable',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'playbackRateDisable'
    },
    {'1': 'time_up_disable', '3': 7, '4': 1, '5': 8, '10': 'timeUpDisable'},
    {
      '1': 'playback_mode_disable',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'playbackModeDisable'
    },
    {
      '1': 'scale_mode_disable',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'scaleModeDisable'
    },
    {'1': 'like_disable', '3': 10, '4': 1, '5': 8, '10': 'likeDisable'},
    {'1': 'dislike_disable', '3': 11, '4': 1, '5': 8, '10': 'dislikeDisable'},
    {'1': 'coin_disable', '3': 12, '4': 1, '5': 8, '10': 'coinDisable'},
    {'1': 'elec_disable', '3': 13, '4': 1, '5': 8, '10': 'elecDisable'},
    {'1': 'share_disable', '3': 14, '4': 1, '5': 8, '10': 'shareDisable'},
    {
      '1': 'screen_shot_disable',
      '3': 15,
      '4': 1,
      '5': 8,
      '10': 'screenShotDisable'
    },
    {
      '1': 'lock_screen_disable',
      '3': 16,
      '4': 1,
      '5': 8,
      '10': 'lockScreenDisable'
    },
    {
      '1': 'recommend_disable',
      '3': 17,
      '4': 1,
      '5': 8,
      '10': 'recommendDisable'
    },
    {
      '1': 'playback_speed_disable',
      '3': 18,
      '4': 1,
      '5': 8,
      '10': 'playbackSpeedDisable'
    },
    {
      '1': 'definition_disable',
      '3': 19,
      '4': 1,
      '5': 8,
      '10': 'definitionDisable'
    },
    {
      '1': 'selections_disable',
      '3': 20,
      '4': 1,
      '5': 8,
      '10': 'selectionsDisable'
    },
    {'1': 'next_disable', '3': 21, '4': 1, '5': 8, '10': 'nextDisable'},
    {'1': 'edit_dm_disable', '3': 22, '4': 1, '5': 8, '10': 'editDmDisable'},
    {
      '1': 'small_window_disable',
      '3': 23,
      '4': 1,
      '5': 8,
      '10': 'smallWindowDisable'
    },
    {'1': 'shake_disable', '3': 24, '4': 1, '5': 8, '10': 'shakeDisable'},
    {'1': 'outer_dm_disable', '3': 25, '4': 1, '5': 8, '10': 'outerDmDisable'},
    {'1': 'inner_dm_disable', '3': 26, '4': 1, '5': 8, '10': 'innerDmDisable'},
    {
      '1': 'freya_enter_disable',
      '3': 27,
      '4': 1,
      '5': 8,
      '10': 'freyaEnterDisable'
    },
    {'1': 'dolby_disable', '3': 28, '4': 1, '5': 8, '10': 'dolbyDisable'},
    {
      '1': 'freya_full_disable',
      '3': 29,
      '4': 1,
      '5': 8,
      '10': 'freyaFullDisable'
    },
    {
      '1': 'skip_oped_switch_disable',
      '3': 30,
      '4': 1,
      '5': 8,
      '10': 'skipOpedSwitchDisable'
    },
    {
      '1': 'record_screen_disable',
      '3': 31,
      '4': 1,
      '5': 8,
      '10': 'recordScreenDisable'
    },
    {
      '1': 'color_optimize_disable',
      '3': 32,
      '4': 1,
      '5': 8,
      '10': 'colorOptimizeDisable'
    },
    {'1': 'dubbing_disable', '3': 33, '4': 1, '5': 8, '10': 'dubbingDisable'},
  ],
};

/// Descriptor for `PlayAbilityConf`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playAbilityConfDescriptor = $convert.base64Decode(
    'Cg9QbGF5QWJpbGl0eUNvbmYSNgoXYmFja2dyb3VuZF9wbGF5X2Rpc2FibGUYASABKAhSFWJhY2'
    'tncm91bmRQbGF5RGlzYWJsZRIhCgxmbGlwX2Rpc2FibGUYAiABKAhSC2ZsaXBEaXNhYmxlEiEK'
    'DGNhc3RfZGlzYWJsZRgDIAEoCFILY2FzdERpc2FibGUSKQoQZmVlZGJhY2tfZGlzYWJsZRgEIA'
    'EoCFIPZmVlZGJhY2tEaXNhYmxlEikKEHN1YnRpdGxlX2Rpc2FibGUYBSABKAhSD3N1YnRpdGxl'
    'RGlzYWJsZRIyChVwbGF5YmFja19yYXRlX2Rpc2FibGUYBiABKAhSE3BsYXliYWNrUmF0ZURpc2'
    'FibGUSJgoPdGltZV91cF9kaXNhYmxlGAcgASgIUg10aW1lVXBEaXNhYmxlEjIKFXBsYXliYWNr'
    'X21vZGVfZGlzYWJsZRgIIAEoCFITcGxheWJhY2tNb2RlRGlzYWJsZRIsChJzY2FsZV9tb2RlX2'
    'Rpc2FibGUYCSABKAhSEHNjYWxlTW9kZURpc2FibGUSIQoMbGlrZV9kaXNhYmxlGAogASgIUgts'
    'aWtlRGlzYWJsZRInCg9kaXNsaWtlX2Rpc2FibGUYCyABKAhSDmRpc2xpa2VEaXNhYmxlEiEKDG'
    'NvaW5fZGlzYWJsZRgMIAEoCFILY29pbkRpc2FibGUSIQoMZWxlY19kaXNhYmxlGA0gASgIUgtl'
    'bGVjRGlzYWJsZRIjCg1zaGFyZV9kaXNhYmxlGA4gASgIUgxzaGFyZURpc2FibGUSLgoTc2NyZW'
    'VuX3Nob3RfZGlzYWJsZRgPIAEoCFIRc2NyZWVuU2hvdERpc2FibGUSLgoTbG9ja19zY3JlZW5f'
    'ZGlzYWJsZRgQIAEoCFIRbG9ja1NjcmVlbkRpc2FibGUSKwoRcmVjb21tZW5kX2Rpc2FibGUYES'
    'ABKAhSEHJlY29tbWVuZERpc2FibGUSNAoWcGxheWJhY2tfc3BlZWRfZGlzYWJsZRgSIAEoCFIU'
    'cGxheWJhY2tTcGVlZERpc2FibGUSLQoSZGVmaW5pdGlvbl9kaXNhYmxlGBMgASgIUhFkZWZpbm'
    'l0aW9uRGlzYWJsZRItChJzZWxlY3Rpb25zX2Rpc2FibGUYFCABKAhSEXNlbGVjdGlvbnNEaXNh'
    'YmxlEiEKDG5leHRfZGlzYWJsZRgVIAEoCFILbmV4dERpc2FibGUSJgoPZWRpdF9kbV9kaXNhYm'
    'xlGBYgASgIUg1lZGl0RG1EaXNhYmxlEjAKFHNtYWxsX3dpbmRvd19kaXNhYmxlGBcgASgIUhJz'
    'bWFsbFdpbmRvd0Rpc2FibGUSIwoNc2hha2VfZGlzYWJsZRgYIAEoCFIMc2hha2VEaXNhYmxlEi'
    'gKEG91dGVyX2RtX2Rpc2FibGUYGSABKAhSDm91dGVyRG1EaXNhYmxlEigKEGlubmVyX2RtX2Rp'
    'c2FibGUYGiABKAhSDmlubmVyRG1EaXNhYmxlEi4KE2ZyZXlhX2VudGVyX2Rpc2FibGUYGyABKA'
    'hSEWZyZXlhRW50ZXJEaXNhYmxlEiMKDWRvbGJ5X2Rpc2FibGUYHCABKAhSDGRvbGJ5RGlzYWJs'
    'ZRIsChJmcmV5YV9mdWxsX2Rpc2FibGUYHSABKAhSEGZyZXlhRnVsbERpc2FibGUSNwoYc2tpcF'
    '9vcGVkX3N3aXRjaF9kaXNhYmxlGB4gASgIUhVza2lwT3BlZFN3aXRjaERpc2FibGUSMgoVcmVj'
    'b3JkX3NjcmVlbl9kaXNhYmxlGB8gASgIUhNyZWNvcmRTY3JlZW5EaXNhYmxlEjQKFmNvbG9yX2'
    '9wdGltaXplX2Rpc2FibGUYICABKAhSFGNvbG9yT3B0aW1pemVEaXNhYmxlEicKD2R1YmJpbmdf'
    'ZGlzYWJsZRghIAEoCFIOZHViYmluZ0Rpc2FibGU=');

@$core.Deprecated('Use playAbilityExtConfDescriptor instead')
const PlayAbilityExtConf$json = {
  '1': 'PlayAbilityExtConf',
  '2': [
    {
      '1': 'allow_close_subtitle',
      '3': 1,
      '4': 1,
      '5': 8,
      '10': 'allowCloseSubtitle'
    },
    {
      '1': 'freya_config',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.FreyaConfig',
      '10': 'freyaConfig'
    },
    {
      '1': 'cast_tips',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.CastTips',
      '10': 'castTips'
    },
  ],
};

/// Descriptor for `PlayAbilityExtConf`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playAbilityExtConfDescriptor = $convert.base64Decode(
    'ChJQbGF5QWJpbGl0eUV4dENvbmYSMAoUYWxsb3dfY2xvc2Vfc3VidGl0bGUYASABKAhSEmFsbG'
    '93Q2xvc2VTdWJ0aXRsZRJOCgxmcmV5YV9jb25maWcYAiABKAsyKy5iaWxpYmlsaS5wZ2MuZ2F0'
    'ZXdheS5wbGF5ZXIudjIuRnJleWFDb25maWdSC2ZyZXlhQ29uZmlnEkUKCWNhc3RfdGlwcxgDIA'
    'EoCzIoLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5DYXN0VGlwc1IIY2FzdFRpcHM=');

@$core.Deprecated('Use playDubbingInfoDescriptor instead')
const PlayDubbingInfo$json = {
  '1': 'PlayDubbingInfo',
  '2': [
    {
      '1': 'background_audio',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.AudioMaterialProto',
      '10': 'backgroundAudio'
    },
    {
      '1': 'role_audio_list',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.RoleAudioProto',
      '10': 'roleAudioList'
    },
    {'1': 'guide_text', '3': 3, '4': 1, '5': 9, '10': 'guideText'},
  ],
};

/// Descriptor for `PlayDubbingInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playDubbingInfoDescriptor = $convert.base64Decode(
    'Cg9QbGF5RHViYmluZ0luZm8SXQoQYmFja2dyb3VuZF9hdWRpbxgBIAEoCzIyLmJpbGliaWxpLn'
    'BnYy5nYXRld2F5LnBsYXllci52Mi5BdWRpb01hdGVyaWFsUHJvdG9SD2JhY2tncm91bmRBdWRp'
    'bxJWCg9yb2xlX2F1ZGlvX2xpc3QYAiADKAsyLi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZX'
    'IudjIuUm9sZUF1ZGlvUHJvdG9SDXJvbGVBdWRpb0xpc3QSHQoKZ3VpZGVfdGV4dBgDIAEoCVIJ'
    'Z3VpZGVUZXh0');

@$core.Deprecated('Use playExtInfoDescriptor instead')
const PlayExtInfo$json = {
  '1': 'PlayExtInfo',
  '2': [
    {
      '1': 'play_dubbing_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayDubbingInfo',
      '10': 'playDubbingInfo'
    },
  ],
};

/// Descriptor for `PlayExtInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playExtInfoDescriptor = $convert.base64Decode(
    'CgtQbGF5RXh0SW5mbxJbChFwbGF5X2R1YmJpbmdfaW5mbxgBIAEoCzIvLmJpbGliaWxpLnBnYy'
    '5nYXRld2F5LnBsYXllci52Mi5QbGF5RHViYmluZ0luZm9SD3BsYXlEdWJiaW5nSW5mbw==');

@$core.Deprecated('Use playListDescriptor instead')
const PlayList$json = {
  '1': 'PlayList',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 5, '10': 'seasonId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cover', '3': 3, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'link', '3': 4, '4': 1, '5': 9, '10': 'link'},
    {
      '1': 'badge_info',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.BadgeInfo',
      '10': 'badgeInfo'
    },
  ],
};

/// Descriptor for `PlayList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playListDescriptor = $convert.base64Decode(
    'CghQbGF5TGlzdBIbCglzZWFzb25faWQYASABKAVSCHNlYXNvbklkEhQKBXRpdGxlGAIgASgJUg'
    'V0aXRsZRIUCgVjb3ZlchgDIAEoCVIFY292ZXISEgoEbGluaxgEIAEoCVIEbGluaxJICgpiYWRn'
    'ZV9pbmZvGAUgASgLMikuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLkJhZGdlSW5mb1'
    'IJYmFkZ2VJbmZv');

@$core.Deprecated('Use playViewBusinessInfoDescriptor instead')
const PlayViewBusinessInfo$json = {
  '1': 'PlayViewBusinessInfo',
  '2': [
    {'1': 'is_preview', '3': 1, '4': 1, '5': 8, '10': 'isPreview'},
    {'1': 'bp', '3': 2, '4': 1, '5': 8, '10': 'bp'},
    {'1': 'marlin_token', '3': 3, '4': 1, '5': 9, '10': 'marlinToken'},
    {
      '1': 'playback_speed_color',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'playbackSpeedColor'
    },
    {
      '1': 'continue_play_info',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ContinuePlayInfo',
      '10': 'continuePlayInfo'
    },
    {
      '1': 'clip_info',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ClipInfo',
      '10': 'clipInfo'
    },
    {
      '1': 'inline_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.InlineType',
      '10': 'inlineType'
    },
    {'1': 'ep_whole_duration', '3': 8, '4': 1, '5': 5, '10': 'epWholeDuration'},
    {
      '1': 'dimension',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Dimension',
      '10': 'dimension'
    },
    {
      '1': 'quality_ext_map',
      '3': 10,
      '4': 3,
      '5': 11,
      '6':
          '.bilibili.pgc.gateway.player.v2.PlayViewBusinessInfo.QualityExtMapEntry',
      '10': 'qualityExtMap'
    },
    {
      '1': 'exp_map',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayViewBusinessInfo.ExpMapEntry',
      '10': 'expMap'
    },
    {
      '1': 'drm_tech_type',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.DrmTechType',
      '10': 'drmTechType'
    },
    {
      '1': 'limit_action_type',
      '3': 13,
      '4': 1,
      '5': 5,
      '10': 'limitActionType'
    },
    {'1': 'is_drm', '3': 14, '4': 1, '5': 8, '10': 'isDrm'},
    {
      '1': 'record_info',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.RecordInfo',
      '10': 'recordInfo'
    },
    {'1': 'vip_status', '3': 16, '4': 1, '5': 5, '10': 'vipStatus'},
    {'1': 'is_live_pre', '3': 17, '4': 1, '5': 8, '10': 'isLivePre'},
    {
      '1': 'episode_info',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.EpisodeInfo',
      '10': 'episodeInfo'
    },
    {
      '1': 'episode_advertisement_info',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.EpisodeAdvertisementInfo',
      '10': 'episodeAdvertisementInfo'
    },
    {
      '1': 'user_status',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.UserStatus',
      '10': 'userStatus'
    },
  ],
  '3': [
    PlayViewBusinessInfo_QualityExtMapEntry$json,
    PlayViewBusinessInfo_ExpMapEntry$json
  ],
};

@$core.Deprecated('Use playViewBusinessInfoDescriptor instead')
const PlayViewBusinessInfo_QualityExtMapEntry$json = {
  '1': 'QualityExtMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.QualityExtInfo',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use playViewBusinessInfoDescriptor instead')
const PlayViewBusinessInfo_ExpMapEntry$json = {
  '1': 'ExpMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `PlayViewBusinessInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playViewBusinessInfoDescriptor = $convert.base64Decode(
    'ChRQbGF5Vmlld0J1c2luZXNzSW5mbxIdCgppc19wcmV2aWV3GAEgASgIUglpc1ByZXZpZXcSDg'
    'oCYnAYAiABKAhSAmJwEiEKDG1hcmxpbl90b2tlbhgDIAEoCVILbWFybGluVG9rZW4SMAoUcGxh'
    'eWJhY2tfc3BlZWRfY29sb3IYBCABKAlSEnBsYXliYWNrU3BlZWRDb2xvchJeChJjb250aW51ZV'
    '9wbGF5X2luZm8YBSABKAsyMC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuQ29udGlu'
    'dWVQbGF5SW5mb1IQY29udGludWVQbGF5SW5mbxJFCgljbGlwX2luZm8YBiADKAsyKC5iaWxpYm'
    'lsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuQ2xpcEluZm9SCGNsaXBJbmZvEksKC2lubGluZV90'
    'eXBlGAcgASgOMiouYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLklubGluZVR5cGVSCm'
    'lubGluZVR5cGUSKgoRZXBfd2hvbGVfZHVyYXRpb24YCCABKAVSD2VwV2hvbGVEdXJhdGlvbhJH'
    'CglkaW1lbnNpb24YCSABKAsyKS5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuRGltZW'
    '5zaW9uUglkaW1lbnNpb24SbwoPcXVhbGl0eV9leHRfbWFwGAogAygLMkcuYmlsaWJpbGkucGdj'
    'LmdhdGV3YXkucGxheWVyLnYyLlBsYXlWaWV3QnVzaW5lc3NJbmZvLlF1YWxpdHlFeHRNYXBFbn'
    'RyeVINcXVhbGl0eUV4dE1hcBJZCgdleHBfbWFwGAsgAygLMkAuYmlsaWJpbGkucGdjLmdhdGV3'
    'YXkucGxheWVyLnYyLlBsYXlWaWV3QnVzaW5lc3NJbmZvLkV4cE1hcEVudHJ5UgZleHBNYXASTw'
    'oNZHJtX3RlY2hfdHlwZRgMIAEoDjIrLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5E'
    'cm1UZWNoVHlwZVILZHJtVGVjaFR5cGUSKgoRbGltaXRfYWN0aW9uX3R5cGUYDSABKAVSD2xpbW'
    'l0QWN0aW9uVHlwZRIVCgZpc19kcm0YDiABKAhSBWlzRHJtEksKC3JlY29yZF9pbmZvGA8gASgL'
    'MiouYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlJlY29yZEluZm9SCnJlY29yZEluZm'
    '8SHQoKdmlwX3N0YXR1cxgQIAEoBVIJdmlwU3RhdHVzEh4KC2lzX2xpdmVfcHJlGBEgASgIUglp'
    'c0xpdmVQcmUSTgoMZXBpc29kZV9pbmZvGBIgASgLMisuYmlsaWJpbGkucGdjLmdhdGV3YXkucG'
    'xheWVyLnYyLkVwaXNvZGVJbmZvUgtlcGlzb2RlSW5mbxJ2ChplcGlzb2RlX2FkdmVydGlzZW1l'
    'bnRfaW5mbxgTIAEoCzI4LmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5FcGlzb2RlQW'
    'R2ZXJ0aXNlbWVudEluZm9SGGVwaXNvZGVBZHZlcnRpc2VtZW50SW5mbxJLCgt1c2VyX3N0YXR1'
    'cxgUIAEoCzIqLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5Vc2VyU3RhdHVzUgp1c2'
    'VyU3RhdHVzGnAKElF1YWxpdHlFeHRNYXBFbnRyeRIQCgNrZXkYASABKAVSA2tleRJECgV2YWx1'
    'ZRgCIAEoCzIuLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5RdWFsaXR5RXh0SW5mb1'
    'IFdmFsdWU6AjgBGjkKC0V4cE1hcEVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIg'
    'ASgFUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use playViewReplyDescriptor instead')
const PlayViewReply$json = {
  '1': 'PlayViewReply',
  '2': [
    {
      '1': 'video_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.VideoInfo',
      '10': 'videoInfo'
    },
    {
      '1': 'play_conf',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayAbilityConf',
      '10': 'playConf'
    },
    {
      '1': 'business',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayViewBusinessInfo',
      '10': 'business'
    },
    {
      '1': 'event',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Event',
      '10': 'event'
    },
    {
      '1': 'view_info',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ViewInfo',
      '10': 'viewInfo'
    },
    {
      '1': 'play_ext_conf',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayAbilityExtConf',
      '10': 'playExtConf'
    },
    {
      '1': 'play_ext_info',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PlayExtInfo',
      '10': 'playExtInfo'
    },
  ],
};

/// Descriptor for `PlayViewReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playViewReplyDescriptor = $convert.base64Decode(
    'Cg1QbGF5Vmlld1JlcGx5EkgKCnZpZGVvX2luZm8YASABKAsyKS5iaWxpYmlsaS5wZ2MuZ2F0ZX'
    'dheS5wbGF5ZXIudjIuVmlkZW9JbmZvUgl2aWRlb0luZm8STAoJcGxheV9jb25mGAIgASgLMi8u'
    'YmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlBsYXlBYmlsaXR5Q29uZlIIcGxheUNvbm'
    'YSUAoIYnVzaW5lc3MYAyABKAsyNC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuUGxh'
    'eVZpZXdCdXNpbmVzc0luZm9SCGJ1c2luZXNzEjsKBWV2ZW50GAQgASgLMiUuYmlsaWJpbGkucG'
    'djLmdhdGV3YXkucGxheWVyLnYyLkV2ZW50UgVldmVudBJFCgl2aWV3X2luZm8YBSABKAsyKC5i'
    'aWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVmlld0luZm9SCHZpZXdJbmZvElYKDXBsYX'
    'lfZXh0X2NvbmYYBiABKAsyMi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuUGxheUFi'
    'aWxpdHlFeHRDb25mUgtwbGF5RXh0Q29uZhJPCg1wbGF5X2V4dF9pbmZvGAcgASgLMisuYmlsaW'
    'JpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlBsYXlFeHRJbmZvUgtwbGF5RXh0SW5mbw==');

@$core.Deprecated('Use playViewReqDescriptor instead')
const PlayViewReq$json = {
  '1': 'PlayViewReq',
  '2': [
    {'1': 'epid', '3': 1, '4': 1, '5': 3, '10': 'epid'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'qn', '3': 3, '4': 1, '5': 3, '10': 'qn'},
    {'1': 'fnver', '3': 4, '4': 1, '5': 5, '10': 'fnver'},
    {'1': 'fnval', '3': 5, '4': 1, '5': 5, '10': 'fnval'},
    {'1': 'download', '3': 6, '4': 1, '5': 13, '10': 'download'},
    {'1': 'force_host', '3': 7, '4': 1, '5': 5, '10': 'forceHost'},
    {'1': 'fourk', '3': 8, '4': 1, '5': 8, '10': 'fourk'},
    {'1': 'spmid', '3': 9, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 10, '4': 1, '5': 9, '10': 'fromSpmid'},
    {'1': 'teenagers_mode', '3': 11, '4': 1, '5': 5, '10': 'teenagersMode'},
    {
      '1': 'prefer_codec_type',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.CodeType',
      '10': 'preferCodecType'
    },
    {'1': 'is_preview', '3': 13, '4': 1, '5': 8, '10': 'isPreview'},
    {'1': 'room_id', '3': 14, '4': 1, '5': 3, '10': 'roomId'},
    {'1': 'is_need_view_info', '3': 15, '4': 1, '5': 8, '10': 'isNeedViewInfo'},
    {
      '1': 'scene_control',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.SceneControl',
      '10': 'sceneControl'
    },
    {
      '1': 'inline_scene',
      '3': 17,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.InlineScene',
      '10': 'inlineScene'
    },
    {'1': 'material_no', '3': 18, '4': 1, '5': 3, '10': 'materialNo'},
    {'1': 'security_level', '3': 19, '4': 1, '5': 5, '10': 'securityLevel'},
    {'1': 'season_id', '3': 20, '4': 1, '5': 3, '10': 'seasonId'},
    {
      '1': 'data_control',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DataControl',
      '10': 'dataControl'
    },
  ],
};

/// Descriptor for `PlayViewReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playViewReqDescriptor = $convert.base64Decode(
    'CgtQbGF5Vmlld1JlcRISCgRlcGlkGAEgASgDUgRlcGlkEhAKA2NpZBgCIAEoA1IDY2lkEg4KAn'
    'FuGAMgASgDUgJxbhIUCgVmbnZlchgEIAEoBVIFZm52ZXISFAoFZm52YWwYBSABKAVSBWZudmFs'
    'EhoKCGRvd25sb2FkGAYgASgNUghkb3dubG9hZBIdCgpmb3JjZV9ob3N0GAcgASgFUglmb3JjZU'
    'hvc3QSFAoFZm91cmsYCCABKAhSBWZvdXJrEhQKBXNwbWlkGAkgASgJUgVzcG1pZBIdCgpmcm9t'
    'X3NwbWlkGAogASgJUglmcm9tU3BtaWQSJQoOdGVlbmFnZXJzX21vZGUYCyABKAVSDXRlZW5hZ2'
    'Vyc01vZGUSVAoRcHJlZmVyX2NvZGVjX3R5cGUYDCABKA4yKC5iaWxpYmlsaS5wZ2MuZ2F0ZXdh'
    'eS5wbGF5ZXIudjIuQ29kZVR5cGVSD3ByZWZlckNvZGVjVHlwZRIdCgppc19wcmV2aWV3GA0gAS'
    'gIUglpc1ByZXZpZXcSFwoHcm9vbV9pZBgOIAEoA1IGcm9vbUlkEikKEWlzX25lZWRfdmlld19p'
    'bmZvGA8gASgIUg5pc05lZWRWaWV3SW5mbxJRCg1zY2VuZV9jb250cm9sGBAgASgLMiwuYmlsaW'
    'JpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlNjZW5lQ29udHJvbFIMc2NlbmVDb250cm9sEk4K'
    'DGlubGluZV9zY2VuZRgRIAEoDjIrLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5Jbm'
    'xpbmVTY2VuZVILaW5saW5lU2NlbmUSHwoLbWF0ZXJpYWxfbm8YEiABKANSCm1hdGVyaWFsTm8S'
    'JQoOc2VjdXJpdHlfbGV2ZWwYEyABKAVSDXNlY3VyaXR5TGV2ZWwSGwoJc2Vhc29uX2lkGBQgAS'
    'gDUghzZWFzb25JZBJOCgxkYXRhX2NvbnRyb2wYFSABKAsyKy5iaWxpYmlsaS5wZ2MuZ2F0ZXdh'
    'eS5wbGF5ZXIudjIuRGF0YUNvbnRyb2xSC2RhdGFDb250cm9s');

@$core.Deprecated('Use popWinDescriptor instead')
const PopWin$json = {
  '1': 'PopWin',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'coupon',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Coupon',
      '10': 'coupon'
    },
    {
      '1': 'button',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'button'
    },
    {'1': 'bottom_text', '3': 4, '4': 1, '5': 9, '10': 'bottomText'},
    {
      '1': 'pop_title',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'popTitle'
    },
    {
      '1': 'subtitle',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'subtitle'
    },
    {
      '1': 'bottom_desc',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'bottomDesc'
    },
    {'1': 'cover', '3': 8, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'pop_type', '3': 9, '4': 1, '5': 9, '10': 'popType'},
  ],
};

/// Descriptor for `PopWin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List popWinDescriptor = $convert.base64Decode(
    'CgZQb3BXaW4SFAoFdGl0bGUYASABKAlSBXRpdGxlEj4KBmNvdXBvbhgCIAMoCzImLmJpbGliaW'
    'xpLnBnYy5nYXRld2F5LnBsYXllci52Mi5Db3Vwb25SBmNvdXBvbhJCCgZidXR0b24YAyADKAsy'
    'Ki5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuQnV0dG9uSW5mb1IGYnV0dG9uEh8KC2'
    'JvdHRvbV90ZXh0GAQgASgJUgpib3R0b21UZXh0EkUKCXBvcF90aXRsZRgFIAEoCzIoLmJpbGli'
    'aWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5UZXh0SW5mb1IIcG9wVGl0bGUSRAoIc3VidGl0bG'
    'UYBiABKAsyKC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVGV4dEluZm9SCHN1YnRp'
    'dGxlEksKC2JvdHRvbV9kZXNjGAcgASgLMiouYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLn'
    'YyLkJ1dHRvbkluZm9SCmJvdHRvbURlc2MSFAoFY292ZXIYCCABKAlSBWNvdmVyEhkKCHBvcF90'
    'eXBlGAkgASgJUgdwb3BUeXBl');

@$core.Deprecated('Use promptBarDescriptor instead')
const PromptBar$json = {
  '1': 'PromptBar',
  '2': [
    {
      '1': 'title',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'title'
    },
    {
      '1': 'sub_title',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'subTitle'
    },
    {'1': 'sub_title_icon', '3': 3, '4': 1, '5': 9, '10': 'subTitleIcon'},
    {'1': 'bg_image', '3': 4, '4': 1, '5': 9, '10': 'bgImage'},
    {
      '1': 'bg_gradient_color',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.GradientColor',
      '10': 'bgGradientColor'
    },
    {
      '1': 'button',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'button'
    },
    {
      '1': 'report',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Report',
      '10': 'report'
    },
    {
      '1': 'full_screen_ip_icon',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'fullScreenIpIcon'
    },
    {
      '1': 'full_screen_bg_gradient_color',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.GradientColor',
      '10': 'fullScreenBgGradientColor'
    },
  ],
};

/// Descriptor for `PromptBar`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List promptBarDescriptor = $convert.base64Decode(
    'CglQcm9tcHRCYXISPgoFdGl0bGUYASABKAsyKC5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZX'
    'IudjIuVGV4dEluZm9SBXRpdGxlEkUKCXN1Yl90aXRsZRgCIAEoCzIoLmJpbGliaWxpLnBnYy5n'
    'YXRld2F5LnBsYXllci52Mi5UZXh0SW5mb1IIc3ViVGl0bGUSJAoOc3ViX3RpdGxlX2ljb24YAy'
    'ABKAlSDHN1YlRpdGxlSWNvbhIZCghiZ19pbWFnZRgEIAEoCVIHYmdJbWFnZRJZChFiZ19ncmFk'
    'aWVudF9jb2xvchgFIAEoCzItLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5HcmFkaW'
    'VudENvbG9yUg9iZ0dyYWRpZW50Q29sb3ISQgoGYnV0dG9uGAYgAygLMiouYmlsaWJpbGkucGdj'
    'LmdhdGV3YXkucGxheWVyLnYyLkJ1dHRvbkluZm9SBmJ1dHRvbhI+CgZyZXBvcnQYByABKAsyJi'
    '5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuUmVwb3J0UgZyZXBvcnQSLQoTZnVsbF9z'
    'Y3JlZW5faXBfaWNvbhgIIAEoCVIQZnVsbFNjcmVlbklwSWNvbhJvCh1mdWxsX3NjcmVlbl9iZ1'
    '9ncmFkaWVudF9jb2xvchgJIAEoCzItLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5H'
    'cmFkaWVudENvbG9yUhlmdWxsU2NyZWVuQmdHcmFkaWVudENvbG9y');

@$core.Deprecated('Use qualityExtInfoDescriptor instead')
const QualityExtInfo$json = {
  '1': 'QualityExtInfo',
  '2': [
    {'1': 'trial_support', '3': 1, '4': 1, '5': 8, '10': 'trialSupport'},
  ],
};

/// Descriptor for `QualityExtInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List qualityExtInfoDescriptor = $convert.base64Decode(
    'Cg5RdWFsaXR5RXh0SW5mbxIjCg10cmlhbF9zdXBwb3J0GAEgASgIUgx0cmlhbFN1cHBvcnQ=');

@$core.Deprecated('Use recordInfoDescriptor instead')
const RecordInfo$json = {
  '1': 'RecordInfo',
  '2': [
    {'1': 'record', '3': 1, '4': 1, '5': 9, '10': 'record'},
    {'1': 'record_icon', '3': 2, '4': 1, '5': 9, '10': 'recordIcon'},
  ],
};

/// Descriptor for `RecordInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordInfoDescriptor = $convert.base64Decode(
    'CgpSZWNvcmRJbmZvEhYKBnJlY29yZBgBIAEoCVIGcmVjb3JkEh8KC3JlY29yZF9pY29uGAIgAS'
    'gJUgpyZWNvcmRJY29u');

@$core.Deprecated('Use reportDescriptor instead')
const Report$json = {
  '1': 'Report',
  '2': [
    {'1': 'show_event_id', '3': 1, '4': 1, '5': 9, '10': 'showEventId'},
    {'1': 'click_event_id', '3': 2, '4': 1, '5': 9, '10': 'clickEventId'},
    {'1': 'extends', '3': 3, '4': 1, '5': 9, '10': 'extends'},
  ],
};

/// Descriptor for `Report`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reportDescriptor = $convert.base64Decode(
    'CgZSZXBvcnQSIgoNc2hvd19ldmVudF9pZBgBIAEoCVILc2hvd0V2ZW50SWQSJAoOY2xpY2tfZX'
    'ZlbnRfaWQYAiABKAlSDGNsaWNrRXZlbnRJZBIYCgdleHRlbmRzGAMgASgJUgdleHRlbmRz');

@$core.Deprecated('Use responseUrlDescriptor instead')
const ResponseUrl$json = {
  '1': 'ResponseUrl',
  '2': [
    {'1': 'order', '3': 1, '4': 1, '5': 13, '10': 'order'},
    {'1': 'length', '3': 2, '4': 1, '5': 4, '10': 'length'},
    {'1': 'size', '3': 3, '4': 1, '5': 4, '10': 'size'},
    {'1': 'url', '3': 4, '4': 1, '5': 9, '10': 'url'},
    {'1': 'backup_url', '3': 5, '4': 3, '5': 9, '10': 'backupUrl'},
    {'1': 'md5', '3': 6, '4': 1, '5': 9, '10': 'md5'},
  ],
};

/// Descriptor for `ResponseUrl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseUrlDescriptor = $convert.base64Decode(
    'CgtSZXNwb25zZVVybBIUCgVvcmRlchgBIAEoDVIFb3JkZXISFgoGbGVuZ3RoGAIgASgEUgZsZW'
    '5ndGgSEgoEc2l6ZRgDIAEoBFIEc2l6ZRIQCgN1cmwYBCABKAlSA3VybBIdCgpiYWNrdXBfdXJs'
    'GAUgAygJUgliYWNrdXBVcmwSEAoDbWQ1GAYgASgJUgNtZDU=');

@$core.Deprecated('Use rightsDescriptor instead')
const Rights$json = {
  '1': 'Rights',
  '2': [
    {'1': 'can_watch', '3': 1, '4': 1, '5': 5, '10': 'canWatch'},
  ],
};

/// Descriptor for `Rights`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rightsDescriptor = $convert
    .base64Decode('CgZSaWdodHMSGwoJY2FuX3dhdGNoGAEgASgFUghjYW5XYXRjaA==');

@$core.Deprecated('Use roleAudioProtoDescriptor instead')
const RoleAudioProto$json = {
  '1': 'RoleAudioProto',
  '2': [
    {'1': 'role_id', '3': 1, '4': 1, '5': 3, '10': 'roleId'},
    {'1': 'role_name', '3': 2, '4': 1, '5': 9, '10': 'roleName'},
    {'1': 'role_avatar', '3': 3, '4': 1, '5': 9, '10': 'roleAvatar'},
    {
      '1': 'audio_material_list',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.AudioMaterialProto',
      '10': 'audioMaterialList'
    },
  ],
};

/// Descriptor for `RoleAudioProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roleAudioProtoDescriptor = $convert.base64Decode(
    'Cg5Sb2xlQXVkaW9Qcm90bxIXCgdyb2xlX2lkGAEgASgDUgZyb2xlSWQSGwoJcm9sZV9uYW1lGA'
    'IgASgJUghyb2xlTmFtZRIfCgtyb2xlX2F2YXRhchgDIAEoCVIKcm9sZUF2YXRhchJiChNhdWRp'
    'b19tYXRlcmlhbF9saXN0GAQgAygLMjIuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLk'
    'F1ZGlvTWF0ZXJpYWxQcm90b1IRYXVkaW9NYXRlcmlhbExpc3Q=');

@$core.Deprecated('Use sceneControlDescriptor instead')
const SceneControl$json = {
  '1': 'SceneControl',
  '2': [
    {'1': 'fav_playlist', '3': 1, '4': 1, '5': 8, '10': 'favPlaylist'},
    {'1': 'small_window', '3': 2, '4': 1, '5': 8, '10': 'smallWindow'},
    {'1': 'pip', '3': 3, '4': 1, '5': 8, '10': 'pip'},
    {'1': 'was_he_inline', '3': 4, '4': 1, '5': 8, '10': 'wasHeInline'},
    {'1': 'is_need_trial', '3': 5, '4': 1, '5': 8, '10': 'isNeedTrial'},
  ],
};

/// Descriptor for `SceneControl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sceneControlDescriptor = $convert.base64Decode(
    'CgxTY2VuZUNvbnRyb2wSIQoMZmF2X3BsYXlsaXN0GAEgASgIUgtmYXZQbGF5bGlzdBIhCgxzbW'
    'FsbF93aW5kb3cYAiABKAhSC3NtYWxsV2luZG93EhAKA3BpcBgDIAEoCFIDcGlwEiIKDXdhc19o'
    'ZV9pbmxpbmUYBCABKAhSC3dhc0hlSW5saW5lEiIKDWlzX25lZWRfdHJpYWwYBSABKAhSC2lzTm'
    'VlZFRyaWFs');

@$core.Deprecated('Use schemeDescriptor instead')
const Scheme$json = {
  '1': 'Scheme',
  '2': [
    {
      '1': 'action_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.pgc.gateway.player.v2.Scheme.ActionType',
      '10': 'actionType'
    },
    {'1': 'toast', '3': 2, '4': 1, '5': 9, '10': 'toast'},
  ],
  '4': [Scheme_ActionType$json],
};

@$core.Deprecated('Use schemeDescriptor instead')
const Scheme_ActionType$json = {
  '1': 'ActionType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'SHOW_TOAST', '2': 1},
  ],
};

/// Descriptor for `Scheme`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemeDescriptor = $convert.base64Decode(
    'CgZTY2hlbWUSUgoLYWN0aW9uX3R5cGUYASABKA4yMS5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbG'
    'F5ZXIudjIuU2NoZW1lLkFjdGlvblR5cGVSCmFjdGlvblR5cGUSFAoFdG9hc3QYAiABKAlSBXRv'
    'YXN0IikKCkFjdGlvblR5cGUSCwoHVU5LTk9XThAAEg4KClNIT1dfVE9BU1QQAQ==');

@$core.Deprecated('Use seasonInfoDescriptor instead')
const SeasonInfo$json = {
  '1': 'SeasonInfo',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 5, '10': 'seasonId'},
    {'1': 'season_type', '3': 2, '4': 1, '5': 5, '10': 'seasonType'},
    {'1': 'season_status', '3': 3, '4': 1, '5': 5, '10': 'seasonStatus'},
    {'1': 'cover', '3': 4, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'title', '3': 5, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'rights',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Rights',
      '10': 'rights'
    },
    {'1': 'mode', '3': 7, '4': 1, '5': 5, '10': 'mode'},
  ],
};

/// Descriptor for `SeasonInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seasonInfoDescriptor = $convert.base64Decode(
    'CgpTZWFzb25JbmZvEhsKCXNlYXNvbl9pZBgBIAEoBVIIc2Vhc29uSWQSHwoLc2Vhc29uX3R5cG'
    'UYAiABKAVSCnNlYXNvblR5cGUSIwoNc2Vhc29uX3N0YXR1cxgDIAEoBVIMc2Vhc29uU3RhdHVz'
    'EhQKBWNvdmVyGAQgASgJUgVjb3ZlchIUCgV0aXRsZRgFIAEoCVIFdGl0bGUSPgoGcmlnaHRzGA'
    'YgASgLMiYuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlJpZ2h0c1IGcmlnaHRzEhIK'
    'BG1vZGUYByABKAVSBG1vZGU=');

@$core.Deprecated('Use segmentVideoDescriptor instead')
const SegmentVideo$json = {
  '1': 'SegmentVideo',
  '2': [
    {
      '1': 'segment',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ResponseUrl',
      '10': 'segment'
    },
  ],
};

/// Descriptor for `SegmentVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List segmentVideoDescriptor = $convert.base64Decode(
    'CgxTZWdtZW50VmlkZW8SRQoHc2VnbWVudBgBIAMoCzIrLmJpbGliaWxpLnBnYy5nYXRld2F5Ln'
    'BsYXllci52Mi5SZXNwb25zZVVybFIHc2VnbWVudA==');

@$core.Deprecated('Use shakeDescriptor instead')
const Shake$json = {
  '1': 'Shake',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 9, '10': 'file'},
  ],
};

/// Descriptor for `Shake`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shakeDescriptor =
    $convert.base64Decode('CgVTaGFrZRISCgRmaWxlGAEgASgJUgRmaWxl');

@$core.Deprecated('Use streamDescriptor instead')
const Stream$json = {
  '1': 'Stream',
  '2': [
    {
      '1': 'info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.StreamInfo',
      '10': 'info'
    },
    {
      '1': 'dash_video',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DashVideo',
      '9': 0,
      '10': 'dashVideo'
    },
    {
      '1': 'segment_video',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.SegmentVideo',
      '9': 0,
      '10': 'segmentVideo'
    },
  ],
  '8': [
    {'1': 'content'},
  ],
};

/// Descriptor for `Stream`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamDescriptor = $convert.base64Decode(
    'CgZTdHJlYW0SPgoEaW5mbxgBIAEoCzIqLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi'
    '5TdHJlYW1JbmZvUgRpbmZvEkoKCmRhc2hfdmlkZW8YAiABKAsyKS5iaWxpYmlsaS5wZ2MuZ2F0'
    'ZXdheS5wbGF5ZXIudjIuRGFzaFZpZGVvSABSCWRhc2hWaWRlbxJTCg1zZWdtZW50X3ZpZGVvGA'
    'MgASgLMiwuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlNlZ21lbnRWaWRlb0gAUgxz'
    'ZWdtZW50VmlkZW9CCQoHY29udGVudA==');

@$core.Deprecated('Use streamInfoDescriptor instead')
const StreamInfo$json = {
  '1': 'StreamInfo',
  '2': [
    {'1': 'quality', '3': 1, '4': 1, '5': 5, '10': 'quality'},
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'err_code', '3': 4, '4': 1, '5': 5, '10': 'errCode'},
    {
      '1': 'limit',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.StreamLimit',
      '10': 'limit'
    },
    {'1': 'need_vip', '3': 6, '4': 1, '5': 8, '10': 'needVip'},
    {'1': 'need_login', '3': 7, '4': 1, '5': 8, '10': 'needLogin'},
    {'1': 'intact', '3': 8, '4': 1, '5': 8, '10': 'intact'},
    {'1': 'attribute', '3': 10, '4': 1, '5': 3, '10': 'attribute'},
    {'1': 'new_description', '3': 11, '4': 1, '5': 9, '10': 'newDescription'},
    {'1': 'display_desc', '3': 12, '4': 1, '5': 9, '10': 'displayDesc'},
    {'1': 'superscript', '3': 13, '4': 1, '5': 9, '10': 'superscript'},
    {
      '1': 'scheme',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Scheme',
      '10': 'scheme'
    },
    {'1': 'support_drm', '3': 15, '4': 1, '5': 8, '10': 'supportDrm'},
    {'1': 'subtitle', '3': 16, '4': 1, '5': 9, '10': 'subtitle'},
  ],
};

/// Descriptor for `StreamInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamInfoDescriptor = $convert.base64Decode(
    'CgpTdHJlYW1JbmZvEhgKB3F1YWxpdHkYASABKAVSB3F1YWxpdHkSFgoGZm9ybWF0GAIgASgJUg'
    'Zmb3JtYXQSIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhkKCGVycl9jb2RlGAQg'
    'ASgFUgdlcnJDb2RlEkEKBWxpbWl0GAUgASgLMisuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheW'
    'VyLnYyLlN0cmVhbUxpbWl0UgVsaW1pdBIZCghuZWVkX3ZpcBgGIAEoCFIHbmVlZFZpcBIdCgpu'
    'ZWVkX2xvZ2luGAcgASgIUgluZWVkTG9naW4SFgoGaW50YWN0GAggASgIUgZpbnRhY3QSHAoJYX'
    'R0cmlidXRlGAogASgDUglhdHRyaWJ1dGUSJwoPbmV3X2Rlc2NyaXB0aW9uGAsgASgJUg5uZXdE'
    'ZXNjcmlwdGlvbhIhCgxkaXNwbGF5X2Rlc2MYDCABKAlSC2Rpc3BsYXlEZXNjEiAKC3N1cGVyc2'
    'NyaXB0GA0gASgJUgtzdXBlcnNjcmlwdBI+CgZzY2hlbWUYDiABKAsyJi5iaWxpYmlsaS5wZ2Mu'
    'Z2F0ZXdheS5wbGF5ZXIudjIuU2NoZW1lUgZzY2hlbWUSHwoLc3VwcG9ydF9kcm0YDyABKAhSCn'
    'N1cHBvcnREcm0SGgoIc3VidGl0bGUYECABKAlSCHN1YnRpdGxl');

@$core.Deprecated('Use streamLimitDescriptor instead')
const StreamLimit$json = {
  '1': 'StreamLimit',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'uri', '3': 2, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'msg', '3': 3, '4': 1, '5': 9, '10': 'msg'},
  ],
};

/// Descriptor for `StreamLimit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamLimitDescriptor = $convert.base64Decode(
    'CgtTdHJlYW1MaW1pdBIUCgV0aXRsZRgBIAEoCVIFdGl0bGUSEAoDdXJpGAIgASgJUgN1cmkSEA'
    'oDbXNnGAMgASgJUgNtc2c=');

@$core.Deprecated('Use taskParamDescriptor instead')
const TaskParam$json = {
  '1': 'TaskParam',
  '2': [
    {'1': 'task_type', '3': 1, '4': 1, '5': 9, '10': 'taskType'},
    {'1': 'activity_id', '3': 2, '4': 1, '5': 3, '10': 'activityId'},
    {'1': 'tips_id', '3': 3, '4': 1, '5': 3, '10': 'tipsId'},
  ],
};

/// Descriptor for `TaskParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taskParamDescriptor = $convert.base64Decode(
    'CglUYXNrUGFyYW0SGwoJdGFza190eXBlGAEgASgJUgh0YXNrVHlwZRIfCgthY3Rpdml0eV9pZB'
    'gCIAEoA1IKYWN0aXZpdHlJZBIXCgd0aXBzX2lkGAMgASgDUgZ0aXBzSWQ=');

@$core.Deprecated('Use textInfoDescriptor instead')
const TextInfo$json = {
  '1': 'TextInfo',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_color', '3': 2, '4': 1, '5': 9, '10': 'textColor'},
    {'1': 'text_color_night', '3': 3, '4': 1, '5': 9, '10': 'textColorNight'},
  ],
};

/// Descriptor for `TextInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textInfoDescriptor = $convert.base64Decode(
    'CghUZXh0SW5mbxISCgR0ZXh0GAEgASgJUgR0ZXh0Eh0KCnRleHRfY29sb3IYAiABKAlSCXRleH'
    'RDb2xvchIoChB0ZXh0X2NvbG9yX25pZ2h0GAMgASgJUg50ZXh0Q29sb3JOaWdodA==');

@$core.Deprecated('Use toastDescriptor instead')
const Toast$json = {
  '1': 'Toast',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'button',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ButtonInfo',
      '10': 'button'
    },
    {'1': 'show_style_type', '3': 3, '4': 1, '5': 5, '10': 'showStyleType'},
    {'1': 'icon', '3': 4, '4': 1, '5': 9, '10': 'icon'},
    {
      '1': 'toast_text',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.TextInfo',
      '10': 'toastText'
    },
    {
      '1': 'report',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Report',
      '10': 'report'
    },
    {
      '1': 'order_report_params',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast.OrderReportParamsEntry',
      '10': 'orderReportParams'
    },
  ],
  '3': [Toast_OrderReportParamsEntry$json],
};

@$core.Deprecated('Use toastDescriptor instead')
const Toast_OrderReportParamsEntry$json = {
  '1': 'OrderReportParamsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Toast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toastDescriptor = $convert.base64Decode(
    'CgVUb2FzdBISCgR0ZXh0GAEgASgJUgR0ZXh0EkIKBmJ1dHRvbhgCIAEoCzIqLmJpbGliaWxpLn'
    'BnYy5nYXRld2F5LnBsYXllci52Mi5CdXR0b25JbmZvUgZidXR0b24SJgoPc2hvd19zdHlsZV90'
    'eXBlGAMgASgFUg1zaG93U3R5bGVUeXBlEhIKBGljb24YBCABKAlSBGljb24SRwoKdG9hc3RfdG'
    'V4dBgFIAEoCzIoLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5UZXh0SW5mb1IJdG9h'
    'c3RUZXh0Ej4KBnJlcG9ydBgGIAEoCzImLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi'
    '5SZXBvcnRSBnJlcG9ydBJsChNvcmRlcl9yZXBvcnRfcGFyYW1zGAcgAygLMjwuYmlsaWJpbGku'
    'cGdjLmdhdGV3YXkucGxheWVyLnYyLlRvYXN0Lk9yZGVyUmVwb3J0UGFyYW1zRW50cnlSEW9yZG'
    'VyUmVwb3J0UGFyYW1zGkQKFk9yZGVyUmVwb3J0UGFyYW1zRW50cnkSEAoDa2V5GAEgASgJUgNr'
    'ZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use userStatusDescriptor instead')
const UserStatus$json = {
  '1': 'UserStatus',
  '2': [
    {'1': 'pay_check', '3': 1, '4': 1, '5': 8, '10': 'payCheck'},
    {'1': 'sponsor', '3': 2, '4': 1, '5': 8, '10': 'sponsor'},
    {
      '1': 'watch_progress',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.WatchProgress',
      '10': 'watchProgress'
    },
    {
      '1': 'aid_watch_progress',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.WatchProgress',
      '10': 'aidWatchProgress'
    },
  ],
};

/// Descriptor for `UserStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userStatusDescriptor = $convert.base64Decode(
    'CgpVc2VyU3RhdHVzEhsKCXBheV9jaGVjaxgBIAEoCFIIcGF5Q2hlY2sSGAoHc3BvbnNvchgCIA'
    'EoCFIHc3BvbnNvchJUCg53YXRjaF9wcm9ncmVzcxgDIAEoCzItLmJpbGliaWxpLnBnYy5nYXRl'
    'd2F5LnBsYXllci52Mi5XYXRjaFByb2dyZXNzUg13YXRjaFByb2dyZXNzElsKEmFpZF93YXRjaF'
    '9wcm9ncmVzcxgEIAEoCzItLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5XYXRjaFBy'
    'b2dyZXNzUhBhaWRXYXRjaFByb2dyZXNz');

@$core.Deprecated('Use videoInfoDescriptor instead')
const VideoInfo$json = {
  '1': 'VideoInfo',
  '2': [
    {'1': 'quality', '3': 1, '4': 1, '5': 13, '10': 'quality'},
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
    {'1': 'timelength', '3': 3, '4': 1, '5': 4, '10': 'timelength'},
    {'1': 'video_codecid', '3': 4, '4': 1, '5': 13, '10': 'videoCodecid'},
    {
      '1': 'stream_list',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Stream',
      '10': 'streamList'
    },
    {
      '1': 'dash_audio',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DashItem',
      '10': 'dashAudio'
    },
    {
      '1': 'dolby',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.DolbyItem',
      '10': 'dolby'
    },
  ],
};

/// Descriptor for `VideoInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoInfoDescriptor = $convert.base64Decode(
    'CglWaWRlb0luZm8SGAoHcXVhbGl0eRgBIAEoDVIHcXVhbGl0eRIWCgZmb3JtYXQYAiABKAlSBm'
    'Zvcm1hdBIeCgp0aW1lbGVuZ3RoGAMgASgEUgp0aW1lbGVuZ3RoEiMKDXZpZGVvX2NvZGVjaWQY'
    'BCABKA1SDHZpZGVvQ29kZWNpZBJHCgtzdHJlYW1fbGlzdBgFIAMoCzImLmJpbGliaWxpLnBnYy'
    '5nYXRld2F5LnBsYXllci52Mi5TdHJlYW1SCnN0cmVhbUxpc3QSRwoKZGFzaF9hdWRpbxgGIAMo'
    'CzIoLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5EYXNoSXRlbVIJZGFzaEF1ZGlvEj'
    '8KBWRvbGJ5GAcgASgLMikuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLkRvbGJ5SXRl'
    'bVIFZG9sYnk=');

@$core.Deprecated('Use viewInfoDescriptor instead')
const ViewInfo$json = {
  '1': 'ViewInfo',
  '2': [
    {
      '1': 'dialog',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Dialog',
      '10': 'dialog'
    },
    {
      '1': 'toast',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast',
      '10': 'toast'
    },
    {
      '1': 'coupon_info',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.CouponInfo',
      '10': 'couponInfo'
    },
    {
      '1': 'demand_no_pay_epids',
      '3': 4,
      '4': 3,
      '5': 3,
      '10': 'demandNoPayEpids'
    },
    {
      '1': 'end_page',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.EndPage',
      '10': 'endPage'
    },
    {
      '1': 'exp_config',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ViewInfo.ExpConfigEntry',
      '10': 'expConfig'
    },
    {
      '1': 'pop_win',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PopWin',
      '10': 'popWin'
    },
    {
      '1': 'try_watch_prompt_bar',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PromptBar',
      '10': 'tryWatchPromptBar'
    },
    {
      '1': 'pay_tip',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.PayTip',
      '10': 'payTip'
    },
    {
      '1': 'high_definition_trial_info',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.HighDefinitionTrialInfo',
      '10': 'highDefinitionTrialInfo'
    },
    {
      '1': 'ext_dialog',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ViewInfo.ExtDialogEntry',
      '10': 'extDialog'
    },
    {
      '1': 'animation',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Animation',
      '10': 'animation'
    },
    {
      '1': 'ext_toast',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.ViewInfo.ExtToastEntry',
      '10': 'extToast'
    },
  ],
  '3': [
    ViewInfo_ExpConfigEntry$json,
    ViewInfo_ExtDialogEntry$json,
    ViewInfo_ExtToastEntry$json
  ],
};

@$core.Deprecated('Use viewInfoDescriptor instead')
const ViewInfo_ExpConfigEntry$json = {
  '1': 'ExpConfigEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 8, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use viewInfoDescriptor instead')
const ViewInfo_ExtDialogEntry$json = {
  '1': 'ExtDialogEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Dialog',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use viewInfoDescriptor instead')
const ViewInfo_ExtToastEntry$json = {
  '1': 'ExtToastEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `ViewInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewInfoDescriptor = $convert.base64Decode(
    'CghWaWV3SW5mbxI+CgZkaWFsb2cYASABKAsyJi5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZX'
    'IudjIuRGlhbG9nUgZkaWFsb2cSOwoFdG9hc3QYAiABKAsyJS5iaWxpYmlsaS5wZ2MuZ2F0ZXdh'
    'eS5wbGF5ZXIudjIuVG9hc3RSBXRvYXN0EksKC2NvdXBvbl9pbmZvGAMgASgLMiouYmlsaWJpbG'
    'kucGdjLmdhdGV3YXkucGxheWVyLnYyLkNvdXBvbkluZm9SCmNvdXBvbkluZm8SLQoTZGVtYW5k'
    'X25vX3BheV9lcGlkcxgEIAMoA1IQZGVtYW5kTm9QYXlFcGlkcxJCCghlbmRfcGFnZRgFIAEoCz'
    'InLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5FbmRQYWdlUgdlbmRQYWdlElYKCmV4'
    'cF9jb25maWcYBiADKAsyNy5iaWxpYmlsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVmlld0luZm'
    '8uRXhwQ29uZmlnRW50cnlSCWV4cENvbmZpZxI/Cgdwb3Bfd2luGAcgASgLMiYuYmlsaWJpbGku'
    'cGdjLmdhdGV3YXkucGxheWVyLnYyLlBvcFdpblIGcG9wV2luEloKFHRyeV93YXRjaF9wcm9tcH'
    'RfYmFyGAggASgLMikuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlByb21wdEJhclIR'
    'dHJ5V2F0Y2hQcm9tcHRCYXISPwoHcGF5X3RpcBgJIAEoCzImLmJpbGliaWxpLnBnYy5nYXRld2'
    'F5LnBsYXllci52Mi5QYXlUaXBSBnBheVRpcBJ0ChpoaWdoX2RlZmluaXRpb25fdHJpYWxfaW5m'
    'bxgKIAEoCzI3LmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5IaWdoRGVmaW5pdGlvbl'
    'RyaWFsSW5mb1IXaGlnaERlZmluaXRpb25UcmlhbEluZm8SVgoKZXh0X2RpYWxvZxgLIAMoCzI3'
    'LmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5WaWV3SW5mby5FeHREaWFsb2dFbnRyeV'
    'IJZXh0RGlhbG9nEkcKCWFuaW1hdGlvbhgMIAEoCzIpLmJpbGliaWxpLnBnYy5nYXRld2F5LnBs'
    'YXllci52Mi5BbmltYXRpb25SCWFuaW1hdGlvbhJTCglleHRfdG9hc3QYDSADKAsyNi5iaWxpYm'
    'lsaS5wZ2MuZ2F0ZXdheS5wbGF5ZXIudjIuVmlld0luZm8uRXh0VG9hc3RFbnRyeVIIZXh0VG9h'
    'c3QaPAoORXhwQ29uZmlnRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAhSBX'
    'ZhbHVlOgI4ARpkCg5FeHREaWFsb2dFbnRyeRIQCgNrZXkYASABKAlSA2tleRI8CgV2YWx1ZRgC'
    'IAEoCzImLmJpbGliaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5EaWFsb2dSBXZhbHVlOgI4AR'
    'piCg1FeHRUb2FzdEVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EjsKBXZhbHVlGAIgASgLMiUuYmls'
    'aWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlRvYXN0UgV2YWx1ZToCOAE=');

@$core.Deprecated('Use watchProgressDescriptor instead')
const WatchProgress$json = {
  '1': 'WatchProgress',
  '2': [
    {'1': 'last_ep_id', '3': 1, '4': 1, '5': 5, '10': 'lastEpId'},
    {'1': 'last_ep_index', '3': 2, '4': 1, '5': 9, '10': 'lastEpIndex'},
    {'1': 'progress', '3': 3, '4': 1, '5': 3, '10': 'progress'},
    {'1': 'last_play_cid', '3': 4, '4': 1, '5': 3, '10': 'lastPlayCid'},
    {
      '1': 'toast',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast',
      '10': 'toast'
    },
    {
      '1': 'toast_without_time',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.pgc.gateway.player.v2.Toast',
      '10': 'toastWithoutTime'
    },
    {'1': 'last_play_aid', '3': 7, '4': 1, '5': 3, '10': 'lastPlayAid'},
  ],
};

/// Descriptor for `WatchProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchProgressDescriptor = $convert.base64Decode(
    'Cg1XYXRjaFByb2dyZXNzEhwKCmxhc3RfZXBfaWQYASABKAVSCGxhc3RFcElkEiIKDWxhc3RfZX'
    'BfaW5kZXgYAiABKAlSC2xhc3RFcEluZGV4EhoKCHByb2dyZXNzGAMgASgDUghwcm9ncmVzcxIi'
    'Cg1sYXN0X3BsYXlfY2lkGAQgASgDUgtsYXN0UGxheUNpZBI7CgV0b2FzdBgFIAEoCzIlLmJpbG'
    'liaWxpLnBnYy5nYXRld2F5LnBsYXllci52Mi5Ub2FzdFIFdG9hc3QSUwoSdG9hc3Rfd2l0aG91'
    'dF90aW1lGAYgASgLMiUuYmlsaWJpbGkucGdjLmdhdGV3YXkucGxheWVyLnYyLlRvYXN0UhB0b2'
    'FzdFdpdGhvdXRUaW1lEiIKDWxhc3RfcGxheV9haWQYByABKANSC2xhc3RQbGF5QWlk');
