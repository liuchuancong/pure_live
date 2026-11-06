import 'dart:io' show File, FileSystemException;
import 'dart:ui' show PlatformDispatcher;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/logging/app_log.dart' show exportAppLog;

/// The screen a failed boot shows instead of the app.
///
/// The widget tree is not up — no theme, no router, no translations — so
/// this renders a bare `DsScope` carrying the failure in the system's own
/// language, with the two moves that need nothing else: a retry (the boot
/// runs again from the top) and a log export (the in-memory ring survives
/// a storage that never opened, so there is always something to hand in).
final class StartupErrorPage extends StatefulWidget {
  /// An error screen for the [error] the bootstrap raised.
  ///
  /// [onRetry] absent means the entry point cannot run the boot again and
  /// the button does not render.
  const StartupErrorPage({required this.error, this.onRetry, super.key});

  /// The start-up failure to show.
  final Object error;

  /// Runs the boot again; a success hands control to the real app.
  final Future<void> Function()? onRetry;

  @override
  State<StartupErrorPage> createState() => _StartupErrorPageState();
}

final class _StartupErrorPageState extends State<StartupErrorPage> {
  bool _busy = false;
  String? _note;

  /// The system's language decides the page's strings: the settings never
  /// opened, so the stored choice does not exist yet.
  bool get _zh => PlatformDispatcher.instance.locale.languageCode.startsWith('zh');

  String _t(String zh, String en) => _zh ? zh : en;

  /// Why the boot failed, in the viewer's words: a file failure names the
  /// path and the system's reason for it; everything else is the error
  /// itself, shortened to what a screen can hold.
  String get _reason {
    String shorten(String text) {
      final line = text.trim().replaceAll('\n', ' ');
      return line.length <= 240 ? line : '${line.substring(0, 240)}…';
    }

    final error = widget.error;
    if (error is FileSystemException) {
      final detail = error.osError?.message ?? error.message;
      return _t('文件错误：${error.path}\n${shorten(detail)}', 'File error: ${error.path}\n${shorten(detail)}');
    }
    return _t('数据错误：', 'Data error: ') + shorten('$error');
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: _t('选择导出位置', 'Choose where to export'));
      if (selected == null || selected.trim().isEmpty) return;
      final file = File(p.join(selected.trim(), 'PureLive-startup-failure.txt'));
      await file.writeAsString(exportAppLog(), flush: true);
      _note = _t('已导出：', 'Exported: ') + file.path;
    } on Object {
      _note = _t('导出失败', 'Export failed');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _retry() async {
    if (_busy || widget.onRetry == null) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      await widget.onRetry!();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // The app's own Directionality lives under the router, which never
      // mounted; the error page must still be able to draw text.
      textDirection: TextDirection.ltr,
      child: DsScope(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s12,
              children: [
                DsIcon(DsIcons.error, color: DsTheme.colorsOf(context).danger.text),
                Text(_t('启动失败', 'Startup failed'), style: DsTheme.typographyOf(context).title),
                Text(
                  '$_reason\n${_t('可以重试；若仍失败，请导出日志反馈。', 'You can retry; if it keeps failing, export the log and report it.')}',
                  textAlign: TextAlign.center,
                  style: DsTheme.typographyOf(context).small,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s8,
                  children: [
                    if (widget.onRetry != null)
                      DsButton(onPressed: _busy ? null : _retry, child: Text(_t('重试', 'Retry'))),
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      onPressed: _busy ? null : _export,
                      child: Text(_t('导出日志', 'Export log')),
                    ),
                  ],
                ),
                if (_note != null)
                  Text(_note!, textAlign: TextAlign.center, style: DsTheme.typographyOf(context).caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
