import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Services & Security
import 'package:mediqueue/services/supabase_config.dart';
import 'package:mediqueue/widgets/role_guard.dart';

// Pages
import 'package:mediqueue/pages/login_page.dart';
import 'package:mediqueue/pages/onboarding_page.dart';
import 'package:mediqueue/pages/home_page.dart';
import 'package:mediqueue/pages/doctors_page.dart';
import 'package:mediqueue/pages/patient_profile_page.dart';
import 'package:mediqueue/pages/my_queue_page.dart';
import 'package:mediqueue/pages/booking_page.dart';
import 'package:mediqueue/pages/book_appointment_page.dart';
import 'package:mediqueue/pages/appointment_management_page.dart';
import 'package:mediqueue/pages/doctor_management_page.dart';
import 'package:mediqueue/pages/receptionist_navigation_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase();
    runApp(const MyApp());
  } catch (error, stackTrace) {
    runApp(ErrorApp(error: error, stackTrace: stackTrace));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const CustomScrollBehavior(),
      home: const OnboardingPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/patient-home': (context) => const NavigationWrapper(),
        '/receptionist-home': (context) => const ReceptionistNavigationWrapper(),
        '/appointments': (context) => const RoleGuard(
              child: AppointmentManagementPage(),
            ),
        '/doctors': (context) => const RoleGuard(
              child: DoctorManagementPage(),
            ),
      },
    );
  }
}

// ============================================================
// RECEPTIONIST NAVIGATION WRAPPER (Receptionist Tab View)
// ============================================================

// ============================================================
// PATIENT NAVIGATION WRAPPER (Patient Tab View)
// ============================================================

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    DoctorsPage(),
    PatientSelectionBottomSheetContent(),
    MyQueuePage(),
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
        onTap: (index) async {
          if (index == 2) {
            final selectedPatient =
                await showPatientSelectionBottomSheet(context);

            if (selectedPatient != null && context.mounted) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingPage(patient: selectedPatient),
                ),
              );

              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking saved')),
                );
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

// ============================================================
// ERROR APP
// ============================================================

class ErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const ErrorApp({super.key, required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Startup Error',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
