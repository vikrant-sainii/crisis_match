import 'dart:math';
import 'package:flutter/material.dart';

/// Full-screen overlay shown when SOS is capturing the distress message.
/// Features animated waveform bars and a countdown timer.
class SosCaptureOverlay extends StatefulWidget {
  final int secondsRemaining;
  final String? statusText;
  final VoidCallback? onCancel;

  const SosCaptureOverlay({
    super.key,
    required this.secondsRemaining,
    this.statusText,
    this.onCancel,
  });

  @override
  State<SosCaptureOverlay> createState() => _SosCaptureOverlayState();
}

class _SosCaptureOverlayState extends State<SosCaptureOverlay>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  final _random = Random();

  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonRed = Color(0xFFEF4444);
  static const Color darkBg = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: darkBg.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SOS Icon with pulse
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.15).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: neonRed.withValues(alpha: 0.15),
                  border: Border.all(color: neonRed.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: neonRed.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: neonRed,
                  size: 48,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Status text
            Text(
              widget.statusText ?? 'LISTENING FOR YOUR MESSAGE...',
              style: const TextStyle(
                color: neonCyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 24),

            // Waveform bars
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(20, (index) {
                    final height = 15.0 +
                        (_random.nextDouble() * 35) *
                            sin((_waveController.value * 2 * pi) +
                                (index * 0.3));
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 4,
                      height: height.abs().clamp(5, 50),
                      decoration: BoxDecoration(
                        color: neonRed.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: neonRed.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: 32),

            // Countdown timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: neonRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: neonRed.withValues(alpha: 0.3)),
              ),
              child: Text(
                'RECORDING... ${widget.secondsRemaining}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Describe your emergency clearly',
              style: TextStyle(
                color: Colors.blueGrey.shade400,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 48),

            // Cancel button
            if (widget.onCancel != null)
              TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, color: Colors.blueGrey),
                label: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
