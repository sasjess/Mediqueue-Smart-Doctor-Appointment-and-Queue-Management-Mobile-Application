import 'package:flutter/material.dart';
import 'package:mediqueue/services/supabase_service.dart';
import 'package:mediqueue/pages/book_appointment_page.dart';
import 'package:mediqueue/pages/booking_page.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _doctors = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final doctorsData = await _supabaseService.fetchDoctorsWithAvailability();
      setState(() {
        _doctors = doctorsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load doctors: $e')),
        );
      }
    }
  }

  DateTime? _parseDutyDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final dt = DateTime.parse(dateStr.trim());
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }

  String _deriveDisplayDutyStatus(Map<String, dynamic>? slot) {
    if (slot == null) return 'UNAVAILABLE';

    final stored = slot['duty_status']?.toString().trim().toUpperCase();
    return (stored == null || stored.isEmpty) ? 'UNAVAILABLE' : stored;
  }

  Map<String, dynamic>? _primaryAvailabilityForDisplay(List availabilities) {
    final normalized = availabilities
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
    if (normalized.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    normalized.sort((a, b) {
      final da = _parseDutyDate(a['duty_date']?.toString());
      final db = _parseDutyDate(b['duty_date']?.toString());
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    for (final slot in normalized) {
      final day = _parseDutyDate(slot['duty_date']?.toString());
      if (day != null && (day.isAtSameMomentAs(today) || day.isAfter(today))) {
        return slot;
      }
    }

    return normalized.first;
  }

  @override
  Widget build(BuildContext context) {
    // Filter doctors list based on search query
    final filteredDoctors = _doctors.where((doctor) {
      final name = (doctor['name'] ?? '').toString().toLowerCase();
      
      // Check direct 'specialization' or nested 'specialties(name)'
      final String spec = (doctor['specialization'] ??
              doctor['specialties']?['name'] ??
              '')
          .toString()
          .toLowerCase();

      final query = _searchQuery.toLowerCase();
      return name.contains(query) || spec.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Find Doctors',
          style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8171E5)),
            onPressed: _loadDoctors,
          )
        ],
      ),
      body: Column(
        children: [
          // ==========================================
          // SEARCH BAR
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search doctor or specialty...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ==========================================
          // DOCTORS LIST / LOADING STATE
          // ==========================================
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                  )
                : filteredDoctors.isEmpty
                    ? const Center(
                        child: Text(
                          'No doctors found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDoctors,
                        color: const Color(0xFF8171E5),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredDoctors.length,
                          itemBuilder: (context, index) {
                            final doctor = filteredDoctors[index];
                            final List availabilityList =
                                doctor['doctor_availability'] ?? [];

                            return _buildDoctorCard(
                              doctor: doctor,
                              availabilities: availabilityList,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Helper widget to render individual Doctor Cards
  Widget _buildDoctorCard({
    required Map<String, dynamic> doctor,
    required List availabilities,
  }) {
    final String name = doctor['name'] ?? 'Unknown Doctor';
    
    // Safely check both potential column names for specialty & profile image
    final String specialization = doctor['specialization'] ??
        doctor['specialties']?['name'] ??
        'General';
    final String? imageUrl = doctor['image_url'] ?? doctor['avatar_url'];

    final Map<String, dynamic>? todaySlot = _primaryAvailabilityForDisplay(availabilities);

    final String status = _deriveDisplayDutyStatus(todaySlot);
    final String startTime = (todaySlot?['start_time'] ?? '').toString();
    final String endTime = (todaySlot?['end_time'] ?? '').toString();
    final bool isAvailable = status == 'AVAILABLE';

    // Helper to safely format time standard format (e.g. "09:00")
    String formatTime(String time) {
      if (time.length >= 5) return time.substring(0, 5);
      return time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ==========================================
              // PROFILE PICTURE WITH FALLBACK & ERROR HANDLING
              // ==========================================
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEDEAFF),
                ),
                child: ClipOval(
                  child: (imageUrl != null && imageUrl.startsWith('http'))
                      ? Image.network(
                          imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF8171E5),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 32,
                            color: Color(0xFF8171E5),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 32,
                          color: Color(0xFF8171E5),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialization,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFEEEEF5)),
          ),

          // Schedule Details & Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    todaySlot != null && startTime.isNotEmpty
                        ? '${formatTime(startTime)} - ${formatTime(endTime)}'
                        : 'No slots today',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: todaySlot == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final selectedPatient = await showPatientSelectionBottomSheet(context);
                        if (selectedPatient != null && mounted) {
                          final result = await navigator.push(
                            MaterialPageRoute(
                              builder: (context) => BookingPage(
                                patient: selectedPatient,
                                initialDoctor: doctor,
                              ),
                            ),
                          );
                          if (result != null && mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Booking confirmed!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8171E5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}