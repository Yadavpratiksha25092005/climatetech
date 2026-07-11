import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listing_model.dart';
import '../models/seller_model.dart';
import '../services/marketplace_service.dart';
import 'auth_provider.dart';

final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  return MarketplaceService(ref.read(apiServiceProvider));
});

enum LoadStatus { initial, loading, loaded, error }

class MarketplaceState {
  final LoadStatus browseStatus;
  final List<ListingModel> listings;
  final String? browseError;

  final LoadStatus sellerStatus;
  final SellerModel? mySeller;
  final String? sellerError;

  final LoadStatus myListingsStatus;
  final List<ListingModel> myListings;
  final String? myListingsError;

  const MarketplaceState({
    this.browseStatus = LoadStatus.initial,
    this.listings = const [],
    this.browseError,
    this.sellerStatus = LoadStatus.initial,
    this.mySeller,
    this.sellerError,
    this.myListingsStatus = LoadStatus.initial,
    this.myListings = const [],
    this.myListingsError,
  });

  MarketplaceState copyWith({
    LoadStatus? browseStatus,
    List<ListingModel>? listings,
    String? browseError,
    LoadStatus? sellerStatus,
    SellerModel? mySeller,
    bool clearMySeller = false,
    String? sellerError,
    LoadStatus? myListingsStatus,
    List<ListingModel>? myListings,
    String? myListingsError,
  }) {
    return MarketplaceState(
      browseStatus: browseStatus ?? this.browseStatus,
      listings: listings ?? this.listings,
      browseError: browseError,
      sellerStatus: sellerStatus ?? this.sellerStatus,
      mySeller: clearMySeller ? null : (mySeller ?? this.mySeller),
      sellerError: sellerError,
      myListingsStatus: myListingsStatus ?? this.myListingsStatus,
      myListings: myListings ?? this.myListings,
      myListingsError: myListingsError,
    );
  }
}

class MarketplaceNotifier extends StateNotifier<MarketplaceState> {
  final MarketplaceService _service;

  String _category = '';
  String _search = '';

  // Guards against a stale browse request (e.g. a fast filter/search change
  // fired while the previous request was still in flight) resolving after a
  // newer one and overwriting fresher listings — same pattern as
  // ClimateNotifier's _aiSummaryRequestId.
  int _browseRequestId = 0;

  MarketplaceNotifier(this._service) : super(const MarketplaceState()) {
    loadListings();
    loadMySellerProfile();
  }

  Future<void> loadListings() async {
    final requestId = ++_browseRequestId;
    state = state.copyWith(browseStatus: LoadStatus.loading, browseError: null);
    try {
      final listings = await _service.browseListings(category: _category, search: _search);
      if (requestId != _browseRequestId) return; // superseded by a newer request
      state = state.copyWith(browseStatus: LoadStatus.loaded, listings: listings);
    } catch (e) {
      if (requestId != _browseRequestId) return;
      state = state.copyWith(browseStatus: LoadStatus.error, browseError: e.toString());
    }
  }

  /// No-op if the category hasn't actually changed, so tapping the
  /// already-selected chip doesn't trigger a redundant reload.
  Future<void> setCategory(String category) async {
    if (_category == category) return;
    _category = category;
    await loadListings();
  }

  Future<void> setSearch(String query) async {
    if (_search == query) return;
    _search = query;
    await loadListings();
  }

  Future<void> loadMySellerProfile() async {
    state = state.copyWith(sellerStatus: LoadStatus.loading, sellerError: null);
    try {
      final seller = await _service.getMySellerProfile();
      state = state.copyWith(sellerStatus: LoadStatus.loaded, mySeller: seller, clearMySeller: seller == null);
    } catch (e) {
      state = state.copyWith(sellerStatus: LoadStatus.error, sellerError: e.toString());
    }
  }

  Future<bool> applyAsSeller({
    required String shopName,
    required String ownerName,
    required String address,
    required String city,
    required String shopCategory,
    required String phone,
    String? description,
    List<String> shopPhotoUrls = const [],
  }) async {
    try {
      final seller = await _service.applySeller(
        shopName: shopName,
        ownerName: ownerName,
        address: address,
        city: city,
        shopCategory: shopCategory,
        phone: phone,
        description: description,
        shopPhotoUrls: shopPhotoUrls,
      );
      state = state.copyWith(sellerStatus: LoadStatus.loaded, mySeller: seller);
      return true;
    } catch (e) {
      state = state.copyWith(sellerStatus: LoadStatus.error, sellerError: e.toString());
      return false;
    }
  }

  Future<void> loadMyListings() async {
    state = state.copyWith(myListingsStatus: LoadStatus.loading, myListingsError: null);
    try {
      final listings = await _service.getMyListings();
      state = state.copyWith(myListingsStatus: LoadStatus.loaded, myListings: listings);
    } catch (e) {
      state = state.copyWith(myListingsStatus: LoadStatus.error, myListingsError: e.toString());
    }
  }

  Future<bool> createListing({
    required String title,
    String? description,
    required double price,
    required String category,
    List<String> imageUrls = const [],
    String condition = 'used',
    String? location,
  }) async {
    try {
      final created = await _service.createListing(
        title: title,
        description: description,
        price: price,
        category: category,
        imageUrls: imageUrls,
        condition: condition,
        location: location,
      );
      await loadMyListings();

      // Keeps the browse collection in sync too, not just myListings — a
      // buyer looking at the same category/search would otherwise not see
      // this listing until the browse screen happens to reload some other
      // way. Only added if it actually matches the current filter, the
      // same way the server-side browse query would include it.
      final matchesCategory = _category.isEmpty || created.category == _category;
      final matchesSearch = _search.isEmpty ||
          created.title.toLowerCase().contains(_search.toLowerCase()) ||
          created.description.toLowerCase().contains(_search.toLowerCase());
      if (matchesCategory && matchesSearch) {
        state = state.copyWith(listings: [created, ...state.listings]);
      }
      return true;
    } catch (e) {
      state = state.copyWith(myListingsError: e.toString());
      return false;
    }
  }

  /// Removes the listing from local state directly instead of re-fetching
  /// the whole list — the server already confirmed the delete, so there's
  /// nothing new to learn from a reload. Removed from both myListings and
  /// the browse collection, since the same listing can appear in either.
  Future<bool> deleteListing(String id) async {
    try {
      await _service.deleteListing(id);
      state = state.copyWith(
        myListings: state.myListings.where((l) => l.id != id).toList(),
        listings: state.listings.where((l) => l.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(myListingsError: e.toString());
      return false;
    }
  }
}

final marketplaceProvider = StateNotifierProvider<MarketplaceNotifier, MarketplaceState>((ref) {
  return MarketplaceNotifier(ref.read(marketplaceServiceProvider));
});
