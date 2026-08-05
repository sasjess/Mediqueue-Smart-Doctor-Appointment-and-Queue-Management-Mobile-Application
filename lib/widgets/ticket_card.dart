import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TicketCard extends StatelessWidget {
  final String bookingCode; // e.g. "MQ-9482103"
  final String patientName;
  final String doctorName;
  final String appointmentTime;
  final int queueNumber;
  final String status;

  const TicketCard({
    super.key,
    required this.bookingCode,
    required this.patientName,
    required this.doctorName,
    required this.appointmentTime,
    required this.queueNumber,
    this.status = 'WAITING',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Patient & Queue Number Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E1E28),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctorName,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Token #$queueNumber',
                  style: const TextStyle(
                    color: Color(0xFF8171E5),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFFEEEEF5), height: 1),
          ),

          // QR Code Rendering
          Center(
            child: QrImageView(
              data: bookingCode, // Encodes the unique booking code string
              version: QrVersions.auto,
              size: 160.0,
              foregroundColor: const Color(0xFF1E1E28),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Ticket Code: $bookingCode',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // Appointment Time Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF8171E5)),
                const SizedBox(width: 8),
                Text(
                  'Time: $appointmentTime',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1E28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}