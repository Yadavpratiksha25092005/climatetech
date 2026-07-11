class AlertModel {
  final String id;
  final String alertType;
  final String severity;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String? ?? '',
      alertType: json['alert_type'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  AlertModel copyWith({bool? isRead}) {
    return AlertModel(
      id: id,
      alertType: alertType,
      severity: severity,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
