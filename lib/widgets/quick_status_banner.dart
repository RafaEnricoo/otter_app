import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../services/firebase_service.dart';

class QuickStatusBanner extends StatelessWidget {
  final bool alwaysShow;

  const QuickStatusBanner({
    super.key,
    this.alwaysShow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: FirebaseService().stateNotifier,
      builder: (context, state, child) {
        if (state == null) return const SizedBox.shrink();

        final sensor = state.sensor;
        final perangkat = state.perangkat;

        final bool hasGas = sensor.dapurFlame > 0;
        final bool hasMotion = sensor.tamuGerak;
        final bool hasSiren = perangkat.buzzerAlrm;
        final bool isLocked = perangkat.kunciPintuRfid;

        final List<Widget> activeBanners = [];

        if (hasGas) {
          activeBanners.add(
            _buildBannerItem(
              title: 'KRITIS: Terdeteksi Kebakaran!',
              subtitle: 'Ada kobaran api terdeteksi di Dapur! Segera evakuasi!',
              icon: Icons.local_fire_department_rounded,
              isAlert: true,
            ),
          );
        }

        if (hasMotion) {
          activeBanners.add(
            _buildBannerItem(
              title: 'DARURAT: Anomali Terdeteksi!',
              subtitle: 'Sensor PIR mendeteksi pergerakan mencurigakan!',
              icon: Icons.person_off_rounded,
              isAlert: true,
            ),
          );
        }

        // Show siren banner if active and not already covered by fire/motion alerts
        if (hasSiren && !hasGas && !hasMotion) {
          activeBanners.add(
            _buildBannerItem(
              title: 'DARURAT: Sirine Rumah Aktif!',
              subtitle: 'Sirine darurat sedang aktif.',
              icon: Icons.campaign_rounded,
              isAlert: true,
            ),
          );
        }

        // Default safe banner if no alerts and alwaysShow is true
        if (activeBanners.isEmpty && alwaysShow) {
          int activeCount = 0;
          if (perangkat.lampuKamar) activeCount++;
          if (perangkat.lampuTamu) activeCount++;
          if (perangkat.lampuKamarMandi) activeCount++;
          if (perangkat.lampuDapur) activeCount++;
          if (perangkat.kipasKamar) activeCount++;
          if (perangkat.buzzerAlrm) activeCount++;
          if (perangkat.ledMerahDapur) activeCount++;

          activeBanners.add(
            _buildBannerItem(
              title: 'Rumah dalam kondisi aman',
              subtitle: '$activeCount perangkat aktif • Kunci RFID ${isLocked ? "aktif" : "terbuka"}',
              icon: Icons.verified_user_rounded,
              isAlert: false,
            ),
          );
        }

        if (activeBanners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: activeBanners.map((banner) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: banner,
          )).toList(),
        );
      },
    );
  }

  Widget _buildBannerItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isAlert,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isAlert
              ? [
                  const Color(AppColors.error).withValues(alpha: 0.12),
                  const Color(AppColors.error).withValues(alpha: 0.04),
                ]
              : [
                  Color(AppColors.secondaryContainer).withValues(alpha: 0.08),
                  Color(AppColors.primary).withValues(alpha: 0.04),
                ],
        ),
        border: Border.all(
          color: isAlert
              ? const Color(AppColors.error).withValues(alpha: 0.35)
              : Color(AppColors.secondaryContainer).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Shield / Warning icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isAlert
                  ? const Color(AppColors.error).withValues(alpha: 0.12)
                  : Color(AppColors.secondaryContainer).withValues(alpha: 0.12),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isAlert ? const Color(AppColors.error) : Color(AppColors.secondaryContainer),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isAlert ? const Color(AppColors.error) : Color(AppColors.onSurface),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAlert ? const Color(AppColors.error) : const Color(0xFF66BB6A),
              boxShadow: [
                BoxShadow(
                  color: (isAlert ? const Color(AppColors.error) : const Color(0xFF66BB6A)).withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
