//
//  Generated code. Do not modify.
//  source: ks.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use compressionTypeDescriptor instead')
const CompressionType$json = {
  '1': 'CompressionType',
  '2': [
    {'1': 'COMPRESSION_TYPE_UNKNOWN', '2': 0},
    {'1': 'NONE', '2': 1},
    {'1': 'GZIP', '2': 2},
    {'1': 'AES', '2': 3},
  ],
};

/// Descriptor for `CompressionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List compressionTypeDescriptor = $convert.base64Decode(
    'Cg9Db21wcmVzc2lvblR5cGUSHAoYQ09NUFJFU1NJT05fVFlQRV9VTktOT1dOEAASCAoETk9ORR'
    'ABEggKBEdaSVAQAhIHCgNBRVMQAw==');

@$core.Deprecated('Use payloadTypeDescriptor instead')
const PayloadType$json = {
  '1': 'PayloadType',
  '2': [
    {'1': 'PAYLOAD_TYPE_UNKNOWN', '2': 0},
    {'1': 'CS_HEARTBEAT', '2': 1},
    {'1': 'CS_ERROR', '2': 3},
    {'1': 'CS_PING', '2': 4},
    {'1': 'PS_HOST_INFO', '2': 51},
    {'1': 'SC_HEARTBEAT_ACK', '2': 101},
    {'1': 'SC_ECHO', '2': 102},
    {'1': 'SC_ERROR', '2': 103},
    {'1': 'SC_PING_ACK', '2': 104},
    {'1': 'SC_INFO', '2': 105},
    {'1': 'CS_ENTER_ROOM', '2': 200},
    {'1': 'CS_USER_PAUSE', '2': 201},
    {'1': 'CS_USER_EXIT', '2': 202},
    {'1': 'CS_AUTHOR_PUSH_TRAFFIC_ZERO', '2': 203},
    {'1': 'CS_HORSE_RACING', '2': 204},
    {'1': 'CS_RACE_LOSE', '2': 205},
    {'1': 'CS_VOIP_SIGNAL', '2': 206},
    {'1': 'SC_ENTER_ROOM_ACK', '2': 300},
    {'1': 'SC_AUTHOR_PAUSE', '2': 301},
    {'1': 'SC_AUTHOR_RESUME', '2': 302},
    {'1': 'SC_AUTHOR_PUSH_TRAFFIC_ZERO', '2': 303},
    {'1': 'SC_AUTHOR_HEARTBEAT_MISS', '2': 304},
    {'1': 'SC_PIP_STARTED', '2': 305},
    {'1': 'SC_PIP_ENDED', '2': 306},
    {'1': 'SC_HORSE_RACING_ACK', '2': 307},
    {'1': 'SC_VOIP_SIGNAL', '2': 308},
    {'1': 'SC_FEED_PUSH', '2': 310},
    {'1': 'SC_ASSISTANT_STATUS', '2': 311},
    {'1': 'SC_REFRESH_WALLET', '2': 312},
    {'1': 'SC_LIVE_CHAT_CALL', '2': 320},
    {'1': 'SC_LIVE_CHAT_CALL_ACCEPTED', '2': 321},
    {'1': 'SC_LIVE_CHAT_CALL_REJECTED', '2': 322},
    {'1': 'SC_LIVE_CHAT_READY', '2': 323},
    {'1': 'SC_LIVE_CHAT_GUEST_END', '2': 324},
    {'1': 'SC_LIVE_CHAT_ENDED', '2': 325},
    {'1': 'SC_RENDERING_MAGIC_FACE_DISABLE', '2': 326},
    {'1': 'SC_RENDERING_MAGIC_FACE_ENABLE', '2': 327},
    {'1': 'SC_RED_PACK_FEED', '2': 330},
    {'1': 'SC_LIVE_WATCHING_LIST', '2': 340},
    {'1': 'SC_LIVE_QUIZ_QUESTION_ASKED', '2': 350},
    {'1': 'SC_LIVE_QUIZ_QUESTION_REVIEWED', '2': 351},
    {'1': 'SC_LIVE_QUIZ_SYNC', '2': 352},
    {'1': 'SC_LIVE_QUIZ_ENDED', '2': 353},
    {'1': 'SC_LIVE_QUIZ_WINNERS', '2': 354},
    {'1': 'SC_SUSPECTED_VIOLATION', '2': 355},
    {'1': 'SC_SHOP_OPENED', '2': 360},
    {'1': 'SC_SHOP_CLOSED', '2': 361},
    {'1': 'SC_GUESS_OPENED', '2': 370},
    {'1': 'SC_GUESS_CLOSED', '2': 371},
    {'1': 'SC_PK_INVITATION', '2': 380},
    {'1': 'SC_PK_STATISTIC', '2': 381},
    {'1': 'SC_RIDDLE_OPENED', '2': 390},
    {'1': 'SC_RIDDLE_CLOESED', '2': 391},
    {'1': 'SC_RIDE_CHANGED', '2': 412},
    {'1': 'SC_BET_CHANGED', '2': 441},
    {'1': 'SC_BET_CLOSED', '2': 442},
    {'1': 'SC_LIVE_SPECIAL_ACCOUNT_CONFIG_STATE', '2': 645},
    {'1': 'SC_LIVE_WARNING_MASK_STATUS_CHANGED_AUDIENCE', '2': 758},
  ],
};

/// Descriptor for `PayloadType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List payloadTypeDescriptor = $convert.base64Decode(
    'CgtQYXlsb2FkVHlwZRIYChRQQVlMT0FEX1RZUEVfVU5LTk9XThAAEhAKDENTX0hFQVJUQkVBVB'
    'ABEgwKCENTX0VSUk9SEAMSCwoHQ1NfUElORxAEEhAKDFBTX0hPU1RfSU5GTxAzEhQKEFNDX0hF'
    'QVJUQkVBVF9BQ0sQZRILCgdTQ19FQ0hPEGYSDAoIU0NfRVJST1IQZxIPCgtTQ19QSU5HX0FDSx'
    'BoEgsKB1NDX0lORk8QaRISCg1DU19FTlRFUl9ST09NEMgBEhIKDUNTX1VTRVJfUEFVU0UQyQES'
    'EQoMQ1NfVVNFUl9FWElUEMoBEiAKG0NTX0FVVEhPUl9QVVNIX1RSQUZGSUNfWkVSTxDLARIUCg'
    '9DU19IT1JTRV9SQUNJTkcQzAESEQoMQ1NfUkFDRV9MT1NFEM0BEhMKDkNTX1ZPSVBfU0lHTkFM'
    'EM4BEhYKEVNDX0VOVEVSX1JPT01fQUNLEKwCEhQKD1NDX0FVVEhPUl9QQVVTRRCtAhIVChBTQ1'
    '9BVVRIT1JfUkVTVU1FEK4CEiAKG1NDX0FVVEhPUl9QVVNIX1RSQUZGSUNfWkVSTxCvAhIdChhT'
    'Q19BVVRIT1JfSEVBUlRCRUFUX01JU1MQsAISEwoOU0NfUElQX1NUQVJURUQQsQISEQoMU0NfUE'
    'lQX0VOREVEELICEhgKE1NDX0hPUlNFX1JBQ0lOR19BQ0sQswISEwoOU0NfVk9JUF9TSUdOQUwQ'
    'tAISEQoMU0NfRkVFRF9QVVNIELYCEhgKE1NDX0FTU0lTVEFOVF9TVEFUVVMQtwISFgoRU0NfUk'
    'VGUkVTSF9XQUxMRVQQuAISFgoRU0NfTElWRV9DSEFUX0NBTEwQwAISHwoaU0NfTElWRV9DSEFU'
    'X0NBTExfQUNDRVBURUQQwQISHwoaU0NfTElWRV9DSEFUX0NBTExfUkVKRUNURUQQwgISFwoSU0'
    'NfTElWRV9DSEFUX1JFQURZEMMCEhsKFlNDX0xJVkVfQ0hBVF9HVUVTVF9FTkQQxAISFwoSU0Nf'
    'TElWRV9DSEFUX0VOREVEEMUCEiQKH1NDX1JFTkRFUklOR19NQUdJQ19GQUNFX0RJU0FCTEUQxg'
    'ISIwoeU0NfUkVOREVSSU5HX01BR0lDX0ZBQ0VfRU5BQkxFEMcCEhUKEFNDX1JFRF9QQUNLX0ZF'
    'RUQQygISGgoVU0NfTElWRV9XQVRDSElOR19MSVNUENQCEiAKG1NDX0xJVkVfUVVJWl9RVUVTVE'
    'lPTl9BU0tFRBDeAhIjCh5TQ19MSVZFX1FVSVpfUVVFU1RJT05fUkVWSUVXRUQQ3wISFgoRU0Nf'
    'TElWRV9RVUlaX1NZTkMQ4AISFwoSU0NfTElWRV9RVUlaX0VOREVEEOECEhkKFFNDX0xJVkVfUV'
    'VJWl9XSU5ORVJTEOICEhsKFlNDX1NVU1BFQ1RFRF9WSU9MQVRJT04Q4wISEwoOU0NfU0hPUF9P'
    'UEVORUQQ6AISEwoOU0NfU0hPUF9DTE9TRUQQ6QISFAoPU0NfR1VFU1NfT1BFTkVEEPICEhQKD1'
    'NDX0dVRVNTX0NMT1NFRBDzAhIVChBTQ19QS19JTlZJVEFUSU9OEPwCEhQKD1NDX1BLX1NUQVRJ'
    'U1RJQxD9AhIVChBTQ19SSURETEVfT1BFTkVEEIYDEhYKEVNDX1JJRERMRV9DTE9FU0VEEIcDEh'
    'QKD1NDX1JJREVfQ0hBTkdFRBCcAxITCg5TQ19CRVRfQ0hBTkdFRBC5AxISCg1TQ19CRVRfQ0xP'
    'U0VEELoDEikKJFNDX0xJVkVfU1BFQ0lBTF9BQ0NPVU5UX0NPTkZJR19TVEFURRCFBRIxCixTQ1'
    '9MSVZFX1dBUk5JTkdfTUFTS19TVEFUVVNfQ0hBTkdFRF9BVURJRU5DRRD2BQ==');

@$core.Deprecated('Use webLiveAssistantTypeDescriptor instead')
const WebLiveAssistantType$json = {
  '1': 'WebLiveAssistantType',
  '2': [
    {'1': 'WEB_LIVE_ASSISTANT_TYPE_UNKNOWN_ASSISTANT_TYPE', '2': 0},
    {'1': 'SUPER', '2': 1},
    {'1': 'JUNIOR', '2': 2},
  ],
};

/// Descriptor for `WebLiveAssistantType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List webLiveAssistantTypeDescriptor = $convert.base64Decode(
    'ChRXZWJMaXZlQXNzaXN0YW50VHlwZRIyCi5XRUJfTElWRV9BU1NJU1RBTlRfVFlQRV9VTktOT1'
    'dOX0FTU0lTVEFOVF9UWVBFEAASCQoFU1VQRVIQARIKCgZKVU5JT1IQAg==');

@$core.Deprecated('Use webCommentFeedShowTypeDescriptor instead')
const WebCommentFeedShowType$json = {
  '1': 'WebCommentFeedShowType',
  '2': [
    {'1': 'FEED_SHOW_UNKNOWN', '2': 0},
    {'1': 'FEED_SHOW_NORMAL', '2': 1},
    {'1': 'FEED_HIDDEN', '2': 2},
  ],
};

/// Descriptor for `WebCommentFeedShowType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List webCommentFeedShowTypeDescriptor = $convert.base64Decode(
    'ChZXZWJDb21tZW50RmVlZFNob3dUeXBlEhUKEUZFRURfU0hPV19VTktOT1dOEAASFAoQRkVFRF'
    '9TSE9XX05PUk1BTBABEg8KC0ZFRURfSElEREVOEAI=');

@$core.Deprecated('Use assistantTypeDescriptor instead')
const AssistantType$json = {
  '1': 'AssistantType',
  '2': [
    {'1': 'UNKNOWN_ASSISTANT_TYPE', '2': 0},
    {'1': 'ASSISTANT_SUPER', '2': 1},
    {'1': 'ASSISTANT_JUNIOR', '2': 2},
  ],
};

/// Descriptor for `AssistantType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List assistantTypeDescriptor = $convert.base64Decode(
    'Cg1Bc3Npc3RhbnRUeXBlEhoKFlVOS05PV05fQVNTSVNUQU5UX1RZUEUQABITCg9BU1NJU1RBTl'
    'RfU1VQRVIQARIUChBBU1NJU1RBTlRfSlVOSU9SEAI=');

@$core.Deprecated('Use styleTypeDescriptor instead')
const StyleType$json = {
  '1': 'StyleType',
  '2': [
    {'1': 'UNKNOWN_STYLE', '2': 0},
    {'1': 'BATCH_STAR_0', '2': 1},
    {'1': 'BATCH_STAR_1', '2': 2},
    {'1': 'BATCH_STAR_2', '2': 3},
    {'1': 'BATCH_STAR_3', '2': 4},
    {'1': 'BATCH_STAR_4', '2': 5},
    {'1': 'BATCH_STAR_5', '2': 6},
    {'1': 'BATCH_STAR_6', '2': 7},
  ],
};

/// Descriptor for `StyleType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List styleTypeDescriptor = $convert.base64Decode(
    'CglTdHlsZVR5cGUSEQoNVU5LTk9XTl9TVFlMRRAAEhAKDEJBVENIX1NUQVJfMBABEhAKDEJBVE'
    'NIX1NUQVJfMRACEhAKDEJBVENIX1NUQVJfMhADEhAKDEJBVENIX1NUQVJfMxAEEhAKDEJBVENI'
    'X1NUQVJfNBAFEhAKDEJBVENIX1NUQVJfNRAGEhAKDEJBVENIX1NUQVJfNhAH');

@$core.Deprecated('Use displayTypeDescriptor instead')
const DisplayType$json = {
  '1': 'DisplayType',
  '2': [
    {'1': 'UNKNOWN_DISPLAY_TYPE', '2': 0},
    {'1': 'COMMENT', '2': 1},
    {'1': 'ALERT', '2': 2},
    {'1': 'TOAST', '2': 3},
  ],
};

/// Descriptor for `DisplayType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List displayTypeDescriptor = $convert.base64Decode(
    'CgtEaXNwbGF5VHlwZRIYChRVTktOT1dOX0RJU1BMQVlfVFlQRRAAEgsKB0NPTU1FTlQQARIJCg'
    'VBTEVSVBACEgkKBVRPQVNUEAM=');

@$core.Deprecated('Use cSWebEnterRoomDescriptor instead')
const CSWebEnterRoom$json = {
  '1': 'CSWebEnterRoom',
  '2': [
    {'1': 'payloadType', '3': 1, '4': 1, '5': 3, '10': 'payloadType'},
    {'1': 'payload', '3': 3, '4': 1, '5': 11, '6': '.kuaishouPubf.CSWebEnterRoom.Payload', '10': 'payload'},
  ],
  '3': [CSWebEnterRoom_Payload$json],
};

@$core.Deprecated('Use cSWebEnterRoomDescriptor instead')
const CSWebEnterRoom_Payload$json = {
  '1': 'Payload',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'liveStreamId', '3': 2, '4': 1, '5': 9, '10': 'liveStreamId'},
    {'1': 'reconnectCount', '3': 3, '4': 1, '5': 13, '10': 'reconnectCount'},
    {'1': 'lastErrorCode', '3': 4, '4': 1, '5': 13, '10': 'lastErrorCode'},
    {'1': 'expTag', '3': 5, '4': 1, '5': 9, '10': 'expTag'},
    {'1': 'attach', '3': 6, '4': 1, '5': 9, '10': 'attach'},
    {'1': 'pageId', '3': 7, '4': 1, '5': 9, '10': 'pageId'},
  ],
};

/// Descriptor for `CSWebEnterRoom`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cSWebEnterRoomDescriptor = $convert.base64Decode(
    'Cg5DU1dlYkVudGVyUm9vbRIgCgtwYXlsb2FkVHlwZRgBIAEoA1ILcGF5bG9hZFR5cGUSPgoHcG'
    'F5bG9hZBgDIAEoCzIkLmt1YWlzaG91UHViZi5DU1dlYkVudGVyUm9vbS5QYXlsb2FkUgdwYXls'
    'b2FkGtkBCgdQYXlsb2FkEhQKBXRva2VuGAEgASgJUgV0b2tlbhIiCgxsaXZlU3RyZWFtSWQYAi'
    'ABKAlSDGxpdmVTdHJlYW1JZBImCg5yZWNvbm5lY3RDb3VudBgDIAEoDVIOcmVjb25uZWN0Q291'
    'bnQSJAoNbGFzdEVycm9yQ29kZRgEIAEoDVINbGFzdEVycm9yQ29kZRIWCgZleHBUYWcYBSABKA'
    'lSBmV4cFRhZxIWCgZhdHRhY2gYBiABKAlSBmF0dGFjaBIWCgZwYWdlSWQYByABKAlSBnBhZ2VJ'
    'ZA==');

@$core.Deprecated('Use sCWebEnterRoomAckDescriptor instead')
const SCWebEnterRoomAck$json = {
  '1': 'SCWebEnterRoomAck',
  '2': [
    {'1': 'minReconnectMs', '3': 1, '4': 1, '5': 4, '10': 'minReconnectMs'},
    {'1': 'maxReconnectMs', '3': 2, '4': 1, '5': 4, '10': 'maxReconnectMs'},
    {'1': 'heartbeatIntervalMs', '3': 3, '4': 1, '5': 4, '10': 'heartbeatIntervalMs'},
  ],
};

/// Descriptor for `SCWebEnterRoomAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sCWebEnterRoomAckDescriptor = $convert.base64Decode(
    'ChFTQ1dlYkVudGVyUm9vbUFjaxImCg5taW5SZWNvbm5lY3RNcxgBIAEoBFIObWluUmVjb25uZW'
    'N0TXMSJgoObWF4UmVjb25uZWN0TXMYAiABKARSDm1heFJlY29ubmVjdE1zEjAKE2hlYXJ0YmVh'
    'dEludGVydmFsTXMYAyABKARSE2hlYXJ0YmVhdEludGVydmFsTXM=');

@$core.Deprecated('Use simpleUserInfoDescriptor instead')
const SimpleUserInfo$json = {
  '1': 'SimpleUserInfo',
  '2': [
    {'1': 'principalId', '3': 1, '4': 1, '5': 9, '10': 'principalId'},
    {'1': 'userName', '3': 2, '4': 1, '5': 9, '10': 'userName'},
    {'1': 'headUrl', '3': 3, '4': 1, '5': 9, '10': 'headUrl'},
  ],
};

/// Descriptor for `SimpleUserInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simpleUserInfoDescriptor = $convert.base64Decode(
    'Cg5TaW1wbGVVc2VySW5mbxIgCgtwcmluY2lwYWxJZBgBIAEoCVILcHJpbmNpcGFsSWQSGgoIdX'
    'Nlck5hbWUYAiABKAlSCHVzZXJOYW1lEhgKB2hlYWRVcmwYAyABKAlSB2hlYWRVcmw=');

@$core.Deprecated('Use webWatchingUserInfoDescriptor instead')
const WebWatchingUserInfo$json = {
  '1': 'WebWatchingUserInfo',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.kuaishouPubf.SimpleUserInfo', '10': 'user'},
    {'1': 'offline', '3': 2, '4': 1, '5': 8, '10': 'offline'},
    {'1': 'tuhao', '3': 3, '4': 1, '5': 8, '10': 'tuhao'},
    {'1': 'liveAssistantType', '3': 4, '4': 1, '5': 14, '6': '.kuaishouPubf.WebLiveAssistantType', '10': 'liveAssistantType'},
    {'1': 'displayKsCoin', '3': 5, '4': 1, '5': 9, '10': 'displayKsCoin'},
  ],
};

/// Descriptor for `WebWatchingUserInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webWatchingUserInfoDescriptor = $convert.base64Decode(
    'ChNXZWJXYXRjaGluZ1VzZXJJbmZvEjAKBHVzZXIYASABKAsyHC5rdWFpc2hvdVB1YmYuU2ltcG'
    'xlVXNlckluZm9SBHVzZXISGAoHb2ZmbGluZRgCIAEoCFIHb2ZmbGluZRIUCgV0dWhhbxgDIAEo'
    'CFIFdHVoYW8SUAoRbGl2ZUFzc2lzdGFudFR5cGUYBCABKA4yIi5rdWFpc2hvdVB1YmYuV2ViTG'
    'l2ZUFzc2lzdGFudFR5cGVSEWxpdmVBc3Npc3RhbnRUeXBlEiQKDWRpc3BsYXlLc0NvaW4YBSAB'
    'KAlSDWRpc3BsYXlLc0NvaW4=');

@$core.Deprecated('Use sCWebLiveWatchingUsersDescriptor instead')
const SCWebLiveWatchingUsers$json = {
  '1': 'SCWebLiveWatchingUsers',
  '2': [
    {'1': 'watchingUser', '3': 1, '4': 3, '5': 11, '6': '.kuaishouPubf.WebWatchingUserInfo', '10': 'watchingUser'},
    {'1': 'displayWatchingCount', '3': 2, '4': 1, '5': 9, '10': 'displayWatchingCount'},
    {'1': 'pendingDuration', '3': 3, '4': 1, '5': 4, '10': 'pendingDuration'},
  ],
};

/// Descriptor for `SCWebLiveWatchingUsers`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sCWebLiveWatchingUsersDescriptor = $convert.base64Decode(
    'ChZTQ1dlYkxpdmVXYXRjaGluZ1VzZXJzEkUKDHdhdGNoaW5nVXNlchgBIAMoCzIhLmt1YWlzaG'
    '91UHViZi5XZWJXYXRjaGluZ1VzZXJJbmZvUgx3YXRjaGluZ1VzZXISMgoUZGlzcGxheVdhdGNo'
    'aW5nQ291bnQYAiABKAlSFGRpc3BsYXlXYXRjaGluZ0NvdW50EigKD3BlbmRpbmdEdXJhdGlvbh'
    'gDIAEoBFIPcGVuZGluZ0R1cmF0aW9u');

@$core.Deprecated('Use cSWebHeartbeatDescriptor instead')
const CSWebHeartbeat$json = {
  '1': 'CSWebHeartbeat',
  '2': [
    {'1': 'payloadType', '3': 1, '4': 1, '5': 3, '10': 'payloadType'},
    {'1': 'payload', '3': 3, '4': 1, '5': 11, '6': '.kuaishouPubf.CSWebHeartbeat.Payload', '10': 'payload'},
  ],
  '3': [CSWebHeartbeat_Payload$json],
};

@$core.Deprecated('Use cSWebHeartbeatDescriptor instead')
const CSWebHeartbeat_Payload$json = {
  '1': 'Payload',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 4, '10': 'timestamp'},
  ],
};

/// Descriptor for `CSWebHeartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cSWebHeartbeatDescriptor = $convert.base64Decode(
    'Cg5DU1dlYkhlYXJ0YmVhdBIgCgtwYXlsb2FkVHlwZRgBIAEoA1ILcGF5bG9hZFR5cGUSPgoHcG'
    'F5bG9hZBgDIAEoCzIkLmt1YWlzaG91UHViZi5DU1dlYkhlYXJ0YmVhdC5QYXlsb2FkUgdwYXls'
    'b2FkGicKB1BheWxvYWQSHAoJdGltZXN0YW1wGAEgASgEUgl0aW1lc3RhbXA=');

@$core.Deprecated('Use socketMessageDescriptor instead')
const SocketMessage$json = {
  '1': 'SocketMessage',
  '2': [
    {'1': 'payloadType', '3': 1, '4': 1, '5': 14, '6': '.kuaishouPubf.PayloadType', '10': 'payloadType'},
    {'1': 'compressionType', '3': 2, '4': 1, '5': 14, '6': '.kuaishouPubf.CompressionType', '10': 'compressionType'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `SocketMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List socketMessageDescriptor = $convert.base64Decode(
    'Cg1Tb2NrZXRNZXNzYWdlEjsKC3BheWxvYWRUeXBlGAEgASgOMhkua3VhaXNob3VQdWJmLlBheW'
    'xvYWRUeXBlUgtwYXlsb2FkVHlwZRJHCg9jb21wcmVzc2lvblR5cGUYAiABKA4yHS5rdWFpc2hv'
    'dVB1YmYuQ29tcHJlc3Npb25UeXBlUg9jb21wcmVzc2lvblR5cGUSGAoHcGF5bG9hZBgDIAEoDF'
    'IHcGF5bG9hZA==');

@$core.Deprecated('Use sCHeartbeatAckDescriptor instead')
const SCHeartbeatAck$json = {
  '1': 'SCHeartbeatAck',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 4, '10': 'timestamp'},
    {'1': 'clientTimestamp', '3': 2, '4': 1, '5': 4, '10': 'clientTimestamp'},
  ],
};

/// Descriptor for `SCHeartbeatAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sCHeartbeatAckDescriptor = $convert.base64Decode(
    'Cg5TQ0hlYXJ0YmVhdEFjaxIcCgl0aW1lc3RhbXAYASABKARSCXRpbWVzdGFtcBIoCg9jbGllbn'
    'RUaW1lc3RhbXAYAiABKARSD2NsaWVudFRpbWVzdGFtcA==');

@$core.Deprecated('Use webCommentFeedDescriptor instead')
const WebCommentFeed$json = {
  '1': 'WebCommentFeed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.kuaishouPubf.SimpleUserInfo', '10': 'user'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'deviceHash', '3': 4, '4': 1, '5': 9, '10': 'deviceHash'},
    {'1': 'sortRank', '3': 5, '4': 1, '5': 4, '10': 'sortRank'},
    {'1': 'color', '3': 6, '4': 1, '5': 9, '10': 'color'},
    {'1': 'showType', '3': 7, '4': 1, '5': 14, '6': '.kuaishouPubf.WebCommentFeedShowType', '10': 'showType'},
    {'1': 'senderState', '3': 8, '4': 1, '5': 11, '6': '.kuaishouPubf.LiveAudienceState', '10': 'senderState'},
  ],
};

/// Descriptor for `WebCommentFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webCommentFeedDescriptor = $convert.base64Decode(
    'Cg5XZWJDb21tZW50RmVlZBIOCgJpZBgBIAEoCVICaWQSMAoEdXNlchgCIAEoCzIcLmt1YWlzaG'
    '91UHViZi5TaW1wbGVVc2VySW5mb1IEdXNlchIYCgdjb250ZW50GAMgASgJUgdjb250ZW50Eh4K'
    'CmRldmljZUhhc2gYBCABKAlSCmRldmljZUhhc2gSGgoIc29ydFJhbmsYBSABKARSCHNvcnRSYW'
    '5rEhQKBWNvbG9yGAYgASgJUgVjb2xvchJACghzaG93VHlwZRgHIAEoDjIkLmt1YWlzaG91UHVi'
    'Zi5XZWJDb21tZW50RmVlZFNob3dUeXBlUghzaG93VHlwZRJBCgtzZW5kZXJTdGF0ZRgIIAEoCz'
    'IfLmt1YWlzaG91UHViZi5MaXZlQXVkaWVuY2VTdGF0ZVILc2VuZGVyU3RhdGU=');

@$core.Deprecated('Use liveAudienceStateDescriptor instead')
const LiveAudienceState$json = {
  '1': 'LiveAudienceState',
  '2': [
    {'1': 'isFromFansTop', '3': 1, '4': 1, '5': 8, '10': 'isFromFansTop'},
    {'1': 'isKoi', '3': 2, '4': 1, '5': 8, '10': 'isKoi'},
    {'1': 'assistantType', '3': 3, '4': 1, '5': 14, '6': '.kuaishouPubf.AssistantType', '10': 'assistantType'},
    {'1': 'fansGroupIntimacyLevel', '3': 4, '4': 1, '5': 13, '10': 'fansGroupIntimacyLevel'},
    {'1': 'nameplate', '3': 5, '4': 1, '5': 11, '6': '.kuaishouPubf.GzoneNameplate', '10': 'nameplate'},
    {'1': 'liveFansGroupState', '3': 6, '4': 1, '5': 11, '6': '.kuaishouPubf.LiveFansGroupState', '10': 'liveFansGroupState'},
    {'1': 'wealthGrade', '3': 7, '4': 1, '5': 13, '10': 'wealthGrade'},
    {'1': 'badgeKey', '3': 8, '4': 1, '5': 9, '10': 'badgeKey'},
    {'1': 'liveAudienceState_11', '3': 11, '4': 3, '5': 11, '6': '.kuaishouPubf.LiveAudienceState.LiveAudienceState_11', '10': 'liveAudienceState11'},
  ],
  '3': [LiveAudienceState_LiveAudienceState_11$json],
};

@$core.Deprecated('Use liveAudienceStateDescriptor instead')
const LiveAudienceState_LiveAudienceState_11$json = {
  '1': 'LiveAudienceState_11',
  '2': [
    {'1': 'liveAudienceState_11_1', '3': 1, '4': 1, '5': 11, '6': '.kuaishouPubf.LiveAudienceState.LiveAudienceState_11.LiveAudienceState_11_1', '10': 'liveAudienceState111'},
  ],
  '3': [LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1$json],
};

@$core.Deprecated('Use liveAudienceStateDescriptor instead')
const LiveAudienceState_LiveAudienceState_11_LiveAudienceState_11_1$json = {
  '1': 'LiveAudienceState_11_1',
  '2': [
    {'1': 'badgeIcon', '3': 2, '4': 1, '5': 9, '10': 'badgeIcon'},
    {'1': 'badgeName', '3': 4, '4': 1, '5': 9, '10': 'badgeName'},
  ],
};

/// Descriptor for `LiveAudienceState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List liveAudienceStateDescriptor = $convert.base64Decode(
    'ChFMaXZlQXVkaWVuY2VTdGF0ZRIkCg1pc0Zyb21GYW5zVG9wGAEgASgIUg1pc0Zyb21GYW5zVG'
    '9wEhQKBWlzS29pGAIgASgIUgVpc0tvaRJBCg1hc3Npc3RhbnRUeXBlGAMgASgOMhsua3VhaXNo'
    'b3VQdWJmLkFzc2lzdGFudFR5cGVSDWFzc2lzdGFudFR5cGUSNgoWZmFuc0dyb3VwSW50aW1hY3'
    'lMZXZlbBgEIAEoDVIWZmFuc0dyb3VwSW50aW1hY3lMZXZlbBI6CgluYW1lcGxhdGUYBSABKAsy'
    'HC5rdWFpc2hvdVB1YmYuR3pvbmVOYW1lcGxhdGVSCW5hbWVwbGF0ZRJQChJsaXZlRmFuc0dyb3'
    'VwU3RhdGUYBiABKAsyIC5rdWFpc2hvdVB1YmYuTGl2ZUZhbnNHcm91cFN0YXRlUhJsaXZlRmFu'
    'c0dyb3VwU3RhdGUSIAoLd2VhbHRoR3JhZGUYByABKA1SC3dlYWx0aEdyYWRlEhoKCGJhZGdlS2'
    'V5GAggASgJUghiYWRnZUtleRJnChRsaXZlQXVkaWVuY2VTdGF0ZV8xMRgLIAMoCzI0Lmt1YWlz'
    'aG91UHViZi5MaXZlQXVkaWVuY2VTdGF0ZS5MaXZlQXVkaWVuY2VTdGF0ZV8xMVITbGl2ZUF1ZG'
    'llbmNlU3RhdGUxMRrwAQoUTGl2ZUF1ZGllbmNlU3RhdGVfMTESgQEKFmxpdmVBdWRpZW5jZVN0'
    'YXRlXzExXzEYASABKAsySy5rdWFpc2hvdVB1YmYuTGl2ZUF1ZGllbmNlU3RhdGUuTGl2ZUF1ZG'
    'llbmNlU3RhdGVfMTEuTGl2ZUF1ZGllbmNlU3RhdGVfMTFfMVIUbGl2ZUF1ZGllbmNlU3RhdGUx'
    'MTEaVAoWTGl2ZUF1ZGllbmNlU3RhdGVfMTFfMRIcCgliYWRnZUljb24YAiABKAlSCWJhZGdlSW'
    'NvbhIcCgliYWRnZU5hbWUYBCABKAlSCWJhZGdlTmFtZQ==');

@$core.Deprecated('Use liveFansGroupStateDescriptor instead')
const LiveFansGroupState$json = {
  '1': 'LiveFansGroupState',
  '2': [
    {'1': 'intimacyLevel', '3': 1, '4': 1, '5': 13, '10': 'intimacyLevel'},
    {'1': 'enterRoomSpecialEffect', '3': 2, '4': 1, '5': 13, '10': 'enterRoomSpecialEffect'},
  ],
};

/// Descriptor for `LiveFansGroupState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List liveFansGroupStateDescriptor = $convert.base64Decode(
    'ChJMaXZlRmFuc0dyb3VwU3RhdGUSJAoNaW50aW1hY3lMZXZlbBgBIAEoDVINaW50aW1hY3lMZX'
    'ZlbBI2ChZlbnRlclJvb21TcGVjaWFsRWZmZWN0GAIgASgNUhZlbnRlclJvb21TcGVjaWFsRWZm'
    'ZWN0');

@$core.Deprecated('Use gzoneNameplateDescriptor instead')
const GzoneNameplate$json = {
  '1': 'GzoneNameplate',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'urls', '3': 3, '4': 3, '5': 11, '6': '.kuaishouPubf.PicUrl', '10': 'urls'},
  ],
};

/// Descriptor for `GzoneNameplate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gzoneNameplateDescriptor = $convert.base64Decode(
    'Cg5Hem9uZU5hbWVwbGF0ZRIOCgJpZBgBIAEoA1ICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIoCg'
    'R1cmxzGAMgAygLMhQua3VhaXNob3VQdWJmLlBpY1VybFIEdXJscw==');

@$core.Deprecated('Use picUrlDescriptor instead')
const PicUrl$json = {
  '1': 'PicUrl',
  '2': [
    {'1': 'cdn', '3': 1, '4': 1, '5': 9, '10': 'cdn'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'urlPattern', '3': 3, '4': 1, '5': 9, '10': 'urlPattern'},
    {'1': 'ip', '3': 4, '4': 1, '5': 9, '10': 'ip'},
  ],
};

/// Descriptor for `PicUrl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List picUrlDescriptor = $convert.base64Decode(
    'CgZQaWNVcmwSEAoDY2RuGAEgASgJUgNjZG4SEAoDdXJsGAIgASgJUgN1cmwSHgoKdXJsUGF0dG'
    'VybhgDIAEoCVIKdXJsUGF0dGVybhIOCgJpcBgEIAEoCVICaXA=');

@$core.Deprecated('Use sCWebFeedPushDescriptor instead')
const SCWebFeedPush$json = {
  '1': 'SCWebFeedPush',
  '2': [
    {'1': 'displayWatchingCount', '3': 1, '4': 1, '5': 9, '10': 'displayWatchingCount'},
    {'1': 'displayLikeCount', '3': 2, '4': 1, '5': 9, '10': 'displayLikeCount'},
    {'1': 'pendingLikeCount', '3': 3, '4': 1, '5': 4, '10': 'pendingLikeCount'},
    {'1': 'pushInterval', '3': 4, '4': 1, '5': 4, '10': 'pushInterval'},
    {'1': 'commentFeeds', '3': 5, '4': 3, '5': 11, '6': '.kuaishouPubf.WebCommentFeed', '10': 'commentFeeds'},
    {'1': 'commentCursor', '3': 6, '4': 1, '5': 9, '10': 'commentCursor'},
    {'1': 'comboCommentFeed', '3': 7, '4': 3, '5': 11, '6': '.kuaishouPubf.WebComboCommentFeed', '10': 'comboCommentFeed'},
    {'1': 'likeFeeds', '3': 8, '4': 3, '5': 11, '6': '.kuaishouPubf.WebLikeFeed', '10': 'likeFeeds'},
    {'1': 'giftFeeds', '3': 9, '4': 3, '5': 11, '6': '.kuaishouPubf.WebGiftFeed', '10': 'giftFeeds'},
    {'1': 'giftCursor', '3': 10, '4': 1, '5': 9, '10': 'giftCursor'},
    {'1': 'systemNoticeFeeds', '3': 11, '4': 3, '5': 11, '6': '.kuaishouPubf.WebSystemNoticeFeed', '10': 'systemNoticeFeeds'},
    {'1': 'shareFeeds', '3': 12, '4': 3, '5': 11, '6': '.kuaishouPubf.WebShareFeed', '10': 'shareFeeds'},
  ],
};

/// Descriptor for `SCWebFeedPush`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sCWebFeedPushDescriptor = $convert.base64Decode(
    'Cg1TQ1dlYkZlZWRQdXNoEjIKFGRpc3BsYXlXYXRjaGluZ0NvdW50GAEgASgJUhRkaXNwbGF5V2'
    'F0Y2hpbmdDb3VudBIqChBkaXNwbGF5TGlrZUNvdW50GAIgASgJUhBkaXNwbGF5TGlrZUNvdW50'
    'EioKEHBlbmRpbmdMaWtlQ291bnQYAyABKARSEHBlbmRpbmdMaWtlQ291bnQSIgoMcHVzaEludG'
    'VydmFsGAQgASgEUgxwdXNoSW50ZXJ2YWwSQAoMY29tbWVudEZlZWRzGAUgAygLMhwua3VhaXNo'
    'b3VQdWJmLldlYkNvbW1lbnRGZWVkUgxjb21tZW50RmVlZHMSJAoNY29tbWVudEN1cnNvchgGIA'
    'EoCVINY29tbWVudEN1cnNvchJNChBjb21ib0NvbW1lbnRGZWVkGAcgAygLMiEua3VhaXNob3VQ'
    'dWJmLldlYkNvbWJvQ29tbWVudEZlZWRSEGNvbWJvQ29tbWVudEZlZWQSNwoJbGlrZUZlZWRzGA'
    'ggAygLMhkua3VhaXNob3VQdWJmLldlYkxpa2VGZWVkUglsaWtlRmVlZHMSNwoJZ2lmdEZlZWRz'
    'GAkgAygLMhkua3VhaXNob3VQdWJmLldlYkdpZnRGZWVkUglnaWZ0RmVlZHMSHgoKZ2lmdEN1cn'
    'NvchgKIAEoCVIKZ2lmdEN1cnNvchJPChFzeXN0ZW1Ob3RpY2VGZWVkcxgLIAMoCzIhLmt1YWlz'
    'aG91UHViZi5XZWJTeXN0ZW1Ob3RpY2VGZWVkUhFzeXN0ZW1Ob3RpY2VGZWVkcxI6CgpzaGFyZU'
    'ZlZWRzGAwgAygLMhoua3VhaXNob3VQdWJmLldlYlNoYXJlRmVlZFIKc2hhcmVGZWVkcw==');

@$core.Deprecated('Use webShareFeedDescriptor instead')
const WebShareFeed$json = {
  '1': 'WebShareFeed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.kuaishouPubf.SimpleUserInfo', '10': 'user'},
    {'1': 'time', '3': 3, '4': 1, '5': 4, '10': 'time'},
    {'1': 'thirdPartyPlatform', '3': 4, '4': 1, '5': 13, '10': 'thirdPartyPlatform'},
    {'1': 'sortRank', '3': 5, '4': 1, '5': 4, '10': 'sortRank'},
    {'1': 'liveAssistantType', '3': 6, '4': 1, '5': 14, '6': '.kuaishouPubf.WebLiveAssistantType', '10': 'liveAssistantType'},
    {'1': 'deviceHash', '3': 7, '4': 1, '5': 9, '10': 'deviceHash'},
  ],
};

/// Descriptor for `WebShareFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webShareFeedDescriptor = $convert.base64Decode(
    'CgxXZWJTaGFyZUZlZWQSDgoCaWQYASABKAlSAmlkEjAKBHVzZXIYAiABKAsyHC5rdWFpc2hvdV'
    'B1YmYuU2ltcGxlVXNlckluZm9SBHVzZXISEgoEdGltZRgDIAEoBFIEdGltZRIuChJ0aGlyZFBh'
    'cnR5UGxhdGZvcm0YBCABKA1SEnRoaXJkUGFydHlQbGF0Zm9ybRIaCghzb3J0UmFuaxgFIAEoBF'
    'IIc29ydFJhbmsSUAoRbGl2ZUFzc2lzdGFudFR5cGUYBiABKA4yIi5rdWFpc2hvdVB1YmYuV2Vi'
    'TGl2ZUFzc2lzdGFudFR5cGVSEWxpdmVBc3Npc3RhbnRUeXBlEh4KCmRldmljZUhhc2gYByABKA'
    'lSCmRldmljZUhhc2g=');

@$core.Deprecated('Use webSystemNoticeFeedDescriptor instead')
const WebSystemNoticeFeed$json = {
  '1': 'WebSystemNoticeFeed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.kuaishouPubf.SimpleUserInfo', '10': 'user'},
    {'1': 'time', '3': 3, '4': 1, '5': 4, '10': 'time'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'displayDuration', '3': 5, '4': 1, '5': 4, '10': 'displayDuration'},
    {'1': 'sortRank', '3': 6, '4': 1, '5': 4, '10': 'sortRank'},
    {'1': 'displayType', '3': 7, '4': 1, '5': 14, '6': '.kuaishouPubf.DisplayType', '10': 'displayType'},
  ],
};

/// Descriptor for `WebSystemNoticeFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webSystemNoticeFeedDescriptor = $convert.base64Decode(
    'ChNXZWJTeXN0ZW1Ob3RpY2VGZWVkEg4KAmlkGAEgASgJUgJpZBIwCgR1c2VyGAIgASgLMhwua3'
    'VhaXNob3VQdWJmLlNpbXBsZVVzZXJJbmZvUgR1c2VyEhIKBHRpbWUYAyABKARSBHRpbWUSGAoH'
    'Y29udGVudBgEIAEoCVIHY29udGVudBIoCg9kaXNwbGF5RHVyYXRpb24YBSABKARSD2Rpc3BsYX'
    'lEdXJhdGlvbhIaCghzb3J0UmFuaxgGIAEoBFIIc29ydFJhbmsSOwoLZGlzcGxheVR5cGUYByAB'
    'KA4yGS5rdWFpc2hvdVB1YmYuRGlzcGxheVR5cGVSC2Rpc3BsYXlUeXBl');

@$core.Deprecated('Use webGiftFeedDescriptor instead')
const WebGiftFeed$json = {
  '1': 'WebGiftFeed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.kuaishouPubf.SimpleUserInfo', '10': 'user'},
    {'1': 'time', '3': 3, '4': 1, '5': 4, '10': 'time'},
    {'1': 'giftId', '3': 4, '4': 1, '5': 13, '10': 'giftId'},
    {'1': 'sortRank', '3': 5, '4': 1, '5': 4, '10': 'sortRank'},
    {'1': 'mergeKey', '3': 6, '4': 1, '5': 9, '10': 'mergeKey'},
    {'1': 'batchSize', '3': 7, '4': 1, '5': 13, '10': 'batchSize'},
    {'1': 'comboCount', '3': 8, '4': 1, '5': 13, '10': 'comboCount'},
    {'1': 'rank', '3': 9, '4': 1, '5': 13, '10': 'rank'},
    {'1': 'expireDuration', '3': 10, '4': 1, '5': 4, '10': 'expireDuration'},
    {'1': 'clientTimestamp', '3': 11, '4': 1, '5': 4, '10': 'clientTimestamp'},
    {'1': 'slotDisplayDuration', '3': 12, '4': 1, '5': 4, '10': 'slotDisplayDuration'},
    {'1': 'starLevel', '3': 13, '4': 1, '5': 13, '10': 'starLevel'},
    {'1': 'styleType', '3': 14, '4': 1, '5': 14, '6': '.kuaishouPubf.StyleType', '10': 'styleType'},
    {'1': 'liveAssistantType', '3': 15, '4': 1, '5': 14, '6': '.kuaishouPubf.WebLiveAssistantType', '10': 'liveAssistantType'},
    {'1': 'deviceHash', '3': 16, '4': 1, '5': 9, '10': 'deviceHash'},
    {'1': 'danmakuDisplay', '3': 17, '4': 1, '5': 8, '10': 'danmakuDisplay'},
  ],
};

/// Descriptor for `WebGiftFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webGiftFeedDescriptor = $convert.base64Decode(
    'CgtXZWJHaWZ0RmVlZBIOCgJpZBgBIAEoCVICaWQSMAoEdXNlchgCIAEoCzIcLmt1YWlzaG91UH'
    'ViZi5TaW1wbGVVc2VySW5mb1IEdXNlchISCgR0aW1lGAMgASgEUgR0aW1lEhYKBmdpZnRJZBgE'
    'IAEoDVIGZ2lmdElkEhoKCHNvcnRSYW5rGAUgASgEUghzb3J0UmFuaxIaCghtZXJnZUtleRgGIA'
    'EoCVIIbWVyZ2VLZXkSHAoJYmF0Y2hTaXplGAcgASgNUgliYXRjaFNpemUSHgoKY29tYm9Db3Vu'
    'dBgIIAEoDVIKY29tYm9Db3VudBISCgRyYW5rGAkgASgNUgRyYW5rEiYKDmV4cGlyZUR1cmF0aW'
    '9uGAogASgEUg5leHBpcmVEdXJhdGlvbhIoCg9jbGllbnRUaW1lc3RhbXAYCyABKARSD2NsaWVu'
    'dFRpbWVzdGFtcBIwChNzbG90RGlzcGxheUR1cmF0aW9uGAwgASgEUhNzbG90RGlzcGxheUR1cm'
    'F0aW9uEhwKCXN0YXJMZXZlbBgNIAEoDVIJc3RhckxldmVsEjUKCXN0eWxlVHlwZRgOIAEoDjIX'
    'Lmt1YWlzaG91UHViZi5TdHlsZVR5cGVSCXN0eWxlVHlwZRJQChFsaXZlQXNzaXN0YW50VHlwZR'
    'gPIAEoDjIiLmt1YWlzaG91UHViZi5XZWJMaXZlQXNzaXN0YW50VHlwZVIRbGl2ZUFzc2lzdGFu'
    'dFR5cGUSHgoKZGV2aWNlSGFzaBgQIAEoCVIKZGV2aWNlSGFzaBImCg5kYW5tYWt1RGlzcGxheR'
    'gRIAEoCFIOZGFubWFrdURpc3BsYXk=');

@$core.Deprecated('Use webLikeFeedDescriptor instead')
const WebLikeFeed$json = {
  '1': 'WebLikeFeed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.kuaishouPubf.SimpleUserInfo', '10': 'user'},
    {'1': 'sortRank', '3': 3, '4': 1, '5': 4, '10': 'sortRank'},
    {'1': 'deviceHash', '3': 4, '4': 1, '5': 9, '10': 'deviceHash'},
  ],
};

/// Descriptor for `WebLikeFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webLikeFeedDescriptor = $convert.base64Decode(
    'CgtXZWJMaWtlRmVlZBIOCgJpZBgBIAEoCVICaWQSMAoEdXNlchgCIAEoCzIcLmt1YWlzaG91UH'
    'ViZi5TaW1wbGVVc2VySW5mb1IEdXNlchIaCghzb3J0UmFuaxgDIAEoBFIIc29ydFJhbmsSHgoK'
    'ZGV2aWNlSGFzaBgEIAEoCVIKZGV2aWNlSGFzaA==');

@$core.Deprecated('Use webComboCommentFeedDescriptor instead')
const WebComboCommentFeed$json = {
  '1': 'WebComboCommentFeed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'content', '3': 2, '4': 1, '5': 9, '10': 'content'},
    {'1': 'comboCount', '3': 3, '4': 1, '5': 13, '10': 'comboCount'},
  ],
};

/// Descriptor for `WebComboCommentFeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List webComboCommentFeedDescriptor = $convert.base64Decode(
    'ChNXZWJDb21ib0NvbW1lbnRGZWVkEg4KAmlkGAEgASgJUgJpZBIYCgdjb250ZW50GAIgASgJUg'
    'djb250ZW50Eh4KCmNvbWJvQ291bnQYAyABKA1SCmNvbWJvQ291bnQ=');

