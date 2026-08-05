import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mediqueue/services/supabase_config.dart';
import 'package:mediqueue/pages/login_page.dart';
import 'package:mediqueue/pages/auth_wrapper.dart';
import 'package:mediqueue/pages/profile_page.dart';
import 'package:mediqueue/pages/appointment_management_page.dart';
import 'package:mediqueue/pages/doctor_management_page.dart';
import 'package:mediqueue/widgets/role_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase();
    runApp(const MyApp());
  } catch (error, stackTrace) {
    runApp(ErrorApp(error: error, stackTrace: stackTrace));
  }
}

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
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const CustomScrollBehavior(),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
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

// Enable mouse drag gesture behavior across Desktop/Web platforms
class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}


