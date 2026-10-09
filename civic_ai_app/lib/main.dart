import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'intro/splash_page.dart';
import 'user/home/user_home_page.dart';
import 'admin/admin_dashboard_page.dart';

void main() {
  runApp(const CivicMindApp());
}

class CivicMindApp extends StatelessWidget {
  const CivicMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CivicMind AI',
      home: const AppStartupPage(),
    );
  }
}

class AppStartupPage extends StatefulWidget {
  const AppStartupPage({super.key});

  @override
  State<AppStartupPage> createState() =>
      _AppStartupPageState();
}

class _AppStartupPageState
    extends State<AppStartupPage> {

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs =
        await SharedPreferences.getInstance();

    final isLoggedIn =
        prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;

    if (isLoggedIn) {
      final role =
          prefs.getString('role');

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AdminDashboardPage(),
          ),
        );
      } else if (role == 'citizen') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const UserHomePage(),
          ),
        );
      } else {
        await prefs.clear();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const SplashPage(),
          ),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const SplashPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F9FC),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}