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

          final Map<String, List<Map<String, dynamic>>> queuesByDoctor = {};
          for (final booking in bookings) {
            final doctorName =
                booking['doctors']?['name']?.toString() ?? 'Doctor';
            queuesByDoctor.putIfAbsent(doctorName, () => []);
            queuesByDoctor[doctorName]!.add(booking);
          }

          return ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            children: queuesByDoctor.entries.expand((entry) {
              final doctorName = entry.key;
              final doctorQueue = entry.value;

              final sectionHeader = Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Queue: $doctorName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E28),
                        ),
                      ),
                    ),
                    Text(
                      '${doctorQueue.length} active',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );

              final tiles = List<Widget>.generate(doctorQueue.length, (index) {
                final booking = doctorQueue[index];
                final rawQueueNumber = booking['queue_number'];
                final tokenNumber = rawQueueNumber is int
                    ? rawQueueNumber
                    : int.tryParse(rawQueueNumber?.toString() ?? '') ??
                        (index + 1);

                return _buildSimpleQueueTile(
                  tokenNumber: tokenNumber,
                  patientName:
                      booking['patients']?['name']?.toString() ?? 'Patient',
                  doctorName: doctorName,
                  status: booking['status']?.toString() ?? 'BOOKED',
                );
              });

              return [sectionHeader, ...tiles];
            }).toList(),
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
    required String doctorName,
    required String status,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status.toUpperCase()) {
      case 'WAITING':
      case 'BOOKED':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'ARRIVED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'SERVING':
        statusColor = Colors.blue;
        statusIcon = Icons.meeting_room;
        break;
      case 'COMPLETED':
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1E1E28),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Queue: $doctorName',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
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