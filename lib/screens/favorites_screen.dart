import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/listings_provider.dart';
import '../widgets/listing_card.dart';

/// Displays the signed-in user's favorited listings.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final auth = context.read<AuthProvider>();
      final uid = auth.userId ?? '';
      if (uid.isNotEmpty) {
        context.read<ListingsProvider>().loadFavorites(uid);
      }
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.userId ?? '';
    final provider = context.watch<ListingsProvider>();

    final allListings = provider.listings;
    final favorites = allListings.where((l) => provider.isFavorited(l.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: uid.isEmpty || !auth.isSignedIn
          ? const Center(
              child: Text('Sign in to see your saved listings.'),
            )
          : favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No favorited listings yet.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Tap the heart on any listing to save it here.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: favorites.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final l = favorites[i];
                    return Card(
                      child: ListingCard(listing: l),
                    );
                  },
                ),
    );
  }
}
