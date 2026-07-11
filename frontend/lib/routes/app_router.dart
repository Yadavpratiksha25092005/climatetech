import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/dark_palette.dart';
import '../providers/auth_provider.dart';
import '../screens/about/about_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/carbon/carbon_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/challenges/challenges_screen.dart';
import '../screens/challenges/leaderboard_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/forecast/forecast_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/marketplace/become_seller_screen.dart';
import '../screens/marketplace/listing_detail_screen.dart';
import '../screens/marketplace/marketplace_home_screen.dart';
import '../screens/marketplace/my_listings_screen.dart';
import '../screens/marketplace/post_listing_screen.dart';
import '../screens/news/news_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      if (location == '/splash') return null;

      final isAuthRoute = location == '/login' || location == '/register';

      // Don't let a protected (or auth) route render while it's still
      // unknown whether the user is authenticated — e.g. a deep link opened
      // cold, before _bootstrap() has resolved. Gate through /splash
      // instead of rendering the destination prematurely; the splash
      // screen already knows to move on to /dashboard or /login itself
      // once status leaves `unknown`.
      // (location == '/splash' already returned above, so reaching here
      // means this is some other route while status is still unresolved.)
      if (authState.status == AuthStatus.unknown) return '/splash';

      final isAuthenticated = authState.status == AuthStatus.authenticated;

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(path: '/carbon', builder: (context, state) => const CarbonScreen()),
      GoRoute(path: '/forecast', builder: (context, state) => const ForecastScreen()),
      GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
      GoRoute(path: '/marketplace', builder: (context, state) => const MarketplaceHomeScreen()),
      GoRoute(path: '/marketplace/become-seller', builder: (context, state) => const BecomeSellerScreen()),
      GoRoute(path: '/marketplace/post', builder: (context, state) => const PostListingScreen()),
      GoRoute(path: '/marketplace/my-listings', builder: (context, state) => const MyListingsScreen()),
      GoRoute(
        path: '/marketplace/listings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const _RouteNotFoundScreen();
          return ListingDetailScreen(listingId: id);
        },
      ),
      GoRoute(path: '/news', builder: (context, state) => const NewsScreen()),
      GoRoute(path: '/challenges', builder: (context, state) => const ChallengesScreen()),
      GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

/// Rendered instead of [ListingDetailScreen] when the route matched but its
/// required :id segment was somehow missing/empty — a required path
/// parameter can't normally be absent when a route matches, but this avoids
/// a forced unwrap crashing on that invariant if it's ever violated.
class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: DarkPalette.textMuted, size: 40),
              const SizedBox(height: 12),
              const Text(
                "This listing link isn't valid.",
                textAlign: TextAlign.center,
                style: TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/marketplace'),
                style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                child: const Text('Back to marketplace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}