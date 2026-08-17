import 'package:mobile_scanner/src/objects/address.dart';
import 'package:mobile_scanner/src/objects/email.dart';
import 'package:mobile_scanner/src/objects/person_name.dart';
import 'package:mobile_scanner/src/objects/phone.dart';

/// A person's or organization's business card.
/// For example a VCARD.
class ContactInfo {
  /// Create a new [ContactInfo] instance.
  const ContactInfo({
    this.addresses = const <Address>[],
    this.emails = const <Email>[],
    this.name,
    this.organization,
    this.phones = const <Phone>[],
    this.title,
    this.urls = const <String>[],
  });

  /// Create a new [ContactInfo] instance from a map.
  factory ContactInfo.fromNative(Map<Object?, Object?> data) {
    final addresses = data['addresses'] as List<Object?>?;
    final emails = data['emails'] as List<Object?>?;
    final phones = data['phones'] as List<Object?>?;
    final urls = data['urls'] as List<Object?>?;
    final name = data['name'] as Map<Object?, Object?>?;

    return ContactInfo(
      addresses:
          addresses == null
              ? const <Address>[]
              : List.unmodifiable(
                addresses.cast<Map<Object?, Object?>>().map(Address.fromNative),
              ),
      emails:
          emails == null
              ? const <Email>[]
              : List.unmodifiable(
                emails.cast<Map<Object?, Object?>>().map(Email.fromNative),
              ),
      name: name == null ? null : PersonName.fromNative(name),
      organization: data['organization'] as String?,
      phones:
          phones == null
              ? const <Phone>[]
              : List.unmodifiable(
                phones.cast<Map<Object?, Object?>>().map(Phone.fromNative),
              ),
      title: data['title'] as String?,
      urls:
          urls == null
              ? const <String>[]
              : List.unmodifiable(urls.cast<String>()),
    );
  }

  /// The list of addresses for the person or organisation.
  final List<Address> addresses;

  /// The list of email addresses for the person or organisation.
  final List<Email> emails;

  /// The name of the contact person.
  final PersonName? name;

  /// The name of the organization.
  final String? organization;

  /// The available phone numbers for the contact person or organisation.
  final List<Phone> phones;

  /// The contact person's title.
  final String? title;

  /// The urls associated with the contact person or organisation.
  final List<String> urls;
}
