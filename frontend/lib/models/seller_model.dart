class SellerModel {
  final String id;
  final String userId;
  final String shopName;
  final String ownerName;
  final String address;
  final String city;
  final String shopCategory;
  final String description;
  final List<String> shopPhotoUrls;
  final String status;
  final DateTime createdAt;

  SellerModel({
    required this.id,
    required this.userId,
    required this.shopName,
    required this.ownerName,
    required this.address,
    required this.city,
    required this.shopCategory,
    required this.description,
    required this.shopPhotoUrls,
    required this.status,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    final photos = json['shop_photo_urls'] as List<dynamic>? ?? [];
    return SellerModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      shopCategory: json['shop_category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      shopPhotoUrls: photos.whereType<String>().toList(),
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
