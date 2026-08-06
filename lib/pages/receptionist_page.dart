import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mediqueue/services/supabase_service.dart';

class ReceptionistPage extends StatefulWidget {
  final bool showProfileAction;

  const ReceptionistPage({super.key, this.showProfileAction = true});

  @override
  State<ReceptionistPage> createState() => _ReceptionistPageState();
}

class _ReceptionistPageState extends State<ReceptionistPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _scannedBooking;
  List<Map<String, dynamic>> _activeBookings = [];
  String _searchQuery = '';
  bool _isLoadingBookings = true;
  bool _isUpdating = false;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_appLifecycleObserver);
    _loadBookings();
    _bookingsSubscription = _supabaseService.streamActiveBookings().listen(
      (_) => _loadBookings(showLoader: false),
      onError: (_) => _loadBookings(showLoader: false),
    );
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadBookings(showLoader: false),
    );
  }

  late final WidgetsBindingObserver _appLifecycleObserver =
      _ReceptionLifecycleObserver(
    onResume: () {
      _loadBookings(showLoader: false);
    },
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_appLifecycleObserver);
    _refreshTimer?.cancel();
    _searchController.dispose();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredBookings() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _activeBookings;

    return _activeBookings.where((booking) {
      final patientName =
          booking['patients']?['name']?.toString().toLowerCase() ?? '';
      final doctorName =
          booking['doctors']?['name']?.toString().toLowerCase() ?? '';
      return patientName.contains(query) || doctorName.contains(query);
    }).toList();
  }

  int _queueNumberValue(Map<String, dynamic> booking) {
    return int.tryParse(booking['queue_number']?.toString() ?? '') ?? 1 << 30;
  }

  List<Map<String, dynamic>> _sortedByQueueNumber(
    List<Map<String, dynamic>> bookings,
  ) {
    final sorted = List<Map<String, dynamic>>.from(bookings);
    sorted.sort((a, b) {
      final queueCompare = _queueNumberValue(a).compareTo(_queueNumberValue(b));
      if (queueCompare != 0) return queueCompare;

      final createdA = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final createdB = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (createdA == null || createdB == null) return 0;
      return createdA.compareTo(createdB);
    });
    return sorted;
  }

  Map<String, dynamic>? _firstByStatus(String status) {
    for (final booking in _activeBookings) {
      final currentStatus = booking['status']?.toString().toUpperCase() ?? '';
      if (currentStatus == status) return booking;
    }
    return null;
  }

  String _tokenLabelFromBooking(Map<String, dynamic>? booking) {
    if (booking == null) return '--';
    final raw = booking['queue_number']?.toString() ?? '';
    if (raw.isEmpty) return '--';
    return raw;
  }

  Future<void> _loadBookings({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isLoadingBookings = true);
    }

    try {
      final bookings = await _supabaseService.fetchActiveBookings();
      if (!mounted) return;
      setState(() {
        _activeBookings = _sortedByQueueNumber(bookings);
        _isLoadingBookings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBookings = false);
      _showSnackBar('Unable to load bookings: $e', success: false);
    }
  }

  void _showSnackBar(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2A7B3F) : Colors.redAccent,
      ),
    );
  }

  Future<void> _refreshScannedBooking() async {
    if (_scannedBooking == null) return;

    try {
      final updatedBooking = await _supabaseService.findBookingByCode(
        _scannedBooking!['booking_code'] as String,
      );
      if (updatedBooking != null && mounted) {
        setState(() => _scannedBooking = updatedBooking);
      }
    } catch (e) {
      _showSnackBar('Unable to refresh scanned booking: $e', success: false);
    }
  }

  Future<void> _markArrived(Map<String, dynamic> booking) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final updated = await _supabaseService.markBookingArrivedByCode(
        booking['booking_code'] as String,
      );

      if (!mounted) return;

      if (updated) {
        await _loadBookings(showLoader: false);
        await _refreshScannedBooking();
        _showSnackBar('Status updated to ARRIVED', success: true);
      } else {
        _showSnackBar('Unable to mark arrival.', success: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating arrival status: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markServing(Map<String, dynamic> booking) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final updated = await _supabaseService.markBookingServingByCode(
        booking['booking_code'] as String,
      );

      if (!mounted) return;

      if (updated) {
        await _loadBookings(showLoader: false);
        await _refreshScannedBooking();
        _showSnackBar('Current patient marked SERVING', success: true);
      } else {
        _showSnackBar('Unable to mark serving.', success: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating serving status: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _skipAndRequeue(Map<String, dynamic> booking) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final newBooking = await _supabaseService.skipAndRequeueBookingByCode(
        booking['booking_code'] as String,
      );

      if (!mounted) return;

      if (newBooking != null) {
        await _loadBookings(showLoader: false);
        setState(() => _scannedBooking = newBooking);
        _showSnackBar('Ticket cancelled and reissued at the end of the queue.', success: true);
      } else {
        _showSnackBar('Unable to requeue this ticket.', success: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error requeueing ticket: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markCompleted(Map<String, dynamic> booking) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final updated = await _supabaseService.markBookingCompletedByCode(
        booking['booking_code'] as String,
      );

      if (!mounted) return;

      if (updated) {
        await _loadBookings(showLoader: false);
        await _refreshScannedBooking();
        _showSnackBar('Appointment marked COMPLETED', success: true);
      } else {
        _showSnackBar('Unable to mark this appointment completed.', success: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error completing appointment: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _showScanActions(Map<String, dynamic> booking) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bookingCode = booking['booking_code']?.toString() ?? '--';
        final patientName = booking['patients']?['name']?.toString() ?? 'Patient';
        final doctorName = booking['doctors']?['name']?.toString() ?? 'Doctor';
        final currentStatus = booking['status']?.toString().toUpperCase() ?? 'BOOKED';

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7D7E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scanned booking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('$patientName • $doctorName'),
              const SizedBox(height: 4),
              Text('Code: $bookingCode'),
              const SizedBox(height: 4),
              Text('Current status: $currentStatus'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () async {
                              Navigator.of(sheetContext).pop();
                              await _markArrived(booking);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8171E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Mark arrived'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () async {
                              Navigator.of(sheetContext).pop();
                              await _markServing(booking);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A7B3F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Mark serving'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await _markCompleted(booking);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B3AB7),
                    side: const BorderSide(color: Color(0xFFE5D7FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Mark completed'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await _skipAndRequeue(booking);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB22C2C),
                    side: const BorderSide(color: Color(0xFFF0C7C7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Skip and requeue'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleScanResult(String bookingCode) async {
    setState(() {
      _scannedBooking = null;
    });

    try {
      final booking = await _supabaseService.findBookingByCode(bookingCode);

      if (!mounted) return;

      if (booking == null) {
        _showSnackBar('No booking found for scanned code.', success: false);
        return;
      }

      setState(() => _scannedBooking = booking);
      _showSnackBar('Booking found. You can update the status below.', success: true);
      await _showScanActions(booking);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Scan failed: $e', success: false);
      }
    }
  }

  Future<void> _openScanner() async {
    final bookingCode = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ScanBookingPage()),
    );

    if (bookingCode != null && bookingCode.isNotEmpty) {
      await _handleScanResult(bookingCode);
    }
  }

  Widget _buildStatusLabel(String status) {
    final statusText = status.toString().toUpperCase();
    Color background;
    Color textColor;

    switch (statusText) {
      case 'WAITING':
      case 'BOOKED':
        background = const Color(0xFFFFF6E6);
        textColor = const Color(0xFFAA6F17);
        break;
      case 'ARRIVED':
        background = const Color(0xFFE6F4EA);
        textColor = const Color(0xFF2A7B3F);
        break;
      case 'SERVING':
        background = const Color(0xFFEAF4FF);
        textColor = const Color(0xFF27548C);
        break;
      case 'COMPLETED':
        background = const Color(0xFFEFE9FF);
        textColor = const Color(0xFF6B3AB7);
        break;
      case 'CANCELLED':
        background = const Color(0xFFFFE7E7);
        textColor = const Color(0xFFB22C2C);
        break;
      case 'CONFIRMED':
        background = const Color(0xFFF4F1FF);
        textColor = const Color(0xFF5A45A7);
        break;
      default:
        background = const Color(0xFFF1F1F7);
        textColor = const Color(0xFF5A5A66);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildBookingTile(Map<String, dynamic> booking) {
    final patientName = booking['patients']?['name']?.toString() ?? 'Patient';
    final doctorName = booking['doctors']?['name']?.toString() ?? 'Doctor';
    final status = booking['status']?.toString().toUpperCase() ?? 'BOOKED';
    final queueNumber = booking['queue_number']?.toString() ?? '--';
    final isTerminal = status == 'COMPLETED' || status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEDEAFF),
                child: Text(
                  queueNumber,
                  style: const TextStyle(
                    color: Color(0xFF8171E5),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
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
              _buildStatusLabel(status),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: isTerminal || _isUpdating
                    ? null
                    : () => _markArrived(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 192, 220, 237),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Mark arrived'),
              ),
              ElevatedButton(
                onPressed: isTerminal || _isUpdating
                    ? null
                    : () => _markServing(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5EFF7),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Mark serving'),
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
        title: const Text(
          'Reception Desk',
          style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.showProfileAction)
            IconButton(
              icon: const Icon(Icons.person, color: Color(0xFF1E1E28)),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF8171E5),
        onRefresh: _loadBookings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEEEEF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient check-in',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E28),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan the patient QR or booking code to update their queue status automatically.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _openScanner,
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Scan patient QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5EFF7),
                        foregroundColor: Colors.black,
                        side: const BorderSide(
                          color: Color(0xFF8171E5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                  hintText: 'Search by patient or doctor name',
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
            const SizedBox(height: 14),
            if (_scannedBooking != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEEEEF5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scanned booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildBookingTile(_scannedBooking!),
                    const SizedBox(height: 8),
                    const Text(
                      'Quick actions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: _isUpdating
                              ? null
                              : () => _markArrived(_scannedBooking!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 192, 220, 237),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          child: const Text('Mark admitted'),
                        ),
                        ElevatedButton(
                          onPressed: _isUpdating
                              ? null
                              : () => _markServing(_scannedBooking!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5EFF7),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          child: const Text('Mark serving'),
                        ),
                        ElevatedButton(
                          onPressed: _isUpdating
                              ? null
                              : () => _markCompleted(_scannedBooking!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5EFF7),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          child: const Text('Mark completed'),
                        ),
                        OutlinedButton(
                          onPressed: _isUpdating
                              ? null
                              : () => _skipAndRequeue(_scannedBooking!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB22C2C),
                            side: const BorderSide(color: Color(0xFFF0C7C7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          child: const Text('Skip and requeue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active appointment queue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E28),
                  ),
                ),
                if (_isUpdating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8171E5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEF5)),
              ),
              child: Builder(
                builder: (_) {
                  final servingBooking = _firstByStatus('SERVING');
                  final waitingBooking = _firstByStatus('ARRIVED') ?? _firstByStatus('BOOKED') ?? _firstByStatus('WAITING');
                  final totalActive = _activeBookings.length;

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Now serving',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Token ${_tokenLabelFromBooking(servingBooking)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF27548C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next token',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Token ${_tokenLabelFromBooking(waitingBooking)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFAA6F17),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active count',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalActive',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E28),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_isLoadingBookings)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                ),
              )
            else if (_activeBookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No active bookings in the queue at the moment.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else if (filteredBookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No matching appointments found.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...filteredBookings.map(_buildBookingTile),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ReceptionLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResume;

  _ReceptionLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

class ScanBookingPage extends StatefulWidget {
  const ScanBookingPage({super.key});

  @override
  State<ScanBookingPage> createState() => _ScanBookingPageState();
}

class _ScanBookingPageState extends State<ScanBookingPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  String? _scanError;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final String? rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      setState(() {
        _scanError = 'Unable to read QR code. Please try again.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _scanError = null;
    });

    await _scannerController.stop();

    if (!mounted) return;
    Navigator.of(context).pop(rawValue);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Scan Patient QR'),
        actions: [
          IconButton(
            onPressed: () async {
              await _scannerController.toggleTorch();
            },
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          if (_scanError != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _scanError!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
