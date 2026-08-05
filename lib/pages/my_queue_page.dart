import 'package:flutter/material.dart';
import 'package:mediqueue/services/supabase_service.dart';

class MyQueuePage extends StatelessWidget {
  const MyQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final SupabaseService supabaseService = SupabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Live Queue Status',
          style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabaseService.streamActiveBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8171E5)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading queue: ${snapshot.error}'));
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No active queue bookings yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];

              return _buildSimpleQueueTile(
                tokenNumber: booking['queue_number'] ?? (index + 1),
                patientName: booking['patients']?['name'] ?? 'Patient',
                status: booking['status'] ?? 'BOOKED',
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // SIMPLE QUEUE TILE WIDGET
  // ==========================================
  Widget _buildSimpleQueueTile({
    required int tokenNumber,
    required String patientName,
    required String status,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status.toUpperCase()) {
      case 'ARRIVED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'IN_ROOM':
        statusColor = Colors.blue;
        statusIcon = Icons.meeting_room;
        break;
      default:
        statusColor = Colors.orange; // BOOKED / WAITING
        statusIcon = Icons.access_time;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Row(
        children: [
          // Token Badge
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEDEAFF),
            child: Text(
              '#$tokenNumber',
              style: const TextStyle(
                color: Color(0xFF8171E5),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Patient Name
          Expanded(
            child: Text(
              patientName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF1E1E28),
              ),
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
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