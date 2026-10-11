// Module: lib/src/models/media/stream_options.dart
// Purpose: Both stream menus one content item offers - qualities and lines - carried together.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 3 (`resolve(ref, {quality, line})`).
//
// One type for the pair because sources answer them in a single request (huya's profileRoom delivers the CDN
// list and the quality flags together), while a caller that fetched qualities and forgot lines renders a half
// menu and cannot tell the viewer the other axis exists.

import 'package:equatable/equatable.dart';

import 'stream_option.dart';
import 'stream_option_kind.dart';

/// The menus for one content item.
final class StreamOptions extends Equatable {
  const StreamOptions({this.qualities = const <StreamOption>[], this.lines = const <StreamOption>[]});

  factory StreamOptions.fromJson(Map<String, Object?> json) =>
      StreamOptions(qualities: _list(json['qualities']), lines: _list(json['lines']));

  /// Nothing known about either axis. Distinct from "the source answered and said none": an empty
  /// [StreamOptions] means the platform must not draw a picker at all.
  static const StreamOptions unknown = StreamOptions();

  final List<StreamOption> qualities;
  final List<StreamOption> lines;

  bool get isEmpty => qualities.isEmpty && lines.isEmpty;

  /// The options for one axis, in the source's own order.
  List<StreamOption> of(StreamOptionKind kind) => kind == StreamOptionKind.quality ? qualities : lines;

  /// The option the source would choose, falling back to the first listed. Null only when that axis is empty.
  StreamOption? preferred(StreamOptionKind kind) {
    final options = of(kind);
    if (options.isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.isDefault) {
        return option;
      }
    }
    return options.first;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'qualities': qualities.map((option) => option.toJson()).toList(growable: false),
    'lines': lines.map((option) => option.toJson()).toList(growable: false),
  };

  static List<StreamOption> _list(Object? raw) => <StreamOption>[
    for (final item in raw is List ? raw : const <Object?>[])
      if (item is Map) StreamOption.fromJson(Map<String, Object?>.from(item)),
  ];

  @override
  List<Object?> get props => <Object?>[qualities, lines];
}
