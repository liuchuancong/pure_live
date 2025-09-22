import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/utils/color_util.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:uuid/uuid.dart';

class CCDanmakuArgs {
  int channelId;
  int gameType;
  int roomId;

  CCDanmakuArgs({
    required this.channelId,
    required this.roomId,
    required this.gameType,
  });
}

class CCDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 45 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://weblink.cc.163.com";

  WebScoketUtils? webScoketUtils;

  final Uuid _uuid = Uuid();

  String generateDeviceToken() {
    return '${_uuid.v1()}@web.cc.163.com';
  }

  @override
  Future start(dynamic args) async {
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  List<int> getReg(String deviceToken) {
    var sid = 6144;
    var cid = 2;
    var updateReqInfo = {
      '22': 640,
      '23': 360,
      '24': 'web',
      '25': 'Linux',
      '29': '163_cc',
      '30': '',
      '31': 'Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Mobile Safari/537.36',
    };

    var macAdd = deviceToken;
    var data = {
      'web-cc': DateTime.now().microsecondsSinceEpoch,
      'macAdd': macAdd,
      'device_token': deviceToken,
      'page_uuid': Uuid().v1(),
      'update_req_info': updateReqInfo,
      'memory': 1,
      'version': 1,
      'system': 'win',
      'client_type': 4253,
      // 'webccType': 4253,
      'webccType': 4253,
      'account_id': deviceToken,
    };

    /// 在 Dart 中，可以使用 ByteData 和 ByteBuffer 类来实现类似 Python 中 struct.pack() 的功能
    // var reg_data = struct('<HHI').pack(sid, cid, 0) + encode_dict(data);

    var writer = BinaryWriter(128);
    writer.writeUint16LE(sid);
    writer.writeUint16LE(cid);
    writer.writeUint32LE(0);
    // writer.writeInt(0, 1, endian: Endian.little);

    writer.writeBytes(encodeMap(data));

    return writer.toBytes();
  }

  Uint8List encodeString(String s) {
    final utf8Bytes = utf8.encode(s);
    final length = utf8Bytes.length;
    final writer = BinaryWriter(5 + utf8Bytes.length);

    // 根据长度选择编码前缀
    if (length < 32) {
      writer.writeUint8(0xA0 + length);
    } else if (length <= 255) {
      writer.writeUint8(0xD9);
      writer.writeUint8(length);
    } else if (length <= 65535) {
      writer.writeUint8(0xDA);
      writer.writeUint16LE(length);
    } else {
      writer.writeUint8(0xDB);
      writer.writeUint32LE(length);
    }

    writer.writeBytes(utf8Bytes);
    return writer.toBytes();
  }

  Uint8List encodeNumber(dynamic num) {
    final writer = BinaryWriter(8);

    if (num is int) {
      if (num >= 0 && num <= 127) {
        writer.writeUint8(num);
      } else if (num <= 255) {
        writer.writeUint8(0xCC);
        writer.writeUint8(num);
      } else if (num <= 65535) {
        writer.writeUint8(0xCD);
        writer.writeUint16LE(num);
      } else if (num <= 0xFFFFFFFF) {
        writer.writeUint8(0xCE);
        writer.writeUint32LE(num);
      } else {
        writer.writeUint8(0xCF);
        // Dart int 是64位，写入完整8字节
        final data = ByteData(8);
        data.setUint64(0, num, Endian.little);
        writer.writeBytes(data.buffer.asUint8List());
      }
    } else if (num is double) {
      writer.writeUint8(0xCB);
      final data = ByteData(8);
      data.setFloat64(0, num, Endian.little);
      writer.writeBytes(data.buffer.asUint8List());
    }

    return writer.toBytes();
  }

  Uint8List encodeMap(Map<String, dynamic> map) {
    final writer = BinaryWriter(1024);
    final entries = map.entries.toList();

    // 写入字典头
    if (entries.length < 16) {
      writer.writeUint8(0x80 | entries.length);
    } else if (entries.length <= 0xFFFF) {
      writer.writeUint8(0xDE);
      writer.writeUint16LE(entries.length);
    } else {
      writer.writeUint8(0xDF);
      writer.writeUint32LE(entries.length);
    }

    // 递归编码键值对
    for (final entry in entries) {
      writer.writeBytes(encodeString(entry.key));
      encodeValue(writer, entry.value);
    }

    return writer.toBytes();
  }

  void encodeValue(BinaryWriter writer, dynamic value) {
    if (value is String) {
      writer.writeBytes(encodeString(value));
    } else if (value is int || value is double) {
      writer.writeBytes(encodeNumber(value));
    } else if (value is Map<String, dynamic>) {
      writer.writeBytes(encodeMap(value));
    } else {
      throw ArgumentError('Unsupported type: ${value.runtimeType}');
    }
  }

  Future<void> joinRoom(dynamic args) async {
    // 先注册信息
    var uuid = const Uuid();
    var deviceToken = '${uuid.v1()}@web.cc.163.com';
    webScoketUtils?.sendMessage(getReg(deviceToken));

    // 延迟发送加入数据包
    await Future.delayed(const Duration(seconds: 1));

    // n.onMessage(2, 2, T),
    // n.onMessage(6144, 20, O),
    // n.onMessage(6144, 2, n._joinRoom),
    // n.onMessage(512, 2, n._joinRoom)

    var args2 = args as CCDanmakuArgs;
    var sid = 512;
    var cid = 1;
    // channel_id, gametype, roomId
    var data = {
      // 'ccsid': 512,
      // 'cccid': 1,
      'roomId': args2.roomId,
      'cid': args2.channelId,
      'gametype': args2.gameType,
      'hall_version': 1,
      'motive': '',
      'account_id': deviceToken,
      'recom_token': '',
      'client_type': 4000,
      'client_source': "",
      // 'room_sessid': "",
    };
    /// ccsid: 512,
//                                         cccid: 1,
//                                         roomId: parseInt(b.a.roomId, 10),
//                                         cid: parseInt(b.a.subcId, 10),
//                                         gametype: b.a.gameType,
//                                         hall_version: 1,
//                                         motive: n,
//                                         account_id: c(),
//                                         recom_token: Object(g.e)(1),
//                                         client_type: 4e3,
//                                         client_source: a,
//                                         room_sessid: s

    CoreLog.d("data: $data");
    var writer = BinaryWriter(128);
    writer.writeUint16LE(sid);
    writer.writeUint16LE(cid);
    writer.writeUint32LE(0);
    writer.writeBytes(encodeMap(data));
    webScoketUtils?.sendMessage(writer.toBytes());
  }

  Uint8List getBeat() {
    final writer = BinaryWriter(8);
    writer.writeUint16LE(6144); // sid
    writer.writeUint16LE(5); // cid
    writer.writeUint32LE(0); // flag
    writer.writeBytes(encodeMap({}));
    return writer.toBytes();
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(getBeat());
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  List<int> _decompressIfNeeded(Uint8List data) {
    if (data[0] == 0x78) {
      // zlib 压缩标识
      return zlib.decode(data);
    }
    return data;
  }

  void decodeMessage(List<int> data) {
    try {
      if (data is! Uint8List) return;
      // 解析消息头
      // final header = ByteData.sublistView(data, 0, 8);
      // final sid = header.getUint16(0, Endian.big);
      // final cid = header.getUint16(2, Endian.big);
      // final flag = header.getUint32(4, Endian.big);

      // 解析消息体
      final body = data.sublist(8);
      final decompressed = _decompressIfNeeded(body);
      final decoder = MessageDecoder(decompressed as Uint8List);
      final message = decoder.decode() as Map<String, dynamic>;

      CoreLog.d("message: $message");
      // 根据消息类型处理不同数据结构
      if (message.containsKey('data') && message['data'] is Map) {
        final msgList = message['data']['msg_list'] as List<dynamic>;
        for (final msg in msgList) {
          onMessage?.call(LiveMessage(
            type: LiveMessageType.chat,
            userName: msg[197] as String,
            message: msg[4] as String,
            color: Colors.white,
          ));
        }
      } else if (message.containsKey('msg')) {
        final msg = message['msg'] as List<dynamic>;
        final nickname = json.decode(msg[7] as String)['nickname'];
        onMessage?.call(LiveMessage(
          type: LiveMessageType.chat,
          userName: nickname,
          message: msg[4] as String,
          color: Colors.white,
        ));
      }
    } catch (e) {
      // print("stack:\n $stack");
      CoreLog.error(e);
    }
  }
}

Color getColor(int type) {
  switch (type) {
    case 1:
      return ColorUtil.fromRGB(255, 0, 0);
    case 2:
      return ColorUtil.fromRGB(30, 135, 240);
    case 3:
      return ColorUtil.fromRGB(122, 200, 75);
    case 4:
      return ColorUtil.fromRGB(255, 127, 0);
    case 5:
      return ColorUtil.fromRGB(155, 57, 244);
    case 6:
      return ColorUtil.fromRGB(255, 105, 180);
    default:
      return Colors.white;
  }
}

enum Type {
  byte, //1
  word, //2
  dword, //4
  string
}

/// 仿 Python struct
class BinaryWriter {
  ByteData _buffer;
  int _offset = 0;

  BinaryWriter(int initialSize) : _buffer = ByteData(initialSize);

  /// 扩展缓冲区容量
  void _ensureCapacity(int requiredLength) {
    if (_offset + requiredLength > _buffer.lengthInBytes) {
      var asUint8List = _buffer.buffer.asUint8List();
      _buffer = ByteData(_offset + requiredLength * 2);
      _buffer.buffer.asUint8List().setRange(0, _offset, asUint8List);
      // _buffer.buffer.asUint8List().setAll(0, newBuffer.buffer.asUint8List());
    }
  }

  /// 写入1字节无符号整数
  void writeUint8(int value) {
    _ensureCapacity(1);
    _buffer.setUint8(_offset++, value);
  }

  /// 写入2字节小端无符号整数
  void writeUint16LE(int value) {
    _ensureCapacity(2);
    _buffer.setUint16(_offset, value, Endian.little);
    _offset += 2;
  }

  /// 写入4字节小端无符号整数
  void writeUint32LE(int value) {
    _ensureCapacity(4);
    _buffer.setUint32(_offset, value, Endian.little);
    _offset += 4;
  }

  /// 写入字节列表
  void writeBytes(List<int> bytes) {
    _ensureCapacity(bytes.length);
    _buffer.buffer.asUint8List().setAll(_offset, bytes);
    _offset += bytes.length;
  }

  /// 获取最终二进制数据
  Uint8List toBytes() {
    return _buffer.buffer.asUint8List(0, _offset);
  }
}

class MessageDecoder {
  int _offset = 0;
  final Uint8List _data;

  MessageDecoder(this._data);

  dynamic _parseValue(int tag) {
    // 处理正数
    if (tag <= 0x7F) {
      return tag;
    }

    // 处理负数
    if (tag >= 0xE0 && tag <= 0xFF) {
      return tag - 256;
    }

    // 短字符串 (长度直接编码在tag中)
    if (tag >= 0xA0 && tag <= 0xBF) {
      return _parseString(tag - 0xA0);
    }

    // 短字典 (长度直接编码在tag中)
    if (tag >= 0x80 && tag <= 0xBF) {
      return _parseMap(tag - 0x80);
    }

    // 短列表
    if (tag >= 0x90 && tag <= 0x9F) {
      return _parseList(tag - 0x90);
    }

    switch (tag) {
      // 字符串
      // case 0xA0...0xBF: // 短字符串 (长度直接编码在tag中)
      // final length = tag - 0xA0;
      // return _parseString(length);
      case 0xD9: // 8位长度字符串
        return _parseString(_readUint8());
      case 0xDA: // 16位长度字符串
        return _parseString(_readUint16());
      case 0xDB: // 32位长度字符串
        return _parseString(_readUint32());

      // 整数
      case 0xCC: // 8位无符号整数
        return _readUint8();
      case 0xCD: // 16位无符号整数
        return _readUint16();
      case 0xCE: // 32位无符号整数
        return _readUint32();
      case 0xCF: // 64位无符号整数
        return _readUint64();

      // 浮点数
      case 0xCB: // 64位双精度浮点
        return _parseDouble();

      // 字典
      // case 0x80...0x8F: // 短字典 (长度直接编码在tag中)
      // return _parseMap(tag - 0x80);
      case 0xDE: // 16位长度字典
        return _parseMap(_readUint16());
      case 0xDF: // 32位长度字典
        return _parseMap(_readUint32());

      // 列表
      // case 0x90...0x9F: // 短列表
      // return _parseList(tag - 0x90);
      case 0xDC: // 16位长度列表
        return _parseList(_readUint16());
      case 0xDD: // 32位长度列表
        return _parseList(_readUint32());

      // 特殊值
      case 0xC0: // null
        return null;
      case 0xC2: // false
        return false;
      case 0xC3: // true
        return true;

      default:
        throw FormatException('Unknown tag: 0x${tag.toRadixString(16)}');
    }
  }

  String _parseString(int length) {
    final bytes = _readBytes(length);
    try {
      return utf8.decode(bytes);
    } catch (e, stackTrace) {
      CoreLog.w("$bytes \n ${e.toString()} \n $stackTrace");
      CoreLog.e(e.toString(), stackTrace);
      return "";
    }
  }

  Map<String, dynamic> _parseMap(int entryCount) {
    final map = <String, dynamic>{};
    for (var i = 0; i < entryCount; i++) {
      final keyTag = _readUint8();
      final key = _parseValue(keyTag).toString();
      final valueTag = _readUint8();
      map[key] = _parseValue(valueTag);
    }
    return map;
  }

  List<dynamic> _parseList(int length) {
    final list = <dynamic>[];
    for (var i = 0; i < length; i++) {
      final tag = _readUint8();
      list.add(_parseValue(tag));
    }
    return list;
  }

  double _parseDouble() {
    final bytes = _readBytes(8);
    return ByteData.sublistView(bytes).getFloat64(0, Endian.little);
  }

  /// 主解码入口
  dynamic decode() {
    final tag = _readUint8();
    return _parseValue(tag);
  }

  /// 读取1字节无符号整数
  int _readUint8() {
    var tmpIndex = min(_data.lengthInBytes - 1, _offset++);
    return _data[tmpIndex];
  }

  /// 读取2字节小端无符号整数
  int _readUint16() {
    final value = ByteData.sublistView(_data, _offset, _offset + 2).getUint16(0, Endian.big);
    _offset += 2;
    return value;
  }

  /// 读取4字节小端无符号整数
  int _readUint32() {
    final value = ByteData.sublistView(_data, _offset, _offset + 4).getUint32(0, Endian.little);
    _offset += 4;
    return value;
  }

  /// 读取8字节小端无符号整数
  int _readUint64() {
    final value = ByteData.sublistView(_data, _offset, _offset + 8).getUint32(0, Endian.little);
    _offset += 8;
    return value;
  }

  /// 读取指定长度的字节
  Uint8List _readBytes(int length) {
    var tmpLen = min(_data.lengthInBytes, _offset + length);
    tmpLen = _offset + length;
    final bytes = _data.sublist(_offset, tmpLen);
    _offset += length;
    return bytes;
  }
}
