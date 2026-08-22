import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class PureLivePipWidget extends StatelessWidget {
  final Widget child;

  const PureLivePipWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return child;
    }
    return Stack(
      children: [
        DragToResizeArea(
          child: Container(color: Colors.black, child: child),
        ),
      ],
    );
  }
}
