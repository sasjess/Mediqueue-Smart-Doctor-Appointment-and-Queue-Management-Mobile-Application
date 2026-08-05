import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Page Imports
import 'package:mediqueue/pages/book_appointment_page.dart';
import 'package:mediqueue/pages/login_page.dart';
import 'package:mediqueue/pages/home_page.dart';
import 'package:mediqueue/pages/doctors_page.dart'; 
import 'package:mediqueue/pages/patient_profile_page.dart';
import 'package:mediqueue/pages/my_queue_page.dart';
import 'package:mediqueue/pages/booking_page.dart';

void main() async {
  // Required before calling any async plugin initialization in Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your credentials from Supabase Dashboard -> Settings -> API
  await Supabase.initialize(
    url: 'https://aginmwptyqgzqxeerabu.supabase.co', // 👈 Replace with your Supabase URL
    anonKey: 'sb_publishable_18KZIVgdhC5VS1U5MeqK4w_ijDuDxW0',          // 👈 Replace with your Supabase Anon Key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Enables smooth mouse drag scrolling across Web & Desktop platforms
      scrollBehavior: const CustomScrollBehavior(),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// NAVIGATION WRAPPER (Main Tab Controller)
// ============================================================

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;

  // Ordered tabs: Home (0) -> Doctors (1) -> Book (2) -> Queue (3) -> Profile (4)
  final List<Widget> _pages = const [
    HomePage(),             // Index 0
    DoctorsPage(),          // Index 1
    PatientSelectionBottomSheetContent(),  // Index 2
    MyQueuePage(),          // Index 3
    PatientProfilePage(),   // Index 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps screen state active when switching tabs
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
        onTap: (index) async {
          // If the user tapped the Book tab (index 2), open the patient
          // selection sheet and continue the booking flow from there.
          if (index == 2) {
            // Do not switch to a separate tab — keep current view and show sheet
            final selectedPatient = await showPatientSelectionBottomSheet(context);

            if (selectedPatient != null && context.mounted) {
              // Navigate to the full BookingPage for the chosen patient
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BookingPage(patient: selectedPatient)),
              );

              // Optionally handle the created booking returned from the page
              if (result != null && context.mounted) {
                // Currently we just show a SnackBar confirming booking
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking saved')));
              }
            }
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            activeIcon: Icon(Icons.medical_services),
            label: 'Doctors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            activeIcon: Icon(Icons.confirmation_number),
            label: 'My Queue',
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

// Enable mouse drag gesture behavior across Desktop/Web browsers
class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}