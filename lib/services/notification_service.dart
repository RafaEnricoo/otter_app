import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Central Notification State
  final ValueNotifier<List<NotificationModel>> notificationsNotifier =
      ValueNotifier<List<NotificationModel>>([
    NotificationModel(
      id: 'notif_1',
      title: 'Backyard Intrusion Alert',
      message: 'Significant motion detected by backyard Cam-04 near the fence line. Security protocol initiated.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      category: NotificationCategory.security,
      priority: NotificationPriority.critical,
      isRead: false,
    ),
    NotificationModel(
      id: 'notif_2',
      title: 'Climate Sensor Offline',
      message: 'Living room temperature sensor node \'Node-T4\' failed to ping. Please inspect batteries.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      category: NotificationCategory.climate,
      priority: NotificationPriority.warning,
      isRead: false,
    ),
    NotificationModel(
      id: 'notif_3',
      title: 'Energy Target Achieved',
      message: 'Congratulations! Total power consumption this week was 18% below the baseline budget.',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      category: NotificationCategory.energy,
      priority: NotificationPriority.info,
      isRead: false,
    ),
    NotificationModel(
      id: 'notif_4',
      title: 'System Firmware Updated',
      message: 'Otter Core OS has successfully updated to version v4.12.0-stable with 8 security patches.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      category: NotificationCategory.system,
      priority: NotificationPriority.info,
      isRead: true,
    ),
    NotificationModel(
      id: 'notif_5',
      title: 'Critical Dehumidifier Trigger',
      message: 'Basement humidity spiked to 72%. Activated auto-exhaust fan to mitigate moisture build-up.',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      category: NotificationCategory.climate,
      priority: NotificationPriority.warning,
      isRead: true,
    ),
  ]);

  // List getter
  List<NotificationModel> get notifications => notificationsNotifier.value;

  // Unread count getter
  int get unreadCount =>
      notificationsNotifier.value.where((n) => !n.isRead).length;

  // Mark a specific notification as read
  void markAsRead(String id) {
    final updated = notificationsNotifier.value.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notificationsNotifier.value = updated;
  }

  // Mark all notifications as read
  void markAllAsRead() {
    final updated = notificationsNotifier.value.map((n) {
      return n.copyWith(isRead: true);
    }).toList();
    notificationsNotifier.value = updated;
  }

  // Delete a specific notification
  void deleteNotification(String id) {
    final updated = notificationsNotifier.value.where((n) => n.id != id).toList();
    notificationsNotifier.value = updated;
  }

  // Clear all notifications
  void clearAll() {
    notificationsNotifier.value = [];
  }

  // Add a new mock notification for demonstration
  void triggerMockNotification() {
    final categories = NotificationCategory.values;
    final priorities = NotificationPriority.values;
    
    final id = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now();
    
    // Create an arbitrary notification
    late NotificationModel mock;
    final index = notificationsNotifier.value.length % 3;
    
    if (index == 0) {
      mock = NotificationModel(
        id: id,
        title: 'Smart Lock Auto-Locked',
        message: 'Front door locked automatically after remaining idle for 5 minutes.',
        timestamp: timestamp,
        category: NotificationCategory.security,
        priority: NotificationPriority.info,
      );
    } else if (index == 1) {
      mock = NotificationModel(
        id: id,
        title: 'High Thermal Demand',
        message: 'Outdoor temperature reached 36°C. Switched living room AC to Eco Cooling.',
        timestamp: timestamp,
        category: NotificationCategory.climate,
        priority: NotificationPriority.warning,
      );
    } else {
      mock = NotificationModel(
        id: id,
        title: 'Excess Solar Production',
        message: 'Solar battery array fully charged. Routing excess 1.2 kW power back to local grid.',
        timestamp: timestamp,
        category: NotificationCategory.energy,
        priority: NotificationPriority.info,
      );
    }

    final updated = List<NotificationModel>.from(notificationsNotifier.value)..insert(0, mock);
    notificationsNotifier.value = updated;
  }

  void addNotification({
    required String title,
    required String message,
    required NotificationCategory category,
    required NotificationPriority priority,
  }) {
    final id = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final newNotif = NotificationModel(
      id: id,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      category: category,
      priority: priority,
    );
    final updated = List<NotificationModel>.from(notificationsNotifier.value)..insert(0, newNotif);
    notificationsNotifier.value = updated;
  }
}
