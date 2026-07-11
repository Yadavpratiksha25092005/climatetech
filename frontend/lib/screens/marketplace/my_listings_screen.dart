import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/listing_model.dart';
import '../../providers/marketplace_provider.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(marketplaceProvider.notifier).loadMyListings();
  }

  Future<void> _delete(ListingModel listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkPalette.navyCard,
        title: const Text('Delete listing?', style: TextStyle(color: DarkPalette.textPrimary)),
        content: Text('Remove "${listing.title}" from the marketplace?', style: const TextStyle(color: DarkPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFE0605A)))),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ref.read(marketplaceProvider.notifier).deleteListing(listing.id);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(marketplaceProvider).myListingsError ?? 'Could not delete listing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplaceProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('My listings', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(marketplaceProvider.notifier).loadMyListings(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(MarketplaceState state) {
    if (state.myListingsStatus == LoadStatus.loading && state.myListings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
      );
    }
    if (state.myListingsStatus == LoadStatus.error && state.myListings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              state.myListingsError ?? 'Could not load your listings.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(marketplaceProvider.notifier).loadMyListings(),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (state.myListings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Text("You haven't posted any listings yet.", style: TextStyle(color: DarkPalette.textMuted, fontSize: 13)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.myListings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _listingTile(state.myListings[i]),
    );
  }

  Widget _listingTile(ListingModel listing) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: listing.imageUrls.isNotEmpty
                  ? Image.network(listing.imageUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('₹${listing.price.toStringAsFixed(0)}', style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE0605A), size: 20),
            onPressed: () => _delete(listing),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white.withOpacity(0.06),
      child: const Icon(Icons.image_outlined, color: DarkPalette.textMuted, size: 20),
    );
  }
}
