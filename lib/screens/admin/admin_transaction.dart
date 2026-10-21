import 'dart:io';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/services/security_service.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/widgets/permission_denied_view.dart';

class AdminTransactionScreen extends StatefulWidget {
  final bool isBottomNav;

  const AdminTransactionScreen({super.key, this.isBottomNav = false});

  @override
  State<AdminTransactionScreen> createState() => _AdminTransactionScreenState();
}

class _AdminTransactionScreenState extends State<AdminTransactionScreen> {
  String _selectedFilter = 'all';

  String _getTransactionTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'topup':
        return 'เติมเงินเข้าวอลเล็ท';
      case 'purchase':
      case 'buy':
        return 'ชำระค่าสินค้า';
      case 'income':
      case 'sale':
        return 'รายรับจากการขาย';
      case 'withdraw':
        return 'ถอนเงินออกจากระบบ';
      case 'refund':
        return 'คืนเงิน';
      default:
        return 'ธุรกรรมอื่นๆ ($type)';
    }
  }

  bool _isAppIncome(String type) {
    List<String> incomingToApp = ['topup', 'purchase', 'buy'];
    return incomingToApp.contains(type.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "ธุรกรรมการเงิน",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isBottomNav
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
                onPressed: () => Get.back(),
              ),
      ),
      body: Stack(
        children: [
          _buildBgCircle(isDark, top: -50, right: -50, size: 250),
          _buildBgCircle(
            isDark,
            top: size.height * 0.4,
            left: -100,
            size: 300,
            opacityFactor: 0.8,
          ),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.transactions)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (snapshot.hasError) {
                  if (PermissionDeniedView.isPermissionDenied(snapshot.error)) {
                    return PermissionDeniedView(
                      title: "ไม่มีสิทธิ์เข้าถึงธุรกรรมการเงิน",
                      message:
                          "หน้านี้สงวนสิทธิ์เฉพาะผู้ดูแลระบบ (Admin) เท่านั้น\nกรุณาเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ หรือติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน",
                      technicalDetails: snapshot.error.toString(),
                      onRetry: () => setState(() {}),
                    );
                  }

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "เกิดข้อผิดพลาดในการโหลดข้อมูล",
                            style: GoogleFonts.kanit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(
                              CupertinoIcons.arrow_clockwise,
                              size: 16,
                            ),
                            label: const Text("ลองใหม่อีกครั้ง"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                final allTransactions = snapshot.data!.docs;

                double totalIn = 0;
                double totalOut = 0;

                for (var doc in allTransactions) {
                  var data = doc.data() as Map<String, dynamic>;
                  double amount = (data['amount'] ?? 0).toDouble();
                  String type = (data['type'] ?? '').toLowerCase();
                  if (_isAppIncome(type)) {
                    totalIn += amount;
                  } else {
                    totalOut += amount;
                  }
                }

                var filteredDocs = _selectedFilter == 'all'
                    ? allTransactions
                    : allTransactions.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        var type = (data['type'] ?? '').toLowerCase();
                        var status = (data['status'] ?? '').toLowerCase();

                        if (_selectedFilter == 'pending_withdraw') {
                          return type == 'withdraw' &&
                              (status == 'pending' || status == 'processing');
                        }
                        if (_selectedFilter == 'purchase' && type == 'buy') {
                          return true;
                        }
                        return type == _selectedFilter;
                      }).toList();

                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  bool isPendingA =
                      dataA['type'] == 'withdraw' &&
                      (dataA['status'] == 'pending' ||
                          dataA['status'] == 'processing');
                  bool isPendingB =
                      dataB['type'] == 'withdraw' &&
                      (dataB['status'] == 'pending' ||
                          dataB['status'] == 'processing');

                  if (isPendingA && !isPendingB) return -1;
                  if (!isPendingA && isPendingB) return 1;

                  if (isPendingA && isPendingB) {
                    int nudgeA = dataA['nudgedCount'] ?? 0;
                    int nudgeB = dataB['nudgedCount'] ?? 0;
                    if (nudgeA != nudgeB) return nudgeB.compareTo(nudgeA);

                    Timestamp? tsA = dataA['createdAt'];
                    Timestamp? tsB = dataB['createdAt'];
                    if (tsA != null && tsB != null) return tsA.compareTo(tsB);
                  }

                  Timestamp? tsA = dataA['createdAt'];
                  Timestamp? tsB = dataB['createdAt'];
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsB.compareTo(tsA);
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.05,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildSummaryItem(
                                  "เงินเข้า (In)",
                                  totalIn,
                                  Colors.green,
                                  CupertinoIcons.arrow_down_right_circle_fill,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                ),
                                _buildSummaryItem(
                                  "เงินออก (Out)",
                                  totalOut,
                                  Colors.redAccent,
                                  CupertinoIcons.arrow_up_right_circle_fill,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('ทั้งหมด', 'all', isDark),
                          _buildFilterChip(
                            'รอโอนเงิน',
                            'pending_withdraw',
                            isDark,
                          ),
                          _buildFilterChip('เติมเงิน', 'topup', isDark),
                          _buildFilterChip('ซื้อสินค้า', 'purchase', isDark),
                          _buildFilterChip('รายรับผู้ขาย', 'income', isDark),
                          _buildFilterChip('ถอนเงิน', 'withdraw', isDark),
                          _buildFilterChip('คืนเงิน', 'refund', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Text(
                                "ไม่พบรายการ",
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                var docId = filteredDocs[index].id;
                                var data =
                                    filteredDocs[index].data()
                                        as Map<String, dynamic>;
                                return _buildTransactionItem(
                                  context,
                                  data,
                                  docId,
                                  isDark,
                                  theme,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${amount.toStringAsFixed(0)} ฿",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    bool isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedFilter = value);
        },
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[400] : Colors.grey[700]),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        elevation: isSelected ? 4 : 0,
        pressElevation: 0,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  Color _getBankColor(String bankName) {
    final b = bankName.toLowerCase();
    if (b.contains('กสิกร')) return const Color(0xFF138f2d);
    if (b.contains('ไทยพาณิชย์') || b.contains('scb')) {
      return const Color(0xFF4e2e7f);
    }
    if (b.contains('กรุงเทพ') || b.contains('bbl')) {
      return const Color(0xFF1e4598);
    }
    if (b.contains('กรุงไทย') || b.contains('ktb')) {
      return const Color(0xFF00a5e5);
    }
    if (b.contains('กรุงศรี') || b.contains('bay')) {
      return const Color(0xFFfec43b);
    }
    if (b.contains('ทหารไทย') || b.contains('ttb')) {
      return const Color(0xFF002d63);
    }
    if (b.contains('ออมสิน') || b.contains('gsb')) {
      return const Color(0xFFeb198d);
    }
    if (b.contains('พร้อมเพย์') || b.contains('promptpay')) {
      return const Color(0xFF113566);
    }
    return AppTheme.primaryColor;
  }

  bool _isCommercialBank(String bankName) {
    final b = bankName.toLowerCase().trim();
    if (b.isEmpty || b == 'ไม่ระบุธนาคาร') return false;
    if (b.contains('พร้อมเพย์') || b.contains('promptpay')) return false;

    const bankKeywords = [
      'ธนาคาร',
      'bank',
      'กสิกร',
      'kbank',
      'kasikorn',
      'ไทยพาณิชย์',
      'scb',
      'กรุงเทพ',
      'bbl',
      'กรุงไทย',
      'ktb',
      'krungthai',
      'กรุงศรี',
      'bay',
      'krungsri',
      'อยุธยา',
      'ทหารไทย',
      'ธนชาต',
      'ttb',
      'tmb',
      'ออมสิน',
      'gsb',
      'ธ.ก.ส',
      'ธกส',
      'baac',
      'ซีไอเอ็มบี',
      'cimb',
      'ยูโอบี',
      'uob',
      'เกียรตินาคิน',
      'kkp',
      'ทิสโก้',
      'tisco',
      'แลนด์ แอนด์ เฮ้าส์',
      'lh',
      'อาคารสงเคราะห์',
      'ghb',
      'อิสลาม',
      'ibank',
    ];
    return bankKeywords.any((kw) => b.contains(kw));
  }

  bool _isPhoneNumber(String rawNumber, [String bankName = '']) {
    String clean = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('66') && clean.length == 11) {
      clean = '0${clean.substring(2)}';
    } else if (clean.length == 9 &&
        (clean.startsWith('6') ||
            clean.startsWith('8') ||
            clean.startsWith('9'))) {
      clean = '0$clean';
    }

    if (clean.length == 10 &&
        (clean.startsWith('06') ||
            clean.startsWith('08') ||
            clean.startsWith('09'))) {
      return true;
    }

    final b = bankName.toLowerCase().trim();
    final bool isPromptPayBank =
        b.contains('พร้อมเพย์') || b.contains('promptpay');
    if (isPromptPayBank) {
      if ((clean.length == 10 && clean.startsWith('0')) || clean.length == 13) {
        return true;
      }
    }

    if (clean.length == 10 &&
        clean.startsWith('0') &&
        !_isCommercialBank(bankName)) {
      return true;
    }

    return false;
  }

  String _normalizePromptPayTarget(String rawNumber) {
    String clean = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('66') && clean.length == 11) {
      clean = '0${clean.substring(2)}';
    } else if (clean.length == 9 &&
        (clean.startsWith('6') ||
            clean.startsWith('8') ||
            clean.startsWith('9'))) {
      clean = '0$clean';
    }
    return clean;
  }

  Future<bool> _markAsProcessing(
    String docId,
    String uid,
    double amount, {
    bool silent = false,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.transactions)
          .doc(docId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        if (!silent) {
          Get.snackbar(
            "ผิดพลาด",
            "ไม่พบข้อมูลรายการธุรกรรม",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
        return false;
      }

      final curData = docSnap.data() as Map<String, dynamic>;
      final curStatus = (curData['status'] ?? '').toString().toLowerCase();

      if (curStatus == 'cancelled' || curStatus == 'canceled') {
        Get.snackbar(
          "ไม่สามารถดำเนินการได้",
          "ผู้ใช้ได้ยกเลิกคำขอถอนเงินนี้ไปแล้วก่อนหน้านี้",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return false;
      }

      if (curStatus == 'success' || curStatus == 'completed') {
        return true;
      }

      await docRef.update({
        'status': 'processing',
        'processingAt': FieldValue.serverTimestamp(),
      });

      if (uid.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: uid,
          title: "กำลังดำเนินการโอนเงิน ฿${amount.toStringAsFixed(2)}",
          body: "แอดมินกำลังดำเนินการโอนเงินเข้าบัญชีของคุณ กรุณารอสักครู่",
          type: "wallet",
        );
      }

      if (!silent) {
        Get.back();
        Get.snackbar(
          "อัปเดตสถานะสำเร็จ",
          "เปลี่ยนสถานะเป็น 'กำลังดำเนินการ' แล้ว (ผู้ใช้ไม่สามารถกดยกเลิกได้)",
          backgroundColor: Colors.blue.shade700,
          colorText: Colors.white,
          icon: const Icon(
            CupertinoIcons.checkmark_shield_fill,
            color: Colors.white,
          ),
          duration: const Duration(seconds: 3),
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error in _markAsProcessing: $e");
      if (!silent) {
        Get.snackbar(
          "เกิดข้อผิดพลาด",
          e.toString(),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return false;
    }
  }

  void _showWithdrawalActionDialog(
    BuildContext context,
    String docId,
    String uid,
    Map<String, dynamic> data,
    String userName,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amount = (data['amount'] ?? 0).toDouble();
    final bankName = data['bankName'] ?? 'ไม่ระบุธนาคาร';
    final accountName = data['accountName'] ?? 'ไม่ระบุชื่อบัญชี';
    final accountNumber = data['accountNumber'] ?? 'ไม่ระบุเลขบัญชี';
    final cleanNumber = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final bankColor = _getBankColor(bankName);
    final bool isPhone = _isPhoneNumber(accountNumber, bankName);
    final String promptPayTarget = _normalizePromptPayTarget(accountNumber);
    final String currentStatus = (data['status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final bool isProcessing = currentStatus == 'processing';
    final String qrAmount = (amount % 1 == 0)
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    final String qrUrl = amount > 0
        ? 'https://promptpay.io/$promptPayTarget/$qrAmount.png'
        : 'https://promptpay.io/$promptPayTarget.png';
    String? existingSlipUrl =
        (data['slipUrl'] ??
                data['slip_image'] ??
                data['slip_url'] ??
                data['slipImage'])
            ?.toString();
    if (existingSlipUrl == null || existingSlipUrl.isEmpty) {
      if (data['slipData'] is Map && data['slipData']['url'] != null) {
        existingSlipUrl = data['slipData']['url'].toString();
      }
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ตรวจสอบการถอนเงิน",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: bankColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: bankColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPhone
                              ? CupertinoIcons.qrcode
                              : CupertinoIcons.building_2_fill,
                          size: 14,
                          color: bankColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          bankName,
                          style: TextStyle(
                            color: bankColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isProcessing
                      ? Colors.blue.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isProcessing
                        ? Colors.blue.withValues(alpha: 0.35)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isProcessing
                          ? CupertinoIcons.hourglass
                          : CupertinoIcons.clock,
                      color: isProcessing ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isProcessing
                                ? "สถานะ: กำลังดำเนินการโอนเงิน (Processing)"
                                : "สถานะ: รอดำเนินการ (Pending)",
                            style: TextStyle(
                              color: isProcessing ? Colors.blue : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isProcessing
                                ? "🔒 ผู้ใช้ไม่สามารถกดยกเลิกได้แล้ว เมื่อโอนสำเร็จให้แตะแนบสลิปด้านล่าง"
                                : "ผู้ใช้ยังกดยกเลิกได้ กด 'เริ่มดำเนินการ' เพื่อล็อกไม่ให้ผู้ใช้ยกเลิกขณะโอนเงิน",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? (isProcessing
                                        ? Colors.blue.shade100
                                        : Colors.grey[400])
                                  : (isProcessing
                                        ? Colors.blue.shade900
                                        : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              if (isPhone && promptPayTarget.isNotEmpty) ...[
                Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF113566).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF113566),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.qrcode,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "พร้อมเพย์ | PromptPay",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            width: 175,
                            height: 175,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                width: 175,
                                height: 175,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                        : null,
                                    color: const Color(0xFF113566),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (ctx, error, stack) => Container(
                              width: 175,
                              height: 175,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.exclamationmark_triangle,
                                      color: Colors.orange,
                                      size: 36,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      "ไม่สามารถโหลด QR ได้",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "โอนไปยังเบอร์: $promptPayTarget",
                          style: const TextStyle(
                            color: Color(0xFF113566),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "ยอดเงิน: ฿${amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "📱 สแกนด้วยแอปธนาคารเพื่อโอนทันที",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bankColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: bankColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.building_2_fill,
                        size: 22,
                        color: bankColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "โอนเงินเข้าบัญชีธนาคาร ($bankName)",
                              style: TextStyle(
                                fontSize: 13,
                                color: bankColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "เลขบัญชีไม่ใช่เบอร์โทรศัพท์ จึงไม่แสดง QR พร้อมเพย์ กรุณาคัดลอกเลขบัญชีเพื่อโอนในแอปธนาคาร",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildDetailRow("ผู้ขอถอนเงิน", userName, isDark),
              _buildDetailRow(
                "จำนวนเงิน",
                "${amount.toStringAsFixed(2)} ฿",
                isDark,
                isHighlight: true,
                onCopy: () {
                  Clipboard.setData(
                    ClipboardData(text: amount.toStringAsFixed(2)),
                  );
                  Get.snackbar(
                    "คัดลอกแล้ว",
                    "คัดลอกยอดเงิน ${amount.toStringAsFixed(2)} แล้ว",
                    backgroundColor: Colors.black87,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
              const Divider(height: 24),
              _buildDetailRow("ธนาคาร", bankName, isDark),
              _buildDetailRow("ชื่อบัญชี", accountName, isDark),
              _buildDetailRow(
                isPhone ? "เบอร์พร้อมเพย์" : "เลขที่บัญชี",
                accountNumber,
                isDark,
                onCopy: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: isPhone ? promptPayTarget : cleanNumber,
                    ),
                  );
                  Get.snackbar(
                    "คัดลอกแล้ว",
                    "คัดลอก${isPhone ? 'เบอร์พร้อมเพย์' : 'เลขบัญชี'} ${isPhone ? promptPayTarget : cleanNumber} แล้ว",
                    backgroundColor: Colors.black87,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),

              if (existingSlipUrl != null && existingSlipUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showSlipDialog(
                      context,
                      existingSlipUrl!,
                      data,
                      userName,
                    ),
                    icon: const Icon(
                      CupertinoIcons.doc_text_viewfinder,
                      size: 16,
                    ),
                    label: const Text("ดูสลิปหลักฐานการโอน"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 25),
              if (!isProcessing) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _markAsProcessing(docId, uid, amount),
                    icon: const Icon(CupertinoIcons.lock_shield, size: 18),
                    label: const Text(
                      "เริ่มดำเนินการ (ล็อกไม่ให้ผู้ใช้กดยกเลิก)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        _showRejectDialog(context, docId, uid, amount);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ปฏิเสธ/คืนเงิน",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        bool ok = await _markAsProcessing(
                          docId,
                          uid,
                          amount,
                          silent: true,
                        );
                        if (ok) {
                          _showUploadSlipDialog(docId, amount);
                        }
                      },
                      icon: const Icon(
                        CupertinoIcons.arrow_up_doc_fill,
                        size: 18,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: Text(
                        isProcessing ? "แนบสลิปโอนเงิน" : "โอนเงินเรียบร้อย",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
                fontSize: isHighlight ? 18 : 14,
                color: isHighlight ? Colors.redAccent : null,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(
                CupertinoIcons.doc_on_clipboard,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              onPressed: onCopy,
              visualDensity: VisualDensity.compact,
              tooltip: "คัดลอก",
            ),
        ],
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    String docId,
    String uid,
    double amount,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String selectedReason = "เลขที่บัญชีไม่ถูกต้อง";
    final TextEditingController customReasonController =
        TextEditingController();
    final List<String> commonReasons = [
      "เลขที่บัญชีไม่ถูกต้อง",
      "ชื่อบัญชีไม่ตรงกับชื่อผู้ใช้ที่ลงทะเบียน",
      "ธนาคารปลายทางไม่สามารถรับโอนได้",
      "อื่นๆ (ระบุเอง)",
    ];

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            title: Text(
              "ปฏิเสธคำขอถอนเงิน",
              style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ยอดเงิน ฿${amount.toStringAsFixed(2)} จะถูกโอนคืนเข้ากระเป๋าวอลเล็ทของผู้ใช้ทันที\nโปรดเลือกเหตุผลเพื่อให้ผู้ใช้ทราบ:",
                    style: GoogleFonts.kanit(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                    child: Column(
                      children: commonReasons.map((reason) {
                        return RadioListTile<String>(
                          title: Text(
                            reason,
                            style: GoogleFonts.kanit(fontSize: 13),
                          ),
                          value: reason,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.red,
                        );
                      }).toList(),
                    ),
                  ),
                  if (selectedReason == "อื่นๆ (ระบุเอง)") ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customReasonController,
                      style: GoogleFonts.kanit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "พิมพ์เหตุผลที่ปฏิเสธ...",
                        hintStyle: GoogleFonts.kanit(fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  "ยกเลิก",
                  style: GoogleFonts.kanit(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  String finalReason = selectedReason == "อื่นๆ (ระบุเอง)"
                      ? customReasonController.text.trim()
                      : selectedReason;
                  if (finalReason.isEmpty) {
                    finalReason = "แอดมินปฏิเสธรายการถอนเงิน";
                  }
                  Get.back();
                  _rejectWithdrawal(docId, uid, amount, finalReason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "ยืนยันปฏิเสธและคืนเงิน",
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUploadSlipDialog(String docId, double expectedAmount) {
    File? slipImage;
    bool isUploading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          final theme = Theme.of(dialogContext);
          final isDark = theme.brightness == Brightness.dark;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "อัปโหลดสลิปยืนยันการโอน",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isUploading)
                        IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid),
                          color: Colors.grey,
                          onPressed: () => Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              setStateDialog(
                                () => slipImage = File(image.path),
                              );
                            }
                          },
                    child: Container(
                      height: 360,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: slipImage != null
                              ? Colors.green
                              : (isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey.shade300),
                          width: 1.5,
                        ),
                      ),
                      child: slipImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  InteractiveViewer(
                                    maxScale: 3.0,
                                    child: Image.file(
                                      slipImage!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons
                                                .arrow_right_arrow_left,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "แตะเพื่อเปลี่ยนรูป",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.photo_on_rectangle,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "แตะเพื่อเลือกรูปสลิป",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "รองรับภาพแนวตั้ง เห็นรายละเอียดครบถ้วน",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isUploading
                              ? null
                              : () => Navigator.of(
                                  dialogContext,
                                  rootNavigator: true,
                                ).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (slipImage == null || isUploading)
                              ? null
                              : () async {
                                  setStateDialog(() => isUploading = true);
                                  bool success = await _uploadSlipAndApprove(
                                    docId,
                                    slipImage!,
                                    expectedAmount,
                                  );
                                  if (dialogContext.mounted) {
                                    setStateDialog(() => isUploading = false);
                                    if (success) {
                                      Navigator.of(
                                        dialogContext,
                                        rootNavigator: true,
                                      ).pop();
                                      Get.snackbar(
                                        "สำเร็จ",
                                        "อนุมัติรายการถอนเงินและอัปโหลดสลิปเรียบร้อย",
                                        backgroundColor: Colors.green,
                                        colorText: Colors.white,
                                        icon: const Icon(
                                          CupertinoIcons
                                              .check_mark_circled_solid,
                                          color: Colors.white,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isUploading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "ยืนยัน",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  Future<bool> _uploadSlipAndApprove(
    String docId,
    File imageFile,
    double expectedAmount,
  ) async {
    try {
      final String slipokApiKey = dotenv.isInitialized
          ? (dotenv.env['SLIPOK_API_KEY'] ?? '')
          : '';

      final branchId = dotenv.isInitialized
          ? (dotenv.env['SLIPOK_BRANCH_ID'] ?? '61849')
          : '61849';
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.slipok.com/api/line/apikey/$branchId'),
      );
      request.headers['x-authorization'] = slipokApiKey;
      request.files.add(
        await http.MultipartFile.fromPath('files', imageFile.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        var slipData = jsonData['data'];
        double transferredAmount = (slipData['amount'] ?? 0).toDouble();
        String transRef = slipData['transRef'] ?? '';

        if (transferredAmount != expectedAmount) {
          Get.snackbar(
            "สลิปไม่ถูกต้อง",
            "จำนวนเงินในสลิป ($transferredAmount ฿) ไม่ตรงกับยอดถอน ($expectedAmount ฿)",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return false;
        }

        if (transRef.isEmpty) {
          Get.snackbar(
            "สลิปไม่สมบูรณ์",
            "ไม่สามารถอ่านรหัสอ้างอิงจากสลิปได้ กรุณาใช้สลิปที่มี QR Code คมชัด",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return false;
        }

        var existingTx = await FirebaseFirestore.instance
            .collection(FirestoreCollections.transactions)
            .where('transRef', isEqualTo: transRef)
            .where('status', isEqualTo: 'success')
            .get();

        bool isDuplicate = existingTx.docs.any((d) => d.id != docId);
        if (isDuplicate) {
          Get.snackbar(
            "สลิปนี้ถูกใช้งานไปแล้ว",
            "สลิปนี้ (รหัสอ้างอิง: $transRef) เคยถูกบันทึกสำเร็จในระบบไปแล้ว ไม่สามารถใช้ซ้ำได้",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            icon: const Icon(
              CupertinoIcons.clear_circled_solid,
              color: Colors.white,
            ),
          );
          return false;
        }

        DocumentReference txRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.transactions)
            .doc(docId);
        DocumentSnapshot txSnap = await txRef.get();
        if (!txSnap.exists) {
          throw Exception("ไม่พบข้อมูลรายการถอนเงิน");
        }
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;
        String expectedUserAccountName = (txData['accountName'] ?? '')
            .toString();
        String expectedUserAccountNumber = (txData['accountNumber'] ?? '')
            .toString();

        if (expectedUserAccountName.isNotEmpty ||
            expectedUserAccountNumber.isNotEmpty) {
          bool isReceiverValid = SecurityService.isSlipReceiverValid(
            receiverData: slipData['receiver'],
            expectedAccountName: expectedUserAccountName,
            expectedPromptPay: expectedUserAccountNumber,
          );

          if (!isReceiverValid) {
            String targetLabel = expectedUserAccountName.isNotEmpty
                ? expectedUserAccountName
                : expectedUserAccountNumber;
            Get.snackbar(
              "สลิปไม่ตรงกับบัญชีผู้รับ",
              "สลิปนี้ไม่ได้โอนไปยังบัญชีของผู้ขอถอน ($targetLabel)\nกรุณาตรวจสอบสลิปการโอนอีกครั้งเพื่อป้องกันการโอนผิดคน",
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
              icon: const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.white,
              ),
            );
            return false;
          }
        }

        String fileName = 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(
          'slips/withdrawals/$docId/$fileName',
        );

        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        String uid = txData['uid'] ?? '';

        await txRef.update({
          'status': 'success',
          'slipUrl': downloadUrl,
          'transRef': transRef,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (uid.isNotEmpty) {
          await NotificationService.sendNotification(
            userId: uid,
            title: "ถอนเงินสำเร็จ ฿${expectedAmount.toStringAsFixed(2)}",
            body:
                "แอดมินได้โอนเงินเข้าบัญชีของคุณเรียบร้อยแล้ว แตะเพื่อดูสลิปหลักฐาน",
            type: "wallet",
          );
        }

        return true;
      } else {
        Get.snackbar(
          "ตรวจสอบสลิปไม่ผ่าน",
          jsonData['message'] ?? 'รูปภาพสลิปไม่ถูกต้อง หรือเซิร์ฟเวอร์มีปัญหา',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<void> _rejectWithdrawal(
    String docId,
    String uid,
    double amount,
    String reason,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference userRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid);
        DocumentReference txRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.transactions)
            .doc(docId);

        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(amount),
        });

        transaction.update(txRef, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'note': reason,
        });
      });

      if (uid.isNotEmpty) {
        await NotificationService.sendNotification(
          userId: uid,
          title: "คำขอถอนเงินถูกปฏิเสธ ฿${amount.toStringAsFixed(2)}",
          body: "เหตุผล: $reason (ระบบได้โอนเงินคืนเข้าวอลเล็ทของคุณแล้ว)",
          type: "wallet",
        );
      }

      Get.snackbar(
        "ปฏิเสธรายการ",
        "ปฏิเสธรายการและคืนเงิน ฿${amount.toStringAsFixed(2)} ให้ผู้ใช้แล้ว",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(CupertinoIcons.info_circle_fill, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showSlipDialog(
    BuildContext context,
    String slipUrl,
    Map<String, dynamic> data,
    String userName,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amount = (data['amount'] ?? 0).toDouble();
    final type = (data['type'] ?? 'unknown').toString().toLowerCase();
    final status = (data['status'] ?? 'pending').toString();
    final String bankName = data['bankName'] ?? '';
    final String accountNumber = data['accountNumber'] ?? '';
    final String accountName = data['accountName'] ?? '';
    final String? note = data['note'];
    final String transRef =
        (data['transRef'] ??
                data['refNumber'] ??
                data['transactionId'] ??
                data['ref'] ??
                '')
            .toString();

    Timestamp? ts = data['createdAt'];
    DateTime date = ts?.toDate() ?? DateTime.now();
    String formattedDate =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
            maxWidth: 480,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_text_viewfinder,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "สลิปหลักฐานการโอนเงิน",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "ใช้นิ้วซูม/ขยายเพื่อตรวจสอบความถูกต้อง",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 24,
                      ),
                      color: Colors.grey,
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 380),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 4.5,
                              child: Center(
                                child: Image.network(
                                  slipUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return SizedBox(
                                      height: 240,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              progress.expectedTotalBytes !=
                                                  null
                                              ? progress.cumulativeBytesLoaded /
                                                    progress.expectedTotalBytes!
                                              : null,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 200,
                                        color: isDark
                                            ? Colors.grey[900]
                                            : Colors.grey[200],
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                CupertinoIcons
                                                    .exclamationmark_triangle_fill,
                                                color: Colors.orange,
                                                size: 36,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "ไม่สามารถโหลดรูปภาพสลิปได้",
                                                style: GoogleFonts.kanit(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "อาจเกิดจาก URL หมดอายุหรือปัญหาการเชื่อมต่อ",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.zoom_in,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "ซูมได้ 4.5 เท่า",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getTransactionTypeName(type),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                _buildStatusBadge(status),
                              ],
                            ),
                            const Divider(height: 20),
                            _buildDetailRow("ผู้ทำรายการ", userName, isDark),
                            _buildDetailRow(
                              "ยอดเงิน",
                              "฿${amount.toStringAsFixed(2)}",
                              isDark,
                              isHighlight: true,
                            ),
                            _buildDetailRow("วันเวลา", formattedDate, isDark),
                            if (bankName.isNotEmpty)
                              _buildDetailRow("ธนาคาร", bankName, isDark),
                            if (accountName.isNotEmpty)
                              _buildDetailRow("ชื่อบัญชี", accountName, isDark),
                            if (accountNumber.isNotEmpty)
                              _buildDetailRow(
                                "เลขที่บัญชี",
                                accountNumber,
                                isDark,
                              ),
                            if (transRef.isNotEmpty)
                              _buildDetailRow(
                                "เลขอ้างอิง",
                                transRef,
                                isDark,
                                onCopy: () {
                                  Clipboard.setData(
                                    ClipboardData(text: transRef),
                                  );
                                  Get.snackbar(
                                    "คัดลอกแล้ว",
                                    "คัดลอกเลขอ้างอิง $transRef แล้ว",
                                    backgroundColor: Colors.black87,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                              ),
                            if (note != null && note.isNotEmpty)
                              _buildDetailRow("หมายเหตุ", note, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetailDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String userName,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amount = (data['amount'] ?? 0).toDouble();
    final type = (data['type'] ?? 'unknown').toString().toLowerCase();
    final status = (data['status'] ?? 'pending').toString();
    final String bankName = data['bankName'] ?? '';
    final String accountNumber = data['accountNumber'] ?? '';
    final String accountName = data['accountName'] ?? '';
    final String? note = data['note'];
    final String transRef =
        (data['transRef'] ??
                data['refNumber'] ??
                data['transactionId'] ??
                data['ref'] ??
                '')
            .toString();

    Timestamp? ts = data['createdAt'];
    DateTime date = ts?.toDate() ?? DateTime.now();
    String formattedDate =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "รายละเอียดธุรกรรม",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow("ประเภท", _getTransactionTypeName(type), isDark),
              _buildDetailRow("ผู้ทำรายการ", userName, isDark),
              _buildDetailRow(
                "ยอดเงิน",
                "฿${amount.toStringAsFixed(2)}",
                isDark,
                isHighlight: true,
              ),
              _buildDetailRow("วันเวลา", formattedDate, isDark),
              if (bankName.isNotEmpty)
                _buildDetailRow("ธนาคาร", bankName, isDark),
              if (accountName.isNotEmpty)
                _buildDetailRow("ชื่อบัญชี", accountName, isDark),
              if (accountNumber.isNotEmpty)
                _buildDetailRow("เลขบัญชี/พร้อมเพย์", accountNumber, isDark),
              if (transRef.isNotEmpty)
                _buildDetailRow(
                  "เลขอ้างอิง",
                  transRef,
                  isDark,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: transRef));
                    Get.snackbar(
                      "คัดลอกแล้ว",
                      "คัดลอกเลขอ้างอิง $transRef แล้ว",
                      backgroundColor: Colors.black87,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
              if (note != null && note.isNotEmpty)
                _buildDetailRow("หมายเหตุ", note, isDark),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("ปิด"),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
    bool isDark,
    ThemeData theme,
  ) {
    String uid = data['uid'] ?? data['member_id'] ?? '';
    String type = (data['type'] ?? 'unknown').toLowerCase();
    double amount = (data['amount'] ?? 0).toDouble();
    String status = data['status'] ?? 'pending';
    Timestamp? ts = data['createdAt'];
    DateTime date = ts?.toDate() ?? DateTime.now();
    String formattedDate =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

    bool isAppIn = _isAppIncome(type);

    String? slipUrl =
        (data['slipUrl'] ??
                data['slip_image'] ??
                data['slip_url'] ??
                data['slipImage'])
            ?.toString();
    if ((slipUrl == null || slipUrl.isEmpty) && data['slipData'] is Map) {
      slipUrl = data['slipData']['url']?.toString();
    }
    final bool hasSlip = slipUrl != null && slipUrl.isNotEmpty;

    return FutureBuilder<DocumentSnapshot?>(
      future: uid.isEmpty
          ? Future.value(null)
          : FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnapshot) {
        String userName = "กำลังโหลด...";
        String userImage = "";

        if (userSnapshot.connectionState == ConnectionState.done) {
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            userName = userData['name'] ?? "ไม่ทราบชื่อ";
            userImage = userData['profileImage'] ?? "";
          } else {
            userName = "ไม่ทราบชื่อผู้ใช้";
          }
        }

        bool isPendingWithdraw =
            type == 'withdraw' &&
            (status == 'pending' || status == 'processing');
        bool isProcessing = type == 'withdraw' && status == 'processing';
        int hoursWaited = DateTime.now().difference(date).inHours;
        int nudgedCount = data['nudgedCount'] ?? 0;
        bool isCritical = isPendingWithdraw && hoursWaited >= 18;
        bool isUrgent =
            isPendingWithdraw && (hoursWaited >= 6 || nudgedCount > 0);

        return InkWell(
          onTap: isPendingWithdraw
              ? () => _showWithdrawalActionDialog(
                  context,
                  docId,
                  uid,
                  data,
                  userName,
                )
              : (hasSlip
                    ? () => _showSlipDialog(context, slipUrl!, data, userName)
                    : () => _showTransactionDetailDialog(
                        context,
                        data,
                        userName,
                      )),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPendingWithdraw
                    ? (isProcessing
                          ? Colors.blue.withValues(alpha: 0.6)
                          : (isCritical
                                ? Colors.redAccent.withValues(alpha: 0.6)
                                : Colors.orange.withValues(alpha: 0.5)))
                    : (hasSlip
                          ? Colors.blue.withValues(alpha: 0.3)
                          : (isDark ? Colors.white10 : Colors.grey.shade100)),
                width: isPendingWithdraw ? 1.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      backgroundImage: userImage.isNotEmpty
                          ? NetworkImage(userImage)
                          : null,
                      child: userImage.isEmpty
                          ? Icon(
                              CupertinoIcons.person_fill,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isAppIn ? Colors.green : Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.cardColor, width: 2),
                        ),
                        child: Icon(
                          isAppIn
                              ? CupertinoIcons.arrow_down_left
                              : CupertinoIcons.arrow_up_right,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _getTransactionTypeName(type),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasSlip) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.doc_text_viewfinder,
                                    size: 10,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    "มีสลิป",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isProcessing) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.hourglass,
                                    size: 10,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    "กำลังโอน",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isPendingWithdraw && isCritical) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                "🔥 วิกฤต (>18 ชม.)",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else if (isPendingWithdraw && isUrgent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                nudgedCount > 0
                                    ? "🔔 เตือน $nudgedCount ครั้ง"
                                    : "⚠️ รอนาน (>6 ชม.)",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      if (hasSlip) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _showSlipDialog(
                            context,
                            slipUrl!,
                            data,
                            userName,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.25,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.photo,
                                  size: 11,
                                  color: AppTheme.primaryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "ดูสลิปหลักฐาน",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${isAppIn ? '+' : '-'}${amount.toStringAsFixed(2)} ฿",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isAppIn ? Colors.green : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'processing':
        color = Colors.blue;
        label = "กำลังดำเนินการ";
        break;
      case 'success':
      case 'completed':
      case 'approved':
        color = Colors.green;
        label = "สำเร็จ";
        break;
      case 'rejected':
        color = Colors.red;
        label = "ปฏิเสธ";
        break;
      case 'cancelled':
      case 'canceled':
      case 'failed':
        color = Colors.red;
        label = "ยกเลิก";
        break;
      default:
        color = Colors.orange;
        label = "รอดำเนินการ";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text_search,
            size: 60,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          const SizedBox(height: 15),
          Text(
            "ไม่พบประวัติธุรกรรม",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
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
    final baseOpacity = isDark ? 0.03 : 0.06;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(
            alpha: baseOpacity * opacityFactor,
          ),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
