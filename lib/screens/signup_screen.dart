import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../repositories/helper_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _stateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'victim';

  // 🌃 CYBER-DARK THEME CONSTANTS
  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color glassBorder = Color(0x3394A3B8);

  List<String> _availableOccupations = [];
  bool _isLoadingOccupations = true;
  String? _selectedOccupation;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchOccupations();
  }

  Future<void> _fetchOccupations() async {
    try {
      final occupations = await HelperRepository().getAvailableOccupations();
      if (mounted) {
        setState(() {
          _availableOccupations = occupations;
          _isLoadingOccupations = false;
          if (_availableOccupations.isNotEmpty) {
            _selectedOccupation = _availableOccupations.first;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingOccupations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text('JOIN THE GRID', style: TextStyle(color:Colors.white,fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pop(context); // Go back, app.dart will handle routing
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCyberTextField(
                  controller: _nameController,
                  label: 'FULL NAME',
                  icon: Icons.person_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'REQUIRED' : null,
                ),
                const SizedBox(height: 20),
                _buildCyberTextField(
                  controller: _emailController,
                  label: 'EMAIL ADDRESS',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty ? 'REQUIRED' : null,
                ),
                const SizedBox(height: 20),
                _buildCyberTextField(
                  controller: _passwordController,
                  label: 'SECURITY KEY',
                  icon: Icons.vpn_key_rounded,
                  obscureText: true,
                  validator: (v) => v == null || v.length < 6 ? 'MIN 6 CHAR' : null,
                ),
                const SizedBox(height: 20),
                _buildCyberTextField(
                  controller: _phoneController,
                  label: 'COMMS LINK (PHONE)',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),
                const Text('SYSTEM ROLE:', style: TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: slatePanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: glassBorder)),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'victim', label: Text('VICTIM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      ButtonSegment(value: 'helper', label: Text('HELPER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      ButtonSegment(value: 'admin', label: Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                    selected: {_role},
                    onSelectionChanged: (v) => setState(() => _role = v.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      selectedBackgroundColor: neonCyan.withOpacity(0.2),
                      selectedForegroundColor: neonCyan,
                      foregroundColor: Colors.blueGrey,
                    ),
                  ),
                ),
                if (_role == 'helper') ...[
                  const SizedBox(height: 24),
                  const Text('SPECIALIZATION:', style: TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  _isLoadingOccupations
                      ? const Center(child: CircularProgressIndicator(color: neonCyan))
                      : Container(
                          decoration: BoxDecoration(color: slatePanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: glassBorder)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedOccupation,
                              dropdownColor: slatePanel,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(border: InputBorder.none),
                              items: _availableOccupations
                                  .map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase(), style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedOccupation = v),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  _buildCyberTextField(controller: _stateController, label: 'OPERATIONAL STATE', icon: Icons.map_rounded),
                ],
                const SizedBox(height: 48),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return Container(
                      height: 56,
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: neonCyan.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: ElevatedButton(
                        onPressed: state is AuthLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(
                                        AuthSignUpRequested(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text.trim(),
                                          fullName: _nameController.text.trim(),
                                          role: _role,
                                          phone: _phoneController.text.isNotEmpty ? _phoneController.text.trim() : null,
                                          occupation: _role == 'helper' ? _selectedOccupation : null,
                                          state: _stateController.text.isNotEmpty ? _stateController.text.trim() : null,
                                        ),
                                      );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: neonCyan,
                          foregroundColor: darkBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: state is AuthLoading
                            ? const CircularProgressIndicator(color: darkBg)
                            : const Text('INITIALIZE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCyberTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: slatePanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: glassBorder)),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            validator: validator,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
