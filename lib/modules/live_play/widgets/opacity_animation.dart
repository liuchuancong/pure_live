import 'package:flutter/material.dart';

class OpacityTansWidget extends StatefulWidget {
  const OpacityTansWidget({super.key, required this.child});

  final Widget child;

  @override
  OpacityState createState() => OpacityState();
}

class OpacityState extends State<OpacityTansWidget> with TickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(duration: const Duration(milliseconds: 500), lowerBound: 0.5, vsync: this);
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
