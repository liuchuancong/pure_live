/// Defines shared configuration for the storage infrastructure.
final class StorageConfig {
  /// Creates a storage configuration.
  ///
  /// [directoryName] is the host application's namespace — the app
  /// supplies its own identity; this reusable package names no product
  /// itself.
  const new({required this.directoryName, this.schemaVersion = 1})
    : assert(directoryName != '', 'The storage directory name must not be empty.'),
      assert(schemaVersion > 0, 'The storage schema version must be positive.');

  /// The application-specific storage directory name, supplied by the
  /// host application.
  final String directoryName;

  /// The current storage schema version.
  ///
  /// Increment this value when a storage migration is required.
  final int schemaVersion;

  /// Builds a namespaced store name for a feature.
  ///
  /// Example: `namespaceName('settings', 'preferences')` returns
  /// `settings.preferences`.
  String namespaceName(String feature, String name) {
    if (feature.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Feature and namespace name must not be empty.');
    }

    return '${feature.trim()}.${name.trim()}';
  }
}
