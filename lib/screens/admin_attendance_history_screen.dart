import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/attendance_record.dart';

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

  /// 🔥 User Cache (from users collection)
  Map<String, Map<String, dynamic>> userCache = {};

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
      filterUserId = _searchCtrl.text.trim().toLowerCase();
      _loadRecords(_selectedDay!);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  /// 🔥 Load User Details from users collection
  Future<void> _loadUserDetails(String userId) async {
    if (userCache.containsKey(userId)) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      userCache[userId] = doc.data()!;
      if (mounted) setState(() {});
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

      // 🔥 Preload user details
      for (var r in batch) {
        _loadUserDetails(r.userId);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<List<AttendanceRecord>> _fetchBatch(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    Query q = FirebaseFirestore.instance
        .collection('attendance')
        .where('checkIn',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('checkIn',
        isLessThanOrEqualTo: Timestamp.fromDate(end))
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

    return snap.docs
        .map((doc) => AttendanceRecord.fromDoc(doc))
        .toList();
  }

  Future<void> _loadMoreRecords() async {
    if (!hasMore) return;

    setState(() => isLoading = true);

    final batch = await _fetchBatch(_selectedDay!);

    setState(() {
      records.addAll(batch);
      isLoading = false;
      if (batch.length < batchSize) hasMore = false;
    });

    for (var r in batch) {
      _loadUserDetails(r.userId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Attendance Calendar'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(),
            _calendar(),
            if (_selectedDay != null) _totalCard(),
            Expanded(child: _body()),
          ],
        ),
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
          prefixIcon:
          const Icon(Icons.search, color: Colors.cyanAccent),
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

  Widget _calendar() {
    return TableCalendar(
      firstDay: DateTime(2023),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) =>
          isSameDay(d, _selectedDay),
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
    if (records.isEmpty && isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(color: Colors.white),
      );
    }

    if (records.isEmpty) {
      return const Center(
        child: Text(
          'No attendance records',
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
              child: CircularProgressIndicator(
                  color: Colors.cyanAccent),
            ),
          )
              : const SizedBox();
        }

        final r = records[i];
        final userName =
            userCache[r.userId]?['name'] ?? r.userId;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight:
                          FontWeight.bold),
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(r),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  'Check-in: ${r.checkIn.toLocal()}',
                  style: const TextStyle(
                      color: Colors.white70)),
              Text(
                  'Check-out: ${r.checkOut?.toLocal() ?? "Working"}',
                  style: const TextStyle(
                      color: Colors.white70)),
              Text(
                  'Duration: ${duration(r)}',
                  style: const TextStyle(
                      color: Colors.white60)),
            ],
          ),
        );
      },
    );
  }

  Widget _totalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Working Time',
              style:
              TextStyle(color: Colors.white70)),
          Text(totalWorkingTime(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.bold)),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
          BorderRadius.circular(12)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontWeight:
              FontWeight.bold,
              fontSize: 12)),
    );
  }
}