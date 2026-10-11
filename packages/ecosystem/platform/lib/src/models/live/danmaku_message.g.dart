// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'danmaku_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DanmakuMessage _$DanmakuMessageFromJson(Map<String, dynamic> json) =>
    _DanmakuMessage(
      room: refFromJson(json['room']),
      kind: _kind(json['kind']),
      text: _text(json['text']),
      at: _at(json['at']),
      senderId: _optionalText(json['senderId']),
      senderName: _optionalText(json['senderName']),
      avatar: _optionalText(json['avatar']),
      amount: _intOrNull(json['amount']),
      itemName: _optionalText(json['itemName']),
      itemId: _optionalText(json['itemId']),
      color: _intOrNull(json['color']),
      isSelf: json['isSelf'] as bool? ?? false,
      extra: json['extra'] == null
          ? const <String, Object?>{}
          : _map(json['extra']),
    );

Map<String, dynamic> _$DanmakuMessageToJson(_DanmakuMessage instance) =>
    <String, dynamic>{
      'room': refToJson(instance.room),
      'kind': _kindName(instance.kind),
      'text': instance.text,
      'at': formatUtc(instance.at),
      'senderId': ?instance.senderId,
      'senderName': ?instance.senderName,
      'avatar': ?instance.avatar,
      'amount': ?_intOrNull(instance.amount),
      'itemName': ?instance.itemName,
      'itemId': ?instance.itemId,
      'color': ?_intOrNull(instance.color),
      'isSelf': instance.isSelf,
      'extra': _mapOut(instance.extra),
    };
