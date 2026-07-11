const List<String> marketplaceCategories = [
  'Electronics',
  'Furniture',
  'Vehicles',
  'Solar & Energy',
  'Garden & Compost',
  'Clothing',
  'Other',
];

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
  final String contactEmail;
  final String contactPhone;

  ListingDetailModel({
    required this.listing,
    required this.shopName,
    required this.ownerName,
    required this.city,
    required this.verified,
    required this.contactName,
    required this.contactEmail,
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
      contactEmail: contactJson['email'] as String? ?? '',
      // Empty for sellers who applied before the phone field existed.
      contactPhone: contactJson['phone'] as String? ?? '',
    );
  }
}
