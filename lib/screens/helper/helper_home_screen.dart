import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/help_request/help_request_bloc.dart';
import '../../blocs/help_request/help_request_event.dart';
import '../../blocs/help_request/help_request_state.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_event.dart';
import '../../blocs/location/location_state.dart';
import '../../models/help_request_model.dart';
import '../../repositories/helper_repository.dart';
import '../../repositories/leaderboard_repository.dart';
import '../../screens/shared/leaderboard_screen.dart';
import '../../widgets/status_badge.dart';
import 'helper_chat_screen.dart';
import 'helper_map_screen.dart';

class HelperHomeScreen extends StatefulWidget {
  const HelperHomeScreen({super.key});

  @override
  State<HelperHomeScreen> createState() => _HelperHomeScreenState();
}

class _HelperHomeScreenState extends State<HelperHomeScreen>
    with TickerProviderStateMixin {
  bool _isAvailable = true;
  String? _helperId;
  late TabController _tabController;

  // 🌃 CYBER-DARK THEME CONSTANTS (Matching Victim UI)
  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonOrange = Color(0xFFFB923C);
  static const Color glassBorder = Color(0x3394A3B8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<LocationBloc>().add(GetCurrentLocation());
    _loadHelperAndSubscribe();
  }

  Future<void> _loadHelperAndSubscribe() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final helperRepo = context.read<HelperRepository>();
    final helper = await helperRepo.getHelperByProfileId(authState.profile.id);
    if (!mounted) return;
    if (helper != null) {
      setState(() {
        _helperId = helper.id;
        _isAvailable = helper.isAvailable;
      });

      context.read<HelpRequestBloc>().add(ListenForHelperMatches(helper.id));

      final locationState = context.read<LocationBloc>().state;
      if (locationState is LocationLoaded) {
        await helperRepo.updateLocation(
          helper.id,
          locationState.lat,
          locationState.lng,
        );
      }
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    if (_helperId == null) return;
    setState(() => _isAvailable = value);
    await context.read<HelperRepository>().updateAvailability(
      _helperId!,
      value,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // 🛰 FLOATING CYBER HEADER
            _buildCyberHeader(),

            // 🔦 SYSTEMS STATUS BAR
            _buildStatusBar(),

            // 📟 CYBER TAB SWITCHER
            _buildCyberSwitcher(),

            // 💬 MAIN CONTENT REGION
            Expanded(
              child: Stack(
                children: [
                  // Background Grid or Subtle Pattern
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.05,
                      child: Image.network(
                        'https://www.transparenttextures.com/patterns/carbon-fibre.png',
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                  ),

                  // Data Views
                  BlocListener<HelpRequestBloc, HelpRequestState>(
                    listener: (context, state) {
                      if (state is HelperRequestsLoaded) {
                        // Optional: Detect subtle changes here if needed
                      }

                      // Handle transitions based on status changes of loaded requests
                      if (state is HelperRequestsLoaded) {
                        final accepted = state.requests.any(
                          (r) => r.status == 'accepted',
                        );
                        final pending = state.requests.any(
                          (r) => r.status == 'pending',
                        );

                        // If we are on the UPLINKS tab (0) and there are no pendings but there are accepteds, move to missions
                        if (_tabController.index == 0 && !pending && accepted) {
                          _tabController.animateTo(1);
                        }
                      }
                    },
                    child: BlocBuilder<HelpRequestBloc, HelpRequestState>(
                      builder: (context, state) {
                        if (state is HelperRequestsLoaded) {
                          final reqs = state.requests;
                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRequestList(
                                reqs
                                    .where((r) => r.status == 'pending')
                                    .toList(),
                                'NO PENDING UPLINKS',
                              ),
                              _buildRequestList(
                                reqs
                                    .where((r) => r.status == 'accepted')
                                    .toList(),
                                'NO ACTIVE MISSIONS',
                              ),
                              _buildRequestList(
                                reqs
                                    .where((r) => r.status == 'completed')
                                    .toList(),
                                'ARCHIVES EMPTY',
                              ),
                              _buildRequestList(
                                reqs
                                    .where((r) => r.status == 'rejected')
                                    .toList(),
                                'REJECTIONS LOGS CLEAR',
                              ),
                            ],
                          );
                        }
                        if (state is HelpRequestError) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.all(24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'SYSTEM OVERLOAD: ${state.message}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(color: neonCyan),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RESPONDER-CMD',
                style: TextStyle(
                  color: neonCyan,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'FIELD AGENT DASHBOARD',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: glassBorder),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.leaderboard_rounded,
                    color: Color(0xFFFFD700),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: glassBorder),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Colors.orangeAccent,
                  ),
                  onPressed: () {
                    context.read<HelpRequestBloc>().add(ClearHelpRequest());
                    context.read<ChatBloc>().add(ClearChat());
                    context.read<AuthBloc>().add(AuthSignOutRequested());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final statusColor = _isAvailable ? Colors.greenAccent : neonOrange;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isAvailable ? 'TRANSMISSION READY' : 'SYSTEM OFFLINE',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _isAvailable,
              onChanged: _toggleAvailability,
              activeThumbColor: Colors.greenAccent,
              activeTrackColor: Colors.greenAccent.withOpacity(0.3),
              inactiveThumbColor: neonOrange,
              inactiveTrackColor: neonOrange.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: slatePanel.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: neonCyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: neonCyan.withOpacity(0.5), width: 1.5),
        ),
        labelColor: neonCyan,
        unselectedLabelColor: Colors.blueGrey.shade400,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1,
        ),
        tabs: const [
          Tab(text: 'UPLINKS'),
          Tab(text: 'MISSIONS'),
          Tab(text: 'ARCHIVE'),
          Tab(text: 'DENIED'),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<HelpRequestModel> list, String emptyMessage) {
    return RefreshIndicator(
      onRefresh: () async {
        if (_helperId != null) {
          context.read<HelpRequestBloc>().add(
            ListenForHelperMatches(_helperId!),
          );
        }
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: neonCyan,
      backgroundColor: darkBg,
      child: list.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                return _buildRequestCard(list[index]);
              },
            ),
    );
  }

  Widget _buildRequestCard(HelpRequestModel request) {
    final isPending = request.status == 'pending';
    final isAccepted = request.status == 'accepted';
    final isCompleted = request.status == 'completed';
    final isRejected = request.status == 'rejected';

    Color cardColor = isPending
        ? neonCyan
        : isAccepted
        ? Colors.greenAccent
        : isRejected
        ? neonOrange
        : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: slatePanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.crisisType.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
                StatusBadge(status: request.status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: darkBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: glassBorder),
                      ),
                      child: Icon(
                        Icons.person_pin_rounded,
                        color: cardColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.victimName ?? "ANONYMOUS CLIENT",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'COORDINATES: ${request.victimCurrLat.toStringAsFixed(4)}, ${request.victimCurrLong.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (request.txHash != null) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _launchTx(request.txHash!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Colors.greenAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'POLYGON PROOF ATTESTED',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.read<HelpRequestBloc>().add(
                            UpdateHelpRequestStatus(
                              requestId: request.id,
                              status: 'rejected',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: neonOrange,
                            side: const BorderSide(color: neonOrange),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'DECLINE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // 1. Update request status in DB (existing mission logic)
                            context.read<HelpRequestBloc>().add(
                              UpdateHelpRequestStatus(
                                requestId: request.id,
                                status: 'accepted',
                              ),
                            );
                            // 2. Create help_session for scoring (isolated leaderboard logic)
                            if (_helperId != null) {
                              await context
                                  .read<LeaderboardRepository>()
                                  .createSession(
                                    requestId: request.id,
                                    helperId: _helperId!,
                                    victimId: request.victimId,
                                    requestCreatedAt:
                                        request.createdAt ?? DateTime.now(),
                                  );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: neonCyan,
                            foregroundColor: darkBg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: neonCyan.withOpacity(0.5),
                          ),
                          child: const Text(
                            'ACCEPT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (isAccepted || isCompleted)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildCyberActionButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HelperChatScreen(request: request),
                          ),
                        ),
                        icon: Icons.forum_rounded,
                        label: 'COMMS',
                        color: neonCyan,
                      ),
                      _buildCyberActionButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HelperMapScreen(request: request),
                          ),
                        ),
                        icon: Icons.radar_rounded,
                        label: 'TRACK',
                        color: neonCyan,
                        outlined: true,
                      ),
                      if (isAccepted) ...[
                        _buildCyberActionButton(
                          onPressed: () =>
                              _showCancelConfirmation(context, request),
                          icon: Icons.cancel_rounded,
                          label: 'ABORT',
                          color: neonOrange,
                          outlined: true,
                        ),
                        _buildCyberActionButton(
                          onPressed: () async {
                            context.read<HelpRequestBloc>().add(
                              UpdateHelpRequestStatus(
                                requestId: request.id,
                                status: 'completed',
                              ),
                            );
                            await context
                                .read<LeaderboardRepository>()
                                .completeSession(request.id);
                          },
                          icon: Icons.check_circle_rounded,
                          label: 'SOLVED',
                          color: Colors.greenAccent,
                        ),
                        _buildCyberActionButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: darkBg,
                                title: const Text(
                                  'Report Fake Request?',
                                  style: TextStyle(
                                    color: neonOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: const Text(
                                  'If the victim is not present or this is a fraudulent request, report it as spam. Admin will review and block the user.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      context.read<HelpRequestBloc>().add(
                                        UpdateHelpRequestStatus(
                                          requestId: request.id,
                                          status: 'spam',
                                        ),
                                      );
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Reported as SPAM. Admin notified.',
                                          ),
                                          backgroundColor: neonOrange,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: neonOrange,
                                    ),
                                    child: const Text(
                                      'REPORT SPAM',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icons.report_problem_rounded,
                          label: 'SPAM',
                          color: neonOrange,
                          outlined: true,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 11,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontSize: 11,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: darkBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
      ),
    );
  }

  Future<void> _launchTx(String hash) async {
    // If the hash length is ~42 characters, it's likely a wallet address (0x + 40 hex).
    // If it's ~66 characters, it's a transaction hash (0x + 64 hex).
    final String pathType = hash.length <= 42 ? 'address' : 'tx';
    final url = Uri.parse('https://amoy.polygonscan.com/$pathType/$hash');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showCancelConfirmation(BuildContext context, HelpRequestModel request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Help?'),
        content: const Text(
          'Are you sure you want to cancel this assistance? '
          'The victim will be immediately re-matched with another rescuer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<HelpRequestBloc>().add(
                UpdateHelpRequestStatus(
                  requestId: request.id,
                  status: 'rejected',
                ),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Confirm Cancellation',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
