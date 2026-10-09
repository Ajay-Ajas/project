import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../complaint/my_complaints_page.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  static const String baseUrl = 'http://127.0.0.1:8000';

  String? selectedCategory;

  double severity = 5;
  double publicImpact = 5;
  double safetyRisk = 5;

  final TextEditingController descriptionController =
      TextEditingController();

  Uint8List? selectedImageBytes;
  String? selectedImageName;

  bool isDetecting = false;
  bool isSubmitting = false;
  bool isGettingLocation = false;

  String? detectedClass;
  double? detectedConfidence;
  String? detectionMessage;

  double? latitude;
  double? longitude;

  String locationText = 'Location not added';

  final List<String> categories = [
    'Road Damage',
    'Garbage',
    'Water Pollution',
    'Fallen Tree',
    'Street Light',
    'Water Supply',
    'Electricity',
    'Sanitation',
    'Environment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // =========================================================
  // PICK IMAGE
  // =========================================================

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;

    if (file.bytes == null) {
      _showMessage('Unable to read the selected image.');
      return;
    }

    setState(() {
      selectedImageBytes = file.bytes;
      selectedImageName = file.name;

      detectedClass = null;
      detectedConfidence = null;
      detectionMessage = null;
    });
  }

  // =========================================================
  // REMOVE IMAGE
  // =========================================================

  void _removeImage() {
    setState(() {
      selectedImageBytes = null;
      selectedImageName = null;

      detectedClass = null;
      detectedConfidence = null;
      detectionMessage = null;
    });
  }

  // =========================================================
  // GET LOCATION
  // =========================================================

  Future<void> _getCurrentLocation() async {
    setState(() {
      isGettingLocation = true;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Please enable location services.');
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission is required.');
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
          await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;

        locationText =
            '${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}';
      });

      _showMessage('Current location added.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to get current location.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  // =========================================================
  // YOLO DETECTION
  // =========================================================

  Future<void> _analyzeImage() async {
    if (selectedImageBytes == null) {
      _showMessage('Please add an image first.');
      return;
    }

    setState(() {
      isDetecting = true;
      detectedClass = null;
      detectedConfidence = null;
      detectionMessage = null;
    });

    try {
      final fileName =
          selectedImageName ?? 'image.jpg';

      final extension =
          fileName.split('.').last.toLowerCase();

      MediaType contentType;

      switch (extension) {
        case 'png':
          contentType =
              MediaType('image', 'png');
          break;

        case 'webp':
          contentType =
              MediaType('image', 'webp');
          break;

        case 'jpeg':
        case 'jpg':
        default:
          contentType =
              MediaType('image', 'jpeg');
          break;
      }

      final request =
          http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ai/detect'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          selectedImageBytes!,
          filename: fileName,
          contentType: contentType,
        ),
      );

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        final detections =
            data['detections'];

        if (detections is List &&
            detections.isNotEmpty) {
          final firstDetection =
              detections.first;

          final String aiClass =
              firstDetection['class']
                      ?.toString() ??
                  '';

          final dynamic confidenceValue =
              firstDetection['confidence'];

          final double confidence =
              confidenceValue is num
                  ? confidenceValue.toDouble()
                  : 0.0;

          final category =
              _convertAiClassToCategory(
            aiClass,
          );

          setState(() {
            detectedClass = aiClass;
            detectedConfidence =
                confidence;

            detectionMessage =
                'Ajas detected a possible civic issue.';

            if (category != null) {
              selectedCategory = category;
            }
          });

          _showMessage(
            'AI detected ${_formatAiClass(aiClass)}.',
          );
        } else {
          setState(() {
            detectionMessage =
                'Ajas could not identify a civic issue from this image.';
          });

          _showMessage(
            'No civic issue was detected.',
          );
        }
      } else {
        String message =
            'AI detection failed.';

        try {
          final data =
              jsonDecode(response.body);

          if (data['detail'] != null) {
            message =
                data['detail'].toString();
          }
        } catch (_) {}

        setState(() {
          detectionMessage = message;
        });

        _showMessage(message);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        detectionMessage =
            'Cannot connect to CivicMind AI server.';
      });

      _showMessage(
        'Cannot connect to CivicMind AI server.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isDetecting = false;
        });
      }
    }
  }

  // =========================================================
  // SUBMIT COMPLAINT
  // =========================================================

  Future<void> _submitComplaint() async {
    if (isSubmitting) return;

    final description =
        descriptionController.text.trim();

    if (selectedCategory == null) {
      _showMessage(
        'Please select an issue category.',
      );
      return;
    }

    if (description.isEmpty) {
      _showMessage(
        'Please describe the issue.',
      );
      return;
    }

    if (latitude == null ||
        longitude == null) {
      _showMessage(
        'Please add your current location.',
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final prefs =
          await SharedPreferences.getInstance();

      int? userId = prefs.getInt('user_id');

      userId ??= prefs.getInt('userId');

      if (userId == null) {
        _showMessage(
          'User session not found. Please login again.',
        );
        return;
      }

      final int loggedInUserId = userId;

      final request =
          http.MultipartRequest(
        'POST',
        Uri.parse(
          '$baseUrl/complaints/create',
        ),
      );

      request.fields['user_id'] =
          userId.toString();

      request.fields['category'] =
          _categoryToBackend(
        selectedCategory!,
      );

      request.fields['description'] =
          description;

      request.fields['latitude'] =
          latitude.toString();

      request.fields['longitude'] =
          longitude.toString();

      request.fields['severity_score'] =
          severity.round().toString();

      request.fields['public_impact'] =
          publicImpact.round().toString();

      request.fields['safety_risk'] =
          safetyRisk.round().toString();

      request.fields['repeat_reports'] =
          '0';

      request.fields['near_sensitive_area'] =
          'no';

      if (selectedImageBytes != null) {
        final fileName =
            selectedImageName ?? 'image.jpg';

        final extension =
            fileName.split('.').last.toLowerCase();

        MediaType contentType;

        switch (extension) {
          case 'png':
            contentType =
                MediaType('image', 'png');
            break;

          case 'webp':
            contentType =
                MediaType('image', 'webp');
            break;

          case 'jpeg':
          case 'jpg':
          default:
            contentType =
                MediaType('image', 'jpeg');
            break;
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            selectedImageBytes!,
            filename: fileName,
            contentType: contentType,
          ),
        );
      }

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        final complaint =
            data['complaint'];

        final complaintId =
            complaint?['id'];

        setState(() {
          isSubmitting = false;
        });

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text(
                'Complaint Submitted',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                complaintId != null
                    ? 'Your complaint #$complaintId has been submitted successfully and is awaiting review.'
                    : 'Your complaint has been submitted successfully and is awaiting review.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('View My Complaints'),
                ),
              ],
            );
          },
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MyComplaintsPage(
              userId: loggedInUserId,
            ),
          ),
        );
      } else {
        String message =
            'Complaint submission failed.';

        try {
          final data =
              jsonDecode(response.body);

          if (data['detail'] != null) {
            message =
                data['detail'].toString();
          }
        } catch (_) {}

        _showMessage(message);
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Cannot connect to CivicMind AI server.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // =========================================================
  // CATEGORY CONVERSION
  // =========================================================

  String _categoryToBackend(
    String category,
  ) {
    switch (category.toLowerCase()) {
      case 'road damage':
        return 'road_damage';

      case 'garbage':
        return 'garbage';

      case 'water pollution':
        return 'water_pollution';

      case 'fallen tree':
        return 'fallen_tree';

      case 'street light':
      case 'street lights':
        return 'street_lights';

      case 'water supply':
        return 'water_supply';

      case 'electricity':
        return 'electricity';

      case 'sanitation':
        return 'sanitation';

      case 'environment':
        return 'environment';

      default:
        return 'other';
    }
  }

  String? _convertAiClassToCategory(
    String aiClass,
  ) {
    switch (aiClass.toLowerCase()) {
      case 'road_damage':
        return 'Road Damage';

      case 'garbage':
        return 'Garbage';

      case 'water_pollution':
        return 'Water Pollution';

      case 'fallen_tree':
        return 'Fallen Tree';

      case 'street_lights':
      case 'street_light':
        return 'Street Light';

      default:
        return null;
    }
  }

  String _formatAiClass(String value) {
    switch (value.toLowerCase()) {
      case 'road_damage':
        return 'Road Damage';

      case 'garbage':
        return 'Garbage';

      case 'water_pollution':
        return 'Water Pollution';

      case 'fallen_tree':
        return 'Fallen Tree';

      case 'street_lights':
      case 'street_light':
        return 'Street Light';

      default:
        return value.replaceAll('_', ' ');
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF7F9FC),
        elevation: 0,
        surfaceTintColor:
            Colors.transparent,
        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Report an Issue',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Help improve your community',
              style: TextStyle(
                color: Color(0xFF7A8493),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 850,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // =====================================================
                  // EVIDENCE
                  // =====================================================

                  const Text(
                    'Evidence',
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
                    'Add a photo of the civic issue for AI analysis.',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFF6B7585),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    height: 230,
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFE5EAF1,
                        ),
                      ),
                    ),
                    child:
                        selectedImageBytes ==
                                null
                            ? InkWell(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                                onTap:
                                    _pickImage,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            const Color(
                                          0xFFEFF6FF,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          17,
                                        ),
                                      ),
                                      child:
                                          const Icon(
                                        Icons
                                            .add_a_photo_outlined,
                                        color:
                                            Color(
                                          0xFF155EEF,
                                        ),
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 14,
                                    ),
                                    const Text(
                                      'Add Photo',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        color:
                                            Color(
                                          0xFF172033,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    const Text(
                                      'JPG, PNG or WEBP',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            12,
                                        color:
                                            Color(
                                          0xFF7A8493,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      19,
                                    ),
                                    child:
                                        Image.memory(
                                      selectedImageBytes!,
                                      width:
                                          double.infinity,
                                      height:
                                          double.infinity,
                                      fit: BoxFit
                                          .cover,
                                    ),
                                  ),

                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child:
                                        Material(
                                      color: Colors
                                          .black
                                          .withOpacity(
                                        0.65,
                                      ),
                                      shape:
                                          const CircleBorder(),
                                      child:
                                          InkWell(
                                        customBorder:
                                            const CircleBorder(),
                                        onTap:
                                            _removeImage,
                                        child:
                                            const Padding(
                                          padding:
                                              EdgeInsets
                                                  .all(
                                            9,
                                          ),
                                          child:
                                              Icon(
                                            Icons
                                                .close_rounded,
                                            color: Colors
                                                .white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    bottom: 12,
                                    child:
                                        Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal:
                                            12,
                                        vertical: 9,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors
                                            .black
                                            .withOpacity(
                                          0.65,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons
                                                .image_outlined,
                                            color: Colors
                                                .white,
                                            size: 18,
                                          ),
                                          const SizedBox(
                                            width: 8,
                                          ),
                                          Expanded(
                                            child:
                                                Text(
                                              selectedImageName ??
                                                  'Selected image',
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                              style:
                                                  const TextStyle(
                                                color: Colors
                                                    .white,
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),

                  const SizedBox(height: 14),

                  if (selectedImageBytes != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            isDetecting
                                ? null
                                : _analyzeImage,
                        icon: isDetecting
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .auto_awesome_rounded,
                              ),
                        label: Text(
                          isDetecting
                              ? 'Ajas is analyzing...'
                              : 'Analyze with Ajas',
                        ),
                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              const Color(
                            0xFF0EA5A4,
                          ),
                          side:
                              const BorderSide(
                            color: Color(
                              0xFF0EA5A4,
                            ),
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

                  const SizedBox(height: 28),

                  // =====================================================
                  // AI DETECTION
                  // =====================================================

                  const Text(
                    'AI Detection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(18),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(0xFFEFFAF9),
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFD6F1EF,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              const Color(
                            0xFF0EA5A4,
                          ),
                          child: isDetecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .auto_awesome_rounded,
                                  color:
                                      Colors.white,
                                ),
                        ),

                        const SizedBox(
                          width: 14,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                _aiTitle(),
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  color:
                                      Color(
                                    0xFF172033,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                _aiDescription(),
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                  color:
                                      Color(
                                    0xFF5F6B7A,
                                  ),
                                ),
                              ),

                              if (detectedClass !=
                                      null &&
                                  detectedConfidence !=
                                      null) ...[
                                const SizedBox(
                                  height: 12,
                                ),

                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.white,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons
                                            .verified_outlined,
                                        size: 18,
                                        color:
                                            Color(
                                          0xFF0EA5A4,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Expanded(
                                        child:
                                            Text(
                                          '${_formatAiClass(detectedClass!)} detected',
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                13,
                                            fontWeight:
                                                FontWeight
                                                    .w700,
                                            color:
                                                Color(
                                              0xFF172033,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(detectedConfidence! * 100).toStringAsFixed(1)}%',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              13,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color:
                                              Color(
                                            0xFF0EA5A4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // CATEGORY
                  // =====================================================

                  const Text(
                    'Issue Category',
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
                    'Confirm the AI suggestion or select manually.',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFF6B7585),
                    ),
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Select issue category',
                      prefixIcon:
                          const Icon(
                        Icons
                            .category_outlined,
                        color:
                            Color(0xFF155EEF),
                      ),
                      filled: true,
                      fillColor:
                          Colors.white,
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color: Color(
                            0xFFE5EAF1,
                          ),
                        ),
                      ),
                    ),
                    items:
                        categories.map(
                      (category) {
                        return DropdownMenuItem(
                          value: category,
                          child:
                              Text(category),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory =
                            value;
                      });
                    },
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // DESCRIPTION
                  // =====================================================

                  const Text(
                    'Description',
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
                    'Describe what is happening and where it is located.',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFF6B7585),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller:
                        descriptionController,
                    maxLines: 5,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Example: Large pothole near the college entrance...',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor:
                          Colors.white,
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // LOCATION
                  // =====================================================

                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(17),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFE5EAF1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFEFF6FF,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .location_on_outlined,
                            color:
                                Color(0xFF155EEF),
                          ),
                        ),

                        const SizedBox(
                          width: 13,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                locationText,
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      Color(
                                    0xFF172033,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              const Text(
                                'Complaint location is required.',
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  color:
                                      Color(
                                    0xFF6B7585,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        TextButton(
                          onPressed:
                              isGettingLocation
                                  ? null
                                  : _getCurrentLocation,
                          child:
                              isGettingLocation
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                      ),
                                    )
                                  : const Text(
                                      'Update',
                                    ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // ASSESSMENT
                  // =====================================================

                  const Text(
                    'Issue Assessment',
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
                    'These details help the AI estimate complaint priority.',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFF6B7585),
                    ),
                  ),

                  const SizedBox(height: 18),

                  _RatingCard(
                    title: 'Severity',
                    icon: Icons
                        .warning_amber_rounded,
                    value: severity,
                    onChanged: (value) {
                      setState(() {
                        severity = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _RatingCard(
                    title: 'Public Impact',
                    icon: Icons
                        .groups_outlined,
                    value: publicImpact,
                    onChanged: (value) {
                      setState(() {
                        publicImpact = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _RatingCard(
                    title: 'Safety Risk',
                    icon: Icons
                        .health_and_safety_outlined,
                    value: safetyRisk,
                    onChanged: (value) {
                      setState(() {
                        safetyRisk = value;
                      });
                    },
                  ),

                  const SizedBox(height: 30),

                  // =====================================================
                  // SUBMIT
                  // =====================================================

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          isSubmitting
                              ? null
                              : _submitComplaint,
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF155EEF,
                        ),
                        foregroundColor:
                            Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                      child: isSubmitting
                          ? const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  width: 12,
                                ),
                                Text(
                                  'Submitting complaint...',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  Icons
                                      .send_rounded,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  'Submit Complaint',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Center(
                    child: Text(
                      'AI-assisted • Final review remains human-controlled',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF7A8493),
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

  // =========================================================
  // AI TITLE
  // =========================================================

  String _aiTitle() {
    if (isDetecting) {
      return 'Ajas is analyzing the image';
    }

    if (detectedClass != null) {
      return 'AI analysis completed';
    }

    if (detectionMessage != null) {
      return 'AI analysis result';
    }

    if (selectedImageBytes == null) {
      return 'Waiting for image';
    }

    return 'Image ready for AI analysis';
  }

  // =========================================================
  // AI DESCRIPTION
  // =========================================================

  String _aiDescription() {
    if (isDetecting) {
      return 'Connecting to CivicMind AI and running YOLO detection.';
    }

    if (detectedClass != null) {
      return 'Ajas identified a possible issue and suggested the category below.';
    }

    if (detectionMessage != null) {
      return detectionMessage!;
    }

    if (selectedImageBytes == null) {
      return 'Add an image and Ajas will analyze it.';
    }

    return 'Press "Analyze with Ajas" to detect the civic issue.';
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}

// =========================================================
// RATING CARD
// =========================================================

class _RatingCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _RatingCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        15,
        18,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5EAF1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                color:
                    const Color(0xFF155EEF),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF172033),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Text(
                  '${value.round()}/10',
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF155EEF),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor:
                const Color(0xFF155EEF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}