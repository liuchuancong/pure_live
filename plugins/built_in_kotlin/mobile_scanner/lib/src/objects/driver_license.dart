/// A driver license or ID card.
class DriverLicense {
  /// Create a new [DriverLicense].
  const DriverLicense({
    this.addressCity,
    this.addressState,
    this.addressStreet,
    this.addressZip,
    this.birthDate,
    this.documentType,
    this.expiryDate,
    this.firstName,
    this.gender,
    this.issueDate,
    this.issuingCountry,
    this.lastName,
    this.licenseNumber,
    this.middleName,
  });

  /// Create a [DriverLicense] from a map.
  factory DriverLicense.fromNative(Map<Object?, Object?> data) {
    return DriverLicense(
      addressCity: data['addressCity'] as String?,
      addressState: data['addressState'] as String?,
      addressStreet: data['addressStreet'] as String?,
      addressZip: data['addressZip'] as String?,
      birthDate: data['birthDate'] as String?,
      documentType: data['documentType'] as String?,
      expiryDate: data['expiryDate'] as String?,
      firstName: data['firstName'] as String?,
      gender: data['gender'] as String?,
      issueDate: data['issueDate'] as String?,
      issuingCountry: data['issuingCountry'] as String?,
      lastName: data['lastName'] as String?,
      licenseNumber: data['licenseNumber'] as String?,
      middleName: data['middleName'] as String?,
    );
  }

  /// The city of the holder's address.
  final String? addressCity;

  /// The state of the holder's address.
  final String? addressState;

  /// The street address of the holder's address.
  final String? addressStreet;

  /// The postal code of the holder's address.
  final String? addressZip;

  /// The holder's birth date.
  final String? birthDate;

  /// The type of the license.
  ///
  /// This is either "DL" for driver licenses or "ID" for ID cards.
  final String? documentType;

  /// The expiry date of the license.
  final String? expiryDate;

  /// The holder's first name.
  final String? firstName;

  /// The holder's gender.
  ///
  /// This is either '1' for male or '2' for female.
  final String? gender;

  /// The issue date of the license.
  ///
  /// The date format depends on the issuing country.
  /// For example `MMDDYYYY` is used in the US,
  /// and `YYYYMMDD` is used in Canada.
  final String? issueDate;

  /// The three-letter country code in which this license was issued.
  final String? issuingCountry;

  /// The holder's last name.
  final String? lastName;

  /// The identifying number for this license.
  final String? licenseNumber;

  /// The holder's middle name.
  final String? middleName;
}
