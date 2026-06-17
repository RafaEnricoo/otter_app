enum NotificationCategory {
  security,
  climate,
  energy,
  system,
}

enum NotificationPriority {
  critical,
  warning,
  info,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final NotificationPriority priority;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    required this.priority,
    this.isRead = false,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationCategory? category,
    NotificationPriority? priority,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'category': category.name,
      'priority': priority.name,
      'is_read': isRead,
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<dynamic, dynamic> map) {
    return NotificationModel(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      message: (map['message'] ?? '') as String,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      category: NotificationCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => NotificationCategory.system,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => NotificationPriority.info,
      ),
      isRead: (map['is_read'] ?? map['isRead'] ?? false) as bool,
    );
  }
}
