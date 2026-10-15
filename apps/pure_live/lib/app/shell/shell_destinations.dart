import 'package:flutter/material.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// The shell branch destinations, shared by every platform's chrome: the
/// labels and icons are one decision, only their container differs.
List<({String label, IconData icon})> shellDestinations(BuildContext context) => [
  (label: context.t.tabs.home, icon: Icons.home_outlined),
  (label: context.t.tabs.follow, icon: Icons.favorite_border),
  (label: context.t.tabs.history, icon: Icons.history),
];
