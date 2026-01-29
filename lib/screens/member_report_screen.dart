import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import '../models/member.dart';
import '../models/attendance_record.dart';
import '../services/report_pdf_service.dart';

class MemberReportScreen extends StatefulWidget {
  final Member member;
  final String? firestoreUserId;

  const MemberReportScreen({
    super.key,
    required this.member,
    this.firestoreUserId,
  });

  @override
  State<MemberReportScreen> createState() => _MemberReportScreenState();
}

class _MemberReportScreenState extends State<MemberReportScreen> {
  bool loading = true;
  List<AttendanceRecord> records = [];
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    setState(() => loading = true);
    try {
      final queryUserId = widget.firestoreUserId ?? widget.member.uid;

      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: queryUserId)
          .orderBy('checkIn', descending: true)
          .get();

      records = snap.docs.map((d) => AttendanceRecord.fromDoc(d)).toList();
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching attendance: $e')),
      );
    }
    setState(() => loading = false);
  }

  List<AttendanceRecord> filteredRecords() {
    if (selectedDate == null) return records;
    return records.where((r) {
      final d = r.checkIn;
      return d.year == selectedDate!.year &&
          d.month == selectedDate!.month &&
          d.day == selectedDate!.day;
    }).toList();
  }

  // ===== PDF EXPORT =====
  Future<void> exportPdf() async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to export')),
      );
      return;
    }

    try {
      final file = await ReportPdfService.exportMemberPdf(widget.member, records);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ${file.path}')),
      );

      // Open PDF file
      await OpenFilex.open(file.path);
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: Text('${widget.member.name} Reports'),
        backgroundColor: Colors.black,
      ),
      body: loading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      )
          : Column(
        children: [
          // ===== DATE FILTER & EXPORT BUTTON =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? "Showing: ${selectedDate!.toLocal().toString().split(' ')[0]}"
                        : "Showing all",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2100),
                      builder: (context, child) =>
                          Theme(data: ThemeData.dark(), child: child!),
                    );
                    if (date != null) setState(() => selectedDate = date);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                  onPressed: () {
                    setState(() => selectedDate = null);
                    fetchAttendance();
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                  onPressed: exportPdf,
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                  label: const Text(
                    'Export PDF',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ===== ATTENDANCE LIST =====
          Expanded(
            child: filteredRecords().isEmpty
                ? const Center(
              child: Text(
                "No records found",
                style: TextStyle(color: Colors.white54),
              ),
            )
                : ListView.builder(
              itemCount: filteredRecords().length,
              itemBuilder: (context, index) {
                final r = filteredRecords()[index];
                ImageProvider? checkInImg;
                ImageProvider? checkOutImg;

                try {
                  if (r.checkInSelfieBase64 != null) {
                    checkInImg = MemoryImage(base64Decode(r.checkInSelfieBase64!));
                  }
                  if (r.checkOutSelfieBase64 != null) {
                    checkOutImg = MemoryImage(base64Decode(r.checkOutSelfieBase64!));
                  }
                } catch (_) {}

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check-in: ${r.checkIn.toLocal()}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Check-out: ${r.checkOut?.toLocal() ?? "Still working"}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text('Status: ${r.status}',
                          style: const TextStyle(color: Colors.white70)),
                      Text(
                        'Total Time: ${r.totalTime.inHours}h ${r.totalTime.inMinutes % 60}m',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (checkInImg != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Text("Check-in Photo:",
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image(image: checkInImg, fit: BoxFit.cover),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (checkOutImg != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Text("Check-out Photo:",
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image(image: checkOutImg, fit: BoxFit.cover),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
