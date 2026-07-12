import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.white,
                  child: const Center(
                    child: Text("ไม่สามารถโหลดรูปภาพได้"),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white, size: 30),
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
        title: const Text('ประวัติธุรกรรม', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("กรุณาเข้าสู่ระบบ"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
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
                        Icon(CupertinoIcons.doc_text_search, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 15),
                        Text(
                          "ยังไม่มีประวัติธุรกรรม",
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
                    var data = docs[index].data() as Map<String, dynamic>;
                    String type = (data['type'] ?? 'unknown').toLowerCase();
                    double amount = (data['amount'] ?? 0).toDouble();
                    String status = data['status'] ?? 'pending';
                    String? slipUrl = data['slipUrl'];
                    String? note = data['note'];
                    Timestamp? ts = data['createdAt'];
                    DateTime date = ts?.toDate() ?? DateTime.now();
                    String formattedDate =
                        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

                    bool isAppIn = _isAppIncome(type);

                    return GestureDetector(
                      onTap: slipUrl != null ? () => _showSlipDialog(context, slipUrl) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAppIn
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAppIn ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right,
                                color: isAppIn ? Colors.green : Colors.red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _getTransactionTypeName(type),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      if (slipUrl != null) ...[
                                        const SizedBox(width: 5),
                                        const Icon(CupertinoIcons.photo, size: 14, color: AppTheme.primaryColor),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                  if (note != null && note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      "หมายเหตุ: $note",
                                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                                    ),
                                  ]
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
                                    color: isAppIn ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _buildStatusBadge(status),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
