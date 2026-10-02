import 'dart:async';
import 'dart:math' as math;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';

/// Entries appended per scroll step.
///
/// The iTab endpoints answer a fixed server page (24 rows, 16 for Bing) which is
/// a different size from what the grid shows per step, so this is a *client*
/// page size: the controller keeps a growing buffer of server pages and hands
/// the scroll view slices of [kWallpaperClientPageSize].
const int kWallpaperClientPageSize = 24;

/// Paging for one (source, group) wallpaper grid.
///
/// Compiled-in sources (solid colours, deepin) skip the network buffer entirely
/// and slice their fixed list locally; paged ones fetch on demand, one server
/// page at a time, and stop asking after the first short page - an endpoint that
/// answers fewer rows than requested has reached the end of its series.
///
/// The buffer only ever grows, exactly like the app's other paging cores: the
/// next slice is served from memory, and a slice boundary that falls inside a
/// server page does not refetch it.
class WallpaperGridController {
  WallpaperGridController({required this.source, required this.group});

  final WallpaperSource source;
  final WallpaperGroup group;

  final WallpaperRepository _repository = WallpaperRepository.instance;

  /// The rows published to the grid so far.
  final RxList<WallpaperItem> list = <WallpaperItem>[].obs;

  /// Requests in flight; the grid shows its footer spinner for this.
  final RxBool loadding = false.obs;

  /// True when a failure left the grid empty and the caller should offer a retry.
  final RxBool pageError = false.obs;

  /// Failure text for the inline row shown under an already-filled grid.
  final RxString errorMsg = ''.obs;

  final RxBool canLoadMore = false.obs;

  /// Fetched server pages, concatenated.
  final List<WallpaperItem> _buffer = <WallpaperItem>[];

  /// Local sources publish their whole table into [_buffer] on the first load.
  bool _bufferReady = false;
  bool _serverExhausted = false;
  int _serverPage = 0;
  int _slices = 0;
  bool _disposed = false;

  bool get _isLocal => _repository.isLocalSource(source.id);

  /// Whether anything has been published yet; the empty state waits for the
  /// first load to finish before it claims the source is empty.
  bool get isEmptyAndIdle => list.isEmpty && !loadding.value;

  /// First load, or a full reload: drops the buffer and starts over.
  Future<void> refresh() async {
    if (_disposed) return;
    // A reload asked for while a slice is in flight would clear the buffer
    // under that request; the running one publishes the fresh first slice
    // anyway, so this is a no-op rather than a race.
    if (loadding.value) return;
    _buffer.clear();
    _bufferReady = false;
    _serverExhausted = false;
    _serverPage = 0;
    _slices = 0;
    list.clear();
    canLoadMore.value = false;
    pageError.value = false;
    errorMsg.value = '';
    await _appendNextSlice();
  }

  /// Appends one client slice; a no-op while a request is in flight.
  Future<void> loadMore() async {
    if (_disposed || loadding.value || !canLoadMore.value) return;
    await _appendNextSlice();
  }

  Future<void> _appendNextSlice() async {
    if (_disposed || loadding.value) return;
    loadding.value = true;
    try {
      final int needed = (_slices + 1) * kWallpaperClientPageSize;
      await _fillBuffer(needed);
      if (_disposed) return;

      final int start = _slices * kWallpaperClientPageSize;
      if (start >= _buffer.length) {
        canLoadMore.value = false;
        return;
      }
      final int end = math.min(start + kWallpaperClientPageSize, _buffer.length);
      list.addAll(_buffer.sublist(start, end));
      _slices++;
      canLoadMore.value = end < _buffer.length || !_serverExhausted;
      pageError.value = false;
      errorMsg.value = '';
    } catch (error) {
      if (_disposed) return;
      errorMsg.value = '$error';
      // A failure with nothing on screen is the page's problem; one after rows
      // are already published keeps them and shows the inline retry instead.
      pageError.value = list.isEmpty;
      canLoadMore.value = list.isNotEmpty;
    } finally {
      if (!_disposed) loadding.value = false;
    }
  }

  /// Grows [_buffer] until it holds [needed] rows or the source runs out.
  Future<void> _fillBuffer(int needed) async {
    if (_isLocal) {
      if (!_bufferReady) {
        _buffer.addAll(_repository.localItems(source.id));
        _bufferReady = true;
        _serverExhausted = true;
      }
      return;
    }

    while (_buffer.length < needed && !_serverExhausted) {
      final int size = _repository.serverPageSize(source.id);
      final int page = _serverPage + 1;
      final List<WallpaperItem> items = await _repository.fetchPage(
        source: source,
        group: group,
        page: page,
        size: size,
      );
      if (_disposed) return;
      _serverPage = page;
      _buffer.addAll(items);
      // A short page ends the series; an empty one would otherwise be requested
      // again by the next slice.
      if (items.length < size) _serverExhausted = true;
    }
  }

  void dispose() {
    _disposed = true;
    list.clear();
  }
}

/// One controller per (source, group), for as long as its grid is on screen.
///
/// The preview page walks the very same list as the grid it was opened from, so
/// the two cannot drift; the grid releases the controller when it leaves the
/// navigation stack, which is what keeps the cache bounded.
class WallpaperPagingStore {
  WallpaperPagingStore._();

  static final WallpaperPagingStore instance = WallpaperPagingStore._();

  final Map<String, WallpaperGridController> _controllers = <String, WallpaperGridController>{};

  static String keyOf(WallpaperSource source, WallpaperGroup group) => '${source.id}|${group.id}';

  WallpaperGridController obtain(WallpaperSource source, WallpaperGroup group) {
    final String key = keyOf(source, group);
    return _controllers.putIfAbsent(key, () => WallpaperGridController(source: source, group: group));
  }

  void release(WallpaperSource source, WallpaperGroup group) {
    final String key = keyOf(source, group);
    _controllers.remove(key)?.dispose();
  }
}
