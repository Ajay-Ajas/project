import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'register_page.dart';
import '../user/home/user_home_page.dart';
import '../admin/admin_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  bool isAdminLogin = false;

  static const String baseUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Please enter username and password');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final role = data['role'];

        if (isAdminLogin && role != 'admin') {
          _showMessage(
            'This account is not an admin account',
          );
          return;
        }

        if (!isAdminLogin && role != 'citizen') {
          _showMessage(
            'Please use Citizen Login for a citizen account',
          );
          return;
        }

        final prefs =
            await SharedPreferences.getInstance();

        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', role);
        await prefs.setString('username', username);

        if (role == 'admin') {
          await prefs.setString(
            'adminUsername',
            data['username'] ?? username,
          );

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AdminDashboardPage(),
            ),
          );
        } else {
          final user = data['user'];

          await prefs.setInt(
            'userId',
            user['id'],
          );

          await prefs.setString(
            'userName',
            user['name'] ?? '',
          );

          await prefs.setString(
            'userUsername',
            user['username'] ?? username,
          );

          await prefs.setDouble(
            'latitude',
            (user['latitude'] as num).toDouble(),
          );

          await prefs.setDouble(
            'longitude',
            (user['longitude'] as num).toDouble(),
          );

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserHomePage(),
            ),
          );
        }
      } else {
        _showMessage(
          data['detail'] ??
              'Invalid username or password',
        );
      }
    } catch (e) {
      _showMessage(
        'Cannot connect to CivicMind AI server',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF155EEF),
                      borderRadius:
                          BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Sign in to continue to CivicMind AI.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF667085),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EEF7),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _loginTypeButton(
                            title: 'Citizen',
                            selected: !isAdminLogin,
                            onTap: () {
                              setState(() {
                                isAdminLogin = false;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _loginTypeButton(
                            title: 'Admin',
                            selected: isAdminLogin,
                            onTap: () {
                              setState(() {
                                isAdminLogin = true;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  Text(
                    isAdminLogin
                        ? 'Administrator Login'
                        : 'Citizen Login',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Username',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: usernameController,
                    textInputAction:
                        TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Enter your username',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Password',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword =
                                !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed:
                          isLoading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF155EEF),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isAdminLogin
                                  ? 'Admin Sign In'
                                  : 'Sign In',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  if (!isAdminLogin) ...[
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Color(0xFF667085),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Create account',
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 26),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F6FF),
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.security_outlined,
                          color: Color(0xFF155EEF),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAdminLogin
                                ? 'Authorized administrators can manage civic complaints and updates.'
                                : 'Ajas helps keep your civic concerns organized and connected to CivicMind AI.',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginTypeButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(0.06),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF155EEF)
                  : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }
}