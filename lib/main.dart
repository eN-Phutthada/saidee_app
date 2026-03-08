import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:saidee_app/screens/splash_screen.dart';
import 'package:saidee_app/screens/chat/chat_screen.dart';
import 'config/theme.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const SaiDeeApp(),
    ),
  );
}

class SaiDeeApp extends StatefulWidget {
  const SaiDeeApp({super.key});

  @override
  State<SaiDeeApp> createState() => _SaiDeeAppState();
}

class _SaiDeeAppState extends State<SaiDeeApp> {
  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'ช่องทางการแจ้งเตือนสำคัญของแอป SAIDEE',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('ได้รับข้อความขณะเปิดแอป!');
      if (message.notification != null) {
        Get.snackbar(
          message.notification!.title ?? 'แจ้งเตือนใหม่',
          message.notification!.body ?? '',
          backgroundColor: Colors.white,
          colorText: Colors.black87,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(15),
          duration: const Duration(seconds: 4),
          boxShadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          icon: const Icon(
            CupertinoIcons.chat_bubble_text_fill,
            color: AppTheme.primaryColor,
          ),
          onTap: (_) {
            _handleNotificationClick(message);
          },
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('ผู้ใช้กดเปิดแอปจากการแจ้งเตือน!');
      _handleNotificationClick(message);
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 2), () {
        _handleNotificationClick(initialMessage);
      });
    }
  }

  void _handleNotificationClick(RemoteMessage message) async {
    if (message.data['type'] == 'chat') {
      String senderId = message.data['senderId'] ?? '';

      if (senderId.isNotEmpty) {
        try {
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get();
          if (userDoc.exists) {
            String name = userDoc.data()?['name'] ?? 'ผู้ใช้งาน';
            String image = userDoc.data()?['profileImage'] ?? '';

            Get.to(
              () => ChatScreen(
                targetUserId: senderId,
                targetUserName: name,
                targetUserImage: image,
              ),
            );
          }
        } catch (e) {
          debugPrint("เกิดข้อผิดพลาดในการเปิดแชทจากแจ้งเตือน: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GetMaterialApp(
      title: 'SaiDee Application',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),

      home: const SplashScreen(),
    );
  }
}
