/// A person's name, divided into individual components.
class PersonName {
  /// Create a new [PersonName] instance.
  const PersonName({
    this.first,
    this.middle,
    this.last,
    this.prefix,
    this.suffix,
    this.formattedName,
    this.pronunciation,
  });

  /// Create a [PersonName] from a map.
  factory PersonName.fromNative(Map<Object?, Object?> data) {
    return PersonName(
      first: data['first'] as String?,
      middle: data['middle'] as String?,
      last: data['last'] as String?,
      prefix: data['prefix'] as String?,
      suffix: data['suffix'] as String?,
      formattedName: data['formattedName'] as String?,
      pronunciation: data['pronunciation'] as String?,
    );
  }

  /// The person's first name.
  final String? first;

  /// The person's middle name.
  final String? middle;

  /// The person's last name.
  final String? last;

  /// The prefix of the person's name.
  final String? prefix;

  /// The suffix of the person's name.
  final String? suffix;

  /// The person's name in a structured format.
  final String? formattedName;

  /// The pronunciation of the person's name.
  ///
  /// This is used for the "kana" name in Japanese phonebooks.
  final String? pronunciation;
}
