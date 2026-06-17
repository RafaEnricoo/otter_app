import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

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

    // 1. Ambil data lokal terlebih dahulu dari SharedPreferences (offline cache)
    username.value = _prefs.getString('profile_username') ?? 'admin';
    password.value = _prefs.getString('profile_password') ?? '1234';
    displayName.value = _prefs.getString('profile_display_name') ?? 'Mimah Dudim';
    role.value = _prefs.getString('profile_role') ?? 'Administrator Rumah Pintar';
    avatarUrl.value = _prefs.getString('profile_avatar_url') ?? '';
    _updateAvatarBytes(avatarUrl.value);

    // 2. Ambil data aktual secara dinamis dari database PostgreSQL server Golang
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/profile')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        username.value = data['username'] ?? username.value;
        password.value = data['password'] ?? password.value;
        displayName.value = data['display_name'] ?? displayName.value;
        role.value = data['role'] ?? role.value;
        avatarUrl.value = data['avatar_url'] ?? avatarUrl.value;
        _updateAvatarBytes(avatarUrl.value);

        // Perbarui cache lokal
        await _prefs.setString('profile_username', username.value);
        await _prefs.setString('profile_password', password.value);
        await _prefs.setString('profile_display_name', displayName.value);
        await _prefs.setString('profile_role', role.value);
        await _prefs.setString('profile_avatar_url', avatarUrl.value);
      }
    } catch (e) {
      debugPrint("Gagal mengambil profil dari database server, memakai data lokal: $e");
    }

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

    // Simpan ke cache lokal SharedPreferences
    await _prefs.setString('profile_username', newUsername);
    await _prefs.setString('profile_password', newPassword);
    await _prefs.setString('profile_display_name', newDisplayName);
    await _prefs.setString('profile_role', newRole);
    await _prefs.setString('profile_avatar_url', newAvatarUrl);

    // Kirim sinkronisasi update ke database PostgreSQL
    try {
      await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': newUsername,
          'password': newPassword,
          'display_name': newDisplayName,
          'role': newRole,
          'avatar_url': newAvatarUrl,
        }),
      );
    } catch (e) {
      debugPrint("Gagal mengirim pembaruan profil ke database: $e");
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
