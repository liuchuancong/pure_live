import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/font_face_provider.dart'
    show appFontFaceProvider, danmakuFontFaceProvider;
import 'package:pure_live/app/providers/font_library_provider.dart' show fontLibraryProvider;
import 'package:pure_live/app/theme/font_defaults.dart' show kBundledFontPresets, platformFontFamilyLabel;
import 'package:pure_live/app/theme/fonts/font_catalog.dart' show FontFamily;
import 'package:pure_live/app/theme/fonts/font_library.dart'
    show FontDownloadException, FontDownloadFailure, FontLibrary;
import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope;
import 'package:pure_live/features/settings/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/l10n/translations.dart';

/// The current family's shown name: the bundled preset's label, the cloud
/// catalogue's name, or the platform's own face.
String fontFamilyLabel(Translations t, String? family, {String? cloudName}) {
  if (family == null) return t.settings.fontPlatform;
  for (final (id, label) in kBundledFontPresets) {
    if (id == family) return label;
  }
  return cloudName ?? family;
}

/// Bytes as the manager shows them: one decimal from the kilabyte up.
String formatFontBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// Opens the font manager: the platform's own face, every family this build
/// bundles, and the cloud catalogue — each downloaded row drawn in its own
/// face once the files are on this device. A choice applies at once: the
/// app's typeface through the root theme scope, or the flying danmaku's
/// when [danmaku] is set.
Future<void> showFontManagerDialog(BuildContext context, {bool danmaku = false}) => showDsDialog<void>(
  context: context,
  builder: (context) => FontManagerDialog(danmaku: danmaku),
);

/// The manager itself; the cloud rows watch the library's progress.
final class FontManagerDialog extends ConsumerStatefulWidget {
  /// Creates the dialog; [danmaku] manages the flying layer's typeface.
  const FontManagerDialog({this.danmaku = false, super.key});

  /// Whether the flying danmaku's typeface is managed instead of the app's.
  final bool danmaku;

  @override
  ConsumerState<FontManagerDialog> createState() => _FontManagerDialogState();
}

final class _FontManagerDialogState extends ConsumerState<FontManagerDialog> {
  List<FontFamily>? _families;
  final Set<String> _failed = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    final families = await ref.read(fontLibraryProvider).catalog();
    if (!mounted) return;
    setState(() => _families = families);
  }

  void _apply(String? family) {
    if (widget.danmaku) {
      if (ref.read(danmakuStyleProvider).fontFamily == family) return;
      unawaited(ref.read(danmakuFontFaceProvider.notifier).set(''));
      unawaited(ref.read(danmakuStyleProvider.notifier).setFontFamily(family));
      // A cloud family must reach the font loader before the barrage names
      // it; the load runs off the local files and the next items draw in it.
      if (family != null) unawaited(ref.read(fontLibraryProvider).ensureRegistered(family));
      return;
    }
    final scope = AppThemeScope.of(context);
    if (scope.settings.fontFamily == family) return;
    unawaited(ref.read(appFontFaceProvider.notifier).set(''));
    scope.onChanged(
      scope.settings.rebuild((b) {
        b
          ..fontFamily = family
          ..fontPackage = null;
      }),
    );
    // A cloud family must reach the font loader before the theme names it;
    // the load runs off the local files and the text repaints when it lands.
    if (family != null) unawaited(ref.read(fontLibraryProvider).ensureRegistered(family));
  }

  /// Pins a downloaded file (or clears it with '') for the active family and
  /// arms its registration.
  Future<void> _setFace(FontFamily family, String face) async {
    final controller = widget.danmaku ? danmakuFontFaceProvider.notifier : appFontFaceProvider.notifier;
    await ref.read(controller).set(face);
    await ref.read(fontLibraryProvider).ensureRegistered(family.id, face: face);
  }

  /// Opens the weight dialog: automatic, or one of the downloaded files.
  Future<void> _chooseFace(FontFamily family) async {
    final t = context.t;
    final library = ref.read(fontLibraryProvider);
    final files = library.filesOf(family.id);
    final current = widget.danmaku
        ? ref.read(danmakuFontFaceProvider)
        : ref.read(appFontFaceProvider);
    await showDsDialog<void>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.settings.fontWeightChange),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            Text(t.settings.fontWeightChangeDesc),
            DsListSection(
              header: Text(family.name),
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.refreshCw),
                  title: Text(t.settings.fontWeightAuto),
                  description: Text(t.settings.fontWeightAutoDesc),
                  selected: current.isEmpty,
                  trailing: current.isEmpty ? const DsIcon(DsIcons.check) : null,
                  onPressed: () {
                    unawaited(_setFace(family, ''));
                    Navigator.of(dialogContext).pop();
                  },
                ),
                for (final file in files)
                  DsListRow(
                    leading: const DsIcon(DsIcons.type),
                    title: Text(_faceLabel(file.path)),
                    description: Text(t.settings.fontWeightLockDesc),
                    selected: current == _fileName(file.path),
                    trailing: current == _fileName(file.path) ? const DsIcon(DsIcons.check) : null,
                    onPressed: () {
                      unawaited(_setFace(family, _fileName(file.path)));
                      Navigator.of(dialogContext).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
        style: const DsDialogStyle(width: 480),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.close),
          ),
        ],
      ),
    );
  }

  static String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

  static String _faceLabel(String path) {
    final name = _fileName(path).replaceFirst(RegExp(r'\.[^.]+$'), '');
    final parts = name.split('-');
    return parts.length > 1 ? parts.last : name;
  }

  Future<void> _download(FontFamily family) async {
    final library = ref.read(fontLibraryProvider);
    setState(() => _failed.remove(family.id));
    try {
      await library.download(family);
      // Register straight away: the manager's rows and the app behind it
      // preview the face the moment its files are complete.
      await library.ensureRegistered(family.id);
    } on FontDownloadException catch (error) {
      if (error.reason == FontDownloadFailure.cancelled) return;
      if (!mounted) return;
      setState(() => _failed.add(family.id));
      showDsToast(context: context, title: context.t.settings.fontManagerDownloadFailed, status: DsStatus.danger);
    } on Object {
      if (!mounted) return;
      setState(() => _failed.add(family.id));
      showDsToast(context: context, title: context.t.settings.fontManagerDownloadFailed, status: DsStatus.danger);
    }
  }

  Future<void> _delete(FontFamily family) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.fontManagerDeleteFont,
      description: t.settings.fontManagerDeleteQuestion(name: family.name),
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    final removed = await ref.read(fontLibraryProvider).delete(family.id);
    if (!mounted) return;
    if (!removed) {
      showDsToast(context: context, title: t.settings.fontManagerDownloadFailed, status: DsStatus.danger);
      return;
    }
    if (widget.danmaku) {
      if (ref.read(danmakuStyleProvider).fontFamily == family.id) _apply(null);
    } else if (AppThemeScope.of(context).settings.fontFamily == family.id) {
      _apply(null);
    }
    showDsToast(context: context, title: t.settings.fontManagerRestartNote, status: DsStatus.info);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final library = ref.watch(fontLibraryProvider);
    final family = widget.danmaku
        ? ref.watch(danmakuStyleProvider).fontFamily
        : AppThemeScope.of(context).settings.fontFamily;
    final face = widget.danmaku ? ref.watch(danmakuFontFaceProvider) : ref.watch(appFontFaceProvider);
    return DsDialog(
      title: Text(widget.danmaku ? t.settings.danmakuFont : t.settings.fontManagerTitle),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          Text(widget.danmaku ? t.settings.danmakuFontManagerDescription : t.settings.fontManagerDescription),
          DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.monitor),
                title: Text(t.settings.fontPlatform),
                description: Text(t.settings.fontManagerSystemDescription(face: platformFontFamilyLabel())),
                detail: Text(family == null ? t.settings.fontManagerInUse : platformFontFamilyLabel()),
                selected: family == null,
                trailing: family == null ? const DsIcon(DsIcons.check) : null,
                onPressed: family == null ? null : () => _apply(null),
              ),
            ],
          ),
          DsListSection(
            header: Text(t.settings.fontManagerBundled),
            children: [
              for (final (id, label) in kBundledFontPresets)
                _BundledFontRow(
                  id: id,
                  label: label,
                  active: family == id,
                  note: t.settings.fontManagerBundledNote,
                  inUse: t.settings.fontManagerInUse,
                  preview: t.settings.fontManagerPreview,
                  onPressed: family == id ? null : () => _apply(id),
                ),
            ],
          ),
          ListenableBuilder(
            listenable: library,
            builder: (context, _) => ConstrainedBox(
              // The catalogue is long; the cloud section scrolls instead of
              // growing the dialog past the window.
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: DsListSection(
                  header: Text(t.settings.fontManagerCloud),
                  children: [
                    if (_families == null)
                      DsListRow(title: Text(t.settings.fontManagerCloudDescription))
                    else
                      for (final entry in _families!) _cloudRow(t, library, family, entry, face),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 600),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }

  DsListRow _cloudRow(Translations t, FontLibrary library, String? current, FontFamily family, String face) {
    final active = current == family.id;
    final downloaded = library.isDownloaded(family.id);
    final files = downloaded ? library.filesOf(family.id) : const <File>[];
    final progress = library.progressOf(family.id);
    final failed = _failed.contains(family.id);
    final colors = DsTheme.colorsOf(context);
    final description = family.license.isEmpty
        ? family.description
        : '${family.description}\n${t.settings.fontManagerLicenseNote(name: family.license)}';
    final String detail;
    if (progress != null) {
      detail = t.settings.fontManagerDownloading(done: progress.done, total: progress.total);
    } else if (failed) {
      detail = t.settings.fontManagerDownloadFailed;
    } else if (active && face.isNotEmpty) {
      detail = t.settings.fontWeightLockedDetail(name: _faceLabel(face));
    } else if (active) {
      detail = t.settings.fontManagerInUse;
    } else if (downloaded) {
      detail = t.settings.fontManagerDownloadedSize(size: formatFontBytes(library.sizeOf(family.id) ?? 0));
    } else {
      detail = t.settings.fontManagerNotDownloaded;
    }
    return DsListRow(
      title: Text(family.name, style: TextStyle(fontFamily: family.id)),
      description: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: failed ? colors.danger.text : null),
      ),
      detail: Text(detail, style: failed && progress == null ? TextStyle(color: colors.danger.text) : null),
      selected: active,
      trailing: Row(
        spacing: DsSpace.s8,
        children: [
          if (progress != null)
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.settings.fontManagerCancelDownload,
              onPressed: () => library.cancelDownload(family.id),
              icon: const DsIcon(DsIcons.x),
            )
          else if (!downloaded)
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(_download(family)),
              child: Text(t.settings.fontManagerDownload),
            )
          else if (!active)
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.settings.fontManagerDeleteFont,
              onPressed: () => unawaited(_delete(family)),
              icon: const DsIcon(DsIcons.trash2),
            ),
          if (active && files.length > 1)
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.settings.fontWeightChange,
              onPressed: () => unawaited(_chooseFace(family)),
              icon: const DsIcon(DsIcons.slidersHorizontal),
            ),
          if (active) const DsIcon(DsIcons.check),
        ],
      ),
      onPressed: downloaded && !active ? () => _apply(family.id) : null,
    );
  }
}

/// The face the bundled preset keeps: unchanged rows, drawn in their own
/// family.
final class _BundledFontRow extends StatelessWidget {
  const _BundledFontRow({
    required this.id,
    required this.label,
    required this.active,
    required this.note,
    required this.inUse,
    required this.preview,
    required this.onPressed,
  });

  final String id;
  final String label;
  final bool active;
  final String note;
  final String inUse;
  final String preview;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsListRow(
      title: Text(label, style: TextStyle(fontFamily: id)),
      description: Text(
        preview,
        style: theme.typography.small.copyWith(fontFamily: id, color: active ? null : colors.textMuted),
      ),
      detail: Text(active ? inUse : note),
      selected: active,
      trailing: active ? const DsIcon(DsIcons.check) : null,
      onPressed: onPressed,
    );
  }
}
