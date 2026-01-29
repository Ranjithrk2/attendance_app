import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';

class UserAttendanceHistoryScreen extends StatefulWidget {
  const UserAttendanceHistoryScreen({super.key});

  @override
  State<UserAttendanceHistoryScreen> createState() =>
      _UserAttendanceHistoryScreenState();
}

class _UserAttendanceHistoryScreenState
    extends State<UserAttendanceHistoryScreen> {
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  Future<void> loadAttendance() async {
    setState(() => isLoading = true);
    try {
      final data = await AttendanceService.getUserRecords();
      setState(() {
        records = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      setState(() => isLoading = false);
    }
  }

  String formatDuration(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null || checkOut == null) return '--';
    final diff = checkOut.difference(checkIn);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C), Color(0xFF2C2C2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with glowing title
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Colors.white70],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(Rect.fromLTWH(
                            0, 0, bounds.width, bounds.height)),
                        child: const Text(
                          'My Attendance History',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                  color: Colors.white24,
                                  blurRadius: 12,
                                  offset: Offset(0, 0))
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: loadAttendance,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                    : records.isEmpty
                    ? const Center(
                  child: Text(
                    'No attendance records',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                    : RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.black87,
                  onRefresh: loadAttendance,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final r = records[index];

                      // Safe timestamp handling
                      final checkIn = r['checkIn'] != null &&
                          r['checkIn'] is Timestamp
                          ? (r['checkIn'] as Timestamp).toDate()
                          : null;
                      final checkOut = r['checkOut'] != null &&
                          r['checkOut'] is Timestamp
                          ? (r['checkOut'] as Timestamp).toDate()
                          : null;

                      // Selfie images
                      ImageProvider? checkInImg;
                      ImageProvider? checkOutImg;
                      try {
                        if (r['checkInSelfieBase64'] != null) {
                          checkInImg = MemoryImage(
                              base64Decode(r['checkInSelfieBase64']));
                        }
                        if (r['checkOutSelfieBase64'] != null) {
                          checkOutImg = MemoryImage(
                              base64Decode(r['checkOutSelfieBase64']));
                        }
                      } catch (_) {}

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white10,
                              Colors.white12,
                              Colors.white24
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.white12,
                              blurRadius: 6,
                              spreadRadius: 2,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.center,
                              children: [
                                checkInImg != null
                                    ? CircleAvatar(
                                  radius: 28,
                                  backgroundImage: checkInImg,
                                  backgroundColor: Colors.white12,
                                )
                                    : const Icon(Icons.person,
                                    size: 50,
                                    color: Colors.white54),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Check-in: ${checkIn != null ? checkIn.toLocal() : '--'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        checkOut != null
                                            ? 'Check-out: ${checkOut.toLocal()}'
                                            : 'Still working',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (checkOutImg != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Checkout Selfie:',
                                      style: TextStyle(
                                          color: Colors.white70),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        child: Image(
                                          image: checkOutImg,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Duration: ${formatDuration(checkIn, checkOut)}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
