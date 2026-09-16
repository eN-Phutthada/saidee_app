import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/models/report_model.dart';
import 'package:saidee_app/screens/auth/login_screen.dart';

/// BottomSheet มาตรฐานสำหรับให้ผู้ใช้ส่งรายงานปัญหา (สินค้า, ร้านค้า, แชท, คำสั่งซื้อ)
class ReportBottomSheet extends StatefulWidget {
  final String targetType; // 'product', 'store', 'chat', 'order'
  final String targetId;
  final String targetTitle;
  final String reportedUserId;
  final String? reportedUserName;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.reportedUserId,
    this.reportedUserName,
  });

  /// แสดง ReportBottomSheet
  static void show({
    required BuildContext context,
    required String targetType,
    required String targetId,
    required String targetTitle,
    required String reportedUserId,
    String? reportedUserName,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Get.snackbar(
        "กรุณาเข้าสู่ระบบ",
        "คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถรายงานปัญหาได้",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      Get.to(() => const LoginScreen());
      return;
    }

    if (currentUser.uid == reportedUserId) {
      Get.snackbar(
        "ไม่สามารถดำเนินการได้",
        "คุณไม่สามารถรายงานบัญชีหรือสินค้าของตนเองได้",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.bottomSheet(
      ReportBottomSheet(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final TextEditingController _detailController = TextEditingController();
  String _selectedCategory = "";
  File? _evidenceImage;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final categories = _getCategories();
    if (categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  List<String> _getCategories() {
    switch (widget.targetType) {
      case 'product':
        return [
          'สินค้าลอกเลียนแบบ / ละเมิดลิขสิทธิ์',
          'สินค้าต้องห้าม / ผิดกฎหมาย',
          'รูปภาพหรือคำบรรยายไม่เหมาะสม',
          'ข้อมูลเท็จ / ราคาไม่ตรงความจริง',
          'อื่นๆ',
        ];
      case 'store':
        return [
          'มีพฤติกรรมฉ้อโกง / ไม่ส่งสินค้า',
          'ชักชวนให้โอนเงินนอกระบบ',
          'แอบอ้างเป็นบุคคลหรือร้านค้าอื่น',
          'พฤติกรรมหรือคำพูดไม่สุภาพ',
          'อื่นๆ',
        ];
      case 'chat':
        return [
          'ใช้ถ้อยคำหยาบคาย / คุกคาม / ข่มขู่',
          'ชักชวนให้โอนเงินนอกระบบ',
          'ส่งข้อความสแปม / โฆษณาไม่พึงประสงค์',
          'พยายามหลอกลวงเอาข้อมูลส่วนตัว',
          'อื่นๆ',
        ];
      case 'order':
      default:
        return [
          'ไม่ได้รับพัสดุตามกำหนด',
          'สินค้าชำรุด / เสียหายรุนแรง',
          'สินค้าไม่ตรงกับรายละเอียด',
          'ผู้ขายไม่ตอบกลับ / ติดต่อไม่ได้',
          'อื่นๆ',
        ];
    }
  }

  String _getTypeLabel() {
    switch (widget.targetType) {
      case 'product':
        return "รายงานสินค้า";
      case 'store':
        return "รายงานร้านค้า";
      case 'chat':
        return "รายงานผู้ใช้ในแชท";
      case 'order':
        return "รายงานข้อพิพาทคำสั่งซื้อ";
      default:
        return "รายงานปัญหา";
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _evidenceImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _submitReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedCategory.isEmpty) {
      Get.snackbar(
        "กรุณาเลือกหมวดหมู่",
        "โปรดเลือกเหตุผลในการรายงานปัญหา",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String uploadedImageUrl = "";

      if (_evidenceImage != null) {
        String fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('reports/$fileName');
        await ref.putFile(_evidenceImage!);
        uploadedImageUrl = await ref.getDownloadURL();
      }

      String reporterName = user.displayName ?? "ผู้ใช้งาน";
      String reporterEmail = user.email ?? "";

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          reporterName = userDoc.data()?['name'] ?? reporterName;
        }
      } catch (_) {}

      final report = ReportModel(
        id: '',
        reporterId: user.uid,
        reporterName: reporterName,
        reporterEmail: reporterEmail,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetTitle: widget.targetTitle,
        reportedUserId: widget.reportedUserId,
        category: _selectedCategory,
        detail: _detailController.text.trim(),
        evidenceUrls: uploadedImageUrl.isNotEmpty ? [uploadedImageUrl] : [],
        status: 'pending',
        actionTaken: 'none',
      );

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .add(report.toMap());

      // หากเป็นข้อพิพาทออเดอร์ ให้อัปเดตสถานะออเดอร์เป็น disputed ด้วย
      if (widget.targetType == 'order') {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.orders)
            .doc(widget.targetId)
            .update({
              'status': 'disputed',
              'isDisputed': true,
              'disputeReason': _selectedCategory,
              'disputeDetail': _detailController.text.trim(),
              'disputeEvidenceUrl': uploadedImageUrl,
              'disputedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      Get.back(); // ปิด BottomSheet

      Get.snackbar(
        "ส่งรายงานปัญหาสำเร็จ",
        "ทีมงานได้รับข้อมูลรายงานของท่านแล้ว และจะดำเนินการตรวจสอบโดยเร็วที่สุด",
        icon: const Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.white),
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint("Error submitting report: $e");
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถส่งรายงานได้ในขณะนี้: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = _getCategories();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 15,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
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
            const SizedBox(height: 15),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color: Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTypeLabel(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        widget.targetTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Text(
              "เลือกหัวข้อปัญหา",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                bool isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.red[700],
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 15),
            const Text(
              "รายละเอียดเพิ่มเติม",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailController,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "อธิบายสิ่งที่เกิดขึ้นหรือพฤติกรรมที่ไม่เหมาะสม...",
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "รูปภาพหลักฐาน (ไม่บังคับ)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_evidenceImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _evidenceImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _evidenceImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(CupertinoIcons.camera_fill, size: 16),
                label: const Text("แนบรูปหลักฐาน"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "ส่งรายงานปัญหา",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
