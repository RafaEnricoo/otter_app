import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/firebase_service.dart';
import '../services/system_settings_service.dart';

class RfidManagementScreen extends StatefulWidget {
  const RfidManagementScreen({super.key});

  @override
  State<RfidManagementScreen> createState() => _RfidManagementScreenState();
}

class _RfidManagementScreenState extends State<RfidManagementScreen> {
  final _firebaseService = FirebaseService();
  final _uidController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late Color _activeAccent;
  double _glassOpacity = 0.05;

  @override
  void initState() {
    super.initState();
    _activeAccent = SystemSettingsService().activeAccent.value;
    _glassOpacity = SystemSettingsService().glassOpacity.value;
  }

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _registerCard() async {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      final uid = _uidController.text.trim().toUpperCase().replaceAll(' ', '');
      final name = _nameController.text.trim();

      await _firebaseService.addRfidCard(uid, name);

      _uidController.clear();
      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kartu RFID milik $name berhasil didaftarkan!'),
            backgroundColor: const Color(0xFF1E2020),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteCard(String uid, String name) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E2020),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4963), size: 24),
                SizedBox(width: 8),
                Text('Hapus Kartu RFID?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus akses kartu RFID milik $name ($uid)? Kartu ini tidak akan dapat membuka pintu lagi.',
              style: const TextStyle(color: Color(0xFFC6C6CE), height: 1.3),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Batal', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB4AB),
                  backgroundColor: const Color(0xFF93000A).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Hapus Akses', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  await _firebaseService.removeRfidCard(uid);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Akses kartu $name telah dihapus.')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                color: _activeAccent.withValues(alpha: 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
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
                color: const Color(0xFFBEC5E5).withValues(alpha: 0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // ─── Main Content ───
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildAddCardSection(),
                      const SizedBox(height: 24),
                      _buildCardListSection(),
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
          ClipOval(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                tooltip: 'Back',
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Kelola Kartu RFID',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFamily: 'Sora',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCardSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daftarkan Kartu Baru',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 16),

            // NAMA PEMILIK KARTU
            const Text(
              'NAMA PEMILIK KARTU',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _buildInputDecoration('Nama pemilik kartu...', Icons.person_outline_rounded),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama pemilik tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // KODE UID RFID (HEXA)
            const Text(
              'KODE UID RFID (HEXADECIMAL)',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uidController,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F\s]')),
              ],
              decoration: _buildInputDecoration('Contoh: A3 B2 C5 D1', Icons.nfc_rounded),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Kode UID tidak boleh kosong';
                }
                final clean = val.replaceAll(' ', '');
                if (clean.length < 4) {
                  return 'Kode UID terlalu pendek';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Register Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Daftarkan Kartu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: _registerCard,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardListSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daftar Kartu Terdaftar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Sora',
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Map<String, dynamic>>(
            stream: _firebaseService.getRfidCardsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Gagal memuat data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final cards = snapshot.data ?? {};
              if (cards.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      children: [
                        Icon(Icons.credit_card_off_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada kartu RFID terdaftar',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
                itemBuilder: (context, index) {
                  final key = cards.keys.elementAt(index);
                  final cardData = cards[key] as Map<dynamic, dynamic>;
                  final name = cardData['nama_pemilik'] ?? 'Tanpa Nama';
                  final status = cardData['status'] ?? 'aktif';
                  final isActive = status == 'aktif';

                  return Row(
                    children: [
                      // NFC Icon Badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isActive ? _activeAccent.withValues(alpha: 0.1) : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.nfc_rounded,
                          color: isActive ? _activeAccent : Colors.white24,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Card Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              key, // UID
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status Switch
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isActive,
                          activeColor: _activeAccent,
                          activeTrackColor: _activeAccent.withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.white38,
                          inactiveTrackColor: Colors.white12,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            final newStatus = val ? 'aktif' : 'nonaktif';
                            _firebaseService.updateRfidCardStatus(key, newStatus);
                          },
                        ),
                      ),

                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteCard(key, name),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, size: 18),
      prefixIconColor: MaterialStateColor.resolveWith((states) {
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
