import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/system_settings_service.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool isActive;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ValueListenableBuilder<double>(
        valueListenable: SystemSettingsService().glassOpacity,
        builder: (context, opacity, _) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: isActive
                  ? Color(AppColors.secondaryContainer).withValues(alpha: opacity)
                  : Colors.white.withValues(alpha: opacity),
              border: Border.all(
                color: isActive
                    ? Color(AppColors.secondaryContainer).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: Color(AppColors.secondaryContainer).withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: BackdropFilter(
              filter: const ColorFilter.mode(
                Colors.transparent,
                BlendMode.multiply,
              ),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: Colors.transparent,
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
