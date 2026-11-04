// This is a generated file - do not edit.
//
// Generated from bilibili/app/playerunite/v1/playerunite.proto.

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

@$core.Deprecated('Use playViewUniteReqDescriptor instead')
const PlayViewUniteReq$json = {
  '1': 'PlayViewUniteReq',
  '2': [
    {
      '1': 'vod',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.VideoVod',
      '10': 'vod'
    },
    {'1': 'spmid', '3': 2, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'from_spmid', '3': 3, '4': 1, '5': 9, '10': 'fromSpmid'},
    {
      '1': 'extra_content',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.bilibili.app.playerunite.v1.PlayViewUniteReq.ExtraContentEntry',
      '10': 'extraContent'
    },
    {'1': 'bvid', '3': 5, '4': 1, '5': 9, '10': 'bvid'},
  ],
  '3': [PlayViewUniteReq_ExtraContentEntry$json],
};

@$core.Deprecated('Use playViewUniteReqDescriptor instead')
const PlayViewUniteReq_ExtraContentEntry$json = {
  '1': 'ExtraContentEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `PlayViewUniteReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playViewUniteReqDescriptor = $convert.base64Decode(
    'ChBQbGF5Vmlld1VuaXRlUmVxEjEKA3ZvZBgBIAEoCzIfLmJpbGliaWxpLnBsYXllcnNoYXJlZC'
    '5WaWRlb1ZvZFIDdm9kEhQKBXNwbWlkGAIgASgJUgVzcG1pZBIdCgpmcm9tX3NwbWlkGAMgASgJ'
    'Uglmcm9tU3BtaWQSZAoNZXh0cmFfY29udGVudBgEIAMoCzI/LmJpbGliaWxpLmFwcC5wbGF5ZX'
    'J1bml0ZS52MS5QbGF5Vmlld1VuaXRlUmVxLkV4dHJhQ29udGVudEVudHJ5UgxleHRyYUNvbnRl'
    'bnQSEgoEYnZpZBgFIAEoCVIEYnZpZBo/ChFFeHRyYUNvbnRlbnRFbnRyeRIQCgNrZXkYASABKA'
    'lSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use playViewUniteReplyDescriptor instead')
const PlayViewUniteReply$json = {
  '1': 'PlayViewUniteReply',
  '2': [
    {
      '1': 'vod_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.VodInfo',
      '10': 'vodInfo'
    },
    {
      '1': 'play_arc_conf',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.PlayArcConf',
      '10': 'playArcConf'
    },
    {
      '1': 'play_device_conf',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.PlayDeviceConf',
      '10': 'playDeviceConf'
    },
    {
      '1': 'event',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.Event',
      '10': 'event'
    },
    {
      '1': 'supplement',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'supplement'
    },
    {
      '1': 'play_arc',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.PlayArc',
      '10': 'playArc'
    },
    {
      '1': 'qn_trial_info',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.QnTrialInfo',
      '10': 'qnTrialInfo'
    },
    {
      '1': 'history',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.History',
      '10': 'history'
    },
    {
      '1': 'view_info',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.bilibili.playershared.ViewInfo',
      '10': 'viewInfo'
    },
  ],
};

/// Descriptor for `PlayViewUniteReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playViewUniteReplyDescriptor = $convert.base64Decode(
    'ChJQbGF5Vmlld1VuaXRlUmVwbHkSOQoIdm9kX2luZm8YASABKAsyHi5iaWxpYmlsaS5wbGF5ZX'
    'JzaGFyZWQuVm9kSW5mb1IHdm9kSW5mbxJGCg1wbGF5X2FyY19jb25mGAIgASgLMiIuYmlsaWJp'
    'bGkucGxheWVyc2hhcmVkLlBsYXlBcmNDb25mUgtwbGF5QXJjQ29uZhJPChBwbGF5X2RldmljZV'
    '9jb25mGAMgASgLMiUuYmlsaWJpbGkucGxheWVyc2hhcmVkLlBsYXlEZXZpY2VDb25mUg5wbGF5'
    'RGV2aWNlQ29uZhIyCgVldmVudBgEIAEoCzIcLmJpbGliaWxpLnBsYXllcnNoYXJlZC5FdmVudF'
    'IFZXZlbnQSNAoKc3VwcGxlbWVudBgFIAEoCzIULmdvb2dsZS5wcm90b2J1Zi5BbnlSCnN1cHBs'
    'ZW1lbnQSOQoIcGxheV9hcmMYBiABKAsyHi5iaWxpYmlsaS5wbGF5ZXJzaGFyZWQuUGxheUFyY1'
    'IHcGxheUFyYxJGCg1xbl90cmlhbF9pbmZvGAcgASgLMiIuYmlsaWJpbGkucGxheWVyc2hhcmVk'
    'LlFuVHJpYWxJbmZvUgtxblRyaWFsSW5mbxI4CgdoaXN0b3J5GAggASgLMh4uYmlsaWJpbGkucG'
    'xheWVyc2hhcmVkLkhpc3RvcnlSB2hpc3RvcnkSPAoJdmlld19pbmZvGAkgASgLMh8uYmlsaWJp'
    'bGkucGxheWVyc2hhcmVkLlZpZXdJbmZvUgh2aWV3SW5mbw==');
