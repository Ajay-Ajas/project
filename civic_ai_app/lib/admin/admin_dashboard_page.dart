import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const String baseUrl = 'http://127.0.0.1:8000';

  bool _loading = true;
  bool _updating = false;

  String _adminUsername = '';
  List<dynamic> _complaints = [];

  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  // ============================================================
  // LOAD ADMIN SESSION
  // ============================================================

  Future<void> _loadAdmin() async {
    final prefs = await SharedPreferences.getInstance();

    final username =
        prefs.getString('admin_username') ??
        prefs.getString('username') ??
        '';

    setState(() {
      _adminUsername = username;
    });

    await _loadComplaints();
  }

  // ============================================================
  // LOAD ALL COMPLAINTS
  // ============================================================

  Future<void> _loadComplaints() async {
    setState(() {
      _loading = true;
    });

    try {
      if (_adminUsername.isEmpty) {
        throw Exception('Admin session not found');
      }

      final uri = Uri.parse(
        '$baseUrl/admin/complaints',
      ).replace(
        queryParameters: {
          'admin_username': _adminUsername,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map && data['complaints'] is List) {
          setState(() {
            _complaints = data['complaints'];
          });
        } else if (data is List) {
          setState(() {
            _complaints = data;
          });
        } else {
          setState(() {
            _complaints = [];
          });
        }
      } else if (response.statusCode == 403) {
        _showMessage(
          'Administrator access required.',
        );
      } else {
        _showMessage(
          'Unable to load complaints.',
        );
      }
    } catch (e) {
      _showMessage(
        'Cannot connect to CivicMind AI server.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // UPDATE COMPLAINT
  // ============================================================

  Future<void> _updateComplaint({
    required int complaintId,
    required String status,
    required String assignedAdmin,
    required String department,
    required String adminAction,
    required String latestUpdate,
  }) async {
    if (_adminUsername.isEmpty) {
      _showMessage('Admin session not found.');
      return;
    }

    setState(() {
      _updating = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
          '$baseUrl/admin/complaints/$complaintId',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'admin_username': _adminUsername,
          'status': status,
          'assigned_admin': assignedAdmin,
          'department': department,
          'admin_action': adminAction,
          'latest_update': latestUpdate,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage(
          'Complaint #$complaintId updated successfully.',
        );

        await _loadComplaints();
      } else if (response.statusCode == 403) {
        _showMessage(
          'Administrator access required.',
        );
      } else {
        String message = 'Failed to update complaint.';

        try {
          final data = jsonDecode(response.body);

          if (data is Map && data['detail'] != null) {
            message = data['detail'].toString();
          }
        } catch (_) {}

        _showMessage(message);
      }
    } catch (e) {
      _showMessage(
        'Cannot connect to CivicMind AI server.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('admin_username');
    await prefs.remove('username');
    await prefs.remove('role');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // COUNTERS
  // ============================================================

  int _countStatus(String status) {
    return _complaints.where((complaint) {
      return complaint['status']
              ?.toString()
              .toLowerCase() ==
          status.toLowerCase();
    }).length;
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    final total = _complaints.length;
    final submitted = _countStatus('Submitted');
    final pending = _countStatus('Pending Review');
    final progress = _countStatus('In Progress');
    final resolved = _countStatus('Resolved');
    final rejected = _countStatus('Rejected');

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildStatistics(
            total: total,
            submitted: submitted,
            pending: pending,
            progress: progress,
            resolved: resolved,
            rejected: rejected,
          ),

          const SizedBox(height: 26),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Citizen Complaints',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadComplaints,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_complaints.isEmpty)
            _buildEmptyState()
          else
            ..._complaints.map(
              (complaint) {
                return _buildComplaintCard(
                  complaint,
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF155EEF),
            Color(0xFF0B4ACB),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'CivicMind AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Administrator • $_adminUsername',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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
  // STATISTICS
  // ============================================================

  Widget _buildStatistics({
    required int total,
    required int submitted,
    required int pending,
    required int progress,
    required int resolved,
    required int rejected,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Total',
                total,
                Icons.list_alt_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Submitted',
                submitted,
                Icons.inbox_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _statCard(
                'Pending',
                pending,
                Icons.pending_actions_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'In Progress',
                progress,
                Icons.sync_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _statCard(
                'Resolved',
                resolved,
                Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Rejected',
                rejected,
                Icons.cancel_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    int value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF155EEF),
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF697586),
                    fontWeight: FontWeight.w600,
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
  // COMPLAINT CARD
  // ============================================================

  Widget _buildComplaintCard(
    dynamic complaint,
  ) {
    final id = _intValue(
      complaint['id'],
    );

    final category =
        complaint['category']?.toString() ??
            'Other';

    final description =
        complaint['description']?.toString() ??
            'No description';

    final username =
        complaint['username']?.toString() ??
            'Unknown citizen';

    final userName =
        complaint['user_name']?.toString() ??
            complaint['name']?.toString() ??
            username;

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
        _doubleValue(
      complaint['ai_confidence'],
    );

    final latitude =
        complaint['latitude']?.toString() ??
            '-';

    final longitude =
        complaint['longitude']?.toString() ??
            '-';

    final latestUpdate =
        complaint['latest_update']?.toString() ??
            'No update available.';

    final assignedAdmin =
        complaint['assigned_admin']?.toString() ??
            '';

    final statusColor =
        _statusColor(status);

    final priorityColor =
        _priorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
                  _categoryIcon(category),
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
                      _displayCategory(category),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Complaint #$id',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A8493),
                      ),
                    ),
                  ],
                ),
              ),

              _badge(
                status,
                statusColor,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CITIZEN
          _sectionTitle(
            'Citizen',
            Icons.person_outline_rounded,
          ),

          const SizedBox(height: 8),

          _infoRow(
            'Name',
            userName,
          ),

          const SizedBox(height: 6),

          _infoRow(
            'Username',
            username,
          ),

          const SizedBox(height: 18),

          // COMPLAINT
          _sectionTitle(
            'Complaint',
            Icons.description_outlined,
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4B5565),
            ),
          ),

          const SizedBox(height: 18),

          // AI ANALYSIS
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE5EAF1),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  'AI Analysis',
                  Icons.auto_awesome_rounded,
                ),

                const SizedBox(height: 12),

                _infoRow(
                  'AI Detection',
                  aiClass,
                ),

                const SizedBox(height: 7),

                _infoRow(
                  'AI Confidence',
                  confidence == null
                      ? 'Not available'
                      : '${(confidence * 100).toStringAsFixed(1)}%',
                ),

                const SizedBox(height: 7),

                Row(
                  children: [
                    const Icon(
                      Icons.priority_high_rounded,
                      size: 17,
                      color: Color(0xFF155EEF),
                    ),
                    const SizedBox(width: 9),
                    const SizedBox(
                      width: 105,
                      child: Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A8493),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _badge(
                      priority,
                      priorityColor,
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                _infoRow(
                  'Department',
                  department,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // LOCATION
          _sectionTitle(
            'Location',
            Icons.location_on_outlined,
          ),

          const SizedBox(height: 8),

          _infoRow(
            'Latitude',
            latitude,
          ),

          const SizedBox(height: 6),

          _infoRow(
            'Longitude',
            longitude,
          ),

          const SizedBox(height: 18),

          // CURRENT ADMIN DATA
          _sectionTitle(
            'Administrative Status',
            Icons.manage_accounts_outlined,
          ),

          const SizedBox(height: 8),

          _infoRow(
            'Assigned Admin',
            assignedAdmin.isEmpty
                ? 'Not assigned'
                : assignedAdmin,
          ),

          const SizedBox(height: 6),

          _infoRow(
            'Latest Update',
            latestUpdate,
          ),

          const SizedBox(height: 20),

          // UPDATE BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _updating
                  ? null
                  : () {
                      _showUpdateDialog(
                        complaintId: id,
                        currentStatus: status,
                        currentAdmin:
                            assignedAdmin,
                        currentDepartment:
                            department,
                        currentUpdate:
                            latestUpdate,
                      );
                    },
              icon: const Icon(
                Icons.edit_note_rounded,
              ),
              label: const Text(
                'Manage Complaint',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF155EEF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UPDATE DIALOG
  // ============================================================

  void _showUpdateDialog({
    required int complaintId,
    required String currentStatus,
    required String currentAdmin,
    required String currentDepartment,
    required String currentUpdate,
  }) {
    String selectedStatus = currentStatus;

    final adminController =
        TextEditingController(
      text: currentAdmin,
    );

    final departmentController =
        TextEditingController(
      text: currentDepartment,
    );

    final updateController =
        TextEditingController(
      text: currentUpdate,
    );

    final actionController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                'Manage Complaint #$complaintId',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    DropdownButtonFormField<String>(
                      initialValue:
                          _validStatus(
                        selectedStatus,
                      ),
                      decoration:
                          const InputDecoration(
                        border:
                            OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Submitted',
                          child: Text(
                            'Submitted',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Pending Review',
                          child: Text(
                            'Pending Review',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'In Progress',
                          child: Text(
                            'In Progress',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Resolved',
                          child: Text(
                            'Resolved',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Rejected',
                          child: Text(
                            'Rejected',
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus =
                                value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Assigned Admin',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    TextField(
                      controller:
                          adminController,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Admin username',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Department',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    TextField(
                      controller:
                          departmentController,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Department',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Admin Action',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    TextField(
                      controller:
                          actionController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Example: Complaint verified and assigned for field inspection.',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Latest Update',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    TextField(
                      controller:
                          updateController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Message visible to citizen',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),

                if (selectedStatus !=
                    'Rejected')
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(
                        dialogContext,
                      );

                      await _updateComplaint(
                        complaintId:
                            complaintId,
                        status:
                            selectedStatus,
                        assignedAdmin:
                            adminController
                                .text
                                .trim(),
                        department:
                            departmentController
                                .text
                                .trim(),
                        adminAction:
                            actionController
                                .text
                                .trim(),
                        latestUpdate:
                            updateController
                                .text
                                .trim(),
                      );
                    },
                    child: const Text(
                      'Update',
                    ),
                  ),

                if (selectedStatus ==
                    'Rejected')
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFFDC2626,
                      ),
                      foregroundColor:
                          Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(
                        dialogContext,
                      );

                      await _updateComplaint(
                        complaintId:
                            complaintId,
                        status: 'Rejected',
                        assignedAdmin:
                            adminController
                                .text
                                .trim(),
                        department:
                            departmentController
                                .text
                                .trim(),
                        adminAction:
                            actionController
                                .text
                                .trim()
                                .isEmpty
                            ? 'Complaint rejected by administrator.'
                            : actionController
                                .text
                                .trim(),
                        latestUpdate:
                            updateController
                                .text
                                .trim()
                                .isEmpty
                            ? 'Complaint was rejected after administrative review.'
                            : updateController
                                .text
                                .trim(),
                      );
                    },
                    child: const Text(
                      'Reject Complaint',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ADMIN PROFILE
  // ============================================================

  Widget _buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 15),

        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBBD4FF),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 48,
              color: Color(0xFF155EEF),
            ),
          ),
        ),

        const SizedBox(height: 18),

        const Center(
          child: Text(
            'Administrator',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ),

        const SizedBox(height: 6),

        Center(
          child: Text(
            _adminUsername.isEmpty
                ? 'Administrator account'
                : '@$_adminUsername',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF697586),
            ),
          ),
        ),

        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5EAF1),
            ),
          ),
          child: Column(
            children: [
              _profileRow(
                Icons.person_outline_rounded,
                'Username',
                _adminUsername.isEmpty
                    ? 'Not available'
                    : _adminUsername,
              ),

              const Divider(
                height: 28,
              ),

              _profileRow(
                Icons.verified_user_outlined,
                'Role',
                'Administrator',
              ),

              const Divider(
                height: 28,
              ),

              _profileRow(
                Icons.security_outlined,
                'Access',
                'Complaint Management',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFDC2626),
            ),
            label: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 15,
              ),
              side: const BorderSide(
                color: Color(0xFFFCA5A5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF155EEF),
          size: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A8493),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5EAF1),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 55,
            color: Color(0xFF9AA4B2),
          ),
          SizedBox(height: 14),
          Text(
            'No complaints available',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Citizen complaints will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF697586),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildNavigation() {
    return NavigationBar(
      selectedIndex: _selectedNav,
      onDestinationSelected: (index) {
        setState(() {
          _selectedNav = index;
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(
            Icons.dashboard_outlined,
          ),
          selectedIcon: Icon(
            Icons.dashboard_rounded,
          ),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.person_outline_rounded,
          ),
          selectedIcon: Icon(
            Icons.person_rounded,
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF7F9FC),
        elevation: 0,
        title: const Text(
          'Admin Console',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),

      body: _selectedNav == 0
          ? _buildDashboard()
          : _buildProfile(),

      bottomNavigationBar:
          _buildNavigation(),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF155EEF),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
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

  Widget _badge(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _displayCategory(
    String category,
  ) {
    switch (category.toLowerCase()) {
      case 'road_damage':
        return 'Road Damage';
      case 'garbage':
        return 'Garbage';
      case 'water_pollution':
        return 'Water Pollution';
      case 'fallen_tree':
        return 'Fallen Tree';
      case 'street_lights':
        return 'Street Lights';
      case 'water_supply':
        return 'Water Supply';
      case 'electricity':
        return 'Electricity';
      case 'sanitation':
        return 'Sanitation';
      case 'environment':
        return 'Environment';
      default:
        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  IconData _categoryIcon(
    String category,
  ) {
    switch (category.toLowerCase()) {
      case 'road_damage':
        return Icons.construction_rounded;
      case 'garbage':
      case 'sanitation':
        return Icons.delete_outline_rounded;
      case 'water_pollution':
      case 'water_supply':
        return Icons.water_drop_outlined;
      case 'fallen_tree':
      case 'environment':
        return Icons.park_outlined;
      case 'street_lights':
      case 'electricity':
        return Icons.lightbulb_outline_rounded;
      default:
        return Icons.report_problem_outlined;
    }
  }

  Color _statusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF15803D);
      case 'in progress':
        return const Color(0xFF2563EB);
      case 'pending review':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _priorityColor(
    String priority,
  ) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFDC2626);
      case 'MEDIUM':
        return const Color(0xFFD97706);
      case 'LOW':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _validStatus(
    String status,
  ) {
    const values = [
      'Submitted',
      'Pending Review',
      'In Progress',
      'Resolved',
      'Rejected',
    ];

    if (values.contains(status)) {
      return status;
    }

    return 'Submitted';
  }

  int _intValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  double? _doubleValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}