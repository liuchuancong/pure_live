import 'dart:async' show unawaited;
import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart' show FilePicker, FileType, PlatformFile;
import 'package:flutter/painting.dart' show BoxFit, Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/background/background_presets.dart';
import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;

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
    this.fit = BoxFit.cover,
    this.maskOpacity = 0.45,
    this.blurSigma = 0,
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

  final BoxFit fit;
  final double maskOpacity;
  final double blurSigma;

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
    BoxFit? fit,
    double? maskOpacity,
    double? blurSigma,
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
    fit: fit ?? this.fit,
    maskOpacity: maskOpacity ?? this.maskOpacity,
    blurSigma: blurSigma ?? this.blurSigma,
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
  static const _blurKey = 'background.blur';

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
      return BackgroundSettings(
        kind: kind,
        imageUrl: StoragePrefs.getString(_imageUrlKey) ?? '',
        imagePath: StoragePrefs.getString(_imagePathKey) ?? '',
        videoUrl: StoragePrefs.getString(_videoUrlKey) ?? '',
        videoPath: StoragePrefs.getString(_videoPathKey) ?? '',
        solidColor: _parseColor(StoragePrefs.getString(_solidKey)) ?? const Color(0xFF141E30),
        gradientColors:
            _parseGradient(StoragePrefs.getString(_gradientKey)) ?? const [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
        fit: fit,
        maskOpacity: (StoragePrefs.getDouble(_maskKey) ?? 0.45).clamp(0.0, 0.8),
        blurSigma: (StoragePrefs.getDouble(_blurKey) ?? 0).clamp(0.0, 40.0),
      );
    } on Object {
      // Storage never opened: the defaults stand.
      return const BackgroundSettings();
    }
  }

  /// Paints [kind] behind the pages, source or not.
  void selectKind(BackgroundKind kind) => _update(
    state.copyWith(
      kind: kind,
      gradientColors: kind == BackgroundKind.gradient && state.gradientColors.length < 2
          ? kDefaultBackgroundGradient
          : state.gradientColors,
      error: '',
    ),
  );

  /// Uses [color] as the flat fill (and switches to the solid kind).
  void setSolid(Color color) => _update(state.copyWith(kind: BackgroundKind.solid, solidColor: color, error: ''));

  /// Uses [colors] as the gradient (and switches to the gradient kind).
  void setGradient(List<Color> colors) {
    if (colors.length < 2) return;
    _update(state.copyWith(kind: BackgroundKind.gradient, gradientColors: List.unmodifiable(colors), error: ''));
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

  void setBlurSigma(double sigma) => _update(state.copyWith(blurSigma: sigma.clamp(0.0, 40.0)));

  /// Back to the theme's surface; the saved media stays for a reselect.
  void clear() => _update(state.copyWith(kind: BackgroundKind.none, error: ''));

  /// Opens the picker and copies an image into the data area.
  Future<void> uploadImage({required String dialogTitle}) async {
    final file = await FilePicker.pickFile(dialogTitle: dialogTitle, type: FileType.image);
    if (file == null) return;
    final previous = state.imagePath;
    await _import(
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
    await _import(
      file,
      prefix: 'background-video',
      onDone: (path) => state.copyWith(kind: BackgroundKind.video, videoPath: path, videoUrl: ''),
    );
    if (!ref.mounted || state.error.isNotEmpty) return;
    unawaited(_delete(previous));
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

  Future<void> _import(
    PlatformFile file, {
    required String prefix,
    required BackgroundSettings Function(String path) onDone,
  }) async {
    state = state.copyWith(busy: true, error: '');
    File? target;
    try {
      final paths = ref.read(storagePathsProvider);
      final directory = Directory(p.join(paths.data.path, 'background'));
      await directory.create(recursive: true);
      final extension = file.extension;
      final suffix = extension != null && extension.isNotEmpty ? '.$extension' : '';
      target = File(p.join(directory.path, '$prefix-${DateTime.now().microsecondsSinceEpoch}$suffix'));
      final sourcePath = file.path;
      if (sourcePath != null && sourcePath.isNotEmpty) {
        await File(sourcePath).copy(target.path);
      } else {
        final sink = target.openWrite();
        try {
          await file.readAsByteStream().forEach(sink.add);
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
        _gradientKey: value.gradientColors.map(_colorHex).join(','),
        _fitKey: value.fit.name,
        _maskKey: value.maskOpacity,
        _blurKey: value.blurSigma,
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

List<Color>? _parseGradient(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final colors = [for (final part in text.split(',')) ?_parseColor(part.trim())];
  return colors.length >= 2 ? colors : null;
}

/// The background choices.
final backgroundSettingsProvider = NotifierProvider<BackgroundSettingsController, BackgroundSettings>(
  BackgroundSettingsController.new,
);
