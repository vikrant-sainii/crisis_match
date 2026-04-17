import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Send a message to Supabase chat_messages table
  Future<ChatMessageModel> sendMessage({
    required String requestId,
    required String senderId,
    required String senderRole,
    required String message,
  }) async {
    final data = await _client
        .from('chat_messages')
        .insert({
          'request_id': requestId,
          'sender_id': senderId,
          'sender_role': senderRole,
          'message': message,
        })
        .select()
        .single();
    return ChatMessageModel.fromJson(data);
  }

  /// Get all messages for a request
  Future<List<ChatMessageModel>> getMessages(String requestId) async {
    final data = await _client
        .from('chat_messages')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    return (data as List)
        .map((e) => ChatMessageModel.fromJson(e))
        .toList();
  }

  /// Subscribe to new messages for a request (realtime)
  StreamSubscription subscribeToMessages(
    String requestId,
    void Function(List<ChatMessageModel>) onUpdate,
  ) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at', ascending: true)
        .listen((data) {
          final messages = data
              .map((e) => ChatMessageModel.fromJson(e))
              .toList();
          onUpdate(messages);
    });
  }

  /// Send message to n8n webhook and get response
  Future<String> sendToN8n({
    required String message,
    required String victimId,
    double? lat,
    double? lng,
  }) async {
    final url = SupabaseConfig.n8nWebhookUrl;
    developer.log('ChatRepo: Sending to n8n: $url');
    developer.log('ChatRepo: Payload: message=$message, victimId=$victimId, lat=$lat, lng=$lng');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'victim_id': victimId,
          'lat': lat,
          'lng': lng,
        }),
      ).timeout(const Duration(seconds: 30));

      developer.log('ChatRepo: n8n response status=${response.statusCode}');
      developer.log('ChatRepo: n8n response body=${response.body}');

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return 'No response from assistant. Please try again.';
        }
        
        try {
          final dynamic body = jsonDecode(response.body);
          
          Map<String, dynamic>? extractData(dynamic obj) {
            if (obj is List && obj.isNotEmpty) return extractData(obj[0]);
            if (obj is Map) return obj as Map<String, dynamic>;
            if (obj is String && (obj.startsWith('{') || obj.startsWith('['))) {
              try { return extractData(jsonDecode(obj)); } catch (_) {}
            }
            return null;
          }

          Map<String, dynamic>? data = extractData(body);
          if (data == null) return body.toString();

          // 1. Check for helper-found response
          if (data.containsKey('helper') && data['helper'] is Map) {
            final helper = data['helper'] as Map;
            final helperName = helper['name']?.toString() ?? 'Unknown';
            final helperType = helper['type']?.toString() ?? 'Unknown';
            final distance = helper['distance'];
            final msg = data['message'] ?? 'Helper found!';
            final distStr = distance != null ? '\n📍 Distance: ${_formatDist(distance)}' : '';
            return '$msg\n👤 Helper: $helperName\n🛠 Type: $helperType$distStr';
          }

          // 2. Try common response keys
          for (final key in ['message', 'output', 'text', 'response', 'reply', 'content', 'answer']) {
            if (data.containsKey(key) && data[key] != null) {
              return data[key].toString();
            }
          }

          // 3. Fallback: Recursively collect ALL strings
          String collectAllText(dynamic obj) {
            if (obj is Map) {
              return obj.entries.map((e) => "${e.key} ${collectAllText(e.value)}").join(" ").trim();
            } else if (obj is List) {
              return obj.map((e) => collectAllText(e)).join(" ").trim();
            } else {
              return obj?.toString() ?? "";
            }
          }

          final allText = collectAllText(data);
          if (allText.isNotEmpty) {
            final cleanedText = allText
              .replaceAll(RegExp(r'[\{\}\[\]"\\n\r]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
            return cleanedText;
          }

          return response.body;
        } catch (_) {
          return response.body;
        }
      } else {
        developer.log('ChatRepo: n8n error status=${response.statusCode}');
        return 'Assistant unavailable (${response.statusCode}). Please try again.';
      }
    } catch (e) {
      developer.log('ChatRepo: n8n error: $e');
      return 'Connection error: $e';
    }
  }

  /// Format distance from n8n (could be km or meters)
  String _formatDist(dynamic dist) {
    if (dist is num) {
      if (dist < 1) return '${(dist * 1000).round()} m';
      return '${dist.toDouble().toStringAsFixed(1)} km';
    }
    return dist.toString();
  }
}

