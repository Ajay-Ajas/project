import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() =>
      _CommunityFeedPageState();
}

class _CommunityFeedPageState
    extends State<CommunityFeedPage> {
  static const String baseUrl =
      'http://127.0.0.1:8000';

  bool isLoading = true;
  String? errorMessage;

  List<dynamic> complaints = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  // ============================================================
  // LOAD PUBLIC COMMUNITY FEED
  // ============================================================

  Future<void> _loadFeed() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/feed'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> loadedComplaints = [];

        if (data is Map<String, dynamic>) {
          final items = data['complaints'];

          if (items is List) {
            loadedComplaints =
                List<dynamic>.from(items);
          }
        } else if (data is List) {
          loadedComplaints =
              List<dynamic>.from(data);
        }

        setState(() {
          complaints = loadedComplaints;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Unable to load the community feed.\n'
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
  // CATEGORY ICON
  // ============================================================

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'garbage':
        return Icons.delete_outline_rounded;

      case 'road_damage':
      case 'road damage':
        return Icons.route_outlined;

      case 'water_pollution':
      case 'water pollution':
      case 'water_supply':
      case 'water supply':
        return Icons.water_drop_outlined;

      case 'fallen_tree':
      case 'fallen tree':
        return Icons.park_outlined;

      case 'street_lights':
      case 'street lights':
      case 'street light':
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
  // CATEGORY DISPLAY
  // ============================================================

  String _displayCategory(String category) {
    switch (category.toLowerCase().trim()) {
      case 'road_damage':
        return 'Road Damage';

      case 'garbage':
        return 'Garbage';

      case 'water_pollution':
        return 'Water Pollution';

      case 'water_supply':
        return 'Water Supply';

      case 'fallen_tree':
        return 'Fallen Tree';

      case 'street_lights':
        return 'Street Lights';

      case 'electricity':
        return 'Electricity';

      case 'sanitation':
        return 'Sanitation';

      case 'environment':
        return 'Environment';

      case 'other':
        return 'Other';

      default:
        if (category.trim().isEmpty) {
          return 'Other';
        }

        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}'
                    '${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(dynamic value) {
    if (value == null ||
        value.toString().isEmpty) {
      return 'Date unavailable';
    }

    try {
      final date =
          DateTime.parse(value.toString()).toLocal();

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

  String _formatConfidence(dynamic value) {
    if (value == null) {
      return '';
    }

    final confidence =
        double.tryParse(value.toString());

    if (confidence == null) {
      return '';
    }

    return '${(confidence * 100).toStringAsFixed(1)}%';
  }

  // ============================================================
  // COMPLAINT CARD
  // ============================================================

  Widget _buildComplaintCard(
    dynamic complaint,
  ) {
    final rawCategory =
        complaint['category']?.toString() ??
            'other';

    final category =
        _displayCategory(rawCategory);

    final description =
        complaint['description']?.toString() ??
            'No description available.';

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
            '';

    final aiConfidence =
        _formatConfidence(
      complaint['ai_confidence'],
    );

    final complaintId =
        complaint['id']?.toString() ?? '-';

    final statusColor =
        _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5EAF1),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // HEADER
          // ------------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(rawCategory),
                  color:
                      const Color(0xFF155EEF),
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
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Complaint #$complaintId',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF7A8493),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        statusColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // DESCRIPTION
          // ------------------------------------------------------

          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4B5565),
            ),
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // INFORMATION
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFF7F9FC),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.flag_outlined,
                  'Priority',
                  priority,
                ),

                const SizedBox(height: 10),

                _infoRow(
                  Icons.account_balance_outlined,
                  'Department',
                  department,
                ),

                if (aiClass.isNotEmpty) ...[
                  const SizedBox(height: 10),

                  _infoRow(
                    Icons.auto_awesome_outlined,
                    'AI Detection',
                    aiClass,
                  ),
                ],

                if (aiConfidence.isNotEmpty) ...[
                  const SizedBox(height: 10),

                  _infoRow(
                    Icons.analytics_outlined,
                    'AI Confidence',
                    aiConfidence,
                  ),
                ],

                const SizedBox(height: 10),

                _infoRow(
                  Icons.calendar_today_outlined,
                  'Submitted',
                  _formatDate(
                    complaint['created_at'],
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
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF155EEF),
        ),

        const SizedBox(width: 9),

        SizedBox(
          width: 90,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7A8493),
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF172033),
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF155EEF),
        ),
      );
    }

    if (errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),

          Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 55,
                    color:
                        Color(0xFF7A8493),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    errorMessage!,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFF5F6B7A),
                    ),
                  ),

                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: _loadFeed,
                    child:
                        const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (complaints.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),

          Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Icon(
                    Icons.public_outlined,
                    size: 60,
                    color:
                        Color(0xFF9AA5B5),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'No community complaints yet',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Civic issues submitted by citizens will appear here.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Color(0xFF7A8493),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      children: [
        // --------------------------------------------------------
        // HEADER SUMMARY
        // --------------------------------------------------------

        Container(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(16),
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
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color:
                      Color(0xFF155EEF),
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${complaints.length} Community Complaint${complaints.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 3),

                  const Text(
                    'Civic issues reported by citizens',
                    style:
                        TextStyle(
                      fontSize: 11,
                      color:
                          Color(0xFF7A8493),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --------------------------------------------------------
        // COMPLAINTS
        // --------------------------------------------------------

        ...complaints.map(
          (complaint) =>
              _buildComplaintCard(
            complaint,
          ),
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
      backgroundColor:
          const Color(0xFFF7F9FC),

      body: SafeArea(
        child: Column(
          children: [
            // ----------------------------------------------------
            // FEED APP BAR
            // ----------------------------------------------------

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                16,
                12,
                8,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Feed',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xFF172033),
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          'See what is happening in your community',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Color(0xFF7A8493),
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadFeed,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color:
                          Color(0xFF172033),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFeed,
                color:
                    const Color(0xFF155EEF),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}