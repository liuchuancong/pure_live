import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow;
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

/// Opens the font manager as a page of its own: the typeface the app (or the
/// flying danmaku, with [danmaku]) draws in, chosen from the platform's own
/// face, the bundled official ones and the cloud catalogue.
///
/// The bundled choices are one dropdown; the cloud families are a transfer
/// list — each one downloads on its own, shows its progress, and can only be
/// applied once its files are all on this device.
Future<void> showFontManagerPage(BuildContext context, {bool danmaku = false}) {
  return Navigator.of(context).push(DsPageRoute<void>(builder: (context) => FontManagerPage(danmaku: danmaku)));
}

/// The page itself.
final class FontManagerPage extends ConsumerStatefulWidget {
  /// Creates the page; [danmaku] manages the flying layer's typeface.
  const FontManagerPage({this.danmaku = false, super.key});

  /// Whether the flying danmaku's typeface is managed instead of the app's.
  final bool danmaku;

  @override
  ConsumerState<FontManagerPage> createState() => _FontManagerPageState();
}

final class _FontManagerPageState extends ConsumerState<FontManagerPage> {
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

  /// The family in force, app-wide or on the flying layer.
  String? _currentFamily() =>
      widget.danmaku ? ref.read(danmakuStyleProvider).fontFamily : AppThemeScope.of(context).settings.fontFamily;

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

  Future<void> _download(FontFamily family) async {
    final library = ref.read(fontLibraryProvider);
    setState(() => _failed.remove(family.id));
    try {
      await library.download(family);
      // Register straight away: the list and the app behind it preview the
      // face the moment its files are complete.
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
    if (_currentFamily() == family.id) _apply(null);
    showDsToast(context: context, title: t.settings.fontManagerRestartNote, status: DsStatus.info);
  }

  /// Opens the weight dialog: automatic, or one of the downloaded files.
  Future<void> _chooseFace(FontFamily family) async {
    final t = context.t;
    final library = ref.read(fontLibraryProvider);
    final files = library.filesOf(family.id);
    final current = widget.danmaku ? ref.read(danmakuFontFaceProvider) : ref.read(appFontFaceProvider);
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
    final name = path.split(RegExp(r'[/\\]')).last.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final parts = name.split('-');
    return parts.length > 1 ? parts.last : name;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final library = ref.watch(fontLibraryProvider);
    final family = widget.danmaku
        ? ref.watch(danmakuStyleProvider).fontFamily
        : AppThemeScope.of(context).settings.fontFamily;
    final face = widget.danmaku ? ref.watch(danmakuFontFaceProvider) : ref.watch(appFontFaceProvider);
    final families = _families ?? const <FontFamily>[];
    // Only a downloaded family can be chosen, and only one with more than one
    // file has a weight to pin.
    final downloaded = [
      for (final item in families)
        if (library.isDownloaded(item.id)) item,
    ];
    final active = downloaded.where((item) => item.id == family).firstOrNull;
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s4),
              child: Row(
                children: [
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const DsIcon(DsIcons.chevronLeft),
                    semanticLabel: t.common.back,
                  ),
                  Expanded(
                    child: Text(
                      widget.danmaku ? t.settings.danmakuFont : t.settings.fontManagerTitle,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s32),
                    children: [
                      DsListSection(
                        header: Text(t.settings.font),
                        children: [
                          // One dropdown for the faces this build carries: the
                          // platform's own, the bundled official ones, and any
                          // cloud family whose files are already here.
                          SettingsChoiceRow<String>(
                            leading: const DsIcon(DsIcons.type),
                            title: t.settings.font,
                            description: t.settings.fontDescription,
                            value: family ?? '',
                            placeholder: t.settings.fontPlatform,
                            options: [
                              DsSelectOption(value: '', label: t.settings.fontPlatform),
                              for (final (id, label) in kBundledFontPresets) DsSelectOption(value: id, label: label),
                              for (final item in downloaded) DsSelectOption(value: item.id, label: item.name),
                            ],
                            onChanged: (value) => _apply(value.isEmpty ? null : value),
                          ),
                          if (family == null)
                            DsListRow(
                              leading: const DsIcon(DsIcons.info),
                              title: Text(t.settings.fontManagerSystemDescription(face: platformFontFamilyLabel())),
                            ),
                          if (active != null && active.files.length > 1)
                            DsListRow(
                              leading: const DsIcon(DsIcons.layers),
                              title: Text(t.settings.fontWeightChange),
                              description: Text(t.settings.fontWeightChangeDesc),
                              detail: Text(
                                face.isEmpty
                                    ? t.settings.fontWeightAuto
                                    : t.settings.fontWeightLockedDetail(name: _faceLabel(face)),
                              ),
                              showChevron: true,
                              onPressed: () => unawaited(_chooseFace(active)),
                            ),
                        ],
                      ),
                      const SizedBox(height: DsSpace.s16),
                      DsListSection(
                        header: Text(t.settings.fontManagerCloud),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s4),
                            child: Text(
                              _families == null
                                  ? t.settings.fontManagerDownloading(done: '0', total: '0')
                                  : t.settings.fontManagerCloudDescription,
                              style: theme.typography.small.copyWith(color: colors.textSubtle),
                            ),
                          ),
                          for (final item in families)
                            _CloudFontRow(
                              family: item,
                              library: library,
                              inUse: item.id == family,
                              failed: _failed.contains(item.id),
                              onDownload: () => unawaited(_download(item)),
                              onCancel: () => library.cancelDownload(item.id),
                              onApply: () => _apply(item.id),
                              onDelete: () => unawaited(_delete(item)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cloud family: its name in its own face once it is here, its state, and
/// the transfer's own controls. A family that is still coming down cannot be
/// applied — the row says so rather than offering a choice that would draw in
/// the fallback face.
final class _CloudFontRow extends StatelessWidget {
  const _CloudFontRow({
    required this.family,
    required this.library,
    required this.inUse,
    required this.failed,
    required this.onDownload,
    required this.onCancel,
    required this.onApply,
    required this.onDelete,
  });

  final FontFamily family;
  final FontLibrary library;
  final bool inUse;
  final bool failed;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final downloaded = library.isDownloaded(family.id);
    final progress = library.progressOf(family.id);
    final size = library.sizeOf(family.id);
    final detail = downloaded
        ? t.settings.fontManagerDownloadedSize(size: formatFontBytes(size ?? 0))
        : failed
        ? t.settings.fontManagerDownloadFailed
        : t.settings.fontManagerNotDownloaded;
    final transferring = t.settings.fontManagerDownloading(
      done: '${progress?.done ?? 0}',
      total: '${progress?.total ?? family.files.length}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsListRow(
          leading: DsIcon(
            downloaded
                ? DsIcons.checkCircle
                : failed
                ? DsIcons.cloudOff
                : DsIcons.cloudDownload,
          ),
          title: Text(family.name, style: downloaded ? TextStyle(fontFamily: family.id) : null),
          description: Text(
            [
              if (family.description.isNotEmpty) family.description,
              if (family.license.isNotEmpty) t.settings.fontManagerLicenseNote(name: family.license),
            ].join(' · '),
          ),
          detail: Text(inUse ? t.settings.fontManagerInUse : detail),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              if (progress != null)
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: onCancel,
                  child: Text(t.settings.fontManagerCancelDownload),
                )
              else if (downloaded) ...[
                if (!inUse)
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: onApply,
                    child: Text(t.settings.fontManagerApply),
                  ),
                DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: onDelete,
                  icon: const DsIcon(DsIcons.trash2),
                  semanticLabel: t.settings.fontManagerDeleteFont,
                ),
              ] else
                DsButton(
                  size: DsSize.sm,
                  onPressed: onDownload,
                  child: Text(failed ? t.common.retry : t.settings.fontManagerDownload),
                ),
            ],
          ),
        ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: DsProgressBar(
                    // The transport answers whole files, so the bar steps per
                    // file and glides between them; the sweep runs until the
                    // first answer lands.
                    value: progress.total == 0 ? null : progress.done / progress.total,
                    semanticLabel: family.name,
                  ),
                ),
                Text(
                  '$transferring · ${formatFontBytes(progress.bytes)}',
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
