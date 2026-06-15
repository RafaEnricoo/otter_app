import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import '../screens/rfid_management_screen.dart';
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

class _NotificationTileState extends State<NotificationTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  double _swipeProgress = 0.0;

  // Context-aware icon — matches notification title first, falls back to category
  IconData _getNotificationIcon(NotificationModel notif) {
    final t = notif.title.toLowerCase();

    // ── Lampu ──
    if (t.contains('lampu') && t.contains('menyala')) return Icons.lightbulb_rounded;
    if (t.contains('lampu') && t.contains('mati')) return Icons.lightbulb_outline_rounded;
    if (t.contains('lampu')) return Icons.lightbulb_rounded;

    // ── Kipas ──
    if (t.contains('kipas') && t.contains('mati')) return Icons.mode_fan_off_rounded;
    if (t.contains('kipas')) return Icons.air_rounded;
    if (t.contains('kecepatan kipas')) return Icons.speed_rounded;

    // ── Sirine / Alarm ──
    if (t.contains('sirine') && (t.contains('aktif') || t.contains('menyala'))) return Icons.campaign_rounded;
    if (t.contains('sirine')) return Icons.notifications_off_rounded;

    // ── RFID / Pintu ──
    if (t.contains('rfid') && t.contains('terkunci')) return Icons.lock_rounded;
    if (t.contains('rfid') && t.contains('terbuka')) return Icons.lock_open_rounded;
    if (t.contains('rfid') && t.contains('didaftarkan')) return Icons.add_card_rounded;
    if (t.contains('rfid') && t.contains('dihapus')) return Icons.credit_card_off_rounded;
    if (t.contains('rfid') && t.contains('disetujui')) return Icons.contactless_rounded;
    if (t.contains('rfid') && (t.contains('fisik') || t.contains('menunggu') || t.contains('pendaftaran'))) return Icons.hourglass_empty_rounded;
    if (t.contains('pintu')) return Icons.sensor_door_rounded;

    // ── Kebakaran / Api ──
    if (t.contains('kebakaran') || t.contains('api')) return Icons.local_fire_department_rounded;

    // ── Anomali / Pergerakan / PIR ──
    if (t.contains('anomali') || t.contains('pergerakan') || t.contains('pir')) return Icons.person_off_rounded;

    // ── Sistem Keamanan ──
    if (t.contains('keamanan') && t.contains('dinonaktifkan')) return Icons.shield_rounded;
    if (t.contains('keamanan')) return Icons.security_rounded;

    // ── Otomatisasi Lampu ──
    if (t.contains('otomatisasi') && t.contains('lampu') && t.contains('aktif')) return Icons.auto_awesome_rounded;
    if (t.contains('otomatisasi') && t.contains('lampu')) return Icons.auto_mode_rounded;

    // ── Otomatisasi Kipas ──
    if (t.contains('otomatisasi') && t.contains('kipas')) return Icons.thermostat_auto_rounded;

    // ── Ambang / Threshold ──
    if (t.contains('ambang') && t.contains('cahaya')) return Icons.wb_twilight_rounded;
    if (t.contains('ambang') && t.contains('suhu')) return Icons.thermostat_rounded;
    if (t.contains('ambang')) return Icons.tune_rounded;

    // ── Fallback: per kategori ──
    switch (notif.category) {
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

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return const Color(0xFFFF4963);
      case NotificationPriority.warning:
        return const Color(0xFFFFB300);
      case NotificationPriority.info:
        return Color(AppColors.secondaryContainer);
    }
  }

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
    final iconData = _getNotificationIcon(widget.notification);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Static Red background (revealed as the card slides left)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF93000A),
                borderRadius: BorderRadius.circular(16.0),
              ),
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24.0),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Opacity(
                  opacity: (_swipeProgress * 3.0).clamp(0.0, 1.0),
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
              ),
            ),
          ),
          // Sliding child
          Dismissible(
            key: Key(widget.notification.id),
            direction: DismissDirection.endToStart,
            background: const SizedBox.shrink(),
            onUpdate: (details) {
              setState(() {
                _swipeProgress = details.progress;
              });
            },
            onDismissed: (direction) {
              HapticFeedback.mediumImpact();
              widget.onDismissed();
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(AppColors.surface),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: GlassCard(
                borderRadius: BorderRadius.circular(16.0),
                isActive: !widget.notification.isRead,
                onTap: () {
                  HapticFeedback.lightImpact();
                  final t = widget.notification.title.toLowerCase();
                  final m = widget.notification.message.toLowerCase();
                  final isRfidPending = t.contains('pendaftaran rfid fisik') || m.contains('menunggu persetujuan');

                  if (isRfidPending) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RfidManagementScreen()),
                    );
                  } else {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }

                  if (!widget.notification.isRead) {
                    widget.onMarkedRead();
                  }
                },
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // ── Main content row ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Priority glow bar
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

                          // Category icon
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

                          // Title & message
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

                    // ── Expandable Action Panel ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _isExpanded
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
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
                                  if (widget.notification.category ==
                                      NotificationCategory.security)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Color(AppColors.secondaryContainer),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.04),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                              color: Color(
                                                      AppColors.secondaryContainer)
                                                  .withValues(alpha: 0.15)),
                                        ),
                                      ),
                                      icon: const Icon(Icons.videocam_rounded,
                                          size: 16),
                                      label: const Text('View Stream',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Opening live backyard security camera stream...')),
                                        );
                                      },
                                    ),
                                  if (widget.notification.category ==
                                      NotificationCategory.climate)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFFFB300),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.04),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                              color: const Color(0xFFFFB300)
                                                  .withValues(alpha: 0.15)),
                                        ),
                                      ),
                                      icon: const Icon(Icons.mode_fan_off_rounded,
                                          size: 16),
                                      label: const Text('Adjust Settings',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Opening climate control settings panel...')),
                                        );
                                      },
                                    ),
                                  if (widget.notification.category ==
                                      NotificationCategory.energy)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Color(AppColors.secondaryContainer),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.04),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                              color: Color(
                                                      AppColors.secondaryContainer)
                                                  .withValues(alpha: 0.15)),
                                        ),
                                      ),
                                      icon: const Icon(Icons.analytics_rounded,
                                          size: 16),
                                      label: const Text('View Energy Log',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Navigating to power usage analytics...')),
                                        );
                                      },
                                    ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          Colors.white.withValues(alpha: 0.7),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.02),
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
                                    child: const Text('Close',
                                        style: TextStyle(fontSize: 12)),
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
          ),
        ],
      ),
    );
  }
}
