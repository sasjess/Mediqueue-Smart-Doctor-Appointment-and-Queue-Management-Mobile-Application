import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/pages/receptionist_dashboard_page.dart';
import 'package:mediqueue/pages/booking_appointment_page.dart'; // or your Home/Booking page
import 'package:mediqueue/pages/login_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      return response?['role'] as String?;
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return 'patient'; // Default fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check authentication state
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return const LoginPage();
    }

    return FutureBuilder<String?>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF8171E5)),
            ),
          );
        }

        final role = snapshot.data ?? 'patient';

        // Route based on user role
        if (role == 'receptionist') {
          return const ReceptionistDashboardLayout();
        } else {
          return const PatientSelectionBottomSheetContent(); // Or your patient dashboard
        }
      },
    );
  }
}