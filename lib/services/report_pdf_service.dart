import 'dart:io';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/member.dart';
import '../models/attendance_record.dart';

class ReportPdfService {
  static Future<File> exportMemberPdf(
      Member member, List<AttendanceRecord> records) async {
    final pdf = pw.Document();

    // Group records by date (YYYY-MM-DD)
    final Map<String, List<AttendanceRecord>> grouped = {};
    for (final r in records) {
      if (r.userId != member.uid) continue;
      final key =
          '${r.checkIn.year}-${r.checkIn.month.toString().padLeft(2, '0')}-${r.checkIn.day.toString().padLeft(2, '0')}';
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(r);
    }

    // Build PDF pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          List<pw.Widget> widgets = [];

          widgets.add(
            pw.Text(
              '${member.name} Attendance Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          );
          widgets.add(pw.SizedBox(height: 16));

          // Table per day
          grouped.forEach((date, dayRecords) {
            // Calculate total hours for the day
            final totalDuration = dayRecords.fold<Duration>(
                Duration.zero, (sum, r) => sum + r.totalTime);

            widgets.add(pw.Text(
              'Date: $date  |  Total Time: ${totalDuration.inHours}h ${totalDuration.inMinutes % 60}m',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ));
            widgets.add(pw.SizedBox(height: 8));

            // Table headers
            widgets.add(
              pw.Table.fromTextArray(
                headers: const ['Check In', 'Check Out', 'Duration'],
                data: dayRecords.map((r) {
                  final checkIn = r.checkIn;
                  final checkOut = r.checkOut;
                  final duration = r.totalTime;
                  return [
                    '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}',
                    checkOut != null
                        ? '${checkOut.hour.toString().padLeft(2, '0')}:${checkOut.minute.toString().padLeft(2, '0')}'
                        : '-',
                    '${duration.inHours}h ${duration.inMinutes % 60}m',
                  ];
                }).toList(),
              ),
            );

            widgets.add(pw.SizedBox(height: 16));
          });

          return widgets;
        },
      ),
    );

    // Save file to documents directory
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${member.name}_attendance.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
