// This is a generated file - do not edit.
//
// Generated from bilibili/metadata/network/network.proto.

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

@$core.Deprecated('Use networkTypeDescriptor instead')
const NetworkType$json = {
  '1': 'NetworkType',
  '2': [
    {'1': 'NT_UNKNOWN', '2': 0},
    {'1': 'WIFI', '2': 1},
    {'1': 'CELLULAR', '2': 2},
    {'1': 'OFFLINE', '2': 3},
    {'1': 'OTHERNET', '2': 4},
    {'1': 'ETHERNET', '2': 5},
  ],
};

/// Descriptor for `NetworkType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List networkTypeDescriptor = $convert.base64Decode(
    'CgtOZXR3b3JrVHlwZRIOCgpOVF9VTktOT1dOEAASCAoEV0lGSRABEgwKCENFTExVTEFSEAISCw'
    'oHT0ZGTElORRADEgwKCE9USEVSTkVUEAQSDAoIRVRIRVJORVQQBQ==');

@$core.Deprecated('Use tFTypeDescriptor instead')
const TFType$json = {
  '1': 'TFType',
  '2': [
    {'1': 'TF_UNKNOWN', '2': 0},
    {'1': 'U_CARD', '2': 1},
    {'1': 'U_PKG', '2': 2},
    {'1': 'C_CARD', '2': 3},
    {'1': 'C_PKG', '2': 4},
    {'1': 'T_CARD', '2': 5},
    {'1': 'T_PKG', '2': 6},
  ],
};

/// Descriptor for `TFType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tFTypeDescriptor = $convert.base64Decode(
    'CgZURlR5cGUSDgoKVEZfVU5LTk9XThAAEgoKBlVfQ0FSRBABEgkKBVVfUEtHEAISCgoGQ19DQV'
    'JEEAMSCQoFQ19QS0cQBBIKCgZUX0NBUkQQBRIJCgVUX1BLRxAG');

@$core.Deprecated('Use networkDescriptor instead')
const Network$json = {
  '1': 'Network',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.bilibili.metadata.network.NetworkType',
      '10': 'type'
    },
    {
      '1': 'tf',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.bilibili.metadata.network.TFType',
      '10': 'tf'
    },
    {'1': 'oid', '3': 3, '4': 1, '5': 9, '10': 'oid'},
  ],
};

/// Descriptor for `Network`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkDescriptor = $convert.base64Decode(
    'CgdOZXR3b3JrEjoKBHR5cGUYASABKA4yJi5iaWxpYmlsaS5tZXRhZGF0YS5uZXR3b3JrLk5ldH'
    'dvcmtUeXBlUgR0eXBlEjEKAnRmGAIgASgOMiEuYmlsaWJpbGkubWV0YWRhdGEubmV0d29yay5U'
    'RlR5cGVSAnRmEhAKA29pZBgDIAEoCVIDb2lk');
