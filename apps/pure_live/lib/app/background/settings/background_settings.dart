import 'dart:async' show unawaited;
import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart' show FilePicker, FileType, PlatformFile;
import 'package:flutter/painting.dart' show BoxFit, Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/background/library/background_presets.dart';
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
    this.maskOpacity = 0.45,
    this.overlayBlurSigma = 0,
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
  final double maskOpacity;

  /// Gaussian sigma of the frosted scrim: what the mask blurs behind it,
  /// so the pages read over any background. 0 keeps the flat wash.
  final double overlayBlurSigma;

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
    double? maskOpacity,
    double? overlayBlurSigma,
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
    maskOpacity: maskOpacity ?? this.maskOpacity,
    overlayBlurSigma: overlayBlurSigma ?? this.overlayBlurSigma,
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
  static const _maskKey = 'background.mask';
  static const _overlayBlurKey = 'background.overlayBlur';

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
        maskOpacity: (StoragePrefs.getDouble(_maskKey) ?? 0.45).clamp(0.0, 0.8),
        overlayBlurSigma: (StoragePrefs.getDouble(_overlayBlurKey) ?? 0).clamp(0.0, 24.0),
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

  void setMaskOpacity(double opacity) => _update(state.copyWith(maskOpacity: opacity.clamp(0.0, 0.8)));

  /// How frosted the scrim is: the mask stops being a flat wash and blurs
  /// the background behind it. Capped lower than the media blur, which is
  /// a one-off paint cost; this one runs on the backdrop every frame.
  void setOverlayBlurSigma(double sigma) => _update(state.copyWith(overlayBlurSigma: sigma.clamp(0.0, 24.0)));

  /// Back to the theme's surface; the saved media stays for a reselect.
  void clear() => _update(state.copyWith(kind: BackgroundKind.none, error: ''));

  /// Opens the picker and copies an image into the data area.
  Future<void> uploadImage({required String dialogTitle}) async {
    final file = await FilePicker.pickFile(dialogTitle: dialogTitle, type: FileType.image);
    if (file == null) return;
    final previous = state.imagePath;
    await _importPicked(
      file,
      prefix: 'background-image',
      onDone: (path) => state.copyWith(kind: BackgroundKind.image, imagePath: path, imageUrl: ''),
    );
    if (!ref.mounted || state.error.isNotEmpty) return;
    unawaited(_delete(previous));
  }

  /// Opens the picker and copies a video into the data area.
  Future<void> uploadVideo({required String dialogTitle}) async {
    final file = await FilePicker.pickFile(dialogTitle: dialogTitle, type: FileType.video);
    if (file == null) return;
    final previous = state.videoPath;
    await _importPicked(
      file,
      prefix: 'background-video',
      onDone: (path) => state.copyWith(kind: BackgroundKind.video, videoPath: path, videoUrl: ''),
    );
    if (!ref.mounted || state.error.isNotEmpty) return;
    unawaited(_delete(previous));
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
    } on Object catch (error) {
      if (target != null) await _delete(target.path);
      if (!ref.mounted) return;
      state = state.copyWith(busy: false, error: '$error');
    }
  }

  Future<void> _delete(String path) async {
    if (path.isEmpty) return;
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
        _maskKey: value.maskOpacity,
        _overlayBlurKey: value.overlayBlurSigma,
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
