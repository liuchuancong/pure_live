import 'package:mobile_scanner/src/enums/phone_type.dart';

/// Phone number information from a barcode.
class Phone {
  /// Construct a new [Phone] instance.
  const Phone({this.number, this.type = PhoneType.unknown});

  /// Create a [Phone] from the given [data].
  factory Phone.fromNative(Map<Object?, Object?> data) {
    return Phone(
      number: data['number'] as String?,
      type: PhoneType.fromRawValue(data['type'] as int? ?? 0),
    );
  }

  /// The phone number value.
  final String? number;

  /// The type of the phone number.
  final PhoneType type;
}
