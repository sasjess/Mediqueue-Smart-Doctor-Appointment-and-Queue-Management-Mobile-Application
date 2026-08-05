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

  /// Fetch or create patient profiles for current user.
  /// Ensures the primary user ("Self") has a valid row in `patients` table with an int4 `patient_id`,
  /// and deduplicates records so "Self" appears exactly once.
  Future<List<Map<String, dynamic>>> getPatientsForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Fetch existing patients from public.patients table
      final List<dynamic> existing = await _client
          .from('patients')
          .select('*')
          .eq('user_id', user.id);

      List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(existing);

      // Fetch user full name from profiles table or auth metadata
      String selfName = 'Self';
      try {
        final profile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
          selfName = profile['full_name'].toString();
        } else if (user.userMetadata?['full_name'] != null) {
          selfName = user.userMetadata!['full_name'].toString();
        } else if (user.email != null) {
          selfName = user.email!.split('@').first;
        }
      } catch (_) {}

      // Check if a "Self" patient record exists
      bool hasSelf = rawList.any((p) => 
        (p['relationship'] ?? '').toString().trim().toLowerCase() == 'self');

      if (!hasSelf && rawList.isEmpty) {
        // Insert "Self" patient record into public.patients table if table is empty
        final newSelf = await _client.from('patients').insert({
          'user_id': user.id,
          'name': selfName,
          'relationship': 'Self',
          'patient_mobile': user.phone ?? user.userMetadata?['phone'] ?? '',
        }).select().single();

        rawList.insert(0, Map<String, dynamic>.from(newSelf));
      } else if (!hasSelf && rawList.isNotEmpty) {
        final firstSelfIndex = rawList.indexWhere((p) =>
            (p['name'] ?? '').toString().trim().toLowerCase() == selfName.trim().toLowerCase());
        if (firstSelfIndex != -1) {
          rawList[firstSelfIndex]['relationship'] = 'Self';
        } else {
          final newSelf = await _client.from('patients').insert({
            'user_id': user.id,
            'name': selfName,
            'relationship': 'Self',
            'patient_mobile': user.phone ?? user.userMetadata?['phone'] ?? '',
          }).select().single();
          rawList.insert(0, Map<String, dynamic>.from(newSelf));
        }
      }

      // Deduplicate patient list:
      // Ensure "Self" appears EXACTLY ONCE in the returned list
      List<Map<String, dynamic>> uniqueList = [];
      bool selfAdded = false;

      for (final p in rawList) {
        final rel = (p['relationship'] ?? '').toString().trim().toLowerCase();
        final isSelf = rel == 'self' || p['name'] == selfName;

        if (isSelf) {
          if (!selfAdded) {
            p['relationship'] = 'Self';
            uniqueList.add(p);
            selfAdded = true;
          }
        } else {
          if (!uniqueList.any((u) => u['patient_id'] == p['patient_id'])) {
            uniqueList.add(p);
          }
        }
      }

      return uniqueList;
    } catch (e) {
      print('Error getting patients: $e');
      return [];
    }
  }

  /// Fetch all patient profiles linked to the logged-in user
  Future<List<Map<String, dynamic>>> fetchPatientProfiles() async {
    return getPatientsForCurrentUser();
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

  /// Create a new booking slot and return the created record
  Future<Map<String, dynamic>?> createBooking({
    required int patientId,
    required String doctorId,
    required int availabilityId,
    required String bookingDate,
  }) async {
    try {
      // Unique booking code for QR (e.g., MQ-948210)
      final String bookingCode = 'MQ-${(Random().nextInt(899999) + 100000)}';
      final int queueNumber = Random().nextInt(89) + 10;

      Map<String, dynamic> payload = {
        'booking_code': bookingCode,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'availability_id': availabilityId,
        'booking_date': bookingDate,
        'queue_number': queueNumber,
        'status': 'WAITING',
      };

      try {
        final response = await _client.from('bookings').insert(payload).select('*, doctors(*), patients(*)').single();
        return response;
      } catch (selectErr) {
        // Fallback simple insert if nested relation select has schema constraints
        final response = await _client.from('bookings').insert(payload).select().single();
        return response;
      }
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
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