bool audioOnlyStopsVideoDecoding({required bool entering, required bool stopVideoDecoding}) {
  return !entering || stopVideoDecoding;
}
