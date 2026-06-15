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

  void _showSuccessDialog(String title, String message, {IconData icon = Icons.check_circle_rounded, Color? iconColor}) {
    final activeColor = iconColor ?? _activeAccent;
    HapticFeedback.lightImpact();
    showDialog(
      context: this.context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: activeColor.withValues(alpha: 0.15), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: activeColor.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: activeColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC6C6CE),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(120, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(dialogContext).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _registerCard() async {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      final uid = _uidController.text.trim().toUpperCase().replaceAll(' ', '');
      final name = _nameController.text.trim();

      await _firebaseService.addRfidCard(uid, name);

      _uidController.clear();
      _nameController.clear();

      _showSuccessDialog(
        'Pendaftaran Sukses',
        'Kartu RFID milik $name telah berhasil didaftarkan ke sistem.',
      );
    }
  }

  void _deleteCard(String uid, String name) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: this.context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
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
                Navigator.of(dialogContext).pop();
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
                final nameVal = name;
                Navigator.of(dialogContext).pop();
                await Future.delayed(const Duration(milliseconds: 350));
                await _firebaseService.removeRfidCard(uid);
                _showSuccessDialog(
                  'Akses Dihapus',
                  'Akses kartu RFID milik $nameVal telah berhasil dihapus dari sistem.',
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFFF4963),
                );
              },
            ),
          ],
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

  void _showApproveDialog(String uid) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: this.context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext dialogContext) {
        return _ApproveRfidDialog(
          uid: uid,
          activeAccent: _activeAccent,
          onApprove: (name) async {
            await _firebaseService.approveRfidCard(uid, name);
            _showSuccessDialog(
              'Kartu Diaktifkan',
              'Kartu RFID dengan UID $uid berhasil diaktifkan untuk $name.',
            );
          },
        );
      },
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
      child: StreamBuilder<Map<String, dynamic>>(
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

          final allCards = snapshot.data ?? {};
          if (allCards.isEmpty) {
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

          // Pisahkan berdasarkan status
          final pendingCards = <String, Map>{};
          final registeredCards = <String, Map>{};

          allCards.forEach((key, value) {
            final cardData = value as Map;
            final status = cardData['status'] ?? 'aktif';
            if (status == 'menunggu') {
              pendingCards[key] = cardData;
            } else {
              registeredCards[key] = cardData;
            }
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── SECTION 1: PERMINTAAN PENDAFTARAN (PENDING APPROVAL) ───
              if (pendingCards.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Permintaan Pendaftaran',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                        fontFamily: 'Sora',
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingCards.length}',
                        style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingCards.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
                  itemBuilder: (context, index) {
                    final key = pendingCards.keys.elementAt(index);
                    final cardData = pendingCards[key]!;
                    final name = cardData['nama_pemilik'] ?? 'Kartu Baru Terdeteksi';

                    return Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.nfc_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                key,
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
                        // Approve Button
                        IconButton(
                          icon: Icon(Icons.check_circle_outline_rounded, color: _activeAccent, size: 22),
                          onPressed: () => _showApproveDialog(key),
                          tooltip: 'Setujui',
                        ),
                        // Reject Button
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22),
                          onPressed: () => _deleteCard(key, name),
                          tooltip: 'Tolak',
                        ),
                      ],
                    );
                  },
                ),
                if (registeredCards.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12, height: 2),
                  const SizedBox(height: 20),
                ],
              ],

              // ─── SECTION 2: DAFTAR KARTU TERDAFTAR ───
              if (registeredCards.isNotEmpty) ...[
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
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: registeredCards.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
                  itemBuilder: (context, index) {
                    final key = registeredCards.keys.elementAt(index);
                    final cardData = registeredCards[key]!;
                    final name = cardData['nama_pemilik'] ?? 'Tanpa Nama';
                    final status = cardData['status'] ?? 'aktif';
                    final isActive = status == 'aktif';

                    return Row(
                      children: [
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
                                key,
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
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteCard(key, name),
                        ),
                      ],
                    );
                  },
                ),
              ] else if (pendingCards.isEmpty) ...[
                Center(
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
                ),
              ],
            ],
          );
        },
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

class _ApproveRfidDialog extends StatefulWidget {
  final String uid;
  final Color activeAccent;
  final Function(String) onApprove;

  const _ApproveRfidDialog({
    required this.uid,
    required this.activeAccent,
    required this.onApprove,
  });

  @override
  State<_ApproveRfidDialog> createState() => _ApproveRfidDialogState();
}

class _ApproveRfidDialogState extends State<_ApproveRfidDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, size: 18),
      prefixIconColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.focused)) {
          return widget.activeAccent;
        }
        return Colors.white38;
      }),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.activeAccent.withValues(alpha: 0.5), width: 1.5),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2020),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      title: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: widget.activeAccent, size: 24),
          const SizedBox(width: 8),
          const Text('Setujui Kartu RFID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan nama pemilik untuk kartu dengan UID: ${widget.uid}',
              style: const TextStyle(color: Color(0xFFC6C6CE), fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'NAMA PEMILIK',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _buildInputDecoration('Nama pemilik kartu...', Icons.person_outline_rounded),
              autofocus: true,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                return null;
              },
            ),
          ],
        ),
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
            foregroundColor: Colors.black,
            backgroundColor: widget.activeAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Setujui & Aktifkan', style: TextStyle(fontWeight: FontWeight.w600)),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              HapticFeedback.heavyImpact();
              final name = _nameController.text.trim();
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 350));
              widget.onApprove(name);
            }
          },
        ),
      ],
    );
  }
}
