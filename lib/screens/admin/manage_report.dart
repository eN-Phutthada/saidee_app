import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class ManageReportScreen extends StatelessWidget {
  const ManageReportScreen({super.key});

  void _updateUserStatus(String userId, String currentStatus) {
    bool isBanning = currentStatus != 'banned';

    AppDialog.showCustomDialog(
      title: isBanning ? "ระงับบัญชีสมาชิก" : "คืนสถานะบัญชี",
      message: isBanning
          ? "คุณต้องการระงับการใช้งานบัญชีนี้ใช่หรือไม่?\nผู้ใช้จะถูกออกจากระบบและเข้าใช้งานไม่ได้ทันที"
          : "คุณต้องการปลดการระงับและคืนสิทธิ์การใช้งานให้สมาชิกรายนี้ใช่หรือไม่?",
      icon: isBanning
          ? CupertinoIcons.lock_shield_fill
          : CupertinoIcons.shield_slash_fill,
      iconColor: isBanning ? Colors.red : Colors.green,
      confirmText: isBanning ? "ระงับบัญชี" : "คืนสถานะปกติ",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: isBanning,
      onConfirm: () async {
        String adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'Admin';
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
                'status': isBanning ? 'banned' : 'active',
                'moderated_at': FieldValue.serverTimestamp(),
                'moderated_by': adminUid,
              });
          Get.back();
          Get.snackbar(
            "ดำเนินการสำเร็จ",
            isBanning ? "ระงับบัญชีแล้ว" : "ปลดระงับบัญชีแล้ว",
            backgroundColor: isBanning ? Colors.orange : Colors.green,
            colorText: Colors.white,
            icon: Icon(
              isBanning ? Icons.lock : Icons.lock_open,
              color: Colors.white,
            ),
          );
        } catch (e) {
          Get.snackbar("Error", "ไม่สามารถดำเนินการได้: $e");
        }
      },
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
          "ศูนย์จัดการรายงาน",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

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
            groupedReports[reportedId]!.add({'id': doc.id, ...data});
            uniqueReporters[reportedId]!.add(reporterId);
          }

          if (groupedReports.isEmpty) {
            return _buildEmptyState(theme);
          }

          return Column(
            children: [
              _buildSummaryHeader(
                groupedReports.length,
                uniqueReporters,
                isDark,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  itemCount: groupedReports.length,
                  itemBuilder: (context, index) {
                    String targetUserId = groupedReports.keys.elementAt(index);
                    List<Map<String, dynamic>> reports =
                        groupedReports[targetUserId]!;
                    int uniqueCount = uniqueReporters[targetUserId]!.length;
                    bool isUrgent = uniqueCount >= 3;

                    return _buildReportCard(
                      context,
                      targetUserId,
                      reports,
                      uniqueCount,
                      isUrgent,
                      theme,
                      isDark,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(int totalCases, Map uniqueMap, bool isDark) {
    int totalReports = 0;
    uniqueMap.forEach((key, value) => totalReports += (value as Set).length);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildHeaderItem(
            "ยูสเซอร์ที่ถูกร้องเรียน",
            totalCases.toString(),
            Colors.orange,
          ),
          const SizedBox(width: 15),
          _buildHeaderItem(
            "จำนวนการแจ้งทั้งหมด",
            totalReports.toString(),
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderItem(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    String userId,
    List reports,
    int count,
    bool isUrgent,
    ThemeData theme,
    bool isDark,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnap) {
        String status = 'active';
        String name = "กำลังโหลด...";
        String img = "";

        if (userSnap.hasData && userSnap.data!.exists) {
          var d = userSnap.data!.data() as Map<String, dynamic>;
          status = d['status'] ?? 'active';
          name = d['name'] ?? userId;
          img = d['profileImage'] ?? "";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: isUrgent
                ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                    child: img.isEmpty
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  if (isUrgent)
                    const CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Icon(
                        Icons.priority_high,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'banned'
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      status == 'banned' ? "ถูกระงับ" : "ปกติ",
                      style: TextStyle(
                        color: status == 'banned' ? Colors.red : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "แจ้ง $count ครั้ง",
                    style: TextStyle(
                      color: isUrgent ? Colors.red : Colors.grey,
                      fontSize: 11,
                      fontWeight: isUrgent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black12 : Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "รายละเอียดการรายงาน:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...reports.map((r) => _buildDetailItem(r, isDark)),
                      const SizedBox(height: 10),
                      _buildActionButtons(userId, status, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(Map<String, dynamic> report, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report['topic'] ?? "ไม่ระบุหัวข้อ",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                _formatDate(report['createdAt']),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            report['detail'] ?? "-",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          if (report['image_proof'] != null && report['image_proof'] != '')
            GestureDetector(
              onTap: () =>
                  Get.to(() => _FullScreenImage(url: report['image_proof'])),
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(report['image_proof']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String userId, String status, ThemeData theme) {
    bool isBanned = status == 'banned';
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBanned ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _updateUserStatus(userId, status),
            icon: Icon(
              isBanned ? Icons.lock_open : Icons.lock_person,
              size: 18,
            ),
            label: Text(isBanned ? "ปลดระงับการใช้งาน" : "ระงับบัญชีทันที"),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.shield_fill, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "ยินดีด้วย! ยังไม่มีรายงานปัญหา",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    DateTime d = (ts as Timestamp).toDate();
    return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute}";
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}
