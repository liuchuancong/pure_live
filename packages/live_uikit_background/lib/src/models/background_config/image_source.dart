part of 'background_config.dart';

/// Where an [ImageBackground] loads its bytes from.
///
/// Sealed so callers cannot pass a "url and asset" ambiguous source. The
/// concrete variants live in this file because they only ever exist as
/// children of an [ImageBackground]; promoting any of them into its own
/// directory would fragment a single coherent entity across files without
/// adding independent maintainability.
///
/// Deliberately does not include a "file path" variant: reading a local
/// file requires `dart:io` and a policy about missing paths, both of
/// which belong to the caller. Wrap your `FileImage(File(path))` (or a
/// `MemoryImage`, `ResizeImage`, `CachedNetworkImageProvider`, ...) in
/// [ProviderImageSource] to keep this package platform-neutral.
@immutable
sealed class ImageSource {
  /// Marks a background image source.
  const new();
}

/// A network-backed image source.
@immutable
final class NetworkImageSource extends ImageSource {
  /// Loads [url] through the framework image pipeline.
  const new(this.url);

  /// The absolute URL of the image.
  final String url;
}

/// A bundled asset image source.
@immutable
final class AssetImageSource extends ImageSource {
  /// Loads a bundled asset named [name], optionally from [package].
  const new(this.name, {this.package});

  /// The asset path relative to the bundle root.
  final String name;

  /// The package the asset lives in, when it is not the app bundle.
  final String? package;
}

/// A caller-supplied [ImageProvider].
///
/// This is the extension point for anything the built-in variants do
/// not cover: local files, cached network images, memory bytes,
/// resolution-aware providers. The package does not decode, cache or
/// fall back on this provider's behalf; it hands the provider to
/// Flutter's `Image` widget exactly as the caller configured it.
@immutable
final class ProviderImageSource extends ImageSource {
  /// Wraps a pre-built provider.
  const new(this.provider);

  /// The provider used verbatim by the rendering layer.
  final ImageProvider provider;
}
