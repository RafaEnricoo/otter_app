import 'dart:async';
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
                list.add(NotificationModel.fromMap(value));
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
    if (_isOnline) {
      _dbRef.child('$id/isRead').set(true);
    } else {
      final updated = notificationsNotifier.value.map((n) {
        if (n.id == id) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      notificationsNotifier.value = updated;
    }
  }

  // Mark all notifications as read
  void markAllAsRead() {
    if (_isOnline) {
      final updates = <String, dynamic>{};
      for (var n in notificationsNotifier.value) {
        updates['${n.id}/isRead'] = true;
      }
      if (updates.isNotEmpty) {
        _dbRef.update(updates);
      }
    } else {
      final updated = notificationsNotifier.value.map((n) {
        return n.copyWith(isRead: true);
      }).toList();
      notificationsNotifier.value = updated;
    }
  }

  // Delete a specific notification
  void deleteNotification(String id) {
    if (_isOnline) {
      _dbRef.child(id).remove();
    } else {
      final updated = notificationsNotifier.value.where((n) => n.id != id).toList();
      notificationsNotifier.value = updated;
    }
  }

  // Clear all notifications
  void clearAll() {
    if (_isOnline) {
      _dbRef.remove();
    } else {
      notificationsNotifier.value = [];
    }
  }

  // Add a new mock notification for demonstration
  void triggerMockNotification() {
    final id = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now();
    late NotificationModel mock;
    final index = notificationsNotifier.value.length % 3;

    if (index == 0) {
      mock = NotificationModel(
        id: id,
        title: 'Smart Lock Mengunci Otomatis',
        message: 'Pintu utama berhasil dikunci otomatis setelah tidak aktif selama 5 menit.',
        timestamp: timestamp,
        category: NotificationCategory.security,
        priority: NotificationPriority.info,
      );
    } else if (index == 1) {
      mock = NotificationModel(
        id: id,
        title: 'Beban Suhu Tinggi',
        message: 'Suhu luar ruangan mencapai 36°C. Mengubah AC Ruang Tamu ke mode pendinginan hemat.',
        timestamp: timestamp,
        category: NotificationCategory.climate,
        priority: NotificationPriority.warning,
      );
    } else {
      mock = NotificationModel(
        id: id,
        title: 'Produksi Energi Berlebih',
        message: 'Panel surya terisi penuh. Mengalirkan sisa daya 1.2 kW ke jaringan listrik lokal.',
        timestamp: timestamp,
        category: NotificationCategory.energy,
        priority: NotificationPriority.info,
      );
    }

    if (_isOnline) {
      _dbRef.child(id).set(mock.toMap());
    } else {
      final updated = List<NotificationModel>.from(notificationsNotifier.value)..insert(0, mock);
      notificationsNotifier.value = updated;
    }
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

    if (_isOnline) {
      _dbRef.child(id).set(newNotif.toMap());
    } else {
      final updated = List<NotificationModel>.from(notificationsNotifier.value)..insert(0, newNotif);
      notificationsNotifier.value = updated;
    }
  }
}
