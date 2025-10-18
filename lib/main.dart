import 'package:app_lecturas_jmas/configs/services/auth_service.dart';
import 'package:app_lecturas_jmas/screens/common/home_screen.dart';
import 'package:app_lecturas_jmas/screens/common/login2.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.ensureInitialized();

  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  runApp(MainApp(isLoggedIn: isLoggedIn));
}

class MainApp extends StatelessWidget {
  final bool isLoggedIn;
  const MainApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lecturas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const HomeScreen() : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
