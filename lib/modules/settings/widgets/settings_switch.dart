import 'package:flutter/material.dart';

class SettingsSwitch extends StatelessWidget {
  final bool value;
  final String title;
  final String? subtitle;
  final Function(bool) onChanged;
  const SettingsSwitch({required this.value, required this.title, this.subtitle, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      //visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey))
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}
