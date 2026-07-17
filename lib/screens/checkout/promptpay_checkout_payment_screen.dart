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
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/screens/home/home_screen.dart';
import 'package:saidee_app/screens/order/buyer_orders_screen.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';
import 'checkout_screen.dart';

class PromptPayCheckoutPaymentScreen extends StatefulWidget {
  final double grandTotal;
  final List<CheckoutShopGroup> shopGroups;
  final Map<String, dynamic>? selectedAddress;
  final double discountAmount;
  final Map<String, dynamic>? appliedCoupon;
  final double itemsTotalAll;

  const PromptPayCheckoutPaymentScreen({
    super.key,
    required this.grandTotal,
    required this.shopGroups,
    required this.selectedAddress,
    required this.discountAmount,
    required this.appliedCoupon,
    required this.itemsTotalAll,
  });

  @override
  State<PromptPayCheckoutPaymentScreen> createState() =>
      _PromptPayCheckoutPaymentScreenState();
}

class _PromptPayCheckoutPaymentScreenState
    extends State<PromptPayCheckoutPaymentScreen> {
  File? _slipImage;
  bool _isVerifying = false;

  final String promptPayNumber = "0647490079";
  final String accountName = "นายพุทธดา หาญนอก";

  final String slipokAuthToken = dotenv.env['SLIPOK_API_KEY'] ?? '';

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
      request.headers['x-authorization'] = slipokAuthToken;
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

        if (transferredAmount != widget.grandTotal) {
          _showError(
            "จำนวนเงินในสลิป ($transferredAmount ฿) ไม่ตรงกับยอดที่ต้องชำระ (${widget.grandTotal.toStringAsFixed(2)} ฿)",
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
          _showError("สลิปนี้ถูกใช้งานไปแล้ว ไม่สามารถใช้ซ้ำได้");
          return;
        }

        String slipUrl = await _uploadSlipToStorage(_slipImage!);
        await _executeOrderCreation(slipUrl, transRef);
      } else {
        _showError(
          "ไม่สามารถตรวจสอบสลิปได้ หรือสลิปนี้ไม่ถูกต้อง\n(${jsonData['message'] ?? 'โปรดใช้สลิปของจริง'})",
        );
      }
    } catch (e) {
      _showError("เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์ กรุณาลองใหม่: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<String> _uploadSlipToStorage(File imageFile) async {
    try {
      String fileName = 'checkout_slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child('slips/checkout/$fileName');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading checkout slip: $e");
      return "";
    }
  }

  Future<void> _executeOrderCreation(String slipUrl, String transRef) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;

    try {
      WriteBatch batch = db.batch();

      DocumentReference txRef = db.collection('transactions').doc();
      batch.set(txRef, {
        'uid': user.uid,
        'type': 'purchase',
        'amount': widget.grandTotal,
        'status': 'success',
        'paymentMethod': 'promptpay_qr',
        'transRef': transRef,
        'slipUrl': slipUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (var group in widget.shopGroups) {
        double shopTotal =
            group.itemsTotal +
            (group.selectedShipping!['price'] ?? 0).toDouble();

        double shopDiscount = 0.0;
        if (widget.discountAmount > 0 && widget.itemsTotalAll > 0) {
          shopDiscount =
              widget.discountAmount * (group.itemsTotal / widget.itemsTotalAll);
        }
        double finalShopTotal = shopTotal - shopDiscount;

        DocumentReference orderRef = db.collection('orders').doc();
        batch.set(orderRef, {
          'buyerId': user.uid,
          'sellerId': group.sellerId,
          'sellerName': group.sellerName,
          'shippingAddress': widget.selectedAddress,
          'items': group.items,
          'subtotal': group.itemsTotal,
          'shippingFee': group.selectedShipping!['price'],
          'shippingMethod': group.selectedShipping!['name'],
          'discount': shopDiscount,
          'couponCode': widget.appliedCoupon?['code'] ?? '',
          'total': finalShopTotal,
          'status': 'pending',
          'paymentMethod': 'promptpay_qr',
          'paymentStatus': 'escrow_held',
          'slipUrl': slipUrl,
          'transRef': transRef,
          'trackingNumber': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (var item in group.items) {
          DocumentReference prodRef = db
              .collection('products')
              .doc(item['productId']);
          batch.update(prodRef, {'status': 'sold'});
        }

        for (var cartId in group.cartDocIds) {
          DocumentReference cartRef = db
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .doc(cartId);
          batch.delete(cartRef);
        }
      }

      await batch.commit();

      // ส่งการแจ้งเตือนไปยังผู้ซื้อและผู้ขาย
      NotificationService.sendNotification(
        userId: user.uid,
        title: "ชำระเงินสำเร็จแล้ว 💳",
        body: "คำสั่งซื้อยอด ${widget.grandTotal.toStringAsFixed(2)} ฿ ถูกส่งไปยังผู้ขายเรียบร้อยแล้ว (ระบบถือเงิน Escrow ปลอดภัย 100%)",
        type: 'order',
      );

      for (var group in widget.shopGroups) {
        NotificationService.sendNotification(
          userId: group.sellerId,
          title: "มีคำสั่งซื้อใหม่เข้ามา! 📦",
          body: "ร้าน ${group.sellerName} มีคำสั่งซื้อใหม่ชำระเงินเรียบร้อยแล้ว กรุณาจัดเตรียมและจัดส่งสินค้า",
          type: 'order',
        );
      }

      AppDialog.showCustomDialog(
        title: "ชำระเงินสำเร็จ!",
        message:
            "คำสั่งซื้อถูกส่งไปยังผู้ขายเรียบร้อยแล้ว\nระบบกำลังถือเงินของท่านไว้อย่างปลอดภัย (Escrow Holding) และจะโอนให้ผู้ขายเมื่อท่านได้รับสินค้า",
        icon: CupertinoIcons.checkmark_alt_circle_fill,
        iconColor: Colors.green,
        confirmText: "ดูรายการคำสั่งซื้อ",
        onConfirm: () {
          Get.offAll(() => const HomeScreen());
          Get.to(() => const BuyerOrdersScreen());
        },
      );
    } catch (e) {
      _showError("เกิดข้อผิดพลาดในการสร้างคำสั่งซื้อ: ${e.toString()}");
    }
  }

  void _showError(String message) {
    Get.snackbar(
      "การตรวจสอบสลิปไม่สำเร็จ",
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
          "ชำระเงินด้วย PromptPay Dynamic QR",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            // Escrow Security Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.shield_fill,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ระบบคนกลางถือเงินปลอดภัย (Escrow)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "เงินของคุณจะถูกถือครองไว้ในระบบ SAIDEE และจะโอนให้ผู้ขายเมื่อคุณกดยืนยันรับสินค้าเท่านั้น",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                  "สแกนชำระเงินผ่านพร้อมเพย์",
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
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          "ยอดชำระเงินสั่งซื้อสุทธิ",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${widget.grandTotal.toStringAsFixed(2)} ฿",
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Image.network(
                                'https://promptpay.io/$promptPayNumber/${widget.grandTotal}.png',
                                height: 200,
                                width: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 180,
                                    width: 180,
                                    color: Colors.grey[100],
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.qr_code_2,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          "ไม่สามารถโหลด QR ได้",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "สแกน QR ด้วยแอปธนาคารใดก็ได้",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "ชื่อบัญชี",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              accountName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "เบอร์พร้อมเพย์",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  promptPayNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _copyPromptPay,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "คัดลอก",
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                  "แนบสลิปเพื่อยืนยันคำสั่งซื้อ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),

            GestureDetector(
              onTap: _pickSlipImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _slipImage == null
                    ? DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          radius: const Radius.circular(15),
                          color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                          strokeWidth: 2,
                          dashPattern: const [8, 4],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          width: double.infinity,
                          child: Column(
                            children: [
                              Icon(
                                CupertinoIcons.photo_on_rectangle,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "กดที่นี่เพื่อแนบรูปสลิปโอนเงิน",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "ระบบจะทำการตรวจสอบสลิปอัตโนมัติ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _slipImage!,
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton.icon(
                            onPressed: _pickSlipImage,
                            icon: const Icon(
                              CupertinoIcons.arrow_2_circlepath,
                              size: 16,
                            ),
                            label: const Text("เปลี่ยนรูปสลิป"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
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
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                ),
                child: _isVerifying
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 15),
                          Text(
                            "กำลัง ตรวจสอบสลิป...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "ยืนยันการชำระเงิน",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
