// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_super_chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveSuperChatMessage _$LiveSuperChatMessageFromJson(Map<String, dynamic> json) => _LiveSuperChatMessage(
  messageId: json['messageId'] as String? ?? '',
  userName: json['userName'] as String? ?? '',
  faceUrl: json['faceUrl'] as String? ?? '',
  text: json['text'] as String? ?? '',
  price: json['price'] == null
      ? const SuperChatPrice()
      : SuperChatPrice.fromJson(json['price'] as Map<String, dynamic>),
  startTime: json['startTime'] == null ? null : DateTime.parse(json['startTime'] as String),
  endTime: json['endTime'] == null ? null : DateTime.parse(json['endTime'] as String),
  display: json['display'] == null
      ? const SuperChatDisplay()
      : SuperChatDisplay.fromJson(json['display'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LiveSuperChatMessageToJson(_LiveSuperChatMessage instance) => <String, dynamic>{
  'messageId': instance.messageId,
  'userName': instance.userName,
  'faceUrl': instance.faceUrl,
  'text': instance.text,
  'price': instance.price.toJson(),
  'startTime': instance.startTime?.toIso8601String(),
  'endTime': instance.endTime?.toIso8601String(),
  'display': instance.display.toJson(),
};
