/// The Bilibili adapter: the reference platform implementation for the
/// `platforms/<site>/` layout — site, parsers, danmaku packet protocol,
/// mapper and session under one boundary.
///
/// Everything here is internal to the package unless the app needs the
/// concrete class for DI; the `LiveSite`/`LiveDanmakuCapability`
/// interfaces are what the rest of the app consumes.
library;

export 'bilibili/bilibili_models.dart';
export 'bilibili/bilibili_site.dart';
export 'bilibili/danmaku/bilibili_mapper.dart';
export 'bilibili/danmaku/bilibili_packet.dart';
export 'bilibili/danmaku/bilibili_session.dart';
export 'bilibili/parsers/bilibili_parser.dart';
