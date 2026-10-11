import 'dart:io';

import 'package:live_log/live_log.dart';

/// End-to-end demo of the `live_log` facade: category views, level
/// policies, differentiated sinks, sanitisation, lazy messages, context,
/// error reporting, memory export, file rotation and sink fault isolation.
///
/// Run from `packages/live_log`:
/// ```sh
/// dart run example/live_log_demo.dart
/// ```
Future<void> main() async {
  // ── 1. Sinks: console takes everything; the file only warnings+; memory
  //       keeps the newest 200 for queries and export. ──────────────────
  final memory = MemorySink(capacity: 200);
  final logDir = await Directory.systemTemp.createTemp('live_log_demo_');
  final fileSink = FileSink(logDir, baseName: 'demo', maxFileBytes: 2 * 1024, maxFiles: 3);
  const console = StdoutConsoleSink();

  final log = LiveLog.root(
    sinks: [
      console,
      SinkBinding(fileSink, minLevel: LogLevel.warning),
      memory,
    ],
    minLevel: LogLevel.debug,
    // Category override: player.mpv is noisy, keep only warnings and up.
    categoryMinLevels: {'player.mpv': LogLevel.warning},
  );

  final net = log.forCategory('live_net');
  final socket = net.forCategory('socket');
  final bili = log.forCategory('sites').forCategory('bilibili').withContext({
    'siteId': 'bilibili',
    'requestId': 'req-42',
  });

  // ── 2. Levels and category paths ────────────────────────────────────
  log.info('应用启动', fields: {'version': '4.1.0'});
  socket.debug('帧解码完成', fields: {'size': 512});
  bili.info('房间详情 https://api.live.bilibili.com/room?sign=deadbeef&cid=777');

  log.forCategory('player').forCategory('mpv')
    ..info('这条被分类覆盖挡住（player.mpv 只收 warning+）')
    ..warning('mpv 警告：丢帧 2.1%');

  // ── 3. Sanitisation: signed URLs, cookies, nested fields ────────────
  bili.info('请求头 Cookie: SESSDATA=abc123; bili_jct=xyz');
  log.debug(
    '嵌套字段脱敏',
    fields: {
      'headers': {'Cookie': 'SESSDATA=secret', 'Referer': 'https://live.bilibili.com'},
      'url': 'https://api.example.com/play?token=t0k3n&q=4',
    },
  );

  // ── 4. Lazy message: the closure must NOT run below the threshold ───
  socket.trace(() {
    stdout.writeln('!!! 失败：被过滤的 trace 仍然构造了消息');
    return 'expensive trace payload';
  });
  stdout.writeln('（trace 闭包未执行，符合预期）');

  // ── 5. Runtime level tuning, including full silence ─────────────────
  log.setMinLevel(LogLevel.off, category: 'live_net.socket');
  socket.debug('这句不会出现');
  log.setMinLevel(LogLevel.debug, category: 'live_net.socket');
  socket.debug('恢复输出');

  // ── 6. Errors, stack traces, ErrorReporter ──────────────────────────
  try {
    throw StateError('上游连接被重置');
  } on Object catch (error, stackTrace) {
    net.error('拉流失败', error: error, stackTrace: stackTrace, fields: {'room': 23058});
  }
  ErrorReporter.report(bili, const FormatException('bad json token=SECRET'), null, message: '弹幕载荷解析失败');

  // ── 7. Grow the file past 2 KB to trigger rotation ──────────────────
  for (var i = 1; i <= 30; i++) {
    log.warning('填充日志制造轮转 line $i —— ${'x' * 80}');
  }
  await fileSink.flushed;

  // ── 8. Memory sink: query and export (re-sanitised on the way out) ──
  final warnings = memory.query(minLevel: LogLevel.warning);
  final recent = warnings.length <= 3 ? warnings : warnings.sublist(warnings.length - 3);
  stdout.writeln('\n─── 内存中最近 3 条 warning+ ───');
  for (final record in recent) {
    stdout.writeln('  ${record.sequence} [${record.category}] ${record.message}');
  }
  stdout
    ..writeln('\n─── JSON Lines 导出（bilibili 分类，导出前再次脱敏）───')
    ..writeln(memory.exportJsonLines(categoryPrefix: 'sites.bilibili', minLevel: LogLevel.warning))
    // ── 9. Rotated files on disk ────────────────────────────────────────
    ..writeln('\n─── 磁盘文件（base=demo, 每文件上限 2KB, 最多 3 个）───');
  for (final entry in logDir.listSync()) {
    stdout.writeln('  ${entry.uri.pathSegments.last}');
  }

  // ── 10. Fault isolation: a throwing sink never breaks the caller ────
  final isolated = LiveLog.root(sinks: [_BrokenSink(), console], minLevel: LogLevel.trace)
    ..fatal('broken sink 在前，这条仍应出现在控制台');
  await isolated.close();

  // ── 11. Hot-swap the file sink: "change log directory in settings" ──
  final logDirB = await Directory.systemTemp.createTemp('live_log_demo_b_');
  final fileSinkB = FileSink(logDirB, baseName: 'demo');
  final swapped = log.replaceSink(fileSink, fileSinkB);
  log.warning('切换后：这条只写进新目录 B');
  await fileSinkB.flushed;
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final oldFiles = logDir.listSync().map((e) => e.uri.pathSegments.last).join(', ');
  final newFiles = logDirB.listSync().map((e) => e.uri.pathSegments.last).join(', ');
  stdout
    ..writeln('\n─── 运行时切换日志目录（replaceSink=$swapped）───')
    ..writeln('  旧目录 A: $oldFiles')
    ..writeln('  新目录 B: $newFiles');

  // ── 12. Silence everything, then shut down ──────────────────────────
  log
    ..setMinLevel(LogLevel.off)
    ..fatal('这句也不会出现');
  await log.close();

  stdout.writeln('\n日志目录保留在: ${logDir.path}');
}

/// A sink that always throws, to prove [LogDispatcher] fault isolation.
final class _BrokenSink implements LogSink {
  @override
  void write(LogRecord record) => throw StateError('sink is broken');

  @override
  Future<void> close() async {}
}
