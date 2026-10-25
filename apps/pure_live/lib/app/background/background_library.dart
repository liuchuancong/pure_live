import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest;

import 'package:pure_live/app/background/background_library_catalog.dart';
import 'package:pure_live/app/background/background_library_models.dart';
import 'package:pure_live/app/background/background_settings.dart';
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;

/// The iTab API headers (the requests its own extension sends). The server
/// checks them before answering; without them the JSON is a refusal.
const Map<String, String> _itabHeaders = {
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
  'fp': 'zhVusd_0lS.1758762915',
  'mode': 'itab',
  'origin': 'chrome-extension://mhloojimgilafopcmlcikiidgbbnelip',
  'version': '2.2.25',
  'accept': 'application/json, text/plain, */*',
  'referer': 'https://www.itab.link/',
};

const String _itabBase = 'https://base.itab.link';

/// The app's reader for the built-in wallpaper library: the iTab picture
/// and video sources, plus the compiled-in deepin set.
final class BackgroundLibraryClient {
  BackgroundLibraryClient(this._ref);

  final Ref _ref;

  /// Reads one page of [source]'s [category]. The deepin set is compiled
  /// in, so it ignores [page] and returns everything once.
  Future<List<WallpaperItem>> fetch({
    required WallpaperSource source,
    required WallpaperCategory? category,
    required int page,
  }) async {
    if (source.isLocal) return deepinWallpaperItems();
    final (path, query) = switch (source.id) {
      WallpaperSourceId.official => (
        '/wallpaper/list',
        <String, String>{
          'sr': '3840x2160',
          'category': category?.query ?? 'nature',
          'sortKey': 'updateTime',
        },
      ),
      WallpaperSourceId.wallhaven => (
        '/wallpaper/wallhaven',
        <String, String>{
          'sr': '3840x2160',
          if (category != null && category.query.isNotEmpty) 'q': category.query,
        },
      ),
      WallpaperSourceId.bing => ('/bing/list', const <String, String>{}),
      WallpaperSourceId.video => ('/wallpaper/video/list', const <String, String>{'sortKey': 'updateTime'}),
      WallpaperSourceId.deepin => throw StateError('deepin is local'),
    };
    final uri = Uri.parse('$_itabBase$path').replace(
      queryParameters: {
        'lang': 'cn',
        ...query,
        'size': '${source.pageSize}',
        'page': '$page',
      },
    );
    final http = _ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
    final response = await http.send(
      LiveRequest.get(uri, headers: _itabHeaders, timeout: const Duration(seconds: 20)),
    );
    if (!response.isOk) throw StateError('HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.text);
    if (decoded is! Map) throw const FormatException('The wallpaper library did not answer with an object');
    final code = decoded['code'];
    if (code is num && code != 200 && code != 0) {
      throw StateError('iTab code=$code ${decoded['msg'] ?? ''}');
    }
    final rows = decoded['data'];
    if (rows is! List) return const [];
    final video = source.isVideo;
    return [
      for (final row in rows)
        if (row is Map) ?_itemOf(Map<String, Object?>.from(row), video: video),
    ];
  }

  /// One API row; a row without a playable/paintable address is dropped.
  WallpaperItem? _itemOf(Map<String, Object?> row, {required bool video}) {
    final raw = (video ? row['url'] : (row['raw'] ?? row['url']))?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    // The API asks its CDN for AVIF by default. The app's image pipeline is
    // not guaranteed to decode AVIF on every desktop backend, so the same
    // rendition is requested as JPEG; the server accepts both.
    final image = video ? raw : _jpeg(raw);
    final thumbRaw = (row['thumb']?.toString().trim() ?? '').isNotEmpty
        ? row['thumb']!.toString().trim()
        : image;
    final thumb = _jpeg(thumbRaw);
    final name = (row['name']?.toString().trim() ??
            row['copyright']?.toString().trim() ??
            _stem(image))
        .trim();
    return WallpaperItem(
      (b) => b
        ..id = (row['id'] ?? row['_id'])?.toString() ?? raw
        ..name = name.isEmpty ? _stem(image) : name
        ..url = image
        ..thumb = thumb
        ..video = video,
    );
  }

  /// The same CDN object in a format the app decodes everywhere.
  static String _jpeg(String url) => url.replaceAll('format,avif', 'format,jpg');

  static String _stem(String url) {
    final path = url.split('?').first;
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

/// The library's client.
final backgroundLibraryClientProvider = Provider<BackgroundLibraryClient>(BackgroundLibraryClient.new);

/// Opens the built-in wallpaper library over the background settings.
Future<void> showBackgroundLibrary(BuildContext context) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(
    title: Text(context.t.settings.backgroundLibraryTitle),
    scrollable: false,
    child: const _BackgroundLibrary(),
  ),
);

final class _BackgroundLibrary extends ConsumerStatefulWidget {
  const _BackgroundLibrary();

  @override
  ConsumerState<_BackgroundLibrary> createState() => _BackgroundLibraryState();
}

final class _BackgroundLibraryState extends ConsumerState<_BackgroundLibrary> {
  WallpaperSource _source = wallpaperSources.first;
  WallpaperCategory? _category = wallpaperSources.first.categories.firstOrNull;
  final List<WallpaperItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;

  /// One more than the newest request this panel started; an answer whose
  /// generation fell behind belongs to a source/category the viewer already
  /// left and must not write the new list.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    // A reset invalidates whatever is in flight; a further page only runs
    // when nothing is, so one source is never fetched twice over itself.
    if (!reset && _loading) return;
    final generation = ++_generation;
    if (reset) {
      setState(() {
        _items.clear();
        _page = 0;
        _hasMore = true;
        _error = null;
      });
    }
    if (!_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = _page + 1;
      final items = await ref.read(backgroundLibraryClientProvider).fetch(
        source: _source,
        category: _category,
        page: page,
      );
      if (!mounted || generation != _generation) return;
      final seen = {for (final item in _items) item.url};
      setState(() {
        _page = page;
        _items.addAll(items.where((item) => seen.add(item.url)));
        _hasMore = !_source.isLocal && items.length >= _source.pageSize;
        _loading = false;
        _error = null;
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
    final source = wallpaperSources.firstWhere((source) => source.id == id);
    setState(() {
      _source = source;
      _category = source.categories.firstOrNull;
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    unawaited(_load(reset: true));
  }

  void _selectCategory(WallpaperCategory category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    unawaited(_load(reset: true));
  }

  void _apply(WallpaperItem item) {
    final controller = ref.read(backgroundSettingsProvider.notifier);
    if (item.video) {
      controller.setVideoUrl(item.url);
    } else {
      controller.setImageUrl(item.url);
    }
    showDsToast(context: context, title: context.t.settings.backgroundLibraryApplied);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final categories = _source.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        DsTabs<WallpaperSourceId>(
          value: _source.id,
          onChanged: _selectSource,
          tabs: [
            for (final source in wallpaperSources)
              DsTab<WallpaperSourceId>(value: source.id, label: Text(source.label(t))),
          ],
        ),
        if (categories.length > 1)
          DsChoiceChips<WallpaperCategory>(
            value: _category ?? categories.first,
            onChanged: _selectCategory,
            semanticLabel: t.settings.backgroundLibraryTitle,
            options: [
              for (final category in categories)
                DsChipOption(value: category, label: Text(category.label(t))),
            ],
          ),
        if (_error != null)
          Expanded(
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.cloudOff),
              title: Text(t.settings.backgroundLibraryFailed),
              description: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis),
              actions: [DsButton(onPressed: () => unawaited(_load(reset: true)), child: Text(t.common.retry))],
            ),
          )
        else
          Expanded(
            child: Stack(
              children: [
                if (_items.isEmpty && !_loading)
                  Center(
                    child: DsEmptyState(
                      icon: const DsIcon(DsIcons.image),
                      title: Text(t.settings.backgroundLibraryEmpty),
                    ),
                  )
                else
                  GridView.builder(
                    padding: const EdgeInsets.only(top: DsSpace.s4, bottom: DsSpace.s8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisSpacing: DsSpace.s8,
                      crossAxisSpacing: DsSpace.s8,
                      childAspectRatio: 16 / 10,
                    ),
                    itemCount: _items.length + (_hasMore && !_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return Center(
                          child: DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: () => unawaited(_load(reset: false)),
                            child: Text(t.settings.backgroundLibraryLoadMore),
                          ),
                        );
                      }
                      final item = _items[index];
                      return _LibraryTile(
                        item: item,
                        semanticLabel: item.name,
                        onPressed: () => _apply(item),
                      );
                    },
                  ),
                if (_loading)
                  ColoredBox(
                    color: colors.surface.withValues(alpha: 0.55),
                    child: const Center(child: DsSpinner()),
                  ),
              ],
            ),
          ),
        Text(
          _source.isLocal
              ? t.settings.backgroundLibraryLocalHint
              : t.settings.backgroundLibraryNetworkHint,
          style: theme.typography.small.copyWith(color: colors.textSubtle),
        ),
      ],
    );
  }
}

/// One thumbnail: the picture's grid copy with a play mark for a clip.
final class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.item, required this.semanticLabel, required this.onPressed});

  final WallpaperItem item;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(
            color: states.contains(WidgetState.hovered) ? colors.accent : colors.border,
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
            if (item.video)
              const Center(
                child: DsIcon(DsIcons.play, size: 22, color: Color(0xCCFFFFFF)),
              ),
          ],
        ),
      ),
    );
  }
}
