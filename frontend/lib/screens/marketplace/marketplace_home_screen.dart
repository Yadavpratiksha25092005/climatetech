import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/listing_model.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/dark_text_field.dart';
import '../../widgets/feature_intro_banner.dart';

class MarketplaceHomeScreen extends ConsumerStatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  ConsumerState<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends ConsumerState<MarketplaceHomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    ref.read(marketplaceProvider.notifier).loadListings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(marketplaceProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplaceProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Marketplace', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: DarkPalette.textPrimary),
            tooltip: 'My listings',
            onPressed: () => context.push('/marketplace/my-listings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkPalette.leafGreen,
        foregroundColor: Colors.black,
        onPressed: () => context.push('/marketplace/post'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(marketplaceProvider.notifier).loadListings(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FeatureIntroBanner(
                icon: Icons.storefront_outlined,
                title: 'Buy and sell eco-friendly goods',
                description:
                    'Browse listings from verified local sellers, or tap the + button to apply as a seller and post your own items.',
              ),
              const SizedBox(height: 16),
              DarkTextField(
                hint: 'Search listings...',
                icon: Icons.search,
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 14),
              _categoryChips(),
              const SizedBox(height: 16),
              if (state.browseStatus == LoadStatus.loading && state.listings.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
                )
              else if (state.browseStatus == LoadStatus.error && state.listings.isEmpty)
                _buildErrorState(state.browseError)
              else if (state.listings.isEmpty)
                _buildEmptyState()
              else
                _buildGrid(state.listings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    final categories = ['', ...marketplaceCategories];
    return SizedBox(
      height: 176,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (context, i) {
          final category = categories[i];
          final label = category.isEmpty ? 'All' : category;
          final selected = _selectedCategory == category;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _selectedCategory = category);
              ref.read(marketplaceProvider.notifier).setCategory(category);
            },
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: selected ? DarkPalette.leafGreen.withOpacity(0.18) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: selected ? Border.all(color: DarkPalette.leafGreen, width: 1.5) : null,
                    ),
                    child: Icon(
                      category.isEmpty ? Icons.apps_rounded : marketplaceCategoryIcon(category),
                      color: selected ? DarkPalette.leafGreen : DarkPalette.textSecondary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? DarkPalette.leafGreen : DarkPalette.textSecondary,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<ListingModel> listings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listings.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, i) => _listingCard(listings[i]),
    );
  }

  Widget _listingCard(ListingModel listing) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/marketplace/listings/${listing.id}'),
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: listing.imageUrls.isNotEmpty
                  ? Image.network(
                      listing.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${listing.price.toStringAsFixed(0)}',
                    style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11),
                        ),
                      ),
                      if (listing.verified) const Icon(Icons.verified, color: DarkPalette.cyanAccent, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.06),
      child: const Center(child: Icon(Icons.image_outlined, color: DarkPalette.textMuted, size: 28)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: const Center(child: Text('No listings found.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
    );
  }

  Widget _buildErrorState(String? message) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? 'Could not load listings.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(marketplaceProvider.notifier).loadListings(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
