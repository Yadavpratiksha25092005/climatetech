import 'package:dio/dio.dart';

import '../models/listing_model.dart';
import '../models/seller_model.dart';
import 'api_service.dart';

class MarketplaceException implements Exception {
  final String message;
  MarketplaceException(this.message);
  @override
  String toString() => message;
}

class MarketplaceService {
  final ApiService _api;

  MarketplaceService(this._api);

  Future<SellerModel> applySeller({
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
      final response = await _api.dio.post('/marketplace/seller/apply', data: {
        'shop_name': shopName,
        'owner_name': ownerName,
        'address': address,
        'city': city,
        'shop_category': shopCategory,
        'phone': phone,
        if (description != null && description.isNotEmpty) 'description': description,
        'shop_photo_urls': shopPhotoUrls,
      });
      return SellerModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  Future<SellerModel?> getMySellerProfile() async {
    try {
      final response = await _api.dio.get('/marketplace/seller/me');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      if (data['has_profile'] != true) return null;
      return SellerModel.fromJson(data['seller'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  Future<List<ListingModel>> browseListings({String? category, String? search, int limit = 20}) async {
    try {
      final response = await _api.dio.get('/marketplace/listings', queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
      });
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => ListingModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  Future<ListingDetailModel> getListingDetail(String id) async {
    try {
      final response = await _api.dio.get('/marketplace/listings/$id');
      return ListingDetailModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  Future<ListingModel> createListing({
    required String title,
    String? description,
    required double price,
    required String category,
    List<String> imageUrls = const [],
    String condition = 'used',
    String? location,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/listings', data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'price': price,
        'category': category,
        'image_urls': imageUrls,
        'condition': condition,
        if (location != null && location.isNotEmpty) 'location': location,
      });
      return ListingModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  Future<List<ListingModel>> getMyListings() async {
    try {
      final response = await _api.dio.get('/marketplace/my-listings');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => ListingModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  Future<void> deleteListing(String id) async {
    try {
      await _api.dio.delete('/marketplace/listings/$id');
    } on DioException catch (e) {
      throw MarketplaceException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the marketplace.';
  }
}
