import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/system_settings_service.dart';
import '../core/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _profile = ProfileService();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _userController;
  late TextEditingController _passwordController;
  
  late String _currentAvatarUrl;
  bool _obscurePassword = true;
  bool _isUploading = false;
  late Color _activeAccent;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _profile.displayName.value);
    _roleController = TextEditingController(text: _profile.role.value);
    _userController = TextEditingController(text: _profile.username.value);
    _passwordController = TextEditingController(text: _profile.password.value);
    _currentAvatarUrl = _profile.avatarUrl.value;
    _activeAccent = SystemSettingsService().activeAccent.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.mediumImpact();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUrl = 'data:image/jpeg;base64,$base64String';

        setState(() {
          _currentAvatarUrl = dataUrl;
          _isUploading = false;
        });

        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diunggah!'),
            backgroundColor: Color(0xFF1E2020),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar dari galeri: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _saveProfile() async {
    HapticFeedback.heavyImpact();
    
    // Save to profile service
    await _profile.updateProfile(
      newDisplayName: _nameController.text.trim(),
      newRole: _roleController.text.trim(),
      newUsername: _userController.text.trim(),
      newPassword: _passwordController.text,
      newAvatarUrl: _currentAvatarUrl,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glassOpacity = SystemSettingsService().glassOpacity.value;

    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      body: Stack(
        children: [
          // ─── Ambient Glow Gradients ───
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeAccent.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 95, sigmaY: 95),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBEC5E5).withValues(alpha: 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 95, sigmaY: 95),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // ─── Main Form UI ───
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(context),

                // Form Contents
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Avatar Editor Section
                      _buildAvatarEditorSection(glassOpacity),
                      const SizedBox(height: 24),

                      // Input Fields Card
                      _buildFieldsSection(glassOpacity),
                      const SizedBox(height: 32),

                      // Save Button
                      _buildSaveButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
          const Text(
            'Edit Profil',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              fontFamily: 'Sora',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarEditorSection(double glassOpacity) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: glassOpacity),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Large circular image preview
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing Aura Ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _activeAccent,
                        _activeAccent.withValues(alpha: 0.1),
                        const Color(0xFFBEC5E5).withValues(alpha: 0.3),
                        _activeAccent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _activeAccent.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Main circular avatar photo or initials fallback
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E2020),
                  ),
                  child: _currentAvatarUrl.isEmpty
                      ? Center(
                          child: Text(
                            _profile.initials,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: _activeAccent,
                              fontFamily: 'Sora',
                            ),
                          ),
                        )
                      : ClipOval(
                          child: _currentAvatarUrl.startsWith('data:image') && _currentAvatarUrl.contains('base64,')
                              ? Image.memory(
                                  base64Decode(_currentAvatarUrl.split('base64,')[1]),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _currentAvatarUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => Center(
                                    child: Icon(Icons.person_rounded, color: _activeAccent, size: 40),
                                  ),
                                ),
                        ),
                ),
                // Upload Overlay Spinner
                if (_isUploading)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_activeAccent),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upload and Delete buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom Gallery Upload Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Galeri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: _isUploading ? null : _pickFromGallery,
              ),
              if (_currentAvatarUrl.isNotEmpty) ...[
                const SizedBox(width: 12),
                // Remove photo button to fallback to initials
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFFF3B30),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: const Color(0xFFFF3B30).withValues(alpha: 0.2)),
                    ),
                  ),
                  icon: const Icon(Icons.delete_rounded, size: 16),
                  label: const Text('Hapus Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _currentAvatarUrl = '';
                    });
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsSection(double glassOpacity) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: glassOpacity),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NAMA LENGKAP
          _buildInputLabel('NAMA LENGKAP'),
          _buildTextField(
            controller: _nameController,
            hint: 'Masukkan nama Anda...',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 20),

          // PERAN / JABATAN
          _buildInputLabel('PERAN / JABATAN'),
          _buildTextField(
            controller: _roleController,
            hint: 'Contoh: Administrator Rumah',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 20),

          // USERNAME
          _buildInputLabel('USERNAME'),
          _buildTextField(
            controller: _userController,
            hint: 'Username untuk login...',
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 20),

          // PASSWORD
          _buildInputLabel('PASSWORD'),
          _buildTextField(
            controller: _passwordController,
            hint: 'Password untuk login...',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: Icon(icon, size: 18),
          prefixIconColor: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.focused)) {
              return _activeAccent;
            }
            return Colors.white38;
          }),
          suffixIcon: suffix,
          suffixIconColor: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.focused)) {
              return _activeAccent;
            }
            return Colors.white38;
          }),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _activeAccent.withValues(alpha: 0.5), width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _activeAccent,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: _isUploading ? null : _saveProfile,
      child: const Text(
        'Simpan Perubahan Profil',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }


}
