import 'dart:async' show unawaited;
import 'dart:io' show File, FileSystemException;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest, LiveStreamedResponse;
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart'
    show appPathsProvider, networkFactoryProvider;
import 'package:pure_live/features/version/release_builds.dart' show ReleaseBuild, formatReleaseSize;
import 'package:pure_live/l10n/translations.dart';

/// Where a download got to.
enum UpdateDownloadPhase {
  /// Fetching bytes.
  running,

  /// The file is complete and in the download folder.
  done,

  /// Stopped by the viewer; what arrived is discarded.
  cancelled,

  /// Stopped by an error; what arrived is discarded.
  failed,
}

/// Downloads one release package into the app's shared download folder and
/// shows its progress (the reference's `showUpdateDownload`).
///
/// The folder is the one 数据与缓存 offers, so an installer lands where the
/// viewer already looks; the transfer writes a `.part` beside the target and
/// renames only once the whole file arrived, which is what keeps a cancelled
/// or broken download from looking like an installer.
Future<void> showUpdateDownload(BuildContext context, {required ReleaseBuild build}) {
  return showDsDialog<void>(
    context: context,
    dismissible: false,
    builder: (context) => UpdateDownloadDialog(build: build),
  );
}

/// The download's dialog: the bar, the byte count, and once the file is down,
/// the two things worth doing with it.
final class UpdateDownloadDialog extends ConsumerStatefulWidget {
  /// The dialog for [build].
  const UpdateDownloadDialog({required this.build, super.key});

  /// The package being fetched.
  final ReleaseBuild build;

  @override
  ConsumerState<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

final class _UpdateDownloadDialogState extends ConsumerState<UpdateDownloadDialog> {
  LiveStreamedResponse? _response;
  UpdateDownloadPhase _phase = UpdateDownloadPhase.running;
  int _received = 0;
  int _total = 0;
  String? _error;
  String? _savedPath;
  String? _savedDirectory;
  bool _cancelled = false;

  // Redraws are throttled to a percent: a 130 MB download arrives in
  // thousands of chunks and the bar does not need all of them.
  int _lastPaintedPercent = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    final response = _response;
    if (_phase == UpdateDownloadPhase.running && response != null) unawaited(response.close());
    super.dispose();
  }

  Future<void> _start() async {
    final directory = ref.read(appPathsProvider).updates.path;
    final target = File(p.join(directory, _finalName(widget.build.name)));
    final part = File('${target.path}.part');
    _savedDirectory = target.parent.path;
    try {
      await target.parent.create(recursive: true);
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      final response = await http.open(
        LiveRequest.get(Uri.parse(widget.build.url), timeout: const Duration(minutes: 10)),
      );
      _response = response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.close();
        throw FileSystemException('HTTP ${response.statusCode}', widget.build.url);
      }
      _total = int.tryParse(response.headers['content-length'] ?? '') ?? widget.build.size;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          _received += chunk.length;
          _paint();
        }
      } finally {
        await sink.close();
      }
      if (_cancelled) {
        await _discard(part);
        _setPhase(UpdateDownloadPhase.cancelled);
        return;
      }
      if (target.existsSync()) await target.delete();
      await part.rename(target.path);
      _savedPath = target.path;
      _setPhase(UpdateDownloadPhase.done);
    } on Object catch (error) {
      await _discard(part);
      if (_cancelled) {
        _setPhase(UpdateDownloadPhase.cancelled);
        return;
      }
      _error = _describe(error);
      _setPhase(UpdateDownloadPhase.failed);
    }
  }

  /// Stops the transfer: the stream is closed, and the loop above reports the
  /// phase once it unwinds.
  Future<void> _cancel() async {
    if (_phase != UpdateDownloadPhase.running) {
      Navigator.of(context).pop();
      return;
    }
    _cancelled = true;
    await _response?.close();
  }

  Future<void> _discard(File part) async {
    try {
      if (part.existsSync()) await part.delete();
    } on Object {
      // A leftover `.part` is invisible to the page and harmless.
    }
  }

  void _setPhase(UpdateDownloadPhase phase) {
    if (!mounted) return;
    setState(() => _phase = phase);
  }

  void _paint() {
    if (!mounted) return;
    final percent = _total <= 0 ? -1 : (_received * 100 ~/ _total);
    if (percent == _lastPaintedPercent) return;
    _lastPaintedPercent = percent;
    setState(() {});
  }

  Future<void> _open(String path) async {
    final t = context.t;
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done && mounted) {
      showDsToast(context: context, title: t.settings.downloadOpenFailed, status: DsStatus.danger);
    }
  }

  /// A failure in the viewer's terms: the transport's own words are noise, so
  /// only the parts that name something are kept.
  static String _describe(Object error) => switch (error) {
    final FileSystemException e => '${e.message}${e.path == null ? '' : ' · ${e.path}'}',
    _ => '$error',
  };

  /// The name on disk: the release's own, with anything a file system reads
  /// as structure taken out.
  static String _finalName(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final build = widget.build;
    final running = _phase == UpdateDownloadPhase.running;
    final done = _phase == UpdateDownloadPhase.done;
    final fraction = _total <= 0 ? null : (_received / _total).clamp(0.0, 1.0);
    final directory = _savedDirectory;
    final savedPath = _savedPath;
    final failure = _error;
    return DsDialog(
      title: Text(t.settings.downloadTitle),
      icon: DsIcon(done ? DsIcons.circleCheck : running ? DsIcons.cloudDownload : DsIcons.circleAlert),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(build.name, style: theme.typography.body.copyWith(color: colors.text)),
          DsProgressBar(value: fraction, animate: running, semanticLabel: build.name),
          Text(
            _total > 0
                ? t.settings.downloadProgress(received: formatReleaseSize(_received), total: formatReleaseSize(_total))
                : t.settings.downloadProgressUnknown(received: formatReleaseSize(_received)),
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          if (_phase == UpdateDownloadPhase.failed && failure != null)
            Text(failure, style: theme.typography.caption.copyWith(color: colors.danger.text)),
          if (_phase == UpdateDownloadPhase.cancelled)
            Text(
              t.settings.downloadCancelled,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          if (done && directory != null)
            Text(
              t.settings.downloadSavedTo(path: directory),
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
        ],
      ),
      actions: [
        if (running)
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => unawaited(_cancel()),
            child: Text(t.common.cancel),
          )
        else
          DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.close)),
        if (done && directory != null)
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_open(directory));
            },
            child: Text(t.settings.downloadOpenFolder),
          ),
        if (done && savedPath != null)
          DsButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_open(savedPath));
            },
            child: Text(t.settings.downloadOpenFile),
          ),
      ],
    );
  }
}
