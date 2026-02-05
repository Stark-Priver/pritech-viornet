import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../layout/main_layout.dart';
import '../screens/splash_screen.dart';
import '../rbac/permissions.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/clients/screens/clients_screen.dart';
import '../../features/clients/screens/client_detail_screen.dart';
import '../../features/vouchers/screens/vouchers_screen.dart';
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
import '../../features/users/screens/users_screen.dart';

// Router Provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final goingToLogin = state.uri.path == '/login';
      final goingToRegister = state.uri.path == '/register';
      final goingToSplash = state.uri.path == '/splash';

      // Allow splash screen always
      if (goingToSplash) return null;

      // If not logged in and not going to login/register, redirect to login
      if (!isLoggedIn && !goingToLogin && !goingToRegister) {
        return '/login';
      }

      // If logged in and going to login, redirect to dashboard
      if (isLoggedIn && (goingToLogin || goingToRegister)) {
        return '/';
      }

      // Check route permissions for authenticated users
      if (isLoggedIn && !goingToLogin && !goingToRegister && !goingToSplash) {
        final checker = PermissionChecker(authState.userRoles);
        if (!checker.canAccessRoute(state.uri.path)) {
          // User doesn't have permission, redirect to dashboard
          return '/';
        }
      }

      return null;
    },
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
            builder: (context, state) => const VouchersScreen(),
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
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class AppRouter {
  static GoRouter router(WidgetRef ref) => ref.watch(routerProvider);
}
