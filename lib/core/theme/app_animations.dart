import 'package:flutter/material.dart';

class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 300);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;

  static TweenSequence<double> get bounceIn => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.05), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.05, end: 0.95), weight: 20),
        TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 40),
      ]);
}
