import 'package:flutter/widgets.dart';

// 「扫码到手机」: what is hard with a remote — typing a cookie, an address,
// reading a long log — is done on a phone that scans a code on the TV.
// Pages ask through [PhoneBridge.maybeOf]; only the TV provides one, and a
// page without one hides its phone buttons (a null bridge is the "no such
// capability" answer, never an error).

/// One field of [PhoneInputRequest].
@immutable
final class PhoneInputField {
  /// Creates the field.
  const new({required this.key, required this.label, this.initial = '', this.hint = '', this.multiline = false});

  /// The name its value comes back under.
  final String key;

  /// The words over it.
  final String label;

  /// Its text when the page opens.
  final String initial;

  /// The grey text while empty.
  final String hint;

  /// Several lines (a cookie).
  final bool multiline;
}

/// A form filled in on a phone.
@immutable
final class PhoneInputRequest {
  /// Creates the request.
  const new({required this.title, required this.fields, this.note});

  /// What is asked.
  final String title;

  /// The fields.
  final List<PhoneInputField> fields;

  /// A line under the title.
  final String? note;
}

/// The TV's 「扫码到手机」 for the pages below it.
class PhoneBridge extends InheritedWidget {
  /// Creates the bridge.
  const new({required this.input, required this.view, required super.child, super.key});

  /// Shows the code of a form; the values by field key, or null when the
  /// viewer cancelled.
  final Future<Map<String, String>?> Function(BuildContext context, PhoneInputRequest request) input;

  /// Shows the code of a page that shows a text (a log) on the phone.
  final Future<void> Function(BuildContext context, {required String title, required String text}) view;

  /// The bridge above [context], if any.
  static PhoneBridge? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<PhoneBridge>();

  @override
  bool updateShouldNotify(PhoneBridge oldWidget) => oldWidget.input != input || oldWidget.view != view;
}
