import 'dart:convert' show utf8;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/features/iptv/iptv_epg_controller.dart';
import 'package:pure_live/features/iptv/iptv_sources_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// What an import dialog closed with: the importer's answer and the name
/// the user (or the file) gave, for the toast.
typedef IptvImportOutcome = ({IptvImportResult result, String name});

/// Where a playlist import reads from.
enum _ImportOrigin {
  /// A web address.
  link,

  /// Pasted M3U/TXT text.
  text,
}

/// Opens the playlist import dialog (address or pasted text, plus a local
/// file picker) and announces how it ended.
Future<void> runIptvPlaylistImport(BuildContext context) async {
  final outcome = await showDsDialog<IptvImportOutcome>(
    context: context,
    builder: (context) => const _PlaylistImportDialog(),
  );
  if (outcome == null || !context.mounted) return;
  showIptvImportOutcome(context, outcome);
}

/// Opens the guide import dialog and announces how it ended.
Future<void> runIptvGuideImport(BuildContext context) async {
  final outcome = await showDsDialog<IptvImportOutcome>(
    context: context,
    builder: (context) => const _GuideImportDialog(),
  );
  if (outcome == null || !context.mounted) return;
  showIptvImportOutcome(context, outcome);
}

/// The toast one import ends with: a success (with the skipped-line count
/// when the parser had to leave lines out), or the reason it saved nothing.
/// A declined replacement says nothing — the dialog already let it go.
void showIptvImportOutcome(BuildContext context, IptvImportOutcome outcome) {
  final t = context.t;
  final result = outcome.result;
  if (result.status == IptvImportStatus.cancelled) return;
  if (result.isImported) {
    showDsToast(
      context: context,
      status: DsStatus.success,
      title: result.issues.isEmpty
          ? t.iptv.imported(name: outcome.name)
          : t.iptv.importSkipped(name: outcome.name, count: result.issues.length),
    );
    return;
  }
  showDsToast(context: context, status: DsStatus.danger, title: iptvImportFailureText(result, t));
}

/// The one line a failed import or sync is worded with.
String iptvImportFailureText(IptvImportResult result, Translations t) => switch (result.status) {
  IptvImportStatus.imported || IptvImportStatus.cancelled => '',
  IptvImportStatus.unsupportedFormat => t.iptv.importFormat,
  IptvImportStatus.invalid => t.iptv.importInvalid,
  IptvImportStatus.networkFailed => t.iptv.importNetworkFailed,
  IptvImportStatus.stale => t.iptv.sourceChanged,
  IptvImportStatus.failed => t.iptv.importFailed,
};

final class _PlaylistImportDialog extends ConsumerStatefulWidget {
  const _PlaylistImportDialog();

  @override
  ConsumerState<_PlaylistImportDialog> createState() => _PlaylistImportDialogState();
}

final class _PlaylistImportDialogState extends ConsumerState<_PlaylistImportDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _text = TextEditingController();
  _ImportOrigin _origin = _ImportOrigin.link;
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _busy => _picking || ref.watch(iptvSourcesProvider.select((state) => state.importing));

  void _toast(String message) => showDsToast(context: context, title: message, status: DsStatus.danger);

  Future<bool> _confirmReplace(String name) {
    final t = context.t;
    return showDsConfirm(
      context: context,
      title: t.iptv.replaceTitle(name: name),
      description: t.iptv.replaceMessage,
      confirmLabel: t.iptv.importAction,
      cancelLabel: t.common.cancel,
    );
  }

  Future<void> _submit() async {
    final t = context.t;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(t.iptv.importNameRequired);
      return;
    }
    final controller = ref.read(iptvSourcesProvider.notifier);
    final IptvImportResult result;
    if (_origin == _ImportOrigin.link) {
      final raw = _url.text.trim();
      if (raw.isEmpty) {
        _toast(t.iptv.importAddressRequired);
        return;
      }
      final uri = Uri.tryParse(raw);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
        _toast(t.iptv.importAddressInvalid);
        return;
      }
      result = await controller.importPlaylistUrl(url: uri, name: name, confirmReplace: _confirmReplace);
    } else {
      if (_text.text.trim().isEmpty) {
        _toast(t.iptv.importTextRequired);
        return;
      }
      result = await controller.importPlaylistText(text: _text.text, name: name, confirmReplace: _confirmReplace);
    }
    _finish(result, name);
  }

  Future<void> _pickFile() async {
    final t = context.t;
    setState(() => _picking = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: t.iptv.pickPlaylistFile,
        type: FileType.custom,
        allowedExtensions: const ['m3u', 'm3u8', 'txt'],
      );
      if (file == null || !mounted) return;
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final name = _fileBaseName(file.name);
      final result = await ref
          .read(iptvSourcesProvider.notifier)
          .importPlaylistText(text: text, name: name, confirmReplace: _confirmReplace);
      _finish(result, name);
    } on Object {
      if (mounted) _toast(t.iptv.importFailed);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Closes on a write; a declined replacement stays open so the name can
  /// be changed, and a failure stays open so the address can be fixed.
  void _finish(IptvImportResult result, String name) {
    if (!mounted) return;
    if (result.isImported) {
      Navigator.of(context).pop<IptvImportOutcome>((result: result, name: name));
    } else if (result.status != IptvImportStatus.cancelled) {
      _toast(iptvImportFailureText(result, context.t));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final busy = _busy;
    return DsDialog(
      title: Text(t.iptv.importPlaylist),
      style: const DsDialogStyle(width: 480),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.iptv.importPlaylistDescription),
          DsSegmentedControl<_ImportOrigin>(
            value: _origin,
            onChanged: busy ? null : (origin) => setState(() => _origin = origin),
            semanticLabel: t.iptv.importPlaylist,
            segments: [
              DsSegment(
                value: _ImportOrigin.link,
                icon: const DsIcon(DsIcons.globe),
                label: Text(t.iptv.importFromUrl),
              ),
              DsSegment(
                value: _ImportOrigin.text,
                icon: const DsIcon(DsIcons.fileText),
                label: Text(t.iptv.importFromText),
              ),
            ],
          ),
          DsTextField(
            controller: _name,
            enabled: !busy,
            autofocus: true,
            placeholder: t.iptv.playlistNameHint,
            semanticLabel: t.iptv.playlistName,
          ),
          if (_origin == _ImportOrigin.link)
            DsTextField(
              controller: _url,
              enabled: !busy,
              clearable: true,
              placeholder: t.iptv.playlistUrlHint,
              semanticLabel: t.iptv.playlistUrl,
              keyboardType: TextInputType.url,
            )
          else
            DsTextField.multiline(
              controller: _text,
              enabled: !busy,
              minLines: 5,
              maxLines: 10,
              placeholder: t.iptv.playlistTextHint,
              semanticLabel: t.iptv.playlistText,
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              loading: _picking,
              onPressed: busy ? null : _pickFile,
              leading: const DsIcon(DsIcons.folderOpen, size: 15),
              child: Text(t.iptv.importFromFile),
            ),
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(loading: busy, onPressed: busy ? null : _submit, child: Text(t.iptv.importAction)),
      ],
    );
  }
}

final class _GuideImportDialog extends ConsumerStatefulWidget {
  const _GuideImportDialog();

  @override
  ConsumerState<_GuideImportDialog> createState() => _GuideImportDialogState();
}

final class _GuideImportDialogState extends ConsumerState<_GuideImportDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  bool get _busy => ref.watch(iptvEpgProvider.select((state) => state.importing));

  void _toast(String message) => showDsToast(context: context, title: message, status: DsStatus.danger);

  Future<bool> _confirmReplace(String name) {
    final t = context.t;
    return showDsConfirm(
      context: context,
      title: t.iptv.replaceTitle(name: name),
      description: t.iptv.replaceMessage,
      confirmLabel: t.iptv.importAction,
      cancelLabel: t.common.cancel,
    );
  }

  Future<void> _submit() async {
    final t = context.t;
    final raw = _url.text.trim();
    if (raw.isEmpty) {
      _toast(t.iptv.importAddressRequired);
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      _toast(t.iptv.importAddressInvalid);
      return;
    }
    final name = _name.text.trim();
    final result = await ref
        .read(iptvEpgProvider.notifier)
        .importFromUrl(url: raw, name: name, confirmReplace: _confirmReplace);
    if (!mounted) return;
    if (result.isImported) {
      Navigator.of(context).pop<IptvImportOutcome>((result: result, name: name.isEmpty ? uri.host : name));
    } else if (result.status != IptvImportStatus.cancelled) {
      _toast(iptvImportFailureText(result, context.t));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final busy = _busy;
    return DsDialog(
      title: Text(t.iptv.importGuide),
      style: const DsDialogStyle(width: 480),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.iptv.importGuideDescription),
          DsTextField(
            controller: _url,
            enabled: !busy,
            autofocus: true,
            clearable: true,
            placeholder: t.iptv.epgSourceHint,
            semanticLabel: t.iptv.epgSourceHint,
            keyboardType: TextInputType.url,
          ),
          DsTextField(
            controller: _name,
            enabled: !busy,
            placeholder: t.iptv.guideNameHint,
            semanticLabel: t.iptv.guideName,
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(loading: busy, onPressed: busy ? null : _submit, child: Text(t.iptv.importAction)),
      ],
    );
  }
}

/// A file's name without its extension: the playlist's default name.
String _fileBaseName(String name) {
  final dot = name.lastIndexOf('.');
  final base = (dot > 0 ? name.substring(0, dot) : name).trim();
  return base.isEmpty ? name : base;
}
