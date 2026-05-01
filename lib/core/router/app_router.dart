import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import 'app_navigation_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/scanner/presentation/pages/scanner_page.dart';
import '../../features/scanner/presentation/pages/product_review_page.dart';
import '../../features/products/presentation/pages/product_list_page.dart';
import '../../features/products/presentation/pages/product_detail_page.dart';
import '../../features/products/presentation/pages/product_form_page.dart';
import '../../features/batches/presentation/pages/batch_form_page.dart';
import '../../features/stock/presentation/pages/movement_page.dart';
import '../../features/stock/presentation/pages/adjustment_approvals_page.dart';
import '../../features/alerts/presentation/pages/alerts_page.dart';
import '../../features/audit/presentation/pages/audit_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/locations/presentation/pages/locations_page.dart';
import '../../features/settings/presentation/pages/users_management_page.dart';
import '../../features/settings/presentation/pages/categories_settings_page.dart';
import '../../features/settings/presentation/pages/alerts_settings_page.dart';
import '../../features/ml/presentation/pages/ml_insights_page.dart';
import '../../features/recipes/presentation/pages/recipes_page.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const scanner = '/scanner';
  static const productReview = '/scanner/review';
  static const productList = '/products';
  static const productDetail = '/products/:id';
  static const productForm = '/products/form';
  static const batchForm = '/batches/form';
  static const movement = '/movement';
  static const adjustmentApprovals = '/movement/approvals';
  static const alerts = '/alerts';
  static const audit = '/audit';
  static const reports = '/reports';
  static const settings = '/settings';
  static const locations = '/locations';
  static const usersManagement = '/settings/users';
  static const categoriesSettings = '/settings/categories';
  static const alertsSettings = '/settings/alerts';
  static const mlInsights = '/ml/insights';
  static const recipes = '/recipes';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      if (auth.isLoading) return null;

      final isLoggedIn = auth.valueOrNull != null;
      final isPublicRoute = {
        AppRoutes.login,
        AppRoutes.register,
      }.contains(state.matchedLocation);

      if (!isLoggedIn && !isPublicRoute) return AppRoutes.login;
      if (isLoggedIn && isPublicRoute) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppNavigationShell(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.scanner,
            builder: (_, __) => const ScannerPage(),
          ),
          GoRoute(
            path: AppRoutes.productReview,
            builder: (_, state) {
              final barcode = state.uri.queryParameters['barcode'] ?? '';
              return ProductReviewPage(barcode: barcode);
            },
          ),
          GoRoute(
            path: AppRoutes.productList,
            builder: (_, __) => const ProductListPage(),
          ),
          GoRoute(
            path: AppRoutes.productDetail,
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '';
              return ProductDetailPage(productId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.productForm,
            builder: (_, state) {
              final productId = state.uri.queryParameters['id'];
              final barcode = state.uri.queryParameters['barcode'];
              final prefillName = state.uri.queryParameters['name'];
              final prefillBrand = state.uri.queryParameters['brand'];
              final prefillCategory = state.uri.queryParameters['category'];
              return ProductFormPage(
                productId: productId,
                barcode: barcode,
                prefillName: prefillName,
                prefillBrand: prefillBrand,
                prefillCategory: prefillCategory,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.batchForm,
            builder: (_, state) {
              final productId = state.uri.queryParameters['productId'] ?? '';
              return BatchFormPage(productId: productId);
            },
          ),
          GoRoute(
            path: AppRoutes.movement,
            builder: (_, state) {
              final batchId = state.uri.queryParameters['batchId'] ?? '';
              return MovementPage(batchId: batchId);
            },
          ),
          GoRoute(
            path: AppRoutes.adjustmentApprovals,
            builder: (_, __) => const AdjustmentApprovalsPage(),
          ),
          GoRoute(
            path: AppRoutes.alerts,
            builder: (_, __) => const AlertsPage(),
          ),
          GoRoute(
            path: AppRoutes.audit,
            builder: (_, __) => const AuditPage(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (_, __) => const ReportsPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.locations,
            builder: (_, __) => const LocationsPage(),
          ),
          GoRoute(
            path: AppRoutes.usersManagement,
            builder: (_, __) => const UsersManagementPage(),
          ),
          GoRoute(
            path: AppRoutes.categoriesSettings,
            builder: (_, __) => const CategoriesSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.alertsSettings,
            builder: (_, __) => const AlertsSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.mlInsights,
            builder: (_, __) => const MlInsightsPage(),
          ),
          GoRoute(
            path: AppRoutes.recipes,
            builder: (_, __) => const RecipesPage(),
          ),
        ],
      ),
    ],
  );
});
