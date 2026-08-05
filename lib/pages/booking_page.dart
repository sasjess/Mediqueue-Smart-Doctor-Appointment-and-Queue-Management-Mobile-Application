import 'package:flutter/material.dart';
import 'package:mediqueue/services/supabase_service.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? initialDoctor;
  const BookingPage({super.key, required this.patient, this.initialDoctor});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final SupabaseService _svc = SupabaseService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDoctorId;
  int? _selectedAvailabilityId;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialDoctor != null) {
      _selectedDoctorId = (widget.initialDoctor!['id'] ?? widget.initialDoctor!['doctor_id'])?.toString();
    }
    _loadDoctors();
  }

  bool _isTodayOrFutureDate(String? dateStr) {
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

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _svc.fetchDoctorsWithAvailability();
      setState(() {
        _doctors = docs;
        if (_selectedDoctorId == null && _doctors.isNotEmpty) {
          final first = _doctors.first;
          _selectedDoctorId = (first['id'] ?? first['doctor_id'])?.toString();
        }
        _updateDefaultAvailabilitySlot();
      });
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateDefaultAvailabilitySlot() {
    if (_selectedDoctorId != null) {
      final doc = _doctors.firstWhere(
        (d) => ((d['id'] ?? d['doctor_id'])?.toString() ?? '') == _selectedDoctorId,
        orElse: () => {},
      );
      final List rawAvail = (doc['doctor_availability'] is List) ? doc['doctor_availability'] as List : [];
      final List validAvail = rawAvail.where((slot) => _isTodayOrFutureDate(slot['duty_date']?.toString())).toList();
      if (validAvail.isNotEmpty) {
        final firstSlot = validAvail.first;
        _selectedAvailabilityId = firstSlot['availability_id'] is int
            ? firstSlot['availability_id'] as int
            : int.tryParse(firstSlot['availability_id']?.toString() ?? firstSlot['id']?.toString() ?? '');
      } else {
        _selectedAvailabilityId = null;
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submitBooking() async {
    if (_selectedDoctorId == null || _selectedDoctorId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a doctor')));
      return;
    }
    if (_selectedAvailabilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an availability slot')));
      return;
    }

    final rawPatientId = widget.patient['patient_id']?.toString() ?? widget.patient['id']?.toString() ?? '';
    final patientId = int.tryParse(rawPatientId) ?? 0;
    if (patientId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid patient selected')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doctorId = _selectedDoctorId!;
      final availabilityId = _selectedAvailabilityId!;

      // find selected availability map
      Map<String, dynamic>? availabilityMap;
      for (final d in _doctors) {
        final dId = (d['id'] ?? d['doctor_id'])?.toString() ?? '';
        if (dId == doctorId && d['doctor_availability'] is List) {
          for (final slot in d['doctor_availability']) {
            final aid = slot['availability_id'] is int
                ? slot['availability_id'] as int
                : int.tryParse(slot['availability_id']?.toString() ?? slot['id']?.toString() ?? '') ?? 0;
            if (aid == availabilityId) {
              availabilityMap = Map<String, dynamic>.from(slot);
              break;
            }
          }
        }
        if (availabilityMap != null) break;
      }

      // prefer selected date, otherwise use availability duty_date if present
      String bookingDate;
      if (_selectedDate != null) {
        final d = _selectedDate!;
        bookingDate = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      } else if (availabilityMap != null && availabilityMap['duty_date'] != null) {
        bookingDate = availabilityMap['duty_date'].toString();
      } else {
        final d = DateTime.now();
        bookingDate = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }

      final created = await _svc.createBooking(
        patientId: patientId,
        doctorId: doctorId,
        availabilityId: availabilityId,
        bookingDate: bookingDate,
      );

      if (created != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, created);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create booking')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating booking: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment', style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E1E28), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF8F9FE),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8171E5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking for: ${widget.patient['name'] ?? 'Patient'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),

                  // Doctor Dropdown
                  const Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _doctors.any((doc) => ((doc['id'] ?? doc['doctor_id'])?.toString() ?? '') == _selectedDoctorId)
                        ? _selectedDoctorId
                        : null,
                    items: _doctors.map((doc) {
                      final docId = (doc['id'] ?? doc['doctor_id'])?.toString() ?? '';
                      final spec = doc['specialization'] ?? doc['specialties']?['name'] ?? '';
                      return DropdownMenuItem<String>(
                        value: docId,
                        child: Text('${doc['name']} ${spec.isNotEmpty ? '($spec)' : ''}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDoctorId = val;
                        _updateDefaultAvailabilitySlot();
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E8))),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Availability Dropdown
                  const Text('Availability Slot', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedAvailabilityId,
                    items: (() {
                      // Find availability list for selected doctor
                      final doc = _doctors.firstWhere(
                        (d) => ((d['id'] ?? d['doctor_id'])?.toString() ?? '') == (_selectedDoctorId ?? ''),
                        orElse: () => {},
                      );
                      final List rawAvail = (doc['doctor_availability'] is List) ? doc['doctor_availability'] as List : [];
                      final List avail = rawAvail.where((slot) => _isTodayOrFutureDate(slot['duty_date']?.toString())).toList();
                      return avail.map<DropdownMenuItem<int>>((slot) {
                        final availId = slot['availability_id'] is int
                            ? slot['availability_id'] as int
                            : int.tryParse(slot['availability_id']?.toString() ?? slot['id']?.toString() ?? '') ?? 0;
                        final start = slot['start_time'] ?? '';
                        final end = slot['end_time'] ?? '';
                        final date = slot['duty_date'] ?? '';
                        final status = slot['duty_status'] ?? '';
                        return DropdownMenuItem(
                          value: availId,
                          child: Text('${date.isNotEmpty ? "$date · " : ""}$start-$end · $status'),
                        );
                      }).toList();
                    })(),
                    onChanged: (val) {
                      setState(() {
                        _selectedAvailabilityId = val;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E8))),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Booking Date (optional)
                  const Text('Booking Date (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E8))),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text(_selectedDate == null ? 'Select booking date (defaults to slot date)' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}', style: TextStyle(color: _selectedDate == null ? Colors.grey : const Color(0xFF222222))),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8171E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
