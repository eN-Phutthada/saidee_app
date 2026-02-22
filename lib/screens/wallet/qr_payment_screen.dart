import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:saidee_app/config/theme.dart';

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
              Get.dialog(
                Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.checkmark_alt,
                            color: Colors.green,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "เติมเงินสำเร็จ!",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "ยอดเงิน ${widget.amount.toStringAsFixed(2)} บาท\nถูกเพิ่มเข้าวอลเล็ทของคุณแล้ว",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Get.back(); // ปิด Dialog
                              Get.back(); // กลับไปหน้าหลัก
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "กลับสู่หน้าหลัก",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                barrierDismissible: false,
              );
            }
          }
        });
  }

  Future<void> _simulatePayment() async {
    setState(() => _isSimulating = true);
    try {
      const secretKey =
          'xnd_development_uECbSQQ13qvRaRejTtYlQI20uqwgZowEobCwUTmN31xHBSM7vjxByLs5qlbtDC'; // ใส่ Secret Key ของ Xendit (Test Mode) ที่นี่
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$secretKey:'))}';

      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.refNo)
          .get();

      if (!doc.exists || doc.data()?['qrId'] == null) {
        Get.snackbar(
          "ข้อผิดพลาด",
          "ไม่พบรหัส QR ID ในระบบ",
          backgroundColor: Colors.red,
          colorText: Colors.white,
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
        Get.snackbar(
          "เกิดข้อผิดพลาด",
          "ไม่สามารถจำลองการจ่ายเงินได้",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    } finally {
      setState(() => _isSimulating = false);
    }
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ชำระเงิน",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Ticket Slip UI ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.white, // ใบเสร็จ/QR พื้นต้องเป็นสีขาวเสมอ
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ขอบด้านบนประดับสีเขียว
                    Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/promptpay_logo.png',
                            height: 40,
                            errorBuilder: (_, __, ___) => const Text(
                              "PromptPay",
                              style: TextStyle(
                                color: Color(0xFF113566),
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),

                          // QR Code
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: QrImageView(
                              data: widget.qrString,
                              version: QrVersions.auto,
                              size: 220.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 25),

                          // จำนวนเงิน
                          const Text(
                            "จำนวนเงินที่ต้องชำระ",
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "฿ ${widget.amount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // เส้นประ (Dashed Line)
                    Row(
                      children: List.generate(
                        30,
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

                    // Footer ของ Slip
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "หมายเลขอ้างอิง",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                widget.refNo.length > 15
                                    ? "${widget.refNo.substring(0, 15)}..."
                                    : widget.refNo,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "สถานะ",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                "รอการชำระเงิน",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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

              const SizedBox(height: 30),

              // --- คำแนะนำ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.time, color: Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "กรุณาสแกนเพื่อชำระเงินภายใน 15 นาที",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // --- ปุ่มจำลอง (เอาไว้เทส) ---
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
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors
                          .grey[200], // ใช้สีเทาอ่อนให้ดูเป็นปุ่มเสริม ไม่แย่งความสนใจ
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
    );
  }
}
