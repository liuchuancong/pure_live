import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:desktop_drop/desktop_drop.dart' show DropDoneDetails, DropTarget;
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart';
import 'package:pure_live/features/settings/pages/wallpaper_preview_page.dart';
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsChild;
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// Opens a background source page: desktop switches the settings pane in
/// place, a touch shell pushes the route.
void _openBackgroundChild(BuildContext context, WidgetRef ref, SettingsSection section) {
  openSettingsChild(context, ref, section);
}

/// Background settings' landing page: the display controls that apply to
/// every kind, then the routes to each source.
final class BackgroundOverviewPane extends ConsumerWidget {
  const BackgroundOverviewPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    final children = settingsChildrenOf(SettingsSection.background);
    // The fit only acts on a surface that has an image or video to place,
    // so its row exists only for those kinds.
    final media = settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.video;
    // What the app would actually paint right now: in auto mode the wash can
    // be stronger than the slider, and the detail should say so.
    final tone = ref.watch(backgroundToneProvider);
    final scrim = backgroundScrimOpacityFor(
      settings: settings,
      plans: tone?.plans,
      dark: DsTheme.of(context).brightness == Brightness.dark,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.backgroundDisplay),
          children: [
            // The fit describes how an image or video is placed, so it
            // steps out on a background with nothing to place.
            if (media)
              SettingsChoiceRow<BoxFit>(
                leading: const DsIcon(DsIcons.expand),
                title: t.settings.backgroundFit,
                description: t.settings.backgroundFitDescription,
                value: settings.fit,
                options: [
                  for (final fit in kBackgroundFits) DsSelectOption(value: fit, label: backgroundFitLabel(t, fit)),
                ],
                onChanged: controller.setFit,
              ),
            SettingsChoiceRow<BackgroundScrimMode>(
              leading: const DsIcon(DsIcons.contrast),
              title: t.settings.backgroundScrimMode,
              description: t.settings.backgroundScrimModeDescription,
              value: settings.scrimMode,
              options: [
                DsSelectOption(value: BackgroundScrimMode.auto, label: t.settings.backgroundScrimAuto),
                DsSelectOption(value: BackgroundScrimMode.custom, label: t.settings.backgroundScrimCustom),
                DsSelectOption(value: BackgroundScrimMode.off, label: t.settings.backgroundScrimOff),
              ],
              onChanged: controller.setScrimMode,
            ),
            // The wash's strength exists only while a wash is painted;
            // auto still takes the slider as its floor.
            if (settings.scrimMode != BackgroundScrimMode.off)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.contrast),
                title: t.settings.backgroundMask,
                description: t.settings.backgroundMaskDescription,
                // Auto may paint more than the slider asks for; the detail is
                // the wash the app really wears.
                detail: Text('${(scrim * 100).round()}%'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.scrimOpacity,
                  max: 0.8,
                  divisions: 16,
                  onChanged: controller.setScrimOpacity,
                  semanticLabel: t.settings.backgroundMask,
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.layers),
              title: t.settings.backgroundOverlayBlur,
              description: t.settings.backgroundOverlayBlurDescription,
              detail: Text('${settings.backgroundBlurSigma.round()}'),
              controlWidth: 220,
              control: DsSlider(
                value: settings.backgroundBlurSigma,
                // Capped low: this filters the backdrop every frame, not a
                // still image once.
                max: 24,
                divisions: 24,
                onChanged: controller.setBackgroundBlur,
                semanticLabel: t.settings.backgroundOverlayBlur,
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.eraser),
              title: Text(t.settings.backgroundClear),
              description: Text(t.settings.backgroundClearDescription),
              onPressed: settings.kind == BackgroundKind.none ? null : controller.clear,
            ),
          ],
        ),
        // One panel fill and one layer blur, applied everywhere: the theme's
        // surface token turns translucent (cards, lists, the room's own
        // columns) and the official floating layers frost on top of it.
        DsListSection(
          header: Text(t.settings.backgroundGlass),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.layers),
              title: Text(t.settings.backgroundGlassEnable),
              description: Text(t.settings.backgroundGlassDescription),
              trailing: DsSwitch(
                value: settings.glass,
                onChanged: (value) => controller.setGlass(value: value),
              ),
            ),
            // The fill and the frost exist only while the glass does.
            if (settings.glass) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.droplet),
                title: t.settings.backgroundGlassFill,
                description: t.settings.backgroundGlassFillDescription,
                detail: Text('${(settings.glassFill * 100).round()}%'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.glassFill,
                  divisions: 20,
                  onChanged: controller.setGlassFill,
                  semanticLabel: t.settings.backgroundGlassFill,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.sparkles),
                title: t.settings.backgroundGlassBlur,
                description: t.settings.backgroundGlassBlurDescription,
                detail: Text('${settings.glassBlur.round()}'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.glassBlur,
                  max: 48,
                  divisions: 24,
                  onChanged: controller.setGlassBlur,
                  semanticLabel: t.settings.backgroundGlassBlur,
                ),
              ),
            ],
          ],
        ),
        DsListSection(
          header: Text(t.settings.backgroundChange),
          children: [
            for (final child in children)
              DsListRow(
                leading: DsIcon(child.icon),
                title: Text(child.label(t)),
                description: Text(child.description(t)),
                showChevron: true,
                onPressed: () => _openBackgroundChild(context, ref, child),
              ),
          ],
        ),
      ],
    );
  }
}

/// Swatches per grid row of the built-in palettes, and the fallback page
/// size before the first width is known.
const int _kSwatchTileWidth = 108;

/// Rows a page of swatches holds. The page size is always a whole number of
/// rows, so a page never ends with one tile short of a line however wide the
/// window is.
const int _kPageRows = 4;

/// Columns of a max-extent grid at [width]: the same arithmetic
/// `SliverGridDelegateWithMaxCrossAxisExtent` uses — it rounds up, so a
/// width even slightly past one extent's worth asks for another column.
int gridColumnsFor(double width, double maxExtent, double spacing) =>
    (width / (maxExtent + spacing)).ceil().clamp(1, 1 << 12);

/// The two swatch groups the colour page switches between.
enum _SwatchGroup { solid, gradient }

/// Solid colours and gradients, each pointing at the live app background;
/// a tap is the preview and the choice at once.
///
/// The groups have a switch of their own rather than one scroll: the tables
/// carry hundreds of swatches apiece, which is neither readable nor quick to
/// walk with a keyboard or a remote in one list.
final class BackgroundColorsPane extends ConsumerStatefulWidget {
  const BackgroundColorsPane({super.key});

  @override
  ConsumerState<BackgroundColorsPane> createState() => _BackgroundColorsPaneState();
}

final class _BackgroundColorsPaneState extends ConsumerState<BackgroundColorsPane> {
  int _solidPage = 1;
  int _gradientPage = 1;
  _SwatchGroup _group = _SwatchGroup.solid;

  /// The swatches of [page], [pageSize] apiece.
  static List<T> _slice<T>(List<T> items, int page, int pageSize) {
    final start = (page - 1) * pageSize;
    if (start >= items.length) return const [];
    return items.sublist(start, (start + pageSize).clamp(0, items.length));
  }

  /// The page bar under a group; absent when the group is one page wide.
  Widget _pager({
    required int page,
    required int total,
    required int pageSize,
    required ValueChanged<int> onPage,
    required String label,
  }) {
    final count = (total / pageSize).ceil().clamp(1, 1 << 20);
    if (count <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s12),
      // The bar is a min-size row; the section stretches it, so the centre
      // has to be asked for.
      child: Align(
        alignment: AlignmentDirectional.center,
        child: DsPagination(page: page, pageCount: count, onChanged: onPage, semanticLabel: label),
      ),
    );
  }

  /// Saves the swatch as a 1920×1080 PNG in the shared download folder.
  Future<void> _savePaint(BuildContext context, WallpaperPreviewPaint paint) async {
    try {
      final handover = await ref
          .read(wallpaperDownloadsProvider.notifier)
          .enqueueBytes(
            title: paint.name,
            kind: WallpaperDownloadKind.paint,
            bytes: await encodeWallpaperPaint(paint),
            fileName: wallpaperFileName(title: paint.name, fallback: 'background', address: 'paint.png'),
          );
      if (!context.mounted) return;
      showDownloadHandoverToast(
        context,
        handover,
        openManager: () => _openBackgroundChild(context, ref, SettingsSection.backgroundDownloads),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: context.t.settings.backgroundDownloadFailed,
        description: '$error',
        status: DsStatus.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        // A page is whole rows of whatever fits this width, so the last row
        // is never one swatch short.
        final columns = gridColumnsFor(constraints.maxWidth, _kSwatchTileWidth.toDouble(), DsSpace.s8);
        final pageSize = columns * _kPageRows;
        final solids = _slice(kBackgroundSolidPresets, _solidPage, pageSize);
        final gradients = _slice(kBackgroundGradientPresets, _gradientPage, pageSize);
        // The preview walks the whole table from the tapped swatch, so a
        // swatch on any page leads to the same run of candidates.
        final solidPaints = [
          for (final preset in kBackgroundSolidPresets) WallpaperPreviewPaint.solid(preset.name, preset.color),
        ];
        final gradientPaints = [
          for (final preset in kBackgroundGradientPresets) WallpaperPreviewPaint.gradient(preset),
        ];
        final solidOffset = (_solidPage - 1) * pageSize;
        final gradientOffset = (_gradientPage - 1) * pageSize;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DsChoiceChips<_SwatchGroup>(
                value: _group,
                semanticLabel: t.settings.backgroundColorsTitle,
                options: [
                  DsChipOption(
                    value: _SwatchGroup.solid,
                    label: Text(t.settings.backgroundSolid),
                    leading: const DsIcon(DsIcons.square),
                  ),
                  DsChipOption(
                    value: _SwatchGroup.gradient,
                    label: Text(t.settings.backgroundGradient),
                    leading: const DsIcon(DsIcons.contrast),
                  ),
                ],
                onChanged: (value) => setState(() => _group = value),
              ),
            ),
            if (_group == _SwatchGroup.solid)
              DsListSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(DsSpace.s12),
                    child: Wrap(
                      spacing: DsSpace.s8,
                      runSpacing: DsSpace.s8,
                      children: [
                        for (var i = 0; i < solids.length; i++)
                          _Swatch(
                            name: solids[i].name,
                            decoration: BoxDecoration(color: solids[i].color),
                            selected: settings.kind == BackgroundKind.solid && settings.solidColor == solids[i].color,
                            copyLabel: t.settings.backgroundCopyColor,
                            copyValue: solids[i].name,
                            onPressed: () => controller.setSolid(solids[i].color),
                            onPreview: () => unawaited(showPalettePreview(context, solidPaints, solidOffset + i)),
                            onDownload: () => unawaited(_savePaint(context, solidPaints[solidOffset + i])),
                          ),
                      ],
                    ),
                  ),
                  _pager(
                    page: _solidPage,
                    total: kBackgroundSolidPresets.length,
                    pageSize: pageSize,
                    onPage: (page) => setState(() => _solidPage = page),
                    label: t.settings.backgroundSolid,
                  ),
                ],
              )
            else
              DsListSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(DsSpace.s12),
                    child: Wrap(
                      spacing: DsSpace.s8,
                      runSpacing: DsSpace.s8,
                      children: [
                        for (var i = 0; i < gradients.length; i++)
                          _Swatch(
                            name: gradients[i].name,
                            decoration: _gradientOf(gradients[i]),
                            selected: settings.kind == BackgroundKind.gradient && _sameGradient(settings, gradients[i]),
                            copyLabel: t.settings.backgroundCopyGradient,
                            copyValue: _cssGradient(gradients[i]),
                            onPressed: () => controller.setGradient(gradients[i]),
                            onPreview: () => unawaited(showPalettePreview(context, gradientPaints, gradientOffset + i)),
                            onDownload: () => unawaited(_savePaint(context, gradientPaints[gradientOffset + i])),
                          ),
                      ],
                    ),
                  ),
                  _pager(
                    page: _gradientPage,
                    total: kBackgroundGradientPresets.length,
                    pageSize: pageSize,
                    onPage: (page) => setState(() => _gradientPage = page),
                    label: t.settings.backgroundGradient,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// The preset as it will paint: its own stops and its own angle.
  static BoxDecoration _gradientOf(BackgroundGradientPreset preset) {
    final (begin, end) = gradientAlignments(preset.deg);
    return BoxDecoration(
      gradient: LinearGradient(begin: begin, end: end, colors: preset.colors, stops: preset.stops),
    );
  }

  /// The preset as a CSS gradient, for the copy action.
  static String _cssGradient(BackgroundGradientPreset preset) {
    final stops = [
      for (var i = 0; i < preset.colors.length; i++) '${_hexOf(preset.colors[i])} ${(preset.stops[i] * 100).round()}%',
    ];
    return 'linear-gradient(${preset.deg}deg, ${stops.join(', ')})';
  }

  static String _hexOf(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Whether the live background is this preset — colours, positions and the
  /// angle, so two tables sharing a palette still mark one swatch.
  static bool _sameGradient(BackgroundSettings settings, BackgroundGradientPreset preset) {
    if (settings.gradientDeg != preset.deg) return false;
    final colors = settings.gradientColors;
    if (colors.length != preset.colors.length) return false;
    for (var i = 0; i < colors.length; i++) {
      if (colors[i] != preset.colors[i]) return false;
    }
    final stops = settings.gradientStops;
    if (stops == null || stops.length != preset.stops.length) return false;
    for (var i = 0; i < stops.length; i++) {
      if ((stops[i] - preset.stops[i]).abs() > 0.001) return false;
    }
    return true;
  }
}

/// One palette swatch: the paint, its name under it, and the ring that says
/// this is what the app is wearing. A tap opens it full-window; a long press
/// or right click offers the same plus applying it, saving it as a picture,
/// and copying the colour in a form another app understands.
final class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.decoration,
    required this.selected,
    required this.copyLabel,
    required this.copyValue,
    required this.onPressed,
    required this.onPreview,
    required this.onDownload,
  });

  /// The colour or gradient, in the form the background paints with.
  final BoxDecoration decoration;

  /// What the source table calls it.
  final String name;

  /// What the copy action is called: a colour value or a gradient.
  final String copyLabel;

  /// The text the copy action puts on the clipboard.
  final String copyValue;

  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsContextMenuRegion(
      semanticLabel: t.common.more,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.eye),
          label: Text(t.settings.backgroundPreviewMedia),
          onPressed: onPreview,
        ),
        DsMenuItem(leading: const DsIcon(DsIcons.check), label: Text(t.settings.backgroundApply), onPressed: onPressed),
        DsMenuItem(
          leading: const DsIcon(DsIcons.download),
          label: Text(t.settings.downloadAction),
          onPressed: onDownload,
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(copyLabel),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: copyValue));
            if (context.mounted) showDsToast(context: context, title: t.common.copied);
          },
        ),
      ],
      child: SizedBox(
        width: _kSwatchTileWidth.toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s4,
          children: [
            DsPressable(
              semanticLabel: name,
              selected: selected,
              onPressed: onPreview,
              builder: (context, states, _) => Container(
                width: _kSwatchTileWidth.toDouble(),
                height: 64,
                decoration: BoxDecoration(
                  color: decoration.color,
                  gradient: decoration.gradient,
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  border: Border.all(
                    color: selected
                        ? colors.accent
                        : states.contains(WidgetState.hovered)
                        ? colors.textSubtle
                        : colors.border,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected ? Center(child: DsIcon(DsIcons.check, size: 20, color: colors.onAccent)) : null,
              ),
            ),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tile's width over height.
const double _kWallpaperAspectRatio = 16 / 10;

/// Online image and video wallpapers, one source at a time, with a preview
/// before the choice is applied.
final class BackgroundLibraryPane extends ConsumerStatefulWidget {
  const BackgroundLibraryPane({required this.video, super.key});

  /// Whether this page lists live wallpapers instead of pictures.
  final bool video;

  @override
  ConsumerState<BackgroundLibraryPane> createState() => _BackgroundLibraryPaneState();
}

final class _BackgroundLibraryPaneState extends ConsumerState<BackgroundLibraryPane> {
  late final List<WallpaperSource> _sources;
  late WallpaperSource _source;
  WallpaperCategory? _category;

  /// What has been fetched, in order: a local source's whole set, or the
  /// server pages loaded so far. The page on screen is a slice of this, so a
  /// page is whole grid rows however wide the window is.
  List<WallpaperItem> _buffer = const [];

  /// How many server pages [_buffer] holds.
  int _serverPages = 0;

  /// Items per page, from the current grid width. The first build replaces
  /// this with the real number; it only has to be sane until then.
  int _pageSize = _kPageRows * 4;

  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _sources = [
      for (final source in wallpaperSources)
        if (source.isVideo == widget.video) source,
    ];
    _source = _sources.first;
    _category = _source.categories.firstOrNull;
    unawaited(_load());
  }

  WallpaperSource get _selectedSource =>
      _sources.firstWhere((source) => source.id == _source.id, orElse: () => _sources.first);

  /// The pages the bar offers: what the buffer already covers, plus one more
  /// while the source still has a page to give.
  int get _pageCount {
    final known = (_buffer.length / _pageSize).ceil();
    return (_hasMore ? known + 1 : known).clamp(1, 1 << 20);
  }

  /// The items of [page].
  List<WallpaperItem> _slice(int page, int pageSize) {
    final start = (page - 1) * pageSize;
    if (start >= _buffer.length) return const [];
    return _buffer.sublist(start, (start + pageSize).clamp(0, _buffer.length));
  }

  /// Loads until the current page is covered by [_buffer].
  ///
  /// A server page has the size the API fixes, so one displayed page can need
  /// more than one of them; the leftovers simply start the next page.
  Future<void> _load() async {
    final generation = ++_generation;
    final source = _selectedSource;
    setState(() => _loading = true);
    try {
      if (source.isLocal) {
        if (_buffer.isEmpty) {
          _buffer = await ref.read(backgroundLibraryClientProvider).fetch(source: source, category: _category, page: 1);
        }
        _hasMore = false;
      } else {
        while (_serverPages * source.pageSize < _page * _pageSize && _hasMore) {
          final items = await ref
              .read(backgroundLibraryClientProvider)
              .fetch(source: source, category: _category, page: _serverPages + 1);
          if (!mounted || generation != _generation) return;
          final seen = {for (final item in _buffer) item.url};
          _buffer = [..._buffer, ...items.where((item) => seen.add(item.url))];
          _serverPages += 1;
          if (items.isEmpty || items.length < source.pageSize) _hasMore = false;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  /// Jumps to [page] and loads it; the same call retries a failed page. A
  /// press while another page is still fetching is dropped, so the pager
  /// never has to be greyed out to say so.
  void _goTo(int page) {
    if (_loading) return;
    final target = page < 1 ? 1 : page;
    if (target == _page && _error == null) return;
    setState(() {
      _page = target;
      _error = null;
    });
    unawaited(_load());
  }

  /// One more server page, for the preview that walked past the entries the
  /// grid showed. The page joins the buffer, so the grid gains it too; the
  /// preview gets only the entries the buffer did not already hold.
  Future<List<WallpaperItem>> _loadMore() async {
    final source = _selectedSource;
    if (source.isLocal || !_hasMore || _loading) return const [];
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(backgroundLibraryClientProvider)
          .fetch(source: source, category: _category, page: _serverPages + 1);
      if (!mounted) return const [];
      final seen = {for (final item in _buffer) item.url};
      final added = items.where((item) => seen.add(item.url)).toList();
      setState(() {
        _buffer = [..._buffer, ...added];
        _serverPages += 1;
        if (items.isEmpty || items.length < source.pageSize) _hasMore = false;
        _loading = false;
      });
      return added;
    } on Object {
      if (!mounted) return const [];
      setState(() => _loading = false);
      return const [];
    }
  }

  void _selectSource(WallpaperSourceId id) {
    if (id == _source.id) return;
    setState(() {
      _source = _sources.firstWhere((source) => source.id == id, orElse: () => _sources.first);
      _category = _source.categories.firstOrNull;
      _reset();
    });
    unawaited(_load());
  }

  void _selectCategory(WallpaperCategory category) {
    if (category.id == _category?.id) return;
    setState(() {
      _category = category;
      _reset();
    });
    unawaited(_load());
  }

  /// Back to the first page of a freshly chosen source or category.
  void _reset() {
    _page = 1;
    _buffer = const [];
    _serverPages = 0;
    _hasMore = true;
    _error = null;
  }

  /// Puts an entry behind the app without walking through the preview.
  void _applyItem(WallpaperItem item) {
    final t = context.t;
    final controller = ref.read(backgroundSettingsProvider.notifier);
    if (item.video) {
      controller.setVideoUrl(item.url);
    } else {
      controller.setImageUrl(item.url);
    }
    showDsToast(context: context, title: t.settings.backgroundLibraryApplied);
  }

  /// Hands an entry to the download queue: the grid shows thumbnails, so
  /// keeping one is otherwise a trip through a browser.
  void _download(WallpaperItem item) {
    final handover = ref
        .read(wallpaperDownloadsProvider.notifier)
        .enqueueUrl(
          title: item.name,
          url: item.url,
          kind: item.video ? WallpaperDownloadKind.video : WallpaperDownloadKind.image,
          thumbUrl: item.thumb,
          fileName: wallpaperFileName(title: item.name, fallback: item.id, address: item.url),
        );
    showDownloadHandoverToast(
      context,
      handover,
      openManager: () => _openBackgroundChild(context, ref, SettingsSection.backgroundDownloads),
    );
  }

  /// The grid every page — and every skeleton row — is laid out with.
  static const SliverGridDelegateWithMaxCrossAxisExtent _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 220,
    mainAxisSpacing: DsSpace.s8,
    crossAxisSpacing: DsSpace.s8,
    childAspectRatio: _kWallpaperAspectRatio,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final source = _selectedSource;
    final categories = source.categories;
    final selectedUrl = widget.video ? settings.videoUrl : settings.imageUrl;
    // The ring means "in use": a saved picture behind a colour or gradient
    // is still remembered, but it is not what the app is painting.
    final selectedKind = widget.video ? BackgroundKind.video : BackgroundKind.image;
    final title = widget.video ? t.settings.backgroundVideosTitle : t.settings.backgroundImagesTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        if (_sources.length > 1)
          DsChoiceChips<WallpaperSourceId>(
            value: source.id,
            semanticLabel: title,
            options: [
              for (final candidate in _sources) DsChipOption(value: candidate.id, label: Text(candidate.label(t))),
            ],
            onChanged: _selectSource,
          ),
        if (categories.length > 1)
          DsChoiceChips<WallpaperCategory>(
            value: _category ?? categories.first,
            semanticLabel: source.label(t),
            options: [for (final category in categories) DsChipOption(value: category, label: Text(category.label(t)))],
            onChanged: _selectCategory,
          ),
        Expanded(
          child: _error != null
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.cloudOff),
                    title: Text(t.settings.backgroundLibraryFailed),
                    description: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis),
                    actions: [DsButton(onPressed: () => _goTo(_page), child: Text(t.common.retry))],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // The page fills the room the window gives it: whole
                    // columns across, as many whole rows down as fit above
                    // the pager, so a narrow window does not leave half the
                    // space empty while showing four tiles.
                    final columns = gridColumnsFor(constraints.maxWidth, _gridDelegate.maxCrossAxisExtent, DsSpace.s8);
                    final tileWidth = (constraints.maxWidth - (columns - 1) * DsSpace.s8) / columns;
                    final tileHeight = tileWidth / _kWallpaperAspectRatio;
                    final rows = ((constraints.maxHeight + DsSpace.s8) / (tileHeight + DsSpace.s8)).floor().clamp(
                      1,
                      1 << 10,
                    );
                    final pageSize = columns * rows;
                    if (pageSize != _pageSize) {
                      _pageSize = pageSize;
                      // The resize may have left the current page past what
                      // the buffer covers; pull what it now needs.
                      if (!_loading && (pageSize * _page > _buffer.length) && _hasMore) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) unawaited(_load());
                        });
                      }
                    }
                    final items = _slice(_page, pageSize);
                    if (items.isEmpty && !_loading) {
                      return Center(
                        child: DsEmptyState(
                          icon: const DsIcon(DsIcons.image),
                          title: Text(t.settings.backgroundLibraryEmpty),
                        ),
                      );
                    }
                    // A page on its way in keeps the grid's shape: skeleton
                    // tiles in the same slots, not a spinner in an empty box.
                    return GridView.builder(
                      primary: false,
                      padding: EdgeInsets.zero,
                      gridDelegate: _gridDelegate,
                      itemCount: items.isEmpty ? pageSize : items.length,
                      itemBuilder: (context, index) {
                        if (items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: DsSpace.s4),
                            child: DsSkeleton.block(),
                          );
                        }
                        final item = items[index];
                        return _WallpaperTile(
                          item: item,
                          selected: settings.kind == selectedKind && item.url == selectedUrl,
                          semanticLabel: '$title ${(_page - 1) * pageSize + index + 1}',
                          // The whole page travels with the tap: the preview
                          // steps through what the grid just showed, and
                          // pulls later pages as the walk reaches them.
                          onPressed: () => unawaited(showWallpaperPreview(context, items, index, more: _loadMore)),
                          onApply: () => _applyItem(item),
                          onDownload: () => _download(item),
                        );
                      },
                    );
                  },
                ),
        ),
        if (_error == null)
          Align(
            alignment: AlignmentDirectional.center,
            child: DsPagination(page: _page, pageCount: _pageCount, onChanged: _goTo, semanticLabel: title),
          ),
      ],
    );
  }
}

/// One grid entry. A tap opens the full preview; a long press or right click
/// offers the same preview plus applying it as is and downloading it.
final class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.item,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
    required this.onApply,
    required this.onDownload,
  });

  final WallpaperItem item;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;
  final VoidCallback onApply;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final inset = selected ? 3.0 : 1.0;
    final radius = theme.radii.card;
    return DsContextMenuRegion(
      semanticLabel: semanticLabel,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.eye),
          label: Text(t.settings.backgroundPreviewMedia),
          onPressed: onPressed,
        ),
        DsMenuItem(leading: const DsIcon(DsIcons.check), label: Text(t.settings.backgroundApply), onPressed: onApply),
        DsMenuItem(
          leading: const DsIcon(DsIcons.download),
          label: Text(t.settings.downloadAction),
          onPressed: onDownload,
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.link),
          label: Text(t.settings.backgroundCopyAddress),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: item.url));
            if (context.mounted) showDsToast(context: context, title: t.common.copied);
          },
        ),
      ],
      child: DsPressable(
        semanticLabel: semanticLabel,
        selected: selected,
        onPressed: onPressed,
        builder: (context, states, _) => Container(
          padding: EdgeInsets.all(inset),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? colors.accent
                  : states.contains(WidgetState.hovered)
                  ? colors.textSubtle
                  : colors.border,
              width: inset,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - inset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DsImage(
                  image: cachedImage(item.thumb),
                  aspectRatio: _kWallpaperAspectRatio,
                  semanticLabel: semanticLabel,
                  fallback: ColoredBox(color: colors.control),
                ),
                if (item.video) const Center(child: DsIcon(DsIcons.play, size: 26, color: Color(0xCCFFFFFF))),
                if (selected)
                  const PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: DsIcon(DsIcons.checkCircle, size: 20, color: Color(0xFFFFFFFF)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public random-picture APIs, grouped. A row fetches a fresh picture in a
/// preview; nothing is applied until the viewer keeps one.
final class BackgroundRandomPane extends ConsumerStatefulWidget {
  const BackgroundRandomPane({super.key});

  @override
  ConsumerState<BackgroundRandomPane> createState() => _BackgroundRandomPaneState();
}

final class _BackgroundRandomPaneState extends ConsumerState<BackgroundRandomPane> {
  RandomWallpaperGroup _group = randomWallpaperGroups.first;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        DsChoiceChips<RandomWallpaperGroup>(
          value: _group,
          semanticLabel: t.wallpaper.title,
          options: [for (final group in randomWallpaperGroups) DsChipOption(value: group, label: Text(group.label(t)))],
          onChanged: (group) => setState(() => _group = group),
        ),
        DsListSection(
          header: Text(t.wallpaper.sourceCount(count: _group.sources.length)),
          children: [
            for (final source in _group.sources)
              DsListRow(
                leading: const DsIcon(DsIcons.globe),
                title: Text(source.label(t)),
                description: Text(source.host),
                showChevron: true,
                onPressed: () => unawaited(showRandomWallpaperPreview(context, source)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Local files and network addresses: the only page that writes a local
/// path or takes a typed URL.
final class BackgroundDevicePane extends ConsumerStatefulWidget {
  /// Creates the page.
  const BackgroundDevicePane({super.key});

  @override
  ConsumerState<BackgroundDevicePane> createState() => _BackgroundDevicePaneState();
}

final class _BackgroundDevicePaneState extends ConsumerState<BackgroundDevicePane> {
  final TextEditingController _imageUrl = TextEditingController();
  final TextEditingController _videoUrl = TextEditingController();

  /// Which of the two sources the page is showing: one card at a time, so the
  /// page does not carry two drop zones and two address fields at once.
  BackgroundMediaKind _kind = BackgroundMediaKind.image;

  /// Which zone a drag is over, so the kit draws the drop affordance there.
  bool _imageDragging = false;
  bool _videoDragging = false;

  /// The formats under a drop zone, in the order the importer accepts them.
  static String _formatsOf(List<String> extensions) =>
      [for (final extension in extensions) extension.toUpperCase()].join(' · ');

  @override
  void initState() {
    super.initState();
    // The fields stay empty on purpose: prefilled with the address already in
    // use, they read as text the viewer typed (or as a page that filled itself
    // in). What is in use now is named under the field instead.
  }

  @override
  void dispose() {
    _imageUrl.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    final muted = DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted);
    final video = _kind == BackgroundMediaKind.video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // Content-width, like the chips elsewhere: two words do not need the
        // whole row's worth of rail.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsSegmentedControl<BackgroundMediaKind>(
            value: _kind,
            semanticLabel: t.settings.backgroundDeviceTitle,
            segments: [
              DsSegment(
                value: BackgroundMediaKind.image,
                label: Text(t.settings.backgroundImage),
                icon: const DsIcon(DsIcons.image, size: 16),
              ),
              DsSegment(
                value: BackgroundMediaKind.video,
                label: Text(t.settings.backgroundVideo),
                icon: const DsIcon(DsIcons.video, size: 16),
              ),
            ],
            onChanged: (value) => setState(() => _kind = value),
          ),
        ),
        if (settings.error.isNotEmpty)
          DsAlert(
            status: DsStatus.danger,
            title: Text(t.settings.backgroundImportFailed),
            description: Text(settings.error, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        if (settings.busy)
          Row(
            spacing: DsSpace.s8,
            children: [
              const SizedBox(width: 14, height: 14, child: DsSpinner()),
              Text(t.settings.backgroundBusy, style: muted),
            ],
          ),
        _sourceSection(
          context,
          title: video ? t.settings.backgroundVideo : t.settings.backgroundImage,
          addressLabel: video ? t.settings.backgroundVideoAddress : t.settings.backgroundImageAddress,
          formats: _formatsOf(video ? kBackgroundVideoExtensions : kBackgroundImageExtensions),
          controller: video ? _videoUrl : _imageUrl,
          path: video ? settings.videoPath : settings.imagePath,
          saved: video ? settings.videoUrl : settings.imageUrl,
          busy: settings.busy,
          dragging: video ? _videoDragging : _imageDragging,
          onDraggingChanged: (value) => setState(() => video ? _videoDragging = value : _imageDragging = value),
          onBrowse: _upload,
          onSubmit: () => _previewTyped(video: video),
          onRemove: () => controller.removeFile(image: !video),
          onPreview: (path) => _preview(_itemOf(path, video: video)),
          onDrop: _drop,
        ),
      ],
    );
  }

  /// One media source: the whole card is the drop zone (drag anywhere on it),
  /// the file it copied, and the network address that can stand in for it.
  Widget _sourceSection(
    BuildContext context, {
    required String title,
    required String addressLabel,
    required String formats,
    required TextEditingController controller,
    required String path,
    required String saved,
    required bool busy,
    required bool dragging,
    required ValueChanged<bool> onDraggingChanged,
    required VoidCallback onBrowse,
    required VoidCallback onSubmit,
    required VoidCallback onRemove,
    required ValueChanged<String> onPreview,
    required ValueChanged<DropDoneDetails> onDrop,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DropTarget(
      onDragEntered: (_) => onDraggingChanged(true),
      onDragExited: (_) => onDraggingChanged(false),
      onDragDone: onDrop,
      // No header: the switch above names the kind, and one more line saying
      // it would only repeat the tab.
      child: DsListSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                DsFileUpload(
                  onBrowse: busy ? null : onBrowse,
                  dragging: dragging,
                  semanticLabel: title,
                  description: Text(formats),
                  files: [
                    if (path.isNotEmpty)
                      DsContextMenuRegion(
                        semanticLabel: p.basename(path),
                        items: [
                          DsMenuItem(
                            leading: const DsIcon(DsIcons.eye),
                            label: Text(t.settings.backgroundPreviewMedia),
                            onPressed: () => onPreview(path),
                          ),
                          DsMenuItem(
                            leading: const DsIcon(DsIcons.download),
                            label: Text(t.settings.downloadAction),
                            onPressed: () => unawaited(_saveCopy(path)),
                          ),
                          DsMenuItem(
                            leading: const DsIcon(DsIcons.trash2),
                            label: Text(t.common.delete),
                            onPressed: busy ? null : onRemove,
                          ),
                        ],
                        child: DsFileItem(
                          name: p.basename(path),
                          size: _sizeOf(path),
                          onRemove: busy ? null : onRemove,
                        ),
                      ),
                  ],
                ),
                Text(addressLabel, style: theme.typography.body.copyWith(color: colors.text)),
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: DsTextField(
                        controller: controller,
                        placeholder: t.settings.backgroundAddressHint,
                        semanticLabel: addressLabel,
                        onSubmitted: (_) => onSubmit(),
                      ),
                    ),
                    DsButton(onPressed: busy ? null : onSubmit, child: Text(t.settings.backgroundPreviewMedia)),
                  ],
                ),
                if (saved.isNotEmpty)
                  Text(
                    '${t.settings.backgroundAddressInUse}: $saved',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTheme.of(context).typography.small.copyWith(color: colors.textSubtle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A dropped file or link goes to the preview, not straight onto the app:
  /// the picker and the address field follow the same rule.
  Future<void> _drop(DropDoneDetails details) async {
    final t = context.t;
    setState(() {
      _imageDragging = false;
      _videoDragging = false;
    });
    final file = details.files.firstOrNull;
    if (file == null) {
      // A link dragged from a browser arrives as text, not as a file. Its
      // path extension still says what it is; a link without one is a picture.
      final text = (details.rawText ?? '').trim();
      final uri = Uri.tryParse(text);
      if (text.isNotEmpty && uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        _previewAddress(text, video: backgroundMediaKindOf(uri.path) == BackgroundMediaKind.video);
        return;
      }
      showDsToast(context: context, title: t.settings.backgroundDropUnsupported, status: DsStatus.danger);
      return;
    }
    final path = file.path;
    final kind = backgroundMediaKindOf(path.isEmpty ? file.name : path);
    if (path.isEmpty || kind == null) {
      showDsToast(context: context, title: t.settings.backgroundDropUnsupported, status: DsStatus.danger);
      return;
    }
    _preview(_itemOf(path, video: kind == BackgroundMediaKind.video));
  }

  /// Opens [address] in the preview; nothing reaches the app until the viewer
  /// keeps it there.
  void _previewAddress(String address, {required bool video}) {
    final t = context.t;
    final uri = Uri.tryParse(address.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      showDsToast(context: context, title: t.settings.backgroundInvalidUrl, status: DsStatus.danger);
      return;
    }
    _preview(_itemOf(address, video: video));
  }

  /// The address field's button: the link just typed, or the file already in
  /// the slot when the field is empty.
  void _previewTyped({required bool video}) {
    final typed = (video ? _videoUrl : _imageUrl).text;
    if (typed.trim().isNotEmpty) {
      _previewAddress(typed, video: video);
      return;
    }
    final settings = ref.read(backgroundSettingsProvider);
    final path = video ? settings.videoPath : settings.imagePath;
    if (path.isEmpty) {
      showDsToast(context: context, title: context.t.settings.backgroundInvalidUrl, status: DsStatus.danger);
      return;
    }
    _preview(_itemOf(path, video: video));
  }

  int? _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } on Object {
      return null;
    }
  }

  /// A card's address as a preview entry: an http(s) address or a path on
  /// disk. Anything else has no preview to show.
  WallpaperItem? _itemOf(String address, {required bool video}) {
    final text = address.trim();
    if (text.isEmpty) return null;
    final parsed = Uri.tryParse(text);
    final scheme = parsed?.scheme ?? '';
    final uri = switch (scheme) {
      'http' || 'https' || 'file' => parsed,
      // A path typed or handed over by the importer: no scheme to read.
      _ when text.contains('/') || text.contains(r'\') => Uri.file(text),
      _ => null,
    };
    if (uri == null) return null;
    final name = uri.scheme == 'file'
        ? p.basename(uri.toFilePath())
        : (uri.pathSegments.isEmpty ? text : uri.pathSegments.last);
    return WallpaperItem(
      (builder) => builder
        ..id = uri.toString()
        ..name = name
        ..url = uri.toString()
        ..thumb = uri.toString()
        ..video = video,
    );
  }

  /// Opens [item] in the app's own preview page: the same stage, scrim and
  /// apply button the online entries get, rather than handing the file to
  /// whatever the system opens it with. Nothing is applied until the viewer
  /// keeps it there.
  void _preview(WallpaperItem? item) {
    if (item == null) return;
    unawaited(showWallpaperPreview(context, [item], 0));
  }

  /// Copies the imported file into the shared download folder, so the
  /// original can be moved or cleaned up without losing the choice.
  Future<void> _saveCopy(String path) async {
    final name = p.basename(path);
    final handover = await ref
        .read(wallpaperDownloadsProvider.notifier)
        .enqueueCopy(
          title: name,
          sourcePath: path,
          fileName: name,
          kind: backgroundMediaKindOf(name) == BackgroundMediaKind.video
              ? WallpaperDownloadKind.video
              : WallpaperDownloadKind.image,
        );
    if (!mounted) return;
    showDownloadHandoverToast(
      context,
      handover,
      openManager: () => _openBackgroundChild(context, ref, SettingsSection.backgroundDownloads),
    );
  }

  /// Picks a picture or a clip and opens it in the preview: the file's own
  /// type decides how it is walked, and nothing is copied into the app's
  /// folder until the viewer keeps it there.
  Future<void> _upload() async {
    final t = context.t;
    final file = await FilePicker.pickFile(
      dialogTitle: t.settings.backgroundDeviceTitle,
      type: FileType.custom,
      allowedExtensions: [...kBackgroundImageExtensions, ...kBackgroundVideoExtensions],
    );
    if (!mounted || file == null) return;
    final path = file.path ?? '';
    final kind = backgroundMediaKindOf(path) ?? backgroundMediaKindOf(file.name);
    if (path.isEmpty || kind == null) {
      showDsToast(context: context, title: t.settings.backgroundDropUnsupported, status: DsStatus.danger);
      return;
    }
    _preview(_itemOf(path, video: kind == BackgroundMediaKind.video));
  }
}

String backgroundFitLabel(Translations t, BoxFit fit) => switch (fit) {
  BoxFit.cover => t.settings.backgroundFitCover,
  BoxFit.contain => t.settings.backgroundFitContain,
  BoxFit.fill => t.settings.backgroundFitFill,
  BoxFit.fitWidth => t.settings.backgroundFitWidth,
  BoxFit.fitHeight => t.settings.backgroundFitHeight,
  BoxFit.none => t.settings.backgroundFitNone,
  BoxFit.scaleDown => t.settings.backgroundFitScaleDown,
};
