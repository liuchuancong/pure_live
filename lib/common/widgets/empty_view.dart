import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.boxConstraints,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final BoxConstraints? boxConstraints;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).disabledColor;
    return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
            height: boxConstraints?.maxHeight,
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 144, color: color),
                  const SizedBox(height: 24),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: "$title\n", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
                      TextSpan(text: "\n$subtitle", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
                    ]),
                    textAlign: TextAlign.center,
                  ),
                  // const SizedBox(height: 32),
                ],
              ),
            )));
  }
}
