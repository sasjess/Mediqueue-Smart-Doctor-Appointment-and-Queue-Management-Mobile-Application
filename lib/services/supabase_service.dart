import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ------------------------------------------------------------
  // 1. DOCTORS & AVAILABILITY
  // ------------------------------------------------------------
  
  /// Fetch all active doctors with their today's schedule
  Future<List<Map<String, dynamic>>> fetchDoctorsWithAvailability() async {
    final response = await _client
        .from('doctors')
        .select('*, doctor_availability(*)');
    return List<Map<String, dynamic>>.from(response);
  }

  // ------------------------------------------------------------
  // 2. PATIENT PROFILES
  // ------------------------------------------------------------

  /// Fetch all patient profiles linked to the logged-in user
  Future<List<Map<String, dynamic>>> fetchPatientProfiles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('patients')
        .select()
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Add a new patient profile (Self or Family Member)
  Future<Map<String, dynamic>?> addPatientProfile({
    required String name,
    required String mobile,
    required String relationship,
    String? dob,
    String? gender,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final response = await _client.from('patients').insert({
      'user_id': userId,
      'name': name,
      'patient_mobile': mobile,
      'relationship': relationship,
      'date_of_birth': dob,
      'gender': gender,
    }).select().single();

    return response;
  }

  // ------------------------------------------------------------
  // 3. APPOINTMENT BOOKINGS
  // ------------------------------------------------------------

  /// Create a new booking slot and return the created record with QR code string
  Future<Map<String, dynamic>?> createBooking({
    required int patientId,
    required int doctorId,
    required int availabilityId,
    required String bookingDate,
  }) async {
    try {
      // Unique booking code for QR (e.g., MQ-9482)
      final String bookingCode = 'MQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final int queueNumber = Random().nextInt(89) + 10;

      final response = await _client.from('bookings').insert({
        'booking_code': bookingCode,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'availability_id': availabilityId,
        'booking_date': bookingDate,
        'queue_number': queueNumber,
        'status': 'WAITING',
      }).select('*, doctors(name, specialization), patients(name)').single();

      return response;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Live Stream of active bookings for the current queue tab
  Stream<List<Map<String, dynamic>>> streamActiveBookings() {
    return _client
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .order('created_at', ascending: false);
  }
}