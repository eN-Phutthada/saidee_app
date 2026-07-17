import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class BuyerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const BuyerOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<BuyerOrderDetailScreen> createState() => _BuyerOrderDetailScreenState();
}

class _BuyerOrderDetailScreenState extends State<BuyerOrderDetailScreen> {
  late bool _isReviewed;

  @override
  void initState() {
    super.initState();
    _isReviewed = widget.orderData['isReviewed'] == true;
  }

  void _copyTrackingNumber(String trackingNumber) {
    if (trackingNumber.isEmpty || trackingNumber == '-') return;
    Clipboard.setData(ClipboardData(text: trackingNumber));

    AppDialog.showCustomDialog(
      title: "คัดลอกแล้ว",
      message: "คัดลอกหมายเลขพัสดุ $trackingNumber เรียบร้อยแล้ว",
      icon: CupertinoIcons.doc_on_clipboard_fill,
      iconColor: Colors.blue,
      confirmText: "ตกลง",
      onConfirm: () => Get.back(),
    );
  }

  Future<void> _confirmDelivery() async {
    AppDialog.showCustomDialog(
      title: "ยืนยันการรับสินค้า",
      message:
          "คุณได้ตรวจสอบสินค้าและต้องการยืนยันการรับสินค้าใช่หรือไม่?\n(การกระทำนี้ไม่สามารถย้อนกลับได้)",
      icon: CupertinoIcons.checkmark_seal_fill,
      iconColor: Colors.green,
      confirmText: "ฉันยอมรับสินค้า",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );
        try {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .update({
                'status': 'completed',
                'updatedAt': FieldValue.serverTimestamp(),
              });

          double totalAmount = (widget.orderData['total'] ?? 0).toDouble();
          String sellerId = widget.orderData['sellerId'];

          WriteBatch batch = FirebaseFirestore.instance.batch();
          DocumentReference sellerRef = FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId);
          batch.update(sellerRef, {
            'walletBalance': FieldValue.increment(totalAmount),
          });

          DocumentReference txRef = FirebaseFirestore.instance
              .collection('transactions')
              .doc();
          batch.set(txRef, {
            'uid': sellerId,
            'type': 'income',
            'amount': totalAmount,
            'order_id': widget.orderId,
            'status': 'success',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await batch.commit();

          NotificationService.sendNotification(
            userId: sellerId,
            title: "ได้รับโอนเงินแล้ว! 💰",
            body: "ผู้ซื้อยืนยันรับสินค้าแล้ว ยอดเงิน ${totalAmount.toStringAsFixed(2)} ฿ ถูกโอนเข้า SAIDEE Wallet เรียบร้อยแล้ว",
            type: 'wallet',
            orderId: widget.orderId,
          );

          NotificationService.sendNotification(
            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            title: "คำสั่งซื้อเสร็จสมบูรณ์ ✨",
            body: "ขอบคุณที่อุดหนุนและใช้งานบริการ อย่าลืมให้คะแนนและรีวิวสินค้านะครับ",
            type: 'order',
            orderId: widget.orderId,
          );

          Get.back();
          Get.back();

          AppDialog.showCustomDialog(
            title: "สำเร็จ",
            message: "ยืนยันการรับสินค้าเรียบร้อยแล้ว",
            icon: CupertinoIcons.check_mark_circled_solid,
            iconColor: Colors.green,
            confirmText: "ตกลง",
            onConfirm: () => Get.back(),
          );
        } catch (e) {
          Get.back();
          AppDialog.showCustomDialog(
            title: "เกิดข้อผิดพลาด",
            message: "ไม่สามารถทำรายการได้ กรุณาลองใหม่",
            icon: CupertinoIcons.xmark_circle_fill,
            iconColor: Colors.red,
            confirmText: "ตกลง",
            onConfirm: () => Get.back(),
          );
        }
      },
    );
  }

  Future<void> _cancelOrder(BuildContext context, double totalAmount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    AppDialog.showCustomDialog(
      title: "ยกเลิกคำสั่งซื้อ",
      message:
          "คุณแน่ใจหรือไม่ที่จะยกเลิกคำสั่งซื้อนี้?\nเงินจะถูกคืนเข้าวอลเล็ททันที",
      icon: CupertinoIcons.xmark_circle_fill,
      iconColor: Colors.red,
      confirmText: "ยืนยัน",
      cancelText: "ปิด",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        _performCancel(user.uid, totalAmount);
      },
    );
  }

  Future<void> _performCancel(String uid, double totalAmount) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId);
      batch.update(orderRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(totalAmount),
      });

      DocumentReference txRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc();
      batch.set(txRef, {
        'uid': uid,
        'type': 'refund',
        'amount': totalAmount,
        'order_id': widget.orderId,
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      List items = widget.orderData['items'] ?? [];
      for (var item in items) {
        String productId = item['productId'];
        DocumentReference productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(productId);
        batch.update(productRef, {'status': 'active'});
      }

      await batch.commit();

      Get.back();
      Get.back();

      AppDialog.showCustomDialog(
        title: "สำเร็จ",
        message: "ยกเลิกคำสั่งซื้อและคืนเงินเรียบร้อย",
        icon: CupertinoIcons.check_mark_circled_solid,
        iconColor: Colors.green,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } catch (e) {
      Get.back();
      AppDialog.showCustomDialog(
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถยกเลิกได้ กรุณาลองใหม่",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    }
  }

  void _showReviewSheet(BuildContext context) {
    if (_isReviewed) return;

    int rating = 5;
    TextEditingController reviewCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 15,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "ให้คะแนนสินค้าและร้านค้า",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "ความพึงพอใจของคุณเป็นอย่างไรบ้าง?",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setModalState(() => rating = index + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            index < rating
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            color: Colors.amber,
                            size: 45,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: reviewCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "แบ่งปันประสบการณ์ของคุณกับสินค้านี้...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(15),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        Get.dialog(
                          const Center(child: CircularProgressIndicator()),
                          barrierDismissible: false,
                        );
                        try {
                          String sellerId = widget.orderData['sellerId'];

                          await FirebaseFirestore.instance
                              .collection('reviews')
                              .add({
                                'orderId': widget.orderId,
                                'buyerId':
                                    FirebaseAuth.instance.currentUser!.uid,
                                'sellerId': sellerId,
                                'rating': rating,
                                'comment': reviewCtrl.text.trim(),
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(widget.orderId)
                              .update({'isReviewed': true});

                          Get.back();

                          setState(() {
                            _isReviewed = true;
                          });

                          AppDialog.showCustomDialog(
                            title: "สำเร็จ",
                            message: "ขอบคุณสำหรับการประเมิน!",
                            icon: CupertinoIcons.star_circle_fill,
                            iconColor: Colors.amber,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                        } catch (e) {
                          Get.back();
                          AppDialog.showCustomDialog(
                            title: "ข้อผิดพลาด",
                            message: "ไม่สามารถส่งรีวิวได้",
                            icon: CupertinoIcons.xmark_circle_fill,
                            iconColor: Colors.red,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ส่งรีวิว",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  void _showReportSheet(BuildContext context) {
    TextEditingController topicCtrl = TextEditingController();
    TextEditingController detailCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    File? imageProof;
    final ImagePicker picker = ImagePicker();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 25,
              right: 25,
              top: 15,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        "รายงานปัญหาผู้ขาย",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "หากพบว่าผู้ขายมีพฤติกรรมฉ้อโกง ส่งสินค้าไม่ตรงปก หรือมีปัญหาอื่นๆ โปรดแจ้งให้ทีมงานทราบ",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: topicCtrl,
                    decoration: InputDecoration(
                      labelText: "หัวข้อปัญหา (เช่น สินค้าไม่ตรงปก, ของปลอม)",
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: detailCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: "อธิบายรายละเอียดเพิ่มเติม",
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "แนบรูปภาพหลักฐาน (ถ้ามี)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 70,
                      );
                      if (pickedFile != null) {
                        setModalState(() {
                          imageProof = File(pickedFile.path);
                        });
                      }
                    },
                    child: imageProof == null
                        ? DottedBorder(
                            color: isDark
                                ? Colors.grey[600]!
                                : Colors.grey[400]!,
                            strokeWidth: 1,
                            dashPattern: const [6, 4],
                            borderType: BorderType.RRect,
                            radius: const Radius.circular(12),
                            child: Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.camera,
                                    color: Colors.grey[500],
                                    size: 30,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "เพิ่มรูป",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Stack(
                            children: [
                              Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(imageProof!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () =>
                                      setModalState(() => imageProof = null),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.red,
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (topicCtrl.text.isEmpty) {
                          AppDialog.showCustomDialog(
                            title: "แจ้งเตือน",
                            message: "กรุณาระบุหัวข้อปัญหา",
                            icon: CupertinoIcons.exclamationmark_triangle_fill,
                            iconColor: Colors.orange,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                          return;
                        }

                        Get.back();
                        Get.dialog(
                          Dialog(
                            backgroundColor: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircularProgressIndicator(color: Colors.red),
                                  SizedBox(height: 20),
                                  Text("กำลังส่งรายงาน..."),
                                ],
                              ),
                            ),
                          ),
                          barrierDismissible: false,
                        );

                        try {
                          String imageUrl = "";

                          if (imageProof != null) {
                            String fileName =
                                'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            Reference ref = FirebaseStorage.instance
                                .ref()
                                .child('reports/$fileName');
                            await ref.putFile(imageProof!);
                            imageUrl = await ref.getDownloadURL();
                          }

                          await FirebaseFirestore.instance
                              .collection('reports')
                              .add({
                                'reporter_id':
                                    FirebaseAuth.instance.currentUser!.uid,
                                'reported_id': widget.orderData['sellerId'],
                                'order_id': widget.orderId,
                                'topic': topicCtrl.text.trim(),
                                'detail': detailCtrl.text.trim(),
                                'image_proof': imageUrl,
                                'status': 'pending',
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(widget.orderId)
                              .update({
                                'status': 'disputed',
                                'disputedAt': FieldValue.serverTimestamp(),
                              });

                          String sellerId = widget.orderData['sellerId'] ?? '';
                          String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                          NotificationService.sendNotification(
                            userId: sellerId,
                            title: "แจ้งเตือนข้อพาทคำสั่งซื้อ ⚠️",
                            body: "ผู้ซื้อรายงานปัญหาในคำสั่งซื้อ ระบบระงับการโอนเงินชั่วคราว ทีมงานกำลังเข้าตรวจสอบ",
                            type: 'dispute',
                            orderId: widget.orderId,
                          );

                          NotificationService.sendNotification(
                            userId: currentUid,
                            title: "ส่งรายงานข้อพาทเรียบร้อย ⚠️",
                            body: "ระบบได้รับเรื่องรายงานของคุณแล้ว และได้ทำการระงับการปล่อยเงินชั่วคราวเรียบร้อยแล้ว",
                            type: 'dispute',
                            orderId: widget.orderId,
                          );

                          Get.back();
                          AppDialog.showCustomDialog(
                            title: "ส่งรายงานสำเร็จ",
                            message:
                                "ระบบได้รับข้อมูลของคุณแล้ว ทีมงานจะดำเนินการตรวจสอบโดยเร็วที่สุด",
                            icon: CupertinoIcons.check_mark_circled_solid,
                            iconColor: Colors.green,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                        } catch (e) {
                          Get.back();
                          AppDialog.showCustomDialog(
                            title: "ข้อผิดพลาด",
                            message: "ไม่สามารถส่งรายงานได้",
                            icon: CupertinoIcons.xmark_circle_fill,
                            iconColor: Colors.red,
                            confirmText: "ตกลง",
                            onConfirm: () => Get.back(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ส่งรายงานให้แอดมิน",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    List items = widget.orderData['items'] ?? [];
    var address = widget.orderData['shippingAddress'] ?? {};
    String status = widget.orderData['status'] ?? 'pending';

    String statusTitle = "กำลังดำเนินการ";
    String statusDesc = "รอผู้ขายจัดเตรียมและส่งสินค้า";
    Color headerColor = Colors.orange;
    IconData headerIcon = CupertinoIcons.time;
    String warrantyText = "";

    if (status == 'shipping') {
      statusTitle = "กำลังจัดส่ง";
      statusDesc = "พัสดุของคุณกำลังเดินทาง";
      headerColor = Colors.blue;
      headerIcon = CupertinoIcons.cube_box;

      Timestamp? ts =
          widget.orderData['updatedAt'] ?? widget.orderData['createdAt'];
      if (ts != null) {
        DateTime shippedDate = ts.toDate();
        DateTime autoConfirmDate = shippedDate.add(const Duration(days: 7));
        warrantyText =
            "${autoConfirmDate.day.toString().padLeft(2, '0')}/${autoConfirmDate.month.toString().padLeft(2, '0')}/${autoConfirmDate.year + 543} เวลา ${autoConfirmDate.hour.toString().padLeft(2, '0')}:${autoConfirmDate.minute.toString().padLeft(2, '0')} น.";
      }
    } else if (status == 'completed') {
      statusTitle = "จัดส่งสำเร็จ";
      statusDesc = "คำสั่งซื้อนี้เสร็จสมบูรณ์แล้ว";
      headerColor = Colors.green;
      headerIcon = CupertinoIcons.checkmark_seal_fill;
    } else if (status == 'cancelled') {
      statusTitle = "ยกเลิกแล้ว";
      statusDesc = "คำสั่งซื้อถูกยกเลิก";
      headerColor = Colors.red;
      headerIcon = CupertinoIcons.xmark_circle;
    } else if (status == 'disputed') {
      statusTitle = "อยู่ระหว่างพิจารณาข้อพาท";
      statusDesc = "ระงับการโอนเงินชั่วคราว ทีมงานกำลังตรวจสอบปัญหา";
      headerColor = Colors.purple;
      headerIcon = CupertinoIcons.exclamationmark_shield_fill;
    }

    Timestamp? ts = widget.orderData['createdAt'];
    String orderDate = "-";
    if (ts != null) {
      DateTime d = ts.toDate();
      orderDate =
          "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "รายละเอียดคำสั่งซื้อ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(
              statusTitle,
              statusDesc,
              headerColor,
              headerIcon,
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  if (status == 'shipping' || status == 'completed')
                    _buildTrackingCard(theme, isDark, widget.orderData),

                  if (status == 'shipping' && warrantyText.isNotEmpty)
                    _buildWarrantyInfoBox(theme, isDark, warrantyText),

                  _buildAddressCard(theme, isDark, address),

                  _buildItemsCard(theme, isDark, items),

                  _buildPaymentSummaryCard(theme, isDark, widget.orderData),

                  _buildOrderInfoCard(theme, isDark, orderDate),

                  if (status == 'completed') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isReviewed
                            ? null
                            : () => _showReviewSheet(context),
                        icon: Icon(
                          CupertinoIcons.star_fill,
                          color: _isReviewed ? Colors.grey : Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          _isReviewed
                              ? "คุณรีวิวสินค้านี้แล้ว"
                              : "ให้คะแนนและรีวิวสินค้า",
                          style: TextStyle(
                            color: _isReviewed
                                ? Colors.grey[700]
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          disabledBackgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReportSheet(context),
                        icon: const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: Colors.red,
                          size: 18,
                        ),
                        label: const Text(
                          "รายงานปัญหา / ผู้ขายทุจริต",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: (status == 'pending' || status == 'shipping')
          ? _buildBottomAction(
              context,
              theme,
              isDark,
              status,
              (widget.orderData['total'] ?? 0).toDouble(),
            )
          : null,
    );
  }

  Widget _buildStatusHeader(
    String title,
    String desc,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(color: color),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 50),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(ThemeData theme, bool isDark, Map data) {
    String trackingNumber = data['trackingNumber'] ?? '-';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.car_detailed, color: Colors.blue),
              SizedBox(width: 10),
              Text(
                "ข้อมูลการจัดส่ง",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "จัดส่งโดย: ${data['shippingMethod'] ?? 'ไม่ระบุ'}",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Text(
                  "เลขพัสดุ: ",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                Expanded(
                  child: Text(
                    trackingNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trackingNumber != '-')
                  GestureDetector(
                    onTap: () => _copyTrackingNumber(trackingNumber),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyInfoBox(
    ThemeData theme,
    bool isDark,
    String dateString,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.timer, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ระยะเวลาประกันสินค้า (รับของอัตโนมัติ)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "กรุณาตรวจสอบสินค้าและกดยืนยันภายในวันที่ $dateString หากเลยกำหนด ระบบจะยืนยันการรับสินค้าและโอนเงินให้ผู้ขายอัตโนมัติ",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(ThemeData theme, bool isDark, Map address) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.location_solid, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text(
                "ที่อยู่จัดส่ง",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "${address['name'] ?? address['receiver_name'] ?? 'ไม่ระบุชื่อ'} | ${address['phone'] ?? ''}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            "${address['address_detail']} ${address['sub_district']} ${address['district']} ${address['province']} ${address['postcode']}",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(ThemeData theme, bool isDark, List items) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.house_alt,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  "ร้าน: ${widget.orderData['sellerName'] ?? 'ไม่ระบุ'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 65,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image: (item['image'] != null && item['image'] != '')
                          ? DecorationImage(
                              image: NetworkImage(item['image']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ไซส์: ${item['size'] ?? '-'}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${item['price']} ฿",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "x1",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(ThemeData theme, bool isDark, Map data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            "ยอดรวมสินค้า",
            "${data['subtotal']} ฿",
            theme,
            isDark,
          ),
          _buildSummaryRow(
            "ค่าจัดส่ง",
            "${data['shippingFee']} ฿",
            theme,
            isDark,
          ),
          if ((data['discount'] ?? 0) > 0)
            _buildSummaryRow(
              "ส่วนลดคูปอง",
              "-${data['discount']} ฿",
              theme,
              isDark,
              color: Colors.red,
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ยอดชำระสุทธิ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "${data['total']} ฿",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme, bool isDark, String date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow("หมายเลขคำสั่งซื้อ", widget.orderId, theme, isDark),
          _buildSummaryRow("เวลาที่สั่งซื้อ", date, theme, isDark),
          _buildSummaryRow("ช่องทางชำระเงิน", "SAIDEE Wallet", theme, isDark),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String status,
    double totalAmount,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: status == 'pending'
              ? OutlinedButton(
                  onPressed: () => _cancelOrder(context, totalAmount),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ยกเลิกคำสั่งซื้อ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                )
              : ElevatedButton(
                  onPressed: _confirmDelivery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ฉันได้ตรวจสอบและยอมรับสินค้า",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value,
    ThemeData theme,
    bool isDark, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
