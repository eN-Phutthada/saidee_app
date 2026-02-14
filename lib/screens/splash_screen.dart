import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/screens/home/home_screen.dart';

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
    Get.off(
      () => const HomeScreen(),
      transition: Transition.circularReveal,
      duration: const Duration(milliseconds: 1000),
    );
  }

  static const _green = Color(0xFF28B431);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
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
                color: const Color(0xFF8C8C8C),
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
