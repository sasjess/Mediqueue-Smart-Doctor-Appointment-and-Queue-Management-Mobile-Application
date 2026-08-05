import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/pages/add_patient_page.dart';

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

  @override
  void initState() {
    super.initState();
    _patientProfilesFuture = _fetchPatients();
  }

  Future<List<Map<String, dynamic>>> _fetchPatients() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    List<Map<String, dynamic>> profilesList = [];

    try {
      // 1. Primary user ("Self")
      final userProfile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final String primaryName = userProfile?['full_name'] ??
          user.userMetadata?['full_name'] ??
          'Self';

      profilesList.add({
        'id': user.id,
        'name': primaryName,
        'relation': 'Self',
      });

      // 2. Dependents from public.patients table
      final dependents = await Supabase.instance.client
          .from('patients')
          .select('patient_id, name, relationship')
          .eq('user_id', user.id);

      for (var item in dependents) {
        profilesList.add({
          'id': item['patient_id'].toString(),
          'name': item['name'] ?? 'Patient',
          'relation': item['relationship'] ?? 'Family Member',
        });
      }
    } catch (e) {
      debugPrint('Error fetching patients: $e');
    }

    return profilesList;
  }

  void _selectPatient(String patientId, String patientName) {
    Navigator.pop(context, {
      'id': patientId,
      'name': patientName,
    });
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
                          onTap: () => _selectPatient(
                            patient['id'].toString(),
                            patient['name'],
                          ),
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
                    // Close the current sheet first
                    Navigator.pop(context);

                    // Push the Add Patient Page
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddPatientPage()),
                    );

                    // If a patient was added, reopen the bottom sheet to show updated list
                    if (result != null && context.mounted) {
                      showPatientSelectionBottomSheet(context);
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