import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/wallet/qr_payment_screen.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  final List<int> _quickAmounts = [100, 300, 500, 1000, 2000, 5000];
  bool _isLoading = false;

  Future<void> _generateQR() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณาระบุจำนวนเงิน",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount < 20) {
      Get.snackbar(
        "แจ้งเตือน",
        "จำนวนเงินขั้นต่ำ 20 บาท",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('createXenditQR');
      final response = await callable.call(<String, dynamic>{'amount': amount});

      final String qrString = response.data['qrString'];
      final String refNo = response.data['externalId'];

      Get.to(
        () => QRPaymentScreen(qrString: qrString, amount: amount, refNo: refNo),
      );
    } on FirebaseFunctionsException catch (e) {
      log(e.message ?? "เกิดข้อผิดพลาดในการสร้าง QR Code");
      Get.snackbar(
        "ข้อผิดพลาด",
        e.message ?? "เกิดข้อผิดพลาดในการสร้าง QR Code",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "เกิดข้อผิดพลาดในการเชื่อมต่อ",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "เติมเงิน",
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // --- Wallet Card แบบพรีเมียม ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E5B3D), Color(0xFF2CB834)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ยอดเงินปัจจุบัน (SAIDEE Wallet)",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Icon(
                        CupertinoIcons.creditcard_fill,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      double balance = 0.0;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        balance = (data['walletBalance'] ?? 0).toDouble();
                      }
                      return Text(
                        "฿ ${balance.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- ส่วนป้อนตัวเลขแบบแอปธนาคาร ---
            Text(
              "ระบุจำนวนเงินที่ต้องการเติม",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Kanit',
                ),
                decoration: InputDecoration(
                  hintText: "0",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(
                  () {},
                ), // อัปเดต UI เพื่อเปลี่ยนสีปุ่ม Quick Amount
              ),
            ),
            Container(
              width: 100,
              height: 2,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 10),
            const Text(
              "THB",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            // --- ปุ่ม Quick Amount แบบ Chips ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _quickAmounts.map((amt) {
                  bool isSelected = _amountController.text == amt.toString();
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _amountController.text = amt.toString()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: (MediaQuery.of(context).size.width - 70) / 3,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : (isDark ? Colors.grey[800] : Colors.white),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[200]!),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          "+$amt",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey[300] : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      // --- ปุ่มยืนยันด้านล่างสุด ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _generateQR,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "สแกน QR เพื่อชำระเงิน",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
