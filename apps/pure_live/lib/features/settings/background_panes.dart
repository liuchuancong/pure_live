import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/background/background_library.dart' show backgroundLibraryClientProvider;
import 'package:pure_live/app/background/background_library_catalog.dart' show wallpaperSources;
import 'package:pure_live/app/background/background_library_models.dart';
import 'package:pure_live/app/background/background_presets.dart'
    show kBackgroundGradientPresets, kBackgroundSolidPresets, kDefaultGradientBegin, kDefaultGradientEnd;
import 'package:pure_live/app/background/background_settings.dart';
import 'package:pure_live/app/background/background_video_source.dart' show AppBackgroundVideoSource;
import 'package:pure_live/app/background/random_wallpaper_catalog.dart';
import 'package:pure_live/app/background/random_wallpaper_client.dart';
import 'package:pure_live/app/providers/environment_providers.dart' show deviceProfileProvider;
import 'package:pure_live/app/providers/settings_section_provider.dart' show settingsSectionProvider;
import 'package:pure_live/app/routing/app_router.dart' show SettingsSectionRoute;
import 'package:pure_live/features/settings/settings_sections.dart';
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;
import 'package:pure_live/shared/widgets/app_loading_indicator.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart' show PureBackground, SolidBackground, VideoBackground;

const double _kBackgroundCompactWidth = 768;

/// Opens a background source page: desktop switches the settings pane in
/// place, a touch shell pushes the route.
void _openBackgroundChild(BuildContext context, WidgetRef ref, SettingsSection section) {
  ref.read(settingsSectionProvider.notifier).section = section;
  final compact =
      !ref.read(deviceProfileProvider).isDesktop && MediaQuery.sizeOf(context).width < _kBackgroundCompactWidth;
  if (compact) unawaited(context.push(SettingsSectionRoute(section: section.name).location));
}

/// Background settings' landing page: the current background, the routes to
/// each source, and the display controls that apply to every kind.
final class BackgroundOverviewPane extends ConsumerWidget {
  const BackgroundOverviewPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    final children = settingsChildrenOf(SettingsSection.background);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        _CurrentBackgroundPreview(settings: settings),
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
        DsListSection(
          header: Text(t.settings.backgroundDisplay),
          children: [
            if (settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.video)
              SettingsChoiceRow<BoxFit>(
                leading: const DsIcon(DsIcons.scan),
                title: t.settings.backgroundFit,
                value: settings.fit,
                options: [for (final fit in kBackgroundFits) DsSelectOption(value: fit, label: _fitLabel(t, fit))],
                onChanged: controller.setFit,
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
            if (settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.video)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.waves),
                title: t.settings.backgroundBlur,
                description: t.settings.backgroundBlurDescription,
                detail: Text('${settings.blurSigma.round()}'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.blurSigma,
                  max: 40,
                  divisions: 40,
                  onChanged: controller.setBlurSigma,
                  semanticLabel: t.settings.backgroundBlur,
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
      ],
    );
  }
}

/// The saved background as a card. A video shows a still hint instead of a
/// second decoder; it is already painting behind the settings.
final class _CurrentBackgroundPreview extends ConsumerWidget {
  const _CurrentBackgroundPreview({required this.settings});

  final BackgroundSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final body = switch (settings.kind) {
      BackgroundKind.none => ColoredBox(
        color: colors.control,
        child: Center(
          child: Text(t.settings.backgroundEmpty, style: theme.typography.small.copyWith(color: colors.textMuted)),
        ),
      ),
      BackgroundKind.solid => ColoredBox(color: settings.solidColor),
      BackgroundKind.gradient => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: kDefaultGradientBegin,
            end: kDefaultGradientEnd,
            colors: settings.gradientColors,
          ),
        ),
      ),
      BackgroundKind.image => _imagePreview(context, colors),
      BackgroundKind.video => ColoredBox(
        color: const Color(0xFF101418),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              const DsIcon(DsIcons.play, size: 28, color: Color(0xCCFFFFFF)),
              Text(
                t.settings.backgroundPreviewVideoHint,
                style: theme.typography.caption.copyWith(color: const Color(0xCCFFFFFF)),
              ),
            ],
          ),
        ),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.settings.backgroundPreview, style: theme.typography.heading.copyWith(color: colors.text)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.card),
              child: AspectRatio(aspectRatio: 16 / 9, child: body),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePreview(BuildContext context, DsColors colors) {
    final path = settings.imagePath;
    final url = settings.imageUrl;
    final image = path.isNotEmpty && File(path).existsSync()
        ? FileImage(File(path))
        : (url.isNotEmpty ? cachedImage(url) : null);
    if (image == null) return ColoredBox(color: colors.control);
    return DsImage(
      image: image,
      aspectRatio: 16 / 9,
      fallback: _PreviewFallback(message: context.t.settings.backgroundPreviewUnavailable),
    );
  }
}

/// Solid colours and gradients, each pointing at the live app background;
/// a tap is the preview and the choice at once.
final class BackgroundColorsPane extends ConsumerWidget {
  const BackgroundColorsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
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
                  for (final color in kBackgroundSolidPresets)
                    _SolidSwatch(
                      color: color,
                      selected: settings.kind == BackgroundKind.solid && settings.solidColor == color,
                      semanticLabel: t.settings.backgroundSolid,
                      onPressed: () => controller.setSolid(color),
                    ),
                ],
              ),
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
                  for (final (index, preset) in kBackgroundGradientPresets.indexed)
                    _GradientSwatch(
                      colors: preset.colors,
                      begin: preset.begin,
                      end: preset.end,
                      selected:
                          settings.kind == BackgroundKind.gradient &&
                          _sameColors(settings.gradientColors, preset.colors),
                      semanticLabel: '${t.settings.backgroundGradient} ${index + 1}',
                      onPressed: () => controller.setGradient(preset.colors),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class _SolidSwatch extends StatelessWidget {
  const _SolidSwatch({
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      selected: selected,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? colors.accent
                : states.contains(WidgetState.hovered)
                ? colors.textSubtle
                : colors.border,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected ? Center(child: DsIcon(DsIcons.check, size: 18, color: colors.onAccent)) : null,
      ),
    );
  }
}

final class _GradientSwatch extends StatelessWidget {
  const _GradientSwatch({
    required this.colors,
    required this.begin,
    required this.end,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
  });

  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = DsTheme.of(context);
    final theme = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      selected: selected,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: 108,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: begin, end: end, colors: colors),
          borderRadius: BorderRadius.circular(ui.radii.card),
          border: Border.all(
            color: selected
                ? theme.accent
                : states.contains(WidgetState.hovered)
                ? theme.textSubtle
                : theme.border,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected ? const Center(child: DsIcon(DsIcons.check, size: 20, color: Color(0xFFFFFFFF))) : null,
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
  final List<WallpaperItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;
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
    unawaited(_load(reset: true));
  }

  WallpaperSource get _selectedSource =>
      _sources.firstWhere((source) => source.id == _source.id, orElse: () => _sources.first);

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _generation++;
      setState(() {
        _items.clear();
        _page = 0;
        _hasMore = true;
        _error = null;
      });
    }
    if (!reset && (_loading || !_hasMore)) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = _page + 1;
      final items = await ref
          .read(backgroundLibraryClientProvider)
          .fetch(source: _selectedSource, category: _category, page: page);
      if (!mounted || generation != _generation) return;
      final seen = {for (final item in _items) item.url};
      setState(() {
        _page = page;
        _items.addAll(items.where((item) => seen.add(item.url)));
        _hasMore = items.length >= _selectedSource.pageSize && !_selectedSource.isLocal;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _selectSource(WallpaperSourceId id) {
    if (id == _source.id) return;
    setState(() {
      _source = _sources.firstWhere((source) => source.id == id, orElse: () => _sources.first);
      _category = _source.categories.firstOrNull;
    });
    unawaited(_load(reset: true));
  }

  void _selectCategory(WallpaperCategory category) {
    if (category.id == _category?.id) return;
    setState(() => _category = category);
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final settings = ref.watch(backgroundSettingsProvider);
    final source = _selectedSource;
    final categories = source.categories;
    final selectedUrl = widget.video ? settings.videoUrl : settings.imageUrl;
    // The ring means "in use": a saved picture behind a colour or gradient
    // is still remembered, but it is not what the app is painting.
    final selectedKind = widget.video ? BackgroundKind.video : BackgroundKind.image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        if (_sources.length > 1)
          DsChoiceChips<WallpaperSourceId>(
            value: source.id,
            semanticLabel: widget.video ? t.settings.backgroundVideosTitle : t.settings.backgroundImagesTitle,
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
              actions: [DsButton(onPressed: () => unawaited(_load(reset: true)), child: Text(t.common.retry))],
            ),
          )
        else if (_items.isEmpty && _loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DsSpace.s32),
            child: Center(child: AppLoadingIndicator(size: 24)),
          )
        else if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
            child: DsEmptyState(icon: const DsIcon(DsIcons.image), title: Text(t.settings.backgroundLibraryEmpty)),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: DsSpace.s8,
              crossAxisSpacing: DsSpace.s8,
              childAspectRatio: 16 / 10,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _WallpaperTile(
                item: item,
                selected: settings.kind == selectedKind && item.url == selectedUrl,
                semanticLabel: '${source.label(t)} ${index + 1}',
                onPressed: () => unawaited(showWallpaperPreview(context, item)),
              );
            },
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DsSpace.s12),
              child: Center(child: AppLoadingIndicator(size: 20)),
            )
          else if (_hasMore)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_load(reset: false)),
                child: Text(t.settings.backgroundLibraryLoadMore),
              ),
            ),
        ],
        Text(
          source.isLocal ? t.settings.backgroundLibraryLocalHint : t.settings.backgroundLibraryNetworkHint,
          style: theme.typography.small.copyWith(color: colors.textSubtle),
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

/// One wallpaper full-size, with the apply action kept out of the grid: a
/// tap that silently replaced the background would be a trap.
Future<void> showWallpaperPreview(BuildContext context, WallpaperItem item) => showDsDialog<void>(
  context: context,
  builder: (context) => _WallpaperPreviewDialog(item: item),
);

final class _WallpaperPreviewDialog extends ConsumerWidget {
  const _WallpaperPreviewDialog({required this.item});

  final WallpaperItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final ui = DsTheme.of(context);
    final borderRadius = BorderRadius.circular(ui.radii.card);
    final preview = item.video
        ? AspectRatio(
            aspectRatio: 16 / 10,
            child: PureBackground(
              config: VideoBackground(
                source: AppBackgroundVideoSource(Uri.parse(item.url)),
                fit: BoxFit.contain,
                underlay: const SolidBackground(color: Color(0xFF000000)),
              ),
              clip: Clip.antiAlias,
              borderRadius: borderRadius,
            ),
          )
        : DsImage(
            image: cachedImage(item.url),
            aspectRatio: 16 / 10,
            fit: BoxFit.contain,
            semanticLabel: t.settings.backgroundPreviewTitle,
            fallback: _PreviewFallback(message: t.settings.backgroundPreviewUnavailable),
          );
    void apply() {
      final controller = ref.read(backgroundSettingsProvider.notifier);
      if (item.video) {
        controller.setVideoUrl(item.url);
      } else {
        controller.setImageUrl(item.url);
      }
      showDsToast(context: context, title: t.settings.backgroundLibraryApplied);
      Navigator.of(context).pop();
    }

    return DsDialog(
      title: Text(t.settings.backgroundPreviewTitle),
      description: ClipRRect(borderRadius: borderRadius, child: preview),
      style: const DsDialogStyle(width: 560),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(onPressed: apply, child: Text(t.settings.backgroundApply)),
      ],
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
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
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
        Text(t.wallpaper.networkHint, style: theme.typography.small.copyWith(color: colors.textSubtle)),
      ],
    );
  }
}

/// Opens a fresh picture from [source] in a preview. The picture is only
/// fetched now; the dialog offers another one until the viewer applies it.
Future<void> showRandomWallpaperPreview(BuildContext context, RandomWallpaperSource source) => showDsDialog<void>(
  context: context,
  builder: (context) => _RandomWallpaperPreviewDialog(source: source),
);

final class _RandomWallpaperPreviewDialog extends ConsumerStatefulWidget {
  const _RandomWallpaperPreviewDialog({required this.source});

  final RandomWallpaperSource source;

  @override
  ConsumerState<_RandomWallpaperPreviewDialog> createState() => _RandomWallpaperPreviewDialogState();
}

final class _RandomWallpaperPreviewDialogState extends ConsumerState<_RandomWallpaperPreviewDialog> {
  RandomWallpaperPicture? _picture;
  RandomWallpaperFailure? _failure;
  bool _loading = true;
  bool _saving = false;

  /// The newest request this dialog started; a slow answer for a picture the
  /// viewer already replaced must not overwrite the new one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    final generation = ++_generation;
    if (_loading) {
      // The first fetch starts in initState, where the fields are already in
      // their loading state; a rebuild here would be redundant.
      _picture = null;
      _failure = null;
    } else {
      setState(() {
        _loading = true;
        _picture = null;
        _failure = null;
      });
    }
    try {
      final picture = await ref.read(randomWallpaperClientProvider).fetch(widget.source);
      if (!mounted || generation != _generation) return;
      setState(() {
        _picture = picture;
        _loading = false;
      });
    } on RandomWallpaperFailure catch (failure) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = failure;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = RandomWallpaperFailure(RandomWallpaperFailureKind.network, '$error');
        _loading = false;
      });
    }
  }

  Future<void> _apply() async {
    final t = context.t;
    final picture = _picture;
    if (picture == null) return;
    setState(() => _saving = true);
    await ref.read(backgroundSettingsProvider.notifier).useRandomImage(picture.bytes, extension: picture.format);
    if (!mounted) return;
    final error = ref.read(backgroundSettingsProvider).error;
    if (error.isNotEmpty) {
      setState(() => _saving = false);
      showDsToast(
        context: context,
        title: t.settings.backgroundImportFailed,
        description: error,
        status: DsStatus.danger,
      );
      return;
    }
    showDsToast(context: context, title: t.wallpaper.applied);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final ui = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final borderRadius = BorderRadius.circular(ui.radii.card);
    final picture = _picture;
    final Widget preview;
    if (_loading) {
      preview = const AspectRatio(
        aspectRatio: 16 / 10,
        child: ColoredBox(
          color: Color(0xFF101418),
          child: Center(child: AppLoadingIndicator(size: 24)),
        ),
      );
    } else if (picture != null) {
      preview = DsImage(
        image: MemoryImage(picture.bytes),
        aspectRatio: 16 / 10,
        fit: BoxFit.contain,
        semanticLabel: t.wallpaper.previewTitle,
        fallback: _PreviewFallback(message: t.wallpaper.unsupported),
      );
    } else {
      preview = AspectRatio(
        aspectRatio: 16 / 10,
        child: _RandomFailureView(failure: _failure, onRetry: () => unawaited(_fetch())),
      );
    }
    return DsDialog(
      title: Text(widget.source.label(t), maxLines: 2, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          ClipRRect(borderRadius: borderRadius, child: preview),
          Row(
            spacing: DsSpace.s4,
            children: [
              DsIcon(DsIcons.globe, size: 12, color: colors.textSubtle),
              Expanded(
                child: Text(
                  '${t.wallpaper.sourceLabel}: ${widget.source.host}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ui.typography.small.copyWith(color: colors.textSubtle),
                ),
              ),
            ],
          ),
        ],
      ),
      style: const DsDialogStyle(width: 560),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          leading: const DsIcon(DsIcons.refreshCw),
          onPressed: _loading || _saving ? null : () => unawaited(_fetch()),
          child: Text(t.wallpaper.another),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          loading: _saving,
          onPressed: picture == null || _loading || _saving ? null : () => unawaited(_apply()),
          child: Text(t.settings.backgroundApply),
        ),
      ],
    );
  }
}

/// A random source that did not answer with a picture, with the retry in
/// place instead of a dead preview.
final class _RandomFailureView extends StatelessWidget {
  const _RandomFailureView({required this.failure, required this.onRetry});

  final RandomWallpaperFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final unsupported = failure?.kind == RandomWallpaperFailureKind.unsupported;
    final detail = failure?.detail ?? '';
    return ColoredBox(
      color: colors.control,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              DsIcon(unsupported ? DsIcons.imageOff : DsIcons.cloudOff, size: 28, color: colors.textSubtle),
              Text(
                unsupported ? t.wallpaper.unsupported : t.wallpaper.fetchFailed,
                textAlign: TextAlign.center,
                style: theme.typography.body.copyWith(color: colors.text),
              ),
              if (detail.isNotEmpty && !unsupported)
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.refreshCw),
                onPressed: onRetry,
                child: Text(t.wallpaper.retry),
              ),
            ],
          ),
        ),
      ),
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

  @override
  void initState() {
    super.initState();
    final settings = ref.read(backgroundSettingsProvider);
    _imageUrl.text = settings.imageUrl;
    _videoUrl.text = settings.videoUrl;
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
          controller: _imageUrl,
          path: settings.imagePath,
          busy: settings.busy,
          onApply: () => _apply(image: true),
          onUpload: () => _upload(image: true),
        ),
        _sourceSection(
          context,
          title: t.settings.backgroundVideo,
          addressLabel: t.settings.backgroundVideoAddress,
          controller: _videoUrl,
          path: settings.videoPath,
          busy: settings.busy,
          onApply: () => _apply(image: false),
          onUpload: () => _upload(image: false),
        ),
      ],
    );
  }

  Widget _sourceSection(
    BuildContext context, {
    required String title,
    required String addressLabel,
    required TextEditingController controller,
    required String path,
    required bool busy,
    required VoidCallback onApply,
    required VoidCallback onUpload,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsListSection(
      header: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(addressLabel, style: theme.typography.body.copyWith(color: colors.text)),
              DsTextField(
                controller: controller,
                placeholder: t.settings.backgroundAddressHint,
                semanticLabel: addressLabel,
                onSubmitted: (_) => onApply(),
              ),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DsButton(
                    onPressed: busy ? null : onApply,
                    leading: const DsIcon(DsIcons.check),
                    child: Text(t.settings.backgroundApply),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    onPressed: busy ? null : onUpload,
                    leading: const DsIcon(DsIcons.upload),
                    child: Text(t.settings.backgroundUpload),
                  ),
                  if (path.isNotEmpty)
                    Text(
                      t.settings.backgroundLocalFile(name: p.basename(path)),
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _apply({required bool image}) {
    final t = context.t;
    final settings = ref.read(backgroundSettingsProvider);
    final url = (image ? _imageUrl : _videoUrl).text.trim();
    if (url.isEmpty && (image ? settings.imagePath : settings.videoPath).isNotEmpty) return;
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

/// A picture that could not be loaded: the box stays, and says why it is
/// empty instead of looking like a blank background.
final class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return ColoredBox(
      color: colors.control,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s8,
          children: [
            DsIcon(DsIcons.imageOff, size: 26, color: colors.textSubtle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fitLabel(Translations t, BoxFit fit) => switch (fit) {
  BoxFit.cover => t.settings.backgroundFitCover,
  BoxFit.contain => t.settings.backgroundFitContain,
  BoxFit.fill => t.settings.backgroundFitFill,
  BoxFit.fitWidth => t.settings.backgroundFitWidth,
  BoxFit.fitHeight => t.settings.backgroundFitHeight,
  BoxFit.none => t.settings.backgroundFitNone,
  BoxFit.scaleDown => t.settings.backgroundFitScaleDown,
};
