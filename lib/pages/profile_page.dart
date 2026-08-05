import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/pages/auth_wrapper.dart';

class ProfilePage extends StatefulWidget {
  final bool isReceptionist;

  const ProfilePage({super.key, this.isReceptionist = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  String _displayName = '';
  String _role = 'Patient';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _user = user;
        _displayName = profile?['full_name']?.toString().trim().isNotEmpty == true
            ? profile!['full_name'].toString()
            : user.userMetadata?['full_name']?.toString() ??
                user.userMetadata?['name']?.toString() ??
                user.email ??
                'User';
        _role = profile?['role']?.toString() ?? (widget.isReceptionist ? 'Receptionist' : 'Patient');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = user;
        _displayName = user.email ?? 'User';
        _role = widget.isReceptionist ? 'Receptionist' : 'Patient';
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8171E5)),
        ),
      );
    }

    final roleLabel = _role.isNotEmpty
        ? '${_role[0].toUpperCase()}${_role.substring(1)}'
        : 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Profile', style: TextStyle(color: Color(0xFF1E1E28))),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFECECF2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isReceptionist ? 'Receptionist profile' : 'Account profile',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFEDEAFF),
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, color: Color(0xFF8171E5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _user?.email ?? 'No email available',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildInfoTile('User ID', _shortId(_user?.id)),
                        const SizedBox(width: 12),
                        _buildInfoTile('Role', roleLabel),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8171E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortId(String? id) {
    if (id == null || id.length < 8) return id ?? 'Unknown';
    return '${id.substring(0, 8)}...';
  }

  Widget _buildInfoTile(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
