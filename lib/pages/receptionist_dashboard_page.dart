import 'package:flutter/material.dart';
import 'package:mediqueue/pages/appointment_management_page.dart';
import 'package:mediqueue/pages/doctor_management_page.dart';
import 'package:mediqueue/pages/patient_profile_page.dart';

class ReceptionistDashboardLayout extends StatefulWidget {
  const ReceptionistDashboardLayout({super.key});

  @override
  State<ReceptionistDashboardLayout> createState() =>
      _ReceptionistDashboardLayoutState();
}

class _ReceptionistDashboardLayoutState
    extends State<ReceptionistDashboardLayout> {
  int _currentIndex = 0;

  late final List<Widget> _tabs = const [
    AppointmentManagementPage(),
    DoctorManagementPage(),
    PatientProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFEDEAFF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.desk_outlined),
            selectedIcon: Icon(Icons.desk, color: Color(0xFF8171E5)),
            label: 'Desk',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services, color: Color(0xFF8171E5)),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF8171E5)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
