import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mediqueue/widgets/ticket_card.dart';
import 'package:path_provider/path_provider.dart';

class BookingTicketPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingTicketPage({super.key, required this.booking});

  @override
  State<BookingTicketPage> createState() => _BookingTicketPageState();
}

class _BookingTicketPageState extends State<BookingTicketPage> {
  final GlobalKey _ticketBoundaryKey = GlobalKey();
  bool _isSaving = false;

  String _formatBookingTime() {
    final bookingDate = widget.booking['booking_date']?.toString() ?? '';
    final startTime =
        widget.booking['doctor_availability']?['start_time']?.toString() ?? '';

    if (bookingDate.isEmpty && startTime.isEmpty) {
      return 'Today';
    }

    if (bookingDate.isNotEmpty && startTime.isNotEmpty) {
      return '$bookingDate $startTime';
    }

    return bookingDate.isNotEmpty ? bookingDate : startTime;
  }

  Future<void> _downloadTicket() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final boundary = _ticketBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Ticket is not ready yet.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to create ticket image.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      Directory? targetDir;

      if (!kIsWeb) {
        targetDir = await getDownloadsDirectory();
        targetDir ??= await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) {
        throw Exception('No download directory available.');
      }

      final bookingCode =
          widget.booking['booking_code']?.toString().replaceAll(' ', '_') ??
              'ticket';
      final filePath =
          '${targetDir.path}/mediqueue_${bookingCode}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket downloaded to: ${file.path}'),
          backgroundColor: const Color(0xFF2A7B3F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName =
        widget.booking['patients']?['name']?.toString() ?? 'Patient';
    final doctorName =
        widget.booking['doctors']?['name']?.toString() ?? 'Doctor';
    final queueName = '$doctorName Queue';
    final bookingCode = widget.booking['booking_code']?.toString() ?? '--';
    final queueNumber = widget.booking['queue_number'] is int
        ? widget.booking['queue_number'] as int
        : int.tryParse(widget.booking['queue_number']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Booking Ticket',
          style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          RepaintBoundary(
            key: _ticketBoundaryKey,
            child: TicketCard(
              bookingCode: bookingCode,
              patientName: patientName,
              doctorName: doctorName,
              queueName: queueName,
              appointmentTime: _formatBookingTime(),
              queueNumber: queueNumber,
              status:
                  widget.booking['status']?.toString().toUpperCase() ??
                      'BOOKED',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Show this QR code to reception when you arrive. Reception will scan it to mark you ARRIVED, then scan again to mark you SERVING.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _downloadTicket,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_isSaving ? 'Downloading...' : 'Download Ticket'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8171E5),
                side: const BorderSide(color: Color(0xFFDDD9F5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8171E5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}