class ForecastItem {
  final DateTime time;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int windDeg;
  final double pop;
  final String weatherMain;
  final String weatherIcon;
  final String description;

  ForecastItem({
    required this.time,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDeg,
    required this.pop,
    required this.weatherMain,
    required this.weatherIcon,
    required this.description,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List<dynamic>?;
    final weather = (weatherList != null && weatherList.isNotEmpty) ? weatherList[0] as Map<String, dynamic> : null;
    final main = json['main'] as Map<String, dynamic>? ?? {};
    final wind = json['wind'] as Map<String, dynamic>? ?? {};

    return ForecastItem(
      time: DateTime.fromMillisecondsSinceEpoch(((json['dt'] as num?)?.toInt() ?? 0) * 1000),
      temperature: (main['temp'] as num?)?.toDouble() ?? 0,
      feelsLike: (main['feels_like'] as num?)?.toDouble() ?? 0,
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0,
      windDeg: (wind['deg'] as num?)?.toInt() ?? 0,
      // OpenWeather's "pop" is a 0-1 probability; convert to a 0-100 percentage.
      pop: ((json['pop'] as num?)?.toDouble() ?? 0) * 100,
      weatherMain: weather?['main'] as String? ?? '',
      weatherIcon: weather?['icon'] as String? ?? '',
      description: weather?['description'] as String? ?? '',
    );
  }
}

class ForecastResult {
  final String location;
  final List<ForecastItem> items;

  ForecastResult({required this.location, required this.items});

  factory ForecastResult.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return ForecastResult(
      location: json['location'] as String? ?? '',
      items: itemsList.map((e) => ForecastItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}