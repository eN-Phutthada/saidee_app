import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class ManageReportScreen extends StatelessWidget {
  const ManageReportScreen({super.key});

  void _banUser(String userId, BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.nosign,
                  color: Colors.red,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "ระงับบัญชี (Ban)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "คุณยืนยันที่จะแบนบัญชีนี้อย่างถาวรหรือไม่?\nการกระทำนี้จะถูกบันทึกลงระบบ",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "ยกเลิก",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        String currentAdminUid =
                            FirebaseAuth.instance.currentUser?.uid ??
                            'Unknown Admin';
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .update({
                              'status': 'banned',
                              'bannedAt': FieldValue.serverTimestamp(),
                              'bannedBy': currentAdminUid,
                            });
                        Get.back();
                        Get.snackbar(
                          "สำเร็จ",
                          "ระงับการใช้งานบัญชีเรียบร้อยแล้ว",
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "แบนทันที",
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
      ),
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
          "จัดการรายงานปัญหา",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          Map<String, List<Map<String, dynamic>>> groupedReports = {};
          Map<String, Set<String>> uniqueReporters = {};

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String reportedId = data['reported_id'] ?? 'unknown';
            String reporterId = data['reporter_id'] ?? 'unknown';

            if (groupedReports[reportedId] == null) {
              groupedReports[reportedId] = [];
              uniqueReporters[reportedId] = {};
            }
            groupedReports[reportedId]!.add(data);
            uniqueReporters[reportedId]!.add(reporterId);
          }

          if (groupedReports.isEmpty) {
            return Center(
              child: Text(
                "ไม่มีรายงานปัญหา",
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              top: 15,
              bottom: 40,
            ),
            itemCount: groupedReports.length,
            itemBuilder: (context, index) {
              String targetUserId = groupedReports.keys.elementAt(index);
              List<Map<String, dynamic>> reports =
                  groupedReports[targetUserId]!;
              int uniqueCount = uniqueReporters[targetUserId]!.length;
              bool isHighRisk = uniqueCount >= 3;

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: isHighRisk
                      ? Colors.red.withOpacity(isDark ? 0.2 : 0.05)
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: isHighRisk
                      ? Border.all(color: Colors.red.withOpacity(0.5))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isHighRisk
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: isHighRisk ? Colors.red : Colors.orange,
                      ),
                    ),
                    title: Text(
                      "ผู้ถูกรายงาน ID: $targetUserId",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isHighRisk
                            ? Colors.red
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "ถูกรายงาน $uniqueCount ครั้ง (จากผู้ใช้ไม่ซ้ำกัน)",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(15),
                          ),
                        ),
                        child: Column(
                          children: [
                            ...reports.map(
                              (report) => Padding(
                                padding: const EdgeInsets.only(bottom: 15.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.arrow_turn_down_right,
                                      color: Colors.grey,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "หัวข้อ: ${report['topic'] ?? '-'}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "ผู้แจ้ง: ${report['reporter_name'] ?? report['reporter_id']}",
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "รายละเอียด: ${report['detail']}",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                          if (report['image_proof'] != null &&
                                              report['image_proof'] != '')
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              height: 120,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                image: DecorationImage(
                                                  image: NetworkImage(
                                                    report['image_proof'],
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    _banUser(targetUserId, context),
                                icon: const Icon(
                                  CupertinoIcons.nosign,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  "ระงับบัญชีผู้ใช้นี้ถาวร",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
