import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Services
import 'package:mediqueue/services/supabase_service.dart';

// Pages & Navigators
import 'package:mediqueue/main.dart';
import 'package:mediqueue/pages/login_page.dart';
import 'package:mediqueue/pages/receptionist_navigation_wrapper.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseService _supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          return const LoginPage();
        }

        return FutureBuilder<String?>(
          future: _supabaseService.fetchCurrentUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8171E5),
                  ),
                ),
              );
            }

            final role = roleSnapshot.data?.toLowerCase();

            // Receptionist / Admin gets Receptionist Bottom Navigation Bar
            if (role == 'receptionist' || role == 'admin') {
              return const ReceptionistNavigationWrapper();
            }

            // Patients get Patient Bottom Navigation Bar
            return const NavigationWrapper();
          },
        );
      },
    );
  }
}