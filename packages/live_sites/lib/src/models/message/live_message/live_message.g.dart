// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveMessage _$LiveMessageFromJson(Map<String, dynamic> json) => _LiveMessage(
  type: $enumDecode(_$LiveMessageTypeEnumMap, json['type']),
  text: json['text'] as String? ?? '',
  sender: json['sender'] == null
      ? null
      : MessageSender.fromJson(json['sender'] as Map<String, dynamic>),
  color: json['color'] == null
      ? null
      : LiveMessageColor.fromJson(json['color'] as Map<String, dynamic>),
  payload: json['payload'],
  emotes:
      (json['emotes'] as List<dynamic>?)
          ?.map((e) => LiveEmote.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  messageId: json['messageId'] as String? ?? '',
  sentAt: json['sentAt'] == null
      ? null
      : DateTime.parse(json['sentAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  isLocal: json['isLocal'] as bool? ?? false,
  replayed: json['replayed'] as bool? ?? false,
  sourceRoomId: json['sourceRoomId'] as String? ?? '',
);

Map<String, dynamic> _$LiveMessageToJson(_LiveMessage instance) =>
    <String, dynamic>{
      'type': _$LiveMessageTypeEnumMap[instance.type]!,
      'text': instance.text,
      'sender': instance.sender,
      'color': instance.color,
      'payload': instance.payload,
      'emotes': instance.emotes,
      'messageId': instance.messageId,
      'sentAt': instance.sentAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'isLocal': instance.isLocal,
      'replayed': instance.replayed,
      'sourceRoomId': instance.sourceRoomId,
    };

const _$LiveMessageTypeEnumMap = {
  LiveMessageType.chat: 'chat',
  LiveMessageType.gift: 'gift',
  LiveMessageType.audienceUpdate: 'audienceUpdate',
  LiveMessageType.superChat: 'superChat',
  LiveMessageType.retraction: 'retraction',
  LiveMessageType.notice: 'notice',
  LiveMessageType.enter: 'enter',
  LiveMessageType.leave: 'leave',
  LiveMessageType.follow: 'follow',
  LiveMessageType.like: 'like',
  LiveMessageType.membershipJoin: 'membershipJoin',
  LiveMessageType.system: 'system',
};
