import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFB923C); // Neon Orange
      case 'matched':
        return const Color(0xFF38BDF8); // Neon Blue
      case 'accepted':
        return const Color(0xFF138808); // Green
      case 'rejected':
        return const Color(0xFFF87171); // Soft Red
      case 'completed':
        return const Color(0xFF4ADE80); // Green Neon
      default:
        return const Color(0xFF94A3B8); // Slate 400
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing status dot
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
