import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

// Screens
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/awaiting_approval_screen.dart';
import 'screens/directory_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/communities_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/donations_screen.dart';
import 'screens/events_screen.dart';
import 'screens/notices_screen.dart';

// Services & Blocs
import 'blocs/auth/auth_cubit.dart';
import 'services/api_service.dart';
import 'widgets/main_layout.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlumniApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AlumniApp extends StatefulWidget {
  const AlumniApp({super.key});

  @override
  State<AlumniApp> createState() => _AlumniAppState();
}

class _AlumniAppState extends State<AlumniApp> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(apiService: ApiService())..checkAuthentication();

    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(_authCubit.stream),
      redirect: (context, state) {
        final authState = _authCubit.state;

        // Don't redirect while checking local storage on app start
        if (authState is AuthLoading || authState is AuthInitial) {
          return null;
        }

        final isAuth = authState is AuthAuthenticated;
        final goingToLanding = state.matchedLocation == '/';
        final goingToLogin = state.matchedLocation == '/login';
        final goingToRegister = state.matchedLocation == '/register';
        final isPublicRoute = goingToLanding || goingToLogin || goingToRegister;

        if (!isAuth && !isPublicRoute) return '/login';

        if (isAuth) {
          final user = (authState).user;
          final isApproved = user['is_approved'] == true;

          if (!isApproved) {
            if (state.matchedLocation != '/awaiting-approval') {
              return '/awaiting-approval';
            }
            return null; // Stay on awaiting approval
          } else {
            // If approved and trying to go to awaiting-approval or public routes
            if (state.matchedLocation == '/awaiting-approval' ||
                isPublicRoute) {
              return '/dashboard';
            }
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/awaiting-approval',
          builder: (context, state) => const AwaitingApprovalScreen(),
        ),
        GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return MainLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/directory',
              builder: (context, state) => const DirectoryScreen(),
            ),
            GoRoute(
              path: '/jobs',
              builder: (context, state) => const JobsScreen(),
            ),
            GoRoute(
              path: '/communities',
              builder: (context, state) => const CommunitiesScreen(),
            ),
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen(),
            ),
            GoRoute(
              path: '/notices',
              builder: (context, state) => const NoticesScreen(),
            ),
            GoRoute(
              path: '/donations',
              builder: (context, state) {
                final user = _authCubit.state is AuthAuthenticated
                    ? (_authCubit.state as AuthAuthenticated).user
                    : null;
                return DonationsScreen(user: user);
              },
            ),
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const AdminUsersScreen(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Alumni Portal',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
