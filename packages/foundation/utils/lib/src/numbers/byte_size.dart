// Module: lib/src/numbers/byte_size.dart
// Purpose: A byte count that names its own unit, so a limit reads as a limit instead of a magic number.
// Author: liuchuancong
// Created: 2026-10-10
//
// Measured duplication: cache policies, sandbox quotas, response caps and disk tiers each write
// `64 * 1024 * 1024`, and the readers of those constants cannot tell a bytes limit from a characters limit
// without opening the declaration. Units here are binary (KiB/MiB), which is what those limits have always
// meant; a decimal reading of the same number would silently shrink every cache in the app.

/// An immutable byte count.
final class ByteSize implements Comparable<ByteSize> {
  const ByteSize(this.bytes);

  /// Zero bytes, the identity for a limit that has not been used.
  static const ByteSize zero = ByteSize(0);

  static const int _kib = 1024;
  static const int _mib = _kib * 1024;
  static const int _gib = _mib * 1024;

  static const ByteSize kilobyte = ByteSize(_kib);
  static const ByteSize megabyte = ByteSize(_mib);
  static const ByteSize gigabyte = ByteSize(_gib);

  /// [count] kilobytes.
  static ByteSize kib(int count) => ByteSize(count * _kib);

  /// [count] megabytes.
  static ByteSize mib(int count) => ByteSize(count * _mib);

  /// [count] gigabytes.
  static ByteSize gib(int count) => ByteSize(count * _gib);

  /// The raw count.
  final int bytes;

  bool get isZero => bytes == 0;

  /// True when this size fits inside [limit]; equal counts fit, since a limit is inclusive here.
  bool fitsWithin(ByteSize limit) => bytes <= limit.bytes;

  ByteSize operator +(ByteSize other) => ByteSize(bytes + other.bytes);

  ByteSize operator -(ByteSize other) => ByteSize(bytes - other.bytes);

  /// A human-readable form, e.g. `1.5 MiB`, for diagnostics and the backup report.
  String get humanReadable {
    if (bytes >= _gib) {
      return '${(bytes / _gib).toStringAsFixed(1)} GiB';
    }
    if (bytes >= _mib) {
      return '${(bytes / _mib).toStringAsFixed(1)} MiB';
    }
    if (bytes >= _kib) {
      return '${(bytes / _kib).toStringAsFixed(1)} KiB';
    }
    return '$bytes B';
  }

  @override
  int compareTo(ByteSize other) => bytes.compareTo(other.bytes);

  @override
  bool operator ==(Object other) => other is ByteSize && other.bytes == bytes;

  @override
  int get hashCode => bytes.hashCode;

  @override
  String toString() => humanReadable;
}
