import 'package:flutter/material.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final ValueNotifier<String> username = ValueNotifier<String>('admin');
  final ValueNotifier<String> password = ValueNotifier<String>('admin123');
  final ValueNotifier<String> displayName = ValueNotifier<String>('Mimah Dudim');
  final ValueNotifier<String> role = ValueNotifier<String>('Administrator Rumah Pintar');

  void updateProfile({
    required String newDisplayName,
    required String newRole,
    required String newUsername,
    required String newPassword,
  }) {
    displayName.value = newDisplayName;
    role.value = newRole;
    username.value = newUsername;
    password.value = newPassword;
  }

  String get initials {
    if (displayName.value.isEmpty) return 'U';
    final parts = displayName.value.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}
