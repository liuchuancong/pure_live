// Module: lib/src/plural_math.dart
// Purpose: The CLDR plural operands, computed from a displayed number so the rules can be written as published.
// Author: liuchuancong
// Created: 2026-10-11
//
// Plural rules in CLDR are stated over operands (n, i, v, w, f, t, e), not over an integer. Taking an
// `int count` only would silently mis-render `1.0 kg`, `2,5` and `1e3`, which is why the operand object
// exists rather than a modulo at each call site.

/// The operands one displayed number yields, in CLDR's names.
final class PluralOperands {
  const PluralOperands({
    required this.n,
    required this.i,
    required this.v,
    required this.w,
    required this.f,
    required this.t,
    this.e,
  });

  /// Parses a number as it will be shown. [decimals] is the number of fraction digits the caller formats with,
  /// so "1.0 items" and "1 items" get different operands even though they are the same value.
  factory PluralOperands.of(num number, {int? decimals}) {
    final rendered = decimals == null ? _plain(number) : number.toStringAsFixed(decimals);
    final lower = rendered.toLowerCase();
    int? exponent;
    var mantissa = lower;
    final marker = lower.indexOf('e');
    if (marker >= 0) {
      exponent = int.tryParse(lower.substring(marker + 1));
      mantissa = lower.substring(0, marker);
    }
    final dot = mantissa.indexOf('.');
    final integerText = dot < 0 ? mantissa : mantissa.substring(0, dot);
    final fractionText = dot < 0 ? '' : mantissa.substring(dot + 1);
    final trimmed = fractionText.replaceAll(RegExp(r'0+$'), '');
    return PluralOperands(
      n: number,
      i: int.tryParse(integerText.replaceAll('_', '')) ?? number.truncate(),
      v: fractionText.length,
      w: trimmed.length,
      f: trimmed.isEmpty ? 0 : int.parse(trimmed),
      t: trimmed.isEmpty ? 0 : int.parse(trimmed.replaceAll(RegExp(r'^0+'), '')),
      e: exponent,
    );
  }

  /// The absolute value being pluralised.
  final num n;

  /// The integer part of absolute n.
  final int i;

  /// The number of visible fraction digits, with trailing zeros.
  final int v;

  /// The number of visible fraction digits, without trailing zeros.
  final int w;

  /// The visible fraction digits as an integer, without trailing zeros.
  final int f;

  /// The value of f with leading zeros stripped, which is what a few rules compare against zero.
  final int t;

  /// The exponent, when the number was written in scientific notation.
  final int? e;

  static String _plain(num value) {
    if (value is int) {
      return value.toString();
    }
    final asDouble = value.toDouble();
    if (asDouble == asDouble.roundToDouble() && asDouble.abs() < 1e15) {
      return asDouble.toStringAsFixed(1);
    }
    return value.toString();
  }

  @override
  String toString() => 'PluralOperands(i $i, v $v, w $w, f $f, t $t${e == null ? '' : ', e $e'})';
}
