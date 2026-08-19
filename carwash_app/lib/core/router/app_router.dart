import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/catalog/screens/catalog_screen.dart';
import '../../features/catalog/screens/register_vehicle_type_screen.dart';
import '../../features/catalog/screens/register_wash_service_screen.dart';
import '../../features/expenses/screens/create_expense_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/operator/screens/operator_home_screen.dart';
import '../../features/payroll/models/advance_model.dart';
import '../../features/payroll/models/employee_model.dart';
import '../../features/payroll/screens/advance_detail_screen.dart';
import '../../features/payroll/screens/advances_screen.dart';
import '../../features/payroll/screens/edit_salary_screen.dart';
import '../../features/payroll/screens/employee_detail_screen.dart';
import '../../features/payroll/screens/employees_screen.dart';
import '../../features/payroll/screens/payroll_pay_screen.dart';
import '../../features/payroll/screens/register_advance_screen.dart';
import '../../features/payroll/screens/register_employee_screen.dart';
import '../../features/washes/models/vehicle_type.dart';
import '../../features/washes/screens/register_wash_screen.dart';

class AppRouter {
  AppRouter._();

  static const login = '/login';
  static const home = '/home';
  static const operatorHome = '/operator-home';
  static const registerWash = '/register-wash';
  static const createExpense = '/create-expense';
  static const employees = '/employees';
  static const registerEmployee = '/employees/register';
  static String employeeDetail(int id) => '/employees/$id';
  static const editSalary = '/employees/edit-salary';
  static const advances = '/advances';
  static const registerAdvance = '/advances/register';
  static String advanceDetail(int id) => '/advances/$id';
  static const payrollPay = '/payroll/pay';
  static const catalog = '/catalog';
  static const registerVehicleType = '/catalog/vehicle-types/register';
  static const registerWashService = '/catalog/wash-services/register';

  static GoRouter routerWith(AuthProvider authProvider) => GoRouter(
    initialLocation: login,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final isLoginRoute = state.matchedLocation == login;
      final user = authProvider.user;
      final isOperator = user?.isOperator ?? false;
      if (!isAuth && !isLoginRoute) return login;
      if (isAuth && isLoginRoute) return isOperator ? operatorHome : home;
      if (isAuth && isOperator) {
        final isAllowedOperatorRoute =
            state.matchedLocation == operatorHome ||
            state.matchedLocation == registerWash;
        if (!isAllowedOperatorRoute) return operatorHome;
      }
      if (isAuth && !isOperator && state.matchedLocation == operatorHome) {
        return home;
      }
      return null;
    },
    routes: [
      GoRoute(path: login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: operatorHome,
        builder: (_, _) => const OperatorHomeScreen(),
      ),
      GoRoute(
        path: registerWash,
        builder: (_, _) => const RegisterWashScreen(),
      ),
      GoRoute(
        path: createExpense,
        builder: (_, _) => const CreateExpenseScreen(),
      ),
      GoRoute(path: payrollPay, builder: (_, _) => const PayrollPayScreen()),
      // Nómina — rutas jerárquicas
      GoRoute(
        path: employees,
        builder: (_, _) => const EmployeesScreen(),
        routes: [
          GoRoute(
            path: 'register',
            builder: (_, _) => const RegisterEmployeeScreen(),
          ),
          GoRoute(
            path: 'edit-salary',
            builder: (_, state) =>
                EditSalaryScreen(employee: state.extra as Employee),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                EmployeeDetailScreen(employee: state.extra as Employee),
          ),
        ],
      ),
      GoRoute(
        path: advances,
        builder: (_, _) => const AdvancesScreen(),
        routes: [
          GoRoute(
            path: 'register',
            builder: (_, state) {
              final extra = state.extra;
              if (extra is Map) {
                return RegisterAdvanceScreen(
                  employee: extra['employee'] as Employee?,
                  existingAdvance: extra['existingAdvance'] as Advance?,
                );
              }
              return RegisterAdvanceScreen(employee: extra as Employee?);
            },
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) {
              final id = int.parse(state.pathParameters['id']!);
              final extra = state.extra;
              return AdvanceDetailScreen(
                advanceId: id,
                initialAdvance: extra is Advance ? extra : null,
              );
            },
          ),
        ],
      ),
      // Catálogo — rutas jerárquicas (solo admin, ver redirect arriba)
      GoRoute(
        path: catalog,
        builder: (_, _) => const CatalogScreen(),
        routes: [
          GoRoute(
            path: 'vehicle-types/register',
            builder: (_, _) => const RegisterVehicleTypeScreen(),
          ),
          GoRoute(
            path: 'wash-services/register',
            builder: (_, state) => RegisterWashServiceScreen(
              vehicleType: state.extra as VehicleType?,
            ),
          ),
        ],
      ),
    ],
  );
}
