import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../services/firebase_service.dart';
import '../screens/voice_assistant_screen.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabGlowAnimation;

  @override
  void initState() {
    super.initState();
    // Animated glow pulsation for FAB
    _fabController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fabGlowAnimation = Tween<double>(begin: 0.25, end: 0.6).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: FirebaseService().stateNotifier,
      builder: (context, state, child) {
        final bool isAlarmActive = state != null &&
            (state.perangkat.buzzerTamu || state.perangkat.buzzerDapur);

        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.07),
                    width: 1,
                  ),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(AppColors.surface).withOpacity(0.85),
                    Color(AppColors.surfaceContainer).withOpacity(0.95),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavBarItem(
                        icon: Icons.home_rounded,
                        activeIcon: Icons.home_filled,
                        isActive: widget.currentIndex == 0,
                        onTap: () => widget.onTabSelected(0),
                        label: 'Beranda',
                      ),
                      _NavBarItem(
                        icon: Icons.grid_view_outlined,
                        activeIcon: Icons.grid_view_rounded,
                        isActive: widget.currentIndex == 1,
                        onTap: () => widget.onTabSelected(1),
                        label: 'Perangkat',
                      ),

                      // ─── Central Mic Button (inline) ───
                      _MicFab(
                        glowAnimation: _fabGlowAnimation,
                        onTap: () => showVoiceAssistant(context),
                      ),

                      _NavBarItem(
                        icon: Icons.analytics_outlined,
                        activeIcon: Icons.analytics_rounded,
                        isActive: widget.currentIndex == 2,
                        onTap: () => widget.onTabSelected(2),
                        label: 'Monitor',
                      ),
                      _NavBarItem(
                        icon: Icons.shield_outlined,
                        activeIcon: Icons.shield_rounded,
                        isActive: widget.currentIndex == 3,
                        onTap: () => widget.onTabSelected(3),
                        label: 'Keamanan',
                        isAlarmActive: isAlarmActive,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}

// ─────────────────────────────────────────────────────────
// Microphone FAB with animated glow rings
// ─────────────────────────────────────────────────────────
class _MicFab extends StatefulWidget {
  final Animation<double> glowAnimation;
  final VoidCallback onTap;

  const _MicFab({
    required this.glowAnimation,
    required this.onTap,
  });

  @override
  State<_MicFab> createState() => _MicFabState();
}

class _MicFabState extends State<_MicFab>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.glowAnimation, _rotationController]),
        builder: (context, child) {
          return SizedBox(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating gradient ring
                      Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Color(AppColors.secondaryContainer),
                                Color(AppColors.secondaryContainer).withOpacity(0.0),
                                Color(AppColors.primary).withOpacity(0.3),
                                Color(AppColors.secondaryContainer).withOpacity(0.0),
                                Color(AppColors.secondaryContainer),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Inner circle (main button)
                      AnimatedScale(
                        scale: _isPressed ? 0.9 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.3),
                              radius: 1.0,
                              colors: [
                                Color(AppColors.surfaceContainerHigh),
                                Color(AppColors.surfaceContainer),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  AppColors.secondaryContainer,
                                ).withOpacity(widget.glowAnimation.value),
                                blurRadius: 16,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.mic_rounded,
                              color: Color(AppColors.secondaryContainer),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Voice',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(AppColors.onSurfaceVariant).withOpacity(0.5),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Nav Bar Item with animated icon + label
// ─────────────────────────────────────────────────────────
class _NavBarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final String label;
  final bool isAlarmActive;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    required this.label,
    this.isAlarmActive = false,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  late AnimationController _alarmController;
  late Animation<double> _alarmOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.value = 0.0; // Active but not "pressed"
    }

    _alarmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _alarmOpacityAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
    );

    if (widget.isAlarmActive) {
      _alarmController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger bounce when becoming active
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward().then((_) => _controller.reverse());
    }

    if (widget.isAlarmActive != oldWidget.isAlarmActive) {
      if (widget.isAlarmActive) {
        _alarmController.repeat(reverse: true);
      } else {
        _alarmController.stop();
        _alarmController.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _alarmController.dispose();
    super.dispose();
  }

  void _handlePress() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: 60,
              child: AnimatedBuilder(
                animation: _alarmOpacityAnimation,
                builder: (context, child) {
                  final double opacity = widget.isAlarmActive ? _alarmOpacityAnimation.value : 1.0;
                  final Color iconColor = widget.isAlarmActive
                      ? Colors.redAccent.withOpacity(opacity)
                      : (widget.isActive
                          ? Color(AppColors.secondaryContainer)
                          : Color(AppColors.onSurfaceVariant).withOpacity(0.6));
                  final Color containerColor = widget.isActive
                      ? (widget.isAlarmActive
                          ? Colors.redAccent.withOpacity(0.12 * opacity)
                          : Color(AppColors.secondaryContainer).withOpacity(0.12))
                      : Colors.transparent;
                  final Color labelColor = widget.isAlarmActive
                      ? Colors.redAccent.withOpacity(opacity)
                      : (widget.isActive
                          ? Color(AppColors.secondaryContainer)
                          : Color(AppColors.onSurfaceVariant).withOpacity(0.5));

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with animated color and optional glow
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: containerColor,
                        ),
                        child: Icon(
                          widget.isActive ? widget.activeIcon : widget.icon,
                          color: iconColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Label
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                          color: labelColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
