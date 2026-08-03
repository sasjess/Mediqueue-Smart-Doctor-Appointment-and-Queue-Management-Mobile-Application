import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// Import your page files here:
import 'package:mediqueue/pages/home_page.dart';
import 'package:mediqueue/pages/doctors_page.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Enables smooth drag scrolling on desktop/web browsers
      scrollBehavior: const CustomScrollBehavior(), 
      home: const NavigationWrapper(),
    );
  }
}

// ============================================================
// NAVIGATION WRAPPER (Handles switching between tabs)
// ============================================================

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;

  // List of screens for each Bottom Navigation tab
  final List<Widget> _pages = const [
    HomePage(),     // Index 0
    DoctorsPage(),  // Index 1
    Center(child: Text('My Queue Page')),       // Index 2
    Center(child: Text('Bookings Page')),         // Index 3
    Center(child: Text('Profile Page')),        // Index 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack preserves page scroll positions when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // Single bottom navigation bar controlling the whole app
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Doctors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue),
            label: 'My Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Enable mouse drag gesture behavior across Desktop/Web platforms
class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}


