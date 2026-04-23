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
  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonOrange = Color(0xFFFB923C);
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    context.read<LeaderboardBloc>().add(const LoadLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 FIELD AGENTS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'GLOBAL RESPONSE LEADERBOARD',
              style: TextStyle(
                color: neonCyan,
                fontSize: 9,
                letterSpacing: 2,
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
                  const Icon(Icons.cloud_off_rounded, color: neonOrange, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
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
                color: isSelected ? neonCyan.withOpacity(0.15) : slatePanel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? neonCyan : Colors.blueGrey.withOpacity(0.3),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                occ.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: isSelected ? neonCyan : Colors.blueGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slatePanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: gold.withOpacity(0.05), blurRadius: 20)],
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
          Text(medals[rank]!, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            entry.name.split(' ').first,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${entry.totalScore.toStringAsFixed(0)} pts',
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
          ),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22),
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
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: slatePanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rankColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rankColor.withOpacity(0.15),
                border: Border.all(color: rankColor.withOpacity(0.5)),
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
                  Text(entry.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    entry.occupation,
                    style: TextStyle(color: neonOrange.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
  static const Color gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: slatePanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.5), borderRadius: BorderRadius.circular(4)),
          ),

          // Avatar + Rank
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: neonCyan.withOpacity(0.15),
                child: Text(
                  entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: neonCyan, fontSize: 36, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _rankColor(entry.rank).withOpacity(0.2),
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
          Text(entry.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: neonOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: neonOrange.withOpacity(0.4)),
            ),
            child: Text(entry.occupation, style: const TextStyle(color: neonOrange, fontWeight: FontWeight.bold, fontSize: 11)),
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
                backgroundColor: darkBg,
                foregroundColor: neonCyan,
                side: const BorderSide(color: neonCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
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
