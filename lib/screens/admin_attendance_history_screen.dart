import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/attendance_record.dart'; // your AttendanceRecord model

class AdminAttendanceHistoryScreen extends StatefulWidget {
  const AdminAttendanceHistoryScreen({super.key});

  @override
  State<AdminAttendanceHistoryScreen> createState() =>
      _AdminAttendanceHistoryScreenState();
}

class _AdminAttendanceHistoryScreenState
    extends State<AdminAttendanceHistoryScreen> {
  List<AttendanceRecord> records = [];
  bool isLoading = false;
  bool hasMore = true;
  static const int batchSize = 10;
  DocumentSnapshot? lastDoc;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String? filterUserId;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _selectedDay = DateTime.now();
    _loadRecords(_selectedDay!);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        _loadMoreRecords();
      }
    });

    _searchCtrl.addListener(() {
      setState(() {
        filterUserId = _searchCtrl.text.trim().toLowerCase();
        _loadRecords(_selectedDay!);
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Location permission is required for check-ins")));
    }
  }

  Future<void> _loadRecords(DateTime date) async {
    setState(() {
      isLoading = true;
      records.clear();
      lastDoc = null;
      hasMore = true;
    });

    try {
      final batch = await _fetchBatch(date);
      setState(() {
        records = batch;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      setState(() => isLoading = false);
    }
  }

  Future<List<AttendanceRecord>> _fetchBatch(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    Query q = FirebaseFirestore.instance
        .collection('attendance')
        .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('checkIn', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('checkIn', descending: true)
        .limit(batchSize);

    if (filterUserId != null && filterUserId!.isNotEmpty) {
      q = q.where('userId', isEqualTo: filterUserId);
    }

    if (lastDoc != null) {
      q = q.startAfterDocument(lastDoc!);
    }

    final snap = await q.get();
    if (snap.docs.isEmpty) {
      hasMore = false;
      return [];
    }

    lastDoc = snap.docs.last;
    return snap.docs.map((doc) => AttendanceRecord.fromDoc(doc)).toList();
  }

  Future<void> _loadMoreRecords() async {
    if (!hasMore) return;
    setState(() => isLoading = true);
    try {
      final batch = await _fetchBatch(_selectedDay!);
      setState(() {
        records.addAll(batch);
        isLoading = false;
        if (batch.length < batchSize) hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more records: $e');
      setState(() => isLoading = false);
    }
  }

  ImageProvider? _img(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  String totalWorkingTime() {
    Duration total = Duration.zero;
    for (final r in records) {
      total += r.totalTime;
    }
    return '${total.inHours}h ${total.inMinutes % 60}m';
  }

  String duration(AttendanceRecord r) {
    if (r.checkOut == null) return '--';
    return '${r.totalTime.inHours}h ${r.totalTime.inMinutes % 60}m';
  }

  Widget _statusBadge(AttendanceRecord r) {
    Color bgColor;
    String text;

    if (r.checkOut == null) {
      bgColor = Colors.green;
      text = "Checked In";
    } else if (r.autoCheckedOut) {
      bgColor = Colors.orange;
      text = "Auto Checked Out";
    } else {
      bgColor = Colors.blueAccent;
      text = "Checked Out";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _locationBlock(String title, GeoPoint? loc) {
    if (loc == null) return const SizedBox();
    final lat = loc.latitude;
    final lng = loc.longitude;
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
          TextButton(
            onPressed: () async {
              final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
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

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search by User ID",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

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
          _searchBar(),
          _calendar(),
          if (_selectedDay != null) _totalCard(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

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
        selectedDecoration:
        BoxDecoration(color: Colors.green, shape: BoxShape.circle),
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
        _loadRecords(selected);
      },
    );
  }

  Widget _body() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a date to view attendance',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    if (records.isEmpty && isLoading) {
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: records.length + 1,
      itemBuilder: (_, i) {
        if (i == records.length) {
          return hasMore
              ? const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          )
              : const SizedBox.shrink();
        }

        final r = records[i];
        final inImg = _img(r.checkInSelfieBase64);
        final outImg = _img(r.checkOutSelfieBase64);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(18),
            border: r.autoCheckedOut
                ? Border.all(color: Colors.orangeAccent, width: 1.4)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.userId,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  _statusBadge(r),
                ],
              ),
              const SizedBox(height: 8),
              _row('Check-in', r.checkIn.toLocal().toString()),
              _row('Check-out', r.checkOut?.toLocal().toString() ?? 'Working'),
              if (inImg != null) _imgRow('Check-in', inImg),
              if (outImg != null) _imgRow('Check-out', outImg),
              _locationBlock('Check-in Location', r.checkInLocation),
              _locationBlock('Check-out Location', r.checkOutLocation),
              const SizedBox(height: 6),
              Text('Duration: ${duration(r)}',
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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