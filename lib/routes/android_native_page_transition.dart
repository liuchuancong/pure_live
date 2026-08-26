import 'package:flutter/material.dart';

class AndroidNativePageTransitionsBuilder extends PageTransitionsBuilder {
  const AndroidNativePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primarySlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.1, 0.0),
    ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut));

    return SlideTransition(
      position: primarySlide,
      child: SlideTransition(position: secondarySlide, child: child),
    );
  }
}
