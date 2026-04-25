import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show cos, sqrt, asin;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/help_request_model.dart';

class HelpRequestRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch a request joining helper location and occupation
  Future<HelpRequestModel?> _fetchJoinedRequest(String requestId) async {
    final data = await _client
        .from('request_table')
        .select('''
          *,
          helpers ( id, profile_id, lat, lng, occupation )
        ''')
        .eq('request_id', requestId)
        .maybeSingle();

    if (data == null) return null;

    if (data['helpers'] != null && data['helpers']['profile_id'] != null) {
      final profileId = data['helpers']['profile_id'] as String;
      final profile = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', profileId)
          .maybeSingle();
      if (profile != null) {
        data['helper_name'] = profile['full_name'];
        data['helper_phone'] = profile['phone'];
      }
    }

    // Calculate distance locally since we rely on the DB stream, not the HTTP response
    if (data['victim_curr_lat'] != null &&
        data['victim_curr_long'] != null &&
        data['helpers'] != null &&
        data['helpers']['lat'] != null &&
        data['helpers']['lng'] != null) {
      double lat1 = (data['victim_curr_lat'] as num).toDouble();
      double lon1 = (data['victim_curr_long'] as num).toDouble();
      double lat2 = (data['helpers']['lat'] as num).toDouble();
      double lon2 = (data['helpers']['lng'] as num).toDouble();

      var p = 0.017453292519943295;
      var c = cos;
      var a =
          0.5 -
          c((lat2 - lat1) * p) / 2 +
          c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
      double distanceKm = 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
      data['distance'] = '${distanceKm.toStringAsFixed(1)} KM AWAY';
    }

    return HelpRequestModel.fromJson(data);
  }

  /// Get active request for a victim (pending or accepted)
  Future<HelpRequestModel?> getActiveRequest(String victimId) async {
    final data = await _client
        .from('request_table')
        .select('''
          *,
          helpers ( lat, lng, occupation )
        ''')
        .eq('victim_id', victimId)
        .inFilter('status', ['pending', 'accepted', 'rejected'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;

    if (data['helper_id'] != null) {
      final profile = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', data['helper_id'])
          .maybeSingle();
      if (profile != null) {
        data['helper_name'] = profile['full_name'];
        data['helper_phone'] = profile['phone'];
      }
    }

    return HelpRequestModel.fromJson(data);
  }

  /// Get a specific request by ID
  Future<HelpRequestModel?> getRequestById(String requestId) async {
    return _fetchJoinedRequest(requestId);
  }

  /// Update request status
  Future<void> updateStatus(String requestId, String status) async {
    await _client
        .from('request_table')
        .update({'status': status})
        .eq('request_id', requestId);
  }

  /// Fetch ALL requests assigned to a specific helper (pending, accepted, rejected, completed)
  Future<List<HelpRequestModel>> getMatchedRequests(String helperId) async {
    final data = await _client
        .from('request_table')
        .select('''
          *,
          helpers ( id, profile_id, lat, lng, occupation ),
          profiles!victim_id ( full_name )
        ''')
        .eq('helper_id', helperId)
        .order('created_at', ascending: false);

    final results = data as List;
    for (var row in results) {
      if (row['profiles'] != null) {
        row['victim_name'] = row['profiles']['full_name'];
      }
      // Also fetch helper name for consistency
      if (row['helpers'] != null && row['helpers']['profile_id'] != null) {
        final profileId = row['helpers']['profile_id'] as String;
        final profile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', profileId)
            .maybeSingle();
        if (profile != null) {
          row['helper_name'] = profile['full_name'];
          row['helper_phone'] = profile['phone'];
        }
      }
    }
    return results.map((e) => HelpRequestModel.fromJson(e)).toList();
  }

  /// Fetch ALL requests created by a specific victim (for history tab)
  Future<List<HelpRequestModel>> getVictimHistory(String victimId) async {
    final data = await _client
        .from('request_table')
        .select('''
          *,
          helpers ( id, profile_id, lat, lng, occupation )
        ''')
        .eq('victim_id', victimId)
        .order('created_at', ascending: false);

    final results = data as List;
    for (var row in results) {
      if (row['helpers'] != null && row['helpers']['profile_id'] != null) {
        final profileId = row['helpers']['profile_id'] as String;
        final profile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', profileId)
            .maybeSingle();
        if (profile != null) {
          row['helper_name'] = profile['full_name'];
          row['helper_phone'] = profile['phone'];
        }
      }
    }
    return results.map((e) => HelpRequestModel.fromJson(e)).toList();
  }

  /// Subscribe to ALL requests for a helper (realtime UI tracking)
  StreamSubscription subscribeToHelperRequests(
    String helperId,
    void Function(List<HelpRequestModel>) onUpdate,
  ) {
    return _client
        .from('request_table')
        .stream(primaryKey: ['request_id'])
        .eq('helper_id', helperId)
        .listen((_) async {
          // Instead of manually mapping the raw stream, fetch the fully joined query
          final fullRequests = await getMatchedRequests(helperId);
          onUpdate(fullRequests);
        });
  }

  /// Subscribe to ALL requests for a victim (realtime)
  StreamSubscription subscribeToVictimRequests(
    String victimId,
    void Function(HelpRequestModel) onUpdate,
  ) {
    return _client
        .from('request_table')
        .stream(primaryKey: ['request_id'])
        .eq('victim_id', victimId)
        .listen((data) async {
          if (data.isNotEmpty) {
            // Priority 1: Find any 'pending' or 'accepted' requests
            final activeRequests = data
                .where(
                  (r) => r['status'] == 'pending' || r['status'] == 'accepted',
                )
                .toList();

            Map<String, dynamic> newest;
            if (activeRequests.isNotEmpty) {
              // If active missions exist, pick the newest one among them
              activeRequests.sort(
                (a, b) => (DateTime.tryParse(b['created_at']) ?? DateTime(0))
                    .compareTo(
                      DateTime.tryParse(a['created_at']) ?? DateTime(0),
                    ),
              );
              newest = activeRequests.first;
            } else {
              // Otherwise pick the newest rejection/completion
              data.sort(
                (a, b) => (DateTime.tryParse(b['created_at']) ?? DateTime(0))
                    .compareTo(
                      DateTime.tryParse(a['created_at']) ?? DateTime(0),
                    ),
              );
              newest = data.first;
            }

            final newestReqId = newest['request_id'];
            developer.log(
              'HelpRequestRepo: Stream update. Newest ID: $newestReqId, Status: ${newest['status']}',
            );

            final fullReq = await _fetchJoinedRequest(newestReqId);
            if (fullReq != null) {
              onUpdate(fullReq);
            }
          }
        });
  }

  /// Update victim's live location on the request
  Future<void> updateVictimLocation(
    String requestId,
    double lat,
    double lng,
  ) async {
    await _client
        .from('request_table')
        .update({'victim_curr_lat': lat, 'victim_curr_long': lng})
        .eq('request_id', requestId);
  }

  /// Update helper's mission-specific live location on the request
  Future<void> updateHelperLocation(
    String requestId,
    double lat,
    double lng,
  ) async {
    await _client
        .from('request_table')
        .update({'helper_curr_lat': lat, 'helper_curr_long': lng})
        .eq('request_id', requestId);
  }

  /// Send DigiLocker code to n8n for full verification
  Future<Map<String, dynamic>> verifyIdentityWithN8n(String code) async {
    final url = SupabaseConfig.n8nDigiLockerUrl;
    developer.log('HelpReqRepo: Verifying DigiLocker code at n8n...');

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': code,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('DigiLocker Verification Failed: ${response.statusCode}');
  }

  /// Dedicated trigger for Women Safety SOS
  Future<Map<String, dynamic>> triggerWomenSafetySos({
    required String victimId,
    required double lat,
    required double lng,
  }) async {
    final url = SupabaseConfig.womensafeturl;
    developer.log('HelpReqRepo: Triggering Women Safety SOS at $url');

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': 'women safety sos',
            'victim_id': victimId,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {'reply': 'SOS Received.'};
      return jsonDecode(response.body);
    }
    throw Exception('Women Safety SOS failed: ${response.statusCode}');
  }

  /// Trigger n8n webhook to initially find helpers
  Future<Map<String, dynamic>> triggerN8nInitialSearch({
    required String message,
    required String victimId,
    required double lat,
    required double lng,
  }) async {
    final url = SupabaseConfig.n8nWebhookUrl;
    developer.log('HelpReqRepo: Triggering n8n search at $url');

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'victim_id': victimId,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 60));

    developer.log(
      'HelpReqRepo: n8n Matcher response status: ${response.statusCode}',
    );
    developer.log('HelpReqRepo: n8n Matcher response body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        developer.log('HelpReqRepo: n8n returned empty success response.');
        return {'reply': 'Alert received by Sahayak Core.'};
      }

      developer.log('HelpReqRepo: Parsing n8n response...');
      dynamic currentBody;
      try {
        currentBody = jsonDecode(response.body);
      } catch (e) {
        developer.log('HelpReqRepo: Failed to decode JSON: $e');
        return {'reply': response.body};
      }

      // Helper function to extract a potential Map from common n8n wrappers
      Map<String, dynamic>? extractData(dynamic obj) {
        if (obj is List && obj.isNotEmpty) return extractData(obj[0]);
        if (obj is Map) return obj as Map<String, dynamic>;

        // If it's a string, it might be double-encoded JSON
        if (obj is String && (obj.startsWith('{') || obj.startsWith('['))) {
          try {
            return extractData(jsonDecode(obj));
          } catch (_) {}
        }
        return null;
      }

      Map<String, dynamic>? data = extractData(currentBody);

      // If we couldn't get a Map even after unwrapping, return the primitive
      if (data == null) {
        return {'reply': currentBody.toString()};
      }

      // 1. Success: matching flow
      if (data.containsKey('matched_id') && data.containsKey('request_id')) {
        return data;
      }

      // 2. Search for common reply/message keys
      for (final key in [
        'reply',
        'message',
        'assistant_message',
        'output',
        'text',
        'response',
        'answer',
      ]) {
        if (data!.containsKey(key)) {
          final val = data[key]!;
          final inner = extractData(val);
          if (inner != null &&
              (inner.containsKey('reply') || inner.containsKey('message'))) {
            data = inner;
          } else {
            return {'reply': val.toString()};
          }
        }
      }

      // 3. Fallback: Recursively collect ALL strings from the object if we're still stuck.
      // This handles the weird n8n case where the message is split across keys/values.
      String collectAllText(dynamic obj) {
        if (obj is Map) {
          return obj.entries
              .map((e) => "${e.key} ${collectAllText(e.value)}")
              .join(" ")
              .trim();
        } else if (obj is List) {
          return obj.map((e) => collectAllText(e)).join(" ").trim();
        } else {
          return obj?.toString() ?? "";
        }
      }

      final allText = collectAllText(data);
      if (allText.isNotEmpty) {
        // Clean up internal JSON-like fragments if they were gathered from keys
        final cleanedText = allText
            .replaceAll(RegExp(r'[\{\}\[\]"\\n\r]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // Remove common internal key names if they appear at the start
        String finalOutput = cleanedText;
        for (final k in ['reply', 'message', 'output']) {
          if (finalOutput.toLowerCase().startsWith('$k :')) {
            finalOutput = finalOutput.substring(k.length + 2).trim();
          } else if (finalOutput.toLowerCase().startsWith('$k:')) {
            finalOutput = finalOutput.substring(k.length + 1).trim();
          }
        }

        return {'reply': finalOutput.isEmpty ? allText : finalOutput};
      }

      return {'reply': response.body};
    } else {
      throw Exception('Failed to find helpers: ${response.statusCode}');
    }
  }

  /// Trigger n8n webhook for ongoing assistance (Assist Agent)
  Future<Map<String, dynamic>> triggerN8nAssist({
    required String message,
    required String victimId,
    double? lat,
    double? lng,
  }) async {
    final url = SupabaseConfig.n8nAssistWebhookUrl;
    developer.log('HelpReqRepo: Triggering n8n assist at $url');

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'victim_id': victimId,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 60));

    developer.log(
      'HelpReqRepo: n8n Assist response status: ${response.statusCode}',
    );
    developer.log('HelpReqRepo: n8n Assist response body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return {'reply': 'No message received from assistant.'};
      }

      try {
        dynamic body = jsonDecode(response.body);

        Map<String, dynamic>? extractData(dynamic obj) {
          if (obj is List && obj.isNotEmpty) return extractData(obj[0]);
          if (obj is Map) return obj as Map<String, dynamic>;
          if (obj is String && (obj.startsWith('{') || obj.startsWith('['))) {
            try {
              return extractData(jsonDecode(obj));
            } catch (_) {}
          }
          return null;
        }

        Map<String, dynamic>? data = extractData(body);
        if (data == null) return {'reply': body.toString()};

        // Check common keys
        for (final key in [
          'reply',
          'message',
          'assistant_message',
          'output',
          'text',
          'response',
          'answer',
        ]) {
          if (data.containsKey(key)) {
            return {'reply': data[key].toString()};
          }
        }

        return {'reply': response.body};
      } catch (_) {
        return {'reply': response.body};
      }
    } else {
      throw Exception('Assist workflow failed (${response.statusCode})');
    }
  }

  /// Calls the n8n Voice Assistant webhook.
  ///
  /// n8n responds with JSON:
  ///   { "message": "<assistant text>", "audio": { "directory": "<mp3_url>", ... } }
  ///
  /// The [audio] field can be:
  ///   - A Map (n8n binary metadata) → we fetch the MP3 from its "directory" URL.
  ///   - A String (base64 encoded MP3) → we decode it directly.
  ///
  /// Returns { 'reply': String, 'audioPath': String? }
  Future<Map<String, dynamic>> triggerN8nVoiceAssist({
    required String message,
    required String victimId,
    required double lat,
    required double lng,
  }) async {
    final url = SupabaseConfig.n8nVoiceAssistUrl;
    developer.log('HelpReqRepo: Calling Voice Assist for $victimId');
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'victim_id': victimId,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return {
          'reply': 'Voice transmission received.',
          'audioPath': null,
        };
      }
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Extract text — try common key names n8n might use
        final String? assistantText =
            (data['assistant_message'] ??
                    data['message'] ??
                    data['reply'] ??
                    data['text'])
                ?.toString();

        // Extract and concatenate audio from the audio_urls array
        // n8n splits long responses into multiple Google TTS chunks → we join them
        String? audioPath;
        final rawUrls = data['audio_urls'];
        if (rawUrls is List && rawUrls.isNotEmpty) {
          try {
            final List<int> combinedBytes = [];
            for (final urlEntry in rawUrls) {
              final audioUrl = urlEntry?.toString();
              if (audioUrl == null || !audioUrl.startsWith('http')) continue;
              final audioResponse = await http
                  .get(Uri.parse(audioUrl))
                  .timeout(const Duration(seconds: 30));
              if (audioResponse.statusCode == 200) {
                combinedBytes.addAll(audioResponse.bodyBytes);
              } else {
                developer.log(
                  'HelpReqRepo: Skipped audio URL (${audioResponse.statusCode}): $audioUrl',
                );
              }
            }
            if (combinedBytes.isNotEmpty) {
              audioPath = await _saveBytesToTempFile(combinedBytes);
            }
          } catch (e) {
            developer.log('HelpReqRepo: Failed to fetch audio_urls: $e');
          }
        }

        return {
          'reply': assistantText ?? 'Voice transmission received.',
          'audioPath': audioPath,
        };
      } catch (e) {
        developer.log('HelpReqRepo: Failed to parse voice assist response: $e');
        return {
          'reply': 'Voice response received but could not be parsed.',
          'audioPath': null,
        };
      }
    } else {
      throw Exception('Voice assist failed: ${response.statusCode}');
    }
  }

  /// Sends [text] to the dedicated TTS n8n webhook and returns a local path
  /// to the concatenated MP3, or null if unavailable.
  ///
  /// Handles two n8n response formats:
  ///   Format A (raw array):  ["<url1>", "<url2>", ...]
  ///   Format B (map):        { "audio_urls": ["<url1>", "<url2>", ...] }
  Future<String?> triggerTTS(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(SupabaseConfig.n8nTtsUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': text}),
          )
          .timeout(const Duration(seconds: 60));

      developer.log(
        'HelpReqRepo: TTS status=${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log('HelpReqRepo: TTS failed (${response.statusCode})');
        return null;
      }

      final decoded = jsonDecode(response.body);

      // Resolve URLs — accept raw List or Map with audio_urls key
      List<dynamic> urls = [];
      if (decoded is List) {
        urls = decoded; // Format A: ["url1", "url2"]
      } else if (decoded is Map && decoded['audio_urls'] is List) {
        urls =
            decoded['audio_urls'] as List; // Format B: { "audio_urls": [...] }
      }

      if (urls.isEmpty) {
        developer.log('HelpReqRepo: TTS — no URLs found in response');
        return null;
      }

      final List<int> combinedBytes = [];
      for (final urlEntry in urls) {
        final audioUrl = urlEntry?.toString();
        if (audioUrl == null || !audioUrl.startsWith('http')) continue;
        final audioResponse = await http
            .get(Uri.parse(audioUrl))
            .timeout(const Duration(seconds: 30));
        if (audioResponse.statusCode == 200) {
          combinedBytes.addAll(audioResponse.bodyBytes);
        } else {
          developer.log(
            'HelpReqRepo: TTS skipped URL (${audioResponse.statusCode}): $audioUrl',
          );
        }
      }

      if (combinedBytes.isEmpty) return null;
      return _saveBytesToTempFile(combinedBytes);
    } catch (e) {
      developer.log('HelpReqRepo: TTS error: $e');
      return null;
    }
  }

  /// Writes [bytes] to a single fixed-name MP3 file in the system temp directory.
  /// Deletes any existing file first → only 1 audio file ever exists at a time.
  /// Returns the absolute file path.
  Future<String> _saveBytesToTempFile(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ai_voice_response.mp3');

    // Overwrite any existing file — keeps storage to exactly 1 file
    if (await file.exists()) await file.delete();
    await file.writeAsBytes(bytes);

    developer.log('HelpReqRepo: Audio saved to ${file.path}');
    return file.path;
  }

  /// Trigger n8n webhook to log events to the Polygon blockchain
  Future<void> triggerBlockchainLog({
    required String requestId,
    required Map<String, dynamic> dataToHash,
  }) async {
    try {
      final url = SupabaseConfig.n8nBlockchainWebhookUrl;
      developer.log('HelpReqRepo: Triggering blockchain log for $requestId');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'request_id': requestId,
              'data_to_hash': dataToHash,
            }),
          )
          .timeout(const Duration(seconds: 15));

      developer.log(
        'HelpReqRepo: Blockchain webhook response: ${response.statusCode}',
      );
    } catch (e) {
      developer.log('HelpReqRepo: Failed to trigger blockchain webhook: $e');
    }
  }

  /// Fetch all requests that are completed but not yet hashed (pending admin approval)
  Future<List<HelpRequestModel>> getRequestsAwaitingApproval() async {
    final data = await _client
        .from('request_table')
        .select('''
          *,
          helpers ( id, profile_id, lat, lng, occupation ),
          profiles!victim_id ( full_name )
        ''')
        .eq('status', 'completed')
        .isFilter('tx_hash', null)
        .order('updated_at', ascending: false);

    return _processApprovalList(data as List);
  }

  /// Subscribe to requests needing approval (realtime)
  StreamSubscription subscribeToRequestsAwaitingApproval(
    void Function(List<HelpRequestModel>) onUpdate,
  ) {
    return _client
        .from('request_table')
        .stream(primaryKey: ['request_id'])
        .eq('status', 'completed')
        .listen((data) async {
          // Manual filter for tx_hash null since streams are limited
          final pending = data.where((r) => r['tx_hash'] == null).toList();
          if (pending.isEmpty) {
            onUpdate([]);
            return;
          }

          // Fetch full joined data for these IDs to match model expectations
          final ids = pending.map((e) => e['request_id']).toList();
          final fullData = await _client
              .from('request_table')
              .select('''
                *,
                helpers ( id, profile_id, lat, lng, occupation ),
                profiles!victim_id ( full_name )
              ''')
              .inFilter('request_id', ids)
              .order('updated_at', ascending: false);

          final processed = await _processApprovalList(fullData as List);
          onUpdate(processed);
        });
  }

  /// Helper to map victims and helper names from profiles
  Future<List<HelpRequestModel>> _processApprovalList(List results) async {
    for (var row in results) {
      if (row['profiles'] != null) {
        row['victim_name'] = row['profiles']['full_name'];
      }
      if (row['helpers'] != null && row['helpers']['profile_id'] != null) {
        final profileId = row['helpers']['profile_id'] as String;
        final profile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', profileId)
            .maybeSingle();
        if (profile != null) {
          row['helper_name'] = profile['full_name'];
          row['helper_phone'] = profile['phone'];
        }
      }
    }
    return results.map((e) => HelpRequestModel.fromJson(e)).toList();
  }

  /// Mark a request as SPAM
  Future<void> markAsSpam(String requestId) async {
    await updateStatus(requestId, 'spam');
  }

  /// Mark a request as BLOCKED (post-admin action)
  Future<void> markAsBlocked(String requestId) async {
    await updateStatus(requestId, 'blocked');
  }

  /// Fetch all requests with status 'spam'
  Future<List<HelpRequestModel>> getSpamRequests() async {
    final data = await _client
        .from('request_table')
        .select('''
          *,
          helpers ( id, profile_id, lat, lng, occupation ),
          profiles!victim_id ( id, full_name, email, phone )
        ''')
        .eq('status', 'spam')
        .order('updated_at', ascending: false);

    return _processSpamList(data as List);
  }

  /// Subscribe to spam reports (realtime)
  StreamSubscription subscribeToSpamRequests(
    void Function(List<HelpRequestModel>) onUpdate,
  ) {
    return _client
        .from('request_table')
        .stream(primaryKey: ['request_id'])
        .eq('status', 'spam')
        .listen((data) async {
          if (data.isEmpty) {
            onUpdate([]);
            return;
          }

          final ids = data.map((e) => e['request_id']).toList();
          final fullData = await _client
              .from('request_table')
              .select('''
                *,
                helpers ( id, profile_id, lat, lng, occupation ),
                profiles!victim_id ( id, full_name, email, phone )
              ''')
              .inFilter('request_id', ids)
              .order('updated_at', ascending: false);

          final processed = _processSpamList(fullData as List);
          onUpdate(processed);
        });
  }

  /// Helper to map victims and helper names from profiles for spam reports
  List<HelpRequestModel> _processSpamList(List results) {
    for (var row in results) {
      if (row['profiles'] != null) {
        row['victim_name'] = row['profiles']['full_name'];
      }
      // Helper names aren't strictly required for spam but good for context
      if (row['helpers'] != null && row['helpers']['profile_id'] != null) {
        // This would require more async calls, skipping for now if not needed
      }
    }
    return results.map((e) => HelpRequestModel.fromJson(e)).toList();
  }
}
