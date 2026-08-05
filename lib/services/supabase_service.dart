import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  int _parseBookingId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse(value.toString());
  }

  // ------------------------------------------------------------
  // 0. AUTH & ROLES
  // ------------------------------------------------------------

  /// Fetch the role for the currently logged-in user from public.profiles.
  Future<String?> fetchCurrentUserRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return profile?['role']?.toString();
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

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

      List<Map<String, dynamic>> rawList =
          List<Map<String, dynamic>>.from(existing);

      // Fetch user full name from profiles table or auth metadata
      String selfName = 'Self';
      try {
        final profile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null &&
            profile['full_name'] != null &&
            profile['full_name'].toString().isNotEmpty) {
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
            (p['name'] ?? '').toString().trim().toLowerCase() ==
            selfName.trim().toLowerCase());
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

    final response = await _client
        .from('patients')
        .insert({
          'user_id': userId,
          'name': name,
          'patient_mobile': mobile,
          'relationship': relationship,
          'date_of_birth': dob,
          'gender': gender,
        })
        .select()
        .single();

    return response;
  }

  // ------------------------------------------------------------
  // 3. APPOINTMENT BOOKINGS
  // ------------------------------------------------------------

  /// Create a new booking slot and return the created record
  Future<Map<String, dynamic>?> createBooking({
    required int patientId,
    required String doctorId, // Doctor ID is UUID String
    required int availabilityId,
    required String bookingDate,
  }) async {
    try {
      // Unique booking code for QR (e.g., MQ-948210)
      final String bookingCode =
          'MQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final int queueNumber = Random().nextInt(89) + 10;

      final Map<String, dynamic> payload = {
        'booking_code': bookingCode,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'availability_id': availabilityId,
        'booking_date': bookingDate,
        'queue_number': queueNumber,
        'status': 'WAITING',
      };

      try {
        final response = await _client
            .from('bookings')
            .insert(payload)
            .select('*, doctors(*), patients(*)')
            .single();
        return response;
      } catch (selectErr) {
        // Fallback simple insert if nested relation select has schema constraints
        final response = await _client
            .from('bookings')
            .insert(payload)
            .select()
            .single();
        return response;
      }
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  /// Lookup booking by QR code or booking code.
  Future<Map<String, dynamic>?> findBookingByCode(String bookingCode) async {
    try {
      final response = await _client
          .from('bookings')
          .select('*, patients(name), doctors(name)')
          .eq('booking_code', bookingCode)
          .maybeSingle();

      return response == null ? null : Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error finding booking by code: $e');
      return null;
    }
  }

  /// Update a booking status by booking id.
  Future<bool> updateBookingStatus({
    required dynamic bookingId,
    required String status,
  }) async {
    try {
      await _client
          .from('bookings')
          .update({'status': status.toUpperCase()})
          .eq('booking_id', _parseBookingId(bookingId));
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Update the booking date for an existing appointment.
  Future<bool> updateBookingDate({
    required dynamic bookingId,
    required String bookingDate,
  }) async {
    try {
      await _client
          .from('bookings')
          .update({'booking_date': bookingDate})
          .eq('booking_id', _parseBookingId(bookingId));
      return true;
    } catch (e) {
      print('Error updating booking date: $e');
      return false;
    }
  }

  /// Fetch active bookings with patient and doctor details for reception views.
  Future<List<Map<String, dynamic>>> fetchActiveBookings() async {
    try {
      final response = await _client
          .from('bookings')
          .select('*, patients(name), doctors(name)')
          .not('status', 'in', '("COMPLETED","CANCELLED")')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching active bookings: $e');
      return [];
    }
  }

  Map<String, dynamic>? _mapDoctorResponse(dynamic response) {
    if (response == null) return null;
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map<String, dynamic>);
    }
    return null;
  }

  /// Create a new doctor record.
  Future<Map<String, dynamic>?> createDoctor({
    required String name,
    required int yearsExperience,
  }) async {
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': name,
      };
      if (yearsExperience > 0) {
        payload['years_experience'] = yearsExperience;
      }

      final response = await _client
          .from('doctors')
          .insert(payload)
          .select('id, name, years_experience');

      return _mapDoctorResponse(response);
    } catch (e) {
      print('Error creating doctor: $e');
      return null;
    }
  }

  /// Update an existing doctor profile.
  Future<bool> updateDoctor({
    required String doctorId, // Doctor ID is UUID
    required String name,
    required int yearsExperience,
  }) async {
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': name,
      };
      if (yearsExperience > 0) {
        payload['years_experience'] = yearsExperience;
      }

      await _client.from('doctors').update(payload).eq('id', doctorId);
      return true;
    } catch (e) {
      print('Error updating doctor: $e');
      return false;
    }
  }

  /// Insert multiple doctor availability slots.
  Future<bool> createDoctorAvailabilityBatch({
    required String doctorId, // Doctor ID is UUID
    required List<Map<String, dynamic>> availabilities,
  }) async {
    try {
      final enriched = availabilities.map((slot) {
        return {...slot, 'doctor_id': doctorId};
      }).toList();
      await _client.from('doctor_availability').insert(enriched);
      return true;
    } catch (e) {
      print('Error creating doctor availability batch: $e');
      return false;
    }
  }

  /// Live stream trigger for booking table changes (used to refresh enriched data).
  Stream<List<Map<String, dynamic>>> streamActiveBookings() {
    return _client
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .order('created_at', ascending: false);
  }
}