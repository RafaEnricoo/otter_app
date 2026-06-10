import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class Header extends StatelessWidget {
  final String? userName;
  final String? userImageUrl;
  final VoidCallback? onNotificationsPressed;
  final VoidCallback? onSettingsPressed;

  const Header({
    super.key,
    this.userName = 'Mimah Dudim',
    this.userImageUrl,
    this.onNotificationsPressed,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 68 + topPadding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(AppColors.surface).withOpacity(0.85),
                Color(AppColors.surfaceContainer).withOpacity(0.75),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerPadding,
              ),
              child: Row(
                children: [
                  // ─── Logo & Branding ───
                  _AnimatedLogo(isMobile: isMobile),

                  const Spacer(),

                  // ─── Desktop Navigation ───
                  if (!isMobile)
                    Row(
                      children: [
                        _NavLink(
                          label: 'Beranda',
                          icon: Icons.home_rounded,
                          isActive: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 6),
                        _NavLink(
                          label: 'Perangkat',
                          icon: Icons.devices_rounded,
                          isActive: false,
                          onTap: () {},
                        ),
                        const SizedBox(width: 6),
                        _NavLink(
                          label: 'Monitor',
                          icon: Icons.analytics_rounded,
                          isActive: false,
                          onTap: () {},
                        ),
                        const SizedBox(width: 6),
                        _NavLink(
                          label: 'Keamanan',
                          icon: Icons.shield_rounded,
                          isActive: false,
                          onTap: () {},
                        ),
                      ],
                    ),

                  const SizedBox(width: AppSpacing.gutter),

                  // ─── Action Buttons ───
                  ValueListenableBuilder<List<NotificationModel>>(
                    valueListenable: NotificationService().notificationsNotifier,
                    builder: (context, list, child) {
                      final count = list.where((n) => !n.isRead).length;
                      return _NotificationButton(
                        onPressed: onNotificationsPressed,
                        badgeCount: count,
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.stackSm),

                  // ─── User Avatar (Opens Profile/Settings) ───
                  GestureDetector(
                    onTap: onSettingsPressed,
                    child: _UserAvatar(
                      userName: userName,
                      userImageUrl: userImageUrl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Animated Logo with gradient shimmer
// ─────────────────────────────────────────────────────────
class _AnimatedLogo extends StatefulWidget {
  final bool isMobile;
  const _AnimatedLogo({required this.isMobile});

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated orb icon
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  center: Alignment.center,
                  startAngle: 0,
                  endAngle: 6.28,
                  transform: GradientRotation(_controller.value * 6.28),
                  colors: [
                    Color(AppColors.secondaryContainer),
                    Color(AppColors.secondaryContainer).withOpacity(0.2),
                    Color(AppColors.primary).withOpacity(0.4),
                    Color(AppColors.secondaryContainer),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(AppColors.secondaryContainer).withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(AppColors.surfaceContainer),
                ),
                child: const Center(
                  child: Icon(
                    Icons.blur_on_rounded,
                    size: 18,
                    color: Color(AppColors.secondaryContainer),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        // Brand name with gradient text
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Color(AppColors.onSurface),
              Color(AppColors.secondaryContainer).withOpacity(0.8),
            ],
          ).createShader(bounds),
          child: Text(
            'Otter',
            style: TextStyle(
              fontSize: widget.isMobile ? 18 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// NavLink with hover animation & active indicator
// ─────────────────────────────────────────────────────────
class _NavLink extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );
    if (widget.isActive) {
      _hoverController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _isHovered;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (!widget.isActive) _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (!widget.isActive) _hoverController.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: widget.isActive
                    ? Color(AppColors.secondaryContainer).withOpacity(0.12)
                    : Colors.white.withOpacity(0.04 * _hoverAnimation.value),
                border: Border.all(
                  color: widget.isActive
                      ? Color(AppColors.secondaryContainer).withOpacity(0.25)
                      : Colors.white
                          .withOpacity(0.06 * _hoverAnimation.value),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isActive) ...[
                    Icon(
                      widget.icon,
                      size: 15,
                      color: Color(AppColors.secondaryContainer),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isHighlighted ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isActive
                          ? Color(AppColors.secondaryContainer)
                          : isHighlighted
                              ? Color(AppColors.onSurface)
                              : Color(AppColors.onSurfaceVariant),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Header Icon Button with hover glow
// ─────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────
// Notification Button with animated badge
// ─────────────────────────────────────────────────────────
class _NotificationButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final int badgeCount;

  const _NotificationButton({
    this.onPressed,
    this.badgeCount = 0,
  });

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.badgeCount > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Notifikasi',
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered
                  ? Colors.white.withOpacity(0.08)
                  : Colors.transparent,
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withOpacity(0.12)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: _isHovered
                        ? Color(AppColors.onSurface)
                        : Color(AppColors.onSurfaceVariant),
                  ),
                ),
                // Badge
                if (widget.badgeCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulse ring
                            Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(
                                    AppColors.secondaryContainer,
                                  ).withOpacity(
                                    0.3 * (1.3 - _pulseAnimation.value),
                                  ),
                                ),
                              ),
                            ),
                            // Badge circle
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(AppColors.secondaryContainer),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(
                                      AppColors.secondaryContainer,
                                    ).withOpacity(0.6),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${widget.badgeCount}',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Color(AppColors.surface),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// User Avatar with status ring
// ─────────────────────────────────────────────────────────
class _UserAvatar extends StatefulWidget {
  final String? userName;
  final String? userImageUrl;

  const _UserAvatar({
    this.userName,
    this.userImageUrl,
  });

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  bool _isHovered = false;

  String get _initials {
    if (widget.userName == null || widget.userName!.isEmpty) return '?';
    final parts = widget.userName!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isHovered
                ? [
                    Color(AppColors.secondaryContainer),
                    Color(AppColors.primary),
                  ]
                : [
                    Color(AppColors.secondaryContainer).withOpacity(0.4),
                    Color(AppColors.primary).withOpacity(0.2),
                  ],
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color:
                        Color(AppColors.secondaryContainer).withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(AppColors.surfaceContainer),
          ),
          child: ClipOval(
            child: widget.userImageUrl != null
                ? Image.network(
                    widget.userImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitials();
                    },
                  )
                : _buildInitials(),
          ),
        ),
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(AppColors.secondaryContainer),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
