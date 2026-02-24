import '../../features/sites/screens/isp_subscription_overview_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../layout/main_layout.dart';
import '../screens/splash_screen.dart';
import 'package:flutter/material.dart';

import './_site_isp_subscription_screen_loader.dart';
import '../rbac/permissions.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/clients/screens/clients_screen.dart';
import '../../features/clients/screens/client_detail_screen.dart';
import '../../features/vouchers/screens/voucher_management_screen.dart';
import '../../features/sales/screens/sales_history_screen.dart';
import '../../features/sales/screens/pos_screen.dart';
import '../../features/sites/screens/sites_screen.dart';
import '../../features/assets/screens/assets_screen.dart';
import '../../features/maintenance/screens/maintenance_screen.dart';
import '../../features/finance/screens/finance_screen.dart';
import '../../features/finance/screens/expenses_screen.dart';
import '../../features/sms/screens/sms_screen.dart';
import '../../features/packages/screens/packages_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/commission_settings_screen.dart';
import '../../features/settings/screens/commission_demands_screen.dart';
import '../../features/settings/screens/my_commissions_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../features/investors/screens/investors_screen.dart';
import '../../features/mikrotik/screens/mikrotik_connect_screen.dart';
import '../../features/mikrotik/screens/mikrotik_dashboard_screen.dart';
import '../../features/mikrotik/screens/mikrotik_sites_screen.dart';
import '../../features/vouchers/screens/voucher_quota_screen.dart';

// ── Router notifier ──────────────────────────────────────────────────────────
// Wraps auth state as a ChangeNotifier so GoRouter can use it as a
// refreshListenable WITHOUT recreating the GoRouter instance on each change.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    // Only retrigger redirect logic when the meaningful auth status changes:
    // - loading finishes (either way), or
    // - authenticated flag flips.
    // Firing on the transient loading->loading tick causes brief route flashes.
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final wasLoading = prev?.isLoading ?? true;
      final wasAuthenticated = prev?.isAuthenticated ?? false;
      final loadingEnded = wasLoading && !next.isLoading;
      final authFlipped = wasAuthenticated != next.isAuthenticated;
      if (loadingEnded || authFlipped) notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState routerState) {
    final authState = _ref.read(authProvider);

    // Never redirect while auth is still initialising (avoids flicker).
    if (authState.isLoading) return null;

    final isLoggedIn = authState.isAuthenticated;
    final goingToLogin = routerState.uri.path == '/login';
    final goingToSplash = routerState.uri.path == '/splash';

    // Splash is always allowed.
    if (goingToSplash) return null;

    // Unauthenticated users can only be on /login.
    if (!isLoggedIn && !goingToLogin) return '/login';

    // Authenticated user landing on /login → go to dashboard.
    if (isLoggedIn && goingToLogin) return '/';

    // RBAC route guard.
    if (isLoggedIn && !goingToLogin && !goingToSplash) {
      final checker = PermissionChecker(authState.userRoles);
      if (!checker.canAccessRoute(routerState.uri.path)) return '/';
    }

    return null;
  }
}

final _routerNotifierProvider =
    ChangeNotifierProvider<_RouterNotifier>((ref) => _RouterNotifier(ref));

// Router Provider — created ONCE; auth changes only retrigger redirect logic.
final routerProvider = Provider<GoRouter>((ref) {
  // ref.READ (not watch) — prevents the Provider from rebuilding when the
  // notifier fires. GoRouter's refreshListenable handles re-running redirect
  // internally without ever recreating the router instance.
  final notifier = ref.read(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // Splash Screen (no layout)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes (no layout)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main App Routes with Layout
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(
            currentRoute: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/clients',
            name: 'clients',
            builder: (context, state) => const ClientsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'client-detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ClientDetailScreen(clientId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/vouchers',
            name: 'vouchers',
            builder: (context, state) => const VoucherManagementScreen(),
          ),
          GoRoute(
            path: '/sales',
            name: 'sales',
            builder: (context, state) => const SalesHistoryScreen(),
          ),
          GoRoute(
            path: '/pos',
            name: 'pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: '/sites',
            name: 'sites',
            builder: (context, state) => const SitesScreen(),
          ),
          GoRoute(
            path: '/assets',
            name: 'assets',
            builder: (context, state) => const AssetsScreen(),
          ),
          GoRoute(
            path: '/maintenance',
            name: 'maintenance',
            builder: (context, state) => const MaintenanceScreen(),
          ),
          GoRoute(
            path: '/finance',
            name: 'finance',
            builder: (context, state) => const FinanceScreen(),
          ),
          GoRoute(
            path: '/expenses',
            name: 'expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/investors',
            name: 'investors',
            builder: (context, state) => const InvestorsScreen(),
          ),
          GoRoute(
            path: '/sms',
            name: 'sms',
            builder: (context, state) => const SmsScreen(),
          ),
          GoRoute(
            path: '/packages',
            name: 'packages',
            builder: (context, state) => const PackagesScreen(),
          ),
          GoRoute(
            path: '/users',
            name: 'users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/my-commissions',
            name: 'my-commissions',
            builder: (context, state) => const MyCommissionsScreen(),
          ),
          GoRoute(
            path: '/commission-demands',
            name: 'commission-demands-top',
            builder: (context, state) => const CommissionDemandsScreen(),
          ),
          GoRoute(
            path: '/voucher-quota',
            name: 'voucher-quota',
            builder: (context, state) => const VoucherQuotaScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'commissions',
                name: 'commission-settings',
                builder: (context, state) => const CommissionSettingsScreen(),
              ),
              GoRoute(
                path: 'commission-demands',
                name: 'commission-demands',
                builder: (context, state) => const CommissionDemandsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/isp-subscription',
            name: 'isp-subscription',
            builder: (context, state) => const IspSubscriptionOverviewScreen(),
          ),
          GoRoute(
            path: '/mikrotik',
            name: 'mikrotik',
            builder: (context, state) => const MikroTikSitesScreen(),
          ),
          GoRoute(
            path: '/mikrotik/connect',
            name: 'mikrotik-connect',
            builder: (context, state) => const MikroTikConnectScreen(),
          ),
          GoRoute(
            path: '/mikrotik/dashboard',
            name: 'mikrotik-dashboard',
            builder: (context, state) => const MikroTikDashboardScreen(),
          ),
          GoRoute(
            path: '/isp-subscription/:siteId',
            name: 'isp-subscription-detail',
            builder: (context, state) {
              final siteIdStr = state.pathParameters['siteId'];
              if (siteIdStr == null) {
                return const Scaffold(
                  body: Center(child: Text('No site ID provided.')),
                );
              }
              final siteId = int.tryParse(siteIdStr);
              if (siteId == null) {
                return const Scaffold(
                  body: Center(child: Text('Invalid site ID.')),
                );
              }
              // Use a FutureBuilder to fetch the Site by ID
              return SiteIspSubscriptionScreenLoader(siteId: siteId);
            },
          ),
        ],
      ),
    ],
  );
});

class AppRouter {
  static GoRouter router(WidgetRef ref) => ref.watch(routerProvider);
}
