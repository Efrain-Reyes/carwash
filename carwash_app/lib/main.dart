import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/providers/home_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: CarwashApp(router: AppRouter.routerWith(authProvider)),
    ),
  );
}

class CarwashApp extends StatelessWidget {
  const CarwashApp({super.key, required this.router});

  final dynamic router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Carwash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
