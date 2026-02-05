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
  List<Map<String, dynamic>> allRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];

  bool isLoading = true;

  DateTime? selectedDate;
  String userFilter = '';

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
        allRecords = data;
        applyFilters();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading records: $e');
      setState(() => isLoading = false);
    }
  }

  // ---------------- SAFETY HELPERS ----------------

  DateTime? _safeTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  ImageProvider? _safeBase64Image(dynamic data) {
    if (data == null || data is! String || data.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(data));
    } catch (_) {
      return null;
    }
  }

  // ---------------- FILTER LOGIC ----------------

  void applyFilters() {
    filteredRecords = allRecords.where((r) {
      final checkIn = _safeTimestamp(r['checkIn']);

      // Date filter
      if (selectedDate != null && checkIn != null) {
        final sameDay =
            checkIn.year == selectedDate!.year &&
                checkIn.month == selectedDate!.month &&
                checkIn.day == selectedDate!.day;
        if (!sameDay) return false;
      }

      // User filter
      if (userFilter.isNotEmpty) {
        final user = (r['displayUserId'] ?? '').toString().toLowerCase();
        if (!user.contains(userFilter.toLowerCase())) return false;
      }

      return true;
    }).toList();

    setState(() {});
  }

  // ---------------- TOTAL HOURS ----------------

  String getTotalWorkingTime() {
    Duration total = Duration.zero;

    for (final r in filteredRecords) {
      final checkIn = _safeTimestamp(r['checkIn']);
      final checkOut = _safeTimestamp(r['checkOut']);
      if (checkIn != null && checkOut != null) {
        total += checkOut.difference(checkIn);
      }
    }

    return '${total.inHours}h ${total.inMinutes % 60}m';
  }

  String formatDuration(DateTime? inTime, DateTime? outTime) {
    if (inTime == null || outTime == null) return '--';
    final diff = outTime.difference(inTime);
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Attendance History'),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : Column(
        children: [
          _filterBar(),
          _totalHoursCard(),
          Expanded(child: _recordsList()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) {
                userFilter = v;
                applyFilters();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Filter by User ID',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                selectedDate = date;
                applyFilters();
              }
            },
          ),
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () {
                selectedDate = null;
                applyFilters();
              },
            )
        ],
      ),
    );
  }

  Widget _totalHoursCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Working Time',
            style: TextStyle(color: Colors.white70),
          ),
          Text(
            getTotalWorkingTime(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordsList() {
    if (filteredRecords.isEmpty) {
      return const Center(
        child: Text('No records found',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final r = filteredRecords[index];

        final checkIn = _safeTimestamp(r['checkIn']);
        final checkOut = _safeTimestamp(r['checkOut']);

        final checkInImg = _safeBase64Image(r['checkInSelfieBase64']);
        final checkOutImg = _safeBase64Image(r['checkOutSelfieBase64']);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (r['displayUserId'] ?? '--').toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _infoRow('Check-in', checkIn?.toLocal().toString() ?? '--'),
              _infoRow(
                  'Check-out', checkOut?.toLocal().toString() ?? 'Working'),
              const SizedBox(height: 8),
              if (checkInImg != null)
                _imageRow('Check-in Selfie', checkInImg),
              if (checkOutImg != null)
                _imageRow('Check-out Selfie', checkOutImg),
              const SizedBox(height: 6),
              Text(
                'Duration: ${formatDuration(checkIn, checkOut)}',
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Text(
      '$label: $value',
      style: const TextStyle(color: Colors.white70),
    );
  }

  Widget _imageRow(String label, ImageProvider image) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style:
              const TextStyle(color: Colors.white60, fontSize: 13)),
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