/// @docImport 'package:mobile_scanner/src/objects/barcode_capture.dart';
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:mobile_scanner/src/enums/barcode_format.dart';
import 'package:mobile_scanner/src/enums/barcode_type.dart';
import 'package:mobile_scanner/src/objects/barcode_bytes.dart';
import 'package:mobile_scanner/src/objects/calendar_event.dart';
import 'package:mobile_scanner/src/objects/contact_info.dart';
import 'package:mobile_scanner/src/objects/driver_license.dart';
import 'package:mobile_scanner/src/objects/email.dart';
import 'package:mobile_scanner/src/objects/geo_point.dart';
import 'package:mobile_scanner/src/objects/phone.dart';
import 'package:mobile_scanner/src/objects/sms.dart';
import 'package:mobile_scanner/src/objects/url_bookmark.dart';
import 'package:mobile_scanner/src/objects/wifi.dart';

/// Represents a single recognized barcode and its value.
class Barcode {
  /// Creates a new [Barcode] instance.
  const Barcode({
    this.calendarEvent,
    this.contactInfo,
    this.corners = const <Offset>[],
    this.displayValue,
    this.driverLicense,
    this.email,
    this.format = BarcodeFormat.unknown,
    this.geoPoint,
    this.phone,
    @Deprecated('Use rawDecodedBytes instead.') this.rawBytes,
    this.rawDecodedBytes,
    this.rawValue,
    this.size = Size.zero,
    this.sms,
    this.type = BarcodeType.unknown,
    this.url,
    this.wifi,
  });

  /// Creates a new [Barcode] instance from the given [data].
  factory Barcode.fromNative(Map<Object?, Object?> data) {
    final calendarEvent = data['calendarEvent'] as Map<Object?, Object?>?;
    final contactInfo = data['contactInfo'] as Map<Object?, Object?>?;
    final corners = data['corners'] as List<Object?>?;
    final driverLicense = data['driverLicense'] as Map<Object?, Object?>?;
    final email = data['email'] as Map<Object?, Object?>?;
    final geoPoint = data['geoPoint'] as Map<Object?, Object?>?;
    final phone = data['phone'] as Map<Object?, Object?>?;
    final sms = data['sms'] as Map<Object?, Object?>?;
    final size = data['size'] as Map<Object?, Object?>?;
    final url = data['url'] as Map<Object?, Object?>?;
    final wifi = data['wifi'] as Map<Object?, Object?>?;

    final barcodeWidth = size?['width'] as double?;
    final barcodeHeight = size?['height'] as double?;

    final rawBytesData = data['rawBytes'] as Uint8List?;
    final rawPayloadData = data['rawPayloadData'] as Uint8List?;

    final BarcodeBytes? rawDecodedBytes;
    if (rawPayloadData != null) {
      rawDecodedBytes = DecodedVisionBarcodeBytes(
        bytes: rawBytesData,
        rawBytes: rawPayloadData,
      );
    } else if (rawBytesData != null) {
      rawDecodedBytes = DecodedBarcodeBytes(bytes: rawBytesData);
    } else {
      rawDecodedBytes = null;
    }

    return Barcode(
      calendarEvent:
          calendarEvent == null
              ? null
              : CalendarEvent.fromNative(calendarEvent),
      contactInfo:
          contactInfo == null ? null : ContactInfo.fromNative(contactInfo),
      corners:
          corners == null
              ? const <Offset>[]
              : List.unmodifiable(
                corners.cast<Map<Object?, Object?>>().map((
                  e,
                ) {
                  final x = e['x']! as double;
                  final y = e['y']! as double;

                  return Offset(x, y);
                }),
              ),
      displayValue: data['displayValue'] as String?,
      driverLicense:
          driverLicense == null
              ? null
              : DriverLicense.fromNative(driverLicense),
      email: email == null ? null : Email.fromNative(email),
      format: BarcodeFormat.fromRawValue(data['format'] as int? ?? -1),
      geoPoint: geoPoint == null ? null : GeoPoint.fromNative(geoPoint),
      phone: phone == null ? null : Phone.fromNative(phone),
      // Populate deprecated rawBytes for backward compatibility.
      // ignore: deprecated_member_use_from_same_package
      rawBytes: rawBytesData,
      rawDecodedBytes: rawDecodedBytes,
      rawValue: data['rawValue'] as String?,
      size:
          barcodeWidth == null || barcodeHeight == null
              ? Size.zero
              : Size(barcodeWidth, barcodeHeight),
      sms: sms == null ? null : SMS.fromNative(sms),
      type: BarcodeType.fromRawValue(data['type'] as int? ?? 0),
      url: url == null ? null : UrlBookmark.fromNative(url),
      wifi: wifi == null ? null : WiFi.fromNative(wifi),
    );
  }

  /// The calendar event that is embedded in the barcode.
  final CalendarEvent? calendarEvent;

  /// The contact information that is embedded in the barcode.
  final ContactInfo? contactInfo;

  /// The corner points of the barcode, relative to the [size] of the barcode.
  ///
  /// On Android, iOS and MacOS, this is a list of four points,
  /// in clockwise direction, starting with the top left.
  ///
  /// On the web, the amount of points and their order
  /// is dependent on the type of barcode that was detected.
  ///
  /// Due to the possible perspective distortions,
  /// the points do not necessarily form a rectangle.
  ///
  /// This list is empty if the corners can not be determined.
  ///
  /// See also [scaleCorners], to scale the corners to a different size.
  final List<Offset> corners;

  /// The barcode value in a user-friendly format.
  ///
  /// This value may omit some of the information encoded in the barcode.
  /// For example, if [rawValue] returns `MEBKM:TITLE:Google;URL://www.google.com;;`,
  /// the display value might be `//www.google.com`.
  ///
  /// This value may be multiline if line breaks are encoded in the barcode.
  /// This value may include the supplement value.
  ///
  /// This is null if there is no user-friendly value for the given barcode.
  final String? displayValue;

  /// The driver license information that is embedded in the barcode.
  final DriverLicense? driverLicense;

  /// The email message that is embedded in the barcode.
  final Email? email;

  /// The format of the barcode.
  final BarcodeFormat format;

  /// The geographic point that is embedded in the barcode.
  final GeoPoint? geoPoint;

  /// The phone number that is embedded in the barcode.
  final Phone? phone;

  /// The raw bytes of the barcode.
  ///
  /// This is null if the raw bytes are not available.
  @Deprecated('Use rawDecodedBytes instead.')
  final Uint8List? rawBytes;

  /// The decoded raw bytes of the barcode.
  ///
  /// This is either a [DecodedBarcodeBytes] (on Android and web)
  /// or a [DecodedVisionBarcodeBytes] (on Apple platforms),
  /// which may contain both decoded bytes and raw payload bytes.
  ///
  /// This is null if the raw bytes are not available.
  final BarcodeBytes? rawDecodedBytes;

  /// The raw string value of the barcode.
  ///
  /// On Android, this is the UTF-8 decoded string value.
  /// On Apple (iOS and macOS), this is Apple's `payloadStringValue` as-is,
  /// which is decoded using Latin-1 (ISO 8859-1) for non-QR barcodes.
  ///
  /// Structured values are not parsed,
  /// for example: 'MEBKM:TITLE:Google;URL://www.google.com;;'.
  ///
  /// For non-UTF-8 barcodes, prefer using [rawDecodedBytes] instead.
  ///
  /// This is null if the raw value is not available.
  final String? rawValue;

  /// The normalized size of the barcode bounding box,
  /// relative to the [BarcodeCapture.size] of the original barcode capture.
  ///
  /// If the bounding box is unavailable, this will be [Size.zero].
  final Size size;

  /// The SMS message that is embedded in the barcode.
  final SMS? sms;

  /// The contextual type of the [format] of the barcode.
  ///
  /// For example: TYPE_TEXT, TYPE_PRODUCT, TYPE_URL, etc.
  ///
  /// For types that are recognized,
  /// but could not be parsed correctly, [BarcodeType.text] will be returned.
  ///
  /// For types that are not recognised, [BarcodeType.unknown] will be returned.
  ///
  /// If a given barcode was not correctly identified,
  /// consider parsing [rawValue] manually instead.
  final BarcodeType type;

  /// The URL bookmark that is embedded in the barcode.
  final UrlBookmark? url;

  /// The Wireless network information that is embedded in the barcode.
  final WiFi? wifi;

  /// Scale the [corners] of this [Barcode] to the given [targetSize].
  ///
  /// Returns the list of scaled offsets,
  /// or an empty list, if the [corners] is empty.
  ///
  /// This method can be used to scale the [corners] of a [Barcode]
  /// from the original camera coordinate space, into widget coordinate space.
  ///
  /// For example, given the `BuildContext` of a widget:
  ///
  /// ```dart
  /// final BuildContext context;
  ///
  /// final Barcode barcode = Barcode(
  ///   size: Size(60, 60),
  ///   corners: [
  ///     Offset(10, 10),
  ///     Offset(50, 10),
  ///     Offset(50, 50),
  ///     Offset(10, 50),
  ///   ],
  /// );
  ///
  /// final List<Offset> scaledCorners = barcode.scaleCorners(
  ///   context.size ?? Size.zero
  /// );
  /// ```
  List<Offset> scaleCorners(Size targetSize) {
    // The size and corners are in the same coordinate space,
    // which is the camera input.
    // If the barcode size is unknown, scale to 0,0.
    final scaleX = size.width > 0 ? targetSize.width / size.width : 0;
    final scaleY = size.height > 0 ? targetSize.height / size.height : 0;

    return [
      for (final Offset offset in corners)
        Offset(offset.dx * scaleX, offset.dy * scaleY),
    ];
  }
}
