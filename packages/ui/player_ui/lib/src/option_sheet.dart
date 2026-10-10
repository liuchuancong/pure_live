// Module: lib/src/option_sheet.dart
// Purpose: The generic variant selector sheet: quality, line, or any other
// option list, rendered as a modal from the player surface.
// Author: liuchuancong
// Created: 2026-10-10
//
// Generic on purpose: the player surface knows option ids/labels, while the
// meaning (quality vs line) belongs to the caller's domain model.

import 'package:flutter/material.dart';

/// One selectable option row.
final class PlayerOption {
  const PlayerOption({required this.id, required this.label, this.selected = false});

  final String id;
  final String label;
  final bool selected;
}

/// Shows the option sheet and returns the chosen option's id, or null when
/// dismissed.
Future<String?> showPlayerOptionSheet(
  BuildContext context, {
  required String title,
  required List<PlayerOption> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          for (final option in options)
            ListTile(
              dense: true,
              title: Text(option.label),
              trailing: option.selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, option.id),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
