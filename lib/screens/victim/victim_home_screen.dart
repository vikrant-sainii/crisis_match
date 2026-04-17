import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
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
import '../../widgets/sos_capture_overlay.dart';
import '../../widgets/wake_word_dialog.dart';
import 'victim_map_screen.dart';
import 'voice_assistant_screen.dart';
import '../../repositories/help_request_repository.dart';
import '../../models/help_request_model.dart';
import '../../blocs/admin/admin_bloc.dart';
import '../../blocs/admin/admin_event.dart';
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

  Timer? _timeoutTimer; // 5-minute timeout timer
  bool _canRetry = false; // Toggled by timer or rejection

  // Location streaming for real-time tracking
  StreamSubscription<Position>? _positionStream;

  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _wasVoiced = false; // Flag to track if the current message started as voice

  // Audio Player for AI responses
  late AudioPlayer _audioPlayer;

  // SOS BLoC (created lazily with victimId)
  SosBloc? _sosBloc;

  // 🌃 CYBER-DARK THEME CONSTANTS
  static const Color darkBg = Color(0xFF0F172A); // Midnight Navy
  static const Color slatePanel = Color(0xFF1E293B); // Slate Blue-Grey
  static const Color neonCyan = Color(0xFF22D3EE); // Electric Cyan
  static const Color neonOrange = Color(0xFFFB923C); // Hazard Orange
  static const Color glassBorder = Color(0x3394A3B8); // Semi-transparent border

  // Locally store initial AI messages for visual feedback
  final List<Map<String, String>> _localAiMessages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    context.read<LocationBloc>().add(GetCurrentLocation());

    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<HelpRequestBloc>().add(
        LoadActiveRequest(authState.profile.id),
      );
      context.read<AdminBloc>().add(LoadAdminData());

      // Create SOS BLoC with victim's ID
      _sosBloc = SosBloc(
        repository: context.read<HelpRequestRepository>(),
        victimId: authState.profile.id,
      );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
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
    _sosBloc?.add(SosPowerButtonTriggered());
  }

  void _stopListening() {
    // Legacy mapping (no longer needed, VoiceAssistantScreen handles closing)
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
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

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) {
        setState(() {
          final state = context.read<HelpRequestBloc>().state;
          if (state is HelpRequestActive && state.request.status == 'pending') {
            context.read<HelpRequestBloc>().add(
              RejectRequest(state.request.id),
            );
          }
          _canRetry = true;
        });
      }
    });
  }

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
      _canRetry = false;
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
    _startTimeoutTimer();
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
    if (_tabController.index == 0) {
      _sendToN8n();
    } else if (_tabController.index == 1) {
      _wasVoiced = false; // Chat with helper doesn't use AI voice assistant path
      _sendToHelper();
    }
    _messageController.clear();

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
          body: SafeArea(
            child: Stack(
              children: [
                // Main content
                Column(
                  children: [
                    // 🛰 FLOATING CYBER HEADER
                    _buildCyberHeader(),

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

                          // Active UI Views
                          Column(
                            children: [
                              // Active Alert Panel (Glow Card)
                              _buildActiveAlertPanel(),

                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildN8nChat(),
                                    _buildHelperChat(),
                                    const HelperGridMap(),
                                    _buildHistoryTab(),
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
    if (state is SosResponseState) {
      // Play voice response
      if (state.audioPath != null) {
        _audioPlayer.play(DeviceFileSource(state.audioPath!));
      }

      // Add AI reply to local chat messages
      setState(() {
        _localAiMessages.add({'role': 'bot', 'message': state.voiceReply});
      });
      _scrollToBottom(_n8nScrollController);

      // If a helper was matched, hand off to HelpRequestBloc
      if (state.matchData != null) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          context.read<HelpRequestBloc>().add(
                LoadActiveRequest(authState.profile.id),
              );
        }
      }

      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.matchData != null
                ? 'SOS PROCESSED — HELPER MATCHED'
                : 'SOS PROCESSED — AWAITING MATCH',
          ),
          backgroundColor: state.matchData != null ? neonCyan : neonOrange,
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
                'CRISIS-MATCH',
                style: TextStyle(
                  color: neonCyan,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'ENCRYPTED RESPONSE CHANNEL',
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
              // 🛡️ SOS Shield Toggle
              _buildSosToggle(),
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
                    color: neonOrange,
                  ),
                  onPressed: () {
                    _sosBloc?.add(DisableSos());
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

  Widget _buildSosToggle() {
    return BlocBuilder<SosBloc, SosState>(
      builder: (context, sosState) {
        final isActive = sosState is SosListening;
        final Color shieldColor = isActive ? Colors.greenAccent : Colors.blueGrey;

        return Tooltip(
          message: isActive ? 'SOS Guardian Active' : 'Shake device vigorously to send emergency SOS',
          child: GestureDetector(
            onTap: () {
              if (isActive) {
                _sosBloc!.add(DisableSos());
              } else {
                _sosBloc!.add(EnableSos());
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.greenAccent.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? Colors.greenAccent.withOpacity(0.5)
                      : glassBorder,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: shieldColor,
                    size: 22,
                  ),
                  if (isActive && sosState is SosListening && sosState.gZ != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Z: ${sosState.gZ!.toStringAsFixed(2)}g',
                      style: const TextStyle(fontSize: 9, color: Colors.greenAccent),
                    ),
                    Text(
                      'Shakes: ${sosState.shakeCount}',
                      style: const TextStyle(fontSize: 9, color: Colors.greenAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildCyberSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          fontSize: 11,
          letterSpacing: 1,
        ),
        tabs: [
          const Tab(text: 'AI PROBE'),
          BlocBuilder<HelpRequestBloc, HelpRequestState>(
            builder: (context, state) {
              final active =
                  state is HelpRequestAccepted || state is HelpRequestResolved;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('COMMS'),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const Tab(text: 'THE GRID'),
          const Tab(text: 'LOGS'),
        ],
      ),
    );
  }

  Widget _buildActiveAlertPanel() {
    return BlocConsumer<HelpRequestBloc, HelpRequestState>(
      listener: (context, state) {
        if (state is HelpRequestAccepted) {
          context.read<ChatBloc>().add(LoadMessages(state.request.id));
          _timeoutTimer?.cancel();
          _tabController.animateTo(1);
          _startVictimLocationPush(state.request.id);
        }
        if (state is HelpRequestRejected) {
          _timeoutTimer?.cancel();
          _stopVictimLocationPush();
          setState(() => _canRetry = true);
        }
        if (state is HelpRequestPending) {
          if (_timeoutTimer == null || !_timeoutTimer!.isActive) {
            _startTimeoutTimer();
          }
          _startVictimLocationPush(state.request.id);
        }
        if (state is HelpRequestInitial || state is HelpRequestResolved) {
          _stopVictimLocationPush();
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
        if (state is HelpRequestSearching) {
          return _buildSearchingRadar();
        }
        if (state is HelpRequestPending || state is HelpRequestRejected) {
          return _buildNeonMatchCard(state as HelpRequestActive);
        }
        if (state is HelpRequestAccepted) {
          return _buildNeonStatusHeader(
            '${state.request.helperName ?? "Responder"} IS EN ROUTE',
            neonCyan,
            Icons.speed_rounded,
            true, // Show map button
            state,
          );
        }
        if (state is HelpRequestResolved) {
          return _buildNeonStatusHeader(
            'THREAT NEUTRALIZED / AID DELIVERED',
            Colors.greenAccent,
            Icons.verified_rounded,
            false,
            state,
          );
        }
        if (state is HelpRequestConversation && state.activeRequest != null) {
          final req = state.activeRequest!;
          if (req.status == 'accepted') {
            return _buildNeonStatusHeader(
              '${req.helperName ?? "Responder"} IS EN ROUTE',
              neonCyan,
              Icons.speed_rounded,
              true,
              HelpRequestAccepted(req),
            );
          } else if (req.status == 'pending' || req.status == 'rejected') {
            return _buildNeonMatchCard(HelpRequestPending(req));
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSearchingRadar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: slatePanel.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.1).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: neonCyan.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.radar_rounded, color: neonCyan, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'UPLINK ACTIVE: LOCATING NEAREST RESPONDER...',
            style: TextStyle(
              color: neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonMatchCard(HelpRequestActive state) {
    final isRejected = state is HelpRequestRejected;
    final color = isRejected ? neonOrange : neonCyan;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slatePanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Center(
              child: Text(
                isRejected ? 'MATCH DROPPED' : 'PROXY MATCH FOUND',
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
                        color: darkBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: glassBorder),
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
                              color: Colors.white,
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
                if (state is! HelpRequestPending && (isRejected || _canRetry))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final authState = context.read<AuthBloc>().state;
                        if (authState is AuthAuthenticated) {
                          final locState = context.read<LocationBloc>().state;
                          if (locState is LocationLoaded) {
                            setState(() {
                              _canRetry = false;
                              _localAiMessages.add({
                                'role': 'bot',
                                'message': 'Write you help request again...',
                              });
                            });
                            // Fresh search using original crisis type but current location
                            context.read<HelpRequestBloc>().add(
                              FindHelper(
                                message: state.request.crisisType,
                                victimId: authState.profile.id,
                                lat: locState.lat,
                                lng: locState.lng,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('WAITING FOR GPS LOCK...'),
                                backgroundColor: neonOrange,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonCyan,
                        foregroundColor: darkBg,
                        elevation: 10,
                        shadowColor: neonCyan.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'RE-SCAN FOR PROXIMITY',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(neonCyan),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'WAITING FOR ENCRYPTION HANDSHAKE...',
                        style: TextStyle(
                          color: Colors.blueGrey.shade400,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
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
        color: slatePanel.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20)],
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
                  child: OutlinedButton.icon(
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
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: neonCyan,
                      side: const BorderSide(color: neonCyan),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonCyan,
                        foregroundColor: darkBg,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 10,
                        shadowColor: neonCyan.withOpacity(0.5),
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
        if (_localAiMessages.isEmpty && state is HelpRequestInitial) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: neonCyan.withOpacity(0.1),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 64,
                    color: neonCyan,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AI CORE READY',
                  style: TextStyle(
                    color: neonCyan,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TRANSMIT YOUR EMERGENCY PROTOCOL',
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
        return ListView.builder(
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
        );

      },
    );
  }

  Widget _buildHelperChat() {
    return BlocBuilder<HelpRequestBloc, HelpRequestState>(
      builder: (context, helpState) {
        if (helpState is! HelpRequestAccepted &&
            helpState is! HelpRequestResolved) {
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
              return ListView.builder(
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

  Widget _buildHistoryTab() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    return FutureBuilder<List<HelpRequestModel>>(
      future: context.read<HelpRequestRepository>().getVictimHistory(
        authState.profile.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: neonCyan),
          );
        }
        final history = (snapshot.data ?? [])
            .where((r) => r.status == 'completed' || r.status == 'rejected')
            .toList();
        if (history.isEmpty) {
          return const Center(
            child: Text(
              'ARCHIVES EMPTY',
              style: TextStyle(color: Colors.blueGrey, letterSpacing: 2),
            ),
          );
        }

        return ListView.builder(
          itemCount: history.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final req = history[index];
            final isCompleted = req.status == 'completed';
            final color = isCompleted ? Colors.greenAccent : neonOrange;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: slatePanel.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: Icon(
                  isCompleted
                      ? Icons.check_circle_outline_rounded
                      : Icons.history_toggle_off_rounded,
                  color: color,
                ),
                title: Text(
                  req.crisisType.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'RESPONDER: ${req.helperName ?? "ANON"}',
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 11,
                  ),
                ),
                trailing: StatusBadge(status: req.status),
                onTap: req.txHash != null ? () => _launchTx(req.txHash!) : null,
              ),
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
            (helpState is HelpRequestResolved) ||
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

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: darkBg,
            boxShadow: [
              BoxShadow(
                color: neonCyan.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: slatePanel,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: disableAiInput
                          ? Colors.transparent
                          : neonCyan.withOpacity(0.3),
                    ),
                    boxShadow: [
                      if (!disableAiInput)
                        BoxShadow(
                          color: neonCyan.withOpacity(0.05),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: TextField(
                    controller: _messageController,
                    enabled: !disableAiInput,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: disableAiInput
                          ? 'PROBING NETWORK...'
                          : 'DATA INPUT...',
                      hintStyle: TextStyle(
                        color: Colors.blueGrey.shade600,
                        letterSpacing: 1,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      suffixIcon: !disableAiInput
                          ? IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening
                                    ? neonOrange
                                    : Colors.blueGrey,
                              ),
                              onPressed: _listen,
                            )
                          : null,
                    ),
                    onSubmitted: disableAiInput ? null : (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: disableAiInput ? null : _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: disableAiInput ? Colors.blueGrey.shade800 : neonCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!disableAiInput)
                        BoxShadow(
                          color: neonCyan.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: darkBg,
                    size: 24,
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
