// This is a generated file - do not edit.
//
// Generated from bilibili/metadata/locale/locale.proto.

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

@$core.Deprecated('Use localeDescriptor instead')
const Locale$json = {
  '1': 'Locale',
  '2': [
    {
      '1': 'c_locale',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.bilibili.metadata.locale.LocaleIds',
      '10': 'cLocale'
    },
    {
      '1': 's_locale',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.bilibili.metadata.locale.LocaleIds',
      '10': 'sLocale'
    },
    {'1': 'sim_code', '3': 3, '4': 1, '5': 9, '10': 'simCode'},
    {'1': 'timezone', '3': 4, '4': 1, '5': 9, '10': 'timezone'},
  ],
};

/// Descriptor for `Locale`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List localeDescriptor = $convert.base64Decode(
    'CgZMb2NhbGUSPgoIY19sb2NhbGUYASABKAsyIy5iaWxpYmlsaS5tZXRhZGF0YS5sb2NhbGUuTG'
    '9jYWxlSWRzUgdjTG9jYWxlEj4KCHNfbG9jYWxlGAIgASgLMiMuYmlsaWJpbGkubWV0YWRhdGEu'
    'bG9jYWxlLkxvY2FsZUlkc1IHc0xvY2FsZRIZCghzaW1fY29kZRgDIAEoCVIHc2ltQ29kZRIaCg'
    'h0aW1lem9uZRgEIAEoCVIIdGltZXpvbmU=');

@$core.Deprecated('Use localeIdsDescriptor instead')
const LocaleIds$json = {
  '1': 'LocaleIds',
  '2': [
    {'1': 'language', '3': 1, '4': 1, '5': 9, '10': 'language'},
    {'1': 'script', '3': 2, '4': 1, '5': 9, '10': 'script'},
    {'1': 'region', '3': 3, '4': 1, '5': 9, '10': 'region'},
  ],
};

/// Descriptor for `LocaleIds`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List localeIdsDescriptor = $convert.base64Decode(
    'CglMb2NhbGVJZHMSGgoIbGFuZ3VhZ2UYASABKAlSCGxhbmd1YWdlEhYKBnNjcmlwdBgCIAEoCV'
    'IGc2NyaXB0EhYKBnJlZ2lvbhgDIAEoCVIGcmVnaW9u');
