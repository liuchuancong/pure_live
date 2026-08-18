/// @docImport 'package:mobile_scanner/src/mobile_scanner_controller.dart';
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:mobile_scanner/src/objects/barcode.dart';

/// This class represents a scanned barcode.
class BarcodeCapture {
  /// Create a new [BarcodeCapture] instance.
  const BarcodeCapture({
    this.barcodes = const <Barcode>[],
    this.image,
    this.raw,
    this.size = Size.zero,
  });

  /// The list of scanned barcodes.
  final List<Barcode> barcodes;

  /// The input image of the barcode capture.
  ///
  /// This is the image that was used to detect the available [barcodes],
  /// not the image from a specific barcode.
  ///
  /// This is always null if [MobileScannerController.returnImage] is false.
  final Uint8List? image;

  /// The raw data of the barcode scan.
  ///
  /// This is the data that was used to detect the available [barcodes], the
  /// input [image] and the [size].
  final Object? raw;

  /// The raw size of the camera input [image],
  /// in which the [barcodes] were detected.
  ///
  /// For example if the camera resolution is 1920x1080 pixels,
  /// this will be a [Size] with a width of 1920 and a height of 1080.
  final Size size;
}
