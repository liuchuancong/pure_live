import 'dart:async';
import 'dart:typed_data';

import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_api_client.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_media_store.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:pure_live/domains/wallpaper/domain/background_controller.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_api_catalog.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/presentation/app_background.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_display_options.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_grid_controller.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_image.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_tile.dart';
import 'package:remixicon/remixicon.dart';

/// Fullscreen preview of exactly one wallpaper.
///
/// Two modes share the page. Catalogue mode walks the grid's paged list - the
/// same controller instance the grid published, so "next" can pull the next page
/// in and both screens agree on the position. API mode downloads a fresh random
/// picture per request and keeps only the one on screen.
///
/// Applying happens here and nowhere else: the grid is for browsing, and a tap
/// on a tile that silently replaced the background would be a trap.
class WallpaperPreviewPage extends StatefulWidget {
  const WallpaperPreviewPage.catalog({
    super.key,
    required String this.sourceId,
    required String this.groupId,
    required WallpaperKind this.kind,
    this.title,
    this.initialIndex = 0,
  }) : apiSource = null;

  const WallpaperPreviewPage.api(WallpaperApiSource this.apiSource, {super.key, this.title})
    : sourceId = null,
      groupId = null,
      kind = null,
      initialIndex = 0;

  /// Catalogue mode: the list to walk.
  final String? sourceId;
  final String? groupId;
  final WallpaperKind? kind;

  /// API mode: the random source to pull pictures from.
  final WallpaperApiSource? apiSource;

  final String? title;
  final int initialIndex;

  bool get isApiMode => apiSource != null;

  @override
  State<WallpaperPreviewPage> createState() => _WallpaperPreviewPageState();
}

class _WallpaperPreviewPageState extends State<WallpaperPreviewPage> {
  static const WallpaperItem _emptyItem = WallpaperItem(file: '');

  int _index = 0;
  bool _applying = false;

  /// API mode: the downloaded picture and its fetch state.
  Uint8List? _apiBytes;
  bool _apiLoading = false;

  /// Catalogue mode: set when "next" ran past the loaded rows and the advance
  /// has to wait for the next slice to arrive (a phone appends; desktop turns
  /// pages instead, which is [_pendingPage]).
  bool _waitingForPage = false;
  int? _pendingPage;
  bool _landOnLastItem = false;

  BasePageScrollAndStateBone<WallpaperItem>? _controller;

  /// Live-wallpaper playback. The player exists only for the video kind and is
  /// released with the page.
  Player? _videoPlayer;
  VideoController? _videoController;
  StreamSubscription<bool>? _playingSubscription;
  bool _videoPlaying = false;
  String? _openedVideoUrl;

  /// Set once the preview's own decoder was released because the clip became the
  /// wallpaper: reopening it here would double-decode against the background
  /// player. The play button clears it.
  bool _suppressAutoOpen = false;

  bool get _isVideo => !widget.isApiMode && widget.kind == WallpaperKind.video;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    if (widget.isApiMode) {
      unawaited(_fetchApiImage());
    } else {
      _resolveCatalog();
      if (_isVideo) _createVideoPlayer();
    }
  }

  @override
  void dispose() {
    unawaited(_playingSubscription?.cancel());
    unawaited(_videoPlayer?.dispose());
    super.dispose();
  }

  void _resolveCatalog() {
    final WallpaperSource? source = WallpaperRepository.instance.loadCatalog().sourceById(widget.sourceId!);
    if (source == null) return;
    final List<WallpaperGroup> groups = source.visibleGroups;
    if (groups.isEmpty) return;
    WallpaperGroup group = groups.first;
    for (final WallpaperGroup candidate in groups) {
      if (candidate.id == widget.groupId) group = candidate;
    }
    // The grid already owns this controller; reaching it through the shared
    // store is what keeps both screens on one list. An empty one is loaded here
    // too, so the preview still shows something if it is ever the first screen
    // to ask for this source (a deep link, or a grid that was not the opener).
    final controller = WallpaperPagingStore.instance.obtain(source, group);
    _controller = controller;
    if (controller.list.isEmpty && !controller.loadding.value) unawaited(controller.loadData());
  }

  BackgroundController get _background => BackgroundController.to;

  void _createVideoPlayer() {
    final Player player = Player();
    _videoPlayer = player;
    _videoController = VideoController(player, configuration: wallpaperVideoControllerConfiguration());
    _playingSubscription = player.stream.playing.listen((playing) {
      if (mounted) setState(() => _videoPlaying = playing);
    });
  }

  Future<void> _openVideo(String url) async {
    final Player? player = _videoPlayer;
    if (player == null || url.isEmpty) return;
    try {
      await player.open(Media(url), play: true);
    } catch (_) {
      if (mounted) ToastUtil.show(i18n('wallpaper_video_play_failed'));
    }
  }

  /// Releases the preview's own decoder.
  ///
  /// Once the clip is the wallpaper the background layer plays it through its own
  /// player; two decoders on one box double the hardware decode cost and stack
  /// the audio.
  void _destroyVideoPlayer() {
    final Player? player = _videoPlayer;
    _videoPlayer = null;
    _videoController = null;
    _videoPlaying = false;
    _openedVideoUrl = null;
    unawaited(_playingSubscription?.cancel());
    _playingSubscription = null;
    unawaited(player?.dispose());
  }

  Future<void> _togglePlay(WallpaperItem item) async {
    _suppressAutoOpen = false;
    var player = _videoPlayer;
    if (player == null) {
      _createVideoPlayer();
      player = _videoPlayer;
      if (player != null && item.file.isNotEmpty) {
        _openedVideoUrl = item.file;
        await player.open(Media(item.file), play: true);
      }
      return;
    }
    if (_videoPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _fetchApiImage() async {
    setState(() => _apiLoading = true);
    var failed = false;
    try {
      final Uint8List? bytes = await WallpaperApiClient.instance.fetchRandomImage(widget.apiSource!);
      if (!mounted) return;
      if (bytes == null) {
        failed = true;
      } else {
        setState(() => _apiBytes = bytes);
      }
    } catch (_) {
      failed = true;
    } finally {
      if (mounted) {
        setState(() => _apiLoading = false);
        if (failed) ToastUtil.show(i18n('wallpaper_fetch_failed'));
      }
    }
  }

  void _next(List<WallpaperItem> items) {
    if (widget.isApiMode) {
      if (!_apiLoading) unawaited(_fetchApiImage());
      return;
    }
    final int next = _index + 1;
    if (next < items.length) {
      setState(() => _index = next);
      _prefetch(items);
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.canLoadMore.value || controller.loadding.value) {
      if (items.isNotEmpty) setState(() => _index = 0);
      return;
    }
    if (controller.usesDesktopPagination) {
      // A numbered page replaces the list, so advancing means opening the next
      // page and landing on its first entry.
      _pendingPage = controller.currentPage + 1;
      _landOnLastItem = false;
      unawaited(controller.goToPage(_pendingPage!));
      return;
    }
    _waitingForPage = true;
    unawaited(controller.loadMoreData());
  }

  void _previous(List<WallpaperItem> items) {
    if (widget.isApiMode) {
      _next(items);
      return;
    }
    if (_index > 0) {
      setState(() => _index -= 1);
      return;
    }
    final controller = _controller;
    if (controller != null && controller.usesDesktopPagination && controller.currentPage > 1) {
      _pendingPage = controller.currentPage - 1;
      _landOnLastItem = true;
      unawaited(controller.goToPage(_pendingPage!));
      return;
    }
    if (items.isNotEmpty) setState(() => _index = items.length - 1);
  }

  /// Keeps a phone's appending list ahead of the cursor: desktop pages are
  /// discrete and load through [_pendingPage] instead.
  void _prefetch(List<WallpaperItem> items) {
    final controller = _controller;
    if (controller == null || controller.usesDesktopPagination) return;
    if (!controller.canLoadMore.value || controller.loadding.value) return;
    if (_index < items.length - 3) return;
    unawaited(controller.loadMoreData());
  }

  Future<void> _apply(WallpaperItem item) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      if (widget.isApiMode) {
        final Uint8List? bytes = _apiBytes;
        if (bytes == null) return;
        final bool applied = await _background.applyNetworkImageBytes(bytes);
        if (!applied) {
          ToastUtil.show(i18n('background_apply_failed', args: <String, String>{'msg': widget.apiSource!.name}));
          return;
        }
      } else {
        switch (widget.kind!) {
          case WallpaperKind.image:
            _background.setNetworkImage(item.file);
          case WallpaperKind.video:
            ToastUtil.show(i18n('wallpaper_video_downloading'));
            final bool applied = await _background.applyNetworkVideo(item.file);
            if (!applied) {
              ToastUtil.show(i18n('background_apply_failed', args: <String, String>{'msg': item.name ?? item.file}));
              return;
            }
          case WallpaperKind.gradient:
            final List<WallpaperGradientStop> stops = item.gradient ?? const <WallpaperGradientStop>[];
            if (stops.length < 2) {
              ToastUtil.show(i18n('background_invalid_gradient'));
              return;
            }
            _background.setCatalogGradient(item);
        }
      }
      if (_isVideo) {
        _destroyVideoPlayer();
        _suppressAutoOpen = true;
      }
      if (mounted) ToastUtil.show(i18n('wallpaper_set_done'));
    } catch (error) {
      if (mounted) {
        ToastUtil.show(i18n('background_apply_failed', args: <String, String>{'msg': '$error'}));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  /// Fill mode, picked from a dialog.
  ///
  /// The bar used to cycle through the values on every tap, which made a
  /// specific mode a matter of counting taps.
  Future<void> _pickFit() async {
    final BoxFit? picked = await _pickOption<BoxFit>(
      title: i18n('wallpaper_fit_mode'),
      icon: Remix.aspect_ratio_line,
      options: kWallpaperFitModes,
      current: _background.state.boxFit,
      labelOf: wallpaperFitLabel,
    );
    if (picked != null) _background.setBoxFit(picked);
  }

  Future<void> _pickBlur() async {
    final double current = kWallpaperBlurSteps[wallpaperBlurIndex(_background.state.blurSigma)];
    final double? picked = await _pickOption<double>(
      title: i18n('wallpaper_blur'),
      icon: Remix.blur_off_line,
      options: kWallpaperBlurSteps,
      current: current,
      labelOf: wallpaperBlurLabel,
    );
    if (picked != null) _background.setBlurSigma(picked);
  }

  Future<void> _pickMask() async {
    final double current = kWallpaperMaskSteps[wallpaperMaskIndex(_background.state.maskOpacity)];
    final double? picked = await _pickOption<double>(
      title: i18n('wallpaper_mask'),
      icon: Remix.contrast_2_line,
      options: kWallpaperMaskSteps,
      current: current,
      labelOf: wallpaperMaskLabel,
    );
    if (picked != null) _background.setMaskOpacity(picked);
  }

  /// A modal list of [options]; the one in force is ticked.
  Future<T?> _pickOption<T>({
    required String title,
    required IconData icon,
    required List<T> options,
    required T current,
    required String Function(T) labelOf,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return showDialog<T>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final T option = options[index];
              final bool selected = option == current;
              return ListTile(
                dense: true,
                title: Text(labelOf(option)),
                trailing: selected ? Icon(Remix.check_line, color: colors.primary) : null,
                onTap: () => Navigator.of(dialogContext).pop(option),
              );
            },
          ),
        ),
        actions: <Widget>[TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Obx(() {
      final BackgroundConfig background = _background.config.v;
      final List<WallpaperItem> items = widget.isApiMode
          ? const <WallpaperItem>[]
          : (controller?.list ?? const <WallpaperItem>[]);

      if (_waitingForPage && _index + 1 < items.length) {
        _waitingForPage = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _index += 1);
        });
      }
      // A desktop page change replaces the list under us; land on its first (or
      // last, when stepping back) entry as soon as it has arrived.
      final int? pendingPage = _pendingPage;
      if (pendingPage != null &&
          controller != null &&
          controller.currentPage == pendingPage &&
          !controller.loadding.value) {
        _pendingPage = null;
        final bool landOnLast = _landOnLastItem;
        _landOnLastItem = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final int length = controller.list.length;
          setState(() => _index = landOnLast && length > 0 ? length - 1 : 0);
        });
      }

      final WallpaperItem item = _itemAt(items);
      _openCurrentVideo(item);

      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(
            _title(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: <Widget>[
            if (!widget.isApiMode && items.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text('${_index + 1}/${items.length}', style: const TextStyle(color: Colors.white70)),
                ),
              ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Blur sits under the mask, so what the preview shows is what the
            // applied background looks like.
            wallpaperBlurred(_buildViewer(background, item), background.blurSigma),
            IgnorePointer(child: _buildMask(background)),
            if (widget.isApiMode && _apiLoading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
            Align(alignment: Alignment.bottomCenter, child: _buildActionBar(items, item)),
          ],
        ),
      );
    });
  }

  WallpaperItem _itemAt(List<WallpaperItem> items) {
    if (items.isEmpty) return _emptyItem;
    return items[_index.clamp(0, items.length - 1)];
  }

  /// Opens the video for the entry on screen, once per URL.
  void _openCurrentVideo(WallpaperItem item) {
    if (!_isVideo || _suppressAutoOpen || item.file.isEmpty || item.file == _openedVideoUrl) return;
    _openedVideoUrl = item.file;
    final String url = item.file;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openVideo(url));
    });
  }

  Widget _buildMask(BackgroundConfig background) {
    if (background.maskOpacity <= 0) return const SizedBox.shrink();
    // Same derivation as the real layer (`AppBackgroundLayer._maskColor`): this
    // page sits below the canvas-transparency override, so its scaffold colour
    // is transparent and cannot say how bright the theme is.
    final bool lightSurface = Theme.of(context).brightness == Brightness.light;
    return ColoredBox(color: (lightSurface ? Colors.white : Colors.black).withValues(alpha: background.maskOpacity));
  }

  Widget _buildViewer(BackgroundConfig background, WallpaperItem item) {
    if (widget.isApiMode) {
      final Uint8List? bytes = _apiBytes;
      if (bytes == null) {
        return _apiLoading
            ? const SizedBox.shrink()
            : Center(
                child: Text(i18n('wallpaper_fetch_failed'), style: const TextStyle(color: Colors.white70)),
              );
      }
      return SizedBox.expand(child: Image.memory(bytes, fit: background.boxFit, gaplessPlayback: true));
    }

    switch (widget.kind!) {
      case WallpaperKind.gradient:
        return GradientPreview(item: item);
      case WallpaperKind.video:
        final VideoController? controller = _videoController;
        if (controller == null) {
          return WallpaperNetworkImage(
            url: item.poster?.isNotEmpty == true ? item.poster! : item.file,
            fit: BoxFit.cover,
            placeholder: const ColoredBox(color: Colors.black),
            fallback: const ColoredBox(color: Colors.black),
          );
        }
        return Video(controller: controller, fit: background.boxFit, controls: (state) => const SizedBox.shrink());
      case WallpaperKind.image:
        return WallpaperNetworkImage(
          url: item.file,
          fit: background.boxFit,
          placeholder: const ColoredBox(color: Colors.black),
          fallback: const ColoredBox(color: Colors.black),
        );
    }
  }

  Widget _buildActionBar(List<WallpaperItem> items, WallpaperItem item) {
    final BackgroundConfig background = _background.state;
    // No scrim behind the bar: the wallpaper is what the user is judging, and a
    // black gradient across its bottom hides exactly the part they look at.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: <Widget>[
          if (widget.isApiMode)
            _PreviewAction(
              icon: Remix.refresh_line,
              label: i18n('wallpaper_change_image'),
              busy: _apiLoading,
              onPressed: () => unawaited(_fetchApiImage()),
            )
          else ...<Widget>[
            if (_isVideo)
              _PreviewAction(
                icon: _videoPlaying ? Remix.pause_line : Remix.play_line,
                label: _videoPlaying ? i18n('wallpaper_pause') : i18n('wallpaper_play'),
                onPressed: () => unawaited(_togglePlay(item)),
              ),
            _PreviewAction(
              icon: Remix.arrow_left_s_line,
              label: i18n('wallpaper_prev'),
              onPressed: () => _previous(items),
            ),
            _PreviewAction(
              icon: Remix.arrow_right_s_line,
              label: i18n('wallpaper_next'),
              onPressed: () => _next(items),
            ),
          ],
          _PreviewAction(
            icon: Remix.aspect_ratio_line,
            label: wallpaperFitLabel(background.boxFit),
            onPressed: () => unawaited(_pickFit()),
          ),
          _PreviewAction(
            icon: Remix.blur_off_line,
            label: wallpaperBlurLabel(background.blurSigma),
            onPressed: () => unawaited(_pickBlur()),
          ),
          _PreviewAction(
            icon: Remix.contrast_2_line,
            label: wallpaperMaskLabel(background.maskOpacity),
            onPressed: () => unawaited(_pickMask()),
          ),
          _PreviewAction(
            icon: Remix.check_line,
            label: i18n('wallpaper_set_background'),
            busy: _applying,
            primary: true,
            onPressed: () => unawaited(_apply(item)),
          ),
        ],
      ),
    );
  }

  String _title(WallpaperItem item) {
    final String? override = widget.title;
    if (override != null && override.isNotEmpty && widget.isApiMode) {
      return '${widget.apiSource!.name} · $override';
    }
    if (override != null && override.isNotEmpty) return override;
    if (widget.isApiMode) return widget.apiSource!.name;
    final String name = item.name ?? '';
    return name.isNotEmpty ? name : '${i18n('wallpaper_library')} ${_index + 1}';
  }
}

/// One bottom-bar button of the preview.
class _PreviewAction extends StatelessWidget {
  const _PreviewAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool busy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget child = busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          );

    return Material(
      color: primary ? colors.primary : Colors.white24,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: child),
      ),
    );
  }
}
