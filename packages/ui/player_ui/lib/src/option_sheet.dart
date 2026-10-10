// Module: lib/src/option_sheet.dart
// Purpose: The generic variant selector sheet: quality, line, or any other
// option list, rendered as a modal from the player surface.
// Author: liuchuancong
// Created: 2026-10-10
//
// Generic on purpose: the player surface knows option ids/labels, while the
// meaning (quality vs line) belongs to the caller's domain model.
//
// It used to open a fixed-height bottom sheet, which the sibling episode panel had already learned not to
// do: a source with forty lines or six qualities rendered a list you could not scroll, so the last options
// existed only to the caller that built the list. It also opened a titled sheet with nothing in it when the
// list was empty, which reads as a broken button rather than as "this content has no variants".

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

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
  if (options.isEmpty) {
    // No sheet at all: an empty list is a fact about the content, and showing a blank panel turns it into a
    // UI bug the viewer has to dismiss.
    return Future<String?>.value();
  }
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      // A short list shrinks to fit; a long one can be pulled up to 85% and scrolled, which is the whole
      // point of the sheet existing in two sizes instead of one clipped one.
      initialChildSize: options.length <= _CompactThreshold ? 0.4 : 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.25,
      builder: (sheetContext, scrollController) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PureLiveSpacing.xl,
              PureLiveSpacing.sm,
              PureLiveSpacing.xl,
              PureLiveSpacing.md,
            ),
            child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: options.length,
              itemBuilder: (rowContext, index) {
                final option = options[index];
                return ListTile(
                  dense: true,
                  selected: option.selected,
                  // The check is the only thing distinguishing the current variant from the rest, so it has
                  // to be announced: a screen reader otherwise reads a list of identical rows.
                  trailing: option.selected
                      ? const Icon(Icons.check, semanticLabel: '当前选择')
                      : const SizedBox(width: PureLiveSpacing.xl),
                  title: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(sheetContext, option.id),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Below this many options the sheet opens at its smaller height; a two-entry quality picker should not
/// cover the picture it is choosing for.
const int _CompactThreshold = 4;
