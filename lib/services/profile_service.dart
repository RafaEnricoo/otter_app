import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;

  final _profileRef = FirebaseDatabase.instance.ref('otter_smarthome/profile');

  final ValueNotifier<String> username = ValueNotifier<String>('admin');
  final ValueNotifier<String> password = ValueNotifier<String>('admin123');
  final ValueNotifier<String> displayName = ValueNotifier<String>('Mimah Dudim');
  final ValueNotifier<String> role = ValueNotifier<String>('Administrator Rumah Pintar');
  final ValueNotifier<String> avatarUrl = ValueNotifier<String>('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80');

  ProfileService._internal() {
    // Check if profile exists, if not, seed it with default values
    _profileRef.get().then((snapshot) {
      if (!snapshot.exists) {
        _profileRef.set({
          'username': 'admin',
          'password': 'admin123',
          'display_name': 'Mimah Dudim',
          'role': 'Administrator Rumah Pintar',
          'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        });
      }
    }).catchError((err) {
      debugPrint("Error checking profile existence: $err");
    });

    // Listen to profile updates from Firebase Realtime Database
    _profileRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        username.value = data['username']?.toString() ?? 'admin';
        password.value = data['password']?.toString() ?? 'admin123';
        displayName.value = data['display_name']?.toString() ?? 'Mimah Dudim';
        role.value = data['role']?.toString() ?? 'Administrator Rumah Pintar';
        avatarUrl.value = data['avatar_url']?.toString() ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80';
      }
    }, onError: (err) {
      debugPrint("Error listening to profile changes: $err");
    });
  }

  Future<void> updateProfile({
    required String newDisplayName,
    required String newRole,
    required String newUsername,
    required String newPassword,
    required String newAvatarUrl,
  }) async {
    displayName.value = newDisplayName;
    role.value = newRole;
    username.value = newUsername;
    password.value = newPassword;
    avatarUrl.value = newAvatarUrl;

    try {
      await _profileRef.update({
        'username': newUsername,
        'password': newPassword,
        'display_name': newDisplayName,
        'role': newRole,
        'avatar_url': newAvatarUrl,
      });
    } catch (e) {
      debugPrint("Gagal sinkronisasi update profile ke Firebase: $e");
    }
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
