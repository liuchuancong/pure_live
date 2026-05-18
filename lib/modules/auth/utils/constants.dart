import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

SizedBox spacer(double height) {
  return SizedBox(
    height: height,
  );
}

/// Set of extension methods to easily display a snackbar
extension ShowSnackBar on BuildContext {
  /// Displays a basic snackbar
  void showSnackBar(
    String message, {
    Color? textColor,
    Color? backgroundColor,
    String? actionLabel,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      content: Text(
        message,
        style: textColor == null ? null : TextStyle(color: textColor),
      ),
      backgroundColor: backgroundColor,
      action: SnackBarAction(
        label: actionLabel ?? 'ok',
        onPressed: () {},
      ),
    ));
  }

  /// Displays a red snackbar indicating error
  void showErrorSnackBar(
    String message, {
    String? actionLabel,
  }) {
    showSnackBar(
      message,
      textColor: Theme.of(this).colorScheme.onErrorContainer,
      backgroundColor: Theme.of(this).colorScheme.errorContainer,
      actionLabel: actionLabel,
    );
  }
}
