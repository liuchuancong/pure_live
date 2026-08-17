/// An sms message from a `SMS:` or similar QRCode type.
class SMS {
  /// Construct a new [SMS] instance.
  const SMS({required this.phoneNumber, this.message});

  /// Construct a new [SMS] instance from the given [data].
  factory SMS.fromNative(Map<Object?, Object?> data) {
    return SMS(
      message: data['message'] as String?,
      phoneNumber: data['phoneNumber'] as String? ?? '',
    );
  }

  /// The message contained in the sms.
  final String? message;

  /// The phone number which sent the sms.
  final String phoneNumber;
}
