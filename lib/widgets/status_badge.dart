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
        return const Color(0xFF22D3EE); // Neon Cyan
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
