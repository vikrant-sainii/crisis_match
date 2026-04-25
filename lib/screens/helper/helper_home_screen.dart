import 'dart:async';
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
import 'helper_profile_screen.dart';

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
  Timer? _priorityHeartbeat;

  // 🏙 SOFT UI THEME CONSTANTS (Matching Modern Design)
  static const Color darkBg = Color(0xFFF8FAFC);
  static const Color slatePanel = Colors.white;
  static const Color neonCyan = Color(0xFF2563EB); // Trust Blue
  static const Color neonOrange = Color(0xFFEF4444); // Emergency Red
  static const Color glassBorder = Color(0xFFE2E8F0);

  static final Gradient tricolorGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFFFF9933).withValues(alpha: 0.08),
      Colors.white,
      const Color(0xFF138808).withValues(alpha: 0.08),
    ],
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<LocationBloc>().add(GetCurrentLocation());
    _loadHelperAndSubscribe();
    _startPriorityHeartbeat();
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
    _priorityHeartbeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        top: false,
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
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
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
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24 + topPadding, 24, 16),
      decoration: BoxDecoration(
        gradient: tricolorGradientSoft,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF9933), // Saffron
                    Color(0xFF1E293B), // Dark Blue (Middle)
                    Color(0xFF138808), // Green
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'SAHAYAK',
                  style: TextStyle(
                    color: Colors.white, // Required for ShaderMask to work correctly
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Text(
                'COMMAND DASHBOARD',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.leaderboard_rounded,
                    color: Color(0xFFF59E0B),
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
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.person_rounded,
                    color: neonCyan,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelperProfileScreen(),
                      ),
                    );
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
    final statusColor = _isAvailable ? const Color(0xFF10B981) : neonOrange;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _isAvailable ? 'ACTIVE & READY' : 'CURRENTLY OFFLINE',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: _isAvailable,
            onChanged: _toggleAvailability,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  void _startPriorityHeartbeat() {
    _priorityHeartbeat?.cancel();
    _priorityHeartbeat = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final locationState = context.read<LocationBloc>().state;
      if (locationState is LocationLoaded && _helperId != null) {
        context.read<HelpRequestBloc>().add(
          SortRequestsByPriority(
            helperLat: locationState.lat,
            helperLng: locationState.lng,
          ),
        );
      }
    });
  }

  Widget _buildCyberSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: neonCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: neonCyan,
        unselectedLabelColor: Colors.blueGrey.shade400,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
        tabs: const [
          Tab(text: 'NEW REQUESTS'),
          Tab(text: 'ACTIVE'),
          Tab(text: 'HISTORY'),
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
        ? const Color(0xFF10B981)
        : isRejected
        ? neonOrange
        : Colors.blueGrey;

    const saffron = Color(0xFFFF9933);
    const green = Color(0xFF138808);
    const tricolorGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        saffron,
        Colors.white,
        green,
      ],
      stops: [0.0, 0.5, 1.0],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: tricolorGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          request.crisisType.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (isPending && request.priorityScore != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (request.priorityScore! > 100)
                                ? Colors.orange.withValues(alpha: 0.1)
                                : neonCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'P:${request.priorityScore!.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: (request.priorityScore! > 100)
                                  ? Colors.orange
                                  : neonCyan,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                          )
                        ],
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'LOC: ${request.victimCurrLat.toStringAsFixed(4)}, ${request.victimCurrLong.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.5),
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
                            side: const BorderSide(color: neonOrange, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white.withOpacity(0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'DECLINE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // 1. Update request status in DB
                            context.read<HelpRequestBloc>().add(
                              UpdateHelpRequestStatus(
                                requestId: request.id,
                                status: 'accepted',
                              ),
                            );
                            // 2. Create help_session for scoring
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
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: neonCyan.withOpacity(0.3),
                          ),
                          child: const Text(
                            'ACCEPT MISSION',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 12,
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
        shadowColor: color.withValues(alpha: 0.3),
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
