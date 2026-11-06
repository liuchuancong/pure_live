/// Where a resolved image came from.
enum CacheSource {
  /// Flutter's decoded-image cache answered without a disk or network read.
  memory,

  /// The disk cache held the bytes.
  disk,

  /// The loader fetched the bytes over the network.
  network,
}
