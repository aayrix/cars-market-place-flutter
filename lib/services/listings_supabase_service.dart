import 'package:supabase_flutter/supabase_flutter.dart';

class ListingsSupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchListings() async {
    final response = await _client
        .from('listings')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addListing(Map<String, dynamic> data) async {
    await _client.from('listings').insert(data);
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    await _client.from('listings').update(data).eq('id', id);
  }

  Future<void> deleteListing(String id) async {
    await _client.from('listings').delete().eq('id', id);
  }
}
