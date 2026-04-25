import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../repositories/help_request_repository.dart';
import 'auth/digilocker_webview_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
  String _role = 'victim';
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _idHash;

  // 🏙 SOFT UI THEME CONSTANTS
  static const Color darkBg = Color(0xFFF8FAFC);
  static const Color neonCyan = Color(0xFF2563EB); // Trust Blue
  static const Color glassBorder = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verifyWithDigiLocker() async {
    // You should replace these with your actual DigiLocker Client ID and Redirect URI
    const clientId = 'YOUR_DIGILOCKER_CLIENT_ID';
    const redirectUri = 'https://crisis-match.auth/callback';

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const DigiLockerWebViewScreen(
          clientId: clientId,
          redirectUri: redirectUri,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isVerifying = true;
      });
      
      // Simulate verification delay
      await Future.delayed(const Duration(seconds: 1));

      if (result['status'] == 'success') {
        setState(() {
          _isVerified = true;
          _idHash = result['id_hash'];
          if (result['full_name'] != null) {
            _nameController.text = result['full_name'];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Identity Verified via DigiLocker!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _showBannedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Access Restricted',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This identity has been permanently banned from Sahayak due to repeated spam or community guidelines violations.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text(
          'CREATE ACCOUNT',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pop(context); // Go back, app.dart will handle routing
          } else if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
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
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _buildCyberTextField(
                  controller: _emailController,
                  label: 'EMAIL ADDRESS',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _buildCyberTextField(
                  controller: _passwordController,
                  label: 'PASSWORD',
                  icon: Icons.vpn_key_rounded,
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 20),
                _buildCyberTextField(
                  controller: _phoneController,
                  label: 'PHONE NUMBER',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                _buildDigiLockerButton(),
                const SizedBox(height: 32),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: (state is AuthLoading || !_isVerified)
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(
                                    AuthSignUpRequested(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text.trim(),
                                      fullName: _nameController.text.trim(),
                                      role: _role,
                                      phone: _phoneController.text.isNotEmpty
                                          ? _phoneController.text.trim()
                                          : null,
                                      idHash: _idHash,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: neonCyan,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: state is AuthLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
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
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glassBorder, width: 1.5),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            validator: validator,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.blueGrey.shade300, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDigiLockerButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IDENTITY VERIFICATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isVerified || _isVerifying ? null : _verifyWithDigiLocker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isVerified
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isVerified
                    ? Colors.green
                    : Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Image.network(
                  'https://www.digilocker.gov.in/assets/img/digilocker_logo.png',
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isVerified
                        ? 'IDENTITY VERIFIED'
                        : 'VERIFY WITH DIGILOCKER',
                    style: TextStyle(
                      color: _isVerified ? Colors.green : Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_isVerifying)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_isVerified)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
        ),
        if (!_isVerified)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              '* Required to prevent spam and ensure community safety',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
