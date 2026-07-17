import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/admin/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _decideRoute);
  }

  Future<void> _decideRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();
            
        if (adminDoc.exists) {
          Get.off(
            () => const AdminDashboard(),
            transition: Transition.circularReveal,
            duration: const Duration(milliseconds: 1000),
          );
          return;
        }
      } catch (e) {
        debugPrint("Error checking admin status in Splash: $e");
      }
    }

    Get.off(
      () => const HomeScreen(),
      transition: Transition.circularReveal,
      duration: const Duration(milliseconds: 1000),
    );
  }

  static const _green = Color(0xFF28B431);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              padding: const EdgeInsets.all(18),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                Text(
                  'SAIDEE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.staatliches(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = _green,
                    shadows: [
                      Shadow(color: _green, offset: const Offset(6, 0)),
                    ],
                  ),
                ),
                Text(
                  'SAIDEE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.staatliches(
                    fontSize: 52,
                    letterSpacing: 1.2,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              'SECONDHAND, FIRST CHOICE',
              style: GoogleFonts.notoSans(
                color: isDark ? Colors.grey[400] : const Color(0xFF8C8C8C),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
