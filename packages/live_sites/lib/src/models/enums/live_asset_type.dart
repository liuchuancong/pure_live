/// How a referenced asset (icon, image) is delivered.
enum LiveAssetType {
  /// Bundled with the package, addressed by a package-relative path.
  bundled,

  /// Fetched from the network, addressed by [LiveAssetType] provider data.
  remote,

  /// No asset provided; the application shows its platform-default icon.
  platformDefault,
}
