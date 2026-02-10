import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminAttendanceHistoryScreen extends StatefulWidget {
  const AdminAttendanceHistoryScreen({super.key});

  @override
  State<AdminAttendanceHistoryScreen> createState() =>
      _AdminAttendanceHistoryScreenState();
}

class _AdminAttendanceHistoryScreenState
    extends State<AdminAttendanceHistoryScreen> {
  List<Map<String, dynamic>> records = [];
  bool isLoading = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _selectedDay = DateTime.now();
    loadRecordsByDate(_selectedDay!);
  }

  // ---------------- REQUEST LOCATION PERMISSION ----------------
  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Location permission is required for check-ins")));
    }
  }

  // ---------------- FIRESTORE LOAD (DAY-WISE) ----------------
  Future<void> loadRecordsByDate(DateTime date) async {
    setState(() {
      isLoading = true;
      records.clear();
    });

    try {
      // Handle start and end of the day in local timezone
      final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('checkIn',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('checkIn', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('checkIn', descending: true)
          .get();

      setState(() {
        records = snapshot.docs.map((d) => d.data()).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      setState(() => isLoading = false);
    }
  }

  // ---------------- HELPERS ----------------
  DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

  ImageProvider? _img(dynamic b64) {
    if (b64 == null || b64 is! String || b64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  String totalWorkingTime() {
    Duration total = Duration.zero;
    for (final r in records) {
      final i = _ts(r['checkIn']);
      final o = _ts(r['checkOut']);
      if (i != null && o != null) {
        total += o.difference(i);
      }
    }
    return '${total.inHours}h ${total.inMinutes % 60}m';
  }

  String duration(DateTime? i, DateTime? o) {
    if (i == null || o == null) return '--';
    final d = o.difference(i);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  // ---------------- LOCATION UI ----------------
  Widget _locationBlock(String title, Map<String, dynamic>? loc) {
    if (loc == null) return const SizedBox();
    final lat = loc['lat'];
    final lng = loc['lng'];
    final acc = loc['accuracy'];
    final ts = _ts(loc['timestamp']);
    if (lat == null || lng == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Lat: $lat, Lng: $lng',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text('Accuracy: ${acc ?? '--'} m',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          if (ts != null)
            Text('At: ${ts.toLocal()}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          TextButton(
            onPressed: () async {
              final url =
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
              if (await canLaunchUrl(Uri.parse(url))) {
                launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'View on Map',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Attendance Calendar'),
      ),
      body: Column(
        children: [
          _calendar(),
          if (_selectedDay != null) _totalCard(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  // ---------------- CALENDAR ----------------
  Widget _calendar() {
    return TableCalendar(
      firstDay: DateTime(2023),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
      calendarStyle: const CalendarStyle(
        defaultTextStyle: TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: Colors.white70),
        todayDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
      ),
      headerStyle: const HeaderStyle(
        titleTextStyle: TextStyle(color: Colors.white),
        formatButtonVisible: false,
        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white60),
        weekendStyle: TextStyle(color: Colors.white60),
      ),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
        loadRecordsByDate(selected);
      },
    );
  }

  // ---------------- BODY ----------------
  Widget _body() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a date to view attendance',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (records.isEmpty) {
      return const Center(
        child: Text(
          'No attendance records for this day',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (_, i) {
        final r = records[i];
        final iTime = _ts(r['checkIn']);
        final oTime = _ts(r['checkOut']);
        final inImg = _img(r['checkInSelfieBase64']);
        final outImg = _img(r['checkOutSelfieBase64']);
        final auto = r['autoCheckedOut'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(18),
            border: auto
                ? Border.all(color: Colors.orangeAccent, width: 1.4)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((r['displayUserId'] ?? '--').toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              if (auto)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Chip(
                    label:
                    Text('AUTO CHECK-OUT', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.orange,
                  ),
                ),
              const SizedBox(height: 8),
              _row('Check-in', iTime?.toLocal().toString() ?? '--'),
              _row('Check-out', oTime?.toLocal().toString() ?? 'Working'),
              if (inImg != null) _imgRow('Check-in', inImg),
              if (outImg != null) _imgRow('Check-out', outImg),
              _locationBlock('Check-in Location', r['checkInLocation']),
              _locationBlock('Check-out Location', r['checkOutLocation']),
              const SizedBox(height: 6),
              Text('Duration: ${duration(iTime, oTime)}',
                  style: const TextStyle(color: Colors.white60)),
            ],
          ),
        );
      },
    );
  }

  Widget _totalCard() {
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
          const Text('Total Working Time', style: TextStyle(color: Colors.white70)),
          Text(totalWorkingTime(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _row(String l, String v) {
    return Text('$l: $v', style: const TextStyle(color: Colors.white70));
  }

  Widget _imgRow(String l, ImageProvider img) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(l, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(image: img, width: 52, height: 52, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}