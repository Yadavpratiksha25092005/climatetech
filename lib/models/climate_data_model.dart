class ClimateDataModel {
  final double latitude;
  final double longitude;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int windDeg;
  final int pressure;
  final int visibility;
  final double rainVolume;
  final double dewPoint;
  final String weatherMain;
  final String weatherDescription;
  final String weatherIcon;
  final int aqi;
  final String aqiLabel;
  final double pm25;
  final double pm10;
  final String locationName;
  final DateTime recordedAt;

 ClimateDataModel({
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDeg,
    required this.pressure,
    required this.visibility,
    required this.rainVolume,
    required this.dewPoint,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.aqi,
    required this.aqiLabel,
    required this.pm25,
    required this.pm10,
    required this.locationName,
    required this.recordedAt,
  });

  factory ClimateDataModel.fromJson(Map<String, dynamic> json) {
    final record = json['record'] as Map<String, dynamic>? ?? {};
    final recordedAtRaw = record['recorded_at'] as String?;
   return ClimateDataModel(
      latitude: (record['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (record['longitude'] as num?)?.toDouble() ?? 0,
      temperature: (record['temperature'] as num?)?.toDouble() ?? 0,
      feelsLike: (record['feels_like'] as num?)?.toDouble() ?? 0,
      humidity: record['humidity'] as int? ?? 0,
      windSpeed: (record['wind_speed'] as num?)?.toDouble() ?? 0,
      windDeg: record['wind_deg'] as int? ?? 0,
      pressure: record['pressure'] as int? ?? 0,
      visibility: record['visibility'] as int? ?? 0,
      rainVolume: (record['rain_volume'] as num?)?.toDouble() ?? 0,
      dewPoint: (record['dew_point'] as num?)?.toDouble() ?? 0,
      weatherMain: record['weather_main'] as String? ?? '',
      weatherDescription: record['weather_description'] as String? ?? '',
      weatherIcon: record['weather_icon'] as String? ?? '',
      aqi: record['aqi'] as int? ?? 0,
      // Read from the same `record` object as every sibling field here —
      // reading from top-level `json` was always missing and silently
      // defaulting to 'Unknown'.
      aqiLabel: record['aqi_label'] as String? ?? 'Unknown',
      pm25: (record['pm2_5'] as num?)?.toDouble() ?? 0,
      pm10: (record['pm10'] as num?)?.toDouble() ?? 0,
      locationName: record['location_name'] as String? ?? 'Your location',
      recordedAt: DateTime.tryParse(recordedAtRaw ?? '') ?? DateTime.now(),
    );
  }
}