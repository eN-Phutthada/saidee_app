import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/providers/theme_provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App basic smoke test: loads theme and wraps properly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return GetMaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const Scaffold(
                body: Center(
                  child: Text('SAIDEE App Initialized'),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('SAIDEE App Initialized'), findsOneWidget);
  });
}
