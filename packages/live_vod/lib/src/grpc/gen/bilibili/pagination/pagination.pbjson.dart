// This is a generated file - do not edit.
//
// Generated from bilibili/pagination/pagination.proto.

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

@$core.Deprecated('Use feedPaginationDescriptor instead')
const FeedPagination$json = {
  '1': 'FeedPagination',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'offset', '3': 2, '4': 1, '5': 9, '10': 'offset'},
    {'1': 'is_refresh', '3': 3, '4': 1, '5': 8, '10': 'isRefresh'},
  ],
};

/// Descriptor for `FeedPagination`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feedPaginationDescriptor = $convert.base64Decode(
    'Cg5GZWVkUGFnaW5hdGlvbhIbCglwYWdlX3NpemUYASABKAVSCHBhZ2VTaXplEhYKBm9mZnNldB'
    'gCIAEoCVIGb2Zmc2V0Eh0KCmlzX3JlZnJlc2gYAyABKAhSCWlzUmVmcmVzaA==');

@$core.Deprecated('Use feedPaginationReplyDescriptor instead')
const FeedPaginationReply$json = {
  '1': 'FeedPaginationReply',
  '2': [
    {'1': 'next_offset', '3': 1, '4': 1, '5': 9, '10': 'nextOffset'},
    {'1': 'prev_offset', '3': 2, '4': 1, '5': 9, '10': 'prevOffset'},
    {'1': 'last_read_offset', '3': 3, '4': 1, '5': 9, '10': 'lastReadOffset'},
  ],
};

/// Descriptor for `FeedPaginationReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feedPaginationReplyDescriptor = $convert.base64Decode(
    'ChNGZWVkUGFnaW5hdGlvblJlcGx5Eh8KC25leHRfb2Zmc2V0GAEgASgJUgpuZXh0T2Zmc2V0Eh'
    '8KC3ByZXZfb2Zmc2V0GAIgASgJUgpwcmV2T2Zmc2V0EigKEGxhc3RfcmVhZF9vZmZzZXQYAyAB'
    'KAlSDmxhc3RSZWFkT2Zmc2V0');

@$core.Deprecated('Use paginationDescriptor instead')
const Pagination$json = {
  '1': 'Pagination',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'next', '3': 2, '4': 1, '5': 9, '10': 'next'},
  ],
};

/// Descriptor for `Pagination`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paginationDescriptor = $convert.base64Decode(
    'CgpQYWdpbmF0aW9uEhsKCXBhZ2Vfc2l6ZRgBIAEoBVIIcGFnZVNpemUSEgoEbmV4dBgCIAEoCV'
    'IEbmV4dA==');

@$core.Deprecated('Use paginationReplyDescriptor instead')
const PaginationReply$json = {
  '1': 'PaginationReply',
  '2': [
    {'1': 'next', '3': 1, '4': 1, '5': 9, '10': 'next'},
    {'1': 'prev', '3': 2, '4': 1, '5': 9, '10': 'prev'},
  ],
};

/// Descriptor for `PaginationReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paginationReplyDescriptor = $convert.base64Decode(
    'Cg9QYWdpbmF0aW9uUmVwbHkSEgoEbmV4dBgBIAEoCVIEbmV4dBISCgRwcmV2GAIgASgJUgRwcm'
    'V2');
