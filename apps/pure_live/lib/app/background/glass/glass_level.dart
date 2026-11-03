/// The frost radius a layer wears, as named rungs of the glass ladder.
///
/// Features never write a sigma of their own: they ask for the rung the
/// surface belongs to and the policy decides whether the device may frost at
/// all. `solid` and `isolated` carry no frost — the first is the glass off,
/// the second a near-solid layer stacked over another.
enum LiveGlassLevel {
  solid(blurSigma: 0),
  subtle(blurSigma: 8),
  standard(blurSigma: 16),
  strong(blurSigma: 22),
  isolated(blurSigma: 0);

  LiveGlassLevel({required this.blurSigma});

  /// The frost radius at full strength.
  final double blurSigma;
}
