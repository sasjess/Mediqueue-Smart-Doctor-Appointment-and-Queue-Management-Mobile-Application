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

  void _showMessage(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2A7B3F) : Colors.redAccent,
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
    _doctorsFuture = _supabaseService.fetchDoctorsWithAvailability();
  }

  Future<void> _refreshDoctors() async {
    setState(() {
      _doctorsFuture = _supabaseService.fetchDoctorsWithAvailability();
    });
  }

  Future<void> _openDoctorForm({Map<String, dynamic>? doctor}) async {
    final nameController = TextEditingController(
      text: doctor?['name']?.toString() ?? '',
    );
    final yearsController = TextEditingController(
      text: doctor?['years_experience']?.toString() ?? '0',
    );
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

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(doctor == null ? 'Create doctor' : 'Update doctor'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Years experience',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (doctor != null)
                    const Text(
                      'Add availability slots',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (doctor != null) const SizedBox(height: 10),
                  if (doctor != null)
                    Column(
                      children: availabilities.map((entry) {
                        final index = availabilities.indexOf(entry);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6FF),
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
                                    onPressed: () {
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
                                    context: context,
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
                                          context: context,
                                          initialTime: entry.startTime,
                                        );
                                        if (time != null) {
                                          setState(
                                            () => entry.startTime = time,
                                          );
                                        }
                                      },
                                      child: Text(
                                        'From: ${entry.startTime.format(context)}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: entry.endTime,
                                        );
                                        if (time != null) {
                                          setState(() => entry.endTime = time);
                                        }
                                      },
                                      child: Text(
                                        'To: ${entry.endTime.format(context)}',
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
                  if (doctor != null)
                    TextButton.icon(
                      onPressed: () => addRow(setState),
                      icon: const Icon(Icons.add, color: Color(0xFF8171E5)),
                      label: const Text(
                        'Add slot',
                        style: TextStyle(color: Color(0xFF8171E5)),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final years =
                        int.tryParse(yearsController.text.trim()) ?? 0;

                    if (name.isEmpty) {
                      _showMessage(
                        'Doctor name is required.',
                        success: false,
                      );
                      return;
                    }

                    final doctorId = doctor != null
                        ? _resolveDoctorId(doctor)
                        : '';

                    if (doctor == null) {
                      final created = await _supabaseService.createDoctor(
                        name: name,
                        yearsExperience: years,
                      );

                      if (created == null) {
                        _showMessage(
                          'Unable to save doctor. Please try again.',
                          success: false,
                        );
                        return;
                      }

                      final createdDoctorId = _resolveDoctorId(created);
                      if (createdDoctorId.isEmpty) {
                        _showMessage(
                          'Saved doctor but could not get its ID.',
                          success: false,
                        );
                        return;
                      }

                      if (availabilities.isNotEmpty) {
                        final success = await _supabaseService
                            .createDoctorAvailabilityBatch(
                              doctorId: createdDoctorId,
                              availabilities: availabilities.map((entry) {
                                return {
                                  'duty_date': entry.date
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                                  'start_time': entry.startTime.format(context),
                                  'end_time': entry.endTime.format(context),
                                  'duty_status': entry.dutyStatus,
                                };
                              }).toList(),
                            );
                        if (!success) {
                          _showMessage(
                            'Doctor saved, but schedule failed.',
                            success: false,
                          );
                        }
                      }
                    } else {
                      if (doctorId.isEmpty) {
                        _showMessage(
                          'Unable to determine doctor ID.',
                          success: false,
                        );
                        return;
                      }

                      final updated = await _supabaseService.updateDoctor(
                        doctorId: doctorId,
                        name: name,
                        yearsExperience: years,
                      );
                      if (!updated) {
                        _showMessage(
                          'Unable to update doctor. Please try again.',
                          success: false,
                        );
                        return;
                      }
                      if (availabilities.isNotEmpty) {
                        final success = await _supabaseService
                            .createDoctorAvailabilityBatch(
                              doctorId: doctorId,
                              availabilities: availabilities.map((entry) {
                                return {
                                  'duty_date': entry.date
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                                  'start_time': entry.startTime.format(context),
                                  'end_time': entry.endTime.format(context),
                                  'duty_status': entry.dutyStatus,
                                };
                              }).toList(),
                            );
                        if (!success) {
                          _showMessage(
                            'Doctor updated, but schedule failed.',
                            success: false,
                          );
                        }
                      }
                    }

                    _showMessage('Doctor saved successfully.');
                    if (!mounted) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    await _refreshDoctors();
  }

  Future<void> _openAvailabilitySheet(Map<String, dynamic> doctor) async {
    final List<DoctorAvailabilityEntry> availabilities = [
      DoctorAvailabilityEntry(
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
      ),
    ];

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add availability slots'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    Column(
                      children: availabilities.map((entry) {
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
                                    onPressed: () {
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
                                    context: context,
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
                                          context: context,
                                          initialTime: entry.startTime,
                                        );
                                        if (time != null) {
                                          setState(
                                            () => entry.startTime = time,
                                          );
                                        }
                                      },
                                      child: Text(
                                        'From: ${entry.startTime.format(context)}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: entry.endTime,
                                        );
                                        if (time != null) {
                                          setState(() => entry.endTime = time);
                                        }
                                      },
                                      child: Text(
                                        'To: ${entry.endTime.format(context)}',
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
                        'Add another slot',
                        style: TextStyle(color: Color(0xFF8171E5)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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
                        'duty_date': entry.date
                            .toIso8601String()
                            .split('T')
                            .first,
                        'start_time': entry.startTime.format(context),
                        'end_time': entry.endTime.format(context),
                        'duty_status': entry.dutyStatus,
                      };
                    }).toList();
                    final success = await _supabaseService
                        .createDoctorAvailabilityBatch(
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
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save slots'),
                ),
              ],
            );
          },
        );
      },
    );
    await _refreshDoctors();
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final name = doctor['name']?.toString() ?? 'Doctor';
    final years = doctor['years_experience']?.toString() ?? '0';
    final availCount =
        (doctor['doctor_availability'] as List<dynamic>?)?.length ?? 0;

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
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
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
              ElevatedButton(
                onPressed: () => _openDoctorForm(doctor: doctor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8171E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Edit doctor'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _openAvailabilitySheet(doctor),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8171E5),
                  side: const BorderSide(color: Color(0xFFDDD9F5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add schedule'),
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
          style: TextStyle(color: Color(0xFF1E1E28)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openDoctorForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add doctor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8171E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size.fromHeight(52),
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