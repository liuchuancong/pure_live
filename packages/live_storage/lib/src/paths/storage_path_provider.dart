/// Resolves the storage directory configured by the application.
typedef StoragePathResolver = Future<String> Function();

/// Provides the application-configured storage directory.
final class StoragePathProvider {
  /// Creates a storage path provider.
  const new({required this.resolver});

  /// Resolves the application-configured storage directory.
  final StoragePathResolver resolver;

  /// Returns the configured storage directory.
  Future<String> getStoragePath() async {
    final path = (await resolver()).trim();

    if (path.isEmpty) {
      throw StateError('The storage path resolver returned an empty path.');
    }

    return path;
  }
}
