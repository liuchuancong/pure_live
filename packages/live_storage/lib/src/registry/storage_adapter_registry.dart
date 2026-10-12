/// Registers Hive CE adapters provided by feature packages.
final class StorageAdapterRegistry {
  /// Creates an empty adapter registry.
  new();

  final Map<String, void Function()> _registrars = {};

  bool _registered = false;

  /// Whether all registered adapters have been registered successfully.
  bool get isRegistered => _registered;

  /// Registers an adapter registrar under a unique feature name.
  ///
  /// Registrars must be added before [registerAll] is called.
  void add(String feature, void Function() registrar) {
    if (_registered) {
      throw StateError('Cannot add registrars after registration.');
    }

    final normalizedFeature = feature.trim();

    if (normalizedFeature.isEmpty) {
      throw ArgumentError.value(feature, 'feature', 'Must not be empty.');
    }

    if (_registrars.containsKey(normalizedFeature)) {
      throw StateError(
        'An adapter registrar is already registered for '
        '"$normalizedFeature".',
      );
    }

    _registrars[normalizedFeature] = registrar;
  }

  /// Registers all adapters in insertion order.
  ///
  /// If registration fails, the error is propagated and the registry remains
  /// unregistered. Previously registered adapters are not rolled back.
  /// Registrars should therefore be safe to retry when possible.
  void registerAll() {
    if (_registered) return;

    for (final registrar in _registrars.values) {
      registrar();
    }

    _registered = true;
  }
}
