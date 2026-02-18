import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class TopGreenShape extends StatelessWidget {
  const TopGreenShape({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      left: -50,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.9),
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(200),
            bottomLeft: Radius.circular(100),
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final bool isPassword;
  final TextInputType inputType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final bool isNumber;

  const CustomTextField({
    super.key,
    required this.label,
    this.isPassword = false,
    this.inputType = TextInputType.text,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.onToggleVisibility,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? AppTheme.primaryColor : const Color(0xFF1B8022),
              fontSize: 16,
            ),
          ),
        ),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),

            TextFormField(
              controller: controller,
              validator: validator,
              obscureText: isPassword ? obscureText : false,
              keyboardType: isNumber ? TextInputType.number : inputType,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorStyle: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 12,
                  height: 1.2,
                ),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          obscureText
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: Colors.grey,
                        ),
                        onPressed: onToggleVisibility,
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Icon(CupertinoIcons.bag, size: 50, color: Colors.grey),
      ),
    );
  }
}
