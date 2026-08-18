import 'package:mobile_scanner/src/enums/barcode_type.dart';
import 'package:mobile_scanner/src/enums/encryption_type.dart';

/// Wireless network information from [BarcodeType.wifi] barcodes.
class WiFi {
  /// Construct a new [WiFi] instance.
  const WiFi({
    this.encryptionType = EncryptionType.unknown,
    this.ssid,
    this.password,
  });

  /// Construct a new [WiFi] instance from the given [data].
  factory WiFi.fromNative(Map<Object?, Object?> data) {
    return WiFi(
      encryptionType: EncryptionType.fromRawValue(
        data['encryptionType'] as int? ?? 0,
      ),
      ssid: data['ssid'] as String?,
      password: data['password'] as String?,
    );
  }

  /// The encryption type of the wireless network.
  final EncryptionType encryptionType;

  /// The ssid of the wireless network.
  final String? ssid;

  /// The password of the wireless network.
  final String? password;
}
