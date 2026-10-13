// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// A picture in a message: [code] is the text that stands for it in the
/// message's own text, exactly as written there, and every occurrence of it is
/// the picture at [url].
@immutable
final class LiveEmote {
  /// Creates an emote.
  const LiveEmote({required this.code, required this.url});

  /// The text standing for the picture.
  final String code;

  /// The picture's address (https or http, as the platform gives it).
  final String url;

  @override
  bool operator ==(Object other) => other is LiveEmote && other.code == code && other.url == url;

  @override
  int get hashCode => Object.hash(code, url);

  @override
  String toString() => 'LiveEmote($code, $url)';
}
