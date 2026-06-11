import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import 'glass_card.dart';

class NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onDismissed;
  final VoidCallback onMarkedRead;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onDismissed,
    required this.onMarkedRead,
  });

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  // Icons based on Category
  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.security:
        return Icons.shield_rounded;
      case NotificationCategory.climate:
        return Icons.thermostat_rounded;
      case NotificationCategory.energy:
        return Icons.bolt_rounded;
      case NotificationCategory.system:
        return Icons.settings_suggest_rounded;
    }
  }

  // Primary colors based on priority
  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return const Color(0xFFFF4963); // Vivid Neon Red
      case NotificationPriority.warning:
        return const Color(0xFFFFB300); // Amber Yellow
      case NotificationPriority.info:
        return Color(AppColors.secondaryContainer); // Neon Electric Cyan
    }
  }

  // Readable category name
  String _getCategoryLabel(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.security:
        return 'Security';
      case NotificationCategory.climate:
        return 'Climate';
      case NotificationCategory.energy:
        return 'Power & Energy';
      case NotificationCategory.system:
        return 'System Core';
    }
  }

  // Format time stamp relatively
  String _formatTimestamp(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(widget.notification.priority);
    final iconData = _getCategoryIcon(widget.notification.category);

    return Dismissible(
      key: Key(widget.notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        widget.onDismissed();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28.0),
        decoration: BoxDecoration(
          color: const Color(0xFF93000A).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: const Color(0xFFFF4963).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4963).withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFFB4AB),
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: GlassCard(
          borderRadius: BorderRadius.circular(16.0),
          isActive: !widget.notification.isRead,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isExpanded = !_isExpanded;
            });
            if (!widget.notification.isRead) {
              widget.onMarkedRead();
            }
          },
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Main content row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glow bar border based on priority
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: priorityColor.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Icon Container
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        iconData,
                        color: priorityColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getCategoryLabel(widget.notification.category),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                _formatTimestamp(widget.notification.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: widget.notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: widget.notification.isRead
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.message,
                            maxLines: _isExpanded ? 10 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.65),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Expandable Action Panel
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _isExpanded
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Action items based on category
                            if (widget.notification.category == NotificationCategory.security)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(AppColors.secondaryContainer),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Color(AppColors.secondaryContainer).withValues(alpha: 0.15)),
                                  ),
                                ),
                                icon: const Icon(Icons.videocam_rounded, size: 16),
                                label: const Text('View Stream', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Opening live backyard security camera stream...')),
                                  );
                                },
                              ),
                            if (widget.notification.category == NotificationCategory.climate)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFB300),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: const Color(0xFFFFB300).withValues(alpha: 0.15)),
                                  ),
                                ),
                                icon: const Icon(Icons.mode_fan_off_rounded, size: 16),
                                label: const Text('Adjust Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Opening climate control settings panel...')),
                                  );
                                },
                              ),
                            if (widget.notification.category == NotificationCategory.energy)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(AppColors.secondaryContainer),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Color(AppColors.secondaryContainer).withValues(alpha: 0.15)),
                                  ),
                                ),
                                icon: const Icon(Icons.analytics_rounded, size: 16),
                                label: const Text('View Energy Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Navigating to power usage analytics...')),
                                  );
                                },
                              ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.7),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                backgroundColor: Colors.white.withValues(alpha: 0.02),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isExpanded = false;
                                });
                              },
                              child: const Text('Close', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
