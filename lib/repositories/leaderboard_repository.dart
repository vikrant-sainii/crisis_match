import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/help_session_model.dart';

/// Completely isolated repository for leaderboard and help session scoring.
/// Has ZERO dependency on HelpRequestRepository.
class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  // ---------------------------------------------------------------------------
  // LEADERBOARD QUERIES
  // ---------------------------------------------------------------------------

  /// Fetches top 10 helpers by score. Optionally filter by occupation.
  Future<List<LeaderboardEntry>> fetchLeaderboard({String? occupation}) async {
    try {
      var query = _client.from('helpers').select('''
            id,
            occupation,
            lat,
            lng,
            total_score,
            total_helps,
            avg_rating,
            profiles!helpers_profile_id_fkey ( full_name )
          ''');

      if (occupation != null && occupation.isNotEmpty) {
        query = query.eq('occupation', occupation);
      }

      final data = await query.order('total_score', ascending: false).limit(10);

      return data.asMap().entries.map((entry) {
        final json = Map<String, dynamic>.from(entry.value as Map);
        // Flatten the profiles join
        final profile = json['profiles'] as Map?;
        json['name'] = profile?['full_name'] ?? 'Anonymous';
        json['helper_id'] = json['id'];
        return LeaderboardEntry.fromJson(json, rank: entry.key + 1);
      }).toList();
    } catch (e) {
      developer.log('LeaderboardRepo: Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// Fetches all unique occupations for filter tabs.
  Future<List<String>> fetchOccupations() async {
    try {
      final data = await _client.from('helpers').select('occupation');

      final Set<String> unique = {};
      for (final row in data) {
        final occ = row['occupation'] as String?;
        if (occ != null && occ.isNotEmpty) unique.add(occ);
      }
      return unique.toList()..sort();
    } catch (e) {
      developer.log('LeaderboardRepo: Error fetching occupations: $e');
      return [];
    }
  }

  /// Fetches detailed stats for a specific helper by profile_id
  Future<LeaderboardEntry?> getHelperWithStats(String profileId) async {
    try {
      final data = await _client.from('helpers').select('''
            id,
            occupation,
            lat,
            lng,
            total_score,
            total_helps,
            avg_rating,
            profiles!helpers_profile_id_fkey ( full_name, phone )
          ''').eq('profile_id', profileId).maybeSingle();

      if (data == null) return null;

      final json = Map<String, dynamic>.from(data as Map);
      final profile = json['profiles'] as Map?;
      json['name'] = profile?['full_name'] ?? 'Anonymous';
      json['phone'] = profile?['phone'];
      json['helper_id'] = json['id'];
      
      return LeaderboardEntry.fromJson(json, rank: 0);
    } catch (e) {
      developer.log('LeaderboardRepo: Error fetching helper stats: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // HELP SESSION MANAGEMENT (Scoring)
  // ---------------------------------------------------------------------------

  /// Called when a helper ACCEPTS a request.
  /// Creates the help_sessions row.
  Future<HelpSessionModel?> createSession({
    required String requestId,
    required String helperId,
    required String victimId,
    required DateTime requestCreatedAt,
  }) async {
    try {
      final acceptedAt = DateTime.now();
      final responseTimeSec = acceptedAt.difference(requestCreatedAt).inSeconds;
      final speedBonus = _calculateSpeedBonus(responseTimeSec);

      final data = await _client
          .from('help_sessions')
          .insert({
            'request_id': requestId,
            'helper_id': helperId,
            'victim_id': victimId,
            'status': 'accepted',
            'request_created_at': requestCreatedAt.toIso8601String(),
            'accepted_at': acceptedAt.toIso8601String(),
            'response_time_sec': responseTimeSec,
            'speed_bonus': speedBonus,
          })
          .select()
          .single();

      developer.log(
        'LeaderboardRepo: Session created for request $requestId. Speed bonus: $speedBonus',
      );
      return HelpSessionModel.fromJson(data);
    } catch (e) {
      developer.log('LeaderboardRepo: Error creating session: $e');
      return null;
    }
  }

  /// Called when a helper marks the session as COMPLETED.
  Future<void> completeSession(String requestId) async {
    try {
      await _client
          .from('help_sessions')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);
      developer.log(
        'LeaderboardRepo: Session completed for request $requestId',
      );
    } catch (e) {
      developer.log('LeaderboardRepo: Error completing session: $e');
    }
  }

  /// Called when a helper CANCELS/ABORTS an accepted session.
  Future<void> cancelSession(String requestId) async {
    try {
      await _client
          .from('help_sessions')
          .update({'status': 'cancelled', 'total_score': -40})
          .eq('request_id', requestId);
      developer.log(
        'LeaderboardRepo: Session cancelled for request $requestId',
      );
    } catch (e) {
      developer.log('LeaderboardRepo: Error cancelling session: $e');
    }
  }

  /// Called when the victim submits a rating (1-5 stars).
  /// Default is 3 stars if victim skips.
  Future<void> submitRating(String requestId, int stars) async {
    try {
      final multiplier = _getRatingMultiplier(stars);
      // The Supabase trigger will auto-calculate total_score & update helpers table
      await _client.from('help_sessions').update({
        'victim_rating': stars,
        'rating_multiplier': multiplier,
      }).eq('request_id', requestId);
      developer.log('LeaderboardRepo: Rating $stars submitted for request $requestId');
    } catch (e) {
      developer.log('LeaderboardRepo: Error submitting rating: $e');
    }
  }

  /// Get the actual rating value given by the victim
  Future<int?> getSessionRating(String requestId) async {
    try {
      final data = await _client
          .from('help_sessions')
          .select('victim_rating')
          .eq('request_id', requestId)
          .maybeSingle();
      return data?['victim_rating'] as int?;
    } catch (e) {
      return null;
    }
  }

  /// Check if a session has already been rated by the victim
  Future<bool> hasSessionBeenRated(String requestId) async {
    try {
      final data = await _client
          .from('help_sessions')
          .select('victim_rating')
          .eq('request_id', requestId)
          .maybeSingle();
      
      if (data == null) return false;
      return data['victim_rating'] != null;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  int _calculateSpeedBonus(int responseTimeSec) {
    if (responseTimeSec <= 10) return 30;
    if (responseTimeSec <= 30) return 20;
    if (responseTimeSec <= 60) return 10;
    return 0;
  }

  double _getRatingMultiplier(int stars) {
    switch (stars) {
      case 5:
        return 1.5;
      case 4:
        return 1.2;
      case 3:
        return 1.0;
      case 2:
        return 0.8;
      case 1:
        return 0.5;
      default:
        return 1.0;
    }
  }
}
