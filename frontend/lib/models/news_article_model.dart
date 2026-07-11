class NewsArticleModel {
  final String title;
  final String description;
  final String url;
  final String imageUrl;
  final String sourceName;
  final DateTime? publishedAt;

  NewsArticleModel({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.sourceName,
    required this.publishedAt,
  });

  factory NewsArticleModel.fromJson(Map<String, dynamic> json) {
    final publishedRaw = json['published_at'] as String?;
    return NewsArticleModel(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
      publishedAt: publishedRaw != null ? DateTime.tryParse(publishedRaw) : null,
    );
  }
}
