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

        final bool isAlert = hasGas || hasSiren || hasMotion;

        // If not alert and alwaysShow is false, don't show the banner
        if (!isAlert && !alwaysShow) {
          return const SizedBox.shrink();
        }

        // Calculate occupancy or active device count
        int activeCount = 0;
        if (perangkat.lampuKamar) activeCount++;
        if (perangkat.lampuTamu) activeCount++;
        if (perangkat.lampuKamarMandi) activeCount++;
        if (perangkat.lampuDapur) activeCount++;
        if (perangkat.kipasKamar) activeCount++;
        if (perangkat.buzzerAlrm) activeCount++;
        if (perangkat.ledMerahDapur) activeCount++;

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
                    isAlert ? Icons.warning_rounded : Icons.verified_user_rounded,
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
                      hasGas 
                          ? 'KRITIS: Terdeteksi Kebakaran!'
                          : hasMotion
                              ? 'DARURAT: Anomali Terdeteksi!'
                              : hasSiren
                                  ? 'DARURAT: Sirine Rumah Aktif!'
                                  : 'Rumah dalam kondisi aman',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isAlert ? const Color(AppColors.error) : Color(AppColors.onSurface),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasGas
                          ? 'Ada kobaran api terdeteksi di Dapur! Segera evakuasi!'
                          : hasMotion
                              ? 'Sensor PIR mendeteksi pergerakan mencurigakan!'
                              : hasSiren
                                  ? 'Sirine darurat sedang aktif.'
                                  : '$activeCount perangkat aktif • Kunci RFID ${isLocked ? "aktif" : "terbuka"}',
                      style: TextStyle(
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
      },
    );
  }
}
