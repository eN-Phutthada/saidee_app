import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:saidee_app/screens/splash_screen.dart';
import 'package:saidee_app/screens/chat/chat_screen.dart';

import 'package:saidee_app/screens/order/seller_orders_screen.dart';
import 'package:saidee_app/screens/order/seller_order_detail_screen.dart';
import 'package:saidee_app/screens/order/buyer_order_detail_screen.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

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

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
        debugPrint("FCM Token Refreshed: $newToken");
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('ได้รับข้อความขณะเปิดแอป! Type: ${message.data['type']}');

      if (message.notification != null) {
        IconData notifIcon = CupertinoIcons.bell_fill;
        Color notifColor = AppTheme.primaryColor;
        String? type = message.data['type'];

        if (type == 'chat') {
          notifIcon = CupertinoIcons.chat_bubble_text_fill;
        } else if (type == 'new_order') {
          notifIcon = CupertinoIcons.cube_box_fill;
          notifColor = Colors.orange;
        } else if (type == 'order_status') {
          notifIcon = CupertinoIcons.car_detailed;
          notifColor = Colors.blue;
        } else if (type == 'return_status') {
          notifIcon = CupertinoIcons.exclamationmark_triangle_fill;
          notifColor = Colors.red;
        }

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
          icon: Icon(notifIcon, color: notifColor),
          onTap: (_) {
            _handleNotificationClick(message);
          },
        );

        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'ช่องทางการแจ้งเตือนสำคัญของแอป SAIDEE',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
        const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
        
        flutterLocalNotificationsPlugin.show(
          id: message.hashCode,
          title: message.notification!.title ?? 'แจ้งเตือนใหม่',
          body: message.notification!.body ?? '',
          notificationDetails: platformDetails,
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
    String? type = message.data['type'];

    if (type == 'chat') {
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

            if (Get.currentRoute.contains('ChatScreen')) {
              Get.back();
            }

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
    } else if (type == 'new_order') {
      Get.to(() => const SellerOrdersScreen());
    } else if (type == 'order_status' || type == 'return_status') {
      String orderId = message.data['orderId'] ?? '';
      if (orderId.isNotEmpty) {
        try {
          var orderDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();

          if (orderDoc.exists) {
            var orderData = orderDoc.data() as Map<String, dynamic>;
            final currentUser = FirebaseAuth.instance.currentUser;

            if (currentUser != null) {
              if (orderData['sellerId'] == currentUser.uid) {
                Get.to(
                  () => SellerOrderDetailScreen(
                    orderId: orderId,
                    orderData: orderData,
                  ),
                );
              } else {
                Get.to(
                  () => BuyerOrderDetailScreen(
                    orderId: orderId,
                    orderData: orderData,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint("เกิดข้อผิดพลาดในการเปิดออเดอร์จากแจ้งเตือน: $e");
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
      navigatorKey: navigatorKey,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 400),

      home: const SplashScreen(),
    );
  }
}
