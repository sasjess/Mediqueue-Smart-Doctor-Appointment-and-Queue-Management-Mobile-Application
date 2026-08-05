import 'package:flutter/material.dart';
import 'package:mediqueue/pages/auth_wrapper.dart';
import 'package:mediqueue/services/supabase_service.dart';

/// Blocks access to reception-only screens for non-receptionist users.
class RoleGuard extends StatefulWidget {
  final Widget child;
  final List<String> allowedRoles;

  const RoleGuard({
    super.key,
    required this.child,
    this.allowedRoles = const ['receptionist'],
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final role = await _supabaseService.fetchCurrentUserRole();
      final normalizedRole = role?.toLowerCase() ?? '';
      final allowed = widget.allowedRoles
          .map((r) => r.toLowerCase())
          .contains(normalizedRole);

      if (mounted) {
        setState(() {
          _allowed = allowed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allowed = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8171E5))),
      );
    }

    if (!_allowed) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Color(0xFF8171E5)),
                const SizedBox(height: 16),
                const Text(
                  'Access denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have permission to view this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8171E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Go to home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
