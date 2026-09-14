import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/config/firestore_collections.dart';

class WalletHistoryScreen extends StatelessWidget {
  const WalletHistoryScreen({super.key});

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
        style: TextStyle(
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
                  child: const Center(child: Text("ไม่สามารถโหลดรูปภาพได้")),
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
        title: const Text(
          'ประวัติธุรกรรม',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("กรุณาเข้าสู่ระบบ"))
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
                    child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"),
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
                          style: TextStyle(
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
                    final durationWaited = DateTime.now().difference(date);
                    final hoursWaited = durationWaited.inHours;
                    final minutesWaited = durationWaited.inMinutes;
                    final isSlaExpired = hoursWaited >= 24;

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
                                      color:
                                          isAppIn ? Colors.green : Colors.red,
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
                                              style: const TextStyle(
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
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (note != null && note.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "หมายเหตุ: $note",
                                            style: TextStyle(
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
                                        style: TextStyle(
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

                          // Interactive Action Box for Pending Withdrawals
                          if (isPendingWithdrawal) ...[
                            const Divider(height: 1),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? (isSlaExpired
                                        ? Colors.red.withValues(alpha: 0.08)
                                        : Colors.orange.withValues(alpha: 0.05))
                                    : (isSlaExpired
                                        ? Colors.red.shade50
                                        : Colors.amber.shade50.withValues(
                                            alpha: 0.6,
                                          )),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isSlaExpired
                                            ? CupertinoIcons
                                                .exclamationmark_triangle_fill
                                            : CupertinoIcons.clock,
                                        size: 15,
                                        color: isSlaExpired
                                            ? Colors.red
                                            : Colors.orange[800],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isSlaExpired
                                              ? "เกินเวลา 24 ชม. แล้ว สามารถขอเงินคืนเข้ากระเป๋าได้ทันที"
                                              : "รอมาแล้ว ${hoursWaited > 0 ? '$hoursWaited ชม.' : '$minutesWaited นาที'} (รับประกันโอนใน 24 ชม.)",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSlaExpired
                                                ? Colors.red[700]
                                                : Colors.orange[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      // Cancel withdrawal button (Available anytime while pending)
                                      OutlinedButton.icon(
                                        onPressed: () => _cancelWithdrawal(
                                          context,
                                          docId,
                                          amount,
                                          uid,
                                        ),
                                        icon: const Icon(
                                          CupertinoIcons.clear_circled,
                                          size: 14,
                                        ),
                                        label: const Text("ยกเลิกคำขอ"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      // Nudge admin button (Remind)
                                      OutlinedButton.icon(
                                        onPressed: () => _nudgeAdmin(
                                          context,
                                          docId,
                                          lastNudgedAt,
                                          amount,
                                        ),
                                        icon: const Icon(
                                          CupertinoIcons.bell_fill,
                                          size: 14,
                                        ),
                                        label: const Text("สะกิดแอดมิน"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange[800],
                                          side: BorderSide(
                                            color: Colors.orange[800]!,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      // Contact support & phone
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showContactAdminDialog(
                                              context,
                                              docId,
                                              amount,
                                            ),
                                        icon: const Icon(
                                          CupertinoIcons.phone_fill,
                                          size: 14,
                                        ),
                                        label: const Text("ติดต่อแอดมิน"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      // Claim refund button if SLA expired
                                      if (isSlaExpired)
                                        ElevatedButton.icon(
                                          onPressed: () => _claimRefundSla(
                                            context,
                                            docId,
                                            amount,
                                            uid,
                                          ),
                                          icon: const Icon(
                                            CupertinoIcons.arrow_uturn_left,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            "ขอเงินคืนทันที (SLA)",
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
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
        title: const Text("ยืนยันยกเลิกการถอนเงิน"),
        content: Text(
          "คุณต้องการยกเลิกคำขอถอนเงินจำนวน ฿${amount.toStringAsFixed(2)} ใช่หรือไม่?\n\nยอดเงินจะถูกโอนกลับเข้าวอลเล็ทของคุณทันที",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              "ไม่ยกเลิก",
              style: TextStyle(color: Colors.grey),
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
                  if ((txSnap.data()
                          as Map<String, dynamic>)['status'] !=
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
                    'note': 'ผู้ใช้กดยกเลิกคำขอถอนเงิน (คืนเงินเข้าวอลเล็ทแล้ว)',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "ยืนยันยกเลิก",
              style: TextStyle(
                color: Colors.white,
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
        title: const Text("ขอรับเงินคืนทันที (SLA เกิน 24 ชม.)"),
        content: Text(
          "คำขอถอนเงินนี้เกินระยะเวลาดำเนินการ 24 ชั่วโมงแล้ว ตามนโยบายความเป็นธรรม คุณสามารถดึงเงิน ฿${amount.toStringAsFixed(2)} กลับเข้าวอลเล็ทได้ทันที",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              "รอต่ออีกสักนิด",
              style: TextStyle(color: Colors.grey),
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
                  if ((txSnap.data()
                          as Map<String, dynamic>)['status'] !=
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "ดึงเงินคืนเข้าวอลเล็ท",
              style: TextStyle(
                color: Colors.white,
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
                      const Text(
                        "ติดต่อฝ่ายบริการลูกค้า / แอดมิน",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "เวลาทำการ: 08:00 - 22:00 น. (ทุกวัน)",
                        style: TextStyle(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "เบอร์โทรสายด่วนแอดมิน",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            adminPhone,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
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
                        label: const Text("คัดลอกเบอร์"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              docId,
                              style: const TextStyle(
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
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                child: const Text("ปิดหน้านี้"),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
