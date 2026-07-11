import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

const _channelId = 'climate_alerts_channel';
const _channelName = 'Climate Alerts';

/// Background FCM messages are delivered on a separate headless isolate, so
/// this must be a top-level (or static) function annotated with
/// `@pragma('vm:entry-point')` for the Flutter engine to find it there.
/// FCM already renders notification-only payloads while the app is
/// backgrounded/terminated, so there's nothing to do here beyond letting the
/// system handle it — this stays side-effect free since the isolate has no
/// guaranteed access to the rest of the app's state (Riverpod providers, etc).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Handles climate-alert push notifications: permission, FCM token
/// registration with the backend, and displaying foreground pushes as local
/// notifications. Every public method is best-effort — a failure here should
/// never crash the app or break login/other features.
class NotificationService {
  final ApiService _api;

  NotificationService(this._api);

  /// Shared across every NotificationService instance and initialized once in
  /// main() before Riverpod exists, so the channel is always ready by the
  /// time a foreground push needs to be displayed.
  static final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alerts about air quality, heat, and rain near you.',
      importance: Importance.high,
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      developer.log('Failed to request notification permission', error: e, name: 'NotificationService');
      return false;
    }
  }

  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _api.dio.put('/users/fcm-token', data: {'fcm_token': token});
    } catch (e) {
      developer.log('Failed to register FCM token', error: e, name: 'NotificationService');
    }
  }

  /// Idempotent — safe to call more than once per app session (e.g. after a
  /// logout/login cycle); it always cancels any prior subscription first so
  /// listeners never accumulate.
  Future<void> setupForegroundHandler() async {
    // Awaited so the old subscription is fully torn down before the
    // replacement is created — without this, cancel() is only requested,
    // not guaranteed complete, leaving a brief window where the outgoing
    // listener could still fire alongside the new one.
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _showLocalNotification(notification.title, notification.body);
    });
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      // Full millisecond precision (not truncated to seconds, which
      // collided when two notifications landed in the same second) masked
      // to 31 bits so it always fits Android's native int32 notification
      // id — a raw millisecondsSinceEpoch value overflows that range.
      final notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      await localNotifications.show(
        notificationId,
        title,
        body,
        details,
      );
    } catch (e) {
      developer.log('Failed to show local notification', error: e, name: 'NotificationService');
    }
  }

  void dispose() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
  }
}
