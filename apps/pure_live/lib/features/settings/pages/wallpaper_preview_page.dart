import 'dart:async' show Timer, unawaited;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui show ImageByteFormat, ImageFilter, PictureRecorder;

import 'package:crypto/crypto.dart' as crypto;
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/panes/background_panes.dart' show backgroundFitLabel;
import 'package:pure_live/features/settings/surface/settings_preview.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart'
    show
        BackgroundConfig,
        BackgroundOverlay,
        GradientBackground,
        ImageBackground,
        ProviderImageSource,
        PureBackground,
        SolidBackground,
        VideoBackground;

/// Below this width the preview keeps its settings in a sheet instead of a
/// sidebar.
const double _kPreviewWideBreakpoint = 900;

/// The intervals the image slideshow offers.
const List<Duration> _kSlideshowIntervals = [Duration(seconds: 3), Duration(seconds: 5), Duration(seconds: 10)];

/// What a preview page walks: the entries of one grid page, a random-image
/// API that answers one picture at a time, or a flat paint (a solid colour or
/// a gradient) from the palette page.
final class WallpaperPreviewSubject {
  const WallpaperPreviewSubject._({
    this.items = const [],
    this.swatches = const [],
    this.index = 0,
    this.source,
    this.more,
  });

  /// A catalogue list, opening on [index]. [more] fetches the entries past
  /// the page the grid showed, so the strip can keep walking.
  const WallpaperPreviewSubject.items(
    List<WallpaperItem> items,
    int index, {
    Future<List<WallpaperItem>> Function()? more,
  }) : this._(items: items, index: index, more: more);

  /// A random source: the next picture is always another fetch.
  const WallpaperPreviewSubject.random(RandomWallpaperSource source) : this._(source: source);

  /// A palette page's swatches, opening on [index].
  const WallpaperPreviewSubject.swatched(List<WallpaperPreviewPaint> swatches, int index)
    : this._(swatches: swatches, index: index);

  /// The entries on screen, in grid order.
  final List<WallpaperItem> items;

  /// The flat paints on screen, in palette order.
  final List<WallpaperPreviewPaint> swatches;

  /// Which entry the page opens on.
  final int index;

  /// The random source, when the page walks an API instead of a list.
  final RandomWallpaperSource? source;

  /// Fetches the entries past [items], or returns none when the source is
  /// walked out.
  final Future<List<WallpaperItem>> Function()? more;

  /// Whether this is a random-image preview rather than a catalogue list.
  bool get isRandom => source != null;

  /// Whether this walks the palette's swatches.
  bool get isPaint => swatches.isNotEmpty;

  /// The entry in view, or null for a random preview.
  WallpaperItem? itemAt(int index) => index >= 0 && index < items.length ? items[index] : null;
}

/// One flat candidate: the colour or gradient itself, and the preset name.
final class WallpaperPreviewPaint {
  /// A solid [color], named [name].
  const WallpaperPreviewPaint.solid(String name, this.color) : solidName = name, preset = null;

  /// A gradient preset, painted with its own stops and angle.
  const WallpaperPreviewPaint.gradient(this.preset) : solidName = null, color = null;

  /// What the palette calls a solid colour; a gradient reads the preset's own.
  final String? solidName;

  /// The solid colour, when this is one.
  final Color? color;

  /// The gradient preset, when this is one.
  final BackgroundGradientPreset? preset;

  /// What the palette calls it.
  String get name => solidName ?? preset?.name ?? '';
}

/// Opens a wallpaper full-window and alone: the media in a rounded stage, its
/// siblings in a strip under it, and the settings beside or under it.
///
/// [more] feeds the strip past the entries the grid showed, so a catalogue
/// page is a starting point rather than the whole walk.
Future<void> showWallpaperPreview(
  BuildContext context,
  List<WallpaperItem> items,
  int index, {
  Future<List<WallpaperItem>> Function()? more,
}) {
  return _openPreview(context, WallpaperPreviewSubject.items(items, index, more: more));
}

/// Opens a palette swatch full-window, walking the page's swatches: the same
/// stage and settings the media kinds get, with the paint in place of them.
Future<void> showPalettePreview(BuildContext context, List<WallpaperPreviewPaint> swatches, int index) {
  return _openPreview(context, WallpaperPreviewSubject.swatched(swatches, index));
}

/// The swatch as a tile paints it: its own stops and angle.
BoxDecoration wallpaperPaintDecoration(WallpaperPreviewPaint paint) {
  final color = paint.color;
  if (color != null) return BoxDecoration(color: color);
  final preset = paint.preset;
  if (preset == null) return const BoxDecoration();
  final (begin, end) = gradientAlignments(preset.deg);
  return BoxDecoration(
    gradient: LinearGradient(begin: begin, end: end, colors: preset.colors, stops: preset.stops),
  );
}

/// The swatch as a picture: painted at a screen's size, so the file a viewer
/// keeps is a wallpaper rather than a thumbnail of one.
Future<Uint8List> encodeWallpaperPaint(WallpaperPreviewPaint paint) async {
  const size = Size(1920, 1080);
  final rect = Offset.zero & size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final preset = paint.preset;
  if (preset == null) {
    canvas.drawRect(rect, Paint()..color = paint.color ?? const Color(0xFF000000));
  } else {
    final (begin, end) = gradientAlignments(preset.deg);
    final gradient = LinearGradient(begin: begin, end: end, colors: preset.colors, stops: preset.stops);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const FormatException('The swatch could not be encoded.');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Opens the next picture from [source] in the same page; the picture is only
/// fetched there, and the page offers another until the viewer keeps one.
Future<void> showRandomWallpaperPreview(BuildContext context, RandomWallpaperSource source) {
  return _openPreview(context, WallpaperPreviewSubject.random(source));
}

Future<void> _openPreview(BuildContext context, WallpaperPreviewSubject subject) {
  // The root navigator, so the page covers the shell instead of opening as
  // another pane inside it.
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(fullscreenDialog: true, builder: (context) => WallpaperPreviewPage(subject: subject)));
}

/// The preview page. It paints in the dark on purpose: the media is the
/// subject, and a light shell around it would compete with every picture.
final class WallpaperPreviewPage extends ConsumerStatefulWidget {
  /// The page for [subject].
  const WallpaperPreviewPage({required this.subject, super.key});

  /// What is being walked.
  final WallpaperPreviewSubject subject;

  @override
  ConsumerState<WallpaperPreviewPage> createState() => _WallpaperPreviewPageState();
}

final class _WallpaperPreviewPageState extends ConsumerState<WallpaperPreviewPage> {
  late final List<WallpaperItem> _items = List.of(widget.subject.items);

  /// The addresses already in the strip, so a later page that repeats one
  /// does not repeat the tile too.
  late final Set<String> _seenUrls = {for (final item in widget.subject.items) item.url};

  /// The palette's swatches, when this page walks flat paints. [_index] walks
  /// whichever of the two lists this page was opened with.
  late final List<WallpaperPreviewPaint> _swatches = List.of(widget.subject.swatches);
  late int _index = _items.isEmpty && _swatches.isEmpty
      ? 0
      : widget.subject.index.clamp(0, (_items.isEmpty ? _swatches.length : _items.length) - 1);

  /// The random pictures fetched so far, newest last; the strip walks them.
  final List<({Uint8List bytes, String format})> _shots = [];

  /// One hash per kept shot, so a random source that hands the same picture
  /// out twice is retried instead of repeating a tile in the strip.
  final List<String> _shotDigests = [];
  int _shotIndex = -1;

  /// The selected random picture, mirrored here so the rest of the page has
  /// one place to read it from.
  Uint8List? _bytes;
  String _extension = 'jpg';

  bool _loading = false;
  bool _loadingMore = false;
  bool _saving = false;
  bool _downloading = false;
  RandomWallpaperFailure? _failure;
  int _generation = 0;

  /// The preview's own transport. An applied wallpaper always loops muted,
  /// so these only shape what the viewer hears while deciding.
  bool _paused = false;
  bool _muted = true;

  /// The resolved pixel size of the picture in view, when it is a picture.
  Size? _mediaSize;
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;

  /// Image slideshow, preview-only.
  Timer? _slideshow;
  bool _autoPlay = false;
  Duration _interval = _kSlideshowIntervals[1];

  final ScrollController _stripScroll = ScrollController();

  WallpaperItem? get _currentItem => _index >= 0 && _index < _items.length ? _items[_index] : null;

  /// The swatch in view, when this page walks the palette.
  WallpaperPreviewPaint? get _currentPaint =>
      widget.subject.isPaint && _index >= 0 && _index < _swatches.length ? _swatches[_index] : null;

  /// Whether what is in view is a clip. The page belongs to the source it
  /// was opened from, so this follows the walked entries only — there is no
  /// switch that would fetch the other library.
  bool get _videoMode => _currentItem?.video ?? false;

  /// Whether there is something to apply or save yet.
  bool get _canCommit => _currentItem != null || _currentPaint != null || (_bytes != null && widget.subject.isRandom);

  int get _stripCount =>
      widget.subject.isRandom ? _shots.length : (widget.subject.isPaint ? _swatches.length : _items.length);

  int get _stripIndex => widget.subject.isRandom ? _shotIndex : _index;

  /// The app background's gate, captured while the page can still read it:
  /// `dispose` may not touch `ref`.
  late final BackgroundPreviewOpenController _backgroundGate;

  @override
  void initState() {
    super.initState();
    _backgroundGate = ref.read(backgroundPreviewOpenProvider.notifier);
    // The wallpaper behind this page stands down while it is up. Deferred to
    // the first frame: closing it again happens in dispose, where `ref` is
    // already out of reach.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _backgroundGate.open();
    });
    if (widget.subject.isRandom) {
      unawaited(_fetch());
    } else {
      _refreshMediaSize();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _revealCurrentThumb();
        // Opened near the end of the grid's own page: start pulling the next
        // one right away, so the forward button has somewhere to go.
        if (_index >= _items.length - 3) unawaited(_loadMore());
      });
    }
  }

  @override
  void dispose() {
    _backgroundGate.close();
    _slideshow?.cancel();
    final stream = _sizeStream;
    final listener = _sizeListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stripScroll.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_loading) return;
    final source = widget.subject.source;
    if (source == null) return;
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final client = ref.read(randomWallpaperClientProvider);
      var picture = await client.fetch(source);
      var digest = _digest(picture.bytes);
      // The random endpoints repeat themselves; after a few redraws the
      // duplicate is kept rather than spinning forever.
      for (var redraws = 0; redraws < 3 && _shotDigests.contains(digest); redraws++) {
        picture = await client.fetch(source);
        digest = _digest(picture.bytes);
        if (!mounted || generation != _generation) return;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _shots.add((bytes: picture.bytes, format: picture.format));
        _shotDigests.add(digest);
        while (_shots.length > 20) {
          _shots.removeAt(0);
          _shotDigests.removeAt(0);
        }
        _shotIndex = _shots.length - 1;
        _bytes = picture.bytes;
        _extension = picture.format;
        _failure = null;
        _loading = false;
      });
      _refreshMediaSize();
      _revealCurrentThumb();
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

  /// The strip's identity for a picture: its SHA-1, not its bytes.
  static String _digest(Uint8List bytes) => crypto.sha1.convert(bytes).toString();

  void _selectItem(int index) {
    if (index < 0 || index >= _items.length || index == _index) return;
    setState(() => _index = index);
    _refreshMediaSize();
    _revealCurrentThumb();
    _restartSlideshow();
    // Three from the end is soon enough that the next page is usually already
    // in the strip when the viewer asks for one more.
    if (index >= _items.length - 3) unawaited(_loadMore());
  }

  void _selectPaint(int index) {
    if (index < 0 || index >= _swatches.length || index == _index) return;
    setState(() => _index = index);
    _revealCurrentThumb();
    _restartSlideshow();
  }

  /// Fetches the entries past the page the grid showed and appends them to the
  /// strip; a source that has given all it has simply stops the walk here.
  Future<void> _loadMore() async {
    final more = widget.subject.more;
    if (more == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final added = await more();
      if (!mounted) return;
      setState(() {
        _items.addAll(added.where((item) => _seenUrls.add(item.url)));
        _loadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// Whether the strip can pull the entries past what it already holds.
  bool get _canLoadMore => widget.subject.more != null;

  /// Walks one entry forward, loading the next page when the strip ends on it.
  Future<void> _advance() async {
    if (_index < _stripCount - 1) {
      _selectStrip(_index + 1);
      return;
    }
    if (!_canLoadMore || _loadingMore) return;
    final before = _items.length;
    await _loadMore();
    if (!mounted || _items.length <= before) return;
    _selectItem(before);
  }

  void _selectStrip(int index) {
    final count = _stripCount;
    if (count == 0) return;
    final target = index.clamp(0, count - 1);
    if (widget.subject.isRandom) {
      _selectShot(target);
    } else if (widget.subject.isPaint) {
      _selectPaint(target);
    } else {
      _selectItem(target);
    }
  }

  void _selectShot(int index) {
    if (index < 0 || index >= _shots.length || index == _shotIndex) return;
    final shot = _shots[index];
    setState(() {
      _shotIndex = index;
      _bytes = shot.bytes;
      _extension = shot.format;
    });
    _refreshMediaSize();
    _revealCurrentThumb();
    _restartSlideshow();
  }

  /// The slideshow's own tick: no restart, so the timer keeps its rhythm.
  void _tickSlideshow() {
    if (!mounted || _videoMode) return;
    if (widget.subject.isRandom) {
      unawaited(_fetch());
      return;
    }
    if (widget.subject.isPaint) {
      final paints = _swatches.length;
      if (paints > 1) _selectPaint((_index + 1) % paints);
      return;
    }
    final count = _items.length;
    if (count <= 1) return;
    if (_index >= count - 1 && _canLoadMore) {
      unawaited(_advance());
      return;
    }
    final next = (_index + 1) % count;
    setState(() => _index = next);
    _refreshMediaSize();
    _revealCurrentThumb();
    if (next >= count - 3) unawaited(_loadMore());
  }

  void _setAutoPlay(bool value) {
    setState(() => _autoPlay = value);
    _restartSlideshow();
  }

  void _setInterval(Duration value) {
    setState(() => _interval = value);
    _restartSlideshow();
  }

  void _restartSlideshow() {
    _slideshow?.cancel();
    _slideshow = null;
    if (!_autoPlay) return;
    _slideshow = Timer.periodic(_interval, (_) => _tickSlideshow());
  }

  /// Resolves the picture's pixel size for the corner chip. A video's frame
  /// size is the decoder's business, so clips show their kind instead.
  void _refreshMediaSize() {
    final stream = _sizeStream;
    final listener = _sizeListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _sizeStream = null;
    _sizeListener = null;
    final provider = _currentImageProvider();
    if (provider == null) {
      if (_mediaSize != null && mounted) setState(() => _mediaSize = null);
      return;
    }
    final next = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener nextListener;
    nextListener = ImageStreamListener((info, _) {
      next.removeListener(nextListener);
      if (!mounted) return;
      setState(() => _mediaSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    }, onError: (_, _) => next.removeListener(nextListener));
    _sizeStream = next;
    _sizeListener = nextListener;
    next.addListener(nextListener);
  }

  ImageProvider? _currentImageProvider() {
    final item = _currentItem;
    if (item != null) return item.video ? null : imageProviderOf(item.url);
    final bytes = _bytes;
    return bytes == null ? null : MemoryImage(bytes);
  }

  /// A still for the blurred backdrop: a video's poster when it has one, the
  /// picture itself otherwise. A clip without a poster keeps the plain scrim.
  ImageProvider? _backdropImage() {
    final item = _currentItem;
    if (item != null) {
      if (item.thumb.isEmpty || (item.video && item.thumb == item.url)) return null;
      return imageProviderOf(item.thumb);
    }
    final bytes = _bytes;
    return bytes == null ? null : MemoryImage(bytes);
  }

  void _revealCurrentThumb() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_stripScroll.hasClients) return;
      final viewport = _stripScroll.position.viewportDimension;
      final target = (_stripIndex * 128.0 - viewport / 2 + 64).clamp(0.0, _stripScroll.position.maxScrollExtent);
      _stripScroll.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    });
  }

  Future<void> _apply() async {
    final t = context.t;
    final controller = ref.read(backgroundSettingsProvider.notifier);
    final paint = _currentPaint;
    if (paint != null) {
      final preset = paint.preset;
      final color = paint.color;
      if (preset != null) {
        controller.setGradient(preset);
      } else if (color != null) {
        controller.setSolid(color);
      }
      if (!mounted) return;
      showDsToast(context: context, title: t.settings.backgroundLibraryApplied);
      _closePreview();
      return;
    }
    final item = _currentItem;
    if (item != null) {
      final local = _localPathOf(item.url);
      if (local != null) {
        // A file the viewer picked is applied by copying it into the slot the
        // app owns, so the wallpaper outlives the original being moved.
        await controller.importDroppedFile(local, image: !item.video);
        if (!mounted) return;
        final error = ref.read(backgroundSettingsProvider).error;
        if (error.isNotEmpty) {
          showDsToast(
            context: context,
            title: t.settings.backgroundImportFailed,
            description: error,
            status: DsStatus.danger,
          );
          return;
        }
        showDsToast(context: context, title: t.settings.backgroundLibraryApplied);
        _closePreview();
        return;
      }
      if (item.video) {
        controller.setVideoUrl(item.url);
      } else {
        controller.setImageUrl(item.url);
      }
      if (!mounted) return;
      showDsToast(context: context, title: t.settings.backgroundLibraryApplied);
      _closePreview();
      return;
    }
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _saving = true);
    await controller.useRandomImage(bytes, extension: _extension);
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
    _closePreview();
  }

  /// Keeps the entry in view: a catalogue address is fetched, a random
  /// picture is already in memory.
  Future<void> _download() async {
    final t = context.t;
    final directory = ref.read(downloadDirectoryProvider).effectivePath;
    final paint = _currentPaint;
    final item = _currentItem;
    final bytes = _bytes;
    if (paint == null && item == null && bytes == null) return;
    setState(() => _downloading = true);
    try {
      if (paint != null) {
        final target = File(
          p.join(directory, wallpaperFileName(title: paint.name, fallback: 'background', address: 'paint.png')),
        );
        await target.parent.create(recursive: true);
        await target.writeAsBytes(await encodeWallpaperPaint(paint));
      } else if (item != null) {
        final local = _localPathOf(item.url);
        if (local != null) {
          // An imported file is copied, not fetched: it is already on disk.
          final target = File(p.join(directory, p.basename(local)));
          await target.parent.create(recursive: true);
          await File(local).copy(target.path);
        } else {
          final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
          await downloadMediaFile(
            http: http,
            url: Uri.parse(item.url),
            directory: directory,
            fileName: wallpaperFileName(title: item.name, fallback: item.id, address: item.url),
          );
        }
      } else {
        final target = File(p.join(directory, 'wallpaper-${DateTime.now().millisecondsSinceEpoch}.$_extension'));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes!);
      }
      if (!mounted) return;
      setState(() => _downloading = false);
      showDsToast(
        context: context,
        title: t.settings.downloadSavedTo(path: directory),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _downloading = false);
      showDsToast(
        context: context,
        title: t.settings.backgroundDownloadFailed,
        description: '$error',
        status: DsStatus.danger,
      );
    }
  }

  /// Closes the page together with any sheet or dialog above it; the apply
  /// action can run from inside the settings sheet.
  void _closePreview() {
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null) {
      navigator.maybePop();
      return;
    }
    navigator.popUntil((candidate) => candidate == route);
    if (navigator.canPop()) navigator.pop();
  }

  /// The candidate with the display settings on it, in the same shape the app
  /// background paints with.
  BackgroundConfig? _configOf(BuildContext context, BackgroundSettings settings) {
    final colors = DsTheme.colorsOf(context);
    final overlay = appBackgroundOverlay(context, opacity: settings.maskOpacity, blurSigma: settings.overlayBlurSigma);
    final underlay = SolidBackground(color: colors.canvas);
    final paint = _currentPaint;
    if (paint != null) return _paintConfig(context, paint, overlay);
    final item = _currentItem;
    if (item != null) {
      if (item.video) {
        // A clip's frost goes on the decoded surface, not on the backdrop: a
        // `Texture` gives a backdrop filter nothing to sample, so the mask
        // would stay a flat wash over a sharp video.
        return VideoBackground(
          source: AppBackgroundVideoSource(Uri.parse(item.url)),
          fit: settings.fit,
          underlay: underlay,
          fallback: underlay,
          muted: _muted,
          blurSigma: settings.overlayBlurSigma,
          overlay: appBackgroundOverlay(context, opacity: settings.maskOpacity, blurSigma: 0),
        );
      }
      return ImageBackground(
        source: ProviderImageSource(imageProviderOf(item.url)),
        fit: settings.fit,
        placeholderColor: colors.canvas,
        underlay: underlay,
        fallback: underlay,
        overlay: overlay,
      );
    }
    final bytes = _bytes;
    if (bytes == null) return null;
    return ImageBackground(
      source: ProviderImageSource(MemoryImage(bytes)),
      fit: settings.fit,
      placeholderColor: colors.canvas,
      underlay: underlay,
      fallback: underlay,
      overlay: overlay,
    );
  }

  /// The swatch as the app would wear it: its own stops and angle, under the
  /// same scrim the media kinds get.
  static BackgroundConfig _paintConfig(BuildContext context, WallpaperPreviewPaint paint, BackgroundOverlay overlay) {
    final color = paint.color;
    if (color != null) return SolidBackground(color: color, overlay: overlay);
    final preset = paint.preset;
    if (preset == null) return SolidBackground(color: DsTheme.colorsOf(context).canvas, overlay: overlay);
    final (begin, end) = gradientAlignments(preset.deg);
    return GradientBackground(colors: preset.colors, stops: preset.stops, begin: begin, end: end, overlay: overlay);
  }

  /// The provider for an entry's address: a file the viewer imported reads
  /// from disk, anything else through the shared image cache.
  static ImageProvider imageProviderOf(String address) {
    final local = _localPathOf(address);
    return local == null ? cachedImage(address) : FileImage(File(local));
  }

  /// The disk path behind a `file:` address, or null for a network one.
  static String? _localPathOf(String address) {
    final uri = Uri.tryParse(address);
    if (uri == null || uri.scheme != 'file') return null;
    final path = uri.toFilePath();
    return path.isEmpty ? null : path;
  }

  /// The swatch as a strip tile paints it: its own stops and angle.
  static BoxDecoration _decorationOf(WallpaperPreviewPaint paint) => wallpaperPaintDecoration(paint);

  String _title(Translations t) {
    final paint = _currentPaint;
    if (paint != null) {
      final name = paint.name.trim();
      final count = '${_index + 1}/${_swatches.length}';
      return name.isEmpty ? count : '$name · $count';
    }
    final item = _currentItem;
    if (item != null) {
      final name = item.name.trim();
      final count = '${_items.isEmpty ? 0 : _index + 1}/${_items.length}';
      return name.isEmpty ? count : '$name · $count';
    }
    final source = widget.subject.source;
    final label = source == null ? t.wallpaper.previewTitle : source.label(t);
    return _shots.isEmpty ? label : '$label · ${_shotIndex + 1}/${_shots.length}';
  }

  /// The chip in the stage corner: pixels and a familiar tier when the size
  /// is known, the media kind otherwise.
  String _resolutionLabel(Translations t) {
    final size = _mediaSize;
    if (size == null) return _videoMode ? t.settings.backgroundVideo : t.settings.backgroundImage;
    final width = size.width.round();
    final height = size.height.round();
    final tier = width >= 3840 || height >= 2160
        ? '4K'
        : width >= 2560 || height >= 1440
        ? '2K'
        : width >= 1920 || height >= 1080
        ? '1080P'
        : width >= 1280 || height >= 720
        ? '720P'
        : null;
    return tier == null ? '$width × $height' : '$width × $height  $tier';
  }

  /// The narrow layout's settings: a bottom sheet, like the app's other
  /// touch surfaces. The page stays behind it and keeps answering changes.
  Future<void> _openSettingsSheet() {
    final t = context.t;
    return showDsPanel<void>(
      context: context,
      presentation: DsPanelPresentation.bottom,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = DsTheme.of(context);
          return DsPanel(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(t.settings.backgroundPreviewSettingsTitle),
                Text(
                  _videoMode ? t.settings.backgroundVideo : t.settings.backgroundImage,
                  style: theme.typography.small.copyWith(color: theme.colors.textSubtle),
                ),
              ],
            ),
            style: DsPanelStyle(background: theme.colors.surface),
            footer: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: DsButton(
                    variant: DsButtonVariant.secondary,
                    leading: const DsIcon(DsIcons.download),
                    onPressed: _canCommit && !_downloading
                        ? () {
                            unawaited(
                              _download().whenComplete(() {
                                if (context.mounted) setSheetState(() {});
                              }),
                            );
                            setSheetState(() {});
                          }
                        : null,
                    child: Text(t.settings.downloadAction),
                  ),
                ),
                Expanded(
                  child: DsButton(
                    loading: _saving,
                    onPressed: _canCommit && !_saving
                        ? () {
                            unawaited(
                              _apply().whenComplete(() {
                                if (context.mounted) setSheetState(() {});
                              }),
                            );
                            setSheetState(() {});
                          }
                        : null,
                    child: Text(t.settings.backgroundApply),
                  ),
                ),
              ],
            ),
            child: _PreviewSettings(
              videoMode: _videoMode,
              paintMode: widget.subject.isPaint,
              muted: _muted,
              autoPlay: _autoPlay,
              interval: _interval,
              onMuted: (value) {
                setState(() => _muted = value);
                setSheetState(() {});
              },
              onAutoPlay: (value) {
                _setAutoPlay(value);
                setSheetState(() {});
              },
              onInterval: (value) {
                _setInterval(value);
                setSheetState(() {});
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);

  Widget _buildPage(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final config = _configOf(context, settings);
    final isVideo = _currentItem?.video ?? false;
    final wide = MediaQuery.sizeOf(context).width >= _kPreviewWideBreakpoint;
    // The frame follows the app's light or dark skin; the backdrop is the
    // wallpaper itself, so the page looks the same in either one only where
    // the media stands.
    return ColoredBox(
      color: DsTheme.colorsOf(context).canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(image: _backdropImage()),
          SafeArea(
            child: wide ? _buildDesktop(context, t, config, isVideo) : _buildMobile(context, t, config, isVideo),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, Translations t, BackgroundConfig? config, bool isVideo) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 920),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 56, offset: Offset(0, 28))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: DsSpace.s12,
                        children: [
                          Expanded(child: _buildStage(context, t, config, isVideo, radius: 14)),
                          if (_stripCount > 0) _buildStrip(context, t),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 380,
                    decoration: BoxDecoration(
                      border: BorderDirectional(start: BorderSide(color: colors.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsPreviewHeading(
                          icon: _videoMode ? DsIcons.video : DsIcons.image,
                          title: widget.subject.isRandom
                              ? t.settings.backgroundPreviewTitle
                              : _videoMode
                              ? t.settings.backgroundVideosTitle
                              : t.settings.backgroundImagesTitle,
                          subtitle: _title(t),
                          trailing: DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const DsIcon(DsIcons.close),
                            semanticLabel: t.common.close,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
                            child: _PreviewSettings(
                              videoMode: _videoMode,
                              paintMode: widget.subject.isPaint,
                              muted: _muted,
                              autoPlay: _autoPlay,
                              interval: _interval,
                              onMuted: (value) => setState(() => _muted = value),
                              onAutoPlay: _setAutoPlay,
                              onInterval: _setInterval,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(DsSpace.s20),
                          child: Row(
                            spacing: DsSpace.s8,
                            children: [
                              DsButton.icon(
                                variant: DsButtonVariant.secondary,
                                onPressed: _canCommit && !_downloading ? () => unawaited(_download()) : null,
                                icon: const DsIcon(DsIcons.download),
                                semanticLabel: t.settings.downloadAction,
                              ),
                              Expanded(
                                child: DsButton(
                                  loading: _saving,
                                  onPressed: _canCommit && !_saving ? () => unawaited(_apply()) : null,
                                  child: Text(t.settings.backgroundApply),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context, Translations t, BackgroundConfig? config, bool isVideo) {
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildStage(context, t, config, isVideo, radius: 0),
              PositionedDirectional(
                top: DsSpace.s8,
                start: DsSpace.s8,
                child: SettingsPreviewCircleButton(
                  icon: DsIcons.chevronLeft,
                  semanticLabel: t.common.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              PositionedDirectional(
                top: DsSpace.s8,
                end: DsSpace.s8,
                child: SettingsPreviewCircleButton(
                  icon: DsIcons.circleEllipsis,
                  semanticLabel: t.settings.backgroundPreviewSettingsTitle,
                  onPressed: () => unawaited(_openSettingsSheet()),
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                if (_stripCount > 0) _buildStrip(context, t),
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: DsIcons.download,
                        label: t.settings.downloadAction,
                        onPressed: _canCommit && !_downloading ? () => unawaited(_download()) : null,
                      ),
                    ),
                    Expanded(
                      child: _ActionTile(
                        icon: DsIcons.check,
                        label: t.settings.backgroundApply,
                        emphasized: true,
                        onPressed: _canCommit && !_saving ? () => unawaited(_apply()) : null,
                      ),
                    ),
                    Expanded(
                      child: _ActionTile(
                        icon: DsIcons.slidersHorizontal,
                        label: t.settings.backgroundPreviewSettingsTitle,
                        onPressed: () => unawaited(_openSettingsSheet()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStage(
    BuildContext context,
    Translations t,
    BackgroundConfig? config,
    bool isVideo, {
    required double radius,
  }) {
    final item = _currentItem;
    final resolution = config == null || widget.subject.isPaint ? null : _resolutionLabel(t);
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _stageContent(config, t),
            if (isVideo)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: SettingsPreviewBar(
                  children: [
                    SettingsPreviewCircleButton(
                      icon: _paused ? DsIcons.play : DsIcons.pause,
                      semanticLabel: _paused ? t.room.play : t.room.pause,
                      onPressed: () => setState(() => _paused = !_paused),
                    ),
                    SettingsPreviewCircleButton(
                      icon: _muted ? DsIcons.volumeOff : DsIcons.volume,
                      semanticLabel: _muted ? t.room.unmute : t.room.mute,
                      onPressed: () => setState(() => _muted = !_muted),
                    ),
                    const SizedBox(width: DsSpace.s8),
                    Text(
                      t.settings.backgroundPreviewLooping,
                      style: DsTheme.of(context).typography.small.copyWith(color: const Color(0xCCFFFFFF)),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            if (isVideo && _paused)
              Center(
                child: _PlayButton(onPressed: () => setState(() => _paused = false), semanticLabel: t.room.play),
              ),
            if (resolution != null)
              PositionedDirectional(
                start: DsSpace.s12,
                bottom: isVideo ? 76 : DsSpace.s12,
                child: SettingsPreviewChip(label: resolution),
              ),
            // Another random picture is on its way: the stage keeps the
            // current one under a dim and a spinner rather than going blank.
            if (_loading && widget.subject.isRandom)
              ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: DsSpinner(
                    semanticLabel: t.settings.backgroundImage,
                    style: const DsSpinnerStyle(size: 36, color: Color(0xFFFFFFFF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return DsContextMenuRegion(
      semanticLabel: _title(t),
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.check),
          label: Text(t.settings.backgroundApply),
          onPressed: () => unawaited(_apply()),
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.download),
          label: Text(t.settings.downloadAction),
          onPressed: () => unawaited(_download()),
        ),
        if (item != null)
          DsMenuItem(
            leading: const DsIcon(DsIcons.link),
            label: Text(t.settings.backgroundCopyAddress),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: item.url));
              if (!context.mounted) return;
              showDsToast(context: context, title: t.common.copied);
            },
          ),
      ],
      child: media,
    );
  }

  Widget _stageContent(BackgroundConfig? config, Translations t) {
    if (config != null) {
      return PureBackground(config: config, paused: _paused, child: const SizedBox.shrink());
    }
    if (_failure != null) {
      return _FailureView(failure: _failure, onRetry: () => unawaited(_fetch()));
    }
    if (!widget.subject.isRandom && _items.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.image), title: Text(t.settings.backgroundLibraryEmpty)),
      );
    }
    return Center(
      child: DsSpinner(
        style: const DsSpinnerStyle(size: 28),
        semanticLabel: _videoMode ? t.settings.backgroundVideo : t.settings.backgroundImage,
      ),
    );
  }

  Widget _buildStrip(BuildContext context, Translations t) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final random = widget.subject.isRandom;
    final count = _stripCount;
    final index = _stripIndex;
    final label = _videoMode ? t.settings.backgroundMoreVideos : t.settings.backgroundMoreImages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s4,
          children: [
            DsIcon(_videoMode ? DsIcons.video : DsIcons.image, size: 16, color: colors.textSubtle),
            const SizedBox(width: DsSpace.s4),
            Text(label, style: theme.typography.labelStrong.copyWith(color: colors.text)),
            const Spacer(),
            Text(
              '${count == 0 ? 0 : index + 1} / $count',
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
            SettingsPreviewCircleButton(
              icon: DsIcons.chevronLeft,
              size: 28,
              semanticLabel: t.settings.backgroundPreviewPrevious,
              onPressed: count == 0 || index <= 0 ? null : () => _selectStrip(index - 1),
            ),
            SettingsPreviewCircleButton(
              icon: DsIcons.chevronRight,
              size: 28,
              semanticLabel: t.settings.backgroundPreviewNext,
              onPressed: count == 0 || (index >= count - 1 && !_canLoadMore) ? null : () => unawaited(_advance()),
            ),
            if (random)
              SettingsPreviewCircleButton(
                icon: DsIcons.refreshCw,
                size: 28,
                semanticLabel: t.settings.backgroundPreviewNext,
                onPressed: _loading ? null : () => unawaited(_fetch()),
              ),
          ],
        ),
        SizedBox(
          height: 76,
          child: ListView.separated(
            controller: _stripScroll,
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpace.s8),
            itemBuilder: (context, position) {
              final selected = position == index;
              final walked = widget.subject.isPaint;
              final item = random || walked ? null : _items[position];
              final swatch = walked ? _swatches[position] : null;
              final provider = random
                  ? MemoryImage(_shots[position].bytes)
                  : (swatch == null ? imageProviderOf(_items[position].thumb) : null);
              final video = !random && !walked && _items[position].video;
              final label = item?.name ?? swatch?.name ?? '${t.settings.backgroundMoreImages} ${position + 1}';
              return DsContextMenuRegion(
                semanticLabel: label,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.eye),
                    label: Text(t.settings.backgroundPreviewMedia),
                    onPressed: () => _selectStrip(position),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.check),
                    label: Text(t.settings.backgroundApply),
                    onPressed: () {
                      _selectStrip(position);
                      unawaited(_apply());
                    },
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.download),
                    label: Text(t.settings.downloadAction),
                    onPressed: () {
                      _selectStrip(position);
                      unawaited(_download());
                    },
                  ),
                  if (item != null)
                    DsMenuItem(
                      leading: const DsIcon(DsIcons.link),
                      label: Text(t.settings.backgroundCopyAddress),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: item.url));
                        if (!context.mounted) return;
                        showDsToast(context: context, title: t.common.copied);
                      },
                    ),
                ],
                child: _ThumbTile(
                  image: provider,
                  swatch: swatch == null ? null : _decorationOf(swatch),
                  selected: selected,
                  video: video,
                  semanticLabel: label,
                  onPressed: () => _selectStrip(position),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The window behind the stage: the media itself, blurred heavily and dimmed,
/// so the chosen picture sets the mood without competing with the preview.
final class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final picture = image;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The wash follows the skin: a dim stage at night, a pale one by day,
        // so the preview reads as part of the app either way.
        ColoredBox(color: colors.canvas),
        if (picture != null)
          // Scaled past the edges so the blurred border never shows as a
          // bright rim around the window.
          ClipRect(
            child: Transform.scale(
              scale: 1.2,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: Image(image: picture, fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
          ),
        ColoredBox(color: theme.brightness == Brightness.dark ? const Color(0x99000000) : const Color(0x66FFFFFF)),
      ],
    );
  }
}

/// The settings shared by the desktop sidebar and the touch sheet.
final class _PreviewSettings extends ConsumerWidget {
  const _PreviewSettings({
    required this.videoMode,
    required this.paintMode,
    required this.muted,
    required this.autoPlay,
    required this.interval,
    required this.onMuted,
    required this.onAutoPlay,
    required this.onInterval,
  });

  final bool videoMode;

  /// A palette swatch: the fit and the slideshow have nothing to act on.
  final bool paintMode;
  final bool muted;
  final bool autoPlay;
  final Duration interval;
  final ValueChanged<bool> onMuted;
  final ValueChanged<bool> onAutoPlay;
  final ValueChanged<Duration> onInterval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (!paintMode)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              _SectionTitle(icon: DsIcons.expand, label: t.settings.backgroundDisplayMode),
              DsSelect<BoxFit>(
                value: settings.fit,
                semanticLabel: t.settings.backgroundDisplayMode,
                options: [
                  for (final fit in kBackgroundFits) DsSelectOption(value: fit, label: backgroundFitLabel(t, fit)),
                ],
                onChanged: (fit) {
                  if (fit != null) controller.setFit(fit);
                },
              ),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            _SectionTitle(icon: DsIcons.contrast, label: t.settings.backgroundMask),
            _SliderRow(
              value: settings.maskOpacity,
              max: 0.8,
              divisions: 16,
              label: '${(settings.maskOpacity * 100).round()}%',
              semanticLabel: t.settings.backgroundMask,
              onChanged: controller.setMaskOpacity,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            _SectionTitle(icon: DsIcons.dropletLines, label: t.settings.backgroundOverlayBlur),
            _SliderRow(
              value: settings.overlayBlurSigma,
              max: 24,
              divisions: 24,
              label: '${settings.overlayBlurSigma.round()}',
              semanticLabel: t.settings.backgroundOverlayBlur,
              onChanged: controller.setOverlayBlurSigma,
            ),
          ],
        ),
        if (videoMode)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              _SectionTitle(icon: DsIcons.volume, label: t.settings.backgroundVideo),
              DsSwitch(
                value: muted,
                onChanged: onMuted,
                label: Text(t.room.mute),
                description: Text(t.settings.backgroundPreviewVideoHint),
              ),
            ],
          )
        else if (!paintMode)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              _SectionTitle(icon: DsIcons.image, label: t.settings.backgroundImage),
              DsSwitch(value: autoPlay, onChanged: onAutoPlay, label: Text(t.settings.backgroundAutoPlay)),
              Text(t.settings.backgroundPlayInterval, style: theme.typography.body.copyWith(color: colors.text)),
              DsSegmentedControl<Duration>(
                value: interval,
                semanticLabel: t.settings.backgroundPlayInterval,
                segments: [
                  for (final option in _kSlideshowIntervals)
                    DsSegment(
                      value: option,
                      label: Text(t.settings.backgroundIntervalSeconds(count: option.inSeconds)),
                    ),
                ],
                onChanged: onInterval,
              ),
            ],
          ),
      ],
    );
  }
}

/// A settings section's label: icon and name on one muted line.
final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final DsIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsIcon(icon, size: 16, color: colors.textSubtle),
        Text(label, style: theme.typography.labelStrong.copyWith(color: colors.text)),
      ],
    );
  }
}

/// A slider with its value printed on the trailing edge.
final class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.value,
    required this.max,
    required this.divisions,
    required this.label,
    required this.semanticLabel,
    required this.onChanged,
  });

  final double value;
  final double max;
  final int divisions;
  final String label;
  final String semanticLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return Row(
      spacing: DsSpace.s12,
      children: [
        Expanded(
          child: DsSlider(
            value: value,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            semanticLabel: semanticLabel,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.end,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
        ),
      ],
    );
  }
}

/// One sibling in the strip: a rounded still, marked when it is in view.
final class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.selected,
    required this.video,
    required this.semanticLabel,
    required this.onPressed,
    this.image,
    this.swatch,
  });

  final ImageProvider? image;

  /// The tile of a palette entry: the paint itself, with no picture behind it.
  final BoxDecoration? swatch;
  final bool selected;
  final bool video;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final inset = selected ? 2.0 : 1.0;
    return DsPressable(
      semanticLabel: semanticLabel,
      selected: selected,
      onPressed: onPressed,
      // The ring is painted outside the rounded clip: sharing one radius
      // with the clip shaved its outer edge at the corners.
      builder: (context, states, _) => Container(
        width: 120,
        height: 76,
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.circular(10 - inset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (swatch case final paint?)
                DecoratedBox(decoration: paint)
              else if (image case final picture?)
                DsImage(image: picture, width: 116, height: 72, semanticLabel: semanticLabel),
              if (video && !selected) const Center(child: DsIcon(DsIcons.play, size: 20, color: Color(0xCCFFFFFF))),
              if (selected)
                PositionedDirectional(
                  end: 4,
                  bottom: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                    child: Center(child: DsIcon(DsIcons.check, size: 12, color: colors.onAccent)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The large play control over a paused clip.
final class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed, required this.semanticLabel});

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0x8A000000),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: const Center(child: DsIcon(DsIcons.play, size: 30, color: Color(0xFFFFFFFF))),
      ),
    );
  }
}

/// One action in the narrow layout's bottom row.
final class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onPressed, this.emphasized = false});

  final DsIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final enabled = onPressed != null;
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: emphasized ? colors.accent : colors.control,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: DsIcon(
                icon,
                size: 20,
                color: emphasized
                    ? colors.onAccent
                    : enabled
                    ? colors.text
                    : colors.textSubtle,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.typography.small.copyWith(color: enabled ? colors.text : colors.textSubtle),
          ),
        ],
      ),
    );
  }
}

/// A random source that did not answer with a picture, with the retry in
/// place instead of a dead preview.
final class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure, required this.onRetry});

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
      color: colors.canvas,
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
