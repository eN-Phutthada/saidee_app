import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/config/firestore_collections.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  String _getTransactionTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'topup':
        return 'เติมเงิน';
      case 'purchase':
      case 'buy':
        return 'ชำระค่าสินค้า';
      case 'income':
      case 'sale':
        return 'รายรับการขาย';
      case 'withdraw':
        return 'ถอนเงิน';
      case 'refund':
        return 'คืนเงิน';
      default:
        return 'ธุรกรรมอื่นๆ';
    }
  }

  bool _isAppIncome(String type) {
    final t = type.toLowerCase();
    return t == 'topup' || t == 'income' || t == 'sale' || t == 'refund';
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
        color = Colors.green;
        label = "สำเร็จ";
        break;
      case 'cancelled':
      case 'failed':
        color = Colors.red;
        label = "ยกเลิก";
        break;
      case 'pending':
      default:
        color = Colors.orange;
        label = "รอดำเนินการ";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.kanit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showSlipDialog(BuildContext context, String slipUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                slipUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.white,
                  child: Center(
                    child: Text(
                      "ไม่สามารถโหลดรูปภาพได้",
                      style: GoogleFonts.kanit(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ประวัติธุรกรรม',
          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? Center(child: Text("กรุณาเข้าสู่ระบบ", style: GoogleFonts.kanit()))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.transactions)
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "เกิดข้อผิดพลาด: ${snapshot.error}",
                      style: GoogleFonts.kanit(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text_search,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "ยังไม่มีประวัติธุรกรรม",
                          style: GoogleFonts.kanit(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs.toList();

                // Sort locally to avoid needing a Firestore composite index
                docs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  Timestamp? tsA = dataA['createdAt'];
                  Timestamp? tsB = dataB['createdAt'];
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsB.compareTo(tsA); // descending
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;
                    String uid = data['uid'] ?? user.uid;
                    String type = (data['type'] ?? 'unknown').toLowerCase();
                    double amount = (data['amount'] ?? 0).toDouble();
                    String status = data['status'] ?? 'pending';
                    String? slipUrl = data['slipUrl'];
                    String? note = data['note'];
                    Timestamp? ts = data['createdAt'];
                    Timestamp? lastNudgedAt = data['lastNudgedAt'];
                    DateTime date = ts?.toDate() ?? DateTime.now();
                    String formattedDate =
                        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

                    bool isAppIn = _isAppIncome(type);
                    bool isPendingWithdrawal =
                        type == 'withdraw' && status.toLowerCase() == 'pending';
                    bool isSlaExpired =
                        DateTime.now().difference(date).inSeconds >= 86400;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: isPendingWithdrawal
                            ? Border.all(
                                color: isSlaExpired
                                    ? Colors.redAccent.withValues(alpha: 0.5)
                                    : Colors.orange.withValues(alpha: 0.4),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.05,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: slipUrl != null
                                ? () => _showSlipDialog(context, slipUrl)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isAppIn
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isAppIn
                                          ? CupertinoIcons.arrow_down_left
                                          : CupertinoIcons.arrow_up_right,
                                      color: isAppIn
                                          ? Colors.green
                                          : Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _getTransactionTypeName(type),
                                              style: GoogleFonts.kanit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (slipUrl != null) ...[
                                              const SizedBox(width: 5),
                                              const Icon(
                                                CupertinoIcons.photo,
                                                size: 14,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formattedDate,
                                          style: GoogleFonts.kanit(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (note != null &&
                                            note.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "หมายเหตุ: $note",
                                            style: GoogleFonts.kanit(
                                              color: Colors.orange[700],
                                              fontSize: 12,
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
                                        style: GoogleFonts.kanit(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: isAppIn
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Standalone Countdown & Action Box for Pending Withdrawals
                          // Owns its timer so list doesn't flicker on ticks!
                          if (isPendingWithdrawal) ...[
                            Divider(
                              height: 1,
                              color: isDark ? Colors.white10 : Colors.grey[200],
                            ),
                            _PendingCountdownBox(
                              docId: docId,
                              uid: uid,
                              amount: amount,
                              lastNudgedAt: lastNudgedAt,
                              createdAt: date,
                              isDark: isDark,
                              onCancel: () => _cancelWithdrawal(
                                context,
                                docId,
                                amount,
                                uid,
                              ),
                              onNudge: () => _nudgeAdmin(
                                context,
                                docId,
                                lastNudgedAt,
                                amount,
                              ),
                              onContact: () => _showContactAdminDialog(
                                context,
                                docId,
                                amount,
                              ),
                              onClaimSla: () =>
                                  _claimRefundSla(context, docId, amount, uid),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _cancelWithdrawal(
    BuildContext context,
    String docId,
    double amount,
    String uid,
  ) async {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          "ยืนยันยกเลิกการถอนเงิน",
          style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          "คุณต้องการยกเลิกคำขอถอนเงินจำนวน ฿${amount.toStringAsFixed(2)} ใช่หรือไม่?\n\nยอดเงินจะถูกโอนกลับเข้าวอลเล็ทของคุณทันที",
          style: GoogleFonts.kanit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              "ไม่ยกเลิก",
              style: GoogleFonts.kanit(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                await FirebaseFirestore.instance.runTransaction((
                  transaction,
                ) async {
                  DocumentReference txRef = FirebaseFirestore.instance
                      .collection(FirestoreCollections.transactions)
                      .doc(docId);
                  DocumentSnapshot txSnap = await transaction.get(txRef);
                  if (!txSnap.exists) throw Exception("ไม่พบข้อมูลรายการ");
                  if ((txSnap.data() as Map<String, dynamic>)['status'] !=
                      'pending') {
                    throw Exception("รายการนี้ได้รับการประมวลผลไปแล้ว");
                  }

                  DocumentReference userRef = FirebaseFirestore.instance
                      .collection(FirestoreCollections.users)
                      .doc(uid);

                  transaction.update(userRef, {
                    'walletBalance': FieldValue.increment(amount),
                  });

                  transaction.update(txRef, {
                    'status': 'cancelled',
                    'updatedAt': FieldValue.serverTimestamp(),
                    'note':
                        'ผู้ใช้กดยกเลิกคำขอถอนเงิน (คืนเงินเข้าวอลเล็ทแล้ว)',
                  });
                });

                Get.snackbar(
                  "ยกเลิกสำเร็จ",
                  "คืนเงิน ฿${amount.toStringAsFixed(2)} เข้าวอลเล็ทของคุณแล้ว",
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  icon: const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: Colors.white,
                  ),
                );
              } catch (e) {
                Get.snackbar(
                  "เกิดข้อผิดพลาด",
                  e.toString().replaceAll('Exception: ', ''),
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              "ยืนยันยกเลิก",
              style: GoogleFonts.kanit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimRefundSla(
    BuildContext context,
    String docId,
    double amount,
    String uid,
  ) async {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          "ขอรับเงินคืนทันที (SLA เกิน 24 ชม.)",
          style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          "คำขอถอนเงินนี้เกินระยะเวลาดำเนินการ 24 ชั่วโมงแล้ว ตามนโยบายความเป็นธรรม คุณสามารถดึงเงิน ฿${amount.toStringAsFixed(2)} กลับเข้าวอลเล็ทได้ทันที",
          style: GoogleFonts.kanit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              "รอต่ออีกสักนิด",
              style: GoogleFonts.kanit(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                await FirebaseFirestore.instance.runTransaction((
                  transaction,
                ) async {
                  DocumentReference txRef = FirebaseFirestore.instance
                      .collection(FirestoreCollections.transactions)
                      .doc(docId);
                  DocumentSnapshot txSnap = await transaction.get(txRef);
                  if (!txSnap.exists) throw Exception("ไม่พบข้อมูลรายการ");
                  if ((txSnap.data() as Map<String, dynamic>)['status'] !=
                      'pending') {
                    throw Exception("รายการนี้ได้รับการประมวลผลไปแล้ว");
                  }

                  DocumentReference userRef = FirebaseFirestore.instance
                      .collection(FirestoreCollections.users)
                      .doc(uid);

                  transaction.update(userRef, {
                    'walletBalance': FieldValue.increment(amount),
                  });

                  transaction.update(txRef, {
                    'status': 'cancelled',
                    'updatedAt': FieldValue.serverTimestamp(),
                    'note':
                        'ผู้ใช้ขอเงินคืนเนื่องจากเกินกำหนดเวลา 24 ชม. (SLA Expired)',
                  });
                });

                Get.snackbar(
                  "ขอเงินคืนสำเร็จ",
                  "ระบบได้คืนเงิน ฿${amount.toStringAsFixed(2)} เข้าวอลเล็ทของคุณเรียบร้อยแล้ว",
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  icon: const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: Colors.white,
                  ),
                );
              } catch (e) {
                Get.snackbar(
                  "เกิดข้อผิดพลาด",
                  e.toString().replaceAll('Exception: ', ''),
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              "ดึงเงินคืนเข้าวอลเล็ท",
              style: GoogleFonts.kanit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _nudgeAdmin(
    BuildContext context,
    String docId,
    Timestamp? lastNudgedAt,
    double amount,
  ) async {
    if (lastNudgedAt != null) {
      final diff = DateTime.now().difference(lastNudgedAt.toDate());
      if (diff.inHours < 2) {
        int minutesLeft = 120 - diff.inMinutes;
        Get.snackbar(
          "เตือนแอดมินแล้ว",
          "คุณได้สะกิดเตือนแอดมินไปแล้ว สามารถสะกิดเตือนอีกครั้งได้ในอีก $minutesLeft นาที",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          icon: const Icon(
            CupertinoIcons.info_circle_fill,
            color: Colors.white,
          ),
        );
        return;
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.transactions)
          .doc(docId)
          .update({
            'lastNudgedAt': FieldValue.serverTimestamp(),
            'nudgedCount': FieldValue.increment(1),
          });

      Get.snackbar(
        "สะกิดแอดมินสำเร็จ!",
        "ระบบได้ส่งแจ้งเตือนด่วนไปยังแอดมินให้เร่งดำเนินการโอนเงินให้คุณแล้ว",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showContactAdminDialog(
    BuildContext context,
    String docId,
    double amount,
  ) {
    const String adminPhone = "064-749-0079";
    const String rawAdminPhone = "0647490079";
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.phone_fill,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ติดต่อฝ่ายบริการลูกค้า / แอดมิน",
                        style: GoogleFonts.kanit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "เวลาทำการ: 08:00 - 22:00 น. (ทุกวัน)",
                        style: GoogleFonts.kanit(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[750]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "เบอร์โทรสายด่วนแอดมิน",
                              style: GoogleFonts.kanit(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              adminPhone,
                              style: GoogleFonts.kanit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: rawAdminPhone),
                          );
                          Get.snackbar(
                            "คัดลอกเบอร์โทรแล้ว",
                            "คัดลอก $adminPhone ไปยังคลิปบอร์ดแล้ว สามารถนำไปวางในแอปโทรศัพท์ได้เลย",
                            backgroundColor: Colors.black87,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                          );
                        },
                        icon: const Icon(
                          CupertinoIcons.doc_on_clipboard,
                          size: 16,
                        ),
                        label: Text(
                          "คัดลอกเบอร์",
                          style: GoogleFonts.kanit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "รหัสอ้างอิงธุรกรรม",
                              style: GoogleFonts.kanit(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              docId,
                              style: GoogleFonts.kanit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: docId));
                          Get.snackbar(
                            "คัดลอกรหัสอ้างอิงแล้ว",
                            docId,
                            backgroundColor: Colors.black87,
                            colorText: Colors.white,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "💡 สามารถแจ้งรหัสอ้างอิงและยอดเงิน ฿${amount.toStringAsFixed(2)} ให้เจ้าหน้าที่เพื่อการตรวจสอบที่รวดเร็ว",
              style: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "ปิดหน้านี้",
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

/// Standalone countdown and action box for pending withdrawals.
/// Contains its own 1-second timer to avoid rebuilding the parent screen/list,
/// eliminating list flicker while keeping the countdown real-time and fluid.
class _PendingCountdownBox extends StatefulWidget {
  final String docId;
  final String uid;
  final double amount;
  final Timestamp? lastNudgedAt;
  final DateTime createdAt;
  final bool isDark;
  final VoidCallback onCancel;
  final VoidCallback onNudge;
  final VoidCallback onContact;
  final VoidCallback onClaimSla;

  const _PendingCountdownBox({
    required this.docId,
    required this.uid,
    required this.amount,
    required this.lastNudgedAt,
    required this.createdAt,
    required this.isDark,
    required this.onCancel,
    required this.onNudge,
    required this.onContact,
    required this.onClaimSla,
  });

  @override
  State<_PendingCountdownBox> createState() => _PendingCountdownBoxState();
}

class _PendingCountdownBoxState extends State<_PendingCountdownBox> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Ticks every second strictly within this isolated widget
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return "00:00:00";
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    const int slaTotalSeconds = 24 * 3600;
    final int elapsedSeconds = DateTime.now()
        .difference(widget.createdAt)
        .inSeconds;
    final int remainingSeconds = slaTotalSeconds - elapsedSeconds;
    final bool isExpired = remainingSeconds <= 0;

    // Check nudge cooldown
    bool canNudge = true;
    String nudgeLabel = "สะกิดเตือน";
    if (widget.lastNudgedAt != null) {
      final nudgeDiff = DateTime.now().difference(
        widget.lastNudgedAt!.toDate(),
      );
      if (nudgeDiff.inHours < 2) {
        canNudge = false;
        final minsLeft = 120 - nudgeDiff.inMinutes;
        nudgeLabel = "รออีก $minsLeftน.";
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: widget.isDark ? 0.12 : 0.05)
            : Colors.orange.withValues(alpha: widget.isDark ? 0.12 : 0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Status & SLA Countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isExpired
                        ? CupertinoIcons.exclamationmark_triangle_fill
                        : CupertinoIcons.clock_fill,
                    size: 16,
                    color: isExpired ? Colors.redAccent : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isExpired
                        ? "เกินเวลารับประกัน 24 ชม."
                        : "รอดำเนินการ (เป้าหมาย 24 ชม.)",
                    style: GoogleFonts.kanit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.redAccent : Colors.orange[800],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isExpired ? Colors.red : Colors.orange).withValues(
                    alpha: widget.isDark ? 0.25 : 0.15,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isExpired ? Colors.red : Colors.orange).withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired
                          ? CupertinoIcons.xmark_circle_fill
                          : CupertinoIcons.stopwatch,
                      size: 12,
                      color: isExpired ? Colors.red : Colors.orange[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpired
                          ? "เกินกำหนด"
                          : _formatDuration(remainingSeconds),
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.red : Colors.orange[900],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Bar (when SLA is running)
          if (!isExpired) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (elapsedSeconds / slaTotalSeconds).clamp(0.0, 1.0),
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  remainingSeconds < 3600 ? Colors.redAccent : Colors.orange,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Policy & Guideline Text
          Text(
            isExpired
                ? "คำขอนี้เกินเวลา 24 ชั่วโมงแล้ว ตามนโยบายความเป็นธรรม ท่านสามารถดึงเงินคืนเข้าวอลเล็ทได้ทันที หรือติดต่อแอดมินเพื่อสอบถามข้อมูล"
                : "ท่านสามารถยกเลิกคำขอเพื่อรับเงินคืนเข้าวอลเล็ทได้ตลอดเวลา หรือสะกิดเตือนแอดมินหากต้องการเร่งด่วน",
            style: GoogleFonts.kanit(
              fontSize: 12,
              color: isExpired ? Colors.red[700] : Colors.grey[600],
              height: 1.35,
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons Row
          if (isExpired)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: widget.onClaimSla,
                    icon: const Icon(
                      CupertinoIcons.arrow_uturn_left_circle_fill,
                      size: 16,
                    ),
                    label: Text(
                      "ดึงเงินคืนทันที",
                      style: GoogleFonts.kanit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: widget.onContact,
                    icon: const Icon(CupertinoIcons.phone_fill, size: 14),
                    label: Text(
                      "สายด่วน",
                      style: GoogleFonts.kanit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(CupertinoIcons.clear_circled, size: 14),
                    label: Text(
                      "ยกเลิก",
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canNudge ? widget.onNudge : null,
                    icon: const Icon(CupertinoIcons.bell_fill, size: 14),
                    label: Text(
                      nudgeLabel,
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withValues(
                        alpha: 0.3,
                      ),
                      disabledForegroundColor: Colors.grey[500],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onContact,
                    icon: const Icon(CupertinoIcons.phone_fill, size: 14),
                    label: Text(
                      "สายด่วน",
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
