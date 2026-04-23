import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient('...', '...');
  final data = await supabase.from('helpers').select();
  print(data);
}
