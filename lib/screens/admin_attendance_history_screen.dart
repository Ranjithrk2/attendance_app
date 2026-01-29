import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';

class AdminAttendanceHistoryScreen extends StatefulWidget {
  const AdminAttendanceHistoryScreen({super.key});

  @override
  State<AdminAttendanceHistoryScreen> createState() =>
      _AdminAttendanceHistoryScreenState();
}

class _AdminAttendanceHistoryScreenState
    extends State<AdminAttendanceHistoryScreen> {
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    setState(() => isLoading = true);
    try {
      final data = await AttendanceService.getAllRecords();
      setState(() {
        records = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading records: $e');
      setState(() => isLoading = false);
    }
  }

  String formatDuration(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null || checkOut == null) return '--';
    final diff = checkOut.difference(checkIn);
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: true, // ✅ BACK ARROW
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Attendance History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF000000),
              Color(0xFF0A0A0A),
              Color(0xFF121212),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : records.isEmpty
            ? const Center(
          child: Text(
            'No attendance records',
            style: TextStyle(color: Colors.white54),
          ),
        )
            : RefreshIndicator(
          color: Colors.white,
          backgroundColor: Colors.black,
          onRefresh: loadRecords,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];

              final checkIn = r['checkIn'] is Timestamp
                  ? (r['checkIn'] as Timestamp).toDate()
                  : null;
              final checkOut = r['checkOut'] is Timestamp
                  ? (r['checkOut'] as Timestamp).toDate()
                  : null;

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
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['displayUserId'] ?? '--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                        'Check-in',
                        checkIn != null
                            ? checkIn.toLocal().toString()
                            : '--'),
                    _infoRow(
                        'Check-out',
                        checkOut != null
                            ? checkOut.toLocal().toString()
                            : 'Still working'),
                    const SizedBox(height: 8),
                    if (checkInImg != null)
                      _imageRow('Check-in Selfie', checkInImg),
                    if (checkOutImg != null)
                      _imageRow('Check-out Selfie', checkOutImg),
                    const SizedBox(height: 8),
                    Text(
                      'Duration: ${formatDuration(checkIn, checkOut)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _imageRow(String label, ImageProvider image) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: image,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
