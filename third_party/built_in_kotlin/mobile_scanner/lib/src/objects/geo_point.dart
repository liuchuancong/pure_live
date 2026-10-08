/// GPS coordinates from a `GEO:` or similar QRCode type.
class GeoPoint {
  /// Construct a new [GeoPoint] instance.
  const GeoPoint({required this.latitude, required this.longitude});

  /// Construct a [GeoPoint] from the given [data].
  ///
  /// If the data does not contain valid GeoPoint coordinates,
  /// then `0,0` is returned.
  factory GeoPoint.fromNative(Map<Object?, Object?> data) {
    final latitude = data['latitude'] as double?;
    final longitude = data['longitude'] as double?;

    // If either is not set, then this GeoPoint is invalid.
    // Return the geographic center as fallback.
    if (latitude == null || longitude == null) {
      return const GeoPoint(latitude: 0, longitude: 0);
    }

    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  /// The latitude of the coordinate.
  final double latitude;

  /// The longitude of the coordinate.
  final double longitude;
}
