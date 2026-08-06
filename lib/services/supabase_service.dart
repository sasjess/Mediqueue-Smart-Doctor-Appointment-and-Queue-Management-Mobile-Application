import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static Future<List<Map<String, dynamic>>>? _specialtiesCache;

  int _parseBookingId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse(value.toString());
  }

  String _normalizeBookingDate(String bookingDate) {
    try {
      final parsed = DateTime.parse(bookingDate.trim());
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return bookingDate.trim();
    }
  }

  String _expectedDutyStatusForDate(String? dutyDate) {
    if (dutyDate == null || dutyDate.trim().isEmpty) return 'UPCOMING';

    try {
      final parsed = DateTime.parse(dutyDate.trim());
      final slotDay = DateTime(parsed.year, parsed.month, parsed.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (slotDay.isBefore(today)) return 'COMPLETED';
      if (slotDay.isAfter(today)) return 'UPCOMING';
      return 'AVAILABLE';
    } catch (_) {
      return 'UPCOMING';
    }
  }

  Future<bool> _syncDoctorAvailabilityStatuses(
    List<Map<String, dynamic>> doctors,
  ) async {
    var changed = false;

    for (final doctor in doctors) {
      final slots = List<dynamic>.from(doctor['doctor_availability'] ?? const []);

      for (final rawSlot in slots) {
        if (rawSlot is! Map) continue;

        final slot = Map<String, dynamic>.from(rawSlot);
        final availabilityId = slot['availability_id'];
        if (availabilityId == null) continue;

        final current = slot['duty_status']?.toString().trim().toUpperCase();
        if (current == 'LATE') continue;

        final expected = _expectedDutyStatusForDate(slot['duty_date']?.toString());
        if (current == expected) continue;

        await _client
            .from('doctor_availability')
            .update({'duty_status': expected})
            .eq('availability_id', availabilityId);
        changed = true;
      }
    }

    return changed;
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
      debugPrint('Error fetching user role: $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // 1. DOCTORS & AVAILABILITY
  // ------------------------------------------------------------

  /// Fetch all active doctors with their today's schedule
  Future<List<Map<String, dynamic>>> fetchDoctorsWithAvailability() async {
    try {
      final response = await _client
          .from('doctors')
          .select('*, doctor_availability(*), specialties(id,name)');

      final doctors = List<Map<String, dynamic>>.from(response);
      final changed = await _syncDoctorAvailabilityStatuses(doctors);
      if (!changed) return doctors;

      final refreshed = await _client
          .from('doctors')
          .select('*, doctor_availability(*), specialties(id,name)');
      return List<Map<String, dynamic>>.from(refreshed);
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSpecialties() async {
    try {
      final response = await _client.from('specialties').select('id, name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching specialties: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSpecialtiesCached() {
    _specialtiesCache ??= fetchSpecialties();
    return _specialtiesCache!;
  }

  Future<void> clearSpecialtiesCache() async {
    _specialtiesCache = null;
  }

  // --- CREATE DOCTOR ---
  Future<Map<String, dynamic>?> createDoctor({
    required String name,
    required String specialist,
    required int yearsExperience,
    String? specialtyId,
    String? about,
    String? profileImage,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'years_experience': yearsExperience,
      };

      final normalizedSpecialist = specialist.trim();
      final normalizedSpecialtyId = specialtyId?.trim() ?? '';
      final normalizedAbout = about?.trim() ?? '';

      if (normalizedSpecialtyId.isNotEmpty && _isValidUuid(normalizedSpecialtyId)) {
        payload['specialty_id'] = normalizedSpecialtyId;
      } else if (normalizedSpecialist.isNotEmpty && _isValidUuid(normalizedSpecialist)) {
        payload['specialty_id'] = normalizedSpecialist;
      }

      if (normalizedAbout.isNotEmpty) {
        payload['about'] = normalizedAbout;
      } else if (normalizedSpecialist.isNotEmpty && !_isValidUuid(normalizedSpecialist)) {
        payload['about'] = normalizedSpecialist;
      }

      if (profileImage != null && profileImage.trim().isNotEmpty) {
        payload['image_url'] = profileImage.trim();
      }

      try {
        final response = await _client
            .from('doctors')
            .insert(payload)
            .select()
            .single();

        return response;
      } catch (e) {
        debugPrint('Error creating doctor: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('Error creating doctor: $e');
      rethrow;
    }
  }

  // --- UPDATE DOCTOR ---
  Future<bool> updateDoctor({
    required String doctorId,
    required String name,
    required String specialist,
    required int yearsExperience,
    String? specialtyId,
    String? about,
    String? profileImage,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'years_experience': yearsExperience,
      };

      final normalizedSpecialist = specialist.trim();
      final normalizedSpecialtyId = specialtyId?.trim() ?? '';
      final normalizedAbout = about?.trim() ?? '';

      if (normalizedSpecialtyId.isNotEmpty && _isValidUuid(normalizedSpecialtyId)) {
        payload['specialty_id'] = normalizedSpecialtyId;
      } else if (normalizedSpecialist.isNotEmpty && _isValidUuid(normalizedSpecialist)) {
        payload['specialty_id'] = normalizedSpecialist;
      }

      if (normalizedAbout.isNotEmpty) {
        payload['about'] = normalizedAbout;
      } else if (normalizedSpecialist.isNotEmpty && !_isValidUuid(normalizedSpecialist)) {
        payload['about'] = normalizedSpecialist;
      }

      if (profileImage != null && profileImage.trim().isNotEmpty) {
        payload['image_url'] = profileImage.trim();
      }

      try {
        await _client.from('doctors').update(payload).eq('id', doctorId);
        return true;
      } catch (firstError) {
        try {
          await _client.from('doctors').update(payload).eq('doctor_id', doctorId);
          return true;
        } catch (secondError) {
          debugPrint('Error updating doctor with both id variants: $firstError | $secondError');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error updating doctor: $e');
      rethrow;
    }
  }

  // Helper method to check if string is a valid UUID format
  bool _isValidUuid(String uuid) {
    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegExp.hasMatch(uuid);
  }

  Future<void> _deleteDoctorByColumn(String doctorId, String columnName) async {
    await _client.from('doctors').delete().eq(columnName, doctorId);
  }

  /// Delete a doctor and clean up their schedules/availabilities.
  Future<bool> deleteDoctor(String doctorId) async {
    try {
      await _client
          .from('doctor_availability')
          .delete()
          .eq('doctor_id', doctorId);

      try {
        await _deleteDoctorByColumn(doctorId, 'id');
        return true;
      } catch (firstError) {
        try {
          await _deleteDoctorByColumn(doctorId, 'doctor_id');
          return true;
        } catch (secondError) {
          debugPrint('Error deleting doctor with both id variants: $firstError | $secondError');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error deleting doctor: $e');
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
      debugPrint('Error creating doctor availability batch: $e');
      return false;
    }
  }

  Future<bool> updateDoctorAvailabilityStatus({
    required dynamic availabilityId,
    required String dutyStatus,
    int? delayMinutes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'duty_status': dutyStatus,
      };

      if (delayMinutes != null) {
        payload['delay_minutes'] = delayMinutes;
      }

      await _client
          .from('doctor_availability')
          .update(payload)
          .eq('availability_id', availabilityId);
      return true;
    } catch (e) {
      debugPrint('Error updating doctor availability status: $e');
      return false;
    }
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

      // Fetch user full name/phone from profiles table or auth metadata
      String selfName = 'Self';
      String selfPhone = '';
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

        if (profile != null && profile['phone'] != null) {
          selfPhone = profile['phone'].toString().trim();
        }
      } catch (_) {}

      if (selfPhone.isEmpty) {
        selfPhone =
            (user.phone ?? user.userMetadata?['phone'] ?? '').toString().trim();
      }

      // Check if a "Self" patient record exists
      final normalizedSelfName = selfName.trim().toLowerCase();
      final hasSelf = rawList.any(
        (p) => (p['relationship'] ?? '').toString().trim().toLowerCase() == 'self',
      );

      if (!hasSelf) {
        final firstSelfLikeIndex = rawList.indexWhere((p) =>
            (p['name'] ?? '').toString().trim().toLowerCase() == normalizedSelfName);

        if (firstSelfLikeIndex != -1) {
          // Persist the Self relationship so future fetches do not try to create again.
          final candidate = rawList[firstSelfLikeIndex];
          final candidateId = candidate['patient_id'];
          final candidateName = (candidate['name'] ?? '').toString().trim();
          final candidateMobile = (candidate['patient_mobile'] ?? '').toString().trim();
          final updatePayload = <String, dynamic>{'relationship': 'Self'};
          if (candidateName.isEmpty && selfName.trim().isNotEmpty) {
            updatePayload['name'] = selfName;
          }
          if (candidateMobile.isEmpty && selfPhone.isNotEmpty) {
            updatePayload['patient_mobile'] = selfPhone;
          }

          if (candidateId != null) {
            try {
              await _client
                  .from('patients')
                  .update(updatePayload)
                  .eq('patient_id', candidateId);
            } catch (_) {}
          }
          rawList[firstSelfLikeIndex]['relationship'] = 'Self';
          if (candidateName.isEmpty && selfName.trim().isNotEmpty) {
            rawList[firstSelfLikeIndex]['name'] = selfName;
          }
          if (candidateMobile.isEmpty && selfPhone.isNotEmpty) {
            rawList[firstSelfLikeIndex]['patient_mobile'] = selfPhone;
          }
        } else {
          final newSelf = await _client.from('patients').insert({
            'user_id': user.id,
            'name': selfName,
            'relationship': 'Self',
            'patient_mobile': selfPhone,
          }).select().single();
          rawList.insert(0, Map<String, dynamic>.from(newSelf));
        }
      } else {
        // Keep existing Self row complete when previously inserted with empty fields.
        final selfIndex = rawList.indexWhere(
          (p) =>
              (p['relationship'] ?? '').toString().trim().toLowerCase() == 'self',
        );
        if (selfIndex != -1) {
          final selfRow = rawList[selfIndex];
          final selfId = selfRow['patient_id'];
          final currentName = (selfRow['name'] ?? '').toString().trim();
          final currentMobile = (selfRow['patient_mobile'] ?? '').toString().trim();
          final patch = <String, dynamic>{};

          if (currentName.isEmpty && selfName.trim().isNotEmpty) {
            patch['name'] = selfName;
            rawList[selfIndex]['name'] = selfName;
          }
          if (currentMobile.isEmpty && selfPhone.isNotEmpty) {
            patch['patient_mobile'] = selfPhone;
            rawList[selfIndex]['patient_mobile'] = selfPhone;
          }

          if (patch.isNotEmpty && selfId != null) {
            try {
              await _client
                  .from('patients')
                  .update(patch)
                  .eq('patient_id', selfId);
            } catch (_) {}
          }
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
      debugPrint('Error getting patients: $e');
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

  Future<Map<String, dynamic>> _hydrateBookingDetails(
    Map<String, dynamic> booking,
  ) async {
    final hydrated = Map<String, dynamic>.from(booking);

    final patientId = booking['patient_id'];
    if (patientId != null) {
      final patient = await _client
          .from('patients')
          .select('patient_id,name')
          .eq('patient_id', patientId)
          .maybeSingle();
      if (patient != null) {
        hydrated['patients'] = patient;
      }
    }

    final doctorId = booking['doctor_id'];
    if (doctorId != null) {
      final doctor = await _client
          .from('doctors')
          .select('id,name')
          .eq('id', doctorId)
          .maybeSingle();

      if (doctor != null) {
        hydrated['doctors'] = doctor;
      }
    }

    return hydrated;
  }

  /// Create a new booking slot and return the created record.
  Future<Map<String, dynamic>?> createBooking({
    required int patientId,
    required String doctorId,
    required int availabilityId,
    required String bookingDate,
    String status = 'BOOKED',
    int? queueNumber,
  }) async {
    try {
      final String bookingCode =
          'MQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final normalizedBookingDate = _normalizeBookingDate(bookingDate);
      final int resolvedQueueNumber = queueNumber ??
          await _nextQueueNumber(
            doctorId: doctorId,
            bookingDate: normalizedBookingDate,
          );

      final Map<String, dynamic> payload = {
        'booking_code': bookingCode,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'availability_id': availabilityId,
        'booking_date': normalizedBookingDate,
        'queue_number': resolvedQueueNumber,
        'status': status.toUpperCase(),
      };

      final response = await _client
          .from('bookings')
          .insert(payload)
          .select()
          .single();

      return await _hydrateBookingDetails(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error creating booking: $e');
      rethrow;
    }
  }

  Future<int> _nextQueueNumber({
    required String doctorId,
    required String bookingDate,
  }) async {
    try {
      final normalizedBookingDate = _normalizeBookingDate(bookingDate);
      final parsed = DateTime.tryParse(normalizedBookingDate);
      if (parsed == null) {
        return 1;
      }

      final dayStart =
          '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      final nextDay = parsed.add(const Duration(days: 1));
      final nextDayStart =
          '${nextDay.year.toString().padLeft(4, '0')}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}';

      final response = await _client
          .from('bookings')
          .select('queue_number')
          .eq('doctor_id', doctorId)
          .gte('booking_date', dayStart)
          .lt('booking_date', nextDayStart);

      final queueNumbers = List<dynamic>.from(response)
          .map((row) => int.tryParse(row['queue_number']?.toString() ?? ''))
          .whereType<int>()
          .toList();

      if (queueNumbers.isEmpty) {
        return 1;
      }

      return queueNumbers.reduce(max) + 1;
    } catch (e) {
      debugPrint('Error calculating next queue number: $e');
      return 1;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProfilesWithActiveTickets() async {
    try {
      final profiles = await fetchPatientProfiles();
      if (profiles.isEmpty) return [];

      final patientIds = profiles
          .map((p) => p['patient_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (patientIds.isEmpty) return [];

      final activeBookings = await _client
          .from('bookings')
          .select('patient_id')
          .filter('patient_id', 'in', patientIds)
          .not('status', 'in', '("COMPLETED","CANCELLED")');

      final activePatientIds = List<dynamic>.from(activeBookings)
          .map((b) => b['patient_id']?.toString())
          .whereType<String>()
          .toSet();

      return profiles
          .where((p) => activePatientIds.contains(p['patient_id']?.toString()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching profiles with active tickets: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchActiveTicketsForPatient({
    required int patientId,
  }) async {
    try {
      final response = await _client
          .from('bookings')
          .select(
            'booking_id,booking_code,booking_date,queue_number,status,availability_id,doctor_id,doctors(id,name),doctor_availability(start_time,end_time,duty_date)',
          )
          .eq('patient_id', patientId)
          .not('status', 'in', '("COMPLETED","CANCELLED")')
          .order('booking_date', ascending: true)
          .order('queue_number', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching active tickets for patient: $e');
      return [];
    }
  }

  /// Lookup booking by QR code or booking code.
  Future<Map<String, dynamic>?> findBookingByCode(String bookingCode) async {
    try {
      final response = await _client
          .from('bookings')
          .select('*')
          .eq('booking_code', bookingCode)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return await _hydrateBookingDetails(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error finding booking by code: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findBookingById(dynamic bookingId) async {
    try {
      final response = await _client
          .from('bookings')
          .select('*')
          .eq('booking_id', _parseBookingId(bookingId))
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error finding booking by id: $e');
      return null;
    }
  }

  Future<void> _completePreviousServingBooking({
    required dynamic currentBookingId,
    required String? doctorId,
    required String? bookingDate,
  }) async {
    if (doctorId == null || doctorId.isEmpty) return;
    if (bookingDate == null || bookingDate.isEmpty) return;

    final previousServing = await _client
        .from('bookings')
        .select('booking_id')
        .eq('doctor_id', doctorId)
        .eq('booking_date', bookingDate)
        .eq('status', 'SERVING')
        .neq('booking_id', _parseBookingId(currentBookingId))
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (previousServing == null) {
      return;
    }

    await _client
        .from('bookings')
        .update({'status': 'COMPLETED'})
        .eq('booking_id', _parseBookingId(previousServing['booking_id']));
  }

  Future<bool> markBookingArrivedByCode(String bookingCode) async {
    try {
      final booking = await findBookingByCode(bookingCode);
      if (booking == null) return false;

      final currentStatus = booking['status']?.toString().toUpperCase() ?? '';
      if (currentStatus == 'ARRIVED' ||
          currentStatus == 'SERVING' ||
          currentStatus == 'COMPLETED' ||
          currentStatus == 'CANCELLED') {
        return true;
      }

      await _client
          .from('bookings')
          .update({'status': 'ARRIVED'})
          .eq('booking_id', _parseBookingId(booking['booking_id']));
      return true;
    } catch (e) {
      debugPrint('Error marking booking as arrived: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> skipAndRequeueBookingByCode(
    String bookingCode,
  ) async {
    try {
      final booking = await findBookingByCode(bookingCode);
      if (booking == null) return null;

      final bookingId = _parseBookingId(booking['booking_id']);
      final doctorId = booking['doctor_id']?.toString();
      final patientId = booking['patient_id'] is int
          ? booking['patient_id'] as int
          : int.tryParse(booking['patient_id']?.toString() ?? '') ?? 0;
      final availabilityId = booking['availability_id'] is int
          ? booking['availability_id'] as int
          : int.tryParse(booking['availability_id']?.toString() ?? '') ?? 0;
      final bookingDate = booking['booking_date']?.toString() ?? '';

      if (patientId <= 0 ||
          doctorId == null ||
          doctorId.isEmpty ||
          availabilityId <= 0 ||
          bookingDate.isEmpty) {
        return null;
      }

      await _client
          .from('bookings')
          .update({'status': 'CANCELLED'})
          .eq('booking_id', bookingId);

      final nextQueue = await _nextQueueNumber(
        doctorId: doctorId,
        bookingDate: bookingDate,
      );

      return await createBooking(
        patientId: patientId,
        doctorId: doctorId,
        availabilityId: availabilityId,
        bookingDate: bookingDate,
        status: 'BOOKED',
        queueNumber: nextQueue,
      );
    } catch (e) {
      debugPrint('Error requeueing booking: $e');
      return null;
    }
  }

  Future<bool> markBookingServingByCode(String bookingCode) async {
    try {
      final booking = await findBookingByCode(bookingCode);
      if (booking == null) return false;

      final bookingId = _parseBookingId(booking['booking_id']);
      final currentStatus = booking['status']?.toString().toUpperCase() ?? '';
      final doctorId = booking['doctor_id']?.toString();
      final bookingDate = booking['booking_date']?.toString();

      await _completePreviousServingBooking(
        currentBookingId: bookingId,
        doctorId: doctorId,
        bookingDate: bookingDate,
      );

      if (currentStatus != 'SERVING') {
        await _client
            .from('bookings')
            .update({'status': 'SERVING'})
            .eq('booking_id', bookingId);
      }

      return true;
    } catch (e) {
      debugPrint('Error marking booking as serving: $e');
      return false;
    }
  }

  Future<bool> markBookingCompletedByCode(String bookingCode) async {
    try {
      final booking = await findBookingByCode(bookingCode);
      if (booking == null) return false;

      final bookingId = _parseBookingId(booking['booking_id']);
      final currentStatus = booking['status']?.toString().toUpperCase() ?? '';

      if (currentStatus == 'COMPLETED') {
        return true;
      }

      if (currentStatus == 'CANCELLED') {
        return false;
      }

      await _client
          .from('bookings')
          .update({'status': 'COMPLETED'})
          .eq('booking_id', bookingId);

      return true;
    } catch (e) {
      debugPrint('Error marking booking as completed: $e');
      return false;
    }
  }

  /// Update a booking status by booking id.
  Future<bool> updateBookingStatus({
    required dynamic bookingId,
    required String status,
  }) async {
    try {
      final normalizedStatus = status.toUpperCase();

      if (normalizedStatus == 'SERVING') {
        final booking = await _findBookingById(bookingId);
        if (booking == null) return false;

        await _completePreviousServingBooking(
          currentBookingId: bookingId,
          doctorId: booking['doctor_id']?.toString(),
          bookingDate: booking['booking_date']?.toString(),
        );
      }

      await _client
          .from('bookings')
          .update({'status': normalizedStatus})
          .eq('booking_id', _parseBookingId(bookingId));
      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
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
      debugPrint('Error updating booking date: $e');
      return false;
    }
  }

  /// Fetch active bookings with patient, doctor, and availability details.
  Future<List<Map<String, dynamic>>> fetchActiveBookings({
    bool todayOnly = false,
  }) async {
    try {
      final response = todayOnly
          ? await (() {
              final now = DateTime.now();
              final today =
                  '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

              return _client
                  .from('bookings')
                  .select('*')
                  .eq('booking_date', today)
                  .not('status', 'in', '("COMPLETED","CANCELLED")')
                  .order('created_at', ascending: false);
            })()
          : await _client
              .from('bookings')
              .select('*')
              .not('status', 'in', '("COMPLETED","CANCELLED")')
              .order('created_at', ascending: false);

      final bookings = List<Map<String, dynamic>>.from(response);
      if (bookings.isEmpty) {
        return [];
      }

      final patientIds = bookings
          .map((booking) => booking['patient_id'])
          .where((value) => value != null)
          .toSet()
          .toList();
      final doctorIds = bookings
          .map((booking) => booking['doctor_id'])
          .where((value) => value != null)
          .toSet()
          .toList();
        final availabilityIds = bookings
          .map((booking) => booking['availability_id'])
          .where((value) => value != null)
          .toSet()
          .toList();

      final patientLookup = <String, Map<String, dynamic>>{};
      if (patientIds.isNotEmpty) {
        final patientsResponse = await _client
            .from('patients')
            .select('patient_id,name')
            .filter('patient_id', 'in', patientIds);

        for (final patient in patientsResponse) {
          final patientKey = patient['patient_id']?.toString();
          if (patientKey != null) {
            patientLookup[patientKey] = Map<String, dynamic>.from(patient);
          }
        }
      }

      final doctorLookup = <String, Map<String, dynamic>>{};
      if (doctorIds.isNotEmpty) {
        final doctorsResponse = await _client
            .from('doctors')
            .select('id,name')
            .filter('id', 'in', doctorIds);

        for (final doctor in doctorsResponse) {
          final doctorKey = doctor['id']?.toString();
          if (doctorKey != null) {
            doctorLookup[doctorKey] = Map<String, dynamic>.from(doctor);
          }
        }
      }

      final availabilityLookup = <String, Map<String, dynamic>>{};
      if (availabilityIds.isNotEmpty) {
        final availabilityResponse = await _client
            .from('doctor_availability')
            .select('availability_id,start_time,end_time,duty_date')
            .filter('availability_id', 'in', availabilityIds);

        for (final slot in availabilityResponse) {
          final slotKey = slot['availability_id']?.toString();
          if (slotKey != null) {
            availabilityLookup[slotKey] = Map<String, dynamic>.from(slot);
          }
        }
      }

      return bookings.map((booking) {
        final enriched = Map<String, dynamic>.from(booking);
        final patientKey = booking['patient_id']?.toString();
        if (patientKey != null && patientLookup.containsKey(patientKey)) {
          enriched['patients'] = patientLookup[patientKey];
        }

        final doctorKey = booking['doctor_id']?.toString();
        if (doctorKey != null && doctorLookup.containsKey(doctorKey)) {
          enriched['doctors'] = doctorLookup[doctorKey];
        }

        final availabilityKey = booking['availability_id']?.toString();
        if (availabilityKey != null &&
            availabilityLookup.containsKey(availabilityKey)) {
          enriched['availability'] = availabilityLookup[availabilityKey];
        }

        return enriched;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching active bookings: $e');
      return [];
    }
  }

  /// Live stream trigger for booking table changes (used to refresh enriched data).
  Stream<List<Map<String, dynamic>>> streamActiveBookings({
    bool todayOnly = false,
  }) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .order('created_at', ascending: false)
        .asyncMap((_) => fetchActiveBookings(todayOnly: todayOnly));
  }
}

