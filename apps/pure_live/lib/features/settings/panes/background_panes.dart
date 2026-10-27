import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:desktop_drop/desktop_drop.dart' show DropDoneDetails, DropTarget;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart';
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
    // Fit and the media blur only act on a surface that has an image or
    // video to place; on the flat kinds they stay visible and inert.
    final media = settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.backgroundDisplay),
          children: [
            SettingsChoiceRow<BoxFit>(
              leading: const DsIcon(DsIcons.expand),
              title: t.settings.backgroundFit,
              description: t.settings.backgroundFitDescription,
              value: settings.fit,
              options: [
                for (final fit in kBackgroundFits) DsSelectOption(value: fit, label: backgroundFitLabel(t, fit)),
              ],
              onChanged: media ? controller.setFit : null,
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.contrast),
              title: t.settings.backgroundMask,
              description: t.settings.backgroundMaskDescription,
              detail: Text('${(settings.maskOpacity * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: settings.maskOpacity,
                max: 0.8,
                divisions: 16,
                onChanged: controller.setMaskOpacity,
                semanticLabel: t.settings.backgroundMask,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.layers),
              title: t.settings.backgroundOverlayBlur,
              description: t.settings.backgroundOverlayBlurDescription,
              detail: Text('${settings.overlayBlurSigma.round()}'),
              controlWidth: 220,
              control: DsSlider(
                value: settings.overlayBlurSigma,
                // Capped low: this filters the backdrop every frame, not a
                // still image once.
                max: 24,
                divisions: 24,
                onChanged: controller.setOverlayBlurSigma,
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

/// Rows a page holds. The page size is always a whole number of rows, so a
/// page never ends with one tile short of a line however wide the window is.
const int _kPageRows = 4;

/// Columns of a max-extent grid at [width]: the same arithmetic
/// `SliverGridDelegateWithMaxCrossAxisExtent` uses.
int gridColumnsFor(double width, double maxExtent, double spacing) =>
    ((width + spacing) / (maxExtent + spacing)).floor().clamp(1, 1 << 12);

/// Solid colours and gradients, each pointing at the live app background;
/// a tap is the preview and the choice at once.
///
/// Both groups are paged. The ported table is twelve flats and 139 gradients,
/// and one scroll of 151 swatches is neither readable nor quick to walk with a
/// keyboard or a remote.
final class BackgroundColorsPane extends ConsumerStatefulWidget {
  const BackgroundColorsPane({super.key});

  @override
  ConsumerState<BackgroundColorsPane> createState() => _BackgroundColorsPaneState();
}

final class _BackgroundColorsPaneState extends ConsumerState<BackgroundColorsPane> {
  int _solidPage = 1;
  int _gradientPage = 1;

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            DsListSection(
              header: Text(t.settings.backgroundSolid),
              children: [
                Padding(
                  padding: const EdgeInsets.all(DsSpace.s12),
                  child: Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      for (final preset in solids)
                        _Swatch(
                          name: preset.name,
                          decoration: BoxDecoration(color: preset.color),
                          selected: settings.kind == BackgroundKind.solid && settings.solidColor == preset.color,
                          onPressed: () => controller.setSolid(preset.color),
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
            ),
            DsListSection(
              header: Text(t.settings.backgroundGradient),
              children: [
                Padding(
                  padding: const EdgeInsets.all(DsSpace.s12),
                  child: Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      for (final preset in gradients)
                        _Swatch(
                          name: preset.name,
                          decoration: _gradientOf(preset),
                          selected: settings.kind == BackgroundKind.gradient && _sameGradient(settings, preset),
                          onPressed: () => controller.setGradient(preset),
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
/// this is what the app is wearing.
final class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.decoration, required this.selected, required this.onPressed});

  /// The colour or gradient, in the form the background paints with.
  final BoxDecoration decoration;

  /// What the source table calls it.
  final String name;

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return SizedBox(
      width: _kSwatchTileWidth.toDouble(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          DsPressable(
            semanticLabel: name,
            selected: selected,
            onPressed: onPressed,
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
    );
  }
}

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

  /// Jumps to [page] and loads it; the same call retries a failed page.
  void _goTo(int page) {
    final target = page < 1 ? 1 : page;
    if (target == _page && _error == null) return;
    setState(() {
      _page = target;
      _error = null;
    });
    unawaited(_load());
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

  /// The grid every page — and every skeleton row — is laid out with.
  static const SliverGridDelegateWithMaxCrossAxisExtent _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 220,
    mainAxisSpacing: DsSpace.s8,
    crossAxisSpacing: DsSpace.s8,
    childAspectRatio: 16 / 10,
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
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s24),
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.cloudOff),
              title: Text(t.settings.backgroundLibraryFailed),
              description: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis),
              actions: [DsButton(onPressed: () => _goTo(_page), child: Text(t.common.retry))],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // Whole rows of this width: a page that ended one tile short
              // was the old scroll-append list's tell.
              final columns = gridColumnsFor(constraints.maxWidth, _gridDelegate.maxCrossAxisExtent, DsSpace.s8);
              final pageSize = columns * _kPageRows;
              if (pageSize != _pageSize) {
                _pageSize = pageSize;
                // The resize may have left the current page past what the
                // buffer covers; pull what it now needs.
                if (!_loading && (pageSize * _page > _buffer.length) && _hasMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_load());
                  });
                }
              }
              final items = _slice(_page, pageSize);
              if (items.isEmpty && !_loading) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
                  child: Center(
                    child: DsEmptyState(
                      icon: const DsIcon(DsIcons.image),
                      title: Text(t.settings.backgroundLibraryEmpty),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s12,
                children: [
                  // A page on its way in keeps the grid's shape: skeleton
                  // tiles in the same slots, not a spinner in an empty box.
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                        // steps through what the grid just showed.
                        onPressed: () => unawaited(showWallpaperPreview(context, items, index)),
                      );
                    },
                  ),
                  Align(
                    alignment: AlignmentDirectional.center,
                    child: DsPagination(
                      page: _page,
                      pageCount: _pageCount,
                      onChanged: _loading ? null : _goTo,
                      semanticLabel: title,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

final class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.item,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
  });

  final WallpaperItem item;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      selected: selected,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        decoration: BoxDecoration(
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
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DsImage(
              image: cachedImage(item.thumb),
              aspectRatio: 16 / 10,
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

  /// Which zone a drag is over, so the kit draws the drop affordance there.
  bool _imageDragging = false;
  bool _videoDragging = false;

  /// The file types each zone accepts; the picker filters by kind, a drop
  /// arrives with whatever the desktop had.
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'};
  static const _videoExtensions = {'.mp4', '.webm', '.mkv', '.mov', '.m4v', '.avi'};

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
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
          title: t.settings.backgroundImage,
          addressLabel: t.settings.backgroundImageAddress,
          formats: 'PNG · JPG · WEBP · GIF',
          controller: _imageUrl,
          path: settings.imagePath,
          saved: settings.imageUrl,
          busy: settings.busy,
          dragging: _imageDragging,
          onDraggingChanged: (value) => setState(() => _imageDragging = value),
          onBrowse: () => _upload(image: true),
          onApply: () => _apply(image: true),
          onRemove: () => controller.removeFile(image: true),
          onDrop: (details) => _drop(details, image: true),
        ),
        _sourceSection(
          context,
          title: t.settings.backgroundVideo,
          addressLabel: t.settings.backgroundVideoAddress,
          formats: 'MP4 · WEBM · MKV',
          controller: _videoUrl,
          path: settings.videoPath,
          saved: settings.videoUrl,
          busy: settings.busy,
          dragging: _videoDragging,
          onDraggingChanged: (value) => setState(() => _videoDragging = value),
          onBrowse: () => _upload(image: false),
          onApply: () => _apply(image: false),
          onRemove: () => controller.removeFile(image: false),
          onDrop: (details) => _drop(details, image: false),
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
    required VoidCallback onApply,
    required VoidCallback onRemove,
    required ValueChanged<DropDoneDetails> onDrop,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DropTarget(
      onDragEntered: (_) => onDraggingChanged(true),
      onDragExited: (_) => onDraggingChanged(false),
      onDragDone: onDrop,
      child: DsListSection(
        header: Text(title),
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
                      DsFileItem(name: p.basename(path), size: _sizeOf(path), onRemove: busy ? null : onRemove),
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
                        onSubmitted: (_) => onApply(),
                      ),
                    ),
                    DsButton(onPressed: busy ? null : onApply, child: Text(t.settings.backgroundApply)),
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

  /// Copies a file dropped on [image]'s zone; a drop the zone does not take
  /// says so instead of failing later in the decoder.
  Future<void> _drop(DropDoneDetails details, {required bool image}) async {
    final t = context.t;
    if (image) {
      setState(() => _imageDragging = false);
    } else {
      setState(() => _videoDragging = false);
    }
    if (ref.read(backgroundSettingsProvider).busy) return;
    final file = details.files.firstOrNull;
    if (file == null) {
      // A link dragged from a browser arrives as text, not as a file.
      final text = (details.rawText ?? '').trim();
      final uri = Uri.tryParse(text);
      if (text.isNotEmpty && uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        (image ? _imageUrl : _videoUrl).text = text;
        _apply(image: image);
        return;
      }
      showDsToast(context: context, title: t.settings.backgroundDropUnsupported, status: DsStatus.danger);
      return;
    }
    final path = file.path;
    final extension = p.extension(path).toLowerCase();
    if (!(image ? _imageExtensions : _videoExtensions).contains(extension)) {
      showDsToast(context: context, title: t.settings.backgroundDropUnsupported, status: DsStatus.danger);
      return;
    }
    await ref.read(backgroundSettingsProvider.notifier).importDroppedFile(path, image: image);
    if (!mounted) return;
    final settings = ref.read(backgroundSettingsProvider);
    if (image) {
      _imageUrl.text = settings.imageUrl;
    } else {
      _videoUrl.text = settings.videoUrl;
    }
    if (settings.error.isNotEmpty) {
      showDsToast(
        context: context,
        title: t.settings.backgroundImportFailed,
        description: settings.error,
        status: DsStatus.danger,
      );
    }
  }

  int? _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } on Object {
      return null;
    }
  }

  void _apply({required bool image}) {
    final t = context.t;
    final settings = ref.read(backgroundSettingsProvider);
    final url = (image ? _imageUrl : _videoUrl).text.trim();
    if (url.isEmpty) {
      // Nothing typed. With a file already in place the field is simply left
      // alone; with none, an empty address would switch the kind to a picture
      // that has no source — nothing paints and the setting looks broken.
      if ((image ? settings.imagePath : settings.videoPath).isEmpty) {
        showDsToast(context: context, title: t.settings.backgroundInvalidUrl, status: DsStatus.danger);
      }
      return;
    }
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
        showDsToast(context: context, title: t.settings.backgroundInvalidUrl, status: DsStatus.danger);
        return;
      }
    }
    final controller = ref.read(backgroundSettingsProvider.notifier);
    image ? controller.setImageUrl(url) : controller.setVideoUrl(url);
  }

  Future<void> _upload({required bool image}) async {
    final t = context.t;
    final controller = ref.read(backgroundSettingsProvider.notifier);
    if (image) {
      await controller.uploadImage(dialogTitle: t.settings.backgroundUploadImage);
    } else {
      await controller.uploadVideo(dialogTitle: t.settings.backgroundUploadVideo);
    }
    if (!mounted) return;
    final settings = ref.read(backgroundSettingsProvider);
    if (image) {
      _imageUrl.text = settings.imageUrl;
    } else {
      _videoUrl.text = settings.videoUrl;
    }
    if (settings.error.isNotEmpty) {
      showDsToast(
        context: context,
        title: t.settings.backgroundImportFailed,
        description: settings.error,
        status: DsStatus.danger,
      );
    }
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
