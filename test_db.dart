import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://mppmezijccsyqdrkuvww.supabase.co'; // extracted from supabase_config.dart
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wcG1lemlqY2NzeXFkcmt1dnd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NTk1MjMsImV4cCI6MjA5MDAzNTUyM30.XeNhA8LVr_O0e7mVxuR7GBSNp3VuDaPj-62B1ciqB3o';
  
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    // We just want to see what error it dumps when inserting dummy data into help_sessions
    final data = await client.from('help_sessions').insert({
      'request_id': '00000000-0000-0000-0000-000000000000',
      'helper_id': '00000000-0000-0000-0000-000000000000',
      'victim_id': '00000000-0000-0000-0000-000000000000',
      'status': 'accepted',
      'request_created_at': DateTime.now().toIso8601String(),
      'accepted_at': DateTime.now().toIso8601String(),
      'response_time_sec': 12,
      'speed_bonus': 10,
    }).select().single();
    print('Success: \$data');
  } catch (e) {
    print('Error caught: \$e');
  }
}
