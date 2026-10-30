import 'dart:async' show unawaited;
import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_local.dart' show musicLocalProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/music_tag_writer.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_match.dart' show findSameSong;

/// Edits a local song's tags in place — the reference's 编辑歌曲标签.
///
/// The dialog reads the file's current tags first, and only the parts the
/// viewer actually changed are written back; a saved edit rescans the local
/// library so the row follows the file.
Future<void> showEditTrackTagsDialog(BuildContext context, WidgetRef ref, audio.MusicTrack track) async {
  final saved = await showDsDialog<bool>(context: context, builder: (context) => _EditTagsDialog(track: track));
  if (saved != true) return;
  unawaited(ref.read(musicLocalProvider.notifier).rescan());
  if (!context.mounted) return;
  showDsToast(context: context, title: context.t.music.tagEditSaved, status: DsStatus.success);
}

final class _EditTagsDialog extends ConsumerStatefulWidget {
  const _EditTagsDialog({required this.track});

  final audio.MusicTrack track;

  @override
  ConsumerState<_EditTagsDialog> createState() => _EditTagsDialogState();
}

final class _EditTagsDialogState extends ConsumerState<_EditTagsDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _singer = TextEditingController();
  final TextEditingController _album = TextEditingController();
  final TextEditingController _lyric = TextEditingController();

  String _fileName = '';
  String _initialName = '';
  String _initialSinger = '';
  String _initialAlbum = '';
  String _initialLyric = '';

  /// The file's own cover, kept so 移除图片 can address it.
  Uint8List? _filePicture;

  /// The cover the viewer picked or matched; it outranks the file's own.
  Uint8List? _newPicture;

  /// Whether the embedded cover should go away.
  bool _removedPicture = false;

  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _matchingLyric = false;
  bool _matchingPicture = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _lyric]) {
      controller.addListener(_onFieldChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    for (final controller in [_name, _lyric]) {
      controller.removeListener(_onFieldChanged);
    }
    _name.dispose();
    _singer.dispose();
    _album.dispose();
    _lyric.dispose();
    super.dispose();
  }

  /// The save button guards on a non-blank name and the lyric row on a
  /// non-empty box; both live on typed text, so edits re-render the actions.
  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final path = widget.track.localPath;
    if (path == null) {
      setState(() => _failed = true);
      return;
    }
    try {
      final tag = await const audio.AudioTagReader().read(File(path));
      if (!mounted) return;
      _fileName = path.split(Platform.pathSeparator).last;
      final dot = _fileName.lastIndexOf('.');
      if (dot > 0) _fileName = _fileName.substring(0, dot);
      _initialName = tag.title ?? '';
      _initialSinger = tag.artist ?? '';
      _initialAlbum = tag.album ?? '';
      _initialLyric = tag.lyric ?? '';
      _filePicture = tag.picture?.bytes;
      _name.text = _initialName.isEmpty ? widget.track.title : _initialName;
      _singer.text = _initialSinger.isEmpty ? widget.track.artist : _initialSinger;
      _album.text = _initialAlbum.isEmpty ? widget.track.album : _initialAlbum;
      _lyric.text = _initialLyric;
      setState(() => _loading = false);
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// The reference's 从文件名解析: strip the extension, split on the dash, trim
  /// both halves.
  void _parseName({required bool nameFirst}) {
    final parts = _fileName.split('-');
    final first = parts.first.trim();
    final second = parts.length > 1 ? parts[1].trim() : '';
    if (nameFirst) {
      _name.text = first;
      if (second.isNotEmpty) _singer.text = second;
    } else {
      _singer.text = first;
      if (second.isNotEmpty) _name.text = second;
    }
    setState(() {});
  }

  Future<void> _pickPicture() async {
    final t = context.t;
    try {
      final picked = await FilePicker.pickFile(dialogTitle: t.music.tagEditSelectPic, type: FileType.image);
      final path = picked?.path;
      if (path == null || !mounted) return;
      final bytes = await File(path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _newPicture = bytes;
        _removedPicture = false;
      });
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: t.music.tagEditSelectPicFailed, status: DsStatus.danger);
    }
  }

  /// Searches the platforms for the same song — the reference's online match
  /// walks the same first-hit chain its 换源 does.
  Future<(audio.MusicTrack, audio.MusicSource)?> _findOnline() async {
    final query = '${_name.text.trim()} ${_singer.text.trim()}';
    for (final source in ref.read(musicSourceListProvider)) {
      try {
        final page = await source.search(query, pageSize: 10);
        final match = findSameSong(widget.track, page.items);
        if (match != null) return (match, source);
      } on Object {
        continue;
      }
    }
    return null;
  }

  Future<void> _matchLyric() async {
    if (_matchingLyric) return;
    setState(() => _matchingLyric = true);
    final t = context.t;
    try {
      final found = await _findOnline();
      final payload = found == null ? null : await found.$2.resolveLyric(found.$1);
      final translation = payload?.translation?.trim() ?? '';
      if (payload == null || payload.lyric.trim().isEmpty) throw StateError('no lyric');
      if (!mounted) return;
      setState(() => _lyric.text = [payload.lyric, if (translation.isNotEmpty) translation].join('\n'));
      showDsToast(context: context, title: t.music.tagEditMatchLyricDone, status: DsStatus.success);
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: t.music.tagEditMatchLyricFailed, status: DsStatus.warning);
    } finally {
      if (mounted) setState(() => _matchingLyric = false);
    }
  }

  Future<void> _matchPicture() async {
    if (_matchingPicture) return;
    setState(() => _matchingPicture = true);
    final t = context.t;
    try {
      final found = await _findOnline();
      final cover = found?.$1.coverUri;
      if (cover == null) throw StateError('no cover');
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.media);
      final response = await http.send(LiveRequest.get(cover, timeout: const Duration(seconds: 10)));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) throw StateError('cover download failed');
      if (!mounted) return;
      setState(() {
        _newPicture = response.bodyBytes;
        _removedPicture = false;
      });
      showDsToast(context: context, title: t.music.tagEditMatchPicDone, status: DsStatus.success);
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: t.music.tagEditMatchPicFailed, status: DsStatus.warning);
    } finally {
      if (mounted) setState(() => _matchingPicture = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final t = context.t;
    try {
      final picture = _newPicture ?? (_removedPicture ? Uint8List(0) : null);
      await writeAudioTags(
        widget.track.localPath!,
        MusicTagWrite(
          title: _name.text.trim() == _initialName ? null : _name.text.trim(),
          artist: _singer.text.trim() == _initialSinger ? null : _singer.text.trim(),
          album: _album.text.trim() == _initialAlbum ? null : _album.text.trim(),
          lyric: _lyric.text == _initialLyric ? null : _lyric.text,
          picture: picture,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Formats without a writer refuse up front; everything else is a real
      // failure worth its message.
      if (failure is UnsupportedError) {
        showDsToast(context: context, title: t.music.tagEditUnsupportedFormat, status: DsStatus.warning);
      } else {
        showDsToast(context: context, title: t.music.tagEditFailed(error: '$failure'), status: DsStatus.danger);
      }
    }
  }

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpace.s8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s4,
      children: [
        Text(label, style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textSubtle)),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final picture = _newPicture ?? (_removedPicture ? null : _filePicture);
    return DsDialog(
      title: Text(t.music.tagEditTitle),
      icon: const DsIcon(DsIcons.edit),
      description: _loading
          ? const SizedBox(height: 96, child: Center(child: DsSpinner()))
          : _failed
          ? SizedBox(
              height: 96,
              child: Center(child: Text(t.music.tagEditReadFailed, style: theme.typography.body.copyWith(color: colors.textMuted))),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  t.music.tagEditFileName,
                  Text(
                    widget.track.localPath ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                ),
                _field(
                  t.music.tagEditName,
                  DsTextField(controller: _name, clearable: true, maxLength: 150, placeholder: t.music.tagEditName),
                ),
                _field(
                  t.music.tagEditParseName,
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: _fileName.isEmpty ? null : () => _parseName(nameFirst: true),
                        child: Text(t.music.tagParseNameSinger),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: _fileName.isEmpty ? null : () => _parseName(nameFirst: false),
                        child: Text(t.music.tagParseSingerName),
                      ),
                    ],
                  ),
                ),
                _field(
                  t.music.tagEditSinger,
                  DsTextField(controller: _singer, clearable: true, maxLength: 150, placeholder: t.music.tagEditSinger),
                ),
                _field(
                  t.music.tagEditAlbum,
                  DsTextField(controller: _album, clearable: true, maxLength: 150, placeholder: t.music.tagEditAlbum),
                ),
                _field(
                  t.music.tagEditPic,
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      DsAvatar(
                        initials: widget.track.title,
                        image: picture == null ? null : MemoryImage(picture),
                        size: DsSize.md,
                        semanticLabel: t.music.tagEditPic,
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        leading: _matchingPicture ? const DsSpinner() : null,
                        onPressed: _matchingPicture ? null : () => unawaited(_matchPicture()),
                        child: Text(t.music.tagEditMatchOnline),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => unawaited(_pickPicture()),
                        child: Text(t.music.tagEditSelectPic),
                      ),
                      if (picture != null)
                        DsButton(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          onPressed: () => setState(() {
                            _newPicture = null;
                            _removedPicture = true;
                          }),
                          child: Text(t.music.tagEditRemovePic),
                        ),
                    ],
                  ),
                ),
                _field(
                  t.music.tagEditLyric,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: DsSpace.s4,
                    children: [
                      DsTextField.multiline(controller: _lyric, minLines: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s8,
                          children: [
                            DsButton(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              leading: _matchingLyric ? const DsSpinner() : null,
                              onPressed: _matchingLyric ? null : () => unawaited(_matchLyric()),
                              child: Text(t.music.tagEditMatchOnline),
                            ),
                            DsButton(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              onPressed: _lyric.text.isEmpty ? null : () => setState(_lyric.clear),
                              child: Text(t.music.tagEditClearLyric),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: _saving || _name.text.trim().isEmpty ? null : () => unawaited(_save()),
          child: Text(t.music.tagEditConfirm),
        ),
      ],
    );
  }
}
