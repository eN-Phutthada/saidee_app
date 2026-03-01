import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class QRPaymentScreen extends StatefulWidget {
  final String qrString;
  final double amount;
  final String refNo;

  const QRPaymentScreen({
    super.key,
    required this.qrString,
    required this.amount,
    required this.refNo,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen> {
  StreamSubscription<DocumentSnapshot>? _txSubscription;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _listenForPaymentSuccess();
  }

  void _listenForPaymentSuccess() {
    _txSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .doc(widget.refNo)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            var data = snapshot.data() as Map<String, dynamic>;
            if (data['status'] == 'success') {
              _txSubscription?.cancel();

              AppDialog.showCustomDialog(
                title: "เติมเงินสำเร็จ!",
                message:
                    "ยอดเงิน ${widget.amount.toStringAsFixed(2)} บาท\nถูกเพิ่มเข้าวอลเล็ทของคุณแล้ว",
                icon: CupertinoIcons.checkmark_alt,
                iconColor: Colors.green,
                confirmText: "กลับสู่หน้าหลัก",
                onConfirm: () {
                  Get.back();
                  Get.back();
                },
              );
            }
          }
        });
  }

  Future<void> _simulatePayment() async {
    setState(() => _isSimulating = true);
    try {
      const secretKey =
          'xnd_development_uECbSQQ13qvRaRejTtYlQI20uqwgZowEobCwUTmN31xHBSM7vjxByLs5qlbtDC'; // ใส่ Secret Key ตามระบบเดิมของคุณ
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$secretKey:'))}';

      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.refNo)
          .get();

      if (!doc.exists || doc.data()?['qrId'] == null) {
        _showCustomSnackbar(
          "ข้อผิดพลาด",
          "ไม่พบรหัส QR ID ในระบบ",
          CupertinoIcons.xmark_circle_fill,
          Colors.red,
        );
        setState(() => _isSimulating = false);
        return;
      }

      final String qrId = doc.data()!['qrId'];
      final url = Uri.parse(
        'https://api.xendit.co/qr_codes/$qrId/payments/simulate',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
          'api-version': '2022-07-31',
        },
        body: jsonEncode({'amount': widget.amount}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ สั่ง Simulate สำเร็จ! รอรับ Webhook ใน 1-3 วินาที');
      } else {
        _showCustomSnackbar(
          "เกิดข้อผิดพลาด",
          "ไม่สามารถจำลองการจ่ายเงินได้",
          CupertinoIcons.xmark_circle_fill,
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Future<void> _cancelPayment() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.refNo)
          .update({'status': 'cancelled'});

      Get.back();
      Get.back();

      _showCustomSnackbar(
        "ยกเลิกแล้ว",
        "การทำรายการชำระเงินถูกยกเลิก",
        CupertinoIcons.info_circle_fill,
        Colors.orange,
      );
    } catch (e) {
      Get.back();
      _showCustomSnackbar(
        "ข้อผิดพลาด",
        "ไม่สามารถยกเลิกรายการได้",
        CupertinoIcons.xmark_circle_fill,
        Colors.red,
      );
    }
  }

  void _showCancelConfirmation() {
    AppDialog.showCustomDialog(
      title: "ยกเลิกรายการ?",
      message: "คุณต้องการยกเลิกการเติมเงินครั้งนี้\nใช่หรือไม่?",
      icon: CupertinoIcons.xmark_circle_fill,
      iconColor: Colors.red,
      confirmText: "ใช่, ยกเลิกเลย",
      cancelText: "ไม่, รอชำระเงิน",
      showCancel: true,
      isDestructive: true,
      onConfirm: () {
        Get.back();
        _cancelPayment();
      },
    );
  }

  void _showCustomSnackbar(
    String title,
    String message,
    IconData icon,
    Color bg,
  ) {
    Get.snackbar(
      title,
      message,
      icon: Icon(icon, color: Colors.white, size: 28),
      snackPosition: SnackPosition.TOP,
      backgroundColor: bg.withOpacity(0.9),
      colorText: Colors.white,
      borderRadius: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      duration: const Duration(seconds: 3),
      barBlur: 20,
    );
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    super.dispose();
  }

  Widget _buildBgCircle(
    bool isDark, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    double opacityFactor = 1.0,
  }) {
    final baseOpacity = isDark ? 0.05 : 0.08;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(baseOpacity * opacityFactor),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showCancelConfirmation();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            "ชำระเงิน",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => _showCancelConfirmation(),
          ),
        ),
        body: Stack(
          children: [
            _buildBgCircle(isDark, top: -50, right: -100, size: 300),
            _buildBgCircle(
              isDark,
              bottom: -80,
              left: -80,
              size: 250,
              opacityFactor: 0.8,
            ),
            _buildBgCircle(
              isDark,
              top: size.height * 0.4,
              left: -100,
              size: 200,
              opacityFactor: 0.5,
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.08,
                              ),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                width: double.infinity,
                                color: AppTheme.primaryColor.withOpacity(0.05),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/promptpay_logo.png',
                                    height: 35,
                                    errorBuilder: (_, __, ___) => const Text(
                                      "PromptPay",
                                      style: TextStyle(
                                        color: Color(0xFF113566),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(30),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.2),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: QrImageView(
                                        data: widget.qrString,
                                        version: QrVersions.auto,
                                        size: 200.0,
                                        backgroundColor: Colors.white,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Colors.black87,
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.square,
                                              color: Colors.black87,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 30),

                                    const Text(
                                      "ยอดที่ต้องชำระ",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "฿ ${widget.amount.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Row(
                                    children: List.generate(
                                      40,
                                      (index) => Expanded(
                                        child: Container(
                                          color: index % 2 == 0
                                              ? Colors.transparent
                                              : Colors.grey[300],
                                          height: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: -15,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: theme.scaffoldBackgroundColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -15,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: theme.scaffoldBackgroundColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              Container(
                                color: Colors.grey[50],
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "หมายเลขอ้างอิง",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          widget.refNo,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            fontFamily: 'Courier',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "สถานะ",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            "รอการชำระเงิน",
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.timer,
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "กรุณาสแกนเพื่อชำระเงินภายใน 15 นาที",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSimulating ? null : _simulatePayment,
                            icon: _isSimulating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.black54,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    CupertinoIcons.hammer_fill,
                                    color: Colors.black54,
                                    size: 18,
                                  ),
                            label: Text(
                              _isSimulating
                                  ? "กำลังจำลอง..."
                                  : "จำลองการชำระเงิน (Test Mode)",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
