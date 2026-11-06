import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:live_cache/src/image/image_cache_policy.dart';
import 'package:live_cache/src/image/image_request.dart';
import 'package:live_cache/src/image/live_image_cache.dart';

/// An [ImageProvider] over [LiveImageCache].
///
/// The provider's identity is the request's business identity (an explicit
/// key or the URL), the category and version, the decode box and the scale.
/// Signed query rotations therefore share one decoded image when the caller
/// supplied a stable key, and a decode-size change gets its own entry.
@immutable
final class LiveCacheImage extends ImageProvider<LiveCacheImage> {
  /// Creates a provider for [request], decoding at [width]×[height] when the
  /// caller asked for a box.
  const new({required this.cache, required this.request, this.width, this.height, this.scale = 1.0});

  /// The cache this provider reads through.
  final LiveImageCache cache;

  /// The business request, including its policy.
  final ImageCacheRequest request;

  /// The decode box's width, or null to decode at the source size.
  final int? width;

  /// The decode box's height, or null to decode at the source size.
  final int? height;

  /// The device-pixel scale, part of the framework's identity.
  final double scale;

  @override
  Future<LiveCacheImage> obtainKey(ImageConfiguration configuration) {
    cache.noteObtain();
    if (request.policy.memoryCache) {
      cache.memory.register(request.categorySlug, this);
    }
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(LiveCacheImage key, ImageDecoderCallback decode) {
    cache.noteLoad();
    final completer = _CacheImageCompleter(
      scale: key.scale,
      debugLabel: 'LiveCacheImage(${key.request.policy.category})',
    );
    unawaited(_pump(key, decode, completer));
    return completer;
  }

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    LiveCacheImage key,
    ImageErrorListener handleError,
  ) {
    if (key.request.policy.memoryCache) {
      super.resolveStreamForKey(configuration, stream, key, handleError);
      return;
    }
    // The policy asked for no decoded copy: hand the stream a completer the
    // framework's ImageCache never stores.
    try {
      stream.setCompleter(loadImage(key, PaintingBinding.instance.instantiateImageCodecWithSize));
    } on Object catch (error, stack) {
      handleError(error, stack);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveCacheImage &&
          other.cache == cache &&
          other.request.categorySlug == request.categorySlug &&
          other.request.identity == request.identity &&
          other.request.effectiveVersion == request.effectiveVersion &&
          other.request.accountScope == request.accountScope &&
          other.width == width &&
          other.height == height &&
          other.scale == scale &&
          mapEquals(other.request.headers, request.headers);

  @override
  int get hashCode => Object.hash(
    cache,
    request.categorySlug,
    request.identity,
    request.effectiveVersion,
    request.accountScope,
    width,
    height,
    scale,
    Object.hashAll(request.headers.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );

  @override
  String toString() => 'LiveCacheImage(${request.policy.category}, ${request.identity})';

  Future<void> _pump(LiveCacheImage key, ImageDecoderCallback decode, _CacheImageCompleter completer) async {
    try {
      final result = await key.cache.resolve(key.request);
      await _show(result.bytes, key, decode, completer);
      if (result.isStale && key.request.policy.mode == ImageExpiryMode.staleWhileRevalidate) {
        unawaited(_refresh(key, decode, completer));
      }
    } on Object catch (error, stack) {
      completer.fail(error, stack);
    }
  }

  Future<void> _refresh(LiveCacheImage key, ImageDecoderCallback decode, _CacheImageCompleter completer) async {
    try {
      final fresh = await key.cache.refresh(key.request);
      if (fresh == null) {
        return;
      }
      await _show(fresh.bytes, key, decode, completer);
    } on Object {
      // A refresh failure keeps the stale picture; the policy already
      // decided that a visible old image beats an error box.
    }
  }

  Future<void> _show(
    Uint8List bytes,
    LiveCacheImage key,
    ImageDecoderCallback decode,
    _CacheImageCompleter completer,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    // A resizing wrapper (`ResizeImage`, the design kit's cover image) hands
    // this provider a decode callback that refuses a second `getTargetSize`,
    // so the callback is only used when the caller asked for no box of its
    // own; with a box the provider decodes at that size itself.
    final codec = key.width == null && key.height == null
        ? await decode(buffer)
        : await ui.instantiateImageCodecWithSize(
            buffer,
            getTargetSize: (intrinsicWidth, intrinsicHeight) {
              var targetWidth = key.width;
              var targetHeight = key.height;
              if (targetWidth != null && targetWidth > intrinsicWidth) {
                targetWidth = intrinsicWidth;
              }
              if (targetHeight != null && targetHeight > intrinsicHeight) {
                targetHeight = intrinsicHeight;
              }
              return ui.TargetImageSize(width: targetWidth, height: targetHeight);
            },
          );
    if (codec.frameCount > 1) {
      // Flutter's own multi-frame completer owns the codec's lifetime and
      // frame clock; this stream only forwards its images.
      completer.play(codec);
      return;
    }
    try {
      final frame = await codec.getNextFrame();
      final info = ImageInfo(image: frame.image, scale: key.scale);
      completer.emitStatic(info);
      // One enormous picture is drawn but not kept: retaining it would push
      // every thumbnail out of the decoded-image budget.
      if (info.sizeBytes > key.cache.config.image.maxMemoryEntryBytes) {
        key.cache.memory.evict(key);
      }
    } finally {
      codec.dispose();
    }
  }
}

/// An image stream that can draw a second, fresher image over the first.
///
/// Static images are emitted directly, so a stale-while-revalidate refresh
/// replaces the picture in place. Multi-frame images delegate to Flutter's
/// [MultiFrameImageStreamCompleter], which owns the frame clock: this stream
/// forwards its frames while anybody is watching, and detaches when the last
/// watcher leaves so the animation pauses instead of burning frames.
///
/// Emitting does not wait for a listener. `loadImage` runs before the widget
/// attaches its own listener, and the framework's image cache holds a
/// keep-alive on the completer until the first frame lands — the same contract
/// `OneFrameImageStreamCompleter` relies on.
final class _CacheImageCompleter extends ImageStreamCompleter {
  new({required this.scale, String? debugLabel}) {
    this.debugLabel = debugLabel;
  }

  final double scale;

  MultiFrameImageStreamCompleter? _animation;
  ImageStreamListener? _forwarder;
  bool _forwarding = false;

  /// Draws one decoded image, replacing any earlier frame sequence.
  void emitStatic(ImageInfo info) {
    _stopAnimation();
    try {
      setImage(info);
      // The framework reports a disposed stream by throwing a StateError from
      // an assert; there is no Exception to catch and the frame has nowhere
      // to go, so the picture is released here instead.
      // ignore: avoid_catching_errors
    } on StateError {
      info.dispose();
    }
  }

  /// Starts a multi-frame sequence, replacing any earlier one.
  void play(ui.Codec codec) {
    _stopAnimation();
    _animation = MultiFrameImageStreamCompleter(
      codec: Future<ui.Codec>.value(codec),
      scale: scale,
      debugLabel: debugLabel,
    );
    _forwarder = ImageStreamListener((info, synchronousCall) => setImage(info));
    if (hasListeners) {
      _attach();
    }
  }

  /// Reports a load failure to the image listener.
  void fail(Object error, StackTrace stack) {
    reportError(
      context: ErrorDescription('while loading an image through the disk cache'),
      exception: error,
      stack: stack,
      silent: true,
    );
  }

  @override
  void addListener(ImageStreamListener listener) {
    final wasIdle = !hasListeners;
    super.addListener(listener);
    if (wasIdle) {
      _attach();
    }
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _detach();
    }
  }

  void _attach() {
    final animation = _animation;
    final forwarder = _forwarder;
    if (animation == null || forwarder == null || _forwarding) {
      return;
    }
    animation.addListener(forwarder);
    _forwarding = true;
  }

  void _detach() {
    final animation = _animation;
    final forwarder = _forwarder;
    if (animation == null || forwarder == null || !_forwarding) {
      return;
    }
    animation.removeListener(forwarder);
    _forwarding = false;
  }

  void _stopAnimation() {
    _detach();
    _animation = null;
    _forwarder = null;
  }
}
