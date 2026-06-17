import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import 'smarthome_service.dart';
import 'system_settings_service.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Background FCM Message: ${message.messageId}");
  }

  bool _isInitialized = false;
  Timer? _pollingTimer;

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

  bool get _isOnline => !SmartHomeService().isUsingFallback;

  void init() {
    if (_isInitialized) return;

    _initLocalNotifications();
    _initFirebaseMessaging();

    // Start periodic polling for notifications (every 2 seconds)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isOnline) return;

      try {
        final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/notifications')).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final List<dynamic> rawList = jsonDecode(res.body);
          final List<NotificationModel> list = [];

          for (var item in rawList) {
            final model = NotificationModel.fromMap(item as Map<String, dynamic>);
            if (model.title.trim().isNotEmpty &&
                model.message.trim().isNotEmpty &&
                model.category != NotificationCategory.energy) {
              list.add(model);
            }
          }

          // Sort notifications by timestamp descending (newest first)
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          // Check if there is a NEW notification added remotely
          final currentList = notificationsNotifier.value;
          if (currentList.isNotEmpty && list.isNotEmpty) {
            final newest = list.first;
            final alreadyExists = currentList.any((n) => n.id == newest.id);
            if (!alreadyExists) {
              newNotificationNotifier.value = newest;
              _playNotificationFeedback(newest.priority);
              _showNativeNotification(newest);
            }
          }

          notificationsNotifier.value = list;
        }
      } catch (e) {
        debugPrint("Gagal polling data notifikasi dari server: $e");
      }
    });

    _isInitialized = true;
  }

  // List getter
  List<NotificationModel> get notifications => notificationsNotifier.value;

  // Unread count getter
  int get unreadCount =>
      notificationsNotifier.value.where((n) => !n.isRead).length;

  // Mark a specific notification as read
  void markAsRead(String id) async {
    final updated = notificationsNotifier.value.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notificationsNotifier.value = updated;

    if (_isOnline) {
      try {
        await http.put(Uri.parse('${AppConfig.apiBaseUrl}/notifications/$id/read'));
      } catch (e) {
        debugPrint("Gagal markAsRead ke server: $e");
      }
    }
  }

  // Mark all notifications as read
  void markAllAsRead() async {
    final updated = notificationsNotifier.value.map((n) {
      return n.copyWith(isRead: true);
    }).toList();
    notificationsNotifier.value = updated;

    if (_isOnline) {
      try {
        await http.put(Uri.parse('${AppConfig.apiBaseUrl}/notifications/read-all'));
      } catch (e) {
        debugPrint("Gagal markAllAsRead ke server: $e");
      }
    }
  }

  // Delete a specific notification
  void deleteNotification(String id) async {
    final updated = notificationsNotifier.value.where((n) => n.id != id).toList();
    notificationsNotifier.value = updated;

    if (_isOnline) {
      try {
        await http.delete(Uri.parse('${AppConfig.apiBaseUrl}/notifications/$id'));
      } catch (e) {
        debugPrint("Gagal deleteNotification dari server: $e");
      }
    }
  }

  // Clear all notifications
  void clearAll() async {
    notificationsNotifier.value = [];

    if (_isOnline) {
      try {
        await http.delete(Uri.parse('${AppConfig.apiBaseUrl}/notifications'));
      } catch (e) {
        debugPrint("Gagal clearAll ke server: $e");
      }
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
  }) async {
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

    newNotificationNotifier.value = newNotif;
    _playNotificationFeedback(priority);
    _showNativeNotification(newNotif);

    if (_isOnline) {
      try {
        await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/notifications'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(newNotif.toMap()),
        );
      } catch (e) {
        debugPrint("Gagal addNotification ke server: $e");
      }
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

  Future<void> _initFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await messaging.subscribeToTopic('otter_home');
      debugPrint("FCM: Subscribed to topic 'otter_home'");

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("FCM Foreground: ${message.notification?.title}");
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint("FCM Initialization error: $e");
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
  }
}
