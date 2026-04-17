import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/helper_model.dart';

class HelperRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Register current user as a helper
  Future<HelperModel> registerHelper({
    required String profileId,
    required String occupation,
    String? state,
    double? lat,
    double? lng,
  }) async {
    developer.log('HelperRepo: Registering helper profileId=$profileId, occupation=$occupation');
    try {
      final data = await _client
          .from('helpers')
          .insert({
            'profile_id': profileId,
            'occupation': occupation,
            'state': state,
            'lat': lat,
            'lng': lng,
            'is_available': true,
            'added_by': profileId,
          })
          .select()
          .single();
      developer.log('HelperRepo: Helper registered successfully: ${data['id']}');
      return HelperModel.fromJson(data);
    } catch (e) {
      developer.log('HelperRepo: ERROR registering helper: $e');
      rethrow;
    }
  }

  /// Get helper record by profile_id
  Future<HelperModel?> getHelperByProfileId(String profileId) async {
    final data = await _client
        .from('helpers')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    if (data == null) return null;
    return HelperModel.fromJson(data);
  }

  /// Update availability
  Future<void> updateAvailability(String helperId, bool isAvailable) async {
    await _client
        .from('helpers')
        .update({'is_available': isAvailable}).eq('id', helperId);
  }

  /// Update helper location
  Future<void> updateLocation(
      String helperId, double lat, double lng) async {
    await _client
        .from('helpers')
        .update({'lat': lat, 'lng': lng}).eq('id', helperId);
  }

  /// Get all registered helpers with profile details (for admin map)
  Future<List<Map<String, dynamic>>> getAllHelpers() async {
    final data = await _client.from('helpers').select('''
          *,
          profiles:profile_id ( full_name, email )
        ''');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Get unique list of occupations from the crisis_helpers reference table
  Future<List<String>> getAvailableOccupations() async {
    try {
      developer.log('HelperRepo: Fetching occupations from crisis_helpers...');
      final data = await _client
          .from('crisis_helpers')
          .select('occupation');
      
      developer.log('HelperRepo: Raw data received: $data');
      
      final list = data as List;
      
      if (list.isEmpty) {
        developer.log('HelperRepo: WARNING - No occupations found in crisis_helpers table.');
        return [];
      }

      final occupations = list.map((e) => e['occupation'] as String).toSet().toList();
      developer.log('HelperRepo: Processed occupations: $occupations');
      return occupations;
    } catch (e) {
      developer.log('HelperRepo: CRITICAL ERROR fetching occupations: $e');
      rethrow;
    }
  }
}
