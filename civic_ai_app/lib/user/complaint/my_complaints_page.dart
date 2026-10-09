import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyComplaintsPage extends StatefulWidget {
  final int userId;

  const MyComplaintsPage({
    super.key,
    required this.userId,
  });

  @override
  State<MyComplaintsPage> createState() => _MyComplaintsPageState();
}

class _MyComplaintsPageState extends State<MyComplaintsPage> {
  static const String baseUrl = 'http://127.0.0.1:8000';

  bool isLoading = true;
  String? errorMessage;

  List<dynamic> complaints = [];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  // ============================================================
  // LOAD USER COMPLAINTS
  // ============================================================

  Future<void> _loadComplaints() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/user/${widget.userId}'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> loadedComplaints = [];

        if (decoded is Map<String, dynamic>) {
          loadedComplaints =
              List<dynamic>.from(decoded['complaints'] ?? []);
        } else if (decoded is List) {
          loadedComplaints = List<dynamic>.from(decoded);
        }

        setState(() {
          complaints = loadedComplaints;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Unable to load your complaints.\n'
              'Server returned ${response.statusCode}.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage =
            'Cannot connect to CivicMind AI server.\n'
            'Make sure the FastAPI server is running.';
        isLoading = false;
      });
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

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

  // ============================================================
  // PROGRESS
  // ============================================================

  int _progressForStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'submitted':
        return 25;

      case 'pending review':
        return 50;

      case 'in progress':
        return 75;

      case 'resolved':
        return 100;

      default:
        return 25;
    }
  }

  // ============================================================
  // CATEGORY ICON
  // ============================================================

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'garbage':
        return Icons.delete_outline_rounded;

      case 'road damage':
      case 'road_damage':
        return Icons.route_outlined;

      case 'water pollution':
      case 'water_pollution':
      case 'water supply':
      case 'water_supply':
        return Icons.water_drop_outlined;

      case 'fallen tree':
      case 'fallen_tree':
        return Icons.park_outlined;

      case 'street light':
      case 'street lights':
      case 'street_lights':
      case 'electricity':
        return Icons.lightbulb_outline_rounded;

      case 'sanitation':
        return Icons.cleaning_services_outlined;

      case 'environment':
        return Icons.eco_outlined;

      default:
        return Icons.report_problem_outlined;
    }
  }

  // ============================================================
  // DISPLAY CATEGORY
  // ============================================================

  String _displayCategory(String category) {
    switch (category.toLowerCase().trim()) {
      case 'road_damage':
        return 'Road Damage';

      case 'water_pollution':
        return 'Water Pollution';

      case 'water_supply':
        return 'Water Supply';

      case 'fallen_tree':
        return 'Fallen Tree';

      case 'street_lights':
        return 'Street Lights';

      case 'garbage':
        return 'Garbage';

      case 'electricity':
        return 'Electricity';

      case 'sanitation':
        return 'Sanitation';

      case 'environment':
        return 'Environment';

      case 'other':
        return 'Other';

      default:
        if (category.isEmpty) {
          return 'Other';
        }

        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date unavailable';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return 'Date unavailable';
    }
  }

  // ============================================================
  // AI CONFIDENCE
  // ============================================================

  String _formatConfidence(dynamic confidence) {
    if (confidence == null) {
      return 'Not available';
    }

    final value = double.tryParse(
      confidence.toString(),
    );

    if (value == null) {
      return 'Not available';
    }

    return '${(value * 100).toStringAsFixed(1)}%';
  }

  // ============================================================
  // STATUS PROGRESS
  // ============================================================

  Widget _buildStatusProgress(String status) {
    const statuses = [
      'Submitted',
      'Pending Review',
      'In Progress',
      'Resolved',
    ];

    int currentIndex = statuses.indexWhere(
      (item) =>
          item.toLowerCase() ==
          status.toLowerCase().trim(),
    );

    if (currentIndex < 0) {
      currentIndex = 0;
    }

    final color = _statusColor(status);
    final progress = _progressForStatus(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Complaint Progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF697586),
              ),
            ),
            const Spacer(),
            Text(
              '$progress%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5EAF1),
            valueColor:
                AlwaysStoppedAnimation<Color>(color),
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: List.generate(
            statuses.length,
            (index) {
              final completed = index <= currentIndex;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed
                            ? color
                            : const Color(0xFFD9E0EA),
                      ),
                    ),

                    if (index < statuses.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentIndex
                              ? color
                              : const Color(0xFFD9E0EA),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 7),

        Row(
          children: statuses.map((item) {
            return Expanded(
              child: Text(
                item,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF697586),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

  Widget _infoRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF155EEF),
        ),

        const SizedBox(width: 9),

        SizedBox(
          width: 105,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7A8493),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF172033),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPLAINT CARD
  // ============================================================

  Widget _buildComplaintCard(dynamic complaint) {
    final rawCategory =
        complaint['category']?.toString() ?? 'other';

    final category = _displayCategory(rawCategory);

    final description =
        complaint['description']?.toString() ??
            'No description available';

    final status =
        complaint['status']?.toString() ??
            'Submitted';

    final priority =
        complaint['priority']?.toString() ??
            'MEDIUM';

    final department =
        complaint['department']?.toString() ??
            'Administrative Review';

    final aiClass =
        complaint['ai_detected_class']?.toString() ??
            'Not detected';

    final confidence =
        complaint['ai_confidence'];

    final latestUpdate =
        complaint['latest_update']?.toString() ??
            'No update available.';

    final complaintId =
        complaint['id']?.toString() ?? '-';

    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5EAF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(rawCategory),
                  color: const Color(0xFF155EEF),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Complaint #$complaintId',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A8493),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ======================================================
          // DESCRIPTION
          // ======================================================

          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4B5565),
            ),
          ),

          const SizedBox(height: 20),

          // ======================================================
          // PROGRESS
          // ======================================================

          _buildStatusProgress(status),

          const SizedBox(height: 20),

          // ======================================================
          // DETAILS
          // ======================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _infoRow(
                  'Priority',
                  priority,
                  Icons.flag_outlined,
                ),

                const SizedBox(height: 11),

                _infoRow(
                  'Department',
                  department,
                  Icons.account_balance_outlined,
                ),

                const SizedBox(height: 11),

                _infoRow(
                  'AI Detection',
                  aiClass,
                  Icons.auto_awesome_outlined,
                ),

                const SizedBox(height: 11),

                _infoRow(
                  'AI Confidence',
                  _formatConfidence(confidence),
                  Icons.analytics_outlined,
                ),

                const SizedBox(height: 11),

                _infoRow(
                  'Submitted',
                  _formatDate(
                    complaint['created_at']?.toString(),
                  ),
                  Icons.calendar_today_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ======================================================
          // LATEST UPDATE
          // ======================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: statusColor,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Latest Update',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF697586),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        latestUpdate,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF5F6B7A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN BODY
  // ============================================================

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF155EEF),
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 50,
                    color: Color(0xFF7A8493),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5F6B7A),
                    ),
                  ),

                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: _loadComplaints,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ----------------------------------------------------------
    // NO COMPLAINTS
    // ----------------------------------------------------------

    if (complaints.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 58,
                    color: Color(0xFF9AA5B5),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'No complaints yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Your submitted complaints will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A8493),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ----------------------------------------------------------
    // COMPLAINT LIST
    // ----------------------------------------------------------

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      children: [
        // --------------------------------------------------------
        // SUMMARY
        // --------------------------------------------------------

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5EAF1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Color(0xFF155EEF),
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${complaints.length} Complaint${complaints.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 3),

                  const Text(
                    'Your civic issues and their progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A8493),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --------------------------------------------------------
        // ALL COMPLAINTS
        // --------------------------------------------------------

        ...complaints.map(
          (complaint) =>
              _buildComplaintCard(complaint),
        ),
      ],
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'My Complaints',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            Text(
              'Track your civic issues and progress',
              style: TextStyle(
                color: Color(0xFF7A8493),
                fontSize: 12,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh complaints',
            onPressed: _loadComplaints,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadComplaints,
          color: const Color(0xFF155EEF),
          child: _buildBody(),
        ),
      ),
    );
  }
}