// Module: lib/features/plugins/plugin_host_page.dart
// Purpose: Plugin management: import a plugin file, toggle it, remove it.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page is the user side of the install pipeline: import validates and
// stores (disabled), the switch loads or unloads the plugin into the running
// registry, and delete removes code. Failures show as text here - a plugin
// that will not load is exactly what this page exists to explain.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live_plugin_host/pure_live_plugin_host.dart';

import '../../app/di.dart';
import '../../app/plugin_hosting.dart';

final class PluginHostPage extends ConsumerStatefulWidget {
  const PluginHostPage({super.key});

  @override
  ConsumerState<PluginHostPage> createState() => _PluginHostPageState();
}

final class _PluginHostPageState extends ConsumerState<PluginHostPage> {
  List<InstalledPlugin>? _plugins;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = ref.read(runtimeProvider).pluginStore;
    final plugins = await store.list();
    if (mounted) {
      setState(() => _plugins = plugins);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(allowedExtensions: <String>['js'], type: FileType.custom);
    if (files.isEmpty) {
      return;
    }
    final path = files.single.path;
    if (path == null) {
      return;
    }
    final store = ref.read(runtimeProvider).pluginStore;
    await _run(() async {
      final installed = await importPluginFile(store, path);
      if (mounted) {
        setState(() => _message = '已导入 ${installed.manifest.name} ${installed.manifest.version},打开开关启用');
      }
    });
  }

  Future<void> _importData() async {
    final files = await FilePicker.pickFiles(
      allowedExtensions: <String>['m3u', 'm3u8', 'json', 'txt'],
      type: FileType.custom,
    );
    if (files.isEmpty) {
      return;
    }
    final path = files.single.path;
    if (path == null) {
      return;
    }
    final store = ref.read(runtimeProvider).pluginStore;
    final name = files.single.name;
    await _run(() async {
      await importDataFile(store, path, name: name);
      if (mounted) {
        setState(() => _message = '已导入数据源 \$name(配置内容即插件),打开开关启用');
      }
    });
  }

  Future<void> _importFromUrl() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('从链接导入'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '插件、TVBox 配置或 M3U 的 http(s) 链接'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('导入')),
        ],
      ),
    );
    // Capture before disposal: the text outlives the controller, not the reverse.
    final url = controller.text.trim();
    controller.dispose();
    if (confirmed != true || url.isEmpty) {
      return;
    }
    final runtime = ref.read(runtimeProvider);
    await _run(() async {
      final installed = await importPluginUrl(runtime, runtime.pluginStore, url);
      if (mounted) {
        setState(() => _message = '已导入 ${installed.manifest.name},打开开关启用');
      }
    });
  }

  Future<void> _toggle(InstalledPlugin plugin, bool enabled) async {
    final runtime = ref.read(runtimeProvider);
    final store = runtime.pluginStore;
    await _run(() async {
      if (enabled) {
        await store.setEnabled(plugin.id, true);
        await loadEnabledPlugins(runtime, store);
      } else {
        await disablePlugin(runtime, store, plugin.id);
      }
    });
  }

  Future<void> _uninstall(InstalledPlugin plugin) async {
    final runtime = ref.read(runtimeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('卸载 ${plugin.manifest.name}'),
        content: const Text('删除插件代码;插件自己的存储数据保留。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('卸载')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final store = runtime.pluginStore;
    await _run(() async {
      runtime.capabilities.unregister(plugin.id);
      await store.uninstall(plugin.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plugins = _plugins;
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.file_open_outlined), tooltip: '导入插件文件', onPressed: _busy ? null : _import),
          IconButton(icon: const Icon(Icons.link), tooltip: '从链接导入', onPressed: _busy ? null : _importFromUrl),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '导入 M3U / TVBox 配置',
            onPressed: _busy ? null : _importData,
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(_message!, style: theme.textTheme.bodySmall),
                  ),
                if (plugins == null)
                  const Center(
                    child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                  )
                else if (plugins.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.extension_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('还没有插件', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '右上角导入 .js 插件文件;站点、影视源都以插件形式接入',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                else
                  for (final plugin in plugins)
                    ListTile(
                      title: Text('${plugin.manifest.name} ${plugin.manifest.version}'),
                      subtitle: Text(
                        '${plugin.manifest.id}\n能力:${plugin.manifest.capabilityNames.join(' / ')}',
                        style: theme.textTheme.bodySmall,
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Switch(value: plugin.enabled, onChanged: (value) => _toggle(plugin, value)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '卸载',
                            onPressed: () => _uninstall(plugin),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
