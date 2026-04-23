import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/sos/sos_bloc.dart';
import '../blocs/sos/sos_event.dart';

class LowNetworkSosSheet extends StatefulWidget {
  final double lat;
  final double lon;
  final String? initialMessage;

  const LowNetworkSosSheet({
    super.key,
    required this.lat,
    required this.lon,
    this.initialMessage,
  });

  @override
  State<LowNetworkSosSheet> createState() => _LowNetworkSosSheetState();
}

class _LowNetworkSosSheetState extends State<LowNetworkSosSheet> {
  final TextEditingController _messageController = TextEditingController();
  String _priority = 'high';
  int _secondsRemaining = 10;
  Timer? _timer;

  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonOrange = Color(0xFFFB923C);
  static const Color glassBorder = Color(0x3394A3B8);

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        // Auto-send will be triggered by BLoC timer, but we can also trigger here to be safe
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      decoration: const BoxDecoration(
        color: slatePanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOW NETWORK SOS ⚠️',
                    style: TextStyle(
                      color: neonOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'HELP WILL BE SENT VIA SMS',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: neonOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neonOrange.withOpacity(0.5)),
                ),
                child: Text(
                  'AUTO-SEND: ${_secondsRemaining}S',
                  style: const TextStyle(
                    color: neonOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Message Field
          const Text(
            'DESCRIBE YOUR SITUATION',
            style: TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Broken leg, building fire, etc.',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              filled: true,
              fillColor: darkBg.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: glassBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: glassBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: neonCyan)),
            ),
          ),
          const SizedBox(height: 20),

          // Priority Toggle
          const Text(
            'EMERGENCY PRIORITY',
            style: TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPriorityOption('low', 'LOW', Icons.info_outline),
              const SizedBox(width: 12),
              _buildPriorityOption('high', 'CRITICAL', Icons.warning_amber_rounded),
            ],
          ),
          const SizedBox(height: 28),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                context.read<SosBloc>().add(
                  SubmitOfflineSos(
                    _messageController.text, 
                    _priority,
                    lat: widget.lat,
                    lon: widget.lon,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: neonOrange,
                foregroundColor: darkBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: neonOrange.withOpacity(0.5),
              ),
              child: const Text(
                'DISPATCH SMS NOW',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityOption(String value, String label, IconData icon) {
    bool isSelected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? (value == 'high' ? Colors.red.withOpacity(0.2) : neonCyan.withOpacity(0.1)) : darkBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? (value == 'high' ? Colors.red : neonCyan) : glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? (value == 'high' ? Colors.red : neonCyan) : Colors.blueGrey, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
