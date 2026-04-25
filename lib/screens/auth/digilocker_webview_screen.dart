import 'package:flutter/material.dart';
import 'dart:async';

class DigiLockerWebViewScreen extends StatefulWidget {
  final String clientId;
  final String redirectUri;

  const DigiLockerWebViewScreen({
    super.key,
    required this.clientId,
    required this.redirectUri,
  });

  @override
  State<DigiLockerWebViewScreen> createState() => _DigiLockerWebViewScreenState();
}

class _DigiLockerWebViewScreenState extends State<DigiLockerWebViewScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isProcessing = false;

  void _simulateVerification() async {
    if (_idController.text.length < 10) return;

    setState(() => _isProcessing = true);
    
    // Simulate Government Server latency
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Return a professional-looking demo identity
      Navigator.pop(context, {
        'status': 'success',
        'full_name': 'VIKRANT SAINI',
        'id_hash': 'sha256_demo_verify_7890',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Image.network(
          'https://www.digilocker.gov.in/assets/img/digilocker_logo.png',
          height: 30,
          errorBuilder: (_, __, ___) => const Text('DigiLocker Identity Vault'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.account_balance_outlined, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Identity Verification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sahayak is requesting access to your verified Aadhaar details for community safety.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Aadhaar or Mobile Number',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _simulateVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('GET OTP & VERIFY', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const Spacer(),
            const Text(
              'Powered by MeitY, Government of India',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
