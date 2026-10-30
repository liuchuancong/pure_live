import 'dart:async' show unawaited;
import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart' show FilePicker, FileType, PlatformFile;
import 'package:flutter/painting.dart' show BoxFit, Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/background/library/background_presets.dart';
import 'package:pure_live/app/background/tone/background_thumbnails.dart' show backgroundClipStillsProvider;
import 'package:pure_live/app/providers/providers.dart';

/// What the app paints behind every page.
enum BackgroundKind {
  /// The theme's own surface (no media).
  none,

  /// A flat colour from the preset palette.
  solid,

  /// A linear gradient from the preset palette.
  gradient,

  /// A still picture, uploaded, from a URL, or from the gallery.
  image,

  /// A looping muted video, uploaded or from a URL.
  video,
}

/// What a local file can become.
enum BackgroundMediaKind { image, video }

/// How the scrim over the wallpaper is decided.
enum BackgroundScrimMode {
  /// No wash at all: the wallpaper is painted as it is.
  off,

  /// At least the custom value, raised until the page's text reaches its
  /// contrast target.
  auto,

  /// Exactly the custom value, whatever it means for readability.
  custom,
}

/// The image formats the importer accepts, in the order the page names them.
const List<String> kBackgroundImageExtensions = [
  'jpg', 'jpeg', 'jfif', 'png', 'webp', 'gif', 'bmp', 'avif', 'heic', 'heif', 'tif', 'tiff', 'ico',
];

/// The video formats the importer accepts, in the order the page names them.
const List<String> kBackgroundVideoExtensions = [
  'mp4', 'm4v', 'mov', 'webm', 'mkv', 'avi', 'flv', 'ts', 'm2ts', 'wmv', '3gp', 'ogv', 'mpg', 'mpeg', 'vob', 'asf',
];

/// What [path]'s extension says it is; null when neither table knows it.
BackgroundMediaKind? backgroundMediaKindOf(String path) {
  final extension = p.extension(path).toLowerCase().replaceFirst('.', '');
  if (kBackgroundImageExtensions.contains(extension)) return BackgroundMediaKind.image;
  if (kBackgroundVideoExtensions.contains(extension)) return BackgroundMediaKind.video;
  return null;
}

/// The fits the background settings offer; a subset of [BoxFit] worded in
/// the settings pane.
const List<BoxFit> kBackgroundFits = [
  BoxFit.cover,
  BoxFit.contain,
  BoxFit.fill,
  BoxFit.fitWidth,
  BoxFit.fitHeight,
  BoxFit.none,
  BoxFit.scaleDown,
];

/// The background's saved choices and the transient upload state.
///
/// Each media kind keeps one source: an uploaded local file (path into the
/// app's data area) or a URL. Setting one clears the other; [kind] picks
/// which kind paints. Empty strings mean "not set", which keeps `copyWith`
/// able to clear a field.
final class BackgroundSettings {
  const BackgroundSettings({
    this.kind = BackgroundKind.none,
    this.imageUrl = '',
    this.imagePath = '',
    this.videoUrl = '',
    this.videoPath = '',
    this.solidColor = const Color(0xFF141E30),
    this.gradientColors = const [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    this.gradientStops = const [0, 1],
    this.gradientDeg = 0,
    this.fit = BoxFit.cover,
    this.scrimMode = BackgroundScrimMode.auto,
    this.scrimOpacity = 0.45,
    this.followTone = true,
    this.backgroundBlurSigma = 0,
    this.glass = false,
    this.glassFill = 0.6,
    this.glassBlur = 24,
    this.busy = false,
    this.error = '',
  });

  final BackgroundKind kind;
  final String imageUrl;
  final String imagePath;
  final String videoUrl;
  final String videoPath;

  /// The flat fill when [kind] is [BackgroundKind.solid].
  final Color solidColor;

  /// The stops when [kind] is [BackgroundKind.gradient]; at least two.
  final List<Color> gradientColors;

  /// Where each stop sits along the gradient line (0–1). The preset table
  /// carries positions; a value saved before it did comes back evenly spread.
  final List<double>? gradientStops;

  /// The gradient's CSS angle (0° points up, positive is clockwise), as the
  /// preset table publishes it.
  final int gradientDeg;

  final BoxFit fit;

  /// How the scrim's opacity is decided. [BackgroundScrimMode.auto] keeps the
  /// wallpaper readable without the viewer having to find the right number;
  /// the custom value in [scrimOpacity] is its floor, so a background that
  /// already reads well at that opacity looks exactly as it always did.
  final BackgroundScrimMode scrimMode;

  /// The scrim: the whole-screen wash laid over the wallpaper, white in a
  /// light palette and black in the dark one. Its opacity is what raises
  /// text contrast, and it is the layer the tone decision scores. In
  /// [BackgroundScrimMode.auto] it is the minimum, not the final value.
  final double scrimOpacity;

  /// Whether the wallpaper's measured brightness chooses the light or the
  /// dark palette. Off keeps the viewer's own theme on every background.
  final bool followTone;

  /// Gaussian sigma applied to the wallpaper itself — pictures, clips,
  /// gradients and flat colours alike. 0 keeps it sharp. This blurs the
  /// backdrop, not the scrim above it.
  final double backgroundBlurSigma;

  /// Whether the app's surfaces wear the glass fill and frost
  /// ([glassFill] over [glassBlur]) instead of the theme's opaque kinds.
  final bool glass;

  /// The panel fill: how opaque a card, list or floating layer's own
  /// background is, so the wallpaper reads through it.
  final double glassFill;

  /// Gaussian sigma behind a floating layer; 0 keeps it translucent but
  /// sharp. Surfaces that cannot frost (cards, lists) keep the fill alone.
  final double glassBlur;

  /// An upload is being copied into the app's data area.
  final bool busy;

  /// The last upload's failure, for the pane; empty when none.
  final String error;

  /// Whether [kind] has a source to paint.
  bool get active => switch (kind) {
    BackgroundKind.none => false,
    BackgroundKind.solid => true,
    BackgroundKind.gradient => gradientColors.length >= 2,
    BackgroundKind.image => imagePath.isNotEmpty || imageUrl.isNotEmpty,
    BackgroundKind.video => videoPath.isNotEmpty || videoUrl.isNotEmpty,
  };

  BackgroundSettings copyWith({
    BackgroundKind? kind,
    String? imageUrl,
    String? imagePath,
    String? videoUrl,
    String? videoPath,
    Color? solidColor,
    List<Color>? gradientColors,
    List<double>? gradientStops,
    int? gradientDeg,
    BoxFit? fit,
    BackgroundScrimMode? scrimMode,
    double? scrimOpacity,
    bool? followTone,
    double? backgroundBlurSigma,
    bool? glass,
    double? glassFill,
    double? glassBlur,
    bool? busy,
    String? error,
  }) => BackgroundSettings(
    kind: kind ?? this.kind,
    imageUrl: imageUrl ?? this.imageUrl,
    imagePath: imagePath ?? this.imagePath,
    videoUrl: videoUrl ?? this.videoUrl,
    videoPath: videoPath ?? this.videoPath,
    solidColor: solidColor ?? this.solidColor,
    gradientColors: gradientColors ?? this.gradientColors,
    gradientStops: gradientStops ?? this.gradientStops,
    gradientDeg: gradientDeg ?? this.gradientDeg,
    fit: fit ?? this.fit,
    scrimMode: scrimMode ?? this.scrimMode,
    scrimOpacity: scrimOpacity ?? this.scrimOpacity,
    followTone: followTone ?? this.followTone,
    backgroundBlurSigma: backgroundBlurSigma ?? this.backgroundBlurSigma,
    glass: glass ?? this.glass,
    glassFill: glassFill ?? this.glassFill,
    glassBlur: glassBlur ?? this.glassBlur,
    busy: busy ?? this.busy,
    error: error ?? this.error,
  );
}

/// Owns the background choices and copies picked files into the app's own
/// data area, so a picked file survives its picker's temporary location.
final class BackgroundSettingsController extends Notifier<BackgroundSettings> {
  /// The persisted parameter names.
  static const _kindKey = 'background.kind';
  static const _imageUrlKey = 'background.imageUrl';
  static const _imagePathKey = 'background.imagePath';
  static const _videoUrlKey = 'background.videoUrl';
  static const _videoPathKey = 'background.videoPath';
  static const _solidKey = 'background.solid';
  static const _gradientKey = 'background.gradient';
  static const _fitKey = 'background.fit';
  // The stored names predate the wording the pane uses now; keeping them
  // means a settings file and a backup written by an older build still read.
  static const _scrimKey = 'background.mask';
  static const _scrimModeKey = 'background.scrimMode';
  static const _followToneKey = 'background.followTone';
  static const _backgroundBlurKey = 'background.overlayBlur';
  static const _glassKey = 'background.glass';
  static const _glassFillKey = 'background.glassFill';
  static const _glassBlurKey = 'background.glassBlur';

  @override
  BackgroundSettings build() {
    try {
      final kind = BackgroundKind.values.firstWhere(
        (value) => value.name == StoragePrefs.getString(_kindKey),
        orElse: () => BackgroundKind.none,
      );
      final fit = BoxFit.values.firstWhere(
        (value) => value.name == StoragePrefs.getString(_fitKey),
        orElse: () => BoxFit.cover,
      );
      final storedGradient = _parseGradient(StoragePrefs.getString(_gradientKey));
      return BackgroundSettings(
        kind: kind,
        imageUrl: StoragePrefs.getString(_imageUrlKey) ?? '',
        imagePath: StoragePrefs.getString(_imagePathKey) ?? '',
        videoUrl: StoragePrefs.getString(_videoUrlKey) ?? '',
        videoPath: StoragePrefs.getString(_videoPathKey) ?? '',
        solidColor: _parseColor(StoragePrefs.getString(_solidKey)) ?? const Color(0xFF141E30),
        gradientColors: storedGradient.colors,
        gradientStops: storedGradient.stops,
        gradientDeg: storedGradient.deg,
        fit: fit,
        scrimMode: BackgroundScrimMode.values.firstWhere(
          (value) => value.name == StoragePrefs.getString(_scrimModeKey),
          orElse: () => BackgroundScrimMode.auto,
        ),
        scrimOpacity: (StoragePrefs.getDouble(_scrimKey) ?? 0.45).clamp(0.0, 0.8),
        followTone: StoragePrefs.getBool(_followToneKey) ?? true,
        backgroundBlurSigma: (StoragePrefs.getDouble(_backgroundBlurKey) ?? 0).clamp(0.0, 24.0),
        glass: StoragePrefs.getBool(_glassKey) ?? false,
        glassFill: (StoragePrefs.getDouble(_glassFillKey) ?? 0.6).clamp(0.0, 1.0),
        glassBlur: (StoragePrefs.getDouble(_glassBlurKey) ?? 24).clamp(0.0, 48.0),
      );
    } on Object {
      // Storage never opened: the defaults stand.
      return const BackgroundSettings();
    }
  }

  /// Paints [kind] behind the pages, source or not.
  void selectKind(BackgroundKind kind) {
    final gradient = state.gradientColors.length < 2 ? kDefaultGradientPreset : null;
    _update(
      state.copyWith(
        kind: kind,
        gradientColors: gradient?.colors,
        gradientStops: gradient?.stops,
        gradientDeg: gradient?.deg,
        error: '',
      ),
    );
  }

  /// Uses [color] as the flat fill (and switches to the solid kind).
  void setSolid(Color color) => _update(state.copyWith(kind: BackgroundKind.solid, solidColor: color, error: ''));

  /// Uses the preset's colours, stop positions and angle (and switches to
  /// the gradient kind).
  void setGradient(BackgroundGradientPreset preset) {
    if (preset.colors.length < 2) return;
    _update(
      state.copyWith(
        kind: BackgroundKind.gradient,
        gradientColors: List.unmodifiable(preset.colors),
        gradientStops: List.unmodifiable(preset.stops),
        gradientDeg: preset.deg,
        error: '',
      ),
    );
  }

  /// Uses [url] as the image and drops the uploaded file it replaces.
  void setImageUrl(String url) {
    final old = state.imagePath;
    _update(state.copyWith(kind: BackgroundKind.image, imageUrl: url.trim(), imagePath: '', error: ''));
    unawaited(_delete(old));
  }

  /// Uses [url] as the video and drops the uploaded file it replaces.
  void setVideoUrl(String url) {
    final old = state.videoPath;
    _update(state.copyWith(kind: BackgroundKind.video, videoUrl: url.trim(), videoPath: '', error: ''));
    unawaited(_delete(old));
  }

  void setFit(BoxFit fit) => _update(state.copyWith(fit: fit));

  /// How the scrim's opacity is decided; see [BackgroundScrimMode].
  void setScrimMode(BackgroundScrimMode mode) => _update(state.copyWith(scrimMode: mode));

  /// The custom scrim strength; in auto mode it is the floor, otherwise the
  /// exact wash. Writing it never changes the mode: the preview page stages
  /// this value for every preset and must not turn auto into custom.
  void setScrimOpacity(double opacity) => _update(state.copyWith(scrimOpacity: opacity.clamp(0.0, 0.8)));

  /// Whether the wallpaper's brightness chooses the palette.
  void setFollowTone({required bool value}) => _update(state.copyWith(followTone: value));

  /// How much the wallpaper itself is blurred, on every kind. Capped low:
  /// this runs on the backdrop every frame, not on one still.
  void setBackgroundBlur(double sigma) => _update(state.copyWith(backgroundBlurSigma: sigma.clamp(0.0, 24.0)));

  /// Whether surfaces wear the glass fill and frost.
  void setGlass({required bool value}) => _update(state.copyWith(glass: value));

  /// The panel fill's opacity; 0 lets the wallpaper through untouched.
  void setGlassFill(double value) => _update(state.copyWith(glassFill: value.clamp(0.0, 1.0)));

  /// The frost behind a floating layer; 0 keeps it translucent but sharp.
  void setGlassBlur(double sigma) => _update(state.copyWith(glassBlur: sigma.clamp(0.0, 48.0)));

  /// Back to the theme's surface; the saved media stays for a reselect.
  void clear() => _update(state.copyWith(kind: BackgroundKind.none, error: ''));

  /// Opens the picker for any supported image or video and copies it into the
  /// slot its own type names: the viewer does not have to say which kind the
  /// file is. Returns the kind imported, or null when the picker was closed.
  Future<BackgroundMediaKind?> uploadMedia({required String dialogTitle}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: [...kBackgroundImageExtensions, ...kBackgroundVideoExtensions],
    );
    if (file == null) return null;
    final kind = backgroundMediaKindOf(file.name) ?? backgroundMediaKindOf(file.path ?? '');
    if (kind == null) return null;
    final image = kind == BackgroundMediaKind.image;
    final previous = image ? state.imagePath : state.videoPath;
    await _importPicked(
      file,
      prefix: image ? 'background-image' : 'background-video',
      onDone: (path) => image
          ? state.copyWith(kind: BackgroundKind.image, imagePath: path, imageUrl: '')
          : state.copyWith(kind: BackgroundKind.video, videoPath: path, videoUrl: ''),
    );
    if (!ref.mounted || state.error.isNotEmpty) return kind;
    unawaited(_delete(previous));
    return kind;
  }

  /// Copies a file dropped onto the settings page into the data area and
  /// paints it; [image] picks which source it becomes.
  Future<void> importDroppedFile(String path, {required bool image}) async {
    final previous = image ? state.imagePath : state.videoPath;
    final extension = p.extension(path);
    await _import(
      sourcePath: path,
      extension: extension.isEmpty ? null : extension.substring(1),
      stream: null,
      prefix: image ? 'background-image' : 'background-video',
      onDone: (target) => image
          ? state.copyWith(kind: BackgroundKind.image, imagePath: target, imageUrl: '')
          : state.copyWith(kind: BackgroundKind.video, videoPath: target, videoUrl: ''),
    );
    if (!ref.mounted || state.error.isNotEmpty) return;
    unawaited(_delete(previous));
  }

  /// Copies a file the picker handed over: from its path on desktop, from
  /// its stream where the platform only has bytes.
  Future<void> _importPicked(
    PlatformFile file, {
    required String prefix,
    required BackgroundSettings Function(String path) onDone,
  }) {
    final path = file.path;
    return _import(
      sourcePath: path,
      extension: file.extension,
      stream: path == null || path.isEmpty ? file.readAsByteStream() : null,
      prefix: prefix,
      onDone: onDone,
    );
  }

  /// Drops the copied file. When it was what the app painted and no address
  /// replaces it, the background returns to the theme's surface.
  void removeFile({required bool image}) {
    final path = image ? state.imagePath : state.videoPath;
    if (path.isEmpty) return;
    final kind = switch (state.kind) {
      BackgroundKind.image when image && state.imageUrl.isEmpty => BackgroundKind.none,
      BackgroundKind.video when !image && state.videoUrl.isEmpty => BackgroundKind.none,
      final current => current,
    };
    _update(
      image
          ? state.copyWith(kind: kind, imagePath: '', error: '')
          : state.copyWith(kind: kind, videoPath: '', error: ''),
    );
    unawaited(_delete(path));
  }

  /// Saves a picture fetched from a random source and makes it the image
  /// background.
  ///
  /// A random API has no stable URL to keep, so the bytes are written into
  /// the app's own media folder. The name is a content hash: fetching the
  /// same picture twice reuses one file and leaves the previous one alone.
  Future<void> useRandomImage(Uint8List bytes, {required String extension}) async {
    if (bytes.length < 256) return;
    state = state.copyWith(busy: true, error: '');
    File? target;
    try {
      final paths = ref.read(storagePathsProvider);
      final directory = Directory(p.join(paths.data.path, 'background'));
      await directory.create(recursive: true);
      target = File(p.join(directory.path, 'random-${_bytesHash(bytes)}.$extension'));
      if (!target.existsSync() || target.lengthSync() == 0) {
        await target.writeAsBytes(bytes, flush: true);
      }
      if (!ref.mounted) return;
      final previous = state.imagePath;
      state = state.copyWith(kind: BackgroundKind.image, imagePath: target.path, imageUrl: '', busy: false, error: '');
      _persist();
      if (previous.isNotEmpty && previous != target.path) unawaited(_delete(previous));
    } on Object catch (error) {
      if (target != null) await _delete(target.path);
      if (!ref.mounted) return;
      state = state.copyWith(busy: false, error: '$error');
    }
  }

  Future<void> _import({
    required String? sourcePath,
    required String? extension,
    required Stream<List<int>>? stream,
    required String prefix,
    required BackgroundSettings Function(String path) onDone,
  }) async {
    state = state.copyWith(busy: true, error: '');
    File? target;
    try {
      final paths = ref.read(storagePathsProvider);
      final directory = Directory(p.join(paths.data.path, 'background'));
      await directory.create(recursive: true);
      final suffix = extension != null && extension.isNotEmpty ? '.$extension' : '';
      target = File(p.join(directory.path, '$prefix-${DateTime.now().microsecondsSinceEpoch}$suffix'));
      if (sourcePath != null && sourcePath.isNotEmpty) {
        await File(sourcePath).copy(target.path);
      } else if (stream != null) {
        final sink = target.openWrite();
        try {
          await stream.forEach(sink.add);
          await sink.flush();
        } finally {
          await sink.close();
        }
      }
      if (!ref.mounted) return;
      state = onDone(target.path).copyWith(busy: false, error: '');
      _persist();
      if (sourcePath != null &&
          sourcePath.isNotEmpty &&
          backgroundMediaKindOf(target.path) == BackgroundMediaKind.video) {
        // A clip that was downloaded already has a still; the copy carries
        // it instead of opening the frames a second time.
        unawaited(
          ref
              .read(backgroundClipStillsProvider)
              .carry(from: Uri.file(sourcePath).toString(), to: Uri.file(target.path).toString()),
        );
      }
    } on Object catch (error) {
      if (target != null) await _delete(target.path);
      if (!ref.mounted) return;
      state = state.copyWith(busy: false, error: '$error');
    }
  }

  Future<void> _delete(String path) async {
    if (path.isEmpty) return;
    // A clip's still is keyed by the clip; the clip going makes it garbage.
    if (backgroundMediaKindOf(path) == BackgroundMediaKind.video) {
      await ref.read(backgroundClipStillsProvider).forget(Uri.file(path).toString());
    }
    try {
      await File(path).delete();
    } on Object {
      // A file already gone (or locked) is not an upload failure.
    }
  }

  void _update(BackgroundSettings next) {
    state = next;
    _persist();
  }

  void _persist() {
    final value = state;
    unawaited(
      StoragePrefs.setPrefs({
        _kindKey: value.kind.name,
        _imageUrlKey: value.imageUrl,
        _imagePathKey: value.imagePath,
        _videoUrlKey: value.videoUrl,
        _videoPathKey: value.videoPath,
        _solidKey: _colorHex(value.solidColor),
        _gradientKey: _encodeGradient(value),
        _fitKey: value.fit.name,
        _scrimModeKey: value.scrimMode.name,
        _scrimKey: value.scrimOpacity,
        _followToneKey: value.followTone,
        _backgroundBlurKey: value.backgroundBlurSigma,
        _glassKey: value.glass,
        _glassFillKey: value.glassFill,
        _glassBlurKey: value.glassBlur,
      }).catchError((Object _) {
        // A preference; a closed store loses it.
      }),
    );
  }
}

/// A colour as `#AARRGGBB`, the form the prefs store.
String _colorHex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// FNV-1a over the bytes and their length: stable across runs, so the same
/// random picture is stored once.
String _bytesHash(Uint8List bytes) {
  var hash = 0x811C9DC5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return '${hash.toRadixString(16).padLeft(8, '0')}-${bytes.length.toRadixString(16)}';
}

Color? _parseColor(String? text) {
  final value = int.tryParse((text ?? '').replaceFirst('#', ''), radix: 16);
  if (value == null) return null;
  return Color(text!.replaceFirst('#', '').length <= 6 ? 0xFF000000 | value : value);
}

/// One stored gradient: `120|#A1C4FD@0,#C2E9FB@100`.
///
/// The older form — a bare comma list of colours, no angle, no positions —
/// still parses: the stops spread evenly and the angle falls back to the
/// diagonal the app painted before the preset table carried one (135°).
({List<Color> colors, List<double>? stops, int deg}) _parseGradient(String? text) {
  const fallback = (colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)], stops: <double>[0, 1], deg: 0);
  final value = text?.trim() ?? '';
  if (value.isEmpty) return fallback;
  final (String? head, String rest) = value.contains('|')
      ? (value.substring(0, value.indexOf('|')), value.substring(value.indexOf('|') + 1))
      : (null, value);
  final parts = [
    for (final part in rest.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
  final colors = <Color>[];
  final stops = <double>[];
  for (final part in parts) {
    final at = part.indexOf('@');
    final body = at < 0 ? part : part.substring(0, at);
    final color = _parseColor(body);
    if (color == null) continue;
    colors.add(color);
    if (at >= 0) {
      final position = double.tryParse(part.substring(at + 1));
      if (position == null) continue;
      stops.add((position / 100).clamp(0.0, 1.0));
    }
  }
  if (colors.length < 2) return fallback;
  final deg = head == null ? _legacyGradientDeg : int.tryParse(head) ?? _legacyGradientDeg;
  return (
    colors: List.unmodifiable(colors),
    stops: stops.length == colors.length ? List.unmodifiable(stops) : null,
    deg: deg,
  );
}

/// The angle a saved gradient without one was painted at.
const int _legacyGradientDeg = 135;

/// The gradient in the form [_parseGradient] reads.
String _encodeGradient(BackgroundSettings value) {
  final colors = value.gradientColors;
  final stops = value.gradientStops;
  final parts = <String>[];
  for (var i = 0; i < colors.length; i++) {
    final position = stops != null && i < stops.length ? '@${(stops[i] * 100).round()}' : '';
    parts.add('${_colorHex(colors[i])}$position');
  }
  return '${value.gradientDeg}|${parts.join(',')}';
}

/// The background choices.
final backgroundSettingsProvider = NotifierProvider<BackgroundSettingsController, BackgroundSettings>(
  BackgroundSettingsController.new,
);
