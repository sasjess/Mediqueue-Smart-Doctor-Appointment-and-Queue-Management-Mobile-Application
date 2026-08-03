import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedCategoryIndex = 0;

  // Search controller & state variable
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // CATEGORIES
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // DOCTORS
  // ------------------------------------------------------------

  final List<Map<String, String>> doctors = [
    {
      'name': 'Dr. Arlene McCoy',
      'specialty': 'Therapist, 7 y.e',
      'image': 'lib/images/doctor1.avif',
      'rating': '4.9',
    },
    {
      'name': 'Dr. Albert Flores',
      'specialty': 'Surgeon, 5 y.e',
      'image': 'lib/images/doctor2.avif',
      'rating': '4.8',
    },
    {
      'name': 'Dr. Aisha Khan',
      'specialty': 'Dentist, 8 y.e',
      'image': 'lib/images/doctor3.avif',
      'rating': '4.9',
    },
    {
      'name': 'Dr. Sara Malik',
      'specialty': 'Dermatologist, 6 y.e',
      'image': 'lib/images/doctor1.avif',
      'rating': '4.7',
    },
  ];

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E9F7),

      // ========================================================
      // MAIN BODY
      // ========================================================

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
                // ==================================================
                // SCROLLABLE CONTENT
                // ==================================================

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

                          const SizedBox(height: 35),

                          // MEDICAL BANNER
                          _buildMedicalBanner(),

                          const SizedBox(height: 35),

                          // SEARCH
                          _buildSearchBox(),

                          const SizedBox(height: 35),

                          // CATEGORIES TITLE
                          _buildSectionTitle(
                            title: 'Categories',
                            actionText: 'See all',
                          ),

                          const SizedBox(height: 12),

                          // CATEGORIES
                          _buildCategories(),

                          const SizedBox(height: 35),

                          // DOCTOR LIST TITLE
                          _buildSectionTitle(
                            title: 'Doctor list',
                            actionText: 'See all',
                          ),

                          const SizedBox(height: 12),

                          // DOCTORS
                          _buildDoctorList(),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w400,
                ),
              ),

              SizedBox(height: 3),

              Text(
                'Jerome Bell',
                style: TextStyle(
                  fontSize: 22,
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
            child: Image.asset(
              'lib/images/doctor1.avif',
              fit: BoxFit.cover,
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
          // ------------------------------------------------------
          // LEFT ILLUSTRATION
          // ------------------------------------------------------

          SizedBox(
            width: 125,
            height: double.infinity,

            child: Stack(
              alignment: Alignment.center,

              children: [
                // Purple background circle
                Positioned(
                  bottom: 10,
                  left: 25,

                  child: Container(
                    width: 70,
                    height: 70,

                    decoration: const BoxDecoration(
                      color: Color(0xFF5A4BB7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Head
                Positioned(
                  top: 18,
                  left: 55,

                  child: Container(
                    width: 27,
                    height: 27,

                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC8B7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Body
                Positioned(
                  bottom: 8,
                  left: 48,

                  child: Container(
                    width: 48,
                    height: 72,

                    decoration: BoxDecoration(
                      color: const Color(0xFF6355C2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),

                // Medical card
                Positioned(
                  right: 5,
                  bottom: 22,

                  child: Transform.rotate(
                    angle: -0.08,

                    child: Container(
                      width: 43,
                      height: 31,

                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB7D7),
                        borderRadius: BorderRadius.circular(5),
                      ),

                      child: const Icon(
                        Icons.medical_information_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // BANNER TEXT
          // ------------------------------------------------------

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 12,
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'How do you feel?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF242424),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Fill out your medical\ncard right now.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      color: Color(0xFF777777),
                    ),
                  ),

                  const SizedBox(height: 9),

                  SizedBox(
                    height: 35,
                    width: 120,

                    child: ElevatedButton(
                      onPressed: () {},

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
                        'Get Started',
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

  // ============================================================
  // SEARCH BOX (UPDATED TO TEXTFIELD)
  // ============================================================

  Widget _buildSearchBox() {
    return Container(
      height: 52,
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
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: const InputDecoration(
          hintText: 'How can we help you?',
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
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required String title,
    required String actionText,
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
          onTap: () {},

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

          final bool selected =
              selectedCategoryIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategoryIndex = index;
              });
            },

            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 200,
              ),

              width: 110,

              margin: EdgeInsets.only(
                right: index == categories.length - 1
                    ? 0
                    : 9,
              ),

              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEDEAFF)
                    : const Color(0xFFF9F9FD),

                borderRadius: BorderRadius.circular(13),

                border: Border.all(
                  color: selected
                      ? const Color(0xFFDCD5FF)
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
                        fontSize: 11,

                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,

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
  // DOCTOR LIST
  // ============================================================

  Widget _buildDoctorList() {
    return SizedBox(
      height: 175,

      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,

        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),

        itemCount: doctors.length,

        itemBuilder: (context, index) {
          return _buildDoctorCard(
            doctors[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // DOCTOR CARD
  // ============================================================

  Widget _buildDoctorCard(
    Map<String, String> doctor,
  ) {
    return Container(
      width: 135,

      margin: const EdgeInsets.only(
        right: 12,
      ),

      padding: const EdgeInsets.fromLTRB(
        10,
        10,
        10,
        8,
      ),

      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FD),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(
          color: const Color(0xFFF2F2F8),
        ),
      ),

      child: Column(
        children: [
          // ------------------------------------------------------
          // DOCTOR IMAGE + RATING
          // ------------------------------------------------------

          SizedBox(
            height: 74,

            child: Stack(
              clipBehavior: Clip.none,

              alignment: Alignment.center,

              children: [
                // Background circle
                Container(
                  width: 66,
                  height: 66,

                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE5E0FA),
                  ),
                ),

                // Doctor image
                ClipOval(
                  child: Image.asset(
                    doctor['image']!,
                    width: 65,
                    height: 65,
                    fit: BoxFit.cover,
                  ),
                ),

                // Rating
                Positioned(
                  bottom: -1,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius:
                          BorderRadius.circular(8),

                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.06),
                          blurRadius: 5,
                        ),
                      ],
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        const Icon(
                          Icons.star,
                          size: 10,
                          color: Color(0xFF7565D1),
                        ),

                        const SizedBox(width: 3),

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
          ),

          const SizedBox(height: 8),

          // DOCTOR NAME
          Text(
            doctor['name']!,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF303030),
            ),
          ),

          const SizedBox(height: 4),

          // SPECIALTY
          Text(
            doctor['specialty']!,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 10,
              color: Color.fromARGB(255, 116, 116, 121),
            ),
          ),
        ],
      ),
    );
  }
}