import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late TextEditingController _avatarUrlController;
  
  late String _currentAvatarUrl;
  bool _obscurePassword = true;
  bool _isUploading = false;
  late Color _activeAccent;

  // Preset Avatars for quick selection
  final List<String> _presetAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80', // Default Women
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80', // Men Glass
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80', // Tech Woman
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80', // Tech Man
    'https://api.dicebear.com/7.x/bottts/png?seed=otter1&backgroundColor=1e2020', // Cyber Bot 1
    'https://api.dicebear.com/7.x/bottts/png?seed=otter2&backgroundColor=1e2020', // Cyber Bot 2
  ];

  // Gallery simulation photos
  final List<String> _simulatedGallery = [
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=200&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _profile.displayName.value);
    _roleController = TextEditingController(text: _profile.role.value);
    _userController = TextEditingController(text: _profile.username.value);
    _passwordController = TextEditingController(text: _profile.password.value);
    _avatarUrlController = TextEditingController(text: _profile.avatarUrl.value);
    _currentAvatarUrl = _profile.avatarUrl.value;
    _activeAccent = SystemSettingsService().activeAccent.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _simulateUpload() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isUploading = true;
    });

    // Simulate standard gallery image selection & upload progress
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      // Pick a random image from simulated gallery
      final randomImage = (_simulatedGallery..shuffle()).first;
      setState(() {
        _currentAvatarUrl = randomImage;
        _avatarUrlController.text = randomImage;
        _isUploading = false;
      });
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto berhasil diunggah dari galeri!'),
          backgroundColor: Color(0xFF1E2020),
          duration: Duration(seconds: 1),
        ),
      );
    });
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
                // Main circular avatar photo
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1E2020),
                  backgroundImage: NetworkImage(_currentAvatarUrl),
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

          // Upload and Select buttons
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
                onPressed: _isUploading ? null : _simulateUpload,
              ),
              const SizedBox(width: 12),
              // Preset Avatar picker dialog trigger
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _activeAccent.withValues(alpha: 0.1),
                  foregroundColor: _activeAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _activeAccent.withValues(alpha: 0.2)),
                  ),
                ),
                icon: const Icon(Icons.face_retouching_natural_rounded, size: 16),
                label: const Text('Preset Avatar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _showPresetAvatarsSelector(),
              ),
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
          const SizedBox(height: 20),

          // CUSTOM AVATAR URL
          _buildInputLabel('URL FOTO KUSTOM'),
          _buildTextField(
            controller: _avatarUrlController,
            hint: 'https://...',
            icon: Icons.link_rounded,
            onChanged: (val) {
              setState(() {
                _currentAvatarUrl = val.isNotEmpty ? val : _profile.avatarUrl.value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          suffixIcon: suffix,
          border: InputBorder.none,
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

  void _showPresetAvatarsSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2020),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Preset Avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Sora'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetAvatars.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final avatar = _presetAvatars[index];
                    final isSelected = _currentAvatarUrl == avatar;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _currentAvatarUrl = avatar;
                          _avatarUrlController.text = avatar;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _activeAccent : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(avatar),
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
