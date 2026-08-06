import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediqueue/services/supabase_service.dart';

class AppointmentManagementPage extends StatefulWidget {
  const AppointmentManagementPage({super.key});

  @override
  State<AppointmentManagementPage> createState() =>
      _AppointmentManagementPageState();
}

class _AppointmentManagementPageState extends State<AppointmentManagementPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String _searchQuery = '';
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _bookingsSubscription = _supabaseService.streamActiveBookings().listen(
      (_) => _loadBookings(showLoader: false),
      onError: (_) => _loadBookings(showLoader: false),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredBookings() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _bookings;

    return _bookings.where((booking) {
      final patientName = booking['patients']?['name']?.toString().toLowerCase() ?? '';
      final doctorName = booking['doctors']?['name']?.toString().toLowerCase() ?? '';
      final status = booking['status']?.toString().toLowerCase() ?? '';
      final queueNumber = booking['queue_number']?.toString().toLowerCase() ?? '';
      final bookingCode = booking['booking_code']?.toString().toLowerCase() ?? '';

      return patientName.contains(query) ||
          doctorName.contains(query) ||
          status.contains(query) ||
          queueNumber.contains(query) ||
          bookingCode.contains(query);
    }).toList();
  }

  Future<void> _loadBookings({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final bookings = await _supabaseService.fetchActiveBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('Unable to load appointments: $e', success: false);
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    if (_isUpdating) return;

    final confirmCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final patientName = booking['patients']?['name']?.toString() ?? 'this patient';
        return AlertDialog(
          title: const Text('Cancel appointment?'),
          content: Text('Are you sure you want to cancel the appointment for $patientName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );

    if (confirmCancel != true) return;

    setState(() => _isUpdating = true);

    try {
      final success = await _supabaseService.updateBookingStatus(
        bookingId: booking['booking_id'],
        status: 'CANCELLED',
      );

      if (!mounted) return;

      if (success) {
        await _loadBookings(showLoader: false);
        _showSnackbar('Appointment cancelled', success: true);
      } else {
        _showSnackbar('Unable to cancel appointment', success: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error cancelling appointment: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _rescheduleBooking(Map<String, dynamic> booking) async {
    final currentDate = DateTime.tryParse(booking['booking_date']?.toString() ?? '');
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;

    setState(() => _isUpdating = true);

    try {
      final formattedDate = selectedDate.toIso8601String().split('T').first;
      final success = await _supabaseService.updateBookingDate(
        bookingId: booking['booking_id'],
        bookingDate: formattedDate,
      );

      if (!mounted) return;

      if (success) {
        await _loadBookings(showLoader: false);
        _showSnackbar('Appointment rescheduled', success: true);
      } else {
        _showSnackbar('Unable to update date', success: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error rescheduling appointment: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showSnackbar(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2A7B3F) : Colors.redAccent,
      ),
    );
  }

  String _formatBookingDate(String dateValue) {
    final date = DateTime.tryParse(dateValue);
    if (date == null) return dateValue;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final patientName = booking['patients']?['name']?.toString() ?? 'Patient';
    final doctorName = booking['doctors']?['name']?.toString() ?? 'Doctor';
    final status = booking['status']?.toString().toUpperCase() ?? 'WAITING';
    final bookingDate = _formatBookingDate(booking['booking_date']?.toString() ?? 'Unknown');
    final isTerminal = status == 'CANCELLED' || status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 239, 236, 244),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text('Doctor: $doctorName', style: const TextStyle(color: Color.fromARGB(255, 23, 23, 23))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status == 'CANCELLED'
                      ? const Color(0xFFFFE7E7)
                      : const Color.fromARGB(255, 228, 223, 249),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Date: $bookingDate', style: const TextStyle(color: Color.fromARGB(255, 23, 23, 23))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton(
                onPressed: isTerminal || _isUpdating
                    ? null
                    : () => _cancelBooking(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 182, 37, 27),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel Appointment'),
              ),
              OutlinedButton(
                onPressed: isTerminal || _isUpdating
                    ? null
                    : () => _rescheduleBooking(booking),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 192, 220, 237),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFDDD9F5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Change date',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _filteredBookings();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Appointment Management',
          style: TextStyle(
            color: Color(0xFF1E1E28),
            fontWeight: FontWeight.w700,
            ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8171E5)))
            : RefreshIndicator(
                color: const Color.fromARGB(255, 7, 7, 7),
                onRefresh: _loadBookings,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEF5)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          hintText: 'Search by patient, doctor, status, token, or code',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Clear search',
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_bookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 36),
                        child: Center(child: Text('No active appointments found.')),
                      )
                    else if (filteredBookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 36),
                        child: Center(child: Text('No matching appointments found.')),
                      )
                    else
                      ...filteredBookings.map(_buildBookingCard),
                  ],
                ),
              ),
      ),
    );
  }
}
