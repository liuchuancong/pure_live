import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsChild;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
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

/// Opens the font manager — the typeface the app (or the flying danmaku, with
/// [danmaku]) draws in — as a page of the settings surface: the centre pane on
/// desktop, a pushed section route on a touch shell, the way every other
/// section page is entered.
void showFontManagerPage(BuildContext context, WidgetRef ref, {bool danmaku = false}) {
  openSettingsChild(context, ref, danmaku ? SettingsSection.fontDanmaku : SettingsSection.fontApp);
}

/// Which slice of the catalogue the list shows.
enum _FontFilter {
  /// Everything this build can draw in: the bundled faces and the cloud ones.
  all,

  /// The official faces shipped inside the app.
  bundled,

  /// Cloud families whose files are already on this device.
  installed,

  /// Cloud families that still need a download.
  available,
}

/// One row's data: a bundled preset (no [family]) or a cloud catalogue entry.
final class _FontEntry {
  const _FontEntry({required this.id, required this.name, required this.description, this.family});

  /// The family id the theme names.
  final String id;

  /// The shown name.
  final String name;

  /// One sentence about the face.
  final String description;

  /// The catalogue entry; null for a bundled preset.
  final FontFamily? family;

  /// Whether the face ships with the app.
  bool get bundled => family == null;

  /// The licence name, when the catalogue has one.
  String get license => family?.license ?? '';

  /// The catalogue's files (empty for a bundled preset).
  List<String> get files => family?.files ?? const [];
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
  final TextEditingController _query = TextEditingController();
  final GlobalKey _listAnchor = GlobalKey();
  _FontFilter _filter = _FontFilter.all;

  @override
  void initState() {
    super.initState();
    // A transfer reports progress through the library's notifier: without
    // listening, the buttons and the bar would keep their first frame.
    ref.read(fontLibraryProvider).addListener(_onLibraryChanged);
    unawaited(_loadCatalog());
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ref.read(fontLibraryProvider).removeListener(_onLibraryChanged);
    _query.dispose();
    super.dispose();
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

  /// Switches to the catalogue's not-yet-downloaded entries and brings the
  /// list into view, so "download more" lands on the action it names.
  void _showDownloads() {
    setState(() => _filter = _FontFilter.available);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _listAnchor.currentContext;
      if (anchor == null) return;
      Scrollable.ensureVisible(
        anchor,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  List<_FontEntry> _entries(Translations t) => [
    for (final (id, label) in kBundledFontPresets)
      _FontEntry(id: id, name: label, description: t.settings.fontManagerBundledNote),
    for (final family in _families ?? const <FontFamily>[])
      _FontEntry(id: family.id, name: family.name, description: family.description, family: family),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final library = ref.watch(fontLibraryProvider);
    final family = widget.danmaku
        ? ref.watch(danmakuStyleProvider).fontFamily
        : AppThemeScope.of(context).settings.fontFamily;
    final entries = _entries(t);
    final query = _query.text.trim().toLowerCase();
    final filtered = [
      for (final entry in entries)
        if (_matchesFilter(entry, library) &&
            (query.isEmpty ||
                entry.name.toLowerCase().contains(query) ||
                entry.description.toLowerCase().contains(query) ||
                entry.license.toLowerCase().contains(query)))
          entry,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final rowActions = constraints.maxWidth >= 640;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: DsSearchField(
                      controller: _query,
                      placeholder: t.settings.fontManagerSearchPlaceholder,
                      semanticLabel: t.settings.fontManagerSearchPlaceholder,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                _buildCurrentSection(context, family: family, library: library, entries: entries),
                KeyedSubtree(
                  key: _listAnchor,
                  child: _buildFilters(context, count: filtered.length, wide: wide),
                ),
                if (filtered.isEmpty)
                  DsCard(
                    child: DsEmptyState(
                      icon: const DsIcon(DsIcons.search),
                      title: Text(t.settings.fontManagerNoResults, style: theme.typography.heading),
                    ),
                  )
                else
                  for (final entry in filtered)
                    _buildFontCard(
                      context,
                      entry: entry,
                      family: family,
                      library: library,
                      rowActions: rowActions,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _matchesFilter(_FontEntry entry, FontLibrary library) => switch (_filter) {
    _FontFilter.all => true,
    _FontFilter.bundled => entry.bundled,
    _FontFilter.installed => !entry.bundled && library.isDownloaded(entry.id),
    _FontFilter.available => !entry.bundled && !library.isDownloaded(entry.id),
  };

  /// The face in force, its switcher and the way to more faces — the same
  /// section rhythm the rest of settings uses, instead of a hero card.
  Widget _buildCurrentSection(
    BuildContext context, {
    required String? family,
    required FontLibrary library,
    required List<_FontEntry> entries,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final current = entries.where((entry) => entry.id == family).firstOrNull;
    final name = family == null
        ? t.settings.fontPlatform
        : fontFamilyLabel(t, family, cloudName: library.nameOf(family));
    final description = family == null
        ? t.settings.fontManagerSystemDescription(face: platformFontFamilyLabel())
        : current != null && current.description.isNotEmpty
        ? current.description
        : t.settings.fontManagerBundledNote;
    final select = DsSelect<String>(
      value: family ?? '',
      onChanged: (value) => _apply(value == null || value.isEmpty ? null : value),
      options: [
        DsSelectOption(value: '', label: t.settings.fontPlatform),
        for (final (id, label) in kBundledFontPresets) DsSelectOption(value: id, label: label),
        for (final entry in entries)
          if (!entry.bundled && library.isDownloaded(entry.id)) DsSelectOption(value: entry.id, label: entry.name),
      ],
      semanticLabel: t.settings.font,
    );
    return DsListSection(
      header: Text(t.settings.fontManagerCurrent),
      children: [
        SettingsConfigRow(
          leading: _FontPreviewTile(family: family, size: 52, background: colors.control),
          title: name,
          description: description,
          controlWidth: 220,
          control: select,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.download),
          title: Text(t.settings.fontManagerDownloadMore),
          showChevron: true,
          onPressed: _showDownloads,
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, {required int count, required bool wide}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final chips = DsChoiceChips<_FontFilter>(
      value: _filter,
      onChanged: (value) => setState(() => _filter = value),
      semanticLabel: t.settings.font,
      options: [
        DsChipOption(
          value: _FontFilter.all,
          label: Text(t.settings.fontManagerFilterAll),
          leading: const DsIcon(DsIcons.layoutGrid),
        ),
        DsChipOption(
          value: _FontFilter.bundled,
          label: Text(t.settings.fontManagerFilterBundled),
          leading: const DsIcon(DsIcons.package),
        ),
        DsChipOption(
          value: _FontFilter.installed,
          label: Text(t.settings.fontManagerFilterInstalled),
          leading: const DsIcon(DsIcons.circleCheck),
        ),
        DsChipOption(
          value: _FontFilter.available,
          label: Text(t.settings.fontManagerFilterAvailable),
          leading: const DsIcon(DsIcons.cloudDownload),
        ),
      ],
    );
    final total = Text(
      t.settings.fontManagerCount(count: '$count'),
      style: theme.typography.caption.copyWith(color: colors.textMuted),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          chips,
          Align(alignment: AlignmentDirectional.centerEnd, child: total),
        ],
      );
    }
    return Row(
      spacing: DsSpace.s16,
      children: [
        Expanded(child: chips),
        total,
      ],
    );
  }

  Widget _buildFontCard(
    BuildContext context, {
    required _FontEntry entry,
    required String? family,
    required FontLibrary library,
    required bool rowActions,
  }) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final installed = entry.bundled || library.isDownloaded(entry.id);
    final inUse = entry.id == family;
    final progress = library.progressOf(entry.id);
    final failed = _failed.contains(entry.id);
    final cloud = entry.family;
    final tags = <Widget>[
      if (!entry.bundled) _FontTag(label: t.settings.fontManagerTagCloud),
      if (entry.files.length > 1) _FontTag(label: t.settings.fontManagerTagWeights(count: '${entry.files.length}')),
      if (entry.license.isNotEmpty) _FontTag(label: entry.license),
    ];
    final preview = _FontPreviewTile(
      family: installed ? entry.id : null,
      size: 64,
      background: inUse ? colors.surface : colors.control,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s6,
      children: [
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              entry.name,
              style: theme.typography.bodyStrong.copyWith(color: colors.text, fontFamily: installed ? entry.id : null),
            ),
            if (inUse)
              DsBadge(
                label: Text(t.settings.fontManagerInUse),
                dot: false,
                style: DsBadgeStyle(background: colors.surface, foreground: colors.accentText),
              ),
          ],
        ),
        if (entry.description.isNotEmpty)
          Text(
            entry.description,
            style: theme.typography.small.copyWith(color: colors.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (tags.isNotEmpty) Wrap(spacing: DsSpace.s6, runSpacing: DsSpace.s6, children: tags),
      ],
    );
    final actions = <Widget>[
      if (progress != null) ...[
        DsButton.icon(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          loading: true,
          onPressed: () {},
          icon: const DsIcon(DsIcons.download),
          semanticLabel: t.settings.fontManagerDownloading(done: '${progress.done}', total: '${progress.total}'),
        ),
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          onPressed: () => library.cancelDownload(entry.id),
          icon: const DsIcon(DsIcons.x),
          semanticLabel: t.settings.fontManagerCancelDownload,
        ),
      ] else if (inUse)
        DsButton(
          variant: DsButtonVariant.tinted,
          size: DsSize.sm,
          leading: const DsIcon(DsIcons.check),
          onPressed: null,
          style: DsButtonStyle(
            disabled: DsButtonStyle(background: colors.accent, foreground: colors.onAccent, shadows: const []),
          ),
          child: Text(t.settings.fontManagerInUse),
        )
      else if (installed)
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: () => _apply(entry.id),
          child: Text(t.settings.fontManagerUse),
        )
      else
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: DsIcon(failed ? DsIcons.refreshCw : DsIcons.download),
          onPressed: () => unawaited(_download(cloud!)),
          child: Text(failed ? t.common.retry : t.settings.fontManagerDownload),
        ),
      if (cloud != null && installed)
        DsMenuAnchor(
          semanticLabel: t.common.more,
          align: DsAlign.end,
          builder: (context, controller, child) => DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            onPressed: controller.toggle,
            icon: const DsIcon(DsIcons.ellipsisVertical),
            semanticLabel: t.common.more,
          ),
          items: [
            if (entry.files.length > 1)
              DsMenuItem(
                leading: const DsIcon(DsIcons.layers),
                label: Text(t.settings.fontWeightChange),
                onPressed: () => unawaited(_chooseFace(cloud)),
              ),
            DsMenuItem(
              leading: const DsIcon(DsIcons.trash2),
              label: Text(t.settings.fontManagerDeleteFont),
              destructive: true,
              onPressed: () => unawaited(_delete(cloud)),
            ),
          ],
        ),
    ];
    final actionRow = Row(mainAxisSize: MainAxisSize.min, spacing: DsSpace.s8, children: actions);
    return DsCard(
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s16),
        background: inUse ? colors.accentTint : null,
        shadows: inUse ? [DsShadow.innerRing(colors.accent)] : [DsShadow.innerRing(colors.border)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rowActions)
            Row(
              spacing: DsSpace.s16,
              children: [
                preview,
                Expanded(child: details),
                actionRow,
              ],
            )
          else ...[
            Row(
              spacing: DsSpace.s16,
              children: [
                preview,
                Expanded(child: details),
              ],
            ),
            const SizedBox(height: DsSpace.s12),
            Align(alignment: AlignmentDirectional.centerEnd, child: actionRow),
          ],
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.s12),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsProgressBar(
                      // The transport answers whole files, so the bar steps per
                      // file and glides between them; the sweep runs until the
                      // first answer lands.
                      value: progress.done == 0 ? null : progress.done / progress.total,
                      semanticLabel: entry.name,
                    ),
                  ),
                  Text(
                    formatFontBytes(progress.bytes),
                    style: theme.typography.small.copyWith(color: colors.textSubtle),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The "Aa" specimen square: the family's own face once its files are here,
/// the fallback face in muted ink while it still needs a download.
final class _FontPreviewTile extends StatelessWidget {
  const _FontPreviewTile({required this.family, required this.size, required this.background});

  final String? family;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsCard(
      style: DsCardStyle(
        padding: EdgeInsets.zero,
        background: background,
        shadows: const [],
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            'Aa',
            style: theme.typography.title.copyWith(
              fontFamily: family,
              fontSize: size * 0.4,
              height: 1,
              color: family == null ? colors.textSubtle : colors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small grey pill under a font's description: where it comes from, how
/// many weights it ships and under what licence.
final class _FontTag extends StatelessWidget {
  const _FontTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DsBadge(label: Text(label), dot: false);
  }
}
