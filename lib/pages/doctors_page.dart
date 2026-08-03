import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const CustomScrollBehavior(),
      home: const DoctorsPage(),
    ),
  );
}

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  String selectedSpecialization = 'All';
  String searchQuery = '';

  // Dropdown items for Specialization
  final List<String> specializations = [
    'All',
    'Therapist',
    'Surgeon',
    'Dentist',
    'Dermatologist',
    'Cardiologist',
    'Pediatrician',
  ];

  // Master Doctor Data
  final List<Map<String, String>> allDoctors = [
    {
      'name': 'Dr. Arlene McCoy',
      'specialty': 'Therapist',
      'experience': '7 y.e',
      'image': 'lib/images/doctor1.avif',
      'rating': '4.9',
      'hospital': 'City Medical Center',
      'availability': 'Available Today',
    },
    {
      'name': 'Dr. Albert Flores',
      'specialty': 'Surgeon',
      'experience': '5 y.e',
      'image': 'lib/images/doctor2.avif',
      'rating': '4.8',
      'hospital': 'General Health Hospital',
      'availability': 'Available Today',
    },
    {
      'name': 'Dr. Aisha Khan',
      'specialty': 'Dentist',
      'experience': '8 y.e',
      'image': 'lib/images/doctor3.avif',
      'rating': '4.9',
      'hospital': 'Smile Clinic',
      'availability': 'Available Today',
    },
    {
      'name': 'Dr. Sara Malik',
      'specialty': 'Dermatologist',
      'experience': '6 y.e',
      'image': 'lib/images/doctor1.avif',
      'rating': '4.7',
      'hospital': 'Skin Care Institute',
      'availability': 'Available Today',
    },
    {
      'name': 'Dr. Robert Fox',
      'specialty': 'Cardiologist',
      'experience': '10 y.e',
      'image': 'lib/images/doctor2.avif',
      'rating': '5.0',
      'hospital': 'Heart Care Center',
      'availability': 'Available Today',
    },
    {
      'name': 'Dr. Eleanor Pena',
      'specialty': 'Pediatrician',
      'experience': '4 y.e',
      'image': 'lib/images/doctor3.avif',
      'rating': '4.8',
      'hospital': 'Children Hope Hospital',
      'availability': 'Available Today',
    },
  ];

  // Get filtered list based on dropdown & search text
  List<Map<String, String>> get filteredDoctors {
    return allDoctors.where((doctor) {
      final matchesSpecialty = selectedSpecialization == 'All' ||
          doctor['specialty'] == selectedSpecialization;

      final matchesQuery = searchQuery.isEmpty ||
          doctor['name']!.toLowerCase().contains(searchQuery.toLowerCase()) ||
          doctor['specialty']!.toLowerCase().contains(searchQuery.toLowerCase());

      return matchesSpecialty && matchesQuery;
    }).toList();
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E9F7),

      // MAIN BODY
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // 1. TITLE & SUBTITLE
                        _buildHeader(),

                        const SizedBox(height: 20),

                        // 2. SEARCH BOX
                        _buildSearchBox(),

                        const SizedBox(height: 20),

                        // 3. SPECIALIZATION DROPDOWN
                        _buildSpecializationDropdown(),

                        const SizedBox(height: 24),

                        // 4. AVAILABLE DOCTORS SECTION TITLE
                        const Text(
                          'Available Doctors',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF292929),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 5. VERTICAL SCROLL VIEW FOR DOCTOR CARDS
                        Expanded(
                          child: _buildVerticalDoctorList(),
                        ),
                      ],
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Doctors',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Find the right Doctor for you',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF777777),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH BOX
  // ============================================================

  Widget _buildSearchBox() {
    return Container(
      height: 50,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFF1F1F8),
        ),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: const InputDecoration(
          hintText: 'Search doctors...',
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
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ============================================================
  // SPECIALIZATION DROPDOWN
  // ============================================================

  Widget _buildSpecializationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specialization',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E5F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSpecialization,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF8171E5),
              ),
              isExpanded: true,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
              items: specializations.map((String specialty) {
                return DropdownMenuItem<String>(
                  value: specialty,
                  child: Text(specialty),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedSpecialization = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VERTICAL DOCTOR LIST
  // ============================================================

  Widget _buildVerticalDoctorList() {
    final docs = filteredDoctors;

    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'No doctors found.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        return _buildDoctorCard(docs[index]);
      },
    );
  }

  // ============================================================
  // DOCTOR CARD (HORIZONTAL LAYOUT FOR VERTICAL LIST)
  // ============================================================

  Widget _buildDoctorCard(Map<String, String> doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF2F2F8),
        ),
      ),
      child: Row(
        children: [
          // Doctor Image + Rating Tag
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5E0FA),
                ),
                child: ClipOval(
                  child: Image.asset(
                    doctor['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, color: Color(0xFF8171E5)),
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 10,
                        color: Color(0xFF7565D1),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        doctor['rating']!,
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

          const SizedBox(width: 16),

          // Doctor Details Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor['name']!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF303030),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${doctor['specialty']} • ${doctor['experience']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF747479),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor['hospital']!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9EAE),
                  ),
                ),
              ],
            ),
          ),

          // Book / Status Action
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEAFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Book',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A4BB7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom behavior for smooth drag scrolling across platforms
class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}