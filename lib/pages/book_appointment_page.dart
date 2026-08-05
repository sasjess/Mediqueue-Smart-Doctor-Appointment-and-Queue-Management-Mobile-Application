import 'package:flutter/material.dart';
import 'package:mediqueue/pages/add_patient_page.dart';
import 'package:mediqueue/services/supabase_service.dart';

/// Shows the patient selector sheet and returns the chosen patient's details
Future<Map<String, dynamic>?> showPatientSelectionBottomSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const PatientSelectionBottomSheetContent(),
  );
}

class PatientSelectionBottomSheetContent extends StatefulWidget {
  const PatientSelectionBottomSheetContent({super.key});

  @override
  State<PatientSelectionBottomSheetContent> createState() =>
      _PatientSelectionBottomSheetContentState();
}

class _PatientSelectionBottomSheetContentState
    extends State<PatientSelectionBottomSheetContent> {
  late Future<List<Map<String, dynamic>>> _patientProfilesFuture;
  final SupabaseService _svc = SupabaseService();

  @override
  void initState() {
    super.initState();
    _patientProfilesFuture = _fetchPatients();
  }

  Future<List<Map<String, dynamic>>> _fetchPatients() async {
    final patients = await _svc.getPatientsForCurrentUser();
    return patients.map((item) {
      return {
        'patient_id': item['patient_id'],
        'id': item['patient_id'].toString(),
        'name': item['name'] ?? 'Patient',
        'relation': item['relationship'] ?? 'Self',
      };
    }).toList();
  }

  void _selectPatient(Map<String, dynamic> patient) {
    Navigator.pop(context, patient);
  }

  @override
  Widget build(BuildContext context) {
    // ⬇️ Wrapped in Material widget to eliminate "No Material ancestor" error
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Book an Appointment',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Who is this appointment for?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 67, 67, 68),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a patient profile or add a family member.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _patientProfilesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                      ),
                    );
                  }

                  final patients = snapshot.data ?? [];

                  return Column(
                    children: patients.map((patient) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E4F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEEEEF5)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEDEAFF),
                            child: Icon(Icons.person_outline, color: Color(0xFF8171E5)),
                          ),
                          title: Text(
                            patient['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            patient['relation'],
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _selectPatient(patient),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 12),

              // ADD NEW PATIENT BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Open the Add Patient page from within the bottom sheet.
                    // Wait for the page to return the newly created patient details
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddPatientPage()),
                    );

                    // If a patient was added, close this sheet and return the new
                    // patient details to the original caller so that the caller
                    // (NavigationWrapper) can continue to the booking form.
                    if (result != null && context.mounted) {
                      Navigator.pop(context, result);
                    }
                  },
                  icon: const Icon(Icons.add, color: Color(0xFF8171E5)),
                  label: const Text('Add New Patient (e.g. Mother, Child)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF8171E5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show a simple booking form bottom sheet for the selected patient.
/// This keeps the booking flow on the same page (bottom-up sheet).
Future<void> showBookingFormBottomSheet(BuildContext context, Map<String, dynamic> patient) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      DateTime? selectedDate;

      return StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Book for: ${patient['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Select booking date'
                            : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                        style: TextStyle(color: selectedDate == null ? Colors.grey : const Color(0xFF222222)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a booking date')));
                      return;
                    }

                    // For now, we only show a success message and close the sheet.
                    // Integration with the booking creation API can be added later.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Booking created successfully!'),
                      backgroundColor: Colors.green,
                    ));

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8171E5)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      });
    },
  );
}