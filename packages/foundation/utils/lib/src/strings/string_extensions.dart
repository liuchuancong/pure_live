// Module: lib/src/strings/string_extensions.dart
// Purpose: The per-string reads every layer repeats: blank-or-absent, whitespace-folded, shortened.
// Author: liuchuancong
// Created: 2026-10-08

import 'string_truncator.dart';

extension StringExtras on String {
  /// The string itself, or null when it is empty or only whitespace.
  ///
  /// Several protocols send an empty field instead of omitting it; treating that as absent keeps the model
  /// meaning of null - the protocol did not say - intact.
  String? get nullIfBlank => trim().isEmpty ? null : this;

  /// Collapses runs of whitespace to single spaces and trims the ends.
  String get collapsedWhitespace => trim().replaceAll(RegExp(r'\s+'), ' ');

  /// True when this string holds nothing but whitespace.
  bool get isBlank => trim().isEmpty;

  /// Shortens to [maxLength] with a trailing ellipsis, leaving short input untouched.
  ///
  /// Prefer [Truncator.at] when the text is user content: this cut is by code unit and can split a
  /// surrogate pair or land mid-word.
  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (maxLength <= 0 || length <= maxLength) {
      return this;
    }
    final keep = maxLength - ellipsis.length;
    if (keep <= 0) {
      return substring(0, maxLength);
    }
    return '${substring(0, keep)}$ellipsis';
  }
}
