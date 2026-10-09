import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../feed/community_feed_page.dart';
import '../report/report_issue_page.dart';
import '../profile/profile_page.dart';
import '../complaint/my_complaints_page.dart';
import '../ajas/ajas_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const String baseUrl = 'http://127.0.0.1:8000';

  int _currentIndex = 0;

  int? _userId;

  bool _isLoadingComplaints = true;

  List<dynamic> _complaints = [];

  final List<String> _titles = [
    'Home',
    'Community',
    'Report Issue',
    'My Complaints',
    'Ajas',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAndComplaints();
  }

  // ======================================================
  // LOAD USER ID + COMPLAINTS
  // ======================================================

  Future<void> _loadUserAndComplaints() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      int? userId = prefs.getInt('user_id');

      userId ??= prefs.getInt('userId');

      if (userId == null) {
        if (!mounted) return;

        setState(() {
          _userId = null;
          _isLoadingComplaints = false;
        });

        return;
      }

      _userId = userId;

      await _loadComplaints();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingComplaints = false;
      });
    }
  }

  // ======================================================
  // LOAD COMPLAINTS FROM FASTAPI
  // ======================================================

  Future<void> _loadComplaints() async {
    if (_userId == null) {
      await _loadUserAndComplaints();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingComplaints = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/complaints/user/$_userId',
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _complaints = List<dynamic>.from(
            data['complaints'] ?? [],
          );

          _isLoadingComplaints = false;
        });
      } else {
        setState(() {
          _complaints = [];
          _isLoadingComplaints = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _complaints = [];
        _isLoadingComplaints = false;
      });
    }
  }

  // ======================================================
  // COUNTS
  // ======================================================

  int get _totalReports {
    return _complaints.length;
  }

  int get _inProgressCount {
    return _complaints.where((complaint) {
      final status =
          complaint['status']?.toString().toLowerCase().trim();

      return status == 'in progress';
    }).length;
  }

  int get _resolvedCount {
    return _complaints.where((complaint) {
      final status =
          complaint['status']?.toString().toLowerCase().trim();

      return status == 'resolved';
    }).length;
  }

  // ======================================================
  // PAGE
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CivicMind AI',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                color: Color(0xFF7A8493),
                fontSize: 12,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: () {
              _loadComplaints();
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF172033),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePage(),
                  ),
                );
              },
              child: const CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFFEAF2FF),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFF155EEF),
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),

      body: _buildCurrentPage(),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,

        onDestinationSelected: (index) async {
          setState(() {
            _currentIndex = index;
          });

          if (index == 0 || index == 3) {
            await _loadComplaints();
          }
        },

        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE6F0FF),

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public_rounded),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'My Issues',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: 'Ajas',
          ),
        ],
      ),
    );
  }

  // ======================================================
  // PAGE SWITCHING
  // ======================================================

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
  return const CommunityFeedPage();

      case 2:
        return const ReportIssuePage();

      case 3:
        if (_userId == null) {
          return _placeholderPage(
            Icons.assignment_rounded,
            'My Complaints',
            'Please login again to view your complaints.',
          );
        }

        return MyComplaintsPage(
          userId: _userId!,
        );

      case 4:
  return const AjasPage();

      default:
        return _homeContent();
    }
  }

  // ======================================================
  // HOME
  // ======================================================

  Widget _homeContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;

        return RefreshIndicator(
          onRefresh: _loadComplaints,

          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),

            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 20,
              vertical: 20,
            ),

            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1200,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Good morning',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w500,
                        color: Color(0xFF6B7585),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'How can we help your community today?',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Report civic issues, track complaints and stay connected with your community.',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Color(0xFF6B7585),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==================================================
                    // MAIN REPORT CARD
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(26),

                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors: [
                            Color(0xFF155EEF),
                            Color(0xFF174EA6),
                          ],
                        ),

                        borderRadius:
                            BorderRadius.circular(24),

                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(
                              0xFF155EEF,
                            ).withOpacity(0.18),
                            blurRadius: 25,
                            offset:
                                const Offset(0, 12),
                          ),
                        ],
                      ),

                      child: isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child:
                                      _heroContent(),
                                ),
                                const SizedBox(
                                  width: 30,
                                ),
                                _heroIcon(),
                              ],
                            )
                          : Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _heroIcon(),
                                const SizedBox(
                                  height: 20,
                                ),
                                _heroContent(),
                              ],
                            ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Your Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // REAL COUNTERS
                    // ==================================================

                    Wrap(
                      spacing: 14,
                      runSpacing: 14,

                      children: [
                        _OverviewCard(
                          icon:
                              Icons.assignment_outlined,
                          title:
                              _isLoadingComplaints
                                  ? '...'
                                  : '$_totalReports',
                          subtitle:
                              'Total Reports',
                        ),

                        _OverviewCard(
                          icon:
                              Icons.pending_actions_rounded,
                          title:
                              _isLoadingComplaints
                                  ? '...'
                                  : '$_inProgressCount',
                          subtitle:
                              'In Progress',
                        ),

                        _OverviewCard(
                          icon:
                              Icons.check_circle_outline_rounded,
                          title:
                              _isLoadingComplaints
                                  ? '...'
                                  : '$_resolvedCount',
                          subtitle:
                              'Resolved',
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Quick Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Select an issue category to start a report.',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Color(0xFF6B7585),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 14,
                      runSpacing: 14,

                      children: [
                        _IssueCard(
                          icon:
                              Icons.construction_rounded,
                          title: 'Road Damage',
                          onTap: () {
                            setState(() {
                              _currentIndex = 2;
                            });
                          },
                        ),

                        _IssueCard(
                          icon:
                              Icons.delete_outline_rounded,
                          title: 'Garbage',
                          onTap: () {
                            setState(() {
                              _currentIndex = 2;
                            });
                          },
                        ),

                        _IssueCard(
                          icon:
                              Icons.water_drop_outlined,
                          title: 'Water Pollution',
                          onTap: () {
                            setState(() {
                              _currentIndex = 2;
                            });
                          },
                        ),

                        _IssueCard(
                          icon:
                              Icons.park_outlined,
                          title: 'Fallen Tree',
                          onTap: () {
                            setState(() {
                              _currentIndex = 2;
                            });
                          },
                        ),

                        _IssueCard(
                          icon:
                              Icons.lightbulb_outline_rounded,
                          title: 'Street Light',
                          onTap: () {
                            setState(() {
                              _currentIndex = 2;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildRecentActivity(),

                    const SizedBox(height: 22),

                    // ==================================================
                    // AJAS
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFEFFAF9),
                        borderRadius:
                            BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFFD6F1EF),
                        ),
                      ),

                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 27,
                            backgroundColor:
                                Color(0xFF0EA5A4),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),

                          const SizedBox(width: 15),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need assistance?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Color(0xFF5F6B7A),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Ask Ajas',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        Color(0xFF172033),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              setState(() {
                                _currentIndex = 4;
                              });
                            },
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              color:
                                  Color(0xFF0EA5A4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ======================================================
  // RECENT ACTIVITY
  // ======================================================

  Widget _buildRecentActivity() {
    if (_isLoadingComplaints) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5EAF1),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF155EEF),
          ),
        ),
      );
    }

    if (_complaints.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5EAF1),
          ),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  Color(0xFFEFF6FF),
              child: Icon(
                Icons.assignment_outlined,
                color: Color(0xFF155EEF),
              ),
            ),

            SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'No recent activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Your complaint activity will appear here.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Color(0xFF6B7585),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final recent =
        _complaints.take(3).toList();

    return Column(
      children: recent.map((complaint) {
        final category =
            complaint['category']?.toString() ??
                'Other';

        final status =
            complaint['status']?.toString() ??
                'Submitted';

        final description =
            complaint['description']?.toString() ??
                'Complaint submitted';

        final statusColor =
            _statusColor(status);

        return Container(
          width: double.infinity,
          margin:
              const EdgeInsets.only(bottom: 10),

          padding:
              const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  const Color(0xFFE5EAF1),
            ),
          ),

          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color:
                      Color(0xFF155EEF),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style:
                                const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  Color(0xFF172033),
                            ),
                          ),
                        ),

                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color: statusColor
                                .withOpacity(
                              0.10,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      description,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color:
                            Color(0xFF6B7585),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ======================================================
  // STATUS COLOR
  // ======================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'submitted':
        return const Color(0xFF155EEF);

      case 'pending review':
        return const Color(0xFFF59E0B);

      case 'in progress':
        return const Color(0xFF0EA5A4);

      case 'resolved':
        return const Color(0xFF16A34A);

      default:
        return const Color(0xFF64748B);
    }
  }

  // ======================================================
  // HERO CONTENT
  // ======================================================

  Widget _heroContent() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        const Icon(
          Icons.campaign_rounded,
          color: Colors.white,
          size: 34,
        ),

        const SizedBox(height: 16),

        const Text(
          'See something that needs attention?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Report a civic issue and let Ajas guide you through the process.',
          style: TextStyle(
            color: Color(0xFFDCE8FF),
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 46,

          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentIndex = 2;
              });
            },

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.white,
              foregroundColor:
                  const Color(0xFF155EEF),
              elevation: 0,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),

            child: const Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                Text(
                  'Report an Issue',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                SizedBox(width: 8),

                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ======================================================
  // HERO ICON
  // ======================================================

  Widget _heroIcon() {
    return Container(
      width: 86,
      height: 86,

      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color:
              Colors.white.withOpacity(0.18),
        ),
      ),

      child: const Icon(
        Icons.location_city_rounded,
        color: Colors.white,
        size: 42,
      ),
    );
  }

  // ======================================================
  // PLACEHOLDER
  // ======================================================

  Widget _placeholderPage(
    IconData icon,
    String title,
    String description,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 65,
              color:
                  const Color(0xFF155EEF),
            ),

            const SizedBox(height: 20),

            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.w800,
                color:
                    Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color:
                    Color(0xFF6B7585),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================
// OVERVIEW CARD
// ========================================================

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5EAF1),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color:
                  const Color(0xFFEFF6FF),
              borderRadius:
                  BorderRadius.circular(13),
            ),

            child: Icon(
              icon,
              color:
                  const Color(0xFF155EEF),
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color:
                      Color(0xFF6B7585),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================================
// ISSUE CARD
// ========================================================

class _IssueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _IssueCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(18),

      onTap: onTap,

      child: Container(
        width: 190,
        height: 105,

        padding:
            const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color:
                const Color(0xFFE5EAF1),
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,

              decoration: BoxDecoration(
                color:
                    const Color(0xFFEFF6FF),
                borderRadius:
                    BorderRadius.circular(13),
              ),

              child: Icon(
                icon,
                color:
                    const Color(0xFF155EEF),
                size: 23,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF172033),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}