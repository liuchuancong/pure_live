import 'dart:io';

class LocalAddress {
  final NetworkInterface interface;
  final InternetAddress address;

  const LocalAddress({required this.interface, required this.address});

  String get ip => address.address;
}
