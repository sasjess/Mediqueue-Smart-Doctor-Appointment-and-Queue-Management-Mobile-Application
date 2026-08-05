import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEBFA),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            color: const Color(0xFFECEBFA),
            child: Column(
              children: [
                // ========================================================
                // TOP ILLUSTRATION AREA
                // ========================================================
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Image.asset(
                          'lib/images/starting.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.medical_services_outlined,
                            size: 150,
                            color: Color(0xFF8171E5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ========================================================
                // BOTTOM CONTAINER WITH CUSTOM CURVED CLIPPER
                // ========================================================
                Expanded(
                  flex: 2,
                  child: ClipPath(
                    clipper: TopCurveClipper(), // 👈 Custom curve applied here!
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.only(
                        left: 28.0,
                        right: 28.0,
                        top: 48.0, // Added extra top padding so text doesn't overlap the curve
                        bottom: 29.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // TEXT CONTENT
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'All specialists in one app',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E1E28),
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Find your doctor and make an\nappointment with one tap',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.2,
                                  color: Color.fromARGB(255, 17, 17, 18),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          // GET STARTED BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/reception');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B52E1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
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
}

// ============================================================
// CUSTOM CLIPPER FOR TOP WAVE / CURVE
// ============================================================
class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    
    // Start at top-left, slightly dipped down
    path.lineTo(0, 30);

    // Quadratic curve across the top edge
    Offset controlPoint = Offset(size.width / 2, 0); // Peak of the curve
    Offset endPoint = Offset(size.width, 30);
    path.quadraticBezierTo(
      controlPoint.dx, 
      controlPoint.dy, 
      endPoint.dx, 
      endPoint.dy,
    );

    // Complete the rectangle path around the bottom
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}



// import 'package:flutter/material.dart';
// import 'home_page.dart';
// import 'package:mediqueue/main.dart'; 

// class OnboardingPage extends StatelessWidget {
//   const OnboardingPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFECEBFA), // Background behind top image
//       body: SafeArea(
//         child: Center(
//           child: Container(
//             constraints: const BoxConstraints(maxWidth: 800),
//             color: const Color(0xFFECEBFA),
//             child: Column(
//               children: [
//                 // ========================================================
//                 // TOP ILLUSTRATION AREA
//                 // ========================================================
//                 Expanded(
//                   flex: 4, // 👈 Increased from 3 to 5 to give image more space
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0), // 👈 Reduced padding
//                     child: Center(
//                       child: SizedBox(
//                         width: double.infinity,
//                         height: double.infinity,
//                         child: Image.asset(
//                           'lib/images/starting.png',
//                           fit: BoxFit.contain, // 👈 Keeps aspect ratio while expanding
//                           errorBuilder: (context, error, stackTrace) =>
//                               const Icon(
//                             Icons.medical_services_outlined,
//                             size: 150, // 👈 Larger fallback icon size
//                             color: Color(0xFF8171E5),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 // ========================================================
//                 // BOTTOM WHITE CONTAINER WITH CONTENT
//                 // ========================================================
//                 Expanded(
//                   flex: 2,
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 28.0,
//                       vertical: 38.0,
//                     ),
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.only(
//                         topLeft: Radius.circular(35),
//                         topRight: Radius.circular(35),
//                       ),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         // TEXT CONTENT
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: const [
//                             Text(
//                               'All specialists in one app',
//                               style: TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.w800,
//                                 color: Color(0xFF1E1E28),
//                                 height: 1.2,
//                               ),
//                             ),
//                             SizedBox(height: 13),
//                             Text(
//                               'Find your doctor and make an\nappointment with one tap',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 height: 1.2,
//                                 color: Color.fromARGB(255, 17, 17, 18),
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ],
//                         ),

//                         // GET STARTED BUTTON
//                         SizedBox(
//                           width: double.infinity,
//                           height: 54,
//                           child: ElevatedButton(
//                             onPressed: () {
//                               // Navigate to HomePage
//                               Navigator.pushReplacement(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) => const NavigationWrapper(),
//                                 ),
//                               );
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: const Color(0xFF5B52E1),
//                               foregroundColor: Colors.white,
//                               elevation: 0,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(16),
//                               ),
//                             ),
//                             child: const Text(
//                               'Get Started',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }