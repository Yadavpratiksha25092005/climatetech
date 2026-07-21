import 'package:flutter/material.dart';

const List<String> marketplaceCategories = [
  'Plants & Saplings',
  'Organic Compost',
  'Solar & Energy',
  'Upcycled & Recycled',
  'Eco Home & Garden',
  'Organic Food',
  'Reusable & Zero-Waste',
  'Eco Fashion',
  'Water Conservation',
  'Other',
];

/// Icon shown on the marketplace category grid for each entry in
/// [marketplaceCategories] — falls back to a generic leaf icon for anything
/// not explicitly mapped (e.g. a future category added without updating this).
IconData marketplaceCategoryIcon(String category) {
  switch (category) {
    case 'Plants & Saplings':
      return Icons.local_florist_outlined;
    case 'Organic Compost':
      return Icons.compost_outlined;
    case 'Solar & Energy':
      return Icons.solar_power_outlined;
    case 'Upcycled & Recycled':
      return Icons.recycling_outlined;
    case 'Eco Home & Garden':
      return Icons.yard_outlined;
    case 'Organic Food':
      return Icons.grass_outlined;
    case 'Reusable & Zero-Waste':
      return Icons.shopping_bag_outlined;
    case 'Eco Fashion':
      return Icons.checkroom_outlined;
    case 'Water Conservation':
      return Icons.water_drop_outlined;
    default:
      return Icons.eco_outlined;
  }
}

class ListingModel {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String category;
  final List<String> imageUrls;
  final String condition;
  final String location;
  final bool isActive;
  final DateTime createdAt;
  final String shopName;
  final bool verified;

  ListingModel({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.condition,
    required this.location,
    required this.isActive,
    required this.createdAt,
    required this.shopName,
    required this.verified,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    final images = json['image_urls'] as List<dynamic>? ?? [];
    return ListingModel(
      id: json['id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      imageUrls: images.whereType<String>().toList(),
      condition: json['condition'] as String? ?? 'used',
      location: json['location'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      shopName: json['shop_name'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
    );
  }
}

/// The richer shape returned by the single-listing detail endpoint, which
/// nests seller/contact info separately rather than flattening it onto the
/// listing the way the browse endpoint does.
class ListingDetailModel {
  final ListingModel listing;
  final String shopName;
  final String ownerName;
  final String city;
  final bool verified;
  final String contactName;
  final String contactPhone;

  ListingDetailModel({
    required this.listing,
    required this.shopName,
    required this.ownerName,
    required this.city,
    required this.verified,
    required this.contactName,
    required this.contactPhone,
  });

  factory ListingDetailModel.fromJson(Map<String, dynamic> json) {
    final listingJson = json['listing'] as Map<String, dynamic>? ?? {};
    final sellerJson = json['seller'] as Map<String, dynamic>? ?? {};
    final contactJson = json['contact'] as Map<String, dynamic>? ?? {};
    return ListingDetailModel(
      listing: ListingModel.fromJson(listingJson),
      shopName: sellerJson['shop_name'] as String? ?? '',
      ownerName: sellerJson['owner_name'] as String? ?? '',
      city: sellerJson['city'] as String? ?? '',
      verified: sellerJson['verified'] as bool? ?? false,
      contactName: contactJson['name'] as String? ?? '',
      contactPhone: contactJson['phone'] as String? ?? '',
    );
  }
}
