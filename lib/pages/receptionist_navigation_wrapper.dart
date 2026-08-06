import 'package:flutter/material.dart';
import 'package:mediqueue/pages/appointment_management_page.dart';
import 'package:mediqueue/pages/doctor_management_page.dart';
import 'package:mediqueue/pages/patient_profile_page.dart';

class ReceptionistNavigationWrapper extends StatefulWidget {
  const ReceptionistNavigationWrapper({super.key});

  @override
  State<ReceptionistNavigationWrapper> createState() =>
      _ReceptionistNavigationWrapperState();
}

class _ReceptionistNavigationWrapperState
    extends State<ReceptionistNavigationWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    AppointmentManagementPage(),
    DoctorManagementPage(),
    PatientProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF8171E5),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.desk_outlined),
            activeIcon: Icon(Icons.desk),
            label: 'Reception Desk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            activeIcon: Icon(Icons.medical_services),
            label: 'Doctors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
