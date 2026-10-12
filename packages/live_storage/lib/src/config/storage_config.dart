/// Defines shared configuration for the PureLive storage infrastructure.
final class StorageConfig {
  /// Creates a storage configuration.
  const new({this.directoryName = 'pure_live', this.schemaVersion = 1})
    : assert(directoryName != '', 'The storage directory name must not be empty.'),
      assert(schemaVersion > 0, 'The storage schema version must be positive.');

  /// The application-specific storage directory name.
  final String directoryName;

  /// The current storage schema version.
  ///
  /// Increment this value when a storage migration is required.
  final int schemaVersion;

  /// Builds a namespaced box name for a feature.
  ///
  /// Example: `boxName('settings', 'preferences')` returns
  /// `settings.preferences`.
  String boxName(String feature, String name) {
    if (feature.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Feature and box name must not be empty.');
    }

    return '${feature.trim()}.${name.trim()}';
  }
}
