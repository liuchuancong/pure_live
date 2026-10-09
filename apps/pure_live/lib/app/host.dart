// Module: lib/app/host.dart
// Purpose: The Flutter host for an assembled runtime: it displays what is wired, and nothing else.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/architecture/system-overview.md section 1 ("App 只是 Runtime 的一个宿主"). This screen exists
// only so the branch has a launchable app again; the experience layer replaces it when that wave lands,
// which is why it renders a list of what is assembled instead of pretending to be a UI.

import 'package:flutter/material.dart';

import 'runtime.dart';

final class PureLiveApp extends StatelessWidget {
  const PureLiveApp({required this.runtime, super.key});

  final PureLiveRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PureLive',
      home: Scaffold(
        appBar: AppBar(title: const Text('PureLive v2')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const Text('运行时已装配'),
            const SizedBox(height: 8),
            for (final entry in _wired.entries)
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${entry.key}: ${entry.value}')),
            const SizedBox(height: 16),
            Text('数据目录: ${runtime.dataDirectory.path}'),
            const SizedBox(height: 8),
            const Text('UI 层与媒体运行时还没有:播放链路到引擎为止(见 docs/roadmap/w3-progress.md §4)。'),
          ],
        ),
      ),
    );
  }

  Map<String, String> get _wired => <String, String>{
    '权限': runtime.permissions.runtimeType.toString(),
    '任务': runtime.tasks.runtimeType.toString(),
    '扩展网关': runtime.gateway.runtimeType.toString(),
    '能力发现': '${runtime.capabilities.length} 个 provider',
    '解析器': '${runtime.resolvers.all.length} 个候选',
    '用户数据': '收藏 / 历史 / 歌单,各自一个文件',
    '聚合': '搜索与首页 Feed 读同一份能力注册表',
    '诊断': '${runtime.diagnostics.events.length} 条(容量 512)',
  };
}
