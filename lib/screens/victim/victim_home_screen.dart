import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../blocs/help_request/help_request_bloc.dart';
import '../../blocs/help_request/help_request_event.dart';
import '../../blocs/help_request/help_request_state.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_event.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/sos/sos_bloc.dart';
import '../../blocs/sos/sos_event.dart';
import '../../blocs/sos/sos_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/status_badge.dart';
import 'victim_history_screen.dart';
import 'victim_map_screen.dart';
import 'victim_profile_screen.dart';
import 'voice_assistant_screen.dart';
import '../../repositories/help_request_repository.dart';
import '../../repositories/leaderboard_repository.dart';
import '../shared/leaderboard_screen.dart';
import '../../blocs/connectivity/connectivity_bloc.dart';
import '../../blocs/connectivity/connectivity_state.dart';
import '../../blocs/admin/admin_bloc.dart';
import '../../blocs/admin/admin_event.dart';
import '../../repositories/low_network_repository.dart';
import '../../widgets/low_network_sos_sheet.dart';
import '../../widgets/helper_grid_map.dart';

class VictimHomeScreen extends StatefulWidget {
  const VictimHomeScreen({super.key});

  @override
  State<VictimHomeScreen> createState() => _VictimHomeScreenState();
}

class _VictimHomeScreenState extends State<VictimHomeScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _n8nScrollController = ScrollController();
  final _helperScrollController = ScrollController();
  late TabController _tabController;
  late AnimationController _pulseController;

  // Location streaming for real-time tracking
  StreamSubscription<Position>? _positionStream;

  bool _isListening = false;
  bool _wasVoiced =
      false; // Flag to track if the current message started as voice
  bool _hasShownRatingDialog =
      false; // Flag to track if rating dialog was shown

  // SOS Multi-Tap state
  int _sosTapCount = 0;
  DateTime? _lastSosTap;

  // Audio Player for AI responses
  late AudioPlayer _audioPlayer;

  // SOS BLoC (created lazily with victimId)
  SosBloc? _sosBloc;

  // 🎨 MODERN LIGHT THEME CONSTANTS (Re-mapped for compatibility)
  static const Color darkBg = Colors.white; // AppTheme.backgroundLight
  static const Color slatePanel = Color(0xFFFFFFFF); // AppTheme.surfaceWhite
  static const Color neonCyan = Color(0xFF1A47B8); // AppTheme.primaryBlue
  static const Color neonOrange = Color(0xFFD32F2F); // AppTheme.emergencyRed
  static const Color saffron = Color(0xFFFF9933);
  static const Color green = Color(0xFF138808);

  static final Gradient tricolorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [saffron.withAlpha(10), Colors.white, green.withAlpha(10)],
  );

  // static final Gradient tricolorGradientSoft = LinearGradient(
  //   begin: Alignment.topLeft,
  //   end: Alignment.bottomRight,
  //   colors: [
  //     saffron.withAlpha(10),
  //     Colors.white.withAlpha(50),
  //     green.withAlpha(10),
  //   ],
  // );
  // Locally store initial AI messages for visual feedback
  final List<Map<String, String>> _localAiMessages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    context.read<LocationBloc>().add(GetCurrentLocation());

    _audioPlayer = AudioPlayer();

    final authState = context.read<AuthBloc>().state;
    String? profileId;

    if (authState is AuthAuthenticated) {
      profileId = authState.profile.id;
      context.read<HelpRequestBloc>().add(LoadActiveRequest(profileId));
      context.read<AdminBloc>().add(LoadAdminData());

      final helpState = context.read<HelpRequestBloc>().state;
      if (_tabController.index == 1 &&
          helpState is HelpRequestActive &&
          helpState.request.status == 'accepted') {
        context.read<ChatBloc>().add(LoadMessages(helpState.request.id));
      }
    } else if (authState is AuthOfflineGuest) {
      // Guest mode: Use a dummy ID and skip online re-fetching
      profileId = "offline_guest_id";
    }

    if (profileId != null) {
      _sosBloc = SosBloc(
        repository: context.read<HelpRequestRepository>(),
        lowNetworkRepo: context.read<LowNetworkRepository>(),
        victimId: profileId,
      );
    }
  }

  @override
  void dispose() {
    _stopVictimLocationPush();
    _pulseController.dispose();
    _messageController.dispose();
    _audioPlayer.dispose();
    _n8nScrollController.dispose();
    _helperScrollController.dispose();
    _tabController.dispose();
    _sosBloc?.close();
    super.dispose();
  }

  /// Start pushing victim's live location to the database for rescuers to track
  void _startVictimLocationPush(String requestId) {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen((Position position) {
          context.read<HelpRequestRepository>().updateVictimLocation(
            requestId,
            position.latitude,
            position.longitude,
          );
          debugPrint(
            'Victim: Pushed new location ($requestId): ${position.latitude}, ${position.longitude}',
          );
        });
  }

  void _stopVictimLocationPush() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void _listen() async {
    // Instead of using local _speech, instantly trigger the SOS Engine Guardian!
    _sosBloc?.add(StartSosCapture());
  }

  void _handleSosTap() {
    final now = DateTime.now();
    if (_lastSosTap == null ||
        now.difference(_lastSosTap!) > const Duration(seconds: 1)) {
      _sosTapCount = 1;
    } else {
      _sosTapCount++;
    }
    _lastSosTap = now;

    if (_sosTapCount >= 3) {
      _sosTapCount = 0;
      _listen(); // Trigger SOS Choice flow
    } else {
      // Small feedback toast/snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tap ${3 - _sosTapCount} more times for SOS'),
          duration: const Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() {});
  }

  void _stopListening() {
    // Legacy mapping (no longer needed, VoiceAssistantScreen handles captures)
    if (_isListening) {
      setState(() => _isListening = false);
    }
  }

  void _onTabChanged() {
    if (_tabController.index == 1) {
      final helpState = context.read<HelpRequestBloc>().state;
      String? requestId;
      if (helpState is HelpRequestActive &&
          (helpState.request.status == 'accepted' ||
              helpState.request.status == 'completed')) {
        requestId = helpState.request.id;
      } else if (helpState is HelpRequestConversation &&
          helpState.activeRequest != null &&
          (helpState.activeRequest!.status == 'accepted' ||
              helpState.activeRequest!.status == 'completed')) {
        requestId = helpState.activeRequest!.id;
      }

      if (requestId != null) {
        context.read<ChatBloc>().add(LoadMessages(requestId));
      }
    }
  }

  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Refactored: Timer logic moved to HelpRequestBloc for stream-first reliability.
  void _sendToN8n() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final bool isVoice = _wasVoiced;
    _wasVoiced = false; // Reset for next interaction

    final locationState = context.read<LocationBloc>().state;
    if (locationState is! LocationLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location required for rapid response.'),
          backgroundColor: neonOrange,
        ),
      );
      return;
    }
    double lat = locationState.lat;
    double lng = locationState.lng;

    setState(() {
      _localAiMessages.add({'role': 'user', 'message': text});
    });

    _scrollToBottom(_n8nScrollController);

    context.read<HelpRequestBloc>().add(
      FindHelper(
        message: text,
        victimId: authState.profile.id,
        lat: lat,
        lng: lng,
        isVoice: isVoice,
      ),
    );
  }

  void _sendToHelper() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final helpRequestState = context.read<HelpRequestBloc>().state;
    if (helpRequestState is HelpRequestActive) {
      context.read<ChatBloc>().add(
        SendMessage(
          requestId: helpRequestState.request.id,
          senderId: authState.profile.id,
          senderRole: 'victim',
          message: text,
        ),
      );
      _scrollToBottom(_helperScrollController);
    }
  }

  void _sendMessage() {
    _stopListening();
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Check connectivity status
    final connState = context.read<ConnectivityBloc>().state;
    if (connState.status == ConnectivityStatus.offline) {
      _handleOfflineMessage(text);
      return;
    }

    if (_tabController.index == 0) {
      _sendToN8n();
    } else if (_tabController.index == 1) {
      _wasVoiced =
          false; // Chat with helper doesn't use AI voice assistant path
      _sendToHelper();
    }
    _messageController.clear();
  }

  void _handleOfflineMessage(String text) {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationLoaded) {
      // Add to local UI log immediately
      setState(() {
        _localAiMessages.add({'role': 'user', 'message': text});
      });
      _scrollToBottom(_n8nScrollController);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: _sosBloc!,
          child: LowNetworkSosSheet(
            lat: locationState.lat,
            lon: locationState.lng,
            initialMessage: text,
          ),
        ),
      );
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send SMS: Location unknown'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sosBloc == null) {
      return const Scaffold(
        backgroundColor: darkBg,
        body: Center(child: CircularProgressIndicator(color: neonCyan)),
      );
    }

    return BlocProvider.value(
      value: _sosBloc!,
      child: BlocListener<SosBloc, SosState>(
        listener: _onSosStateChanged,
        child: Scaffold(
          backgroundColor: darkBg,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
              ? null
              : _buildProminentSosButton(),
          bottomNavigationBar: _buildBottomNavBar(context),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                // 🛰 MODERN HEADER
                _buildHeader(context),

                // 💬 MAIN CONTENT REGION
                Expanded(
                  child: Stack(
                    children: [
                      // Active UI Views
                      Column(
                        children: [
                          // Active Alert Panel (Glow Card)
                          _buildActiveAlertPanel(),

                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildN8nChat(),
                                _buildHelperChat(),
                                const HelperGridMap(),
                                const VictimHistoryScreen(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildNightPillInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSosStateChanged(BuildContext context, SosState state) {
    if (state is SosActivated) {
      // Instantly pop up the Google Assistant interface
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (pageContext, animation, secondaryAnimation) =>
              BlocProvider.value(
                value: context.read<SosBloc>(),
                child: const VoiceAssistantScreen(),
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }

    if (state is SosError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (state is SosOfflineInputPending) {
      // First, pop the VoiceAssistantScreen if it was accidentally opened
      // (though branching in Bloc usually prevents this)
      if (Navigator.of(context).canPop()) {
        // Check if top is VoiceAssistantScreen...
        // For now, just show the Bottom Sheet on top
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => BlocProvider.value(
          value: context.read<SosBloc>(),
          child: LowNetworkSosSheet(lat: state.lat, lon: state.lon),
        ),
      );
    }

    if (state is SosOfflineSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SOS DISPATCHED VIA SMS to ${state.phoneNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.greenAccent.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    if (state is SosAwaitingAction) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SELECT SOS TYPE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.woman_rounded, color: Colors.pink),
                title: const Text('WOMEN SAFETY SOS'),
                subtitle: const Text('Instant alert to contacts'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<SosBloc>().add(
                    SelectWomanSafetyAction(state.lat, state.lon),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.mic_rounded, color: Colors.blue),
                title: const Text('VOICE ASSISTANT'),
                subtitle: const Text('Describe your emergency'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<SosBloc>().add(SelectVoiceAssistAction());
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    }

    if (state is SosCaptured) {
      // 🎙️ PERSIST VOICE COMMAND TO CHAT LOG
      setState(() {
        _localAiMessages.add({'role': 'user', 'message': state.message});
      });
      _scrollToBottom(_n8nScrollController);
    }
    // Handoff to HelpRequestBloc is now managed in VoiceAssistantScreen listener
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16 + topPadding, 24, 16),
      decoration: BoxDecoration(gradient: tricolorGradient),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF9933), // Saffron
                      neonCyan, // Primary Blue
                      Color(0xFF138808), // Green
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'Sahayak Setu',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Emergency Response',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Connectivity Status Badge
              BlocBuilder<ConnectivityBloc, ConnectivityState>(
                builder: (context, state) {
                  Color color;
                  IconData icon;
                  switch (state.status) {
                    case ConnectivityStatus.online:
                      color = const Color.fromARGB(255, 25, 54, 38);
                      icon = Icons.wifi;
                      break;
                    case ConnectivityStatus.lowNetwork:
                      color = Colors.orangeAccent;
                      icon = Icons.network_check;
                      break;
                    case ConnectivityStatus.offline:
                      color = Colors.redAccent;
                      icon = Icons.portable_wifi_off;
                      break;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          state.status == ConnectivityStatus.online
                              ? 'Online'
                              : 'Offline',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_rounded, color: neonCyan),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VictimProfileScreen(),
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

  Widget _buildProminentSosButton() {
    return BlocBuilder<SosBloc, SosState>(
      builder: (context, sosState) {
        final isActive = sosState is SosListening;

        return GestureDetector(
          onTap: () {
            if (isActive) {
              _sosBloc!.add(DisableSos());
            } else {
              _handleSosTap();
            }
          },
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = isActive
                  ? 1.0 + (_pulseController.value * 0.1)
                  : 1.0;
              final shadowOpacity = isActive
                  ? (1.0 - _pulseController.value) * 0.5
                  : 0.2;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D4D), Color(0xFFFF1A1A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: shadowOpacity),
                        blurRadius: isActive ? 20 : 10,
                        spreadRadius: isActive ? 10 : 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_in_talk_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 0,
      child: SizedBox(
        height: 60,
        child: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          dividerColor: Colors.transparent,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: Colors.transparent, // No indicator line
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 9,
          ),
          tabs: [
            const Tab(icon: Icon(Icons.smart_toy_outlined), text: 'AI ASSIST'),
            BlocBuilder<HelpRequestBloc, HelpRequestState>(
              builder: (context, state) {
                final active =
                    state is HelpRequestActive &&
                    (state.request.status == 'accepted' ||
                        state.request.status == 'completed');
                return Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: active ? Colors.red : null,
                      ),
                      const SizedBox(height: 4),
                      const Text('CHAT'),
                    ],
                  ),
                );
              },
            ),
            const Tab(icon: Icon(Icons.map_outlined), text: 'MAP'),
            const Tab(icon: Icon(Icons.history_rounded), text: 'HISTORY'),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(String requestId) {
    int rating = 3;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: darkBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: neonCyan.withValues(alpha: 0.5)),
              ),
              title: const Text(
                'FIELD AGENT RATING',
                style: TextStyle(
                  color: neonCyan,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How was the responder?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  if (rating == 3)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Defaulting to 3 stars if skipped.',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 10),
                      ),
                    ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () async {
                    // Skip applies default 3
                    Navigator.pop(ctx);
                    await context.read<LeaderboardRepository>().submitRating(
                      requestId,
                      3,
                    );
                  },
                  child: const Text(
                    'SKIP',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await context.read<LeaderboardRepository>().submitRating(
                      requestId,
                      rating,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rating submitted. Thank you!'),
                        backgroundColor: neonCyan,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonCyan,
                    foregroundColor: darkBg,
                  ),
                  child: const Text(
                    'SUBMIT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActiveAlertPanel() {
    return BlocConsumer<HelpRequestBloc, HelpRequestState>(
      listener: (context, state) {
        if (state is HelpRequestActive) {
          final req = state.request;

          if (req.status == 'accepted') {
            // Intelligent Tab Switch: Only switch to COMMS if not already on a tracking/history tab
            if (_tabController.index == 0) {
              _tabController.animateTo(1);
            }
            _startVictimLocationPush(req.id);
          } else if (req.status == 'rejected') {
            _stopVictimLocationPush();
          } else if (req.status == 'pending') {
            _startVictimLocationPush(req.id);
          } else if (req.status == 'completed') {
            _stopVictimLocationPush();
            if (!_hasShownRatingDialog) {
              _hasShownRatingDialog = true;

              // Async check to prevent showing dialog on every app restart if already rated
              context
                  .read<LeaderboardRepository>()
                  .hasSessionBeenRated(req.id)
                  .then((alreadyRated) {
                    if (!alreadyRated && mounted) {
                      _showRatingDialog(req.id);
                    }
                  });
            }
          }
        }

        if (state is HelpRequestInitial) {
          _stopVictimLocationPush();
          _hasShownRatingDialog = false;
        }

        if (state is HelpRequestConversation) {
          setState(() {
            _localAiMessages.add({'role': 'bot', 'message': state.message});
          });
          _scrollToBottom(_n8nScrollController);
          // 🎙️ AUTO-PLAY VOICE RESPONSE
          if (state.audioPath != null) {
            _audioPlayer.play(DeviceFileSource(state.audioPath!));
          }
        }
      },
      builder: (context, state) {
        if (state is HelpRequestInitial) {
          return const SizedBox.shrink();
        }

        if (state is HelpRequestSearching) {
          // Find if we have a current request to cancel (from persistent BLoC state)
          final activeReq = context
              .read<HelpRequestBloc>()
              .currentActiveRequest;
          return _buildSearchingRadar(activeReq?.id);
        }

        if (state is HelpRequestActive) {
          final req = state.request;
          if (req.status == 'accepted') {
            return _buildNeonStatusHeader(
              '${req.helperName ?? "Responder"} IS EN ROUTE',
              neonCyan,
              Icons.speed_rounded,
              true, // Show map button
              state,
            );
          } else if (req.status == 'completed') {
            return const SizedBox.shrink();
          } else if (req.status == 'pending') {
            return _buildNeonMatchCard(state);
          }
        }

        if (state is HelpRequestConversation) {
          final req = state.activeRequest;
          if (req != null) {
            if (req.status == 'pending' || req.status == 'accepted') {
              return _buildNeonMatchCard(
                HelpRequestActive(
                  req,
                  matchedId: state.matchedId,
                  distance: state.distance,
                ),
              );
            } else if (req.status == 'rejected') {
              return _buildSearchingRadar(req.id);
            }
          }
          // Default: Just chatting or search failed, show nothing.
          return const SizedBox.shrink();
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSearchingRadar([String? requestId]) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: tricolorGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: neonCyan.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: neonCyan,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'UPLINK ACTIVE: LOCATING RESPONDER...',
                  style: TextStyle(
                    color: neonCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              // --- STOP SEARCH BUTTON ---
              TextButton(
                onPressed: () {
                  if (requestId != null) {
                    context.read<HelpRequestBloc>().add(
                      UpdateHelpRequestStatus(
                        requestId: requestId,
                        status: 'cancelled',
                      ),
                    );
                  } else {
                    // Local fallback if no ID yet (Initial search phase)
                    context.read<HelpRequestBloc>().add(ClearHelpRequest());
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: neonOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: neonOrange.withValues(alpha: 0.3)),
                  ),
                ),
                child: const Text(
                  'STOP SEARCH',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeonMatchCard(HelpRequestActive state) {
    final status = state.request.status;
    final isRejected = status == 'rejected';
    final isPending = status == 'pending';
    final color = isRejected ? neonOrange : neonCyan;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tricolorGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Center(
              child: Text(
                isRejected ? 'MATCH DROPPED' : 'SAHAYAK MATCH FOUND',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.request.helperName ?? "ANONYMOUS",
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            state.request.helperOccupation?.toUpperCase() ??
                                "RESPONDER",
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: isRejected ? 'rejected' : 'pending'),
                  ],
                ),
                const SizedBox(height: 20),
                // --- DISTANCE & ETA ---
                if (state.request.distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  state.request.distance!,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPending)
                          const Text(
                            'AWAITING ACCEPTANCE...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonStatusHeader(
    String text,
    Color color,
    IconData icon,
    bool showMap,
    HelpRequestActive state,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tricolorGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              StatusBadge(status: state.request.status),
            ],
          ),
          if (showMap) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VictimMapScreen(request: state.request),
                      ),
                    ),
                    icon: const Icon(
                      Icons.location_searching_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'TRACK SIGNAL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: 11,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: neonCyan,
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (state.request.helperPhone != null &&
                    state.request.helperPhone!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final Uri telUri = Uri.parse(
                          'tel:${state.request.helperPhone}',
                        );
                        if (await canLaunchUrl(telUri)) {
                          await launchUrl(telUri);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('COULD NOT INITIALIZE CALL'),
                              backgroundColor: neonOrange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text(
                        'CALL RESPONDER',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonCyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: neonCyan.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildN8nChat() {
    return BlocBuilder<HelpRequestBloc, HelpRequestState>(
      builder: (context, state) {
        final isCompleted =
            state is HelpRequestActive && state.request.status == 'completed';
        if (_localAiMessages.isEmpty &&
            (state is HelpRequestInitial || isCompleted)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: neonCyan.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF9933), // Saffron
                        Colors.white,
                        Color(0xFF138808), // Green
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF9933), // Saffron
                      Color(
                        0xFF000080,
                      ), // Navy Blue (better for text contrast than pure white)
                      Color(0xFF138808), // Green
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: const Text(
                    'AI SAHAYAK READY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TRANSMIT YOUR EMERGENCY',
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          );
        }
        return Stack(
          children: [
            Center(
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: MediaQuery.of(context).size.width * 0.6,
                  color: neonCyan,
                ),
              ),
            ),
            ListView.builder(
              controller: _n8nScrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _localAiMessages.length,
              itemBuilder: (context, index) {
                final msg = _localAiMessages[index];
                final isBot = msg['role'] != 'user';
                return ChatBubble(
                  message: msg['message']!,
                  isMe: !isBot,
                  senderLabel: isBot ? 'AI-CORE' : 'ME',
                  onSpeak: isBot
                      ? () async {
                          final path = await context
                              .read<HelpRequestRepository>()
                              .triggerTTS(msg['message']!);
                          if (path != null) {
                            await _audioPlayer.stop();
                            await _audioPlayer.play(DeviceFileSource(path));
                          }
                        }
                      : null,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelperChat() {
    return BlocBuilder<HelpRequestBloc, HelpRequestState>(
      builder: (context, helpState) {
        final isActiveMission =
            helpState is HelpRequestActive &&
            (helpState.request.status == 'accepted' ||
                helpState.request.status == 'completed');

        if (!isActiveMission) {
          return Center(
            child: Opacity(
              opacity: 0.3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ENCRYPTED LINK OFFLINE',
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return BlocBuilder<ChatBloc, ChatState>(
          builder: (context, chatState) {
            if (chatState is ChatLoaded) {
              final authState = context.read<AuthBloc>().state;
              final userId = authState is AuthAuthenticated
                  ? authState.profile.id
                  : '';
              final messages = chatState.messages;
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'CHANNEL ESTABLISHED. COMMENCE DATA TRANSFER.',
                    style: TextStyle(
                      color: neonCyan,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              _scrollToBottom(_helperScrollController);
              return Stack(
                children: [
                  Center(
                    child: Opacity(
                      opacity: 0.05,
                      child: Icon(
                        Icons.support_agent_rounded,
                        size: MediaQuery.of(context).size.width * 0.6,
                        color: neonCyan,
                      ),
                    ),
                  ),
                  ListView.builder(
                    controller: _helperScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == userId;
                      return ChatBubble(
                        message: msg.message,
                        isMe: isMe,
                        senderLabel: isMe ? 'CLIENT' : 'RESPONDER',
                      );
                    },
                  ),
                ],
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: neonCyan),
            );
          },
        );
      },
    );
  }

  Widget _buildNightPillInput() {
    return BlocBuilder<HelpRequestBloc, HelpRequestState>(
      builder: (context, helpState) {
        if (_tabController.index == 2 || _tabController.index == 3) {
          return const SizedBox.shrink();
        }

        bool isResolved =
            (helpState is HelpRequestActive &&
            helpState.request.status == 'completed');
        bool disableAiInput =
            _tabController.index == 0 && (helpState is HelpRequestSearching);

        if (isResolved && _tabController.index == 1) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: const Center(
              child: Text(
                'MISSION ARCHIVED. LINK TERMINATED.',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          );
        }

        final isChatTab = _tabController.index == 1;
        final leadingIcon = isChatTab
            ? Icons.chat_bubble_outline
            : Icons.auto_awesome;
        final hintText = isChatTab
            ? 'Type message for responder...'
            : (disableAiInput ? 'PROBING NETWORK...' : 'Ask AI Assistant...');
        final sendIcon = isChatTab
            ? Icons.send_rounded
            : Icons.arrow_upward_rounded;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFE3F2FD),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        leadingIcon,
                        color: const Color(0xFF2196F3),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !disableAiInput,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onSubmitted: disableAiInput
                              ? null
                              : (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListening
                              ? Colors.red
                              : Colors.grey.shade400,
                        ),
                        onPressed: _listen,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: disableAiInput ? null : _sendMessage,
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: disableAiInput
                        ? Colors.grey.shade300
                        : const Color(0xFF2196F3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!disableAiInput)
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Icon(
                    sendIcon,
                    color: Colors.white,
                    size: isChatTab
                        ? 24
                        : 28, // send_rounded looks better slightly smaller
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchTx(String hash) async {
    final url = Uri.parse('https://amoy.polygonscan.com/tx/$hash');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }
}
