import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpecialistPage extends StatefulWidget {
  const SpecialistPage({super.key});

  @override
  State<SpecialistPage> createState() => _SpecialistPageState();
}

class _SpecialistPageState extends State<SpecialistPage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  
  // 1. Declare the Future variable
  late Future<List<Map<String, dynamic>>> _specialtiesFuture;

  @override
  void initState() {
    super.initState();
    // 2. Fetch data ONCE when the screen loads
    _specialtiesFuture = _fetchSpecialties();
  }

  // Helper method to fetch from Supabase
  Future<List<Map<String, dynamic>>> _fetchSpecialties() async {
    final response = await Supabase.instance.client
        .from('specialties')
        .select('id, name, description');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Icon mapping helper based on specialty name
  IconData _getSpecialtyIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('dent')) return Icons.medical_services_outlined;
    if (lowerName.contains('surg')) return Icons.healing_outlined;
    if (lowerName.contains('therap')) return Icons.accessibility_new_outlined;
    if (lowerName.contains('cardio') || lowerName.contains('heart')) return Icons.favorite_border;
    if (lowerName.contains('skin') || lowerName.contains('derma')) return Icons.face_outlined;
    if (lowerName.contains('child') || lowerName.contains('pedia')) return Icons.child_care_outlined;
    if (lowerName.contains('eye') || lowerName.contains('opht')) return Icons.remove_red_eye_outlined;
    if (lowerName.contains('neuro')) return Icons.psychology_outlined;
    return Icons.local_hospital_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text(
          'Specialists & Services',
          style: TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // SEARCH BAR
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAF8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      searchQuery = val;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search specialty or service...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF8171E5)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            // SPECIALISTS LIST
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                // 3. Pass the stored future instance here
                future: _specialtiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8171E5)),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading specialties: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  List<Map<String, dynamic>> specialties = snapshot.data ?? [];

                  // 4. Filter the cached dataset locally when typing
                  if (searchQuery.isNotEmpty) {
                    specialties = specialties.where((item) {
                      final name = (item['name'] ?? '').toString().toLowerCase();
                      final desc = (item['description'] ?? '').toString().toLowerCase();
                      final query = searchQuery.toLowerCase();
                      return name.contains(query) || desc.contains(query);
                    }).toList();
                  }

                  if (specialties.isEmpty) {
                    return const Center(
                      child: Text(
                        'No specialists found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: specialties.length,
                    itemBuilder: (context, index) {
                      final item = specialties[index];
                      final String name = item['name'] ?? 'Specialist';
                      final String description = item['description'] ??
                          'Medical professional specializing in $name treatments and comprehensive patient care.';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFF0F0F8),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ICON BADGE
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E0FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getSpecialtyIcon(name),
                                color: const Color(0xFF8171E5),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // TITLE & DESCRIPTION
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF222222),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}