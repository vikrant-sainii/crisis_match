import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/help_request/help_request_bloc.dart';
import '../../blocs/help_request/help_request_event.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../repositories/leaderboard_repository.dart';
import '../../models/leaderboard_entry_model.dart';

class HelperProfileScreen extends StatefulWidget {
  const HelperProfileScreen({super.key});

  @override
  State<HelperProfileScreen> createState() => _HelperProfileScreenState();
}

class _HelperProfileScreenState extends State<HelperProfileScreen> {
  LeaderboardEntry? _helperStats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final repo = LeaderboardRepository(Supabase.instance.client);
      final stats = await repo.getHelperWithStats(authState.profile.id);
      if (mounted) {
        setState(() {
          _helperStats = stats;
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final profile = authState.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'RESPONDER PROFILE',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. Profile Avatar & Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Icon(Icons.support_agent_rounded, color: theme.primaryColor, size: 50),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    profile.fullName.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SAHAYAK ACCOUNT',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 2. Stats Section
            if (_isLoadingStats)
              const Center(child: CircularProgressIndicator())
            else if (_helperStats != null)
              _buildStatsSection(),
            
            const SizedBox(height: 24),

            // 3. Details List
            _buildDetailSection(
              title: 'IDENTITY DATA',
              items: [
                _buildDetailItem(Icons.email_outlined, 'EMAIL', profile.email),
                _buildDetailItem(Icons.phone_outlined, 'PHONE', profile.phone ?? 'NOT LINKED'),
                _buildDetailItem(Icons.work_outline_rounded, 'SPECIALIZATION', _helperStats?.occupation ?? 'VOLUNTEER'),
                _buildDetailItem(Icons.fingerprint_rounded, 'UID', profile.id.toUpperCase()),
              ],
            ),
            const SizedBox(height: 40),

            // 4. Security / Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.power_settings_new_rounded),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('SCORE', _helperStats!.totalScore.toInt().toString(), Icons.emoji_events_rounded, Colors.orange),
          _buildStatItem('RATING', _helperStats!.avgRating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
          _buildStatItem('HELPS', _helperStats!.totalHelps.toString(), Icons.volunteer_activism_rounded, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.blueGrey.shade400,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade400,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey.shade300, size: 20),
      title: Text(
        label,
        style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('LOGOUT?'),
        content: const Text('You will be logged out of the responder dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              
              // 1. Clear active states
              try {
                context.read<HelpRequestBloc>().add(ClearHelpRequest());
              } catch (_) {}
              
              try {
                context.read<ChatBloc>().add(ClearChat());
              } catch (_) {}

              // 2. Trigger global sign-out
              context.read<AuthBloc>().add(AuthSignOutRequested());
              
              // 3. Return to root
              Navigator.pop(context);
            },
            child: const Text('LOGOUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
