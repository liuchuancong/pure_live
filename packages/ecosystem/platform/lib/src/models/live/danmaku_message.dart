// Module: lib/src/models/live/danmaku_message.dart
// Purpose: One live-room message as the source reported it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1's `DanmakuCapability`. The model lives in platform
// rather than in a danmaku package because the *source* produces it and both the overlay (ui) and the
// recorder (features) consume it; the protocol that turns a websocket into these rows belongs to the provider.
// And it lives under `models/live/` because a danmaku is a live-room object - 点播没有一个地方会产出它。
//
// freezed 生成相等 / copyWith / toJson(§2.1);字段转换器仍留在本文件:一条弹幕缺 `text` 是"空文本的一行",
// 缺 `at` 由 provider 在收到时打时间戳,`kind` 读不出来回落到 [DanmakuKind.text]。这三条规则本身就是实现,
// 它们要待在直接读得到的地方,而不是藏在没人会去翻的默认转换器后面。

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../support/json.dart';
import '../content/content_ref/content_ref.dart';
import 'danmaku_kind.dart';

part 'danmaku_message.freezed.dart';
part 'danmaku_message.g.dart';

/// One message from a live room.
@freezed
abstract class DanmakuMessage with _$DanmakuMessage {
  const factory DanmakuMessage({
    @JsonKey(fromJson: refFromJson, toJson: refToJson) required ContentRef room,
    @JsonKey(fromJson: _kind, toJson: _kindName) required DanmakuKind kind,

    /// The text to show. For a gift this is the sentence ("送了火箭"), not the item name - the item is [itemName].
    @JsonKey(fromJson: _text) required String text,

    /// When the source said it happened, in UTC. A wire row with no timestamp is stamped on receipt by the
    /// provider, so a surface that scrolls by [at] treats rows from a provider that had to guess as arriving in
    /// order rather than comparable across rooms.
    @JsonKey(fromJson: _at, toJson: formatUtc) required DateTime at,
    @JsonKey(fromJson: _optionalText, includeIfNull: false) String? senderId,
    @JsonKey(fromJson: _optionalText, includeIfNull: false) String? senderName,
    @JsonKey(fromJson: _optionalText, includeIfNull: false) String? avatar,

    /// Gift/superchat paid amount in the platform's own unit. The unit is deliberately *not* normalised: showing
    /// it as money needs the platform's currency, and inventing a common one here would be a conversion nobody
    /// asked for.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? amount,

    /// The gifted item's name/id, when [kind] is a gift.
    @JsonKey(fromJson: _optionalText, includeIfNull: false) String? itemName,
    @JsonKey(fromJson: _optionalText, includeIfNull: false) String? itemId,

    /// The sender's chosen colour as the source encoded it (0xRRGGBB), when it carries one.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? color,

    /// The viewer's own message echoed back. A surface must not double-print it, and the only way to know is
    /// that the source said so.
    @Default(false) bool isSelf,

    /// Whatever the platform carries that this shape cannot name (see danmaku_kind.dart's note on `system`).
    @JsonKey(fromJson: _map, toJson: _mapOut) @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = _DanmakuMessage;

  const DanmakuMessage._();

  factory DanmakuMessage.fromJson(Map<String, Object?> json) => _$DanmakuMessageFromJson(json);

  /// True when this row names a paid interaction rather than speech.
  bool get isPaid => kind == DanmakuKind.gift || kind == DanmakuKind.superChat;

  /// Display name, falling back to what the source had: an anonymous wire row is still a row.
  String get displaySender => senderName?.isNotEmpty == true ? senderName! : '匿名';

  @override
  String toString() =>
      'DanmakuMessage(${kind.name} $displaySender: ${text.length > 24 ? '${text.substring(0, 24)}…' : text})';
}

DanmakuKind _kind(Object? value) => enumByName(DanmakuKind.values, value as String?) ?? DanmakuKind.text;

String _kindName(DanmakuKind value) => value.name;

String _text(Object? value) => value is String ? value : '';

String? _optionalText(Object? value) => value is String && value.isNotEmpty ? value : null;

DateTime _at(Object? value) => parseUtc(value) ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc();

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

Map<String, Object?> _map(Object? value) => asObjectMap(value);

Map<String, Object?> _mapOut(Map<String, Object?> value) => value;
