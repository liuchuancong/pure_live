import 'dart:io';

import 'hls_retained_window.dart';

/// Small replayable metadata for one complete, exact prefetch identity.
/// This is a cache admission rule, not a general HTTP response validator:
/// an origin may legally ignore Range, but that full body is not this range.
final class HlsHttpBodyMetadata {
  HlsHttpBodyMetadata._(this.statusCode, this.expectedLength, this.contentType, this.contentRange, this.acceptRanges);
  final int statusCode;
  final int expectedLength;
  final String? contentType;
  final String? contentRange;
  final String? acceptRanges;

  static void validateRequestRange(HlsSegmentRange? range) {
    if (range != null && (range.offset < 0 || range.length <= 0 || range.offset > 0x7fffffffffffffff - range.length)) {
      throw const FormatException('Invalid prefetch byte range');
    }
  }

  factory HlsHttpBodyMetadata.fromResponse(HttpClientResponse response, {HlsSegmentRange? requestedRange}) {
    return HlsHttpBodyMetadata.validate(
      statusCode: response.statusCode,
      contentLength: response.contentLength,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      contentRange: response.headers.value(HttpHeaders.contentRangeHeader),
      acceptRanges: response.headers.value(HttpHeaders.acceptRangesHeader),
      contentEncoding: response.headers.value(HttpHeaders.contentEncodingHeader),
      decompressed: response.compressionState == HttpClientResponseCompressionState.decompressed,
      requestedRange: requestedRange,
    );
  }

  factory HlsHttpBodyMetadata.validate({
    required int statusCode,
    required int contentLength,
    String? contentType,
    String? contentRange,
    String? acceptRanges,
    String? contentEncoding,
    bool decompressed = false,
    HlsSegmentRange? requestedRange,
  }) {
    validateRequestRange(requestedRange);
    for (final entry in [(contentType, 4096), (contentRange, 128), (acceptRanges, 256), (contentEncoding, 128)]) {
      final value = entry.$1;
      if (value != null && (value.length > entry.$2 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(value))) {
        throw const FormatException('Invalid prefetch response metadata');
      }
    }
    if (contentLength < -1) throw const FormatException('Invalid prefetch content length');
    final encoded = contentEncoding != null && contentEncoding.toLowerCase() != 'identity';
    if ((encoded && !decompressed) || (requestedRange != null && (encoded || decompressed))) {
      throw const FormatException('Encoded response does not match prefetch byte identity');
    }
    if (requestedRange == null) {
      if (statusCode != HttpStatus.ok || contentRange != null) {
        throw const FormatException('Prefetch requires a complete resource response');
      }
      return HlsHttpBodyMetadata._(statusCode, decompressed ? -1 : contentLength, contentType, null, acceptRanges);
    }
    final match = RegExp(
      r'^bytes (\d{1,19})-(\d{1,19})/(\d{1,19}|\*)$',
      caseSensitive: false,
    ).firstMatch(contentRange ?? '');
    final start = match == null ? null : int.tryParse(match.group(1)!);
    final end = match == null ? null : int.tryParse(match.group(2)!);
    final total = match == null || match.group(3) == '*' ? null : int.tryParse(match.group(3)!);
    if (statusCode != HttpStatus.partialContent ||
        match == null ||
        start == null ||
        end == null ||
        start != requestedRange.offset ||
        end != requestedRange.offset + requestedRange.length - 1 ||
        (match.group(3) != '*' && (total == null || total <= end)) ||
        (contentLength != -1 && contentLength != requestedRange.length)) {
      throw const FormatException('Prefetch Content-Range differs from the requested bytes');
    }
    return HlsHttpBodyMetadata._(statusCode, requestedRange.length, contentType, contentRange, acceptRanges);
  }
}
