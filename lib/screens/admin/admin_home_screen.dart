import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/admin/admin_bloc.dart';
import '../../blocs/admin/admin_event.dart';
import '../../blocs/admin/admin_state.dart';
import '../../config/supabase_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../widgets/helper_grid_map.dart';
import '../shared/leaderboard_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedOccupation = ''; 
  String _selectedState = 'Maharashtra';
  LatLng _selectedLocation = const LatLng(19.0760, 72.8777); // Default Mumbai
  GoogleMapController? _mapController;

  static const List<String> _states = ['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'Gujarat', 'Punjab', 'Chandigarh'];
  static const Color neonCyan = Color(0xFF22D3EE);
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<AdminBloc>().add(LoadAdminData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=${SupabaseConfig.googleMapsApiKey}',
    );
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        final latLng = LatLng(location['lat'], location['lng']);
        setState(() => _selectedLocation = latLng);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
      }
    } catch (e) {
      debugPrint('Search Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('ADMIN COMMAND CENTER', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: neonCyan)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Color(0xFFFFD700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.orangeAccent),
            onPressed: () {
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.blueGrey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: [
            const Tab(icon: Icon(Icons.map_rounded), text: 'MAP'),
            const Tab(icon: Icon(Icons.person_add_rounded), text: 'HELPER'),
            Tab(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(Icons.verified_user_rounded),
                   const SizedBox(width: 4),
                   _PulsingDot(),
                ],
              ),
              text: 'APPROVALS',
            ),
            const Tab(icon: Icon(Icons.report_gmailerrorred_rounded), text: 'SPAM'),
          ],
        ),
      ),
      body: BlocListener<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          }
          if (state is AdminActionError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red));
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMapTab(),
            _buildAddHelperTab(),
            _buildApprovalsTab(),
            _buildSpamReportsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return const HelperGridMap();
  }
// ... existing code ...
  Widget _buildSpamReportsTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) return const Center(child: CircularProgressIndicator());
        if (state is AdminDataLoaded) {
          final spam = state.spamReports;
          if (spam.isEmpty) return const Center(child: Text('NO FRAUD REPORTS DETECTED', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: spam.length,
            itemBuilder: (context, index) {
              final req = spam[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.report_problem_rounded, color: Colors.orangeAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req.crisisType.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                              Text('REPORTED VICTIM: ${req.victimName ?? 'Anonymous'}', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.blueGrey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RESTRICTION PERIOD', style: TextStyle(color: Colors.blueGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                            Text('15 DAYS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: () {
                             context.read<AdminBloc>().add(BlockVictim(profileId: req.victimId, requestId: req.id));
                          },
                          child: const Text('BLOCK VICTIM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAddHelperTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is! AdminDataLoaded) return const Center(child: CircularProgressIndicator());
        
        final occupations = state.occupations;
        if (_selectedOccupation.isEmpty && occupations.isNotEmpty) {
          _selectedOccupation = occupations.first;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('REGISTER NEW RESCUE AGENT', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 24),
              _buildTextField(_emailController, 'EMAIL ADDRESS', Icons.email),
              const SizedBox(height: 16),
              _buildTextField(_nameController, 'FULL NAME', Icons.person),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, 'TEMPORARY PASSWORD', Icons.lock, obscure: true),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildDropdown('OCCUPATION', occupations, _selectedOccupation, (v) => setState(() => _selectedOccupation = v!))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdown('STATE / REGION', _states, _selectedState, (v) => setState(() => _selectedState = v!))),
                ],
              ),
              const SizedBox(height: 32),
              const Text('SELECT BASE LOCATION (SEARCH OR TAP)', style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                height: 300,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueGrey)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 12),
                        onMapCreated: (c) => _mapController = c,
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                           Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                        },
                        onTap: (latLng) => setState(() => _selectedLocation = latLng),
                        markers: {
                           Marker(markerId: const MarkerId('selected'), position: _selectedLocation, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan)),
                        },
                      ),
                      Positioned(
                        top: 10, left: 10, right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(hintText: 'Search location...', border: InputBorder.none, suffixIcon: Icon(Icons.search)),
                            onSubmitted: _searchLocation,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    context.read<AdminBloc>().add(AddHelperAccount(
                      email: _emailController.text,
                      password: _passwordController.text,
                      fullName: _nameController.text,
                      occupation: _selectedOccupation,
                      state: _selectedState,
                      lat: _selectedLocation.latitude,
                      lng: _selectedLocation.longitude,
                    ));
                  },
                  child: const Text('PROVISION ACCOUNT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            underline: const SizedBox(),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase().replaceAll('_', ' '), style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalsTab() {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) return const Center(child: CircularProgressIndicator());
        if (state is AdminDataLoaded) {
          final pending = state.pendingApprovals;
          if (pending.isEmpty) return const Center(child: Text('NO SESSIONS AWAITING APPROVAL', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final req = pending[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueGrey.withOpacity(0.3))),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req.crisisType.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                              Text('VICTIM: ${req.victimName ?? 'Anonymous'}', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.blueGrey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RESPONDER', style: TextStyle(color: Colors.blueGrey, fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(req.helperName ?? 'ANON', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: () => context.read<AdminBloc>().add(ApproveRequest(req)),
                          child: const Text('APPROVE & HASH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 4, spreadRadius: 1)]),
      ),
    );
  }
}
