// This is a generated file - do not edit.
//
// Generated from bilibili/playershared/playershared.proto.

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

@$core.Deprecated('Use arcTypeDescriptor instead')
const ArcType$json = {
  '1': 'ArcType',
  '2': [
    {'1': 'ARC_TYPE_NORMAL', '2': 0},
    {'1': 'ARC_TYPE_INTERACT', '2': 1},
  ],
};

/// Descriptor for `ArcType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List arcTypeDescriptor = $convert.base64Decode(
    'CgdBcmNUeXBlEhMKD0FSQ19UWVBFX05PUk1BTBAAEhUKEUFSQ19UWVBFX0lOVEVSQUNUEAE=');

@$core.Deprecated('Use bizTypeDescriptor instead')
const BizType$json = {
  '1': 'BizType',
  '2': [
    {'1': 'BIZ_TYPE_UNKNOWN', '2': 0},
    {'1': 'BIZ_TYPE_UGC', '2': 1},
    {'1': 'BIZ_TYPE_PGC', '2': 2},
    {'1': 'BIZ_TYPE_PUGV', '2': 3},
  ],
};

/// Descriptor for `BizType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List bizTypeDescriptor = $convert.base64Decode(
    'CgdCaXpUeXBlEhQKEEJJWl9UWVBFX1VOS05PV04QABIQCgxCSVpfVFlQRV9VR0MQARIQCgxCSV'
    'pfVFlQRV9QR0MQAhIRCg1CSVpfVFlQRV9QVUdWEAM=');

@$core.Deprecated('Use buttonActionDescriptor instead')
const ButtonAction$json = {
  '1': 'ButtonAction',
  '2': [
    {'1': 'BUTTON_UNKNOWN', '2': 0},
    {'1': 'PAY', '2': 1},
    {'1': 'VIP', '2': 2},
    {'1': 'PACK', '2': 3},
    {'1': 'LINK', '2': 4},
    {'1': 'COUPON', '2': 5},
    {'1': 'DEMAND', '2': 6},
    {'1': 'DEMAND_PACK', '2': 7},
    {'1': 'FOLLOW', '2': 8},
    {'1': 'APPOINTMENT', '2': 9},
    {'1': 'VIP_FREE', '2': 10},
    {'1': 'TASK', '2': 11},
    {'1': 'CHARGINGPLUS', '2': 12},
    {'1': 'BP', '2': 13},
    {'1': 'PRE_SELL', '2': 14},
  ],
};

/// Descriptor for `ButtonAction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List buttonActionDescriptor = $convert.base64Decode(
    'CgxCdXR0b25BY3Rpb24SEgoOQlVUVE9OX1VOS05PV04QABIHCgNQQVkQARIHCgNWSVAQAhIICg'
    'RQQUNLEAMSCAoETElOSxAEEgoKBkNPVVBPThAFEgoKBkRFTUFORBAGEg8KC0RFTUFORF9QQUNL'
    'EAcSCgoGRk9MTE9XEAgSDwoLQVBQT0lOVE1FTlQQCRIMCghWSVBfRlJFRRAKEggKBFRBU0sQCx'
    'IQCgxDSEFSR0lOR1BMVVMQDBIGCgJCUBANEgwKCFBSRV9TRUxMEA4=');

@$core.Deprecated('Use codeTypeDescriptor instead')
const CodeType$json = {
  '1': 'CodeType',
  '2': [
    {'1': 'NOCODE', '2': 0},
    {'1': 'CODE264', '2': 1},
    {'1': 'CODE265', '2': 2},
    {'1': 'CODEAV1', '2': 3},
  ],
};

/// Descriptor for `CodeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List codeTypeDescriptor = $convert.base64Decode(
    'CghDb2RlVHlwZRIKCgZOT0NPREUQABILCgdDT0RFMjY0EAESCwoHQ09ERTI2NRACEgsKB0NPRE'
    'VBVjEQAw==');

@$core.Deprecated('Use confTypeDescriptor instead')
const ConfType$json = {
  '1': 'ConfType',
  '2': [
    {'1': 'NoType', '2': 0},
    {'1': 'FLIPCONF', '2': 1},
    {'1': 'CASTCONF', '2': 2},
    {'1': 'FEEDBACK', '2': 3},
    {'1': 'SUBTITLE', '2': 4},
    {'1': 'PLAYBACKRATE', '2': 5},
    {'1': 'TIMEUP', '2': 6},
    {'1': 'PLAYBACKMODE', '2': 7},
    {'1': 'SCALEMODE', '2': 8},
    {'1': 'BACKGROUNDPLAY', '2': 9},
    {'1': 'LIKE', '2': 10},
    {'1': 'DISLIKE', '2': 11},
    {'1': 'COIN', '2': 12},
    {'1': 'ELEC', '2': 13},
    {'1': 'SHARE', '2': 14},
    {'1': 'SCREENSHOT', '2': 15},
    {'1': 'LOCKSCREEN', '2': 16},
    {'1': 'RECOMMEND', '2': 17},
    {'1': 'PLAYBACKSPEED', '2': 18},
    {'1': 'DEFINITION', '2': 19},
    {'1': 'SELECTIONS', '2': 20},
    {'1': 'NEXT', '2': 21},
    {'1': 'EDITDM', '2': 22},
    {'1': 'SMALLWINDOW', '2': 23},
    {'1': 'SHAKE', '2': 24},
    {'1': 'OUTERDM', '2': 25},
    {'1': 'INNERDM', '2': 26},
    {'1': 'PANORAMA', '2': 27},
    {'1': 'DOLBY', '2': 28},
    {'1': 'COLORFILTER', '2': 29},
    {'1': 'LOSSLESS', '2': 30},
    {'1': 'FREYAENTER', '2': 31},
    {'1': 'FREYAFULLENTER', '2': 32},
    {'1': 'SKIPOPED', '2': 33},
    {'1': 'RECORDSCREEN', '2': 34},
    {'1': 'DUBBING', '2': 35},
    {'1': 'LISTEN', '2': 36},
  ],
};

/// Descriptor for `ConfType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List confTypeDescriptor = $convert.base64Decode(
    'CghDb25mVHlwZRIKCgZOb1R5cGUQABIMCghGTElQQ09ORhABEgwKCENBU1RDT05GEAISDAoIRk'
    'VFREJBQ0sQAxIMCghTVUJUSVRMRRAEEhAKDFBMQVlCQUNLUkFURRAFEgoKBlRJTUVVUBAGEhAK'
    'DFBMQVlCQUNLTU9ERRAHEg0KCVNDQUxFTU9ERRAIEhIKDkJBQ0tHUk9VTkRQTEFZEAkSCAoETE'
    'lLRRAKEgsKB0RJU0xJS0UQCxIICgRDT0lOEAwSCAoERUxFQxANEgkKBVNIQVJFEA4SDgoKU0NS'
    'RUVOU0hPVBAPEg4KCkxPQ0tTQ1JFRU4QEBINCglSRUNPTU1FTkQQERIRCg1QTEFZQkFDS1NQRU'
    'VEEBISDgoKREVGSU5JVElPThATEg4KClNFTEVDVElPTlMQFBIICgRORVhUEBUSCgoGRURJVERN'
    'EBYSDwoLU01BTExXSU5ET1cQFxIJCgVTSEFLRRAYEgsKB09VVEVSRE0QGRILCgdJTk5FUkRNEB'
    'oSDAoIUEFOT1JBTUEQGxIJCgVET0xCWRAcEg8KC0NPTE9SRklMVEVSEB0SDAoITE9TU0xFU1MQ'
    'HhIOCgpGUkVZQUVOVEVSEB8SEgoORlJFWUFGVUxMRU5URVIQIBIMCghTS0lQT1BFRBAhEhAKDF'
    'JFQ09SRFNDUkVFThAiEgsKB0RVQkJJTkcQIxIKCgZMSVNURU4QJA==');

@$core.Deprecated('Use drmTechTypeDescriptor instead')
const DrmTechType$json = {
  '1': 'DrmTechType',
  '2': [
    {'1': 'UNKNOWN_DRM', '2': 0},
    {'1': 'FAIR_PLAY', '2': 1},
    {'1': 'WIDE_VINE', '2': 2},
    {'1': 'BILI_DRM', '2': 3},
  ],
};

/// Descriptor for `DrmTechType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List drmTechTypeDescriptor = $convert.base64Decode(
    'CgtEcm1UZWNoVHlwZRIPCgtVTktOT1dOX0RSTRAAEg0KCUZBSVJfUExBWRABEg0KCVdJREVfVk'
    'lORRACEgwKCEJJTElfRFJNEAM=');

@$core.Deprecated('Use effectsDescriptor instead')
const Effects$json = {
  '1': 'Effects',
  '2': [
    {'1': 'EFFECTS_UNKNOWN', '2': 0},
    {'1': 'GAUSSIAN_BLUR', '2': 1},
    {'1': 'HALF_ALPHA', '2': 2},
  ],
};

/// Descriptor for `Effects`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List effectsDescriptor = $convert.base64Decode(
    'CgdFZmZlY3RzEhMKD0VGRkVDVFNfVU5LTk9XThAAEhEKDUdBVVNTSUFOX0JMVVIQARIOCgpIQU'
    'xGX0FMUEhBEAI=');

@$core.Deprecated('Use extDataTypeDescriptor instead')
const ExtDataType$json = {
  '1': 'ExtDataType',
  '2': [
    {'1': 'EXT_DATA_TYPE_UNKNOWN', '2': 0},
    {'1': 'PLAY_LIST', '2': 1},
  ],
};

/// Descriptor for `ExtDataType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List extDataTypeDescriptor = $convert.base64Decode(
    'CgtFeHREYXRhVHlwZRIZChVFWFRfREFUQV9UWVBFX1VOS05PV04QABINCglQTEFZX0xJU1QQAQ'
    '==');

@$core.Deprecated('Use guideStyleDescriptor instead')
const GuideStyle$json = {
  '1': 'GuideStyle',
  '2': [
    {'1': 'STYLE_UNKNOWN', '2': 0},
    {'1': 'HORIZONTAL_IMAGE', '2': 1},
    {'1': 'VERTICAL_TEXT', '2': 2},
    {'1': 'SIMPLE_TEXT', '2': 3},
    {'1': 'CHARGING_TEXT', '2': 4},
  ],
};

/// Descriptor for `GuideStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List guideStyleDescriptor = $convert.base64Decode(
    'CgpHdWlkZVN0eWxlEhEKDVNUWUxFX1VOS05PV04QABIUChBIT1JJWk9OVEFMX0lNQUdFEAESEQ'
    'oNVkVSVElDQUxfVEVYVBACEg8KC1NJTVBMRV9URVhUEAMSEQoNQ0hBUkdJTkdfVEVYVBAE');

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

@$core.Deprecated('Use showStyleTypeDescriptor instead')
const ShowStyleType$json = {
  '1': 'ShowStyleType',
  '2': [
    {'1': 'SHOW_STYLE_TYPE_UNKNOWN', '2': 0},
    {'1': 'SHOW_STYLE_TYPE_ORDINARY', '2': 1},
    {'1': 'SHOW_STYLE_TYPE_RESIDENT', '2': 2},
  ],
};

/// Descriptor for `ShowStyleType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List showStyleTypeDescriptor = $convert.base64Decode(
    'Cg1TaG93U3R5bGVUeXBlEhsKF1NIT1dfU1RZTEVfVFlQRV9VTktOT1dOEAASHAoYU0hPV19TVF'
    'lMRV9UWVBFX09SRElOQVJZEAESHAoYU0hPV19TVFlMRV9UWVBFX1JFU0lERU5UEAI=');

@$core.Deprecated('Use toastTypeDescriptor instead')
const ToastType$json = {
  '1': 'ToastType',
  '2': [
    {'1': 'TOAST_TYPE_UNKNOWN', '2': 0},
    {'1': 'VIP_CONTENT_REMIND', '2': 1},
    {'1': 'VIP_DEFINITION_REMIND', '2': 2},
    {'1': 'VIP_DEFINITION_GUIDE', '2': 3},
    {'1': 'OGV_VIDEO_START_TOAST', '2': 4},
    {'1': 'CHARGING_TOAST', '2': 5},
  ],
};

/// Descriptor for `ToastType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List toastTypeDescriptor = $convert.base64Decode(
    'CglUb2FzdFR5cGUSFgoSVE9BU1RfVFlQRV9VTktOT1dOEAASFgoSVklQX0NPTlRFTlRfUkVNSU'
    '5EEAESGQoVVklQX0RFRklOSVRJT05fUkVNSU5EEAISGAoUVklQX0RFRklOSVRJT05fR1VJREUQ'
    'AxIZChVPR1ZfVklERU9fU1RBUlRfVE9BU1QQBBISCg5DSEFSR0lOR19UT0FTVBAF');

@$core.Deprecated('Use unsupportSceneDescriptor instead')
const UnsupportScene$json = {
  '1': 'UnsupportScene',
  '2': [
    {'1': 'UNKNOWN_SCENE', '2': 0},
    {'1': 'PREMIERE', '2': 1},
  ],
};

/// Descriptor for `UnsupportScene`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List unsupportSceneDescriptor = $convert.base64Decode(
    'Cg5VbnN1cHBvcnRTY2VuZRIRCg1VTktOT1dOX1NDRU5FEAASDAoIUFJFTUlFUkUQAQ==');

@$core.Deprecated('Use arcConfDescriptor instead')
const ArcConf$json = {
  '1': 'ArcConf',
  '2': [
    {'1': 'is_support', '3': 1, '4': 1, '5': 8, '10': 'isSupport'},
    {'1': 'disabled', '3': 2, '4': 1, '5': 8, '10': 'disabled'},
    {
      '1': 'extra_content',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ExtraContent',
      '10': 'extraContent'
    },
    {'1': 'unsupport_scene', '3': 4, '4': 3, '5': 5, '10': 'unsupportScene'},
  ],
};

/// Descriptor for `ArcConf`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arcConfDescriptor = $convert.base64Decode(
    'CgdBcmNDb25mEh0KCmlzX3N1cHBvcnQYASABKAhSCWlzU3VwcG9ydBIaCghkaXNhYmxlZBgCIA'
    'EoCFIIZGlzYWJsZWQSSAoNZXh0cmFfY29udGVudBgDIAEoCzIjLmJpbGliaWxpLnBsYXllcnNo'
    'YXJlZC5FeHRyYUNvbnRlbnRSDGV4dHJhQ29udGVudBInCg91bnN1cHBvcnRfc2NlbmUYBCADKA'
    'VSDnVuc3VwcG9ydFNjZW5l');

@$core.Deprecated('Use backgroundInfoDescriptor instead')
const BackgroundInfo$json = {
  '1': 'BackgroundInfo',
  '2': [
    {'1': 'drawable_color', '3': 1, '4': 1, '5': 9, '10': 'drawableColor'},
    {
      '1': 'drawable_bitmap_url',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'drawableBitmapUrl'
    },
    {'1': 'effects', '3': 3, '4': 1, '5': 5, '10': 'effects'},
  ],
};

/// Descriptor for `BackgroundInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backgroundInfoDescriptor = $convert.base64Decode(
    'Cg5CYWNrZ3JvdW5kSW5mbxIlCg5kcmF3YWJsZV9jb2xvchgBIAEoCVINZHJhd2FibGVDb2xvch'
    'IuChNkcmF3YWJsZV9iaXRtYXBfdXJsGAIgASgJUhFkcmF3YWJsZUJpdG1hcFVybBIYCgdlZmZl'
    'Y3RzGAMgASgFUgdlZmZlY3Rz');

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
      '6': '.bilibili.playershared.GradientColor',
      '10': 'bgGradientColor'
    },
    {'1': 'img', '3': 6, '4': 1, '5': 9, '10': 'img'},
  ],
};

/// Descriptor for `BadgeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List badgeInfoDescriptor = $convert.base64Decode(
    'CglCYWRnZUluZm8SEgoEdGV4dBgBIAEoCVIEdGV4dBIZCghiZ19jb2xvchgCIAEoCVIHYmdDb2'
    'xvchIkCg5iZ19jb2xvcl9uaWdodBgDIAEoCVIMYmdDb2xvck5pZ2h0Eh0KCnRleHRfY29sb3IY'
    'BCABKAlSCXRleHRDb2xvchJQChFiZ19ncmFkaWVudF9jb2xvchgFIAEoCzIkLmJpbGliaWxpLn'
    'BsYXllcnNoYXJlZC5HcmFkaWVudENvbG9yUg9iZ0dyYWRpZW50Q29sb3ISEAoDaW1nGAYgASgJ'
    'UgNpbWc=');

@$core.Deprecated('Use bottomDisplayDescriptor instead')
const BottomDisplay$json = {
  '1': 'BottomDisplay',
  '2': [
    {
      '1': 'title',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'title'
    },
    {'1': 'icon', '3': 2, '4': 1, '5': 9, '10': 'icon'},
  ],
};

/// Descriptor for `BottomDisplay`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bottomDisplayDescriptor = $convert.base64Decode(
    'Cg1Cb3R0b21EaXNwbGF5EjUKBXRpdGxlGAEgASgLMh8uYmlsaWJpbGkucGxheWVyc2hhcmVkLl'
    'RleHRJbmZvUgV0aXRsZRISCgRpY29uGAIgASgJUgRpY29u');

@$core.Deprecated('Use buttonDescriptor instead')
const Button$json = {
  '1': 'Button',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'link', '3': 2, '4': 1, '5': 9, '10': 'link'},
    {
      '1': 'report_params',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.Button.ReportParamsEntry',
      '10': 'reportParams'
    },
  ],
  '3': [Button_ReportParamsEntry$json],
};

@$core.Deprecated('Use buttonDescriptor instead')
const Button_ReportParamsEntry$json = {
  '1': 'ReportParamsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Button`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buttonDescriptor = $convert.base64Decode(
    'CgZCdXR0b24SEgoEdGV4dBgBIAEoCVIEdGV4dBISCgRsaW5rGAIgASgJUgRsaW5rElQKDXJlcG'
    '9ydF9wYXJhbXMYAyADKAsyLy5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuQnV0dG9uLlJlcG9ydFBh'
    'cmFtc0VudHJ5UgxyZXBvcnRQYXJhbXMaPwoRUmVwb3J0UGFyYW1zRW50cnkSEAoDa2V5GAEgAS'
    'gJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

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
    {
      '1': 'action_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.ButtonAction',
      '10': 'actionType'
    },
    {
      '1': 'badge_info',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.BadgeInfo',
      '10': 'badgeInfo'
    },
    {
      '1': 'report',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Report',
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
      '6': '.bilibili.playershared.TextInfo',
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
      '6': '.bilibili.playershared.GradientColor',
      '10': 'bgGradientColor'
    },
    {
      '1': 'order_report_params',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ButtonInfo.OrderReportParamsEntry',
      '10': 'orderReportParams'
    },
    {
      '1': 'task_param',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TaskParam',
      '10': 'taskParam'
    },
    {'1': 'frame_color', '3': 17, '4': 1, '5': 9, '10': 'frameColor'},
    {'1': 'icon', '3': 18, '4': 1, '5': 9, '10': 'icon'},
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
    'lnaHQSEgoEbGluaxgGIAEoCVIEbGluaxJECgthY3Rpb25fdHlwZRgHIAEoDjIjLmJpbGliaWxp'
    'LnBsYXllcnNoYXJlZC5CdXR0b25BY3Rpb25SCmFjdGlvblR5cGUSPwoKYmFkZ2VfaW5mbxgIIA'
    'EoCzIgLmJpbGliaWxpLnBsYXllcnNoYXJlZC5CYWRnZUluZm9SCWJhZGdlSW5mbxI1CgZyZXBv'
    'cnQYCSABKAsyHS5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuUmVwb3J0UgZyZXBvcnQSNgoXbGVmdF'
    '9zdHJpa2V0aHJvdWdoX3RleHQYCiABKAlSFWxlZnRTdHJpa2V0aHJvdWdoVGV4dBJJChBzaW1w'
    'bGVfdGV4dF9pbmZvGAsgASgLMh8uYmlsaWJpbGkucGxheWVyc2hhcmVkLlRleHRJbmZvUg5zaW'
    '1wbGVUZXh0SW5mbxImCg9zaW1wbGVfYmdfY29sb3IYDCABKAlSDXNpbXBsZUJnQ29sb3ISMQoV'
    'c2ltcGxlX2JnX2NvbG9yX25pZ2h0GA0gASgJUhJzaW1wbGVCZ0NvbG9yTmlnaHQSUAoRYmdfZ3'
    'JhZGllbnRfY29sb3IYDiABKAsyJC5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuR3JhZGllbnRDb2xv'
    'clIPYmdHcmFkaWVudENvbG9yEmgKE29yZGVyX3JlcG9ydF9wYXJhbXMYDyADKAsyOC5iaWxpYm'
    'lsaS5wbGF5ZXJzaGFyZWQuQnV0dG9uSW5mby5PcmRlclJlcG9ydFBhcmFtc0VudHJ5UhFvcmRl'
    'clJlcG9ydFBhcmFtcxI/Cgp0YXNrX3BhcmFtGBAgASgLMiAuYmlsaWJpbGkucGxheWVyc2hhcm'
    'VkLlRhc2tQYXJhbVIJdGFza1BhcmFtEh8KC2ZyYW1lX2NvbG9yGBEgASgJUgpmcmFtZUNvbG9y'
    'EhIKBGljb24YEiABKAlSBGljb24aRAoWT3JkZXJSZXBvcnRQYXJhbXNFbnRyeRIQCgNrZXkYAS'
    'ABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use comprehensiveToastDescriptor instead')
const ComprehensiveToast$json = {
  '1': 'ComprehensiveToast',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {
      '1': 'button',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ButtonInfo',
      '10': 'button'
    },
    {'1': 'show_style_type', '3': 3, '4': 1, '5': 5, '10': 'showStyleType'},
    {'1': 'icon', '3': 4, '4': 1, '5': 9, '10': 'icon'},
    {
      '1': 'toast_text',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'toastText'
    },
    {
      '1': 'report',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Report',
      '10': 'report'
    },
    {
      '1': 'order_report_params',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ComprehensiveToast.OrderReportParamsEntry',
      '10': 'orderReportParams'
    },
  ],
  '3': [ComprehensiveToast_OrderReportParamsEntry$json],
};

@$core.Deprecated('Use comprehensiveToastDescriptor instead')
const ComprehensiveToast_OrderReportParamsEntry$json = {
  '1': 'OrderReportParamsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ComprehensiveToast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List comprehensiveToastDescriptor = $convert.base64Decode(
    'ChJDb21wcmVoZW5zaXZlVG9hc3QSEgoEdHlwZRgBIAEoBVIEdHlwZRI5CgZidXR0b24YAiABKA'
    'syIS5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuQnV0dG9uSW5mb1IGYnV0dG9uEiYKD3Nob3dfc3R5'
    'bGVfdHlwZRgDIAEoBVINc2hvd1N0eWxlVHlwZRISCgRpY29uGAQgASgJUgRpY29uEj4KCnRvYX'
    'N0X3RleHQYBSABKAsyHy5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuVGV4dEluZm9SCXRvYXN0VGV4'
    'dBI1CgZyZXBvcnQYBiABKAsyHS5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuUmVwb3J0UgZyZXBvcn'
    'QScAoTb3JkZXJfcmVwb3J0X3BhcmFtcxgHIAMoCzJALmJpbGliaWxpLnBsYXllcnNoYXJlZC5D'
    'b21wcmVoZW5zaXZlVG9hc3QuT3JkZXJSZXBvcnRQYXJhbXNFbnRyeVIRb3JkZXJSZXBvcnRQYX'
    'JhbXMaRAoWT3JkZXJSZXBvcnRQYXJhbXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1'
    'ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use confValueDescriptor instead')
const ConfValue$json = {
  '1': 'ConfValue',
  '2': [
    {'1': 'switch_val', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'switchVal'},
    {'1': 'selected_val', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'selectedVal'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `ConfValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confValueDescriptor = $convert.base64Decode(
    'CglDb25mVmFsdWUSHwoKc3dpdGNoX3ZhbBgBIAEoBUgAUglzd2l0Y2hWYWwSIwoMc2VsZWN0ZW'
    'RfdmFsGAIgASgFSABSC3NlbGVjdGVkVmFsQgcKBXZhbHVl');

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

@$core.Deprecated('Use deviceConfDescriptor instead')
const DeviceConf$json = {
  '1': 'DeviceConf',
  '2': [
    {
      '1': 'conf_value',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ConfValue',
      '10': 'confValue'
    },
  ],
};

/// Descriptor for `DeviceConf`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceConfDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VDb25mEj8KCmNvbmZfdmFsdWUYASABKAsyIC5iaWxpYmlsaS5wbGF5ZXJzaGFyZW'
    'QuQ29uZlZhbHVlUgljb25mVmFsdWU=');

@$core.Deprecated('Use dialogDescriptor instead')
const Dialog$json = {
  '1': 'Dialog',
  '2': [
    {'1': 'style_type', '3': 1, '4': 1, '5': 5, '10': 'styleType'},
    {
      '1': 'background_info',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.BackgroundInfo',
      '10': 'backgroundInfo'
    },
    {
      '1': 'title',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'title'
    },
    {
      '1': 'subtitle',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'subtitle'
    },
    {
      '1': 'image',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ImageInfo',
      '10': 'image'
    },
    {
      '1': 'button',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ButtonInfo',
      '10': 'button'
    },
    {
      '1': 'bottom_desc',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ButtonInfo',
      '10': 'bottomDesc'
    },
    {
      '1': 'report',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Report',
      '10': 'report'
    },
    {'1': 'count_down_sec', '3': 9, '4': 1, '5': 5, '10': 'countDownSec'},
    {
      '1': 'right_bottom_desc',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'rightBottomDesc'
    },
    {
      '1': 'bottom_display',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.BottomDisplay',
      '10': 'bottomDisplay'
    },
    {
      '1': 'ext_data',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ExtData',
      '10': 'extData'
    },
    {
      '1': 'limit_action_type',
      '3': 13,
      '4': 1,
      '5': 5,
      '10': 'limitActionType'
    },
  ],
};

/// Descriptor for `Dialog`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dialogDescriptor = $convert.base64Decode(
    'CgZEaWFsb2cSHQoKc3R5bGVfdHlwZRgBIAEoBVIJc3R5bGVUeXBlEk4KD2JhY2tncm91bmRfaW'
    '5mbxgCIAEoCzIlLmJpbGliaWxpLnBsYXllcnNoYXJlZC5CYWNrZ3JvdW5kSW5mb1IOYmFja2dy'
    'b3VuZEluZm8SNQoFdGl0bGUYAyABKAsyHy5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuVGV4dEluZm'
    '9SBXRpdGxlEjsKCHN1YnRpdGxlGAQgASgLMh8uYmlsaWJpbGkucGxheWVyc2hhcmVkLlRleHRJ'
    'bmZvUghzdWJ0aXRsZRI2CgVpbWFnZRgFIAEoCzIgLmJpbGliaWxpLnBsYXllcnNoYXJlZC5JbW'
    'FnZUluZm9SBWltYWdlEjkKBmJ1dHRvbhgGIAMoCzIhLmJpbGliaWxpLnBsYXllcnNoYXJlZC5C'
    'dXR0b25JbmZvUgZidXR0b24SQgoLYm90dG9tX2Rlc2MYByABKAsyIS5iaWxpYmlsaS5wbGF5ZX'
    'JzaGFyZWQuQnV0dG9uSW5mb1IKYm90dG9tRGVzYxI1CgZyZXBvcnQYCCABKAsyHS5iaWxpYmls'
    'aS5wbGF5ZXJzaGFyZWQuUmVwb3J0UgZyZXBvcnQSJAoOY291bnRfZG93bl9zZWMYCSABKAVSDG'
    'NvdW50RG93blNlYxJLChFyaWdodF9ib3R0b21fZGVzYxgKIAEoCzIfLmJpbGliaWxpLnBsYXll'
    'cnNoYXJlZC5UZXh0SW5mb1IPcmlnaHRCb3R0b21EZXNjEksKDmJvdHRvbV9kaXNwbGF5GAsgAy'
    'gLMiQuYmlsaWJpbGkucGxheWVyc2hhcmVkLkJvdHRvbURpc3BsYXlSDWJvdHRvbURpc3BsYXkS'
    'OQoIZXh0X2RhdGEYDCABKAsyHi5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuRXh0RGF0YVIHZXh0RG'
    'F0YRIqChFsaW1pdF9hY3Rpb25fdHlwZRgNIAEoBVIPbGltaXRBY3Rpb25UeXBl');

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
      '6': '.bilibili.playershared.DolbyItem.Type',
      '10': 'type'
    },
    {
      '1': 'audio',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.DashItem',
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
    'CglEb2xieUl0ZW0SOQoEdHlwZRgBIAEoDjIlLmJpbGliaWxpLnBsYXllcnNoYXJlZC5Eb2xieU'
    'l0ZW0uVHlwZVIEdHlwZRI1CgVhdWRpbxgCIAMoCzIfLmJpbGliaWxpLnBsYXllcnNoYXJlZC5E'
    'YXNoSXRlbVIFYXVkaW8iJwoEVHlwZRIICgROT05FEAASCgoGQ09NTU9OEAESCQoFQVRNT1MQAg'
    '==');

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {
      '1': 'shake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Shake',
      '10': 'shake'
    },
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBIyCgVzaGFrZRgBIAEoCzIcLmJpbGliaWxpLnBsYXllcnNoYXJlZC5TaGFrZVIFc2'
    'hha2U=');

@$core.Deprecated('Use extDataDescriptor instead')
const ExtData$json = {
  '1': 'ExtData',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.ExtDataType',
      '10': 'type'
    },
    {
      '1': 'play_list_info',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.PlayListInfo',
      '9': 0,
      '10': 'playListInfo'
    },
  ],
  '8': [
    {'1': 'data'},
  ],
};

/// Descriptor for `ExtData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List extDataDescriptor = $convert.base64Decode(
    'CgdFeHREYXRhEjYKBHR5cGUYASABKA4yIi5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuRXh0RGF0YV'
    'R5cGVSBHR5cGUSSwoOcGxheV9saXN0X2luZm8YAiABKAsyIy5iaWxpYmlsaS5wbGF5ZXJzaGFy'
    'ZWQuUGxheUxpc3RJbmZvSABSDHBsYXlMaXN0SW5mb0IGCgRkYXRh');

@$core.Deprecated('Use extraContentDescriptor instead')
const ExtraContent$json = {
  '1': 'ExtraContent',
  '2': [
    {'1': 'disable_reason', '3': 1, '4': 1, '5': 9, '10': 'disableReason'},
    {'1': 'disable_code', '3': 2, '4': 1, '5': 3, '10': 'disableCode'},
  ],
};

/// Descriptor for `ExtraContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List extraContentDescriptor = $convert.base64Decode(
    'CgxFeHRyYUNvbnRlbnQSJQoOZGlzYWJsZV9yZWFzb24YASABKAlSDWRpc2FibGVSZWFzb24SIQ'
    'oMZGlzYWJsZV9jb2RlGAIgASgDUgtkaXNhYmxlQ29kZQ==');

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

@$core.Deprecated('Use historyDescriptor instead')
const History$json = {
  '1': 'History',
  '2': [
    {
      '1': 'current_video',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.HistoryInfo',
      '10': 'currentVideo'
    },
    {
      '1': 'related_video',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.HistoryInfo',
      '10': 'relatedVideo'
    },
  ],
};

/// Descriptor for `History`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyDescriptor = $convert.base64Decode(
    'CgdIaXN0b3J5EkcKDWN1cnJlbnRfdmlkZW8YASABKAsyIi5iaWxpYmlsaS5wbGF5ZXJzaGFyZW'
    'QuSGlzdG9yeUluZm9SDGN1cnJlbnRWaWRlbxJHCg1yZWxhdGVkX3ZpZGVvGAIgASgLMiIuYmls'
    'aWJpbGkucGxheWVyc2hhcmVkLkhpc3RvcnlJbmZvUgxyZWxhdGVkVmlkZW8=');

@$core.Deprecated('Use historyInfoDescriptor instead')
const HistoryInfo$json = {
  '1': 'HistoryInfo',
  '2': [
    {'1': 'progress', '3': 1, '4': 1, '5': 3, '10': 'progress'},
    {'1': 'last_play_cid', '3': 2, '4': 1, '5': 3, '10': 'lastPlayCid'},
    {
      '1': 'toast',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Toast',
      '10': 'toast'
    },
    {
      '1': 'toast_without_time',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Toast',
      '10': 'toastWithoutTime'
    },
    {'1': 'last_play_aid', '3': 5, '4': 1, '5': 3, '10': 'lastPlayAid'},
  ],
};

/// Descriptor for `HistoryInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyInfoDescriptor = $convert.base64Decode(
    'CgtIaXN0b3J5SW5mbxIaCghwcm9ncmVzcxgBIAEoA1IIcHJvZ3Jlc3MSIgoNbGFzdF9wbGF5X2'
    'NpZBgCIAEoA1ILbGFzdFBsYXlDaWQSMgoFdG9hc3QYAyABKAsyHC5iaWxpYmlsaS5wbGF5ZXJz'
    'aGFyZWQuVG9hc3RSBXRvYXN0EkoKEnRvYXN0X3dpdGhvdXRfdGltZRgEIAEoCzIcLmJpbGliaW'
    'xpLnBsYXllcnNoYXJlZC5Ub2FzdFIQdG9hc3RXaXRob3V0VGltZRIiCg1sYXN0X3BsYXlfYWlk'
    'GAUgASgDUgtsYXN0UGxheUFpZA==');

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
      '6': '.bilibili.playershared.Node',
      '10': 'historyNode'
    },
    {'1': 'graph_version', '3': 2, '4': 1, '5': 3, '10': 'graphVersion'},
    {'1': 'msg', '3': 3, '4': 1, '5': 9, '10': 'msg'},
    {'1': 'mark', '3': 4, '4': 1, '5': 3, '10': 'mark'},
  ],
};

/// Descriptor for `Interaction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interactionDescriptor = $convert.base64Decode(
    'CgtJbnRlcmFjdGlvbhI+CgxoaXN0b3J5X25vZGUYASABKAsyGy5iaWxpYmlsaS5wbGF5ZXJzaG'
    'FyZWQuTm9kZVILaGlzdG9yeU5vZGUSIwoNZ3JhcGhfdmVyc2lvbhgCIAEoA1IMZ3JhcGhWZXJz'
    'aW9uEhAKA21zZxgDIAEoCVIDbXNnEhIKBG1hcmsYBCABKANSBG1hcms=');

@$core.Deprecated('Use lossLessItemDescriptor instead')
const LossLessItem$json = {
  '1': 'LossLessItem',
  '2': [
    {'1': 'is_lossless_audio', '3': 1, '4': 1, '5': 8, '10': 'isLosslessAudio'},
    {
      '1': 'audio',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.DashItem',
      '10': 'audio'
    },
    {'1': 'need_vip', '3': 3, '4': 1, '5': 8, '10': 'needVip'},
  ],
};

/// Descriptor for `LossLessItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lossLessItemDescriptor = $convert.base64Decode(
    'CgxMb3NzTGVzc0l0ZW0SKgoRaXNfbG9zc2xlc3NfYXVkaW8YASABKAhSD2lzTG9zc2xlc3NBdW'
    'RpbxI1CgVhdWRpbxgCIAEoCzIfLmJpbGliaWxpLnBsYXllcnNoYXJlZC5EYXNoSXRlbVIFYXVk'
    'aW8SGQoIbmVlZF92aXAYAyABKAhSB25lZWRWaXA=');

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

@$core.Deprecated('Use playArcDescriptor instead')
const PlayArc$json = {
  '1': 'PlayArc',
  '2': [
    {
      '1': 'video_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.BizType',
      '10': 'videoType'
    },
    {'1': 'aid', '3': 2, '4': 1, '5': 4, '10': 'aid'},
    {'1': 'cid', '3': 3, '4': 1, '5': 4, '10': 'cid'},
    {
      '1': 'drm_tech_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.DrmTechType',
      '10': 'drmTechType'
    },
    {
      '1': 'arc_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.ArcType',
      '10': 'arcType'
    },
    {
      '1': 'interaction',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Interaction',
      '10': 'interaction'
    },
    {
      '1': 'dimension',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Dimension',
      '10': 'dimension'
    },
    {'1': 'duration', '3': 8, '4': 1, '5': 3, '10': 'duration'},
    {'1': 'is_preview', '3': 9, '4': 1, '5': 8, '10': 'isPreview'},
  ],
};

/// Descriptor for `PlayArc`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playArcDescriptor = $convert.base64Decode(
    'CgdQbGF5QXJjEj0KCnZpZGVvX3R5cGUYASABKA4yHi5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuQm'
    'l6VHlwZVIJdmlkZW9UeXBlEhAKA2FpZBgCIAEoBFIDYWlkEhAKA2NpZBgDIAEoBFIDY2lkEkYK'
    'DWRybV90ZWNoX3R5cGUYBCABKA4yIi5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuRHJtVGVjaFR5cG'
    'VSC2RybVRlY2hUeXBlEjkKCGFyY190eXBlGAUgASgOMh4uYmlsaWJpbGkucGxheWVyc2hhcmVk'
    'LkFyY1R5cGVSB2FyY1R5cGUSRAoLaW50ZXJhY3Rpb24YBiABKAsyIi5iaWxpYmlsaS5wbGF5ZX'
    'JzaGFyZWQuSW50ZXJhY3Rpb25SC2ludGVyYWN0aW9uEj4KCWRpbWVuc2lvbhgHIAEoCzIgLmJp'
    'bGliaWxpLnBsYXllcnNoYXJlZC5EaW1lbnNpb25SCWRpbWVuc2lvbhIaCghkdXJhdGlvbhgIIA'
    'EoA1IIZHVyYXRpb24SHQoKaXNfcHJldmlldxgJIAEoCFIJaXNQcmV2aWV3');

@$core.Deprecated('Use playArcConfDescriptor instead')
const PlayArcConf$json = {
  '1': 'PlayArcConf',
  '2': [
    {
      '1': 'arc_confs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.PlayArcConf.ArcConfsEntry',
      '10': 'arcConfs'
    },
  ],
  '3': [PlayArcConf_ArcConfsEntry$json],
};

@$core.Deprecated('Use playArcConfDescriptor instead')
const PlayArcConf_ArcConfsEntry$json = {
  '1': 'ArcConfsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ArcConf',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `PlayArcConf`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playArcConfDescriptor = $convert.base64Decode(
    'CgtQbGF5QXJjQ29uZhJNCglhcmNfY29uZnMYASADKAsyMC5iaWxpYmlsaS5wbGF5ZXJzaGFyZW'
    'QuUGxheUFyY0NvbmYuQXJjQ29uZnNFbnRyeVIIYXJjQ29uZnMaWwoNQXJjQ29uZnNFbnRyeRIQ'
    'CgNrZXkYASABKAVSA2tleRI0CgV2YWx1ZRgCIAEoCzIeLmJpbGliaWxpLnBsYXllcnNoYXJlZC'
    '5BcmNDb25mUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use playDeviceConfDescriptor instead')
const PlayDeviceConf$json = {
  '1': 'PlayDeviceConf',
  '2': [
    {
      '1': 'device_confs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.PlayDeviceConf.DeviceConfsEntry',
      '10': 'deviceConfs'
    },
  ],
  '3': [PlayDeviceConf_DeviceConfsEntry$json],
};

@$core.Deprecated('Use playDeviceConfDescriptor instead')
const PlayDeviceConf_DeviceConfsEntry$json = {
  '1': 'DeviceConfsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.DeviceConf',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `PlayDeviceConf`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playDeviceConfDescriptor = $convert.base64Decode(
    'Cg5QbGF5RGV2aWNlQ29uZhJZCgxkZXZpY2VfY29uZnMYASADKAsyNi5iaWxpYmlsaS5wbGF5ZX'
    'JzaGFyZWQuUGxheURldmljZUNvbmYuRGV2aWNlQ29uZnNFbnRyeVILZGV2aWNlQ29uZnMaYQoQ'
    'RGV2aWNlQ29uZnNFbnRyeRIQCgNrZXkYASABKAVSA2tleRI3CgV2YWx1ZRgCIAEoCzIhLmJpbG'
    'liaWxpLnBsYXllcnNoYXJlZC5EZXZpY2VDb25mUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use playListDescriptor instead')
const PlayList$json = {
  '1': 'PlayList',
  '2': [
    {'1': 'season_id', '3': 1, '4': 1, '5': 3, '10': 'seasonId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cover', '3': 3, '4': 1, '5': 9, '10': 'cover'},
    {'1': 'link', '3': 4, '4': 1, '5': 9, '10': 'link'},
    {
      '1': 'badge_info',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.BadgeInfo',
      '10': 'badgeInfo'
    },
  ],
};

/// Descriptor for `PlayList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playListDescriptor = $convert.base64Decode(
    'CghQbGF5TGlzdBIbCglzZWFzb25faWQYASABKANSCHNlYXNvbklkEhQKBXRpdGxlGAIgASgJUg'
    'V0aXRsZRIUCgVjb3ZlchgDIAEoCVIFY292ZXISEgoEbGluaxgEIAEoCVIEbGluaxI/CgpiYWRn'
    'ZV9pbmZvGAUgASgLMiAuYmlsaWJpbGkucGxheWVyc2hhcmVkLkJhZGdlSW5mb1IJYmFkZ2VJbm'
    'Zv');

@$core.Deprecated('Use playListInfoDescriptor instead')
const PlayListInfo$json = {
  '1': 'PlayListInfo',
  '2': [
    {
      '1': 'play_list',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.PlayList',
      '10': 'playList'
    },
  ],
};

/// Descriptor for `PlayListInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playListInfoDescriptor = $convert.base64Decode(
    'CgxQbGF5TGlzdEluZm8SPAoJcGxheV9saXN0GAIgAygLMh8uYmlsaWJpbGkucGxheWVyc2hhcm'
    'VkLlBsYXlMaXN0UghwbGF5TGlzdA==');

@$core.Deprecated('Use promptBarDescriptor instead')
const PromptBar$json = {
  '1': 'PromptBar',
  '2': [
    {
      '1': 'title',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'title'
    },
    {
      '1': 'subtitle',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.TextInfo',
      '10': 'subtitle'
    },
    {'1': 'sub_title_icon', '3': 3, '4': 1, '5': 9, '10': 'subTitleIcon'},
    {'1': 'bg_image', '3': 4, '4': 1, '5': 9, '10': 'bgImage'},
    {
      '1': 'bg_gradient_color',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.GradientColor',
      '10': 'bgGradientColor'
    },
    {
      '1': 'button',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ButtonInfo',
      '10': 'button'
    },
    {
      '1': 'report',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Report',
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
      '6': '.bilibili.playershared.GradientColor',
      '10': 'fullScreenBgGradientColor'
    },
  ],
};

/// Descriptor for `PromptBar`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List promptBarDescriptor = $convert.base64Decode(
    'CglQcm9tcHRCYXISNQoFdGl0bGUYASABKAsyHy5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuVGV4dE'
    'luZm9SBXRpdGxlEjsKCHN1YnRpdGxlGAIgASgLMh8uYmlsaWJpbGkucGxheWVyc2hhcmVkLlRl'
    'eHRJbmZvUghzdWJ0aXRsZRIkCg5zdWJfdGl0bGVfaWNvbhgDIAEoCVIMc3ViVGl0bGVJY29uEh'
    'kKCGJnX2ltYWdlGAQgASgJUgdiZ0ltYWdlElAKEWJnX2dyYWRpZW50X2NvbG9yGAUgASgLMiQu'
    'YmlsaWJpbGkucGxheWVyc2hhcmVkLkdyYWRpZW50Q29sb3JSD2JnR3JhZGllbnRDb2xvchI5Cg'
    'ZidXR0b24YBiADKAsyIS5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuQnV0dG9uSW5mb1IGYnV0dG9u'
    'EjUKBnJlcG9ydBgHIAEoCzIdLmJpbGliaWxpLnBsYXllcnNoYXJlZC5SZXBvcnRSBnJlcG9ydB'
    'ItChNmdWxsX3NjcmVlbl9pcF9pY29uGAggASgJUhBmdWxsU2NyZWVuSXBJY29uEmYKHWZ1bGxf'
    'c2NyZWVuX2JnX2dyYWRpZW50X2NvbG9yGAkgASgLMiQuYmlsaWJpbGkucGxheWVyc2hhcmVkLk'
    'dyYWRpZW50Q29sb3JSGWZ1bGxTY3JlZW5CZ0dyYWRpZW50Q29sb3I=');

@$core.Deprecated('Use qnTrialInfoDescriptor instead')
const QnTrialInfo$json = {
  '1': 'QnTrialInfo',
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
      '6': '.bilibili.playershared.Toast',
      '10': 'startToast'
    },
    {
      '1': 'end_toast',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Toast',
      '10': 'endToast'
    },
    {
      '1': 'quality_open_tip_btn',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Button',
      '10': 'qualityOpenTipBtn'
    },
  ],
};

/// Descriptor for `QnTrialInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List qnTrialInfoDescriptor = $convert.base64Decode(
    'CgtRblRyaWFsSW5mbxIdCgp0cmlhbF9hYmxlGAEgASgIUgl0cmlhbEFibGUSJwoPcmVtYWluaW'
    '5nX3RpbWVzGAIgASgFUg5yZW1haW5pbmdUaW1lcxIUCgVzdGFydBgDIAEoBVIFc3RhcnQSHwoL'
    'dGltZV9sZW5ndGgYBCABKAVSCnRpbWVMZW5ndGgSPQoLc3RhcnRfdG9hc3QYBSABKAsyHC5iaW'
    'xpYmlsaS5wbGF5ZXJzaGFyZWQuVG9hc3RSCnN0YXJ0VG9hc3QSOQoJZW5kX3RvYXN0GAYgASgL'
    'MhwuYmlsaWJpbGkucGxheWVyc2hhcmVkLlRvYXN0UghlbmRUb2FzdBJOChRxdWFsaXR5X29wZW'
    '5fdGlwX2J0bhgIIAEoCzIdLmJpbGliaWxpLnBsYXllcnNoYXJlZC5CdXR0b25SEXF1YWxpdHlP'
    'cGVuVGlwQnRu');

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

@$core.Deprecated('Use responseDashDescriptor instead')
const ResponseDash$json = {
  '1': 'ResponseDash',
  '2': [
    {
      '1': 'video',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.DashItem',
      '10': 'video'
    },
    {
      '1': 'audio',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.DashItem',
      '10': 'audio'
    },
  ],
};

/// Descriptor for `ResponseDash`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseDashDescriptor = $convert.base64Decode(
    'CgxSZXNwb25zZURhc2gSNQoFdmlkZW8YASADKAsyHy5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuRG'
    'FzaEl0ZW1SBXZpZGVvEjUKBWF1ZGlvGAIgAygLMh8uYmlsaWJpbGkucGxheWVyc2hhcmVkLkRh'
    'c2hJdGVtUgVhdWRpbw==');

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

@$core.Deprecated('Use schemeDescriptor instead')
const Scheme$json = {
  '1': 'Scheme',
  '2': [
    {
      '1': 'action_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.Scheme.ActionType',
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
    'CgZTY2hlbWUSSQoLYWN0aW9uX3R5cGUYASABKA4yKC5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuU2'
    'NoZW1lLkFjdGlvblR5cGVSCmFjdGlvblR5cGUSFAoFdG9hc3QYAiABKAlSBXRvYXN0IikKCkFj'
    'dGlvblR5cGUSCwoHVU5LTk9XThAAEg4KClNIT1dfVE9BU1QQAQ==');

@$core.Deprecated('Use segmentVideoDescriptor instead')
const SegmentVideo$json = {
  '1': 'SegmentVideo',
  '2': [
    {
      '1': 'segment',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ResponseUrl',
      '10': 'segment'
    },
  ],
};

/// Descriptor for `SegmentVideo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List segmentVideoDescriptor = $convert.base64Decode(
    'CgxTZWdtZW50VmlkZW8SPAoHc2VnbWVudBgBIAMoCzIiLmJpbGliaWxpLnBsYXllcnNoYXJlZC'
    '5SZXNwb25zZVVybFIHc2VnbWVudA==');

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
      '1': 'stream_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.StreamInfo',
      '10': 'streamInfo'
    },
    {
      '1': 'dash_video',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.DashVideo',
      '9': 0,
      '10': 'dashVideo'
    },
    {
      '1': 'segment_video',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.SegmentVideo',
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
    'CgZTdHJlYW0SQgoLc3RyZWFtX2luZm8YASABKAsyIS5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuU3'
    'RyZWFtSW5mb1IKc3RyZWFtSW5mbxJBCgpkYXNoX3ZpZGVvGAIgASgLMiAuYmlsaWJpbGkucGxh'
    'eWVyc2hhcmVkLkRhc2hWaWRlb0gAUglkYXNoVmlkZW8SSgoNc2VnbWVudF92aWRlbxgDIAEoCz'
    'IjLmJpbGliaWxpLnBsYXllcnNoYXJlZC5TZWdtZW50VmlkZW9IAFIMc2VnbWVudFZpZGVvQgkK'
    'B2NvbnRlbnQ=');

@$core.Deprecated('Use streamInfoDescriptor instead')
const StreamInfo$json = {
  '1': 'StreamInfo',
  '2': [
    {'1': 'quality', '3': 1, '4': 1, '5': 13, '10': 'quality'},
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'err_code', '3': 4, '4': 1, '5': 13, '10': 'errCode'},
    {
      '1': 'limit',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.StreamLimit',
      '10': 'limit'
    },
    {'1': 'need_vip', '3': 6, '4': 1, '5': 8, '10': 'needVip'},
    {'1': 'need_login', '3': 7, '4': 1, '5': 8, '10': 'needLogin'},
    {'1': 'intact', '3': 8, '4': 1, '5': 8, '10': 'intact'},
    {'1': 'no_rexcode', '3': 9, '4': 1, '5': 8, '10': 'noRexcode'},
    {'1': 'attribute', '3': 10, '4': 1, '5': 3, '10': 'attribute'},
    {'1': 'new_description', '3': 11, '4': 1, '5': 9, '10': 'newDescription'},
    {'1': 'display_desc', '3': 12, '4': 1, '5': 9, '10': 'displayDesc'},
    {'1': 'superscript', '3': 13, '4': 1, '5': 9, '10': 'superscript'},
    {'1': 'vip_free', '3': 14, '4': 1, '5': 8, '10': 'vipFree'},
    {'1': 'subtitle', '3': 15, '4': 1, '5': 9, '10': 'subtitle'},
    {
      '1': 'scheme',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Scheme',
      '10': 'scheme'
    },
    {'1': 'support_drm', '3': 17, '4': 1, '5': 8, '10': 'supportDrm'},
  ],
};

/// Descriptor for `StreamInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamInfoDescriptor = $convert.base64Decode(
    'CgpTdHJlYW1JbmZvEhgKB3F1YWxpdHkYASABKA1SB3F1YWxpdHkSFgoGZm9ybWF0GAIgASgJUg'
    'Zmb3JtYXQSIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhkKCGVycl9jb2RlGAQg'
    'ASgNUgdlcnJDb2RlEjgKBWxpbWl0GAUgASgLMiIuYmlsaWJpbGkucGxheWVyc2hhcmVkLlN0cm'
    'VhbUxpbWl0UgVsaW1pdBIZCghuZWVkX3ZpcBgGIAEoCFIHbmVlZFZpcBIdCgpuZWVkX2xvZ2lu'
    'GAcgASgIUgluZWVkTG9naW4SFgoGaW50YWN0GAggASgIUgZpbnRhY3QSHQoKbm9fcmV4Y29kZR'
    'gJIAEoCFIJbm9SZXhjb2RlEhwKCWF0dHJpYnV0ZRgKIAEoA1IJYXR0cmlidXRlEicKD25ld19k'
    'ZXNjcmlwdGlvbhgLIAEoCVIObmV3RGVzY3JpcHRpb24SIQoMZGlzcGxheV9kZXNjGAwgASgJUg'
    'tkaXNwbGF5RGVzYxIgCgtzdXBlcnNjcmlwdBgNIAEoCVILc3VwZXJzY3JpcHQSGQoIdmlwX2Zy'
    'ZWUYDiABKAhSB3ZpcEZyZWUSGgoIc3VidGl0bGUYDyABKAlSCHN1YnRpdGxlEjUKBnNjaGVtZR'
    'gQIAEoCzIdLmJpbGliaWxpLnBsYXllcnNoYXJlZC5TY2hlbWVSBnNjaGVtZRIfCgtzdXBwb3J0'
    'X2RybRgRIAEoCFIKc3VwcG9ydERybQ==');

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
      '6': '.bilibili.playershared.Button',
      '10': 'button'
    },
  ],
};

/// Descriptor for `Toast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toastDescriptor = $convert.base64Decode(
    'CgVUb2FzdBISCgR0ZXh0GAEgASgJUgR0ZXh0EjUKBmJ1dHRvbhgCIAEoCzIdLmJpbGliaWxpLn'
    'BsYXllcnNoYXJlZC5CdXR0b25SBmJ1dHRvbg==');

@$core.Deprecated('Use videoVodDescriptor instead')
const VideoVod$json = {
  '1': 'VideoVod',
  '2': [
    {'1': 'aid', '3': 1, '4': 1, '5': 3, '10': 'aid'},
    {'1': 'cid', '3': 2, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'qn', '3': 3, '4': 1, '5': 4, '10': 'qn'},
    {'1': 'fnver', '3': 4, '4': 1, '5': 5, '10': 'fnver'},
    {'1': 'fnval', '3': 5, '4': 1, '5': 5, '10': 'fnval'},
    {'1': 'download', '3': 6, '4': 1, '5': 13, '10': 'download'},
    {'1': 'force_host', '3': 7, '4': 1, '5': 5, '10': 'forceHost'},
    {'1': 'fourk', '3': 8, '4': 1, '5': 8, '10': 'fourk'},
    {
      '1': 'prefer_codec_type',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.bilibili.playershared.CodeType',
      '10': 'preferCodecType'
    },
    {'1': 'voice_balance', '3': 10, '4': 1, '5': 4, '10': 'voiceBalance'},
  ],
};

/// Descriptor for `VideoVod`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoVodDescriptor = $convert.base64Decode(
    'CghWaWRlb1ZvZBIQCgNhaWQYASABKANSA2FpZBIQCgNjaWQYAiABKANSA2NpZBIOCgJxbhgDIA'
    'EoBFICcW4SFAoFZm52ZXIYBCABKAVSBWZudmVyEhQKBWZudmFsGAUgASgFUgVmbnZhbBIaCghk'
    'b3dubG9hZBgGIAEoDVIIZG93bmxvYWQSHQoKZm9yY2VfaG9zdBgHIAEoBVIJZm9yY2VIb3N0Eh'
    'QKBWZvdXJrGAggASgIUgVmb3VyaxJLChFwcmVmZXJfY29kZWNfdHlwZRgJIAEoDjIfLmJpbGli'
    'aWxpLnBsYXllcnNoYXJlZC5Db2RlVHlwZVIPcHJlZmVyQ29kZWNUeXBlEiMKDXZvaWNlX2JhbG'
    'FuY2UYCiABKARSDHZvaWNlQmFsYW5jZQ==');

@$core.Deprecated('Use viewInfoDescriptor instead')
const ViewInfo$json = {
  '1': 'ViewInfo',
  '2': [
    {
      '1': 'dialog_map',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ViewInfo.DialogMapEntry',
      '10': 'dialogMap'
    },
    {
      '1': 'prompt_bar',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.PromptBar',
      '10': 'promptBar'
    },
    {
      '1': 'toasts',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.ComprehensiveToast',
      '10': 'toasts'
    },
  ],
  '3': [ViewInfo_DialogMapEntry$json],
};

@$core.Deprecated('Use viewInfoDescriptor instead')
const ViewInfo_DialogMapEntry$json = {
  '1': 'DialogMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Dialog',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `ViewInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewInfoDescriptor = $convert.base64Decode(
    'CghWaWV3SW5mbxJNCgpkaWFsb2dfbWFwGAEgAygLMi4uYmlsaWJpbGkucGxheWVyc2hhcmVkLl'
    'ZpZXdJbmZvLkRpYWxvZ01hcEVudHJ5UglkaWFsb2dNYXASPwoKcHJvbXB0X2JhchgCIAEoCzIg'
    'LmJpbGliaWxpLnBsYXllcnNoYXJlZC5Qcm9tcHRCYXJSCXByb21wdEJhchJBCgZ0b2FzdHMYAy'
    'ADKAsyKS5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuQ29tcHJlaGVuc2l2ZVRvYXN0UgZ0b2FzdHMa'
    'WwoORGlhbG9nTWFwRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSMwoFdmFsdWUYAiABKAsyHS5iaW'
    'xpYmlsaS5wbGF5ZXJzaGFyZWQuRGlhbG9nUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use vodInfoDescriptor instead')
const VodInfo$json = {
  '1': 'VodInfo',
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
      '6': '.bilibili.playershared.Stream',
      '10': 'streamList'
    },
    {
      '1': 'dash_audio',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.bilibili.playershared.DashItem',
      '10': 'dashAudio'
    },
    {
      '1': 'dolby',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.DolbyItem',
      '10': 'dolby'
    },
    {
      '1': 'volume',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.VolumeInfo',
      '10': 'volume'
    },
    {
      '1': 'loss_less_item',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.LossLessItem',
      '10': 'lossLessItem'
    },
    {'1': 'support_project', '3': 10, '4': 1, '5': 8, '10': 'supportProject'},
  ],
};

/// Descriptor for `VodInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vodInfoDescriptor = $convert.base64Decode(
    'CgdWb2RJbmZvEhgKB3F1YWxpdHkYASABKA1SB3F1YWxpdHkSFgoGZm9ybWF0GAIgASgJUgZmb3'
    'JtYXQSHgoKdGltZWxlbmd0aBgDIAEoBFIKdGltZWxlbmd0aBIjCg12aWRlb19jb2RlY2lkGAQg'
    'ASgNUgx2aWRlb0NvZGVjaWQSPgoLc3RyZWFtX2xpc3QYBSADKAsyHS5iaWxpYmlsaS5wbGF5ZX'
    'JzaGFyZWQuU3RyZWFtUgpzdHJlYW1MaXN0Ej4KCmRhc2hfYXVkaW8YBiADKAsyHy5iaWxpYmls'
    'aS5wbGF5ZXJzaGFyZWQuRGFzaEl0ZW1SCWRhc2hBdWRpbxI2CgVkb2xieRgHIAEoCzIgLmJpbG'
    'liaWxpLnBsYXllcnNoYXJlZC5Eb2xieUl0ZW1SBWRvbGJ5EjkKBnZvbHVtZRgIIAEoCzIhLmJp'
    'bGliaWxpLnBsYXllcnNoYXJlZC5Wb2x1bWVJbmZvUgZ2b2x1bWUSSQoObG9zc19sZXNzX2l0ZW'
    '0YCSABKAsyIy5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuTG9zc0xlc3NJdGVtUgxsb3NzTGVzc0l0'
    'ZW0SJwoPc3VwcG9ydF9wcm9qZWN0GAogASgIUg5zdXBwb3J0UHJvamVjdA==');

@$core.Deprecated('Use volumeInfoDescriptor instead')
const VolumeInfo$json = {
  '1': 'VolumeInfo',
  '2': [
    {'1': 'measured_i', '3': 1, '4': 1, '5': 1, '10': 'measuredI'},
    {'1': 'measured_lra', '3': 2, '4': 1, '5': 1, '10': 'measuredLra'},
    {'1': 'measured_tp', '3': 3, '4': 1, '5': 1, '10': 'measuredTp'},
    {
      '1': 'measured_threshold',
      '3': 4,
      '4': 1,
      '5': 1,
      '10': 'measuredThreshold'
    },
    {'1': 'target_offset', '3': 5, '4': 1, '5': 1, '10': 'targetOffset'},
    {'1': 'target_i', '3': 6, '4': 1, '5': 1, '10': 'targetI'},
    {'1': 'target_tp', '3': 7, '4': 1, '5': 1, '10': 'targetTp'},
  ],
};

/// Descriptor for `VolumeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List volumeInfoDescriptor = $convert.base64Decode(
    'CgpWb2x1bWVJbmZvEh0KCm1lYXN1cmVkX2kYASABKAFSCW1lYXN1cmVkSRIhCgxtZWFzdXJlZF'
    '9scmEYAiABKAFSC21lYXN1cmVkTHJhEh8KC21lYXN1cmVkX3RwGAMgASgBUgptZWFzdXJlZFRw'
    'Ei0KEm1lYXN1cmVkX3RocmVzaG9sZBgEIAEoAVIRbWVhc3VyZWRUaHJlc2hvbGQSIwoNdGFyZ2'
    'V0X29mZnNldBgFIAEoAVIMdGFyZ2V0T2Zmc2V0EhkKCHRhcmdldF9pGAYgASgBUgd0YXJnZXRJ'
    'EhsKCXRhcmdldF90cBgHIAEoAVIIdGFyZ2V0VHA=');
