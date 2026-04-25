import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/help_request_model.dart';
import '../../repositories/help_request_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/status_badge.dart';
import 'victim_history_detail_screen.dart';

class VictimHistoryScreen extends StatefulWidget {
  const VictimHistoryScreen({super.key});

  @override
  State<VictimHistoryScreen> createState() => _VictimHistoryScreenState();
}

class _VictimHistoryScreenState extends State<VictimHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    return FutureBuilder<List<HelpRequestModel>>(
      future: context.read<HelpRequestRepository>().getVictimHistory(
        authState.profile.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A47B8)),
          );
        }
        
        final history = (snapshot.data ?? [])
            .where((r) => r.status == 'completed' || r.status == 'rejected')
            .toList();

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.archive_outlined, size: 64, color: Colors.blueGrey.shade200),
                const SizedBox(height: 16),
                Text(
                  'ARCHIVES EMPTY',
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: const Color(0xFF1A47B8),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: history.length,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding for FAB
            itemBuilder: (context, index) {
              final req = history[index];
              final isCompleted = req.status == 'completed';
              final statusColor = isCompleted ? Colors.greenAccent.shade700 : Colors.redAccent;

              const saffron = Color(0xFFFF9933);
              const green = Color(0xFF138808);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      saffron.withOpacity(0.05),
                      Colors.white,
                      green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [saffron, Colors.white, green],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.history_toggle_off_rounded,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                  ),
                  title: Text(
                    req.crisisType.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.person_pin_rounded, size: 12, color: Colors.blueGrey.shade300),
                        const SizedBox(width: 4),
                        Text(
                          'RESPONDER: ${req.helperName ?? "ANON"}',
                          style: TextStyle(
                            color: Colors.blueGrey.shade400,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: StatusBadge(status: req.status),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VictimHistoryDetailScreen(request: req),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
