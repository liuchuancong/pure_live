import 'package:mobile_scanner/src/enums/address_type.dart';

/// An address.
class Address {
  /// Creates a new [Address] instance.
  const Address({
    this.addressLines = const <String>[],
    this.type = AddressType.unknown,
  });

  /// Creates a new [Address] instance from a map.
  factory Address.fromNative(Map<Object?, Object?> data) {
    final addressLines = data['addressLines'] as List<Object?>?;
    final type = AddressType.fromRawValue(data['type'] as int? ?? 0);

    if (addressLines == null) {
      return Address(type: type);
    }

    return Address(
      addressLines: List.unmodifiable(addressLines.cast<String>()),
      type: type,
    );
  }

  /// The address lines that represent this address.
  final List<String> addressLines;

  /// Gets type of the address.
  final AddressType type;
}
