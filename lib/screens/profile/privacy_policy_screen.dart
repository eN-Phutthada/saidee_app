import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("นโยบายความเป็นส่วนตัว"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/documents/privacy_policy_saidee.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "เกิดข้อผิดพลาดในการโหลดนโยบายความเป็นส่วนตัว",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            );
          }
          return Markdown(
            data: snapshot.data ?? "",
            styleSheet: MarkdownStyleSheet(
              h1: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
              h2: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              h3: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
              p: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 15, height: 1.5),
              listBullet: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          );
        },
      ),
    );
  }
}
