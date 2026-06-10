import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/notification_tile.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();
  String _selectedCategory = 'All'; // 'All', 'Security', 'Climate', 'Energy', 'System'
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Filter mapper
  NotificationCategory? _getCategoryEnum(String name) {
    switch (name) {
      case 'Security':
        return NotificationCategory.security;
      case 'Climate':
        return NotificationCategory.climate;
      case 'Energy':
        return NotificationCategory.energy;
      case 'System':
        return NotificationCategory.system;
      default:
        return null;
    }
  }

  // Handle pull-to-refresh
  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _service.triggerMockNotification();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      body: Stack(
        children: [
          // ─── Ambient Glow Gradients ───
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F4FE).withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBEC5E5).withOpacity(0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // ─── Main Content ───
          SafeArea(
            child: ValueListenableBuilder<List<NotificationModel>>(
              valueListenable: _service.notificationsNotifier,
              builder: (context, allNotifications, child) {
                // Filter logic
                final targetCategory = _getCategoryEnum(_selectedCategory);
                final filteredList = targetCategory == null
                    ? allNotifications
                    : allNotifications.where((n) => n.category == targetCategory).toList();

                final unreadCount = allNotifications.where((n) => !n.isRead).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Custom Header
                    _buildHeader(context, unreadCount),

                    // Filter Chips Row
                    _buildFilterBar(),

                    const SizedBox(height: 12),

                    // Notifications List or Empty State
                    Expanded(
                      child: filteredList.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: const Color(0xFF00F4FE),
                              backgroundColor: const Color(0xFF1E2020),
                              strokeWidth: 2.5,
                              onRefresh: _handleRefresh,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  return NotificationTile(
                                    key: ValueKey(item.id),
                                    notification: item,
                                    onDismissed: () {
                                      setState(() {
                                        _service.deleteNotification(item.id);
                                      });
                                    },
                                    onMarkedRead: () {
                                      setState(() {
                                        _service.markAsRead(item.id);
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Header UI with title and actions
  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Row(
        children: [
          // Elegant Back button
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

          // Screen Title & Badge count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Notifikasi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    fontFamily: 'Sora',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount > 0 ? '$unreadCount pesan belum dibaca' : 'Semua sudah terbaca!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: unreadCount > 0 ? const Color(0xFF00F4FE) : Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),

          // Header Actions
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Color(0xFF00F4FE), size: 22),
              tooltip: 'Tandai semua terbaca',
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _service.markAllAsRead();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua notifikasi ditandai sudah dibaca.')),
                );
              },
            ),
          IconButton(
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 22,
            ),
            tooltip: 'Hapus semua',
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showClearAllDialog();
            },
          ),
        ],
      ),
    );
  }

  // Filter Tabs
  Widget _buildFilterBar() {
    final categories = ['All', 'Security', 'Climate', 'Energy', 'System'];
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedCategory = cat;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00F4FE).withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00F4FE).withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00F4FE).withOpacity(0.12),
                          blurRadius: 10,
                          spreadRadius: -1,
                        )
                      ]
                    : [],
              ),
              child: Text(
                cat == 'All' ? 'Semua' :
                cat == 'Security' ? 'Keamanan' :
                cat == 'Climate' ? 'Iklim' :
                cat == 'Energy' ? 'Energi' :
                cat == 'System' ? 'Sistem' : cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF00F4FE) : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Clear All Confirmation Overlay
  void _showClearAllDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E2020),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4963), size: 24),
                SizedBox(width: 8),
                Text('Hapus Kotak Masuk?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              'Apakah Anda yakin ingin menghapus semua notifikasi? Tindakan ini tidak dapat dibatalkan.',
              style: TextStyle(color: Color(0xFFC6C6CE), height: 1.3),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Batal', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB4AB),
                  backgroundColor: const Color(0xFF93000A).withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _service.clearAll();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Beautiful visual Empty State
  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeController,
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Allows pull to refresh even when empty
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating / Floating Glass Orb
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00F4FE).withOpacity(0.12),
                          const Color(0xFF00F4FE).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.blur_on_rounded,
                        size: 40,
                        color: Color(0xFF00F4FE),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Kotak Masuk Kosong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  fontFamily: 'Sora',
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'Rumah pintar Anda berjalan normal. Tarik ke bawah untuk memindai pembaruan sistem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Manual simulate button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F4FE).withOpacity(0.08),
                  foregroundColor: const Color(0xFF00F4FE),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF00F4FE), width: 0.5),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Pindai Perangkat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                onPressed: _handleRefresh,
              ),
              const SizedBox(height: 80), // Offset for list scroll feel
            ],
          ),
        ),
      ),
    );
  }
}
