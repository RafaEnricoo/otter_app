import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';
import 'firebase_service.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _dbRef = FirebaseDatabase.instance.ref('otter_smarthome/notifikasi');
  bool _isInitialized = false;

  // Central Notification State
  final ValueNotifier<List<NotificationModel>> notificationsNotifier =
      ValueNotifier<List<NotificationModel>>([]);

  bool get _isOnline => !FirebaseService().isUsingFallback;

  void init() {
    if (_isInitialized) return;

    // Listen to Firebase database changes in real-time
    _dbRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final data = event.snapshot.value;
          if (data is Map) {
            final List<NotificationModel> list = [];
            data.forEach((key, value) {
              if (value is Map) {
                final model = NotificationModel.fromMap(value);
                // Filter out unimportant (empty title/message) and energy-related notifications
                if (model.title.trim().isNotEmpty &&
                    model.message.trim().isNotEmpty &&
                    model.category != NotificationCategory.energy) {
                  list.add(model);
                }
              }
            });
            // Sort notifications by timestamp descending (newest first)
            list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            notificationsNotifier.value = list;
          }
        } catch (e) {
          debugPrint("Gagal mengurai data notifikasi dari Firebase: $e");
        }
      } else {
        notificationsNotifier.value = [];
      }
    }, onError: (err) {
      debugPrint("Firebase notifikasi error, berjalan dalam mode lokal: $err");
      notificationsNotifier.value = [];
    });

    _isInitialized = true;
  }

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

    if (_isOnline) {
      _dbRef.child('$id/isRead').set(true);
    }
  }

  // Mark all notifications as read
  void markAllAsRead() {
    final updated = notificationsNotifier.value.map((n) {
      return n.copyWith(isRead: true);
    }).toList();
    notificationsNotifier.value = updated;

    if (_isOnline) {
      final updates = <String, dynamic>{};
      for (var n in updated) {
        updates['${n.id}/isRead'] = true;
      }
      if (updates.isNotEmpty) {
        _dbRef.update(updates);
      }
    }
  }

  // Delete a specific notification
  void deleteNotification(String id) {
    // Optimistic local update (crucial for Dismissible)
    final updated = notificationsNotifier.value.where((n) => n.id != id).toList();
    notificationsNotifier.value = updated;

    if (_isOnline) {
      _dbRef.child(id).remove();
    }
  }

  // Clear all notifications
  void clearAll() {
    notificationsNotifier.value = [];

    if (_isOnline) {
      _dbRef.remove();
    }
  }

  // Add a new mock notification for demonstration (no-op)
  void triggerMockNotification() {}

  void addNotification({
    required String title,
    required String message,
    required NotificationCategory category,
    required NotificationPriority priority,
  }) {
    // Filter out energy and empty notifications at the entry point
    if (category == NotificationCategory.energy) return;
    if (title.trim().isEmpty || message.trim().isEmpty) return;

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

    if (_isOnline) {
      _dbRef.child(id).set(newNotif.toMap());
    }
  }
}
