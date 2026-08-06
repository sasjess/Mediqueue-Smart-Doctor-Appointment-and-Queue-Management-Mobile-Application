
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/services/supabase_service.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _client = Supabase.instance.client;

  User? _currentUser;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String? _userRole;

  // Profile fields
  String _displayName = '';
  String _displayPhone = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = _client.auth.currentUser;
      final role = await _supabaseService.fetchCurrentUserRole();

      // Default values from Auth User Metadata / Phone
      String name = _currentUser?.userMetadata?['full_name'] ?? '';
      String phone = _currentUser?.phone ?? '';

      // Query public.profiles table for latest stored details
      if (_currentUser != null) {
        final profile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', _currentUser!.id)
            .maybeSingle();

        if (profile != null) {
          if ((profile['full_name'] ?? '').toString().isNotEmpty) {
            name = profile['full_name'].toString();
          }
          if ((profile['phone'] ?? '').toString().isNotEmpty) {
            phone = profile['phone'].toString();
          }
        }
      }

      // Fetch dependent patient profiles only if the logged-in user is a patient
      List<Map<String, dynamic>> data = [];
      if (role?.toLowerCase() == 'patient') {
        data = await _supabaseService.fetchPatientProfiles();
      }

      if (mounted) {
        setState(() {
          _userRole = role?.toLowerCase();
          _patients = data;
          _displayName = name.isNotEmpty ? name : 'User';
          _displayPhone = phone;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- EDIT PROFILE DIALOG ---
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _displayPhone);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8171E5),
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();

              if (newName.isEmpty) return;

              // Hide keyboard and close dialog
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialogContext);

              setState(() => _isLoading = true);

              try {
                final user = _client.auth.currentUser;
                if (user != null) {
                  // 1. Check if profile row exists in DB
                  final existingProfile = await _client
                      .from('profiles')
                      .select('id')
                      .eq('id', user.id)
                      .maybeSingle();

                  if (existingProfile != null) {
                    await _client.from('profiles').update({
                      'full_name': newName,
                      'phone': newPhone,
                    }).eq('id', user.id);
                  } else {
                    await _client.from('profiles').insert({
                      'id': user.id,
                      'full_name': newName,
                      'phone': newPhone,
                      'role': _userRole ?? 'receptionist',
                    });
                  }

                  // 2. Local state update first so UI reflects changes immediately
                  if (mounted) {
                    setState(() {
                      _displayName = newName;
                      _displayPhone = newPhone;
                      _isLoading = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }

                  // 3. Update Auth Metadata quietly (Avoids triggering full auth wrapper route refresh)
                  await _client.auth.updateUser(
                    UserAttributes(
                      data: {'full_name': newName},
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- HANDLE LOGOUT ---
  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  // --- ADD PATIENT DEPENDENT DIALOG (PATIENTS ONLY) ---
  void _showAddPatientDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final relationshipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                    labelText: 'Relationship (e.g. Spouse, Child)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8171E5),
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  relationshipController.text.isNotEmpty) {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context);
                await _supabaseService.addPatientProfile(
                  name: nameController.text.trim(),
                  mobile: mobileController.text.trim(),
                  relationship: relationshipController.text.trim(),
                );
                _loadProfileData();
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = _userRole == 'receptionist' || _userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isStaff ? 'Staff Profile' : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8171E5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- PROFILE CARD ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  const Color(0xFF8171E5).withOpacity(0.1),
                              child: Icon(
                                isStaff ? Icons.badge : Icons.person,
                                size: 36,
                                color: const Color(0xFF8171E5),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentUser?.email ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_displayPhone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _displayPhone,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  if (isStaff) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8171E5)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _userRole?.toUpperCase() ?? 'STAFF',
                                        style: const TextStyle(
                                          color: Color(0xFF8171E5),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // Edit Details Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _showEditProfileDialog,
                            icon: const Icon(Icons.edit_outlined,
                                color: Color(0xFF8171E5), size: 18),
                            label: const Text(
                              'Edit Profile Details',
                              style: TextStyle(
                                color: Color(0xFF8171E5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- MANAGED PROFILES (HIDDEN FOR RECEPTIONISTS) ---
                  if (!isStaff) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Managed Profiles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddPatientDialog,
                          icon: const Icon(Icons.add, color: Color(0xFF8171E5)),
                          label: const Text(
                            'Add New',
                            style: TextStyle(color: Color(0xFF8171E5)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_patients.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Text(
                            'No patient profiles found.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _patients.length,
                        itemBuilder: (context, index) {
                          final patient = _patients[index];
                          final isSelf = (patient['relationship'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              'self';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelf
                                    ? const Color(0xFF8171E5)
                                    : Colors.grey[300],
                                child: Icon(
                                  isSelf
                                      ? Icons.person
                                      : Icons.family_restroom,
                                  color:
                                      isSelf ? Colors.white : Colors.grey[700],
                                ),
                              ),
                              title: Text(
                                patient['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Relationship: ${patient['relationship'] ?? 'Self'}',
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],

                  // --- SIGN OUT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handleSignOut,
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}