// Module: lib/src/models/media/stream_option.dart
// Purpose: One choice a source offers before a stream is resolved - a quality or a line.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 names `QualityCapability` and `LineCapability`, and
// section 3 gives `resolve(ref, {quality, line})` a `SelectionRef` for each - but nothing could return the list
// to choose from, so a caller had to guess an id (ledger §5 called this "还没有定义的一块"). This is one item of
// that list; the pair of menus is `stream_options.dart`.
//
// The shape is grounded in three real platforms rather than invented here, and the differences are why the
// fields are optional instead of a single "quality" concept:
// - douyu's `multirates` gives a display name plus an **opaque request code** that is not a bitrate and cannot
//   be sorted numerically (`{quality: 20000, name: '源'}` ranks below 720p by value, above it by wording);
// - huya's lines are a **CDN list with no names**, only an ordinal the viewer can point at;
// - bilibili's guest path serves one capped stream and reports no menu at all.
// So: an id that must round-trip into `SelectionRef`, a label for the human, a default flag, and *optional*
// physical facts (bitrate/codec/size/auth) that some platforms know and some never tell.

import 'package:equatable/equatable.dart';

import '../../support/json.dart';
import '../content/paging.dart';
import 'stream_option_kind.dart';

/// One choice a source offers for [StreamOptionKind].
final class StreamOption extends Equatable {
  const StreamOption({
    required this.id,
    required this.kind,
    this.label,
    this.isDefault = false,
    this.bitrateKbps,
    this.codec,
    this.width,
    this.height,
    this.requiresAuth = false,
    this.available = true,
    this.rank,
  });

  factory StreamOption.fromJson(Map<String, Object?> json) {
    final kind = enumByName(StreamOptionKind.values, json['kind'] as String?);
    if (kind == null) {
      throw FormatException('stream_option.kind is not a known kind', json['kind']);
    }
    return StreamOption(
      id: requireString(json, 'id', 'stream_option'),
      kind: kind,
      label: json['label'] is String ? json['label']! as String : null,
      isDefault: json['isDefault'] as bool? ?? false,
      bitrateKbps: json['bitrateKbps'] is num ? (json['bitrateKbps']! as num).toInt() : null,
      codec: json['codec'] is String ? json['codec']! as String : null,
      width: json['width'] is num ? (json['width']! as num).toInt() : null,
      height: json['height'] is num ? (json['height']! as num).toInt() : null,
      requiresAuth: json['requiresAuth'] as bool? ?? false,
      available: json['available'] as bool? ?? true,
      rank: json['rank'] is num ? (json['rank']! as num).toInt() : null,
    );
  }

  /// The value to hand back to `resolve(quality:/line:)`. Opaque on purpose: for douyu this is a request code,
  /// for huya an ordinal, and the platform must not reinterpret either.
  final String id;

  final StreamOptionKind kind;

  /// What the source calls it, for a menu. Null means the source named nothing, which is honest for a CDN list
  /// and better than the platform inventing "线路2" that then disagrees with the source's own order.
  final String? label;

  /// The one the source would pick if the viewer said nothing.
  final bool isDefault;

  /// Nominal bitrate in kbps, when the source states one. Never derived from the label: see the file header on
  /// why a source's wording and a number do not order the same way.
  final int? bitrateKbps;
  final String? codec;
  final int? width;
  final int? height;

  /// Set when only a signed-in account can open this option. A menu that hides it is a lie of omission; the
  /// surface shows it marked and lets the caller decide, which is what plugin-permission.md's visibility rule
  /// asks for.
  final bool requiresAuth;

  /// False means "this option exists and currently cannot be served" (an offline 4K line). It is different
  /// from the option not being listed, because a viewer who chose it needs to hear *why* playback changed.
  final bool available;

  /// The source's own ordering weight, higher first, when it has one. [rank] is used for display order instead
  /// of [bitrateKbps] precisely because the two disagree on douyu, where "源" is the top option but its numeric
  /// code is not the largest.
  final int? rank;

  String get displayLabel => label?.isNotEmpty == true ? label! : id;

  SelectionRef get selection => SelectionRef(id, label: label);

  bool get isQuality => kind == StreamOptionKind.quality;

  bool get isLine => kind == StreamOptionKind.line;

  /// Order for a menu: the source's stated rank first (descending), then bitrate (descending), then declaration
  /// order is left to the caller's list position.
  static int byPrecedence(StreamOption a, StreamOption b) {
    final byRank = (b.rank ?? -1).compareTo(a.rank ?? -1);
    if (byRank != 0) {
      return byRank;
    }
    return (b.bitrateKbps ?? -1).compareTo(a.bitrateKbps ?? -1);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    if (label != null) 'label': label,
    if (isDefault) 'isDefault': true,
    if (bitrateKbps != null) 'bitrateKbps': bitrateKbps,
    if (codec != null) 'codec': codec,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (requiresAuth) 'requiresAuth': true,
    if (!available) 'available': false,
    if (rank != null) 'rank': rank,
  };

  @override
  List<Object?> get props => <Object?>[
    id,
    kind,
    label,
    isDefault,
    bitrateKbps,
    codec,
    width,
    height,
    requiresAuth,
    available,
    rank,
  ];
}
