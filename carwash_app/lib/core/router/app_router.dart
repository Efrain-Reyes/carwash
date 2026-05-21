import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/expenses/screens/create_expense_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/operator/screens/operator_home_screen.dart';
import '../../features/payroll/models/advance_model.dart';
import '../../features/payroll/models/employee_model.dart';
import '../../features/payroll/screens/advance_detail_screen.dart';
import '../../features/payroll/screens/advances_screen.dart';
import '../../features/payroll/screens/employee_detail_screen.dart';
import '../../features/payroll/screens/employees_screen.dart';
import '../../features/payroll/screens/payroll_pay_screen.dart';
import '../../features/payroll/screens/register_advance_screen.dart';
import '../../features/payroll/screens/register_employee_screen.dart';
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
  static const advances = '/advances';
  static const registerAdvance = '/advances/register';
  static String advanceDetail(int id) => '/advances/$id';
  static const payrollPay = '/payroll/pay';

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
            builder: (_, state) =>
                RegisterAdvanceScreen(employee: state.extra as Employee?),
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
    ],
  );
}
