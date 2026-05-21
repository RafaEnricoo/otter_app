import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

/// Shows the Voice Assistant overlay as a modal bottom sheet.
Future<void> showVoiceAssistant(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Color(AppColors.surface).withOpacity(0.85),
    builder: (context) => const VoiceAssistantSheet(),
  );
}

class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key});

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet>
    with TickerProviderStateMixin {
  // ─── State ───
  _VoiceState _voiceState = _VoiceState.idle;
  String _transcriptText = '';
  String _feedbackText = '';

  // ─── Animations ───
  late AnimationController _entryController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _waveController;

  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();

    // Entry animation
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    // Mic pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sound wave
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Orb ring rotation
    _orbController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _entryController.forward();
  }

  void _simulateVoiceFlow() async {
    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.listening;
      _transcriptText = '';
      _feedbackText = '';
    });

    // Phase 2: Show transcript
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.processing;
      _transcriptText = '"Matikan lampu ruang tamu"';
    });

    // Phase 3: Show feedback
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _voiceState = _VoiceState.success;
      _feedbackText = 'Lampu ruang tamu dimatikan';
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(AppColors.surfaceContainer).withOpacity(0.7),
                  Color(AppColors.surface).withOpacity(0.95),
                  Color(AppColors.surface),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: bottomPadding + 24,
                  top: 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Drag Handle ───
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 28),
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Color(AppColors.onSurfaceVariant)
                              .withOpacity(0.25),
                        ),
                      ),
                    ),

                    // ─── Sound Wave / Status Area ───
                    SizedBox(
                      height: 100,
                      child: _buildWaveArea(),
                    ),

                    const SizedBox(height: 20),

                    // ─── Transcript Text ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _transcriptText.isNotEmpty
                          ? Padding(
                              key: ValueKey(_transcriptText),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _transcriptText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(AppColors.onSurface),
                                  letterSpacing: -0.5,
                                  height: 1.3,
                                ),
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('empty-transcript'),
                              height: 32,
                            ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Feedback Text ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _feedbackText.isNotEmpty
                          ? Row(
                              key: ValueKey(_feedbackText),
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(AppColors.secondaryContainer),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _feedbackText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(AppColors.secondaryContainer)
                                        .withOpacity(0.85),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(
                              key: ValueKey('empty-feedback'),
                              height: 20,
                            ),
                    ),

                    const SizedBox(height: 32),

                    // ─── Mic Button ───
                    _buildMicButton(),

                    const SizedBox(height: 20),

                    // ─── Status Label ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusLabel,
                        key: ValueKey(_statusLabel),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(AppColors.onSurfaceVariant)
                              .withOpacity(0.4),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLabel {
    switch (_voiceState) {
      case _VoiceState.idle:
        return 'TAP TO SPEAK';
      case _VoiceState.listening:
        return 'LISTENING';
      case _VoiceState.processing:
        return 'PROCESSING';
      case _VoiceState.success:
        return 'DONE';
    }
  }

  // ─────────────────────────────────────────────────
  // Sound Wave Visualizer
  // ─────────────────────────────────────────────────
  Widget _buildWaveArea() {
    if (_voiceState == _VoiceState.idle) {
      return Center(
        child: Icon(
          Icons.mic_none_rounded,
          size: 48,
          color: Color(AppColors.onSurfaceVariant).withOpacity(0.2),
        ),
      );
    }

    if (_voiceState == _VoiceState.success) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(AppColors.secondaryContainer).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color:
                        Color(AppColors.secondaryContainer).withOpacity(0.3),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.check_rounded,
                  color: Color(AppColors.secondaryContainer),
                  size: 32,
                ),
              ),
            ),
          );
        },
      );
    }

    // Listening / Processing — animated wave bars
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(9, (index) {
            final phase = index / 9 * 2 * math.pi;
            final waveValue =
                (math.sin(_waveController.value * 2 * math.pi + phase) + 1) /
                    2;
            final heightFactor = _voiceState == _VoiceState.processing
                ? 0.15 + waveValue * 0.25
                : 0.2 + waveValue * 0.8;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 5,
                height: 100 * heightFactor,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(AppColors.secondaryContainer),
                      Color(AppColors.secondaryContainer).withOpacity(0.15),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(AppColors.secondaryContainer)
                          .withOpacity(0.4 * waveValue),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // Glowing Mic Button
  // ─────────────────────────────────────────────────
  Widget _buildMicButton() {
    final isActive =
        _voiceState == _VoiceState.listening ||
        _voiceState == _VoiceState.processing;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (_voiceState == _VoiceState.success) {
          Navigator.of(context).pop();
        } else if (_voiceState == _VoiceState.idle) {
          _simulateVoiceFlow();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _orbController]),
        builder: (context, child) {
          return SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Outer ping ring (only when active) ──
                if (isActive)
                  AnimatedOpacity(
                    opacity: isActive ? 0.6 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(AppColors.secondaryContainer)
                              .withOpacity(_pulseAnimation.value * 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // ── Rotating gradient ring ──
                if (isActive)
                  Transform.rotate(
                    angle: _orbController.value * 2 * math.pi,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(AppColors.secondaryContainer),
                            Color(AppColors.secondaryContainer)
                                .withOpacity(0.0),
                            Color(AppColors.primary).withOpacity(0.2),
                            Color(AppColors.secondaryContainer)
                                .withOpacity(0.0),
                            Color(AppColors.secondaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Core button ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.2),
                      radius: 1.0,
                      colors: [
                        Color(AppColors.surfaceContainerHigh),
                        Color(AppColors.surfaceContainer),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(AppColors.secondaryContainer).withOpacity(
                          isActive ? _pulseAnimation.value : 0.15,
                        ),
                        blurRadius: isActive ? 60 : 20,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      // Inner glow
                      if (isActive)
                        BoxShadow(
                          color: Color(AppColors.secondaryContainer)
                              .withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _voiceState == _VoiceState.success
                          ? Icon(
                              Icons.check_rounded,
                              key: const ValueKey('check'),
                              color: Color(AppColors.secondaryContainer),
                              size: 36,
                            )
                          : Icon(
                              Icons.mic_rounded,
                              key: const ValueKey('mic'),
                              color: Color(AppColors.secondaryContainer),
                              size: 40,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _VoiceState { idle, listening, processing, success }
