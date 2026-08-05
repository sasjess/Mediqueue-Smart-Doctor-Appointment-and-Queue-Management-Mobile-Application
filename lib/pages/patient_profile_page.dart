import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/pages/login_page.dart';
import 'package:mediqueue/services/supabase_service.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final SupabaseService _supabaseService = SupabaseService();
  
  // Dynamically get current user getter
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  String _fullName = '';
  String _phone = '';
  String? _avatarUrl;
  bool _isLoadingProfile = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // ==========================================
  // FETCH USER PROFILE FROM SUPABASE
  // ==========================================
  Future<void> _loadUserProfile() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
      return;
    }

    try {
      // 1. First fallback: Pull name and phone from Auth user metadata directly
      String name = user.userMetadata?['full_name'] ?? '';
      String phone = user.userMetadata?['phone'] ?? '';
      String? avatar;

      // 2. Query public.profiles database table
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        if (response['full_name'] != null && response['full_name'].toString().isNotEmpty) {
          name = response['full_name'];
        }
        if (response['phone'] != null && response['phone'].toString().isNotEmpty) {
          phone = response['phone'];
        }
        avatar = response['avatar_url'];
      }

      if (mounted) {
        setState(() {
          _fullName = name;
          _phone = phone;
          _avatarUrl = avatar;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback to email name if anything fails
          _fullName = user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User';
        });
      }
    } finally {
      // ALWAYS stop the loading indicator when execution finishes
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  // ==========================================
  // UPLOAD AVATAR TO SUPABASE STORAGE
  // ==========================================
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    final user = currentUser;
    if (image == null || user == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final filePath = '${user.id}/avatar.$fileExt';

      // 1. Upload File to Supabase Storage
      await Supabase.instance.client.storage.from('avatars').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // 2. Get Public Image URL
      final String publicUrl =
          Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);

      final String freshUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // 3. Update Database Record
      await Supabase.instance.client.from('profiles').update({
        'avatar_url': freshUrl,
      }).eq('id', user.id);

      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'avatar_url': freshUrl}),
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _avatarUrl = freshUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ==========================================
  // EDIT PROFILE DETAILS BOTTOM SHEET MODAL
  // ==========================================
  void _showEditProfileModal() {
    final user = currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: _fullName);
    final phoneController = TextEditingController(text: _phone);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Profile Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // NAME FIELD
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF8171E5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // PHONE FIELD
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF8171E5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              final newName = nameController.text.trim();
                              final newPhone = phoneController.text.trim();

                              try {
                                await Supabase.instance.client.from('profiles').update({
                                  'full_name': newName,
                                  'phone': newPhone,
                                }).eq('id', user.id);

                                if (mounted) {
                                  setState(() {
                                    _fullName = newName;
                                    _phone = newPhone;
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8171E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // LOGOUT LOGIC
  // ==========================================
  Future<void> _handleLogout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of MediQueue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String? getFormattedAvatarUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    try {
      String cleanPath = trimmed;
      if (cleanPath.startsWith('avatars/')) {
        cleanPath = cleanPath.replaceFirst('avatars/', '');
      }
      return Supabase.instance.client.storage.from('avatars').getPublicUrl(cleanPath);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final String userEmail = user?.email ?? 'patient@example.com';
    final String initial = _fullName.isNotEmpty
        ? _fullName[0].toUpperCase()
        : (userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'P');

    final String? formattedAvatar = getFormattedAvatarUrl(_avatarUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Profile & Account',
          style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. PRIMARY ACCOUNT USER HEADER
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // AVATAR WITH CAMERA OVERLAY FOR PICKING PHOTO
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFECEBFA),
                        backgroundImage: formattedAvatar != null ? NetworkImage(formattedAvatar) : null,
                        child: formattedAvatar == null
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8171E5),
                                ),
                              )
                            : null,
                      ),
                      if (_isUploadingImage)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Color(0xFF8171E5),
                            child: Icon(Icons.camera_alt, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // NAME & PHONE/EMAIL DETAILS
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingProfile
                              ? 'Loading...'
                              : (_fullName.isNotEmpty ? _fullName : userEmail.split('@').first),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        if (_phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _phone,
                            style: const TextStyle(color: Color(0xFF8171E5), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // EDIT BUTTON
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                    onPressed: _showEditProfileModal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 2. PATIENT PROFILES SECTION
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Patient Profiles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF8171E5)),
                  label: const Text(
                    'Add New',
                    style: TextStyle(color: Color(0xFF8171E5), fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),

            // DYNAMIC PATIENTS LIST
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabaseService.fetchPatientProfiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                    ),
                  );
                }

                final patients = snapshot.data ?? [];

                if (patients.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No patient profiles linked yet. Click "Add New" above.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  );
                }

                return Column(
                  children: patients.map((patient) {
                    final String name = patient['name'] ?? 'Patient Name';
                    final String relation = patient['relationship'] ?? 'Self';
                    final String gender = patient['gender'] ?? 'N/A';
                    final String dob = patient['date_of_birth'] ?? 'N/A';

                    return _buildPatientCard(
                      name: name,
                      relation: relation,
                      details: '$relation • $gender ($dob)',
                      onTap: () {},
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 3. ACCOUNT SETTINGS & PREFERENCES
            // ==========================================
            const Text(
              'Account Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildSettingsTile(
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Queue updates, reminders',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.security_outlined,
              title: 'Privacy & Security',
              subtitle: 'Password, biometrics',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs, contact support',
              onTap: () {},
            ),
            
            // LOGOUT BUTTON TILE
            _buildSettingsTile(
              icon: Icons.logout,
              title: 'Log Out',
              subtitle: 'Sign out of your session',
              textColor: Colors.redAccent,
              onTap: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard({
    required String name,
    required String relation,
    required String details,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEDEAFF),
          child: Icon(Icons.badge_outlined, color: Color(0xFF8171E5)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(details, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textColor = const Color(0xFF222222),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: textColor == Colors.redAccent ? Colors.redAccent : const Color(0xFF8171E5),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))
            : null,
        trailing: textColor == Colors.redAccent
            ? const Icon(Icons.chevron_right, size: 20, color: Colors.redAccent)
            : const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}

// import 'package:flutter/material.dart';

// class PatientProfilePage extends StatelessWidget {
//   const PatientProfilePage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FE),
//       appBar: AppBar(
//         title: const Text(
//           'Profile & Account',
//           style: TextStyle(color: Color(0xFF1E1E28), fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ==========================================
//             // 1. PRIMARY ACCOUNT USER HEADER
//             // ==========================================
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Row(
//                 children: [
//                   const CircleAvatar(
//                     radius: 30,
//                     backgroundColor: Color(0xFFECEBFA),
//                     child: Icon(Icons.person, size: 36, color: Color(0xFF8171E5)),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Text(
//                           'John Doe',
//                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                         SizedBox(height: 4),
//                         Text(
//                           'johndoe@email.com • +1 234 567 890',
//                           style: TextStyle(color: Colors.grey, fontSize: 12),
//                         ),
//                       ],
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.edit_outlined, color: Colors.grey),
//                     onPressed: () {
//                       // Edit account details
//                     },
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 24),

//             // ==========================================
//             // 2. PATIENT PROFILES SECTION (Self & Family)
//             // ==========================================
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Patient Profiles',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//                 TextButton.icon(
//                   onPressed: () {
//                     // Add new family profile modal
//                   },
//                   icon: const Icon(Icons.add, size: 18, color: Color(0xFF8171E5)),
//                   label: const Text(
//                     'Add New',
//                     style: TextStyle(color: Color(0xFF8171E5), fontWeight: FontWeight.bold),
//                   ),
//                 )
//               ],
//             ),
//             const SizedBox(height: 8),

//             _buildPatientCard(
//               name: 'John Doe',
//               relation: 'Self (Primary)',
//               ageGender: '32 yrs, Male',
//               onTap: () {},
//             ),
//             _buildPatientCard(
//               name: 'Sarah Doe',
//               relation: 'Daughter',
//               ageGender: '8 yrs, Female',
//               onTap: () {},
//             ),
//             _buildPatientCard(
//               name: 'Robert Doe',
//               relation: 'Father',
//               ageGender: '64 yrs, Male',
//               onTap: () {},
//             ),

//             const SizedBox(height: 24),

//             // ==========================================
//             // 3. ACCOUNT SETTINGS & PREFERENCES
//             // ==========================================
//             const Text(
//               'Account Settings',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),

//             _buildSettingsTile(
//               icon: Icons.notifications_none_outlined,
//               title: 'Notifications',
//               subtitle: 'Queue updates, reminders',
//               onTap: () {},
//             ),
//             _buildSettingsTile(
//               icon: Icons.security_outlined,
//               title: 'Privacy & Security',
//               subtitle: 'Password, biometrics',
//               onTap: () {},
//             ),
//             _buildSettingsTile(
//               icon: Icons.help_outline,
//               title: 'Help & Support',
//               subtitle: 'FAQs, contact support',
//               onTap: () {},
//             ),
//             _buildSettingsTile(
//               icon: Icons.logout,
//               title: 'Log Out',
//               subtitle: '',
//               textColor: Colors.redAccent,
//               onTap: () {},
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Helper widget for Patient Profiles
//   Widget _buildPatientCard({
//     required String name,
//     required String relation,
//     required String ageGender,
//     required VoidCallback onTap,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFEEEEF5)),
//       ),
//       child: ListTile(
//         leading: const CircleAvatar(
//           backgroundColor: Color(0xFFEDEAFF),
//           child: Icon(Icons.badge_outlined, color: Color(0xFF8171E5)),
//         ),
//         title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//         subtitle: Text('$relation • $ageGender', style: const TextStyle(color: Colors.grey, fontSize: 12)),
//         trailing: const Icon(Icons.chevron_right, size: 20),
//         onTap: onTap,
//       ),
//     );
//   }

//   // Helper widget for General Account Settings
//   Widget _buildSettingsTile({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required VoidCallback onTap,
//     Color textColor = const Color(0xFF222222),
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: textColor == Colors.redAccent ? Colors.redAccent : const Color(0xFF8171E5)),
//         title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
//         subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
//         trailing: textColor == Colors.redAccent ? null : const Icon(Icons.chevron_right, size: 20),
//         onTap: onTap,
//       ),
//     );
//   }
// }