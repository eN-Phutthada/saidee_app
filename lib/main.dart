import 'dart:convert';
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
import 'package:saidee_app/screens/order/buyer_order_detail_screen.dart';

import 'package:saidee_app/screens/splash_screen.dart';
import 'package:saidee_app/screens/chat/chat_screen.dart';

import 'package:saidee_app/screens/order/seller_orders_screen.dart';
import 'package:saidee_app/screens/order/seller_order_detail_screen.dart';
import 'package:saidee_app/screens/wallet/wallet_history_screen.dart';
import 'package:saidee_app/services/notification_service.dart';

import 'config/theme.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';

// ช่องทางการแจ้งเตือนสำคัญระดับระบบ Android
const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'ช่องทางการแจ้งเตือนสำคัญของแอป SAIDEE',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId} (data: ${message.data})");

  // สร้าง Channel สำหรับ background isolate
  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImplementation?.createNotificationChannel(highImportanceChannel);

  // กรณีเป็น Data-only message (message.notification เป็น null)
  // ระบบ Android จะไม่แจ้งเตือนอัตโนมัติเมื่อปิดแอป ต้องแสดงผ่าน LocalNotifications เอง
  if (message.notification == null && message.data.isNotEmpty) {
    String title = (message.data['title'] ??
            message.data['senderName'] ??
            'แจ้งเตือนใหม่')
        .toString();
    String body = (message.data['body'] ??
            message.data['message'] ??
            message.data['content'] ??
            '')
        .toString();

    if (title.isNotEmpty || body.isNotEmpty) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            highImportanceChannel.id,
            highImportanceChannel.name,
            channelDescription: highImportanceChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/launcher_icon',
          );

      await flutterLocalNotificationsPlugin.show(
        id: message.hashCode.abs() % 100000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: jsonEncode(message.data),
      );
    }
  }
}

/// นำทางผู้ใช้ไปยังหน้าที่เกี่ยวข้องเมื่อกดที่แจ้งเตือน
void handleNotificationClickFromData(Map<String, dynamic> data) async {
  String? type = data['type'];

  if (type == 'chat') {
    String senderId = (data['senderId'] ?? '').toString();

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
  } else if (type == 'wallet') {
    Get.to(() => const WalletHistoryScreen());
  } else if (type == 'order_status' ||
      type == 'return_status' ||
      type == 'order' ||
      type == 'dispute') {
    String orderId = (data['orderId'] ?? '').toString();
    if (orderId.isEmpty && data['extraData'] is Map) {
      orderId = (data['extraData']['orderId'] ?? '').toString();
    }

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Info: .env file not loaded from assets: $e");
    try {
      dotenv.loadFromString(envString: '');
    } catch (_) {}
  }

  // สร้าง Channel ให้ระบบ Android ล่วงหน้าตั้งแต่ main() เพื่อให้พร้อมรับแจ้งเตือนเมื่อปิดแอป
  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImplementation?.createNotificationChannel(highImportanceChannel);

  // ตั้งค่า Local Notifications สำหรับดักจับการคลิกแจ้งเตือน
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      debugPrint("Local notification clicked: ${details.payload}");
      if (details.payload != null && details.payload!.isNotEmpty) {
        try {
          Map<String, dynamic> data = jsonDecode(details.payload!);
          handleNotificationClickFromData(data);
        } catch (e) {
          debugPrint("Error parsing notification payload: $e");
        }
      }
    },
  );

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

  Future<void> _syncFcmToken({String? specificToken}) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String? token =
          specificToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(currentUser.uid)
          .get();

      final targetCollection = adminDoc.exists ? 'admins' : 'users';

      await FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(currentUser.uid)
          .set({
            'fcmToken': token,
            'lastActive': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint("FCM Token synced to $targetCollection: $token");
    } catch (e) {
      debugPrint("Error syncing FCM token: $e");
    }
  }

  Future<void> _setupPushNotifications() async {
    // 1. ขอสิทธิ์การแจ้งเตือน Android 13+
    var androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

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

    // 2. ปิด alert ของระบบขณะเปิดแอปอยู่ เพื่อไม่ให้เด้งซ้อนกับ In-App Get.snackbar
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );

    // 3. ซิงค์ FCM Token ให้ตรงกับบัญชีที่ล็อกอินอยู่เสมอ
    _syncFcmToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _syncFcmToken(specificToken: newToken);
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncFcmToken();
      }
    });

    // 4. ดักจับข้อความแจ้งเตือนขณะเปิดแอป (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('ได้รับข้อความขณะเปิดแอป! Type: ${message.data['type']}');

      String title = message.notification?.title ??
          message.data['title'] ??
          message.data['senderName'] ??
          'แจ้งเตือนใหม่';
      String body = message.notification?.body ??
          message.data['body'] ??
          message.data['message'] ??
          '';

      if (title.isEmpty && body.isEmpty) return;

      // กรองแจ้งเตือนซ้ำ
      if (NotificationService.isDuplicateNotification(title, body)) return;

      IconData notifIcon = CupertinoIcons.bell_fill;
      Color notifColor = AppTheme.primaryColor;
      String? type = message.data['type'];

      if (type == 'chat') {
        notifIcon = CupertinoIcons.chat_bubble_text_fill;
        notifColor = Colors.purple;
      } else if (type == 'new_order') {
        notifIcon = CupertinoIcons.cube_box_fill;
        notifColor = Colors.orange;
      } else if (type == 'order_status' || type == 'order') {
        notifIcon = CupertinoIcons.car_detailed;
        notifColor = Colors.blue;
      } else if (type == 'return_status' || type == 'dispute') {
        notifIcon = CupertinoIcons.exclamationmark_triangle_fill;
        notifColor = Colors.red;
      } else if (type == 'wallet') {
        notifIcon = CupertinoIcons.money_dollar_circle_fill;
        notifColor = Colors.green;
      }

      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }

      // แสดงเฉพาะ In-App Get.snackbar เท่านั้น
      // ไม่เรียก flutterLocalNotificationsPlugin.show() ใน foreground เพื่อแก้ปัญหาการแจ้งเตือนซ้อนกัน
      Get.snackbar(
        title,
        body,
        backgroundColor: Colors.white,
        colorText: Colors.black87,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 4),
        boxShadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        icon: Icon(notifIcon, color: notifColor),
        onTap: (_) {
          handleNotificationClickFromData(message.data);
        },
      );
    });

    // 5. ดักจับเมื่อผู้ใช้กดเปิดแอปจากการแจ้งเตือนใน Background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('ผู้ใช้กดเปิดแอปจากการแจ้งเตือน!');
      handleNotificationClickFromData(message.data);
    });

    // 6. ดักจับเมื่อเปิดแอปจาก Terminated state ผ่าน FCM Notification
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        handleNotificationClickFromData(initialMessage.data);
      });
    }

    // 7. ดักจับเมื่อเปิดแอปจาก Terminated state ผ่าน Local Notification
    final NotificationAppLaunchDetails? launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse?.payload != null &&
        launchDetails.notificationResponse!.payload!.isNotEmpty) {
      try {
        Map<String, dynamic> data =
            jsonDecode(launchDetails.notificationResponse!.payload!);
        Future.delayed(const Duration(seconds: 1), () {
          handleNotificationClickFromData(data);
        });
      } catch (e) {
        debugPrint("Error parsing launch notification payload: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GetMaterialApp(
      title: 'SaiDee Beta',
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
