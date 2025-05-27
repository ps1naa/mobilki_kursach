import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kursovoi/src/features/auth/application/auth_service.dart';
import 'package:kursovoi/src/features/auth/presentation/screens/login_screen.dart';
import 'package:kursovoi/src/features/auth/presentation/screens/register_screen.dart';
import 'package:kursovoi/src/features/home/presentation/screens/home_screen.dart';
import 'package:kursovoi/src/features/admin/presentation/screens/add_product_screen.dart';
import 'package:kursovoi/src/features/cart/presentation/screens/cart_screen.dart';
import 'package:kursovoi/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:kursovoi/src/features/shell/presentation/screens/user_shell.dart';
import 'package:kursovoi/src/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:kursovoi/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:kursovoi/src/features/products/presentation/screens/product_detail_screen.dart';
import 'package:kursovoi/src/features/admin/presentation/screens/admin_products_screen.dart';
import 'package:kursovoi/src/features/admin/presentation/screens/edit_product_screen.dart';
import 'package:kursovoi/src/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:kursovoi/src/features/admin/presentation/screens/admin_report_screen.dart';


class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;
  final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell-${user?.uid}');

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    redirect: (context, state) {
      final loggedIn = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => null,
      );
      final isLoggingFlow = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isSplashScreen = state.matchedLocation == '/splash';

      if (loggedIn == null) {
        return isSplashScreen ? null : '/splash';
      }
      if (!loggedIn) {
        return isLoggingFlow ? null : '/login';
      }

      final role = ref.read(userRoleProvider).asData?.value;
      final isAdminPath = state.matchedLocation.startsWith('/admin');
      final isSharedDetailPath = state.matchedLocation.startsWith('/order/') || 
                                 state.matchedLocation.startsWith('/product/');

      if (role == 'admin' && (isLoggingFlow || isSplashScreen)) {
          return '/admin'; 
      }
      if (role == 'admin' && !isAdminPath && !isSharedDetailPath && !isLoggingFlow && !isSplashScreen) {
         return '/admin'; 
      }
      if (role != 'admin' && (isLoggingFlow || isSplashScreen)) {
         return '/';
      }
      if (role != 'admin' && isAdminPath) {
         return '/';
      }

      return null;
    },
    refreshListenable: GoRouterRefreshStream(ref.watch(authStateProvider.stream)),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Группа маршрутов админа
      GoRoute(
          path: '/admin',
          builder: (context, state) => const HomeScreen(),
          routes: [
             GoRoute(
               path: 'products', // -> /admin/products
               builder: (context, state) => const AdminProductsScreen(),
             ),
             GoRoute(
               path: 'add-product', // -> /admin/add-product
               builder: (context, state) => const AddProductScreen(),
             ),
             GoRoute(
                path: 'edit-product/:productId', // -> /admin/edit-product/xyz
                builder: (context, state) {
                   final productId = state.pathParameters['productId'];
                   if (productId == null) return const Scaffold(body: Center(child: Text('Missing product ID')));
                   return EditProductScreen(productId: productId);
                },
             ),
             GoRoute(
                path: 'orders', // -> /admin/orders
                builder: (context, state) => const AdminOrdersScreen(),
             ),
             GoRoute(
                path: 'report', // -> /admin/report
                builder: (context, state) => const AdminReportScreen(),
             ),
          ]
      ),

      GoRoute(
         path: '/checkout',
         builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
         path: '/order/:orderId', 
         builder: (context, state) {
            final orderId = state.pathParameters['orderId'];
            if (orderId == null) return const Scaffold(body: Center(child: Text('Missing order ID')));
            return OrderDetailScreen(orderId: orderId);
         },
      ),
       GoRoute(
         path: '/product/:productId',
         builder: (context, state) {
            final productId = state.pathParameters['productId'];
            if (productId == null) return const Scaffold(body: Center(child: Text('Missing product ID')));
            return ProductDetailScreen(productId: productId);
         },
      ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          // Отображаем Shell только если это не админ
          final role = ref.watch(userRoleProvider).asData?.value;
          if (role != 'admin') {
            return UserShell(child: child);
          }
          return child; 
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/cart',
             pageBuilder: (context, state) => const NoTransitionPage(child: CartScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Ошибка')),
      body: Center(child: Text('Страница не найдена: ${state.error}')),
    ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
} 