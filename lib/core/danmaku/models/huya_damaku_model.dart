// ignore_for_file: constant_identifier_names

enum EWebSocketCommandType {
  EWSCmd_NULL(0),
  EWSCmd_RegisterReq(1),
  EWSCmd_RegisterRsp(2),
  EWSCmd_WupReq(3),
  EWSCmd_WupRsp(4),
  EWSCmdC2S_HeartBeat(5),
  EWSCmdS2C_HeartBeatAck(6),
  EWSCmdS2C_MsgPushReq(7),
  EWSCmdC2S_DeregisterReq(8),
  EWSCmdS2C_DeRegisterRsp(9),
  EWSCmdC2S_VerifyCookieReq(10),
  EWSCmdS2C_VerifyCookieRsp(11),
  EWSCmdC2S_VerifyHuyaTokenReq(12),
  EWSCmdS2C_VerifyHuyaTokenRsp(13),
  EWSCmdC2S_UNVerifyReq(14),
  EWSCmdS2C_UNVerifyRsp(15),
  EWSCmdC2S_RegisterGroupReq(16),
  EWSCmdS2C_RegisterGroupRsp(17),
  EWSCmdC2S_UnRegisterGroupReq(18),
  EWSCmdS2C_UnRegisterGroupRsp(19),
  EWSCmdC2S_HeartBeatReq(20),
  EWSCmdS2C_HeartBeatRsp(21),
  EWSCmdS2C_MsgPushReq_V2(22),
  EWSCmdC2S_UpdateUserExpsReq(23),
  EWSCmdS2C_UpdateUserExpsRsp(24),
  EWSCmdC2S_WSHistoryMsgReq(25),
  EWSCmdS2C_WSHistoryMsgRsp(26),
  EWSCmdS2C_EnterP2P(27),
  EWSCmdS2C_EnterP2PAck(28),
  EWSCmdS2C_ExitP2P(29),
  EWSCmdS2C_ExitP2PAck(30),
  EWSCmdC2S_SyncGroupReq(31),
  EWSCmdS2C_SyncGroupRsp(32),
  EWSCmdC2S_UpdateUserInfoReq(33),
  EWSCmdS2C_UpdateUserInfoRsp(34),
  EWSCmdC2S_MsgAckReq(35),
  EWSCmdS2C_MsgAckRsp(36),
  EWSCmdC2S_CloudGameReq(37),
  EWSCmdS2C_CloudGamePush(38),
  EWSCmdS2C_CloudGameRsp(39),
  EWSCmdS2C_RpcReq(40),
  EWSCmdC2S_RpcRsp(41),
  EWSCmdS2C_RpcRspRsp(42),
  EWSCmdC2S_GetStunPortReq(101),
  EWSCmdS2C_GetStunPortRsp(102),
  EWSCmdC2S_WebRTCOfferReq(103),
  EWSCmdS2C_WebRTCOfferRsp(104),
  EWSCmdC2S_SignalUpgradeReq(105),
  EWSCmdS2C_SignalUpgradeRsp(106);

  final int value;
  const EWebSocketCommandType(this.value);

  // 从整数值解析（抛异常版本）
  static EWebSocketCommandType fromValue(int value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError.value(value, 'value', '未知的命令类型'),
    );
  }

  // 判断是否为请求（包含 Req 或 C2S）
  bool get isRequest {
    return switch (this) {
      EWSCmd_RegisterReq ||
      EWSCmd_WupReq ||
      EWSCmdC2S_HeartBeat ||
      EWSCmdC2S_DeregisterReq ||
      EWSCmdC2S_VerifyCookieReq ||
      EWSCmdC2S_VerifyHuyaTokenReq ||
      EWSCmdC2S_UNVerifyReq ||
      EWSCmdC2S_RegisterGroupReq ||
      EWSCmdC2S_UnRegisterGroupReq ||
      EWSCmdC2S_HeartBeatReq ||
      EWSCmdC2S_UpdateUserExpsReq ||
      EWSCmdC2S_WSHistoryMsgReq ||
      EWSCmdC2S_SyncGroupReq ||
      EWSCmdC2S_UpdateUserInfoReq ||
      EWSCmdC2S_MsgAckReq ||
      EWSCmdC2S_CloudGameReq ||
      EWSCmdC2S_RpcRsp ||
      EWSCmdC2S_GetStunPortReq ||
      EWSCmdC2S_WebRTCOfferReq ||
      EWSCmdC2S_SignalUpgradeReq => true,
      _ => false,
    };
  }

  // 判断是否为响应（包含 Rsp 或 S2C）
  bool get isResponse {
    return switch (this) {
      EWSCmd_RegisterRsp ||
      EWSCmd_WupRsp ||
      EWSCmdS2C_HeartBeatAck ||
      EWSCmdS2C_DeRegisterRsp ||
      EWSCmdS2C_VerifyCookieRsp ||
      EWSCmdS2C_VerifyHuyaTokenRsp ||
      EWSCmdS2C_UNVerifyRsp ||
      EWSCmdS2C_RegisterGroupRsp ||
      EWSCmdS2C_UnRegisterGroupRsp ||
      EWSCmdS2C_HeartBeatRsp ||
      EWSCmdS2C_UpdateUserExpsRsp ||
      EWSCmdS2C_WSHistoryMsgRsp ||
      EWSCmdS2C_SyncGroupRsp ||
      EWSCmdS2C_UpdateUserInfoRsp ||
      EWSCmdS2C_MsgAckRsp ||
      EWSCmdS2C_CloudGameRsp ||
      EWSCmdS2C_RpcRspRsp ||
      EWSCmdS2C_GetStunPortRsp ||
      EWSCmdS2C_WebRTCOfferRsp ||
      EWSCmdS2C_SignalUpgradeRsp => true,
      _ => false,
    };
  }

  // 判断是否为推送
  bool get isPush {
    return switch (this) {
      EWSCmdS2C_MsgPushReq || EWSCmdS2C_MsgPushReq_V2 || EWSCmdS2C_CloudGamePush => true,
      _ => false,
    };
  }

  // 判断是否为心跳相关
  bool get isHeartBeat {
    return switch (this) {
      EWSCmdC2S_HeartBeat || EWSCmdS2C_HeartBeatAck || EWSCmdC2S_HeartBeatReq || EWSCmdS2C_HeartBeatRsp => true,
      _ => false,
    };
  }

  // 判断是否为 P2P 相关
  bool get isP2P {
    return switch (this) {
      EWSCmdS2C_EnterP2P || EWSCmdS2C_EnterP2PAck || EWSCmdS2C_ExitP2P || EWSCmdS2C_ExitP2PAck => true,
      _ => false,
    };
  }

  // 判断是否为 WebRTC 相关
  bool get isWebRTC {
    return switch (this) {
      EWSCmdC2S_GetStunPortReq ||
      EWSCmdS2C_GetStunPortRsp ||
      EWSCmdC2S_WebRTCOfferReq ||
      EWSCmdS2C_WebRTCOfferRsp ||
      EWSCmdC2S_SignalUpgradeReq ||
      EWSCmdS2C_SignalUpgradeRsp => true,
      _ => false,
    };
  }

  // 获取命令分类
  String get category {
    return switch (this) {
      EWSCmd_NULL => 'NULL',
      EWSCmd_RegisterReq || EWSCmd_RegisterRsp => '注册',
      EWSCmd_WupReq || EWSCmd_WupRsp => 'WUP',
      EWSCmdC2S_HeartBeat || EWSCmdS2C_HeartBeatAck || EWSCmdC2S_HeartBeatReq || EWSCmdS2C_HeartBeatRsp => '心跳',
      EWSCmdS2C_MsgPushReq || EWSCmdS2C_MsgPushReq_V2 => '消息推送',
      EWSCmdC2S_DeregisterReq || EWSCmdS2C_DeRegisterRsp => '注销',
      EWSCmdC2S_VerifyCookieReq || EWSCmdS2C_VerifyCookieRsp => 'Cookie验证',
      EWSCmdC2S_VerifyHuyaTokenReq || EWSCmdS2C_VerifyHuyaTokenRsp => '虎牙Token验证',
      EWSCmdC2S_UNVerifyReq || EWSCmdS2C_UNVerifyRsp => '取消验证',
      EWSCmdC2S_RegisterGroupReq || EWSCmdS2C_RegisterGroupRsp => '注册群组',
      EWSCmdC2S_UnRegisterGroupReq || EWSCmdS2C_UnRegisterGroupRsp => '取消注册群组',
      EWSCmdC2S_UpdateUserExpsReq || EWSCmdS2C_UpdateUserExpsRsp => '更新用户经验',
      EWSCmdC2S_WSHistoryMsgReq || EWSCmdS2C_WSHistoryMsgRsp => '历史消息',
      EWSCmdS2C_EnterP2P || EWSCmdS2C_EnterP2PAck || EWSCmdS2C_ExitP2P || EWSCmdS2C_ExitP2PAck => 'P2P',
      EWSCmdC2S_SyncGroupReq || EWSCmdS2C_SyncGroupRsp => '同步群组',
      EWSCmdC2S_UpdateUserInfoReq || EWSCmdS2C_UpdateUserInfoRsp => '更新用户信息',
      EWSCmdC2S_MsgAckReq || EWSCmdS2C_MsgAckRsp => '消息确认',
      EWSCmdC2S_CloudGameReq || EWSCmdS2C_CloudGamePush || EWSCmdS2C_CloudGameRsp => '云游戏',
      EWSCmdS2C_RpcReq || EWSCmdC2S_RpcRsp || EWSCmdS2C_RpcRspRsp => 'RPC',
      EWSCmdC2S_GetStunPortReq ||
      EWSCmdS2C_GetStunPortRsp ||
      EWSCmdC2S_WebRTCOfferReq ||
      EWSCmdS2C_WebRTCOfferRsp ||
      EWSCmdC2S_SignalUpgradeReq ||
      EWSCmdS2C_SignalUpgradeRsp => 'WebRTC',
    };
  }
}
