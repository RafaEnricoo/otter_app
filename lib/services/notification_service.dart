import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import 'firebase_service.dart';
import 'system_settings_service.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _dbRef = FirebaseDatabase.instance.ref('otter_smarthome/notifikasi');
  bool _isInitialized = false;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Central Notification State
  final ValueNotifier<List<NotificationModel>> notificationsNotifier =
      ValueNotifier<List<NotificationModel>>([]);

  // Notifier for newly received notification (for floating banner overlay)
  final ValueNotifier<NotificationModel?> newNotificationNotifier =
      ValueNotifier<NotificationModel?>(null);

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool get _isOnline => !FirebaseService().isUsingFallback;

  void init() {
    if (_isInitialized) return;

    _initLocalNotifications();

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

            // Check if there is a NEW notification added remotely
            final currentList = notificationsNotifier.value;
            if (currentList.isNotEmpty && list.isNotEmpty) {
              final newest = list.first;
              final alreadyExists = currentList.any((n) => n.id == newest.id);
              if (!alreadyExists) {
                // Trigger overlay and sound for the new remote notification!
                newNotificationNotifier.value = newest;
                _playNotificationFeedback(newest.priority);
                _showNativeNotification(newest);
              }
            }

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

  void _playNotificationFeedback(NotificationPriority priority) async {
    final settings = SystemSettingsService();
    if (settings.enableNotificationSound.value) {
      try {
        final String soundPath = (priority == NotificationPriority.critical)
            ? 'sounds/error.wav'
            : 'sounds/notification.mp3';
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(soundPath));
      } catch (e) {
        debugPrint("Gagal memutar suara notifikasi: $e");
      }
    }

    if (settings.enableVibration.value) {
      try {
        if (await Vibration.hasVibrator() ?? false) {
          if (priority == NotificationPriority.critical) {
            Vibration.vibrate(pattern: [0, 200, 100, 200]);
          } else {
            Vibration.vibrate(duration: 80);
          }
        }
      } catch (e) {
        debugPrint("Gagal menjalankan getaran: $e");
      }
    }
  }

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

    // Trigger overlay notifier
    newNotificationNotifier.value = newNotif;
    _playNotificationFeedback(priority);
    _showNativeNotification(newNotif);

    if (_isOnline) {
      _dbRef.child(id).set(newNotif.toMap());
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'otter_channel_id',
        'Otter Smart Home Notifications',
        description: 'This channel is used for smart home notifications.',
        importance: Importance.high,
        playSound: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint("Gagal inisialisasi native notifications: $e");
    }
  }

  void _showNativeNotification(NotificationModel notif) async {
    final settings = SystemSettingsService();
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'otter_channel_id',
        'Otter Smart Home Notifications',
        channelDescription: 'This channel is used for smart home notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: settings.enableNotificationSound.value,
      );
      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        notif.hashCode,
        notif.title,
        notif.message,
        platformChannelSpecifics,
        payload: 'notification',
      );
    } catch (e) {
      debugPrint("Gagal memicu native notification: $e");
    }
  }
}
