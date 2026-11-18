/// One rate's word, everywhere a rate is named — the bar's picker, the
/// menu's rows, the gesture's note. The number sheds its trailing zeros
/// and reads with the multiplication sign, the mark the letter x never
/// earned: 1×, 0.5×, 1.25×.
String playerRateLabel(double rate) {
  final text = rate.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text×';
}
