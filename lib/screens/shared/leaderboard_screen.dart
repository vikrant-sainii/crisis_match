import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/leaderboard/leaderboard_bloc.dart';
import '../../blocs/leaderboard/leaderboard_event.dart';
import '../../blocs/leaderboard/leaderboard_state.dart';
import '../../models/leaderboard_entry_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // 🌃 CYBER THEME
  // 🏙 SOFT UI THEME
  static const Color saffron = Color(0xFFFF9933);
  static const Color white = Color(0xFFFFFFFF);
  static const Color green = Color(0xFF138808);
  static const Color neonCyan = Color(0xFF2563EB);
  static const Color gold = Color(0xFFF59E0B);
  static const Color silver = Color(0xFF94A3B8);
  static const Color bronze = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    context.read<LeaderboardBloc>().add(const LoadLeaderboard());
  }

  

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            saffron.withValues(alpha: 0.1),
            Colors.white,
            green.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAHAYAK LEADERBOARD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'INDIA RESPONSE RANKINGS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          if (state is LeaderboardLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: neonCyan),
                  SizedBox(height: 16),
                  Text('SYNCING FIELD DATA...', style: TextStyle(color: neonCyan, fontSize: 11, letterSpacing: 2)),
                ],
              ),
            );
          }

          if (state is LeaderboardError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message, style: const TextStyle(color: Colors.blueGrey, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.read<LeaderboardBloc>().add(const LoadLeaderboard()),
                    child: const Text('RETRY', style: TextStyle(color: neonCyan, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ],
              ),
            );
          }

          if (state is LeaderboardLoaded) {
            return Column(
              children: [
                // Filter Tabs
                _buildOccupationFilter(state),

                // Top 3 Podium
                if (state.entries.length >= 3)
                  _buildPodium(state.entries),

                // Full List
                Expanded(
                  child: state.entries.isEmpty
                      ? const Center(
                          child: Text(
                            'NO AGENTS ON LEADERBOARD YET',
                            style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: state.entries.length,
                          itemBuilder: (context, index) {
                            return _buildEntryCard(state.entries[index]);
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      ),
    );
  }

  Widget _buildOccupationFilter(LeaderboardLoaded state) {
    final occupations = ['All', ...state.occupations];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: occupations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final occ = occupations[index];
          final isSelected = (state.selectedOccupation == null && occ == 'All') ||
              state.selectedOccupation == occ;

          return GestureDetector(
            onTap: () {
              if (occ == 'All') {
                context.read<LeaderboardBloc>().add(const FilterLeaderboard(null));
              } else {
                context.read<LeaderboardBloc>().add(FilterLeaderboard(occ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? neonCyan : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? neonCyan : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [BoxShadow(color: neonCyan.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Text(
                occ.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.blueGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> entries) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            saffron.withValues(alpha: 0.1),
            Colors.white,
            green.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) _buildPodiumPillar(second, 2, silver, height: 72),
          if (first != null) _buildPodiumPillar(first, 1, gold, height: 96),
          if (third != null) _buildPodiumPillar(third, 3, bronze, height: 56),
        ],
      ),
    );
  }

  Widget _buildPodiumPillar(LeaderboardEntry entry, int rank, Color color, {required double height}) {
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return GestureDetector(
      onTap: () => _showHelperProfile(entry),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Text(
                entry.name[0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.name.split(' ').first,
            style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${entry.totalScore.toStringAsFixed(0)} PTS',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Container(
            width: 70,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                medals[rank]!,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(LeaderboardEntry entry) {
    Color rankColor;
    if (entry.rank == 1) {
      rankColor = gold;
    } else if (entry.rank == 2) rankColor = silver;
    else if (entry.rank == 3) rankColor = bronze;
    else rankColor = neonCyan;

    return GestureDetector(
      onTap: () => _showHelperProfile(entry),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rankColor.withValues(alpha: 0.15),
                border: Border.all(color: rankColor.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name, 
                    style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 15)
                  ),
                  Text(
                    entry.occupation.toUpperCase(),
                    style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: neonCyan, size: 14),
                    Text(
                      entry.totalScore.toStringAsFixed(0),
                      style: const TextStyle(color: neonCyan, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                    Text(
                      entry.avgRating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(' · ${entry.totalHelps} helps', style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: Colors.blueGrey.shade600, size: 20),
          ],
        ),
      ),
    );
  }

  void _showHelperProfile(LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HelperProfileSheet(entry: entry),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER PROFILE BOTTOM SHEET
// ---------------------------------------------------------------------------

class _HelperProfileSheet extends StatelessWidget {
  final LeaderboardEntry entry;

  const _HelperProfileSheet({required this.entry});

  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonOrange = Color(0xFFFB923C);

  @override
  Widget build(BuildContext context) {
    const saffron = Color(0xFFFF9933);
    const green = Color(0xFF138808);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40),
        ],
        border: Border.all(color: saffron.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
          ),

          // Avatar + Rank
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [saffron, Colors.white, green]),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: TextStyle(color: _rankColor(entry.rank), fontSize: 36, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _rankColor(entry.rank).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _rankColor(entry.rank)),
                ),
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(color: _rankColor(entry.rank), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          Text(entry.name, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.4)),
            ),
            child: Text(entry.occupation, style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          Row(
            children: [
              Expanded(child: _statTile('⚡ SCORE', entry.totalScore.toStringAsFixed(0), neonCyan)),
              const SizedBox(width: 12),
              Expanded(child: _statTile('✅ HELPS', '${entry.totalHelps}', Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: _statTile('★ RATING', entry.avgRating.toStringAsFixed(1), Colors.amber)),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: saffron,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return const Color(0xFF22D3EE);
  }
}
