import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pure_live/core/common/core_log.dart';

enum LiveMessageType {
  /// 聊天
  chat,

  /// 礼物,暂时不支持
  gift,

  /// 在线人数
  online,

  /// 醒目留言
  superChat,
}

class LiveMessage {
  /// 消息类型
  final LiveMessageType type;

  /// 用户名
  final String userName;

  /// 信息
  String message;

  /// 数据
  /// 单Type=Online时，Data为人气值(long)
  final dynamic data;

  /// 弹幕颜色
  final Color color;

  /// 用户等级
  final String userLevel;

  /// 粉丝等级
  final String fansLevel;
  /// 粉丝牌子名
  final String fansName;

  LiveMessage({
    required this.type,
    required this.userName,
    required this.message,
    this.data,
    required this.color,
    this.userLevel = "",
    this.fansLevel = "",
    this.fansName = "",
  });
}

class LiveMessageColor {
  final int r, g, b;

  LiveMessageColor(this.r, this.g, this.b);

  static LiveMessageColor get white => LiveMessageColor(255, 255, 255);

  static LiveMessageColor numberToColor(int intColor) {
    var obj = intColor.toRadixString(16);

    LiveMessageColor color = LiveMessageColor.white;
    if (obj.length == 4) {
      obj = "00$obj";
    }
    if (obj.length == 6) {
      var R = int.parse(obj.substring(0, 2), radix: 16);
      var G = int.parse(obj.substring(2, 4), radix: 16);
      var B = int.parse(obj.substring(4, 6), radix: 16);

      color = LiveMessageColor(R, G, B);
    }
    if (obj.length == 8) {
      var R = int.parse(obj.substring(2, 4), radix: 16);
      var G = int.parse(obj.substring(4, 6), radix: 16);
      var B = int.parse(obj.substring(6, 8), radix: 16);
      //var A = int.parse(obj.substring(0, 2), radix: 16);
      color = LiveMessageColor(R, G, B);
    }

    return color;
  }

  /// 16进制颜色转换 #FFFFFF
  static LiveMessageColor hexToColor(String color) {
    var messageColor = LiveMessageColor.white;
    if (color != "" && color.length == 7) {
      try {
        var r = int.parse(color.substring(1, 3), radix: 16);
        var g = int.parse(color.substring(3, 5), radix: 16);
        var b = int.parse(color.substring(5, 7), radix: 16);
        messageColor = LiveMessageColor(r, g, b);
      } catch (e) {
        //
        CoreLog.error(e);
      }
    }
    return messageColor;
  }

  @override
  int get hashCode {
    return r * 10000 + g * 100 + b;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveMessageColor &&
          runtimeType == other.runtimeType &&
          (other.r == r && other.g == g && other.b == b);

  @override
  String toString() {
    return "#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}";
  }
}

class LiveSuperChatMessage {
  final String userName;
  final String face;
  final String message;
  final int price;
  final DateTime startTime;
  final DateTime endTime;
  final String backgroundColor;
  final String backgroundBottomColor;

  LiveSuperChatMessage({
    required this.backgroundBottomColor,
    required this.backgroundColor,
    required this.endTime,
    required this.face,
    required this.message,
    required this.price,
    required this.startTime,
    required this.userName,
  });
}
