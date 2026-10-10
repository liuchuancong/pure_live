// Module: lib/features/settings/settings_page.dart
// Purpose: The settings tab: runtime facts today, preference groups as the
// corresponding services land.
// Author: liuchuancong
// Created: 2026-10-09

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:file_picker/file_picker.dart';
import 'package:pure_live_adaptive/pure_live_adaptive.dart';
import 'package:pure_live_release/pure_live_release.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live_design/pure_live_design.dart';

import '../../app/appearance.dart';
import '../../app/di.dart';
import '../../app/update_transport.dart';
import '../../app/user_backup.dart';

final class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('外观'),
          const _AppearanceSection(),
          const _SectionHeader('通用'),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('从发布源获取最新版本'),
            onTap: () => _checkUpdate(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份用户数据'),
            subtitle: const Text('收藏、历史、歌单与外观导出为文件'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复用户数据'),
            subtitle: const Text('从备份文件恢复,恢复后需重启应用'),
            onTap: () => _importBackup(context, ref),
          ),
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

/// The 外观 group: style, seed, mode and background, written through the
/// appearance controller and persisted on every change.
final class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('界面风格'),
          trailing: DropdownButton<AdaptiveUiStyle>(
            value: appearance.style,
            items: <DropdownMenuItem<AdaptiveUiStyle>>[
              for (final style in AdaptiveStyleRegistry.withAllVariants().available)
                DropdownMenuItem(value: style, child: Text(style.label)),
            ],
            onChanged: (style) => style == null ? null : controller.update(appearance.copyWith(style: style)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.colorize),
          title: const Text('主题色'),
          subtitle: Row(
            children: <Widget>[
              for (final seed in const <Color>[
                Color(0xFF6A5AE0),
                Color(0xFF2196F3),
                Color(0xFF4CAF50),
                Color(0xFFFF9800),
                Color(0xFFE91E63),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => controller.update(appearance.copyWith(seed: seed)),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: seed,
                      child: appearance.seed == seed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('深浅模式'),
          trailing: DropdownButton<ThemeMode>(
            value: appearance.themeMode,
            items: const <DropdownMenuItem<ThemeMode>>[
              DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
            ],
            onChanged: (mode) => mode == null ? null : controller.update(appearance.copyWith(themeMode: mode)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.wallpaper),
          title: const Text('背景'),
          subtitle: Text(_backgroundLabel(appearance.background)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editBackground(context, controller, appearance),
        ),
      ],
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

String _backgroundLabel(BackgroundConfig background) {
  if (!background.isActive) {
    return '未启用';
  }
  return switch (background.kind) {
    BackgroundKind.color => '纯色',
    BackgroundKind.image => '图片',
    BackgroundKind.video => '视频',
    BackgroundKind.none => '未启用',
  };
}

Future<void> _editBackground(BuildContext context, AppearanceController controller, AppearanceConfig appearance) async {
  final kindController = TextEditingController(text: appearance.background.source ?? '');
  final opacity = ValueNotifier<double>(appearance.background.opacity);
  final kind = ValueNotifier<BackgroundKind>(
    appearance.background.isActive ? appearance.background.kind : BackgroundKind.image,
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('背景设置'),
      content: SizedBox(
        width: 360,
        child: ListBody(
          children: <Widget>[
            ValueListenableBuilder<BackgroundKind>(
              valueListenable: kind,
              builder: (context, value, _) => DropdownButton<BackgroundKind>(
                value: value,
                isExpanded: true,
                items: const <DropdownMenuItem<BackgroundKind>>[
                  DropdownMenuItem(value: BackgroundKind.none, child: Text('无')),
                  DropdownMenuItem(value: BackgroundKind.color, child: Text('纯色(RRGGBB)')),
                  DropdownMenuItem(value: BackgroundKind.image, child: Text('图片(地址或文件路径)')),
                  DropdownMenuItem(value: BackgroundKind.video, child: Text('视频(地址或文件路径)')),
                ],
                onChanged: (next) => kind.value = next ?? BackgroundKind.image,
              ),
            ),
            ValueListenableBuilder<BackgroundKind>(
              valueListenable: kind,
              builder: (context, value, _) => value == BackgroundKind.none || value == BackgroundKind.color
                  ? TextField(
                      controller: kindController,
                      decoration: value == BackgroundKind.color
                          ? const InputDecoration(hintText: '6 位十六进制,例如 101828')
                          : const InputDecoration(hintText: '图片/视频的地址或文件路径'),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            const Text('内容遮挡强度'),
            ValueListenableBuilder<double>(
              valueListenable: opacity,
              builder: (context, value, _) => Slider(
                value: value,
                min: 0,
                max: 1,
                divisions: 10,
                label: '${(value * 100).round()}%',
                onChanged: (next) => opacity.value = next,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
      ],
    ),
  );
  final source = kindController.text.trim();
  kindController.dispose();
  if (saved != true) {
    return;
  }
  await controller.update(
    appearance.copyWith(
      background: BackgroundConfig(
        kind: kind.value,
        source: kind.value == BackgroundKind.none ? null : source,
        opacity: opacity.value,
      ),
    ),
  );
}

/// The release feed this build checks. One source of truth for the shell.
const String kReleaseFeedUrl = 'https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/releases.json';

UpdateTarget _currentTarget() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => UpdateTarget.android,
    TargetPlatform.windows => UpdateTarget.windows,
    TargetPlatform.linux => UpdateTarget.linux,
    TargetPlatform.macOS => UpdateTarget.macos,
    _ => UpdateTarget.windows,
  };
}

Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final info = await PackageInfo.fromPlatform();
  // The checker reads through the runtime's client rather than building its own: pure_live_release is L0 and
  // cannot depend on the network package, and a client created here would have nobody left to close it.
  final checker = UpdateChecker(
    feedUrl: kReleaseFeedUrl,
    transport: NetworkUpdateFeedTransport(ref.read(runtimeProvider).network),
    target: _currentTarget(),
  );
  messenger.showSnackBar(const SnackBar(content: Text('正在检查更新…')));
  final result = await checker.check(AppVersion.parse(info.version));
  if (!context.mounted) {
    return;
  }
  final decision = result.decide();
  final theme = Theme.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(decision.shouldUpdate ? '发现新版本 ${result.entry!.title}' : '已是最新版本'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (result.error != null) Text('检查失败:${result.error}', style: theme.textTheme.bodySmall),
            if (result.error == null)
              Text(
                '当前版本 ${info.version} · 最新 ${result.entry!.version.full} (${result.entry!.date})',
                style: theme.textTheme.bodySmall,
              ),
            if (decision.reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  decision.reason!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (result.entry?.changelog != null && result.entry!.changelog!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  result.entry!.changelog!,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        if (result.entry?.githubUrl != null)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(result.entry!.githubUrl!), mode: LaunchMode.externalApplication),
            child: const Text('打开发布页'),
          ),
        if (result.asset != null)
          FilledButton(
            onPressed: () => launchUrl(Uri.parse(result.asset!.url), mode: LaunchMode.externalApplication),
            child: const Text('下载安装包'),
          ),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭')),
      ],
    ),
  );
}

Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
  final runtime = ref.read(runtimeProvider);
  final document = await buildUserBackup(runtime);
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(document));
  final destination = await FilePicker.saveFile(fileName: 'purelive-backup.json', bytes: Uint8List.fromList(bytes));
  if (destination == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出到 \$destination')));
}

Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
  final files = await FilePicker.pickFiles(allowedExtensions: <String>['json'], type: FileType.custom);
  final path = files.isEmpty ? null : files.single.path;
  if (path == null || !context.mounted) {
    return;
  }
  // Everything the flow needs is captured before the first await: no
  // BuildContext use crosses an async gap.
  final runtime = ref.read(runtimeProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final document = decodeBackupDocument(await File(path).readAsString());
    final (lines, _) = await restoreUserBackup(runtime, document);
    final summary = lines.join('\n');
    if (!context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('恢复完成,重启应用后生效')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复完成'),
        content: Text('$summary\n重启应用后生效。'),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('知道了'))],
      ),
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('恢复失败:$error')));
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
