import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  final ValueNotifier<String> username = ValueNotifier<String>('admin');
  final ValueNotifier<String> password = ValueNotifier<String>('1234');
  final ValueNotifier<String> displayName = ValueNotifier<String>('Mimah Dudim');
  final ValueNotifier<String> role = ValueNotifier<String>('Administrator Rumah Pintar');
  final ValueNotifier<String> avatarUrl = ValueNotifier<String>('');
  final ValueNotifier<Uint8List?> avatarBytes = ValueNotifier<Uint8List?>(null);

  void _updateAvatarBytes(String url) {
    if (url.startsWith('data:image') && url.contains('base64,')) {
      try {
        final base64Str = url.split('base64,')[1];
        avatarBytes.value = base64Decode(base64Str);
      } catch (e) {
        avatarBytes.value = null;
      }
    } else {
      avatarBytes.value = null;
    }
  }

  ProfileService._internal() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    username.value = _prefs.getString('profile_username') ?? 'admin';
    password.value = _prefs.getString('profile_password') ?? '1234';
    displayName.value = _prefs.getString('profile_display_name') ?? 'Mimah Dudim';
    role.value = _prefs.getString('profile_role') ?? 'Administrator Rumah Pintar';
    avatarUrl.value = _prefs.getString('profile_avatar_url') ?? '';
    _updateAvatarBytes(avatarUrl.value);

    _isInitialized = true;
  }

  Future<void> updateProfile({
    required String newDisplayName,
    required String newRole,
    required String newUsername,
    required String newPassword,
    required String newAvatarUrl,
  }) async {
    if (!_isInitialized) await _init();

    displayName.value = newDisplayName;
    role.value = newRole;
    username.value = newUsername;
    password.value = newPassword;
    if (avatarUrl.value != newAvatarUrl) {
      avatarUrl.value = newAvatarUrl;
      _updateAvatarBytes(newAvatarUrl);
    }

    await _prefs.setString('profile_username', newUsername);
    await _prefs.setString('profile_password', newPassword);
    await _prefs.setString('profile_display_name', newDisplayName);
    await _prefs.setString('profile_role', newRole);
    await _prefs.setString('profile_avatar_url', newAvatarUrl);
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
