import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 🌃 CYBER-DARK THEME CONSTANTS
  static const Color darkBg = Color(0xFF0F172A);
  static const Color slatePanel = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color glassBorder = Color(0x3394A3B8);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text(state.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          } else if (state is AuthBlocked) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: darkBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.gpp_bad_rounded, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('ACCESS RESTRICTED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.message,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Text(
                        'This protocol is enforced to maintain the integrity of the CrisisMatch network.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                actions: [
                   TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<AuthBloc>().add(AuthSignOutRequested());
                    },
                    child: const Text('ACKNOWLEDGE', style: TextStyle(color: neonCyan, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ],
              ),
            );
          }
        },
        child: Stack(
          children: [
            // 💠 CARBON FIBER BACKGROUND
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/carbon-fibre.png',
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 🛰 COMMAND PORTAL LOGO
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: neonCyan.withOpacity(0.2), width: 2),
                          boxShadow: [BoxShadow(color: neonCyan.withOpacity(0.1), blurRadius: 40, spreadRadius: 5)],
                        ),
                        child: const Icon(Icons.crisis_alert_rounded, size: 64, color: neonCyan),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'CRISISMATCH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      Text(
                        'COMMAND INTERFACE v1.0',
                        style: TextStyle(
                          color: neonCyan.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 56),

                      // 📟 AUTHENTICATION INPUTS
                      _buildCyberTextField(
                        controller: _emailController,
                        label: 'IDENTIFICATION (EMAIL)',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || v.isEmpty ? 'REQUIRED' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildCyberTextField(
                        controller: _passwordController,
                        label: 'ACCESS CODE (PASSWORD)',
                        icon: Icons.vpn_key_rounded,
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty ? 'REQUIRED' : null,
                      ),
                      const SizedBox(height: 40),

                      // ⚡ AUTHORIZE ACCESS BUTTON
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          return Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: neonCyan.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: state is AuthLoading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        context.read<AuthBloc>().add(
                                              AuthSignInRequested(
                                                email: _emailController.text.trim(),
                                                password:_passwordController.text.trim(),
                                              ),
                                            );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: neonCyan,
                                foregroundColor: darkBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: state is AuthLoading
                                  ? const CircularProgressIndicator(color: darkBg)
                                  : const Text(
                                      'AUTHORIZE ACCESS',
                                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // 🔗 JOIN THE GRID
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, letterSpacing: 1),
                            children: const [
                              TextSpan(text: "NEW OPERATIVE? "),
                              TextSpan(
                                text: "JOIN THE GRID",
                                style: TextStyle(color: neonCyan, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
          style: const TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: slatePanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glassBorder),
          ),
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
