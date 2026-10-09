// Module: lib/features/settings/settings_page.dart
// Purpose: The settings tab: runtime facts today, preference groups as the
// corresponding services land.
// Author: liuchuancong
// Created: 2026-10-09

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/di.dart';

final class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('运行时'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('数据目录'),
            subtitle: Text(runtime.dataDirectory.path),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('已注册内容源'),
            subtitle: Text('${runtime.capabilities.length} 个'),
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('扩展网关'),
            subtitle: Text(runtime.gateway.runtimeType.toString()),
          ),
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: const Text('v2 开发版(重构中)'),
          ),
          const FutureBuilderVersionTile(),
        ],
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Reads the real package identity from the platform. Kept separate so the
/// version row is its own async unit and a platform failure cannot take the
/// whole settings list down.
final class FutureBuilderVersionTile extends StatelessWidget {
  const FutureBuilderVersionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.tag),
          title: const Text('包信息'),
          subtitle: Text(info == null ? '读取中…' : '${info.packageName} · ${info.version}+${info.buildNumber}'),
        );
      },
    );
  }
}
