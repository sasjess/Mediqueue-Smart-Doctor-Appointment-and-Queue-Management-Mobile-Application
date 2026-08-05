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

    bool isTodayOrFutureDate(String? dateStr) {
      if (dateStr == null || dateStr.trim().isEmpty) return false;
      try {
        final slotDate = DateTime.parse(dateStr.trim());
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final compareDate = DateTime(slotDate.year, slotDate.month, slotDate.day);
        return compareDate.isAfter(today) || compareDate.isAtSameMomentAs(today);
      } catch (_) {
        return true;
      }
    }

    final upcomingAvailabilities = availabilities.where((slot) {
      return isTodayOrFutureDate(slot['duty_date']?.toString());
    }).toList();

    // Get primary availability slot if available
    final Map<String, dynamic>? todaySlot = upcomingAvailabilities.isNotEmpty
        ? Map<String, dynamic>.from(upcomingAvailabilities.first)
        : null;

    final String status = todaySlot?['duty_status'] ?? 'UNAVAILABLE';
    final String startTime = (todaySlot?['start_time'] ?? '').toString();
    final String endTime = (todaySlot?['end_time'] ?? '').toString();

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
                  color: (status == 'AVAILABLE' || status.toLowerCase() == 'on duty')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: (status == 'AVAILABLE' || status.toLowerCase() == 'on duty')
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