import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;

/// The settings domain's index page.
///
/// Still mostly an entry list — the cluster's pages (appearance, danmaku,
/// font, logs, backup, …) land with their own waves — but the desktop's
/// window choices live here already, because they are shell-wide rather than
/// a page's concern.
final class SettingsPage extends ConsumerStatefulWidget {
  /// The settings index page.
  const new({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends ConsumerState<SettingsPage> {
  // The live selection: the store's value updates immediately even though
  // the frame itself is a next-start change, and the hint below says so.
  ShellWindowChrome? _chromeChoice;

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(environmentProvider).runtime.kind;
    final onDesktop = kind == PlatformKind.windows || kind == PlatformKind.macos || kind == PlatformKind.linux;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.tabs.settings)),
      body: onDesktop
          ? ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), children: [_windowSection(context)])
          : LiveEmpty(title: context.t.common.empty),
    );
  }

  Widget _windowSection(BuildContext context) {
    final t = context.t.shellSettings;
    final store = ref.read(shellPreferencesProvider);
    final chrome = _chromeChoice ?? store?.value.windowChrome ?? ShellWindowChrome.app;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.sectionWindow, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(t.titleBar, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<ShellWindowChrome>(
              segments: [
                ButtonSegment(value: ShellWindowChrome.app, label: Text(t.titleBarApp)),
                ButtonSegment(value: ShellWindowChrome.system, label: Text(t.titleBarSystem)),
              ],
              selected: {chrome},
              onSelectionChanged: (selection) {
                final next = selection.first;
                setState(() => _chromeChoice = next);
                unawaited(store?.update((preferences) => preferences.copyWith(windowChrome: next)));
              },
            ),
            const SizedBox(height: 8),
            Text(
              t.titleBarHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
