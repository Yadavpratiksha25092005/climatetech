class GeoLocationModel {
  final String name;
  final String state;
  final String country;
  final double lat;
  final double lon;

  GeoLocationModel({
    required this.name,
    required this.state,
    required this.country,
    required this.lat,
    required this.lon,
  });

  factory GeoLocationModel.fromJson(Map<String, dynamic> json) {
    return GeoLocationModel(
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
    );
  }

  String get displayName {
    final parts = [name, if (state.isNotEmpty) state, country].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }
}
