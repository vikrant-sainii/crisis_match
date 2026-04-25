import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/help_request_model.dart';
import '../../models/leaderboard_entry_model.dart';
import '../../repositories/leaderboard_repository.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/status_badge.dart';

class VictimHistoryDetailScreen extends StatefulWidget {
  final HelpRequestModel request;

  const VictimHistoryDetailScreen({super.key, required this.request});

  @override
  State<VictimHistoryDetailScreen> createState() => _VictimHistoryDetailScreenState();
}

class _VictimHistoryDetailScreenState extends State<VictimHistoryDetailScreen> {
  LeaderboardEntry? _helperStats;
  int? _sessionRating;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  GoogleMapController? _mapController;

  LatLng? get _helperLocation {
    if (_helperStats?.lat != null && _helperStats?.lng != null) {
      return LatLng(_helperStats!.lat!, _helperStats!.lng!);
    }
    if (widget.request.helperCurrLat != null && widget.request.helperCurrLong != null) {
      return LatLng(widget.request.helperCurrLat!, widget.request.helperCurrLong!);
    }
    if (widget.request.helperLat != null && widget.request.helperLng != null) {
      return LatLng(widget.request.helperLat!, widget.request.helperLng!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    context.read<ChatBloc>().add(LoadMessages(widget.request.id));
  }

  Future<void> _loadData() async {
    final repo = context.read<LeaderboardRepository>();
    final stats = await repo.getHelperWithStats(widget.request.helperId);
    final rating = await repo.getSessionRating(widget.request.id);
    if (mounted) {
      setState(() {
        _helperStats = stats;
        _sessionRating = rating;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = widget.request.status == 'completed';
    final accentColor = isCompleted ? Colors.greenAccent.shade700 : Colors.redAccent;

    const saffron = Color(0xFFFF9933);
    const white = Color(0xFFFFFFFF);
    const green = Color(0xFF138808);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [saffron, Colors.black87, green],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: const Text(
            'PAST INCIDENTS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
        ),
    
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. Helper Detail Card (with Integrated Map)
          _buildHelperCard(theme, accentColor),

          // 2. Chat Transcript Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_edu_rounded, size: 14, color: theme.primaryColor),
                ),
                const SizedBox(width: 10),
                Text(
                  'COMMUNICATION TRANSCRIPT',
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Icon(Icons.shield_rounded, size: 14, color: Colors.green.shade400),
              ],
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoaded) {
                    final messages = state.messages;
                    if (messages.isEmpty) {
                      return const Center(child: Text('NO DATA TRANSFERRED'));
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderRole == 'victim';
                        final timeStr = msg.createdAt != null 
                            ? DateFormat('hh:mm a').format(msg.createdAt!) 
                            : null;
                        
                        return ChatBubble(
                          message: msg.message,
                          isMe: isMe,
                          senderLabel: isMe ? 'ME' : 'RESPONDER',
                          time: timeStr,
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
          ),
          // 4. Mission Summary Panel (Bottom)
          _buildMissionSummary(theme),
        ],
      ),
    );
  }

  Widget _buildHelperCard(ThemeData theme, Color accentColor) {
    const saffron = Color(0xFFFF9933);
    const green = Color(0xFF138808);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            saffron.withOpacity(0.08),
            Colors.white,
            green.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [saffron, Colors.white, green],
                        ),
                        boxShadow: [
                          BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person_rounded, color: theme.primaryColor, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.request.helperName?.toUpperCase() ?? 'ANONYMOUS',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            widget.request.helperOccupation?.toUpperCase() ?? 'RESPONDER',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: widget.request.status),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isLoading 
                    ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('RATING', _sessionRating?.toString() ?? 'N/A', Icons.star_rounded, Colors.amber),
                          _buildStatItem('SCORE', _helperStats?.totalScore.toInt().toString() ?? '0', Icons.bolt_rounded, Colors.blue),
                          _buildStatItem('HELPS', _helperStats?.totalHelps.toString() ?? '0', Icons.handshake_rounded, Colors.purple),
                        ],
                      ),
                ),
              ],
            ),
          ),
          
          if (_helperLocation != null)
            Container(
              height: 180,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: _helperLocation!,
                        zoom: 13,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('helper'),
                          position: _helperLocation!,
                        ),
                      },
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_helperLocation!, 15),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                            ],
                          ),
                          child: Icon(Icons.my_location_rounded, color: theme.primaryColor, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.blueGrey.shade300,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMissionSummary(ThemeData theme) {
    final createdAt = widget.request.createdAt ?? DateTime.now();
    final updatedAt = widget.request.updatedAt ?? createdAt;
    final dateStr = DateFormat('MMMM dd, yyyy').format(createdAt);
    final timeStr = DateFormat('hh:mm a').format(createdAt);
    
    final duration = updatedAt.difference(createdAt);
    final durationStr = "${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              Icons.calendar_today_rounded,
              dateStr,
              timeStr,
              Colors.blue,
            ),
          ),
          Container(height: 40, width: 1, color: Colors.grey.shade200),
          Expanded(
            child: _buildSummaryItem(
              Icons.timer_outlined,
              'DURATION',
              durationStr,
              Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
