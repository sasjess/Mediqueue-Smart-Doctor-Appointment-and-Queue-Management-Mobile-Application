import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediqueue/pages/SpecialistPage.dart';
import 'package:mediqueue/services/supabase_service.dart';
import 'package:mediqueue/widgets/ticket_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int selectedCategoryIndex = 0; // Fixed: Declared missing category state variable
  bool _isLoadingTickets = false;

  String userName = 'User';
  String? avatarUrl;
  StreamSubscription? _profileSubscription;

  // Categories List
  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Dentist',
      'icon': Icons.medical_services_outlined,
    },
    {
      'name': 'Surgeon',
      'icon': Icons.healing_outlined,
    },
    {
      'name': 'Therapist',
      'icon': Icons.accessibility_new_outlined,
    },
    {
      'name': 'Cardio',
      'icon': Icons.favorite_border,
    },
    {
      'name': 'Skin',
      'icon': Icons.face_outlined,
    },
    {
      'name': 'Children',
      'icon': Icons.child_care_outlined,
    },
  ];

  // Future to store Doctor list so typing in search doesn't keep hitting Supabase
  late Future<List<Map<String, dynamic>>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = _fetchDoctors();
    _fetchUserProfile();
    _setupProfileSubscription();
  }

  void _setupProfileSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      _profileSubscription = Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
          .listen((data) {
        if (data.isNotEmpty && mounted) {
          final profile = data.first;
          setState(() {
            if (profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
              userName = profile['full_name'].toString();
            }
            if (profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty) {
              avatarUrl = profile['avatar_url'].toString();
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error listening to profile changes: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      // Check Auth metadata first
      final nameFromMeta = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
      final avatarFromMeta = user.userMetadata?['avatar_url'];

      if (mounted) {
        setState(() {
          if (nameFromMeta != null) userName = nameFromMeta.toString();
          if (avatarFromMeta != null && avatarFromMeta.toString().isNotEmpty) {
            avatarUrl = avatarFromMeta.toString();
          }
        });
      }

      // Check database profiles table as well
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            if (profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
              userName = profile['full_name'].toString();
            }
            if (profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty) {
              avatarUrl = profile['avatar_url'].toString();
            }
          });
        }
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
      }
    }
  }

  // Fetch doctors and their related specialties & availability
  Future<List<Map<String, dynamic>>> _fetchDoctors() async {
    return _supabaseService.fetchDoctorsWithAvailability();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _profileSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E9F7),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          _buildHeader(),

                          const SizedBox(height: 28),

                          // MEDICAL BANNER
                          _buildMedicalBanner(),

                          const SizedBox(height: 35),

                          // SEARCH BOX
                          _buildSearchBox(),

                          const SizedBox(height: 35),

                          // CATEGORIES TITLE
                          _buildSectionTitle(
                            title: 'Categories',
                            actionText: 'See all',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SpecialistPage(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // CATEGORIES
                          _buildCategories(),

                          const SizedBox(height: 35),

                          // DOCTOR LIST TITLE
                          _buildSectionTitle(
                            title: 'Doctor list',
                            actionText: 'See all',
                            onTap: () {
                              _showAllDoctorsBottomSheet(context);
                            },
                          ),

                          const SizedBox(height: 12),

                          // DOCTORS FETCHED FROM SUPABASE
                          _buildDoctorListFromDatabase(),
                        ],
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

  String? _getFormattedAvatarUrl(String? url) {
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

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    final String? formattedAvatar = _getFormattedAvatarUrl(avatarUrl);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 16, 16, 16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 23,
                  color: Color(0xFF222222),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // PROFILE IMAGE
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE5E4F4),
            border: Border.all(
              color: const Color(0xFFF1F0F8),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: (formattedAvatar != null && formattedAvatar.isNotEmpty)
                ? Image.network(
                    formattedAvatar,
                    key: ValueKey(formattedAvatar),
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8171E5),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person,
                      color: Color(0xFF8171E5),
                      size: 28,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Color(0xFF8171E5),
                    size: 28,
                  ),
          ),
      ),
    ],
  );
}

  // ============================================================
  // MEDICAL BANNER
  // ============================================================
  Widget _buildMedicalBanner() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDF0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'lib/images/receptionist11.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF8171E5),
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need your ticket?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF242424),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Find active tickets by\npatient profile instantly.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      color: Color.fromARGB(255, 32, 32, 32),
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 35,
                    width: 139,
                    child: ElevatedButton(
                      onPressed: _isLoadingTickets ? null : _openGetMyTicketFlow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8171E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text(
                        'Get My Ticket',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTicketTime(Map<String, dynamic> ticket) {
    final bookingDate = ticket['booking_date']?.toString() ?? '';

    String startTime = '';
    final availability = ticket['doctor_availability'];
    if (availability is Map<String, dynamic>) {
      startTime = availability['start_time']?.toString() ?? '';
    } else if (availability is List && availability.isNotEmpty) {
      final first = availability.first;
      if (first is Map<String, dynamic>) {
        startTime = first['start_time']?.toString() ?? '';
      }
    }

    if (bookingDate.isNotEmpty && startTime.isNotEmpty) {
      return '$bookingDate $startTime';
    }
    return bookingDate.isNotEmpty ? bookingDate : 'Today';
  }

  DateTime? _parseDutyDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final dt = DateTime.parse(dateStr.trim());
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }

  String _deriveDisplayDutyStatus(Map<String, dynamic>? slot) {
    if (slot == null) return 'UNAVAILABLE';

    final stored = slot['duty_status']?.toString().trim().toUpperCase();
    if (stored == 'LATE') return 'LATE';

    final slotDay = _parseDutyDate(slot['duty_date']?.toString());
    if (slotDay == null) return (stored == null || stored.isEmpty) ? 'UNAVAILABLE' : stored;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (slotDay.isBefore(today)) return 'COMPLETED';
    if (slotDay.isAfter(today)) return 'UPCOMING';
    return 'AVAILABLE';
  }

  Map<String, dynamic>? _primaryAvailabilityForDisplay(List<dynamic> slots) {
    final normalized = slots
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
    if (normalized.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    normalized.sort((a, b) {
      final da = _parseDutyDate(a['duty_date']?.toString());
      final db = _parseDutyDate(b['duty_date']?.toString());
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    for (final slot in normalized) {
      final day = _parseDutyDate(slot['duty_date']?.toString());
      if (day != null && (day.isAtSameMomentAs(today) || day.isAfter(today))) {
        return slot;
      }
    }

    return normalized.first;
  }

  Future<void> _openGetMyTicketFlow() async {
    if (_isLoadingTickets) return;

    setState(() => _isLoadingTickets = true);
    try {
      final profiles = await _supabaseService.fetchProfilesWithActiveTickets();
      if (!mounted) return;

      if (profiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active tickets found for your profiles.')),
        );
        return;
      }

      final selectedProfile = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                const Text(
                  'Select Patient Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...profiles.map((profile) {
                  final name = profile['name']?.toString() ?? 'Patient';
                  final relation = profile['relationship']?.toString() ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEDEAFF),
                      child: Icon(Icons.person, color: Color(0xFF8171E5)),
                    ),
                    title: Text(name),
                    subtitle: relation.isNotEmpty ? Text(relation) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheetContext, profile),
                  );
                }),
              ],
            ),
          );
        },
      );

      if (selectedProfile == null || !mounted) return;
      await _showTicketsForProfile(selectedProfile);
    } finally {
      if (mounted) {
        setState(() => _isLoadingTickets = false);
      }
    }
  }

  Future<void> _showTicketsForProfile(Map<String, dynamic> profile) async {
    final patientId = profile['patient_id'] is int
        ? profile['patient_id'] as int
        : int.tryParse(profile['patient_id']?.toString() ?? '') ?? 0;

    if (patientId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid profile selected.')),
      );
      return;
    }

    final tickets = await _supabaseService.fetchActiveTicketsForPatient(
      patientId: patientId,
    );

    if (!mounted) return;

    if (tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active tickets for this profile.')),
      );
      return;
    }

    final profileName = profile['name']?.toString() ?? 'Patient';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.88;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$profileName Tickets',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      final doctorName =
                          ticket['doctors']?['name']?.toString() ?? 'Doctor';
                      final queueName = '$doctorName Queue';
                      final bookingCode =
                          ticket['booking_code']?.toString() ?? '--';
                      final queueNumber = ticket['queue_number'] is int
                          ? ticket['queue_number'] as int
                          : int.tryParse(
                                  ticket['queue_number']?.toString() ?? '') ??
                              (index + 1);
                      final status =
                          ticket['status']?.toString().toUpperCase() ?? 'BOOKED';

                      return TicketCard(
                        bookingCode: bookingCode,
                        patientName: profileName,
                        doctorName: doctorName,
                        queueName: queueName,
                        appointmentTime: _formatTicketTime(ticket),
                        queueNumber: queueNumber,
                        status: status,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8171E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SEARCH BOX
  // ============================================================
  Widget _buildSearchBox() {
    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 234, 234, 248),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFF1F1F8),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: const InputDecoration(
          hintText: 'Search doctors or specialties..',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 143, 143, 147),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 21,
            color: Color.fromARGB(255, 112, 54, 171),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================
  Widget _buildSectionTitle({
    required String title,
    required String actionText,
    VoidCallback? onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF292929),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB8B8C3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CATEGORIES
  // ============================================================
  Widget _buildCategories() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final bool selected = selectedCategoryIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategoryIndex = index;
                // Filter by selected category name
                searchQuery = category['name'];
                _searchController.text = category['name'];
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              margin: EdgeInsets.only(
                right: index == categories.length - 1 ? 0 : 9,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? const Color.fromARGB(255, 203, 198, 227)
                    : const Color.fromARGB(255, 234, 234, 248),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? const Color.fromARGB(255, 224, 218, 252)
                      : const Color.fromRGBO(243, 243, 248, 1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 7),
                  Icon(
                    category['icon'],
                    size: 30,
                    color: const Color(0xFFB6B0DB),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      category['name'],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                        color: const Color(0xFF696978),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // DOCTOR LIST FROM SUPABASE
  // ============================================================
  Widget _buildDoctorListFromDatabase() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _doctorsFuture, // Use stored cached Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 185,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF8171E5)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 120,
            child: Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        List<Map<String, dynamic>> doctors = snapshot.data ?? [];

        // Filter doctors based on search bar text
        if (searchQuery.isNotEmpty) {
          doctors = doctors.where((doc) {
            final name = (doc['name'] ?? '').toString().toLowerCase();
            final spec = (doc['specialties']?['name'] ?? '').toString().toLowerCase();
            final query = searchQuery.toLowerCase();
            return name.contains(query) || spec.contains(query);
          }).toList();
        }

        if (doctors.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text('No doctors found', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doc = doctors[index];
              final String name = doc['name'] ?? 'Doctor';
              final String specialtyName = doc['specialties']?['name'] ?? 'Specialist';
              final int exp = doc['years_experience'] ?? 0;
              final String rating = (doc['rating'] ?? 5.0).toString();
              final String? img = doc['image_url'];

              // Extract Availability Info
              final List availabilityList = doc['doctor_availability'] ?? [];
              final Map<String, dynamic>? availability =
                  _primaryAvailabilityForDisplay(availabilityList);

              final String dutyStatus = _deriveDisplayDutyStatus(availability);
              final int delayMinutes = availability?['delay_minutes'] ?? 0;

              return _buildDoctorCard(
                name: name,
                specialty: '$specialtyName, $exp y.e',
                rating: rating,
                imageUrl: img,
                dutyStatus: dutyStatus,
                delayMinutes: delayMinutes,
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // DOCTOR CARD
  // ============================================================
  Widget _buildDoctorCard({
    required String name,
    required String specialty,
    required String rating,
    String? imageUrl,
    required String dutyStatus,
    required int delayMinutes,
  }) {
    final normalizedStatus = dutyStatus.toUpperCase();
    final bool isAvailable = normalizedStatus == 'AVAILABLE';

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 234, 234, 248),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF2F2F8)),
      ),
      child: Column(
        children: [
          // IMAGE + RATING + ON/OFF DUTY BADGE
          SizedBox(
            height: 74,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE5E0FA),
                  ),
                ),
                ClipOval(
                  child: (imageUrl != null && imageUrl.startsWith('http'))
                      ? Image.network(
                          imageUrl,
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 65,
                              height: 65,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8171E5),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 35,
                            color: Color(0xFF7565D1),
                          ),
                        )
                      : Image.asset(
                          'lib/images/doctor1.avif',
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 35,
                            color: Color(0xFF7565D1),
                          ),
                        ),
                ),
                // Duty Status Dot (Green / Red)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                // Rating Badge
                Positioned(
                  bottom: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 10, color: Color(0xFF7565D1)),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // DOCTOR NAME
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF303030),
            ),
          ),

          const SizedBox(height: 2),

          // SPECIALTY
          Text(
            specialty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color.fromARGB(255, 116, 116, 121),
            ),
          ),

          const SizedBox(height: 4),

          // LIVE STATUS / DELAY TAG
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: delayMinutes > 0
                  ? Colors.orange.shade100
                  : (isAvailable ? Colors.green.shade50 : Colors.orange.shade50),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              delayMinutes > 0 ? 'Delayed $delayMinutes m' : dutyStatus,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: delayMinutes > 0
                    ? Colors.orange.shade800
                    : (isAvailable ? Colors.green.shade700 : Colors.orange.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALL DOCTORS BOTTOM SHEET (TRIGGERED BY "SEE ALL")
  // ============================================================
  void _showAllDoctorsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Doctors',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // FULL DOCTORS LIST
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _doctorsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF8171E5)));
                    }

                    List doctors = snapshot.data ?? [];

                    return ListView.builder(
                      itemCount: doctors.length,
                      itemBuilder: (context, index) {
                        final doc = doctors[index];
                        final String name = doc['name'] ?? 'Doctor';
                        final String spec = doc['specialties']?['name'] ?? 'Specialist';
                        final int exp = doc['years_experience'] ?? 0;
                        final String rating = (doc['rating'] ?? 5.0).toString();
                        final String? img = doc['image_url'];

                        final List availList = doc['doctor_availability'] ?? [];
                        final Map<String, dynamic>? avail =
                          _primaryAvailabilityForDisplay(availList);
                        final String status = _deriveDisplayDutyStatus(avail);
                        final bool isAvailable = status.toUpperCase() == 'AVAILABLE';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: const Color.fromARGB(255, 243, 243, 250),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFE5E0FA),
                              backgroundImage: (img != null && img.startsWith('http')) ? NetworkImage(img) : null,
                              child: img == null ? const Icon(Icons.person, color: Color(0xFF7565D1)) : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text('$spec • $exp yrs exp\n⭐ $rating'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}