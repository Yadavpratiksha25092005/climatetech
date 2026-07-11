import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert_model.dart';
import '../services/alert_service.dart';
import 'auth_provider.dart';

final alertServiceProvider = Provider<AlertService>((ref) {
  return AlertService(ref.read(apiServiceProvider));
});

enum AlertsStatus { initial, loading, loaded, error }

class AlertsState {
  final AlertsStatus status;
  final List<AlertModel> alerts;
  final String? errorMessage;
  final int unreadCount;

  const AlertsState({
    this.status = AlertsStatus.initial,
    this.alerts = const [],
    this.errorMessage,
    this.unreadCount = 0,
  });

  AlertsState copyWith({
    AlertsStatus? status,
    List<AlertModel>? alerts,
    String? errorMessage,
    int? unreadCount,
  }) {
    return AlertsState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      errorMessage: errorMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class AlertsNotifier extends StateNotifier<AlertsState> {
  final AlertService _alertService;

  AlertsNotifier(this._alertService) : super(const AlertsState()) {
    load();
    loadUnreadCount();
  }

  Future<void> load() async {
    state = state.copyWith(status: AlertsStatus.loading, errorMessage: null);
    try {
      final alerts = await _alertService.getAlertHistory();
      state = state.copyWith(status: AlertsStatus.loaded, alerts: alerts);
    } catch (e) {
      state = state.copyWith(status: AlertsStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final count = await _alertService.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {
      // Best-effort badge count — never surface this as a load error.
    }
  }

  /// Marks one alert as read, updating both the list entry and the unread
  /// badge count optimistically rather than re-fetching either.
  Future<void> markAsRead(String alertId) async {
    final index = state.alerts.indexWhere((a) => a.id == alertId);
    if (index == -1 || state.alerts[index].isRead) return;

    final updated = [...state.alerts];
    updated[index] = updated[index].copyWith(isRead: true);
    state = state.copyWith(alerts: updated, unreadCount: (state.unreadCount - 1).clamp(0, 1 << 31));

    try {
      await _alertService.markAsRead(alertId);
    } catch (_) {
      // Best-effort: leave the optimistic local update in place rather than
      // reverting and flickering the badge — the next loadUnreadCount()/load()
      // will reconcile with the server if this silently failed.
    }
  }
}

final alertsProvider = StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  return AlertsNotifier(ref.read(alertServiceProvider));
});
