import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'alerts_provider.dart';
import 'carbon_provider.dart';
import 'challenge_provider.dart';
import 'climate_provider.dart';
import 'insights_provider.dart';
import 'marketplace_provider.dart';
// newsProvider is deliberately NOT imported/invalidated here — GET /news is
// a page-keyed Redis cache shared across every user (no user_id filtering
// at all server-side), so there's no per-user state there to go stale.

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.read(storageServiceProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
      ref.read(apiServiceProvider), ref.read(storageServiceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(apiServiceProvider));
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthService _authService;
  final StorageService _storage;

  AuthNotifier(this._ref, this._authService, this._storage)
      : super(const AuthState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _authService.fetchProfile();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _setupNotifications();
    } catch (_) {
      await _storage.clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _authService.login(phone: phone, password: password);
      state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          isLoading: false);
      _setupNotifications();
      _refreshUserScopedProviders();
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      // Any error that isn't the service's own AuthException (a malformed
      // response, a bug elsewhere) must still resolve isLoading — otherwise
      // the sign-in button spins forever with no way out.
      state = state.copyWith(isLoading: false, errorMessage: 'Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> register(String name, String phone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _authService.register(
          name: name, phone: phone, password: password);
      state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          isLoading: false);
      _setupNotifications();
      _refreshUserScopedProviders();
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Something went wrong. Please try again.');
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
    _invalidateUserScopedProviders();
  }

  /// Every provider invalidated here is a plain, app-lifetime
  /// StateNotifierProvider that fetches user-specific data once in its
  /// constructor and never rebuilds on its own — so without this, whoever
  /// logs in next inherits this user's cached state (an approved seller's
  /// status leaking onto a brand-new account, one user's carbon/challenge/
  /// alert/climate data briefly showing for another, etc).
  ///
  /// Invalidating is NOT always lazy: if the provider still has an active
  /// listener at this exact moment — e.g. DashboardScreen stays mounted
  /// (and subscribed to climateProvider) underneath a pushed ProfileScreen,
  /// since go_router's redirect-driven navigation only catches up on the
  /// next frame, after this synchronous method has already returned —
  /// Riverpod rebuilds it EAGERLY, right here, using whatever token exists
  /// at this exact point (already cleared by _authService.logout() above).
  /// That fetch fails with "missing authorization header" and settles into
  /// an error state that would otherwise sit there, stale, through the next
  /// login. _refreshUserScopedProviders() (called from login()/register())
  /// is what actually guarantees fresh data gets shown — this invalidation
  /// is a defense-in-depth measure, not the whole fix.
  ///
  /// newsProvider is deliberately excluded: GET /news is a page-keyed Redis
  /// cache with no user_id filtering at all, shared identically across every
  /// user, so there's no per-user state there to go stale.
  ///
  /// Each provider is invalidated independently so one glitching never skips
  /// the rest, and nothing here can block logout() from completing.
  void _invalidateUserScopedProviders() {
    _invalidateSafely(marketplaceProvider);
    _invalidateSafely(challengeProvider);
    _invalidateSafely(alertsProvider);
    _invalidateSafely(carbonProvider);
    _invalidateSafely(climateProvider);
    _invalidateSafely(insightsProvider);
  }

  void _invalidateSafely(ProviderBase<Object?> provider) {
    try {
      // Guard with exists() first: calling ref.invalidate() (from within
      // another provider's scope, which is what this is) on a provider that
      // has never been read yet doesn't just no-op — Riverpod's internal
      // dependency-tracking assertion constructs it in order to invalidate
      // it, then immediately disposes it again. Any fire-and-forget load()
      // its constructor kicked off is still pending at that point, and later
      // crashes with "Bad state: used after dispose" when it tries to write
      // to state. exists() is a genuine no-op check — it never creates.
      if (_ref.exists(provider)) {
        _ref.invalidate(provider);
      }
    } catch (_) {
      // A provider-invalidation hiccup must never block logout.
    }
  }

  /// Guarantees every per-user provider shows fresh, correctly-authenticated
  /// data for THIS session, regardless of what happened to it during the
  /// previous logout (an eager, no-token refetch triggered by an active
  /// listener; a still-pending lazy invalidation; or nothing at all on a
  /// truly first-ever login). Fire-and-forget and individually guarded —
  /// see _invalidateSafely — so one provider's hiccup can't affect another's
  /// refresh or block login/register from completing.
  void _refreshUserScopedProviders() {
    _refreshSafely(
        () => _ref.read(marketplaceProvider.notifier).loadListings());
    _refreshSafely(
        () => _ref.read(marketplaceProvider.notifier).loadMySellerProfile());
    _refreshSafely(
        () => _ref.read(challengeProvider.notifier).loadChallenges());
    _refreshSafely(
        () => _ref.read(challengeProvider.notifier).loadNewChallengesCount());
    _refreshSafely(() => _ref.read(alertsProvider.notifier).load());
    _refreshSafely(() => _ref.read(alertsProvider.notifier).loadUnreadCount());
    _refreshSafely(() => _ref.read(carbonProvider.notifier).load());
    _refreshSafely(() => _ref.read(climateProvider.notifier).loadClimate());
    _refreshSafely(() => _ref.read(insightsProvider.notifier).load());
  }

  void _refreshSafely(Future<void> Function() action) {
    try {
      unawaited(action().catchError((_) {}));
    } catch (_) {
      // A provider-refresh hiccup must never block login/register.
    }
  }

  /// Returns whether the refresh actually succeeded so a caller that cares
  /// (unlike the fire-and-forget use after a challenge check-in) can surface
  /// a failure instead of it vanishing silently.
  Future<bool> refreshProfile() async {
    try {
      final user = await _authService.fetchProfile();
      state = state.copyWith(user: user);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget: notification setup (permission prompt, FCM token
  /// registration, foreground listener) must never block or fail the login
  /// flow itself.
  void _setupNotifications() {
    unawaited(_runNotificationSetup());
  }

  Future<void> _runNotificationSetup() async {
    try {
      final notifications = _ref.read(notificationServiceProvider);
      final granted = await notifications.requestPermission();
      if (granted) {
        await notifications.registerToken();
      }
      notifications.setupForegroundHandler();
    } catch (_) {
      // Notifications are best-effort; never let a failure here affect auth state.
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
      ref, ref.read(authServiceProvider), ref.read(storageServiceProvider));
});
