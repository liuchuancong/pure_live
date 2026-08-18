import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/enums/barcode_type.dart';
import 'package:mobile_scanner/src/objects/barcode.dart';
import 'package:mobile_scanner/src/objects/barcode_bytes.dart';
import 'package:mobile_scanner/src/web/zxing/result_point.dart';

/// The JS static interop class for the Result class in the ZXing library.
///
/// See also: https://github.com/zxing-js/library/blob/master/src/core/Result.ts
@JS()
extension type Result(JSObject _) implements JSObject {
  @JS('barcodeFormat')
  external int? get _barcodeFormat;

  /// Get the text of the result.
  external String? get text;

  @JS('rawBytes')
  external JSUint8Array? get _rawBytes;

  @JS('resultPoints')
  external JSArray<ResultPoint>? get _resultPoints;

  /// Get the timestamp of the result.
  external int? get timestamp;

  /// Get the barcode format of the result.
  ///
  /// See also https://github.com/zxing-js/library/blob/master/src/core/BarcodeFormat.ts
  BarcodeFormat get barcodeFormat {
    return switch (_barcodeFormat) {
      0 => BarcodeFormat.aztec,
      1 => BarcodeFormat.codabar,
      2 => BarcodeFormat.code39,
      3 => BarcodeFormat.code93,
      4 => BarcodeFormat.code128,
      5 => BarcodeFormat.dataMatrix,
      6 => BarcodeFormat.ean8,
      7 => BarcodeFormat.ean13,
      8 => BarcodeFormat.itf,
      9 => BarcodeFormat.maxiCode,
      10 => BarcodeFormat.pdf417,
      11 => BarcodeFormat.qrCode,
      12 => BarcodeFormat.dataBar,
      13 => BarcodeFormat.dataBarExpanded,
      14 => BarcodeFormat.upcA,
      15 => BarcodeFormat.upcE,
      // UPC/EAN extension
      16 => BarcodeFormat.unknown,
      17 => BarcodeFormat.microQrCode,
      _ => BarcodeFormat.unknown,
    };
  }

  /// Get the raw bytes of the result.
  Uint8List? get rawBytes => _rawBytes?.toDart;

  /// Get the corner points of the result, sorted in clockwise order if four
  /// points exist.
  List<Offset> get resultPoints {
    final points = _resultPoints;

    if (points == null || points.length == 0) {
      return const [];
    }

    final pointList =
        points.toDart.map((point) {
          return Offset(point.x, point.y);
        }).toList();

    return processBarcodeCorners(pointList);
  }

  /// Process and sort barcode corners if four points exist.
  /// If only 2 or 3 points are available, attempts to estimate missing points.
  List<Offset> processBarcodeCorners(List<Offset> points) {
    if (points.length == 4) {
      return sortCornersClockwise(points);
    } else if (points.length == 3) {
      return estimateFourthPoint(points);
    } else if (points.length == 2) {
      return estimateRemainingPoints(points);
    }
    return points; // Return original if no special handling is needed.
  }

  /// Sorts four detected points into
  /// [Top-Left, Top-Right, Bottom-Right, Bottom-Left]
  List<Offset> sortCornersClockwise(List<Offset> points) {
    points.sort((a, b) {
      if (a.dy == b.dy) {
        return a.dx.compareTo(b.dx);
      }
      return a.dy.compareTo(b.dy);
    });

    final topLeft = points[3];
    final topRight = points[2];
    final bottomRight = points[1];
    final bottomLeft = points[0];

    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  /// Estimate missing fourth corner when given three points (for QR codes)
  List<Offset> estimateFourthPoint(List<Offset> points) {
    // Assume a parallelogram based on three known points
    final a = points[0];
    final b = points[1];
    final c = points[2];

    // Compute the missing point (approximate)
    final d = Offset(a.dx + (c.dx - b.dx), a.dy + (c.dy - b.dy));

    return sortCornersClockwise([a, b, c, d]);
  }

  /// Estimate remaining corners when only two points are given
  /// (for 1D barcodes)
  List<Offset> estimateRemainingPoints(List<Offset> points) {
    final start = points[0];
    final end = points[1];

    // Approximate barcode height (arbitrary small value for 1D barcodes)
    const double heightOffset = 10;

    final topLeft = Offset(start.dx, start.dy - heightOffset);
    final topRight = Offset(end.dx, end.dy - heightOffset);
    final bottomRight = end;
    final bottomLeft = start;

    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  /// Convert this result to a [Barcode].
  Barcode get toBarcode {
    // The order of the points is dependent on the type of barcode.
    // Don't do a manual correction here, but leave it up to the reader
    // implementation.
    final corners = resultPoints;

    final rawBytesData = rawBytes;

    return Barcode(
      corners: corners,
      format: barcodeFormat,
      displayValue: text,
      // Populate deprecated rawBytes for backward compatibility.
      // ignore: deprecated_member_use_from_same_package
      rawBytes: rawBytesData,
      rawDecodedBytes:
          rawBytesData != null
              ? DecodedBarcodeBytes(bytes: rawBytesData)
              : null,
      rawValue: text,
      size: _computeSize(corners),
      type: BarcodeType.text,
    );
  }

  Size _computeSize(List<Offset> points) {
    if (points.length != 4) {
      return Size.zero;
    }

    final xCoords = points.map((p) => p.dx);
    final yCoords = points.map((p) => p.dy);

    // Find the minimum and maximum x and y coordinates.
    final xMin = xCoords.reduce((a, b) => a < b ? a : b);
    final xMax = xCoords.reduce((a, b) => a > b ? a : b);
    final yMin = yCoords.reduce((a, b) => a < b ? a : b);
    final yMax = yCoords.reduce((a, b) => a > b ? a : b);

    return Size(xMax - xMin, yMax - yMin);
  }
}
