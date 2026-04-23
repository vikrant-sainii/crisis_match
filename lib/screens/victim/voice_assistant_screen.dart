import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/sos/sos_bloc.dart';
import '../../blocs/sos/sos_state.dart';
import '../../blocs/help_request/help_request_bloc.dart';
import '../../blocs/help_request/help_request_event.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314), // Deep Google Assistant dark grey
      body: BlocConsumer<SosBloc, SosState>(
        listener: (context, state) {
          if (state is SosDisabled) {
            Navigator.of(context).pop();
          } else if (state is SosCaptured) {
            // THE CRITICAL HANDOFF: Pass captured message to the main app dashboard
            final authState = context.read<AuthBloc>().state;
            final locationState = context.read<LocationBloc>().state;

            if (authState is AuthAuthenticated && locationState is LocationLoaded) {
              context.read<HelpRequestBloc>().add(
                FindHelper(
                  message: state.message,
                  victimId: authState.profile.id,
                  lat: locationState.lat,
                  lng: locationState.lng,
                  isVoice: true,
                ),
              );
            }

            // Close the voice UI so they can see the Chat/Map dashboard
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          String header = "Guardian Assist";
          String liveText = "";
          bool isListening = false;
          bool isThinking = false;

          if (state is SosActivated) {
            header = "Preparing...";
            isListening = true;
          } else if (state is SosCapturing) {
            header = "Listening...";
            liveText = state.liveText.trim().isEmpty ? "..." : state.liveText;
            isListening = true;
          } else if (state is SosCaptured) {
            header = "Mission Accepted";
            liveText = "Sending: ${state.message}";
            isThinking = true;
          } else if (state is SosError) {
             header = "Error";
             liveText = state.message;
          }

          return SafeArea(
            child: Stack(
              children: [
                // Top Action Bar
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 32),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),

                // Main Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // Top Chip Indicator
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isThinking ? Icons.cloud_sync : Icons.mic_none_outlined,
                              color: isThinking ? Colors.blueAccent : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              header,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Expanded(flex: 3, child: SizedBox()),

                    // Live Text Display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          liveText,
                          key: ValueKey(liveText),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),

                    const Expanded(flex: 4, child: SizedBox()),
                  ],
                ),

                // Bottom Assistant Glow Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final pulse = _animController.value;
                      return Container(
                        height: isListening 
                            ? 60 + (pulse * 30) // Breathes when listening
                            : isThinking ? 40 : 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isThinking
                                ? [
                                    Colors.blueAccent,
                                    Colors.cyanAccent,
                                    Colors.blue,
                                    Colors.indigo,
                                  ]
                                : [
                                    Colors.redAccent,
                                    Colors.blueAccent,
                                    Colors.yellowAccent,
                                    Colors.greenAccent,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.33, 0.66, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isThinking ? Colors.blue : Colors.white).withOpacity(0.3 * pulse),
                              blurRadius: 40 + (pulse * 20),
                              spreadRadius: 10 + (pulse * 10),
                            ),
                          ],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(50),
                            topRight: Radius.circular(50),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
