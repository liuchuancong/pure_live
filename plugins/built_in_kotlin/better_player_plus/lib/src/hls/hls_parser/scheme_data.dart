import 'package:flutter/foundation.dart';

@immutable
class SchemeData {
  const SchemeData({this.licenseServerUrl, required this.mimeType, this.data, this.requiresSecureDecryption});

  /// The URL of the server to which license requests should be made. May be null if unknown.
  final String? licenseServerUrl;

  /// The mimeType of [data].
  final String mimeType;

  /// The initialization base data.
  /// you should build pssh manually for use.
  final Uint8List? data;

  /// Whether secure decryption is required.
  final bool? requiresSecureDecryption;

  SchemeData copyWithData(Uint8List? data) => SchemeData(
    licenseServerUrl: licenseServerUrl,
    mimeType: mimeType,
    data: data,
    requiresSecureDecryption: requiresSecureDecryption,
  );

  @override
  bool operator ==(Object other) {
    if (other is SchemeData) {
      return other.mimeType == mimeType &&
          other.licenseServerUrl == licenseServerUrl &&
          other.requiresSecureDecryption == requiresSecureDecryption &&
          other.data == data;
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(licenseServerUrl, mimeType, data, requiresSecureDecryption);
}
