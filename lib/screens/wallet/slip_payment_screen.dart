import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/screens/home/home_screen.dart';

class SlipPaymentScreen extends StatefulWidget {
  final double amount;
  const SlipPaymentScreen({super.key, required this.amount});

  @override
  State<SlipPaymentScreen> createState() => _SlipPaymentScreenState();
}

class _SlipPaymentScreenState extends State<SlipPaymentScreen> {
  File? _slipImage;
  bool _isVerifying = false;

  final String promptPayNumber = "0647490079";
  final String accountName = "นายพุทธดา หาญนอก";

  final String slipokApiKey = dotenv.env['SLIPOK_API_KEY'] ?? '';

  void _copyPromptPay() {
    Clipboard.setData(ClipboardData(text: promptPayNumber));
    Get.snackbar(
      "คัดลอกแล้ว",
      "คัดลอกเบอร์พร้อมเพย์เรียบร้อยแล้ว นำไปวางในแอปธนาคารได้เลย",
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      icon: const Icon(
        CupertinoIcons.check_mark_circled_solid,
        color: Colors.white,
      ),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _pickSlipImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _slipImage = File(image.path));
    }
  }

  Future<void> _verifySlip() async {
    if (_slipImage == null) return;

    setState(() => _isVerifying = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.slipok.com/api/line/apikey/61849'),
      );
      request.headers['x-authorization'] = slipokApiKey;
      request.files.add(
        await http.MultipartFile.fromPath('files', _slipImage!.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        var slipData = jsonData['data'];
        double transferredAmount = (slipData['amount'] ?? 0).toDouble();

        String transRef = slipData['transRef'] ?? '';

        if (transferredAmount != widget.amount) {
          _showError(
            "จำนวนเงินในสลิป ($transferredAmount ฿) ไม่ตรงกับยอดที่ต้องชำระ (${widget.amount} ฿)",
          );
          return;
        }

        if (transRef.isEmpty) {
          _showError(
            "ไม่สามารถอ่านรหัสอ้างอิงจากสลิปได้ กรุณาใช้รูปสลิปที่ชัดเจนกว่านี้",
          );
          return;
        }

        var existingTx = await FirebaseFirestore.instance
            .collection('transactions')
            .where('transRef', isEqualTo: transRef)
            .where('status', isEqualTo: 'success')
            .get();

        if (existingTx.docs.isNotEmpty) {
          _showError("สลิปนี้ถูกใช้งานเพื่อเติมเงินไปแล้ว ไม่สามารถใช้ซ้ำได้");
          return;
        }

        String slipUrl = await _uploadSlipToStorage(_slipImage!);
        await _updateWallet(slipUrl, transRef);
      } else {
        _showError(
          "ไม่สามารถตรวจสอบสลิปได้ หรือสลิปนี้ไม่ถูกต้อง\n(${jsonData['message'] ?? 'โปรดใช้สลิปของจริง'})",
        );
      }
    } catch (e) {
      _showError("เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์ กรุณาลองใหม่");
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<String> _uploadSlipToStorage(File imageFile) async {
    try {
      String fileName = 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child('slips/$fileName');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading slip: $e");
      return "";
    }
  }

  Future<void> _updateWallet(String slipUrl, String transRef) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(widget.amount),
      });

      DocumentReference txRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc();

      batch.set(txRef, {
        'uid': user.uid,
        'type': 'topup',
        'amount': widget.amount,
        'status': 'success',
        'method': 'slip',
        'slip_image': slipUrl,
        'transRef': transRef,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      Get.offAll(() => const HomeScreen());
      Get.snackbar(
        "เติมเงินสำเร็จ!",
        "เติมเงิน ${widget.amount.toStringAsFixed(2)} บาท เข้าวอลเล็ทเรียบร้อยแล้ว",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(
          CupertinoIcons.check_mark_circled_solid,
          color: Colors.white,
        ),
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      _showError("เกิดข้อผิดพลาดในการบันทึกข้อมูลระบบ");
    }
  }

  void _showError(String message) {
    Get.snackbar(
      "ตรวจสอบไม่ผ่าน",
      message,
      backgroundColor: Colors.red[800],
      colorText: Colors.white,
      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white),
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "โอนเงินแนบสลิป",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 12,
                  child: const Text(
                    "1",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "โอนเงินผ่านพร้อมเพย์",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF113566),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/promptpay_logo.jpg',
                        height: 30,
                        errorBuilder: (_, __, ___) => const Text(
                          "PromptPay",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        const Text(
                          "ยอดที่ต้องชำระ",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${widget.amount.toStringAsFixed(2)} ฿",
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(),
                        ),

                        const Text(
                          "เบอร์พร้อมเพย์",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              promptPayNumber,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(width: 15),
                            GestureDetector(
                              onTap: _copyPromptPay,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.copy,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "ชื่อบัญชี: $accountName",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[800],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 12,
                  child: const Text(
                    "2",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "อัปโหลดสลิปการโอนเงิน",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),

            GestureDetector(
              onTap: _isVerifying ? null : _pickSlipImage,
              child: _slipImage == null
                  ? DottedBorder(
                      color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                      strokeWidth: 2,
                      dashPattern: const [8, 4],
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(20),
                      child: Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.photo_on_rectangle,
                              size: 50,
                              color: AppTheme.primaryColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              "แตะเพื่อเลือกรูปภาพสลิปจากอัลบั้ม",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "รองรับเฉพาะไฟล์ .jpg และ .png",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      height: 400,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_slipImage!, fit: BoxFit.contain),
                            if (!_isVerifying)
                              Positioned(
                                top: 15,
                                right: 15,
                                child: GestureDetector(
                                  onTap: _pickSlipImage,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.pencil,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "เปลี่ยนรูป",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: (_slipImage == null || _isVerifying)
                  ? null
                  : _verifySlip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: _isVerifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(width: 15),
                        Text(
                          "กำลังตรวจสอบสลิป...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "ตรวจสอบและยืนยันการโอนเงิน",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
