/// Baidu Live's platform models (`BaiduliveRoom`, `BaiduliveCategory`,
/// `BaiduliveVariant`, `BaiduliveSource`, `BaiduliveState`, `BaidulivePage` and
/// the `BaiduliveDanmakuArgs` the chat carries) live beside the parser that
/// reads them and the codec that hands the chat arguments on. This barrel is
/// kept for the `api/` layout: it declares nothing itself, so importing it can
/// never shadow the real definitions.
library;

export 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_codec.dart';
export 'package:live_sites/src/platforms/baidulive/parsers/baidulive_room_parser.dart';
