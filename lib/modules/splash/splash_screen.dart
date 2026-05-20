import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pure_live/common/index.dart';

enum LoaderType { spinner, dots, progressBar }

class SplashScreen extends StatefulWidget {
  final Color? bgColor;
  final Gradient? bgGradient;
  final Widget? logo;
  final String? logoText;
  final bool showLogo;
  final bool showTextLogo;
  final bool showLoader;
  final LoaderType loaderType;
  final VoidCallback? onNextPressed;
  final Widget? nextButton;
  final Duration duration; // زمان نمایش خودکار
  final TextStyle? textStyle; // رنگ و استایل متن

  const SplashScreen({
    super.key,
    this.bgColor,
    this.bgGradient,
    this.logo,
    this.logoText,
    this.showLogo = true,
    this.showTextLogo = false,
    this.showLoader = true,
    this.loaderType = LoaderType.spinner,
    this.onNextPressed,
    this.nextButton,
    this.duration = const Duration(seconds: 3),
    this.textStyle,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    if (widget.onNextPressed != null) {
      Timer(widget.duration, () {
        widget.onNextPressed!();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: widget.bgGradient == null ? widget.bgColor ?? Colors.white : null,
          gradient: widget.bgGradient,
        ),
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showLogo && widget.logo != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(scale: _scaleAnimation, child: widget.logo),
              ),
            if (widget.showTextLogo && widget.logoText != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(
                    widget.logoText!,
                    style:
                        widget.textStyle ??
                        const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 30),
            if (widget.showLoader) _buildLoader(),
            const SizedBox(height: 30),
            if (widget.nextButton != null) GestureDetector(onTap: widget.onNextPressed, child: widget.nextButton),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    switch (widget.loaderType) {
      case LoaderType.spinner:
        return const CircularProgressIndicator(color: Colors.white);
      case LoaderType.dots:
        return const AnimatedDots();
      case LoaderType.progressBar:
        return SizedBox(
          width: 200,
          child: LinearProgressIndicator(backgroundColor: Colors.white.withValues(alpha: 0.3), color: Colors.white),
        );
    }
  }
}

class AnimatedDots extends StatefulWidget {
  const AnimatedDots({super.key});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int dotCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (index) {
        return FadeTransition(
          opacity: _animation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Icon(Icons.circle, size: 12, color: Colors.white),
          ),
        );
      }),
    );
  }
}
