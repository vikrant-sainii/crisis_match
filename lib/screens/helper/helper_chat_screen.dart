import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../blocs/help_request/help_request_bloc.dart';
import '../../blocs/help_request/help_request_event.dart';
import '../../blocs/help_request/help_request_state.dart';
import '../../models/help_request_model.dart';
import '../../widgets/chat_bubble.dart';
import 'helper_map_screen.dart';

/// Chat screen for a helper to communicate with a specific victim.
/// Each instance creates its own ChatBloc so multiple chats don't conflict.
class HelperChatScreen extends StatefulWidget {
  final HelpRequestModel request;

  const HelperChatScreen({super.key, required this.request});

  @override
  State<HelperChatScreen> createState() => _HelperChatScreenState();
}

class _HelperChatScreenState extends State<HelperChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String _victimName = 'Victim';

  // 🏙 SOFT UI THEME CONSTANTS
  static const Color darkBg = Color(0xFFF8FAFC);
  static const Color slatePanel = Colors.white;
  static const Color neonCyan = Color(0xFF2563EB); // Trust Blue
  static const Color glassBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    
    // Use the GLOBAL ChatBloc from context
    // Load existing messages and subscribe to realtime updates
    context.read<ChatBloc>().add(LoadMessages(widget.request.id));
    
    // Fetch victim's name from profiles
    _fetchVictimName();
  }

  Future<void> _fetchVictimName() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', widget.request.victimId)
          .maybeSingle();
      if (data != null && data['full_name'] != null && mounted) {
        setState(() {
          _victimName = data['full_name'] as String;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    context.read<ChatBloc>().add(SendMessage(
      requestId: widget.request.id,
      senderId: authState.profile.id,
      senderRole: 'helper',
      message: _messageController.text.trim(),
    ));

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
              // 🛰 CYBER COMMS HEADER
              _buildCyberChatHeader(),

              // 📟 MISSION STATUS BAR
              _buildMissionStatusBar(),

              // 💬 CHAT STREAM
              Expanded(
                child: Stack(
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
                    BlocBuilder<ChatBloc, ChatState>(
                      builder: (context, state) {
                        if (state is ChatLoaded) {
                          final authState = context.read<AuthBloc>().state;
                          final userId = authState is AuthAuthenticated ? authState.profile.id : '';
                          final messages = state.messages;

                          if (messages.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: neonCyan.withValues(alpha: 0.1), width: 2)),
                                    child: const Icon(Icons.wifi_tethering_rounded, size: 48, color: neonCyan),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('LINK ESTABLISHED', style: TextStyle(color: neonCyan, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3)),
                                  const SizedBox(height: 8),
                                  Text('WAITING FOR DATA PACKETS FROM $_victimName', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 10, letterSpacing: 1.5)),
                                ],
                              ),
                            );
                          }

                          _scrollToBottom();
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg.senderId == userId;
                              return ChatBubble(
                                message: msg.message,
                                isMe: isMe,
                                senderLabel: isMe ? 'YOU' : _victimName.toUpperCase(),
                              );
                            },
                          );
                        }
                        if (state is ChatError) {
                          return Center(child: Text('UPLINK ERROR: ${state.message}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)));
                        }
                        return const Center(child: CircularProgressIndicator(color: neonCyan));
                      },
                    ),
                  ],
                ),
              ),

              // ⌨️ NIGHT-PILL INPUT
              _buildNightPillInput(),
            ],
          ),
        ),
    );
  }

  Widget _buildCyberChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _victimName.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                Text(
                  'SECURE RESPONSE CHANNEL',
                  style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: neonCyan.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.radar_rounded, color: neonCyan),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelperMapScreen(request: widget.request))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionStatusBar() {
    return BlocBuilder<HelpRequestBloc, HelpRequestState>(
      builder: (context, state) {
        bool isResolved = false;
        if (state is HelpRequestActive && state.request.status == 'completed') isResolved = true;

        final color = isResolved ? const Color(0xFF10B981) : neonCyan;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(isResolved ? Icons.verified_rounded : Icons.bolt_rounded, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isResolved ? 'MISSION ACCOMPLISHED' : 'DEPLOYMENT ACTIVE: ${widget.request.crisisType.toUpperCase()}',
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
              if (!isResolved)
                TextButton(
                  onPressed: () => _showResolveDialog(),
                  child: const Text('FINALIZE', style: TextStyle(color: neonCyan, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showResolveDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: slatePanel,
        title: const Text('FINALIZE MISSION?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you have completed providing aid? This will lock the channel and archive the logs.', style: TextStyle(color: Colors.blueGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('GO BACK', style: TextStyle(color: Colors.blueGrey))),
          ElevatedButton(
            onPressed: () {
              context.read<HelpRequestBloc>().add(UpdateHelpRequestStatus(requestId: widget.request.id, status: 'completed'));
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: neonCyan, foregroundColor: darkBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('CONFIRM RESOLUTION', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildNightPillInput() {
    return BlocBuilder<HelpRequestBloc, HelpRequestState>(
      builder: (context, helpState) {
        bool isResolved = false;
        if (helpState is HelpRequestActive && helpState.request.status == 'completed') isResolved = true;

        if (isResolved) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: const Center(child: Text('MISSION ARCHIVED. COMMS LINK TERMINATED.', style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontStyle: FontStyle.italic, letterSpacing: 1.5))),
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: neonCyan,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: neonCyan.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
