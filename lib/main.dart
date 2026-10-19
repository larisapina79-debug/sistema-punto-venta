import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/app_header.dart';
import 'screens/auth/login_screen.dart';
import 'screens/users/users_screen.dart';
import 'services/auth_service.dart';
import 'screens/cash_closures/start_cash_register_screen.dart';
import 'screens/branches/branch_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
    await AuthService().restore();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Punto de Venta',
      debugShowCheckedModeBanner: false,
      initialRoute: Session.user == null ? '/login' : '/login',
    routes: {
        for (final item in navItems)
          item.route: (_) =>
              PlaceholderScreen(title: item.label, route: item.route),
        '/login': (_) => const LoginScreen(),
        '/usuarios': (_) => const UsersScreen(),
        '/sucursales': (_) => const BranchesScreen(),
        '/start-cash-register': (_) => const StartCashRegisterScreen(),
      },
    );
  }
}


class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String route;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(currentRoute: route),
      drawer: AppDrawer(currentRoute: route),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 12),
            const Text(
              'Firebase conectado correctamente',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
