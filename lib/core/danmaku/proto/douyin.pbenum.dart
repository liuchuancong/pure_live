import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;
// This is a generated file - do not edit.
//
// Generated from douyin.proto.

// ignore: invalid_language_version_override
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

class CommentTypeTag extends $pb.ProtobufEnum {
  static const CommentTypeTag COMMENTTYPETAGUNKNOWN = CommentTypeTag._(
    0,
    _omitEnumNames ? '' : 'COMMENTTYPETAGUNKNOWN',
  );
  static const CommentTypeTag COMMENTTYPETAGSTAR = CommentTypeTag._(1, _omitEnumNames ? '' : 'COMMENTTYPETAGSTAR');

  static const $core.List<CommentTypeTag> values = <CommentTypeTag>[COMMENTTYPETAGUNKNOWN, COMMENTTYPETAGSTAR];

  static final $core.List<CommentTypeTag?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 1);
  static CommentTypeTag? valueOf($core.int value) => value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CommentTypeTag._(super.value, super.name);
}

const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
