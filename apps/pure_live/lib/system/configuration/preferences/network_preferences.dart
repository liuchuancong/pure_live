import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// The outgoing proxy the app's own requests take.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class NetworkPreferences extends Equatable {
  /// The shipping defaults.
  const new({this.proxyEnabled = false, this.proxyHost = '127.0.0.1', this.proxyPort = 7890});

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory NetworkPreferences.fromJson(Map<String, Object?> json) {
    return NetworkPreferences(
      proxyEnabled: json['proxyEnabled'] as bool? ?? false,
      proxyHost: json['proxyHost'] as String? ?? '127.0.0.1',
      proxyPort: json['proxyPort'] as int? ?? 7890,
    );
  }

  /// Whether outgoing requests route through the user's proxy.
  final bool proxyEnabled;

  /// The proxy host name or IP.
  final String proxyHost;

  /// The proxy port.
  final int proxyPort;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {'proxyEnabled': proxyEnabled, 'proxyHost': proxyHost, 'proxyPort': proxyPort};

  /// Returns a copy with the given fields replaced.
  NetworkPreferences copyWith({bool? proxyEnabled, String? proxyHost, int? proxyPort}) => NetworkPreferences(
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    proxyHost: proxyHost ?? this.proxyHost,
    proxyPort: proxyPort ?? this.proxyPort,
  );

  @override
  List<Object?> get props => [proxyEnabled, proxyHost, proxyPort];
}
