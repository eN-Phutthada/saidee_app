import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class AdminTransactionScreen extends StatelessWidget {
  final bool isBottomNav;

  const AdminTransactionScreen({super.key, this.isBottomNav = false});

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

  bool _isIncomeToUser(String type) {
    List<String> incomeTypes = ['topup', 'income', 'sale', 'refund'];
    return incomeTypes.contains(type.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ประวัติธุรกรรมการเงิน",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: isBottomNav
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => Get.back(),
              ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final transactions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 40),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              var data = transactions[index].data() as Map<String, dynamic>;
              String uid = data['uid'] ?? data['member_id'] ?? '';
              String type = data['type'] ?? 'unknown';
              double amount = (data['amount'] ?? 0).toDouble();

              Timestamp? ts = data['createdAt'];
              DateTime date = ts?.toDate() ?? DateTime.now();
              String formattedDate =
                  "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

              bool isIncome = _isIncomeToUser(type);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get(),
                builder: (context, userSnapshot) {
                  String userName = "ไม่ทราบชื่อ (UID: $uid)";
                  String userImage = "";

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    userName = userData['name'] ?? userName;
                    userImage = userData['profileImage'] ?? "";
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(15),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              backgroundImage: userImage.isNotEmpty
                                  ? NetworkImage(userImage)
                                  : null,
                              child: userImage.isEmpty
                                  ? const Icon(
                                      CupertinoIcons.person_fill,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: theme.cardColor,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: isIncome
                                      ? Colors.green
                                      : Colors.red,
                                  child: Icon(
                                    isIncome
                                        ? CupertinoIcons.arrow_down_left
                                        : CupertinoIcons.arrow_up_right,
                                    size: 12,
                                    color: Colors.white,
                                  ),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getTransactionTypeName(type),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                              if (data['order_id'] != null)
                                Text(
                                  "Order: ${data['order_id']}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${isIncome ? '+' : '-'}${amount.toStringAsFixed(2)} ฿",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isIncome ? Colors.green : Colors.red,
                                fontFamily: 'Kanit',
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (data['status'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: data['status'] == 'success'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  data['status'] == 'success'
                                      ? "สำเร็จ"
                                      : "รอดำเนินการ",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: data['status'] == 'success'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
