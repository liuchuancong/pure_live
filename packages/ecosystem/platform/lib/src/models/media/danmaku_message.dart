// Module: lib/src/models/media/danmaku_message.dart
// Purpose: One live-room message as the source reported it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1's `DanmakuCapability`. The model lives in platform
// rather than in a danmaku package because the *source* produces it and both the overlay (ui) and the
// recorder (features) consume it; the protocol that turns a websocket into these rows belongs to the provider.
//
// Hand-written, not generated: this is somebody else's wire shape (see the `_intOrNull`/`_stringOrNull`
// tolerance below), where the rules about "what counts as stated" are the implementation and a generated
// `fromJson` would either lose them or bury them in converters nobody can read.

import 'package:equatable/equatable.dart';

import '../../support/json.dart';
import '../content/content_ref.dart';
import 'danmaku_kind.dart';

/// One message from a live room.
final class DanmakuMessage extends Equatable {
  const DanmakuMessage({
    required this.room,
    required this.kind,
    required this.text,
    required this.at,
    this.senderId,
    this.senderName,
    this.avatar,
    this.amount,
    this.itemName,
    this.itemId,
    this.color,
    this.isSelf = false,
    this.extra = const <String, Object?>{},
  });

  factory DanmakuMessage.fromJson(Map<String, Object?> json) => DanmakuMessage(
    room: ContentRef.fromJson(asObjectMap(json['room'])),
    kind: enumByName(DanmakuKind.values, json['kind'] as String?) ?? DanmakuKind.text,
    text: _stringOrNull(json['text']) ?? '',
    at: parseUtc(json['at']) ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
    senderId: _stringOrNull(json['senderId']),
    senderName: _stringOrNull(json['senderName']),
    avatar: _stringOrNull(json['avatar']),
    amount: _intOrNull(json['amount']),
    itemName: _stringOrNull(json['itemName']),
    itemId: _stringOrNull(json['itemId']),
    color: _intOrNull(json['color']),
    isSelf: json['isSelf'] as bool? ?? false,
    extra: asObjectMap(json['extra']),
  );

  final ContentRef room;
  final DanmakuKind kind;

  /// The text to show. For a gift this is the sentence ("送了火箭"), not the item name - the item is [itemName].
  final String text;

  /// When the source said it happened, in UTC. A wire row with no timestamp is stamped on receipt by the
  /// provider, so a surface that scrolls by [at] treats rows from a provider that had to guess as arriving in
  /// order rather than comparable across rooms.
  final DateTime at;

  final String? senderId;
  final String? senderName;
  final String? avatar;

  /// Gift/superchat paid amount in the platform's own unit. The unit is deliberately *not* normalised: showing
  /// it as money needs the platform's currency, and inventing a common one here would be a conversion nobody
  /// asked for.
  final int? amount;

  /// The gifted item's name/id, when [kind] is a gift.
  final String? itemName;
  final String? itemId;

  /// The sender's chosen colour as the source encoded it (0xRRGGBB), when it carries one.
  final int? color;

  /// The viewer's own message echoed back. A surface must not double-print it, and the only way to know is
  /// that the source said so.
  final bool isSelf;

  /// Whatever the platform carries that this shape cannot name (see danmaku_kind.dart's note on `system`).
  final Map<String, Object?> extra;

  /// True when this row names a paid interaction rather than speech.
  bool get isPaid => kind == DanmakuKind.gift || kind == DanmakuKind.superChat;

  /// Display name, falling back to what the source had: an anonymous wire row is still a row.
  String get displaySender => senderName?.isNotEmpty == true ? senderName! : '匿名';

  Map<String, Object?> toJson() => <String, Object?>{
    'room': room.toJson(),
    'kind': kind.name,
    'text': text,
    'at': formatUtc(at),
    if (senderId != null) 'senderId': senderId,
    if (senderName != null) 'senderName': senderName,
    if (avatar != null) 'avatar': avatar,
    if (amount != null) 'amount': amount,
    if (itemName != null) 'itemName': itemName,
    if (itemId != null) 'itemId': itemId,
    if (color != null) 'color': color,
    if (isSelf) 'isSelf': true,
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  List<Object?> get props => <Object?>[room, kind, text, at, senderId, amount, itemId, isSelf];

  @override
  String toString() =>
      'DanmakuMessage(${kind.name} $displaySender: ${text.length > 24 ? '${text.substring(0, 24)}…' : text})';
}

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

String? _stringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;
