import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = '';
  String username = '';
  String role = '';
  String location = '';
  int? age;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs =
        await SharedPreferences.getInstance();

    final latitude = prefs.getDouble('latitude');
    final longitude = prefs.getDouble('longitude');

    if (!mounted) return;

    setState(() {
      name = prefs.getString('userName') ?? '';
      username =
          prefs.getString('userUsername') ?? '';
      role = prefs.getString('role') ?? 'citizen';
      age = prefs.getInt('userAge');

      if (latitude != null && longitude != null) {
        location =
            '${latitude.toStringAsFixed(5)}, '
            '${longitude.toStringAsFixed(5)}';
      } else {
        location = 'Location unavailable';
      }
    });
  }

  Future<void> _logout() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 600,
              ),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFF155EEF),
                      borderRadius:
                          BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    name.isEmpty
                        ? 'Citizen'
                        : name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w700,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    username.isEmpty
                        ? ''
                        : '@$username',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF667085),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            const Color(0xFFE4E7EC),
                      ),
                    ),
                    child: Column(
                      children: [
                        _ProfileRow(
                          icon:
                              Icons.person_outline,
                          title: 'Name',
                          value: name.isEmpty
                              ? 'Not available'
                              : name,
                        ),
                        const Divider(height: 28),
                        _ProfileRow(
                          icon:
                              Icons.account_circle_outlined,
                          title: 'Username',
                          value: username.isEmpty
                              ? 'Not available'
                              : username,
                        ),
                        const Divider(height: 28),
                        _ProfileRow(
                          icon:
                              Icons.cake_outlined,
                          title: 'Age',
                          value: age?.toString() ??
                              'Not available',
                        ),
                        const Divider(height: 28),
                        _ProfileRow(
                          icon:
                              Icons.location_on_outlined,
                          title: 'Current Location',
                          value: location,
                        ),
                        const Divider(height: 28),
                        _ProfileRow(
                          icon:
                              Icons.badge_outlined,
                          title: 'Account Type',
                          value:
                              role == 'admin'
                                  ? 'Administrator'
                                  : 'Citizen',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed:
                          _confirmLogout,
                      icon: const Icon(
                        Icons.logout_outlined,
                      ),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFFD92D20),
                        side: const BorderSide(
                          color: Color(0xFFF0B8B3),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
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
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF155EEF),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w600,
                  color: Color(0xFF172033),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}