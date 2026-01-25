// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import '../../widgets/common_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const TopGreenShape(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 100),
                const AppLogo(size: 90),
                const SizedBox(height: 10),
                const Text(
                  "สร้างบัญชี",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B8022),
                  ),
                ),
                const SizedBox(height: 30),

                // Content Area
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // ห้ามปัดเอง ต้องกดปุ่ม
                    children: [
                      _buildStep1(), // ข้อมูลทั่วไป
                      _buildStep2(), // รูปโปรไฟล์
                      _buildStep3(), // รหัสผ่าน
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "คุณมีบัญชีอยู่แล้ว? ",
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "เข้าสู่ระบบ",
                          style: TextStyle(
                            color: Color(0xFF2CB834),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: ชื่อ, อีเมล, เบอร์โทร
  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const CustomTextField(label: "ชื่อ - สกุล"),
          const CustomTextField(
            label: "อีเมล",
            inputType: TextInputType.emailAddress,
          ),
          const CustomTextField(
            label: "เบอร์โทร",
            inputType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: const Text("ถัดไป"),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: รูปโปรไฟล์
  Widget _buildStep2() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "รูปโปรไฟล์",
            style: TextStyle(color: Color(0xFF2CB834), fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
            color: Colors.white,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.camera_alt_outlined,
              size: 50,
              color: Colors.grey,
            ),
            onPressed: () {
              // TODO: Implement Image Picker
            },
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextPage,
            child: const Text("ถัดไป"),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Step 3: รหัสผ่าน
  Widget _buildStep3() {
    return Column(
      children: [
        const CustomTextField(
          label: "รหัสผ่าน",
          isPassword: true,
          suffixIcon: Icons.visibility_outlined,
        ),
        const CustomTextField(
          label: "ยืนยันรหัสผ่าน",
          isPassword: true,
          suffixIcon: Icons.visibility_outlined,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Get.to(() => const HomeScreen()),
            child: const Text("ลงทะเบียน"),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
