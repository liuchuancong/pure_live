/// The kind of backing an asset reference points at.
enum LiveAssetType {
  /// Shipped inside the application bundle, addressed by a package path.
  bundled,

  /// Fetched over the network, addressed by a URI.
  remote,

  /// A platform-supplied default used when nothing better is available.
  platformDefault,
}
