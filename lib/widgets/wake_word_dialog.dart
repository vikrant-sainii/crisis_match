import 'package:flutter/material.dart';

/// Bottom sheet dialog for configuring the SOS wake word.
class WakeWordDialog extends StatefulWidget {
  final String currentWakeWord;
  final ValueChanged<String> onSave;

  const WakeWordDialog({
    super.key,
    required this.currentWakeWord,
    required this.onSave,
  });

  @override
  State<WakeWordDialog> createState() => _WakeWordDialogState();
}

class _WakeWordDialogState extends State<WakeWordDialog> {
  late TextEditingController _controller;

  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonOrange = Color(0xFFFB923C);
  static const Color glassBorder = Color(0x3394A3B8);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentWakeWord);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: neonCyan, size: 24),
              SizedBox(width: 12),
              Text(
                'WAKE WORD CONFIG',
                style: TextStyle(
                  color: neonCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Set a custom phrase to activate SOS hands-free. Speak this phrase anytime to trigger emergency mode.',
            style: TextStyle(
              color: Colors.blueGrey.shade400,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Input field
          TextField(
            controller: _controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'WAKE WORD',
              labelStyle: TextStyle(
                color: Colors.blueGrey.shade400,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              filled: true,
              fillColor: slatePanel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: neonCyan, width: 1.5),
              ),
              prefixIcon: const Icon(Icons.mic_rounded, color: neonCyan),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: neonOrange),
                tooltip: 'Reset to default',
                onPressed: () {
                  _controller.text = 'help crisis match';
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: neonCyan.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: neonCyan.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded,
                    color: neonCyan, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Choose 3+ words that you wouldn\'t say normally, e.g. "activate rescue now"',
                    style: TextStyle(
                      color: Colors.blueGrey.shade300,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final word = _controller.text.trim().toLowerCase();
                if (word.isNotEmpty) {
                  widget.onSave(word);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: neonCyan,
                foregroundColor: darkBg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: neonCyan.withValues(alpha: 0.5),
              ),
              child: const Text(
                'SAVE WAKE WORD',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
