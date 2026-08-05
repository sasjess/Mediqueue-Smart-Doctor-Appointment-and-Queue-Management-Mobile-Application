import 'package:flutter/material.dart';
import 'package:mediqueue/pages/receptionist_page.dart';
import 'package:mediqueue/pages/profile_page.dart';

class ReceptionistDashboardLayout extends StatefulWidget {
  const ReceptionistDashboardLayout({super.key});

  @override
  State<ReceptionistDashboardLayout> createState() =>
      _ReceptionistDashboardLayoutState();
}

class _ReceptionistDashboardLayoutState
    extends State<ReceptionistDashboardLayout> {
  int _currentIndex = 0;

  late final List<Widget> _tabs = [
    const ReceptionistPage(showProfileAction: false),
    const ProfilePage(isReceptionist: true),
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
            icon: Icon(Icons.view_list_rounded),
            selectedIcon: Icon(Icons.view_list_rounded, color: Color(0xFF8171E5)),
            label: 'Reception Desk',
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
