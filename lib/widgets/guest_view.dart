import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';
import 'package:saidee_app/screens/auth/register_screen.dart';

class GuestView extends StatelessWidget {
  const GuestView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(isDark ? 0.05 : 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      scale: 4.5,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        CupertinoIcons.bag,
                        size: 50,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text(
                    "ยินดีต้อนรับสู่ SAIDEE",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 15),

                  Text(
                    "แหล่งรวมเสื้อผ้ามือสองคุณภาพดี\nเข้าสู่ระบบเพื่อเริ่มต้นประสบการณ์ที่ดีที่สุด",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildBenefitTile(context, "ติดตามสถานะคำสั่งซื้อได้ง่ายๆ"),
                  _buildBenefitTile(context, "บันทึกสินค้าที่ชอบลงรายการโปรด"),
                  _buildBenefitTile(context, "ลงขายสินค้าของคุณเอง"),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => Get.to(() => const LoginScreen()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      child: const Text(
                        "เข้าสู่ระบบ",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: () => Get.to(() => const RegisterScreen()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "สร้างบัญชีใหม่",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

  Widget _buildBenefitTile(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
