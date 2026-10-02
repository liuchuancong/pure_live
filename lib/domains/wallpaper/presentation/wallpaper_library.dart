import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/core/network/image_cache_manager.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/domains/wallpaper/domain/background_controller.dart';

/// One wallpaper source: its groups, its grid and the paging that fills it.
///
/// Compiled-in sources (colours, deepin) render their whole list at once; the
/// API-backed ones page. Nothing loads before the source is selected, so opening
/// the settings page costs no requests.
class WallpaperLibraryView extends StatefulWidget {
  const WallpaperLibraryView({super.key, required this.source});

  final WallpaperSource source;

  @override
  State<WallpaperLibraryView> createState() => _WallpaperLibraryViewState();
}

class _WallpaperLibraryViewState extends State<WallpaperLibraryView> {
  final WallpaperRepository _repository = WallpaperRepository.instance;

  late WallpaperGroup _group;
  List<WallpaperItem> _items = const <WallpaperItem>[];
  bool _loading = false;
  String? _error;
  int _page = 0;

  /// Sources answer with fewer rows than asked near the end of a series; the
  /// first short page stops further paging.
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _selectSource(widget.source);
  }

  void _selectSource(WallpaperSource source) {
    _error = null;
    _items = const <WallpaperItem>[];
    _page = 0;
    final groups = source.visibleGroups;
    _group = groups.first;
    if (_repository.isLocalSource(source.id)) {
      _items = _repository.localItems(source.id);
      _hasMore = false;
      _loading = false;
      return;
    }
    _hasMore = true;
    _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    final source = widget.source;
    if (_repository.isLocalSource(source.id)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final size = _repository.serverPageSize(source.id);
      final page = reset ? 1 : _page + 1;
      final items = await _repository.fetchPage(source: source, group: _group, page: page, size: size);
      if (!mounted || widget.source.id != source.id) return;
      setState(() {
        _page = page;
        _items = reset ? items : <WallpaperItem>[..._items, ...items];
        _hasMore = items.length >= size;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _apply(WallpaperItem item) async {
    final controller = BackgroundController.to;
    switch (widget.source.kind) {
      case WallpaperKind.gradient:
        controller.setCatalogGradient(item);
      case WallpaperKind.image:
        // Every URL these sources hand out is stable, so stream it through the
        // shared image cache instead of copying megabytes into the app dir.
        controller.setNetworkImage(item.file);
      case WallpaperKind.video:
        // A clip is downloaded before it is applied: streaming the CDN directly
        // is what left previous builds with a black background. It takes a few
        // seconds, so the wait is announced rather than leaving a tap with no
        // answer.
        ToastUtil.show(i18n('wallpaper_video_downloading'));
        final applied = await controller.applyNetworkVideo(item.file);
        if (!applied) {
          ToastUtil.show(i18n('background_apply_failed', args: {'msg': item.name ?? item.file}));
        } else {
          ToastUtil.show(i18n('wallpaper_video_applied'));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = widget.source;
    final groups = source.visibleGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (source.categorized && groups.length > 1)
          _GroupChips(
            groups: groups,
            selected: _group,
            languageCode: context.locale.languageCode,
            onSelected: (group) {
              setState(() => _group = group);
              _loadPage(reset: true);
            },
          ),
        const SizedBox(height: 12),
        if (_error != null)
          context.buildModernCard([
            context.buildTile(
              icon: Remix.error_warning_line,
              title: i18n('background_load_failed'),
              subtitle: _error,
              onTap: () => _loadPage(reset: true),
              trailing: const Icon(Remix.refresh_line),
            ),
          ])
        else if (_items.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(i18n('background_catalog_empty'), style: theme.textTheme.bodyMedium)),
          )
        else
          _Grid(items: _items, kind: source.kind, onApply: _apply),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (!_loading && _hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loadPage,
                icon: const Icon(Remix.arrow_down_line, size: 18),
                label: Text(i18n('wallpaper_load_more')),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selected,
    required this.languageCode,
    required this.onSelected,
  });

  final List<WallpaperGroup> groups;
  final WallpaperGroup selected;
  final String languageCode;
  final ValueChanged<WallpaperGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final group in groups)
          ChoiceChip(
            label: Text('${group.localizedName(languageCode)} ${group.count}'),
            selected: group.id == selected.id,
            onSelected: (_) => onSelected(group),
          ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.kind, required this.onApply});

  final List<WallpaperItem> items;
  final WallpaperKind kind;
  final ValueChanged<WallpaperItem> onApply;

  @override
  Widget build(BuildContext context) {
    // One watch for the whole grid: `usesWallpaper` is a plain comparison, so
    // marking the in-use card does not need a listener per card.
    return Obx(() {
      final controller = BackgroundController.to;
      // The flags are resolved *here*, not inside `itemBuilder`: that callback
      // runs lazily during layout, after this builder has already returned, so
      // an observable read there subscribes to nothing and `Obx` throws.
      final selected = List<bool>.generate(items.length, (index) => controller.usesWallpaper(items[index]));
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.62,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _WallpaperCard(
          item: items[index],
          kind: kind,
          selected: selected[index],
          onTap: () => onApply(items[index]),
        ),
      );
    });
  }
}

class _WallpaperCard extends StatelessWidget {
  const _WallpaperCard({required this.item, required this.kind, required this.selected, required this.onTap});

  final WallpaperItem item;
  final WallpaperKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Artwork(item: item, kind: kind),
            if (item.name != null && item.name!.isNotEmpty)
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Text(
                  item.name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
            if (kind == WallpaperKind.video)
              Positioned(top: 6, left: 8, child: Icon(Remix.play_circle_line, color: Colors.white, size: 20)),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Remix.check_line, size: 15, color: theme.colorScheme.onPrimary),
                ),
              ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.colorScheme.primary, width: 3),
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

class _Artwork extends StatelessWidget {
  const _Artwork({required this.item, required this.kind});

  final WallpaperItem item;
  final WallpaperKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == WallpaperKind.gradient) {
      final colors =
          item.gradient?.map((stop) => colorFromHex(stop.color)).whereType<Color>().toList(growable: false) ??
          const <Color>[];
      if (colors.isEmpty) return const SizedBox.shrink();
      final ramp = colors.length == 1 ? <Color>[colors.first, colors.first] : colors;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // CSS 0deg points up; a stop list without an angle still reads top
            // to bottom, which is what these presets were authored with.
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: ramp,
          ),
        ),
      );
    }

    final thumb = (item.thumb?.isNotEmpty ?? false) ? item.thumb! : item.file;
    return CachedNetworkImage(
      imageUrl: thumb,
      fit: BoxFit.cover,
      cacheManager: AppImageCacheManager.instance,
      placeholder: (context, url) => const ColoredBox(color: Color(0xFF20222A)),
      errorWidget: (context, url, error) => const Center(child: Icon(Remix.error_warning_line, color: Colors.white54)),
    );
  }
}
