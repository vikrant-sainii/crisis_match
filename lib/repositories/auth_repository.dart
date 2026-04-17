import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Sign up with email/password; pass metadata so the DB trigger can use it
  Future<ProfileModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    developer.log('AuthRepo: Starting signup for $email with role=$role');

    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
        'phone': phone,
      },
    );

    final user = authResponse.user;
    if (user == null) throw Exception('Sign up failed');

    developer.log('AuthRepo: User created with id=${user.id}');

    // Wait a moment for the DB trigger, then try to fetch profile with a timeout
    try {
      final profile = await getProfile(user.id).timeout(const Duration(seconds: 10));
      developer.log('AuthRepo: Profile fetched successfully, role=${profile.role}');
      return profile;
    } catch (e) {
      developer.log('AuthRepo: Profile fetch timed out or failed ($e). Using metadata fallback.');
      // Return profile from metadata to keep the user moving
      return ProfileModel(
        id: user.id,
        role: role,
        fullName: fullName,
        email: email,
        phone: phone,
      );
    }
  }

  /// Sign in with email/password
  Future<ProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    developer.log('AuthRepo: Starting signin for $email');

    final authResponse = await _client.auth.signInWithPassword(
      email: email,     
      password: password,
    );

    final user = authResponse.user;
    if (user == null) throw Exception('Sign in failed');

    developer.log('AuthRepo: Signed in, userId=${user.id}');

    // Try to get profile, fallback to user metadata
    try {
      final profile = await getProfile(user.id);
      developer.log('AuthRepo: Profile loaded, role=${profile.role}');
      return profile;
    } catch (e) {
      developer.log('AuthRepo: Profile fetch failed: $e');
      // Fallback: build profile from auth user metadata
      final meta = user.userMetadata ?? {};
      return ProfileModel(
        id: user.id,
        role: (meta['role'] as String?) ?? 'victim',
        fullName: (meta['full_name'] as String?) ?? '',
        email: email,
        phone: meta['phone'] as String?,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current auth user id (null if not logged in)
  String? getCurrentUserId() {
    return _client.auth.currentUser?.id;
  }

  /// Check if user is logged in
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Get profile from profiles table with Lazy Cleanup for expired blocks
  Future<ProfileModel> getProfile(String userId) async {
    developer.log('AuthRepo: Fetching profile for $userId');
    final data =
        await _client.from('profiles').select().eq('id', userId).single();
    
    ProfileModel profile = ProfileModel.fromJson(data);

    // 🕒 LAZY CLEANUP: If blocked state is expired, reset it in DB
    if (profile.isBlocked && profile.blockedUntil != null) {
      if (profile.blockedUntil!.isBefore(DateTime.now())) {
        developer.log('AuthRepo: Block expired for $userId. Cleaning up...');
        await _client.from('profiles').update({
          'is_blocked': false,
          'blocked_until': null,
        }).eq('id', userId);
        
        // Return a clean version
        return profile.copyWith(isBlocked: false, blockedUntil: null);
      }
    }

    return profile;
  }

  /// Block a user for a specific duration (15 days) and update the request status
  Future<void> blockUser({
    required String profileId,
    required String requestId,
    int days = 15,
  }) async {
    final blockedUntil = DateTime.now().add(Duration(days: days));
    
    // 1. Update Profile
    await _client.from('profiles').update({
      'is_blocked': true,
      'blocked_until': blockedUntil.toIso8601String(),
    }).eq('id', profileId);

    // 2. Update Request Status to 'blocked'
    await _client.from('request_table').update({
      'status': 'blocked',
    }).eq('request_id', requestId);
    
    developer.log('AuthRepo: User $profileId blocked until $blockedUntil');
  }
}
