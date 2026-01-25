// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import '../../widgets/common_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const TopGreenShape(),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  // Logo
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppLogo(size: 100),
                  ),
                  const SizedBox(height: 20),
                  // Texts
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "เข้าสู่ระบบ",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "ยินดีต้อนรับกลับมา",
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 120), // เว้นระยะให้พ้น BG สีเขียว
                  // Form Fields
                  const CustomTextField(label: "อีเมล"),
                  const CustomTextField(
                    label: "รหัสผ่าน",
                    isPassword: true,
                    suffixIcon: Icons.visibility_outlined,
                  ),

                  const SizedBox(height: 40),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.to(() => const HomeScreen()),
                      child: const Text("เข้าสู่ระบบ"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "คุณยังไม่มีบัญชี? ",
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "ลงทะเบียน",
                          style: TextStyle(
                            color: Color(0xFF2CB834),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
