import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/smarthome_service.dart';

class FloatingNotificationBanner extends StatefulWidget {
  const FloatingNotificationBanner({super.key});

  @override
  State<FloatingNotificationBanner> createState() => _FloatingNotificationBannerState();
}

class _FloatingNotificationBannerState extends State<FloatingNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  NotificationModel? _currentNotif;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<double>(begin: -180.0, end: 16.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    NotificationService().newNotificationNotifier.addListener(_onNewNotification);
  }

  @override
  void dispose() {
    NotificationService().newNotificationNotifier.removeListener(_onNewNotification);
    _controller.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _onNewNotification() {
    final notif = NotificationService().newNotificationNotifier.value;
    if (notif != null) {
      _dismissTimer?.cancel();
      setState(() {
        _currentNotif = notif;
      });
      _controller.forward();

      // Auto-dismiss after 7 seconds unless it requires action
      _dismissTimer = Timer(const Duration(seconds: 7), () {
        _hide();
      });
    }
  }

  void _hide() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentNotif = null;
        });
        NotificationService().newNotificationNotifier.value = null;
      }
    });
  }

  String? _extractUid(String message) {
    // Regex to match Hex UID (typically 8 to 10 chars, upper/lower case hex, optionally colon-separated)
    final regExp = RegExp(r'UID\s+([A-Fa-f0-9:]+)');
    final match = regExp.firstMatch(message);
    return match?.group(1);
  }

  void _showApproveDialog(BuildContext context, String uid) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(AppColors.surfaceContainerHigh).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.0),
            ),
            title: Row(
              children: [
                const Icon(Icons.add_card_rounded, color: Color(0xFF00F4FE), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Setujui Kartu RFID',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UID: $uid',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Nama Pemilik Kartu',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00F4FE)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Batal',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F4FE),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    HapticFeedback.heavyImpact();
                    Navigator.of(context).pop();
                    _hide();
                    
                    // Call backend approve API
                    await SmartHomeService().approveRfidCard(uid, name);
                    
                    // Show custom snackbar
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(
                        content: Text('Kartu RFID milik $name berhasil diaktifkan!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNotif == null) return const SizedBox.shrink();

    final uid = _extractUid(_currentNotif!.message);
    final isRfidForeign =
        _currentNotif!.title.contains('RFID Asing') || _currentNotif!.title.contains('RFID');

    // Categorized UI theme helper
    Color categoryColor = const Color(0xFF00F4FE); // Info (Cyan)
    IconData categoryIcon = Icons.info_rounded;

    if (_currentNotif!.priority == NotificationPriority.critical) {
      categoryColor = const Color(AppColors.error); // Red/Pink
      categoryIcon = Icons.report_gmailerrorred_rounded;
    } else if (_currentNotif!.priority == NotificationPriority.warning) {
      categoryColor = const Color(0xFFFFA726); // Warning (Orange)
      categoryIcon = Icons.warning_amber_rounded;
    } else if (_currentNotif!.category == NotificationCategory.security) {
      categoryColor = const Color(0xFF00F4FE);
      categoryIcon = Icons.security_rounded;
    } else if (_currentNotif!.category == NotificationCategory.climate) {
      categoryColor = const Color(0xFF81C784);
      categoryIcon = Icons.thermostat_rounded;
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          top: _slideAnimation.value,
          left: 16,
          right: 16,
          child: child!,
        );
      },
      child: GestureDetector(
        onTap: () {
          // Pause or dismiss on tap
          _hide();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF1E2020).withOpacity(0.75),
                border: Border.all(
                  color: categoryColor.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: categoryColor.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: categoryColor.withOpacity(0.12),
                    ),
                    child: Center(
                      child: Icon(categoryIcon, color: categoryColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _currentNotif!.title,
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'BARU',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: categoryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentNotif!.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.3,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        
                        // Action buttons if RFID
                        if (isRfidForeign && uid != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  _hide();
                                },
                                child: Text(
                                  'Abaikan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: categoryColor,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  _showApproveDialog(context, uid);
                                },
                                child: const Text(
                                  'Setujui',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
