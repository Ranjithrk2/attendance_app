import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

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

  // ---------------- FIRESTORE LOAD (DAY-WISE) ----------------

  Future<void> loadRecordsByDate(DateTime date) async {
    setState(() {
      isLoading = true;
      records.clear();
    });

    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('checkIn', isLessThan: Timestamp.fromDate(end))
          .orderBy('checkIn', descending: true)
          .get();

      setState(() {
        records = snapshot.docs.map((d) => d.data()).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
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
        todayDecoration:
        BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
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
          'No attendance records',
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

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (r['displayUserId'] ?? '--').toString(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _row('Check-in', iTime?.toLocal().toString() ?? '--'),
              _row('Check-out', oTime?.toLocal().toString() ?? 'Working'),
              const SizedBox(height: 6),
              if (inImg != null) _imgRow('Check-in', inImg),
              if (outImg != null) _imgRow('Check-out', outImg),
              const SizedBox(height: 6),
              Text(
                'Duration: ${duration(iTime, oTime)}',
                style: const TextStyle(color: Colors.white60),
              ),
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
          const Text('Total Working Time',
              style: TextStyle(color: Colors.white70)),
          Text(totalWorkingTime(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _row(String l, String v) {
    return Text('$l: $v',
        style: const TextStyle(color: Colors.white70));
  }

  Widget _imgRow(String l, ImageProvider img) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(l,
              style:
              const TextStyle(color: Colors.white60, fontSize: 13)),
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