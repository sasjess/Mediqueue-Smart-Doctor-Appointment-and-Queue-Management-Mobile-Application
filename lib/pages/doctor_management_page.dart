import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:mediqueue/services/supabase_service.dart';

class DoctorManagementPage extends StatefulWidget {
  const DoctorManagementPage({super.key});

  @override
  State<DoctorManagementPage> createState() => _DoctorManagementPageState();
}

class DoctorAvailabilityEntry {
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String dutyStatus;

  DoctorAvailabilityEntry({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.dutyStatus = 'AVAILABLE',
  });
}

class _DoctorManagementPageState extends State<DoctorManagementPage> {
  final SupabaseService _supabaseService = SupabaseService();
  late Future<List<Map<String, dynamic>>> _doctorsFuture;
  bool _isSyncingStatuses = false;

  DateTime? _parseSlotDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final date = DateTime.parse(dateStr.trim());
      final timeParts = (timeStr ?? '').split(':');
      final hour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '0') ?? 0;
      final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _derivedDutyStatus(Map<String, dynamic> slot) {
    final storedStatus = slot['duty_status']?.toString().trim().toUpperCase();
    if (storedStatus == 'LATE') return 'LATE';

    final now = DateTime.now();
    final dateOnly = slot['duty_date']?.toString();
    final startAt = _parseSlotDateTime(dateOnly, slot['start_time']?.toString());
    final endAt = _parseSlotDateTime(dateOnly, slot['end_time']?.toString());

    if (startAt == null || endAt == null) {
      return storedStatus ?? 'UPCOMING';
    }

    final today = DateTime(now.year, now.month, now.day);
    final slotDay = DateTime(startAt.year, startAt.month, startAt.day);

    if (slotDay.isBefore(today)) return 'COMPLETED';
    if (slotDay.isAfter(today)) return 'UPCOMING';
    if (now.isBefore(startAt)) return 'AVAILABLE TODAY';
    if (now.isAfter(endAt)) return 'COMPLETED';
    return 'ON DUTY';
  }

  bool _isTodaySlot(Map<String, dynamic> slot) {
    final dateStr = slot['duty_date']?.toString();
    if (dateStr == null || dateStr.trim().isEmpty) return false;

    try {
      final slotDate = DateTime.parse(dateStr.trim());
      final now = DateTime.now();
      return slotDate.year == now.year &&
          slotDate.month == now.month &&
          slotDate.day == now.day;
    } catch (_) {
      return false;
    }
  }

  String _dateBasedDutyStatus(DateTime slotDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final slotDay = DateTime(slotDate.year, slotDate.month, slotDate.day);

    if (slotDay.isBefore(today)) return 'COMPLETED';
    if (slotDay.isAfter(today)) return 'UPCOMING';
    return 'AVAILABLE';
  }

  Future<bool> _syncDateBasedStatusesIfNeeded(List<Map<String, dynamic>> slots) async {
    var hasUpdates = false;

    for (final slot in slots) {
      final dateStr = slot['duty_date']?.toString();
      final availabilityId = slot['availability_id'];
      if (dateStr == null || availabilityId == null) continue;

      try {
        final slotDate = DateTime.parse(dateStr.trim());
        final currentStatus = slot['duty_status']?.toString().trim().toUpperCase();
        final expectedStatus = _dateBasedDutyStatus(slotDate);

        if (currentStatus != expectedStatus) {
          await _supabaseService.updateDoctorAvailabilityStatus(
            availabilityId: availabilityId,
            dutyStatus: expectedStatus,
          );
          hasUpdates = true;
        }
      } catch (_) {
        continue;
      }
    }

    return hasUpdates;
  }

  Future<List<Map<String, dynamic>>> _loadDoctorsWithStatusSync() async {
    final doctors = await _supabaseService.fetchDoctorsWithAvailability();
    if (_isSyncingStatuses) return doctors;

    _isSyncingStatuses = true;
    try {
      var changed = false;
      for (final doctor in doctors) {
        final slots = List<Map<String, dynamic>>.from(
          (doctor['doctor_availability'] as List<dynamic>?) ?? [],
        );
        final updated = await _syncDateBasedStatusesIfNeeded(slots);
        if (updated) changed = true;
      }

      if (changed) {
        return await _supabaseService.fetchDoctorsWithAvailability();
      }

      return doctors;
    } finally {
      _isSyncingStatuses = false;
    }
  }

  Future<void> _updateAvailabilityStatus(
    Map<String, dynamic> slot,
    String status, {
    int? delayMinutes,
  }) async {
    final availabilityId = slot['availability_id'];
    if (availabilityId == null) {
      _showMessage('Unable to determine availability ID.', success: false);
      return;
    }

    final success = await _supabaseService.updateDoctorAvailabilityStatus(
      availabilityId: availabilityId,
      dutyStatus: status,
      delayMinutes: delayMinutes,
    );

    if (!success) {
      _showMessage('Unable to update slot status.', success: false);
      return;
    }

    _showMessage('Slot status updated to $status.');
    await _refreshDoctors();
  }

  void _showMessage(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2A7B3F) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _resolveDoctorId(Map<String, dynamic> doctor) {
    final id = doctor['id'] ?? doctor['doctor_id'];
    return id?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _doctorsFuture = _loadDoctorsWithStatusSync();
  }

  Future<void> _refreshDoctors() async {
    setState(() {
      _doctorsFuture = _loadDoctorsWithStatusSync();
    });
  }

  // --- DELETE DOCTOR DIALOG ---
  Future<void> _deleteDoctor(Map<String, dynamic> doctor) async {
    final doctorId = _resolveDoctorId(doctor);
    final doctorName = doctor['name'] ?? 'this doctor';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Doctor'),
        content: Text('Are you sure you want to delete Dr. $doctorName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && doctorId.isNotEmpty) {
      try {
        final success = await _supabaseService.deleteDoctor(doctorId);
        if (success) {
          _showMessage('Doctor deleted successfully.');
          _refreshDoctors();
        } else {
          _showMessage('Failed to delete doctor.', success: false);
        }
      } catch (e) {
        _showMessage('Error deleting doctor: $e', success: false);
      }
    }
  }

  Future<bool> _confirmDeleteAction({
    required String title,
    required String message,
    String confirmLabel = 'Delete',
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return confirm == true;
  }

  // --- CREATE / EDIT DOCTOR FORM (CLEAN BOTTOM SHEET) ---
  Future<void> _openDoctorForm({Map<String, dynamic>? doctor}) async {
    final specialtiesFuture = _supabaseService.fetchSpecialtiesCached();

    final nameController = TextEditingController(
      text: doctor?['name']?.toString() ?? '',
    );
    final aboutController = TextEditingController(
      text: doctor?['about']?.toString() ?? '',
    );
    final yearsController = TextEditingController(
      text: doctor?['years_experience']?.toString() ?? '0',
    );
    final photoUrlController = TextEditingController(
      text: doctor?['profile_image']?.toString() ??
          doctor?['image_url']?.toString() ??
          doctor?['photo_url']?.toString() ??
          '',
    );
    String? selectedSpecialtyId = doctor?['specialty_id']?.toString() ??
        (doctor?['specialties'] is Map
            ? doctor?['specialties']?['id']?.toString()
            : null);

    final List<DoctorAvailabilityEntry> availabilities = [];

    void addRow(StateSetter dialogSetState) {
      dialogSetState(() {
        availabilities.add(
          DoctorAvailabilityEntry(
            date: DateTime.now(),
            startTime: const TimeOfDay(hour: 9, minute: 0),
            endTime: const TimeOfDay(hour: 17, minute: 0),
          ),
        );
      });
    }

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(builderContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(builderContext).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Drag Handle Indicator
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        doctor == null ? 'Create Doctor' : 'Update Doctor',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E28),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: specialtiesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E8),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF8171E5),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading specialties...'),
                                ],
                              ),
                            );
                          }

                          final specialties = snapshot.data ?? [];
                          if (specialties.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E8),
                                ),
                              ),
                              child: const Text(
                                'No specialties found. Add specialties in Supabase first.',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }

                          final hasSelectedSpecialty = specialties.any(
                            (specialty) =>
                                specialty['id']?.toString() == selectedSpecialtyId,
                          );

                          return DropdownButtonFormField<String>(
                            initialValue:
                                hasSelectedSpecialty ? selectedSpecialtyId : null,
                            items: specialties.map((specialty) {
                              final specialtyId =
                                  specialty['id']?.toString() ?? '';
                              final specialtyName =
                                  specialty['name']?.toString() ?? 'Specialty';
                              return DropdownMenuItem<String>(
                                value: specialtyId,
                                child: Text(specialtyName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSpecialtyId = value;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Specialty',
                              prefixIcon: const Icon(
                                Icons.medical_services_outlined,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FE),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: aboutController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'About / Notes (Optional)',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: yearsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Years of Experience',
                          prefixIcon: const Icon(Icons.work_outline),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: photoUrlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Profile Image URL (Optional)',
                          prefixIcon: const Icon(Icons.image_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Paste from clipboard',
                            icon: const Icon(Icons.paste_outlined),
                            onPressed: () async {
                              final clipboard =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              final pastedText = clipboard?.text?.trim();
                              if (pastedText == null || pastedText.isEmpty) {
                                _showMessage(
                                  'Clipboard is empty.',
                                  success: false,
                                );
                                return;
                              }
                              photoUrlController.text = pastedText;
                              photoUrlController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                  offset: photoUrlController.text.length,
                                ),
                              );
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (doctor != null) ...[
                        const Text(
                          'Add Availability Slots',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: availabilities.map((entry) {
                            final index = availabilities.indexOf(entry);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E4F4),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Slot ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () async {
                                          final confirmed = await _confirmDeleteAction(
                                            title: 'Remove slot?',
                                            message:
                                                'Are you sure you want to remove Slot ${index + 1} from this doctor schedule?',
                                            confirmLabel: 'Remove',
                                          );
                                          if (!confirmed) return;

                                          setState(() {
                                            availabilities.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: builderContext,
                                        initialDate: entry.date,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365),
                                        ),
                                      );
                                      if (date != null) {
                                        setState(() => entry.date = date);
                                      }
                                    },
                                    child: Text(
                                      'Date: ${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final time = await showTimePicker(
                                              context: builderContext,
                                              initialTime: entry.startTime,
                                            );
                                            if (time != null) {
                                              setState(
                                                () => entry.startTime = time,
                                              );
                                            }
                                          },
                                          child: Text(
                                            'From: ${entry.startTime.format(builderContext)}',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final time = await showTimePicker(
                                              context: builderContext,
                                              initialTime: entry.endTime,
                                            );
                                            if (time != null) {
                                              setState(
                                                () => entry.endTime = time,
                                              );
                                            }
                                          },
                                          child: Text(
                                            'To: ${entry.endTime.format(builderContext)}',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        TextButton.icon(
                          onPressed: () => addRow(setState),
                          icon: const Icon(Icons.add,
                              color: Color.fromARGB(255, 158, 151, 203)),
                          label: const Text(
                            'Add Slot',
                            style: TextStyle(color: Color(0xFF8171E5)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.of(modalContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8171E5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final about = aboutController.text.trim();
                                final photoUrl = photoUrlController.text.trim();
                                final years =
                                    int.tryParse(yearsController.text.trim()) ??
                                        0;

                                if (name.isEmpty) {
                                  _showMessage('Doctor name is required.',
                                      success: false);
                                  return;
                                }

                                try {
                                  final doctorId = doctor != null
                                      ? _resolveDoctorId(doctor)
                                      : '';

                                  if (doctor == null) {
                                    final created =
                                        await _supabaseService.createDoctor(
                                      name: name,
                                      specialist: selectedSpecialtyId ?? about,
                                      yearsExperience: years,
                                      specialtyId: selectedSpecialtyId,
                                      about: about,
                                      profileImage: photoUrl,
                                    );

                                    if (created == null) {
                                      _showMessage(
                                        'Unable to save doctor. Please try again.',
                                        success: false,
                                      );
                                      return;
                                    }

                                    final createdDoctorId =
                                        _resolveDoctorId(created);

                                    if (availabilities.isNotEmpty &&
                                        createdDoctorId.isNotEmpty) {
                                      await _supabaseService
                                          .createDoctorAvailabilityBatch(
                                        doctorId: createdDoctorId,
                                        availabilities:
                                            availabilities.map((entry) {
                                          return {
                                            'duty_date': entry.date
                                                .toIso8601String()
                                                .split('T')
                                                .first,
                                            'start_time': entry.startTime
                                                .format(builderContext),
                                            'end_time': entry.endTime
                                                .format(builderContext),
                                            'duty_status': _dateBasedDutyStatus(entry.date),
                                          };
                                        }).toList(),
                                      );
                                    }
                                  } else {
                                    if (doctorId.isEmpty) {
                                      _showMessage(
                                        'Unable to determine doctor ID.',
                                        success: false,
                                      );
                                      return;
                                    }

                                    final updated =
                                        await _supabaseService.updateDoctor(
                                      doctorId: doctorId,
                                      name: name,
                                      specialist: selectedSpecialtyId ?? about,
                                      yearsExperience: years,
                                      specialtyId: selectedSpecialtyId,
                                      about: about,
                                      profileImage: photoUrl,
                                    );
                                    if (!updated) {
                                      _showMessage(
                                        'Unable to update doctor. Please try again.',
                                        success: false,
                                      );
                                      return;
                                    }
                                  }

                                  if (!mounted) return;
                                  Navigator.of(modalContext).pop(true);
                                } catch (e) {
                                  if (!mounted) return;
                                  final message = e.toString();
                                  debugPrint('Doctor save failed: $message');
                                  _showMessage(
                                    message.contains('PostgrestException')
                                        ? 'Save failed: ${message.split('message:').last.trim()}'
                                        : 'Error saving doctor: $message',
                                    success: false,
                                  );
                                }
                              },
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      _showMessage('Doctor saved successfully.');
      await _refreshDoctors();
    }
  }

  // --- AVAILABILITY SHEET ---
  Future<void> _openAvailabilitySheet(Map<String, dynamic> doctor) async {
    final allSlots = List<Map<String, dynamic>>.from(
      (doctor['doctor_availability'] as List<dynamic>?) ?? [],
    );
    await _syncDateBasedStatusesIfNeeded(allSlots);
    final existingSlots = allSlots.where(_isTodaySlot).toList();

    final List<DoctorAvailabilityEntry> availabilities = [
      DoctorAvailabilityEntry(
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
      ),
    ];

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Manage Availability Slots'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (existingSlots.isNotEmpty) ...[
                      const Text(
                        'Today Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...existingSlots.map((slot) {
                        final status = _derivedDutyStatus(slot);
                        final statusColor = status == 'ON DUTY'
                            ? const Color(0xFF2A7B3F)
                            : status == 'LATE'
                                ? Colors.redAccent
                                : status == 'AVAILABLE TODAY'
                                    ? const Color(0xFF8171E5)
                                    : status == 'COMPLETED'
                                        ? Colors.grey
                                        : const Color(0xFF6B5BCD);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FE),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6E6F2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${slot['duty_date'] ?? ''}  ${slot['start_time'] ?? ''} - ${slot['end_time'] ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => _updateAvailabilityStatus(
                                      slot,
                                      'UPCOMING',
                                    ),
                                    child: const Text('Upcoming'),
                                  ),
                                  TextButton(
                                    onPressed: () => _updateAvailabilityStatus(
                                      slot,
                                      'AVAILABLE TODAY',
                                    ),
                                    child: const Text('Available Today'),
                                  ),
                                  TextButton(
                                    onPressed: () => _updateAvailabilityStatus(
                                      slot,
                                      'ON DUTY',
                                    ),
                                    child: const Text('On Duty'),
                                  ),
                                  TextButton(
                                    onPressed: () => _updateAvailabilityStatus(
                                      slot,
                                      'COMPLETED',
                                    ),
                                    child: const Text('Completed'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final delayController =
                                          TextEditingController();
                                      final delay = await showDialog<int?>(
                                        context: dialogContext,
                                        builder: (delayContext) => AlertDialog(
                                          title: const Text('Mark Doctor Late'),
                                          content: TextField(
                                            controller: delayController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Delay minutes',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                delayContext,
                                              ),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(
                                                  delayContext,
                                                  int.tryParse(
                                                        delayController.text.trim(),
                                                      ) ??
                                                      0,
                                                );
                                              },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (delay == null) return;
                                      await _updateAvailabilityStatus(
                                        slot,
                                        'LATE',
                                        delayMinutes: delay,
                                      );
                                    },
                                    child: const Text('Mark Late'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Add New Slots',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...availabilities.map((entry) {
                      final index = availabilities.indexOf(entry);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Slot ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await _confirmDeleteAction(
                                      title: 'Remove slot?',
                                      message:
                                          'Are you sure you want to remove Slot ${index + 1} from this doctor schedule?',
                                      confirmLabel: 'Remove',
                                    );
                                    if (!confirmed) return;

                                    setState(
                                      () => availabilities.removeAt(index),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: entry.date,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null) {
                                  setState(() => entry.date = date);
                                }
                              },
                              child: Text(
                                'Date: ${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: entry.startTime,
                                      );
                                      if (time != null) {
                                        setState(() => entry.startTime = time);
                                      }
                                    },
                                    child: Text(
                                      'From: ${entry.startTime.format(dialogContext)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: entry.endTime,
                                      );
                                      if (time != null) {
                                        setState(() => entry.endTime = time);
                                      }
                                    },
                                    child: Text(
                                      'To: ${entry.endTime.format(dialogContext)}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          availabilities.add(
                            DoctorAvailabilityEntry(
                              date: DateTime.now(),
                              startTime: const TimeOfDay(hour: 9, minute: 0),
                              endTime: const TimeOfDay(hour: 17, minute: 0),
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add, color: Color(0xFF8171E5)),
                      label: const Text(
                        'Add Another Slot',
                        style: TextStyle(color: Color(0xFF8171E5)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8171E5),
                  ),
                  onPressed: () async {
                    final doctorId = _resolveDoctorId(doctor);
                    if (doctorId.isEmpty) {
                      _showMessage(
                        'Unable to determine doctor ID.',
                        success: false,
                      );
                      return;
                    }

                    final slots = availabilities.map((entry) {
                      return {
                        'duty_date': entry.date.toIso8601String().split('T').first,
                        'start_time': entry.startTime.format(dialogContext),
                        'end_time': entry.endTime.format(dialogContext),
                        'duty_status': _dateBasedDutyStatus(entry.date),
                      };
                    }).toList();

                    final success = await _supabaseService.createDoctorAvailabilityBatch(
                      doctorId: doctorId,
                      availabilities: slots,
                    );

                    if (!success) {
                      _showMessage(
                        'Unable to save slots. Please try again.',
                        success: false,
                      );
                      return;
                    }

                    if (!mounted) return;
                    _showMessage('Schedule saved successfully.');
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text(
                    'Save Slots',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    await _refreshDoctors();
  }

  // --- DOCTOR CARD ITEM WITH PHOTO & DELETE BUTTON ---
  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final name = doctor['name']?.toString() ?? 'Doctor';
    final specialist = doctor['specialties']?['name']?.toString() ??
      doctor['about']?.toString() ??
      'General Practitioner';
    final years = doctor['years_experience']?.toString() ?? '0';
    final photoUrl = doctor['profile_image']?.toString() ??
        doctor['image_url']?.toString() ??
        doctor['photo_url']?.toString() ??
        '';

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

    final availabilities = (doctor['doctor_availability'] as List<dynamic>?) ?? [];
    final upcomingAvailabilities = availabilities.where((slot) {
      return isTodayOrFutureDate(slot['duty_date']?.toString());
    }).toList();
    final availCount = upcomingAvailabilities.length;

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
                radius: 28,
                backgroundColor: const Color(0xFF8171E5).withOpacity(0.15),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 32,
                        color: Color(0xFF8171E5),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialist,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8171E5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _deleteDoctor(doctor),
                tooltip: 'Delete Doctor',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip('Experience', '$years yrs'),
              const SizedBox(width: 8),
              _buildInfoChip('Slots', '$availCount'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openDoctorForm(doctor: doctor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8171E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Edit Doctor',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openAvailabilitySheet(doctor),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8171E5),
                    side: const BorderSide(color: Color(0xFFDDD9F5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add Schedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Color(0xFF5A45A7)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Doctor Management',
          style: TextStyle(
            color: Color(0xFF1E1E28),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Receptionist Doctor Hub',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E28),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create, update, and manage doctor profiles',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openDoctorForm(),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Doctor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8171E5),
                        overlayColor: const Color(0xFF6B5BCD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _doctorsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8171E5),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load doctors: ${snapshot.error}',
                        ),
                      );
                    }
                    final doctors = snapshot.data ?? [];
                    if (doctors.isEmpty) {
                      return const Center(
                        child: Text('No doctor profiles available yet.'),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _refreshDoctors,
                      child: ListView.builder(
                        itemCount: doctors.length,
                        itemBuilder: (context, index) =>
                            _buildDoctorCard(doctors[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}