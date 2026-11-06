/// How hard the cache tries to keep an entry.
enum CachePriority {
  /// Cheap to fetch again; evicted before anything else.
  low(0),

  /// The default for ordinary covers and thumbnails.
  normal(1),

  /// Shared, slow or expensive images: avatars, platform icons, channel
  /// logos. Evicted after normal and low entries.
  high(2),

  /// Never expires on its own. Only an explicit clear or a capacity
  /// emergency removes it.
  permanent(3);

  new(this.rank);

  /// Lower ranks are evicted first.
  final int rank;

  /// The value stored in the cache index, falling back to [normal] for an
  /// unknown or missing name.
  static CachePriority fromName(String? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return normal;
  }
}
