import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/main.dart';
import 'package:mediqueue/services/supabase_service.dart';
import 'package:mediqueue/pages/login_page.dart';
import 'package:mediqueue/pages/receptionist_navigation_wrapper.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final SupabaseService supabaseService = SupabaseService();

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. Check if user is logged in
        final session = supabase.auth.currentSession;
        if (session == null) {
          return const LoginPage();
        }

        // 2. User is logged in, fetch their role from public.profiles
        return FutureBuilder<String?>(
          future: supabaseService.fetchCurrentUserRole(),
          builder: (context, roleSnapshot) {
            // Show a sleek loading indicator while fetching the role
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF8F9FA),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                ),
              );
            }

            final role = roleSnapshot.data?.toLowerCase().trim() ?? 'patient';

            // 3. Route strictly based on role
            if (role == 'receptionist' || role == 'admin') {
              return const ReceptionistNavigationWrapper();
            } else {
              return const NavigationWrapper();
            }
          },
        );
      },
    );
  }
}