import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  bool locationLoading = false;

  double? latitude;
  double? longitude;

  String locationText = 'Location is required';

  static const String baseUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() {
      locationLoading = true;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          'Please enable location services.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage(
          'Location permission was denied.',
        );
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is permanently denied.',
        );
        return;
      }

      final position =
          await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;

        locationText =
            'Location captured successfully';
      });

      _showMessage(
        'Current location captured.',
      );
    } catch (e) {
      _showMessage(
        'Unable to get your current location.',
      );
    } finally {
      if (mounted) {
        setState(() {
          locationLoading = false;
        });
      }
    }
  }

  Future<void> _createAccount() async {
    final name = nameController.text.trim();
    final ageText = ageController.text.trim();
    final username =
        usernameController.text.trim();
    final password =
        passwordController.text.trim();

    if (name.isEmpty ||
        ageText.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      _showMessage(
        'Please complete all required fields.',
      );
      return;
    }

    final age = int.tryParse(ageText);

    if (age == null || age < 1) {
      _showMessage(
        'Please enter a valid age.',
      );
      return;
    }

    if (password.length < 4) {
      _showMessage(
        'Password must contain at least 4 characters.',
      );
      return;
    }

    if (latitude == null || longitude == null) {
      _showMessage(
        'Please provide your current location.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'age': age,
          'username': username,
          'password': password,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully. Please sign in.',
            ),
          ),
        );

        await Future.delayed(
          const Duration(milliseconds: 800),
        );

        if (!mounted) return;

        Navigator.pop(context);
      } else {
        _showMessage(
          data['detail'] ??
              'Unable to create account.',
        );
      }
    } catch (e) {
      _showMessage(
        'Cannot connect to CivicMind AI server.',
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Create Account',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Join CivicMind AI',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Create your citizen account to report and track civic issues.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color:
                          Color(0xFF667085),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Full Name',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller:
                        nameController,
                    decoration:
                        _inputDecoration(
                      hint:
                          'Enter your name',
                      icon:
                          Icons.person_outline,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Age',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller:
                        ageController,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        _inputDecoration(
                      hint:
                          'Enter your age',
                      icon:
                          Icons.cake_outlined,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Username',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller:
                        usernameController,
                    decoration:
                        _inputDecoration(
                      hint:
                          'Choose a username',
                      icon:
                          Icons.account_circle_outlined,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Password',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller:
                        passwordController,
                    obscureText:
                        obscurePassword,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Create a password',
                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon:
                          IconButton(
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
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Current Location',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(0xFF344054),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      border: Border.all(
                        color:
                            const Color(
                          0xFFE4E7EC,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .location_on_outlined,
                          color: latitude !=
                                  null
                              ? const Color(
                                  0xFF157347,
                                )
                              : const Color(
                                  0xFF155EEF,
                                ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Text(
                            locationText,
                            style: TextStyle(
                              color: latitude !=
                                      null
                                  ? const Color(
                                      0xFF157347,
                                    )
                                  : const Color(
                                      0xFF667085,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 48,
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          locationLoading
                              ? null
                              : _getLocation,
                      icon: locationLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .my_location_outlined,
                            ),
                      label: Text(
                        locationLoading
                            ? 'Getting Location...'
                            : 'Use Current Location',
                      ),
                      style:
                          OutlinedButton
                              .styleFrom(
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed:
                          isLoading
                              ? null
                              : _createAccount,
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF155EEF,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Center(
                    child: Text(
                      'Your location is used to support civic complaint reporting.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF667085),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}