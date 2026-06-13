import 'package:flutter/material.dart';

class AnimatedTempText extends StatelessWidget {
  final double celsiusValue;
  final bool isCelsius;
  final TextStyle style;
  final bool showUnit;

  const AnimatedTempText({
    super.key,
    required this.celsiusValue,
    required this.isCelsius,
    required this.style,
    this.showUnit = true,
  });

  @override
  Widget build(BuildContext context) {
    final double targetValue = isCelsius ? celsiusValue : (celsiusValue * 1.8 + 32);
    final String suffix = showUnit ? (isCelsius ? '°C' : '°F') : '°';

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetValue),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${value.toStringAsFixed(1)}$suffix',
          style: style,
        );
      },
    );
  }
}
