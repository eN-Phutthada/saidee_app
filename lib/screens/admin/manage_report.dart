import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/models/report_model.dart';
import 'package:saidee_app/screens/admin/admin_user_detail_screen.dart';
import 'package:saidee_app/services/moderation_service.dart';
import 'package:saidee_app/services/notification_service.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class ManageReportScreen extends StatefulWidget {
  const ManageReportScreen({super.key});

  @override
  State<ManageReportScreen> createState() => _ManageReportScreenState();
}

class _ManageReportScreenState extends State<ManageReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTypeFilter = 'all';

  final List<Map<String, String>> _typeFilters = [
    {'key': 'all', 'label': 'ทั้งหมด'},
    {'key': 'product', 'label': '🛍️ สินค้า'},
    {'key': 'store', 'label': '🏪 ร้านค้า'},
    {'key': 'chat', 'label': '💬 แชท'},
    {'key': 'order', 'label': '📦 คำสั่งซื้อ'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentAdminUid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'Admin';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "ศูนย์จัดการรายงาน & การกำกับดูแล",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "รอตรวจสอบ"),
            Tab(text: "กำลังตรวจ"),
            Tab(text: "ดำเนินการแล้ว"),
            Tab(text: "ปฏิเสธ/ยกเลิก"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.reports)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(theme, "ยังไม่มีรายการรายงานปัญหาในระบบ");
          }

          final allReports = snapshot.data!.docs.map((doc) {
            return ReportModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          return Column(
            children: [
              _buildFilterChips(isDark),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportList(
                      _filterReports(allReports, 'pending'),
                      theme,
                      isDark,
                    ),
                    _buildReportList(
                      _filterReports(allReports, 'in_review'),
                      theme,
                      isDark,
                    ),
                    _buildReportList(
                      _filterReports(allReports, 'resolved'),
                      theme,
                      isDark,
                    ),
                    _buildReportList(
                      _filterReports(allReports, 'dismissed'),
                      theme,
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _typeFilters.map((filter) {
            final isSelected = _selectedTypeFilter == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTypeFilter = filter['key']!);
                  }
                },
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<ReportModel> _filterReports(List<ReportModel> reports, String tab) {
    return reports.where((r) {
      bool matchesTab = false;
      if (tab == 'pending') {
        matchesTab = (r.status == 'pending');
      } else if (tab == 'in_review') {
        matchesTab = (r.status == 'in_review');
      } else if (tab == 'resolved') {
        matchesTab = r.status.startsWith('resolved');
      } else if (tab == 'dismissed') {
        matchesTab = (r.status == 'dismissed');
      }

      bool matchesType = _selectedTypeFilter == 'all' ||
          r.targetType == _selectedTypeFilter;

      return matchesTab && matchesType;
    }).toList();
  }

  Widget _buildReportList(
    List<ReportModel> reports,
    ThemeData theme,
    bool isDark,
  ) {
    if (reports.isEmpty) {
      return _buildEmptyState(theme, "ไม่มีรายการรายงานในหมวดนี้");
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return _buildReportCard(context, reports[index], theme, isDark);
      },
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ReportModel report,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Target Type & Status
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTargetTypeBadge(report.targetType),
                Row(
                  children: [
                    _buildStatusBadge(report.status),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(report.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category / Reason Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.category,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (report.targetTitle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.targetTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Detail
                Text(
                  report.detail.isNotEmpty ? report.detail : "ไม่มีรายละเอียดเพิ่มเติม",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                    height: 1.4,
                  ),
                ),

                // Evidence images preview
                if (report.evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.evidenceUrls.length,
                      itemBuilder: (context, imgIndex) {
                        final imgUrl = report.evidenceUrls[imgIndex];
                        return GestureDetector(
                          onTap: () => Get.to(() => _FullScreenImage(url: imgUrl)),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              image: DecorationImage(
                                image: NetworkImage(imgUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                // Reporter Information
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "ผู้แจ้ง: ${report.reporterName.isNotEmpty ? report.reporterName : report.reporterId}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                // Reported User Information & Moderation Actions
                _buildReportedUserSection(context, report, theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportedUserSection(
    BuildContext context,
    ReportModel report,
    ThemeData theme,
    bool isDark,
  ) {
    if (report.reportedUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(report.reportedUserId)
          .get(),
      builder: (context, snapshot) {
        String userName = "กำลังโหลด...";
        String userStatus = "active";
        String profileImg = "";
        int strikeCount = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          userName = data['name'] ?? report.reportedUserId;
          userStatus = data['status'] ?? 'active';
          profileImg = data['profileImage'] ?? '';
          strikeCount = (data['strikeCount'] ?? 0) as int;
        }

        bool isBanned = userStatus == 'banned' || userStatus == 'suspended';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                  child: profileImg.isEmpty
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            isBanned ? "สถานะ: ถูกระงับ" : "สถานะ: ปกติ",
                            style: TextStyle(
                              fontSize: 11,
                              color: isBanned ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (strikeCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "เตือนแล้ว $strikeCount ครั้ง",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      Get.to(() => AdminUserDetailScreen(
                            userId: report.reportedUserId,
                            userData: snapshot.data!.data()
                                as Map<String, dynamic>,
                          ));
                    }
                  },
                  child: const Text(
                    "ดูโปรไฟล์",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Moderation Action Buttons
            _buildActionButtonsRow(context, report, userStatus, isBanned),
          ],
        );
      },
    );
  }

  Widget _buildActionButtonsRow(
    BuildContext context,
    ReportModel report,
    String userStatus,
    bool isBanned,
  ) {
    bool isResolved = report.status.startsWith('resolved') ||
        report.status == 'dismissed';

    return Column(
      children: [
        Row(
          children: [
            if (report.status == 'pending') ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateReportStatus(report.id, 'in_review'),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text("เริ่มตรวจ"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _showModerationActionSheet(
                  context,
                  report,
                  isBanned,
                ),
                icon: const Icon(Icons.gavel_rounded, size: 16),
                label: Text(
                  isResolved ? "ทบทวนการตัดสิน" : "ดำเนินการตัดสิน / ลงโทษ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Order Dispute specific actions
        if (report.targetType == 'order' && !isResolved) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _resolveDisputeRefund(context, report),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "คืนเงินผู้ซื้อ",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _resolveDisputeRelease(context, report),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "โอนเงินให้ผู้ขาย",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showModerationActionSheet(
    BuildContext context,
    ReportModel report,
    bool isBanned,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      "มาตรการกำกับดูแล & การลงโทษ",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. ส่งหนังสือเตือน
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  ),
                  title: const Text("ส่งหนังสือเตือน (Official Warning)"),
                  subtitle: const Text("ตักเตือนผู้ใช้ บันทึก Strike และส่งแจ้งเตือน"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptWarningDialog(context, report);
                  },
                ),

                // 2. ระงับบัญชี (ชั่วคราว / ถาวร)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBanned ? Icons.lock_open : Icons.block,
                      color: isBanned ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(isBanned ? "ปลดระงับการใช้งานบัญชี" : "ระงับการใช้งานบัญชี (Ban)"),
                  subtitle: Text(
                    isBanned
                        ? "คืนสิทธิ์การเข้าใช้งานและกู้คืนสินค้า"
                        : "เลือกแบนชั่วคราว (1, 3, 7, 14, 30 วัน) หรือแบนถาวร",
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isBanned) {
                      _confirmUnban(context, report);
                    } else {
                      _promptBanDialog(context, report);
                    }
                  },
                ),

                // 3. ซ่อนสินค้าที่ละเมิดกฎ (ถ้าเป็นสินค้า)
                if (report.targetType == 'product')
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.visibility_off, color: Colors.orange),
                    ),
                    title: const Text("ระงับการแสดงผลสินค้านี้"),
                    subtitle: const Text("ซ่อนสินค้าออกจากระบบโดยไม่แบนบัญชี"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _promptHideProductDialog(context, report);
                    },
                  ),

                // 4. ปฏิเสธรายงาน / ไม่พบความผิด
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                  title: const Text("ปฏิเสธรายงาน / ไม่พบความผิด"),
                  subtitle: const Text("ปิดรายงานโดยไม่มีการลงโทษ"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptDismissDialog(context, report);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _promptWarningDialog(BuildContext context, ReportModel report) {
    final reasonController = TextEditingController(
      text: "ตรวจพบพฤติกรรมที่ไม่เหมาะสมตามรายงาน: ${report.category}",
    );

    AppDialog.showCustomDialog(
      title: "ส่งหนังสือแจ้งเตือน",
      message: "ผู้ใช้จะได้รับการแจ้งเตือนและบันทึกประวัติการถูกเตือน (Strike) ในระบบ",
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "เหตุผลการเตือน",
            border: OutlineInputBorder(),
          ),
        ),
      ),
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.amber,
      confirmText: "ส่งการแจ้งเตือน",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        final success = await ModerationService.sendWarning(
          userId: report.reportedUserId,
          reason: reasonController.text.trim(),
          adminUid: _currentAdminUid,
        );

        if (success) {
          await _updateReportStatus(
            report.id,
            'resolved',
            actionTaken: 'warning',
            adminNote: reasonController.text.trim(),
          );
          Get.snackbar("สำเร็จ", "ส่งหนังสือเตือนเรียบร้อยแล้ว",
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          Get.snackbar("ข้อผิดพลาด", "ไม่สามารถส่งหนังสือเตือนได้",
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }

  void _promptBanDialog(BuildContext context, ReportModel report) {
    int selectedDays = 7; // ค่าเริ่มต้น 7 วัน
    bool isPermanent = false;
    final reasonController = TextEditingController(
      text: "ละเมิดกฎระเบียบของแพลตฟอร์ม: ${report.category}",
    );

    Get.dialog(
      StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 8),
                Text("ระงับการใช้งานบัญชี", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("เลือกระยะเวลาการระงับ:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [1, 3, 7, 14, 30].map((days) {
                      final selected = !isPermanent && selectedDays == days;
                      return ChoiceChip(
                        label: Text("$days วัน"),
                        selected: selected,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              selectedDays = days;
                              isPermanent = false;
                            });
                          }
                        },
                      );
                    }).toList()
                      ..add(
                        ChoiceChip(
                          label: const Text("ถาวร (Permanent)"),
                          selected: isPermanent,
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                isPermanent = true;
                              });
                            }
                          },
                        ),
                      ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "เหตุผลในการระงับ",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("ยกเลิก"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Get.back();
                  Duration? duration = isPermanent ? null : Duration(days: selectedDays);
                  final success = await ModerationService.banUser(
                    userId: report.reportedUserId,
                    reason: reasonController.text.trim(),
                    duration: duration,
                    adminUid: _currentAdminUid,
                  );

                  if (success) {
                    await _updateReportStatus(
                      report.id,
                      'resolved',
                      actionTaken: isPermanent ? 'perm_ban' : 'temp_ban',
                      adminNote: reasonController.text.trim(),
                    );
                    Get.snackbar(
                      "สำเร็จ",
                      isPermanent
                          ? "ระงับบัญชีผู้ใช้ถาวรเรียบร้อยแล้ว"
                          : "ระงับบัญชีผู้ใช้เป็นเวลา $selectedDays วันเรียบร้อยแล้ว",
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                    );
                  } else {
                    Get.snackbar("ข้อผิดพลาด", "ไม่สามารถระงับบัญชีได้",
                        backgroundColor: Colors.red, colorText: Colors.white);
                  }
                },
                child: const Text("ยืนยันระงับบัญชี"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmUnban(BuildContext context, ReportModel report) {
    AppDialog.showCustomDialog(
      title: "ปลดระงับการใช้งาน",
      message: "ผู้ใช้จะสามารถเข้าสู่ระบบและสินค้าที่ถูกระงับจะกลับมาแสดงผลตามปกติ",
      icon: Icons.lock_open,
      iconColor: Colors.green,
      confirmText: "ปลดระงับ",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        final success = await ModerationService.unbanUser(
          userId: report.reportedUserId,
          adminUid: _currentAdminUid,
        );

        if (success) {
          await _updateReportStatus(
            report.id,
            'resolved',
            actionTaken: 'unbanned',
            adminNote: 'ปลดระงับบัญชีผู้ใช้',
          );
          Get.snackbar("สำเร็จ", "ปลดระงับบัญชีเรียบร้อยแล้ว",
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          Get.snackbar("ข้อผิดพลาด", "ไม่สามารถปลดระงับบัญชีได้",
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }

  void _promptHideProductDialog(BuildContext context, ReportModel report) {
    final reasonController = TextEditingController(
      text: "สินค้าละเมิดข้อกำหนด: ${report.category}",
    );

    AppDialog.showCustomDialog(
      title: "ระงับการแสดงผลสินค้า",
      message: "สินค้านี้จะถูกซ่อนออกจากหน้าหลักและการค้นหาทันที",
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "เหตุผลการระงับสินค้า",
            border: OutlineInputBorder(),
          ),
        ),
      ),
      icon: Icons.visibility_off,
      iconColor: Colors.orange,
      confirmText: "ระงับสินค้านี้",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        final success = await ModerationService.hideProduct(
          productId: report.targetId,
          reason: reasonController.text.trim(),
          adminUid: _currentAdminUid,
        );

        if (success) {
          await _updateReportStatus(
            report.id,
            'resolved',
            actionTaken: 'hide_product',
            adminNote: reasonController.text.trim(),
          );
          Get.snackbar("สำเร็จ", "ระงับการแสดงผลสินค้าเรียบร้อยแล้ว",
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          Get.snackbar("ข้อผิดพลาด", "ไม่สามารถระงับสินค้าได้",
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }

  void _promptDismissDialog(BuildContext context, ReportModel report) {
    final reasonController = TextEditingController(
      text: "ตรวจสอบแล้วไม่พบการกระทำความผิด หรือหลักฐานไม่เพียงพอ",
    );

    AppDialog.showCustomDialog(
      title: "ปฏิเสธรายงาน",
      message: "ปิดรายงานนี้โดยไม่ดำเนินการลงโทษต่อผู้ใช้",
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "หมายเหตุสำหรับแอดมิน",
            border: OutlineInputBorder(),
          ),
        ),
      ),
      icon: Icons.cancel_outlined,
      iconColor: Colors.grey,
      confirmText: "ยืนยันปิดรายงาน",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        await _updateReportStatus(
          report.id,
          'dismissed',
          actionTaken: 'dismissed',
          adminNote: reasonController.text.trim(),
        );
        Get.snackbar("สำเร็จ", "ปิดรายงานเรียบร้อยแล้ว",
            backgroundColor: Colors.grey, colorText: Colors.white);
      },
    );
  }

  Future<void> _updateReportStatus(
    String reportId,
    String status, {
    String actionTaken = 'none',
    String adminNote = '',
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .doc(reportId)
          .update({
        'status': status,
        'actionTaken': actionTaken,
        'adminNote': adminNote,
        'resolvedBy': _currentAdminUid,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating report status: $e");
    }
  }

  void _resolveDisputeRefund(
    BuildContext context,
    ReportModel report,
  ) async {
    String orderId = report.targetId;
    String buyerId = report.reporterId;
    if (orderId.isEmpty || buyerId.isEmpty) return;

    AppDialog.showCustomDialog(
      title: "ยืนยันการคืนเงินให้ผู้ซื้อ",
      message: "ระบบจะทำรายการยกเลิกออเดอร์และโอนเงินคืนเข้าวอลเล็ทของผู้ซื้อทันที",
      icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
      iconColor: Colors.orange,
      confirmText: "อนุมัติคืนเงิน",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        try {
          var orderDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.orders)
              .doc(orderId)
              .get();
          if (!orderDoc.exists) throw Exception("ไม่พบข้อมูลออเดอร์");
          double total = (orderDoc.data()!['total'] ?? 0).toDouble();

          WriteBatch batch = FirebaseFirestore.instance.batch();

          DocumentReference orderRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.orders)
              .doc(orderId);
          batch.update(orderRef, {
            'status': 'cancelled',
            'escrowStatus': 'refunded',
            'note': 'แอดมินตัดสินข้อพิพาท: คืนเงินให้ผู้ซื้อ',
            'resolvedAt': FieldValue.serverTimestamp(),
          });

          DocumentReference userRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(buyerId);
          batch.update(userRef, {'walletBalance': FieldValue.increment(total)});

          DocumentReference txRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.transactions)
              .doc();
          batch.set(txRef, {
            'uid': buyerId,
            'type': 'refund',
            'amount': total,
            'order_id': orderId,
            'status': 'success',
            'createdAt': FieldValue.serverTimestamp(),
          });

          DocumentReference reportRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.reports)
              .doc(report.id);
          batch.update(reportRef, {
            'status': 'resolved_refund',
            'actionTaken': 'refund',
            'resolvedBy': _currentAdminUid,
            'resolvedAt': FieldValue.serverTimestamp(),
          });

          await batch.commit();

          NotificationService.sendNotification(
            userId: buyerId,
            title: "อนุมัติคืนเงินข้อพิพาท 💰",
            body:
                "ข้อพิพาทคำสั่งซื้อได้รับการอนุมัติ คืนเงิน ${total.toStringAsFixed(2)} ฿ เข้า SAIDEE Wallet เรียบร้อยแล้ว",
            type: 'wallet',
            orderId: orderId,
          );

          NotificationService.sendNotification(
            userId: report.reportedUserId,
            title: "แจ้งผลการตัดสินข้อพิพาท ℹ️",
            body: "ข้อพิพาทคำสั่งซื้อได้รับการตัดสินแล้ว (อนุมัติคืนเงินให้ผู้ซื้อ)",
            type: 'dispute',
            orderId: orderId,
          );

          Get.snackbar("สำเร็จ", "อนุมัติคืนเงินผู้ซื้อเรียบร้อยแล้ว",
              backgroundColor: Colors.green, colorText: Colors.white);
        } catch (e) {
          Get.snackbar("เกิดข้อผิดพลาด", e.toString(),
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }

  void _resolveDisputeRelease(
    BuildContext context,
    ReportModel report,
  ) async {
    String orderId = report.targetId;
    String sellerId = report.reportedUserId;
    if (orderId.isEmpty || sellerId.isEmpty) return;

    AppDialog.showCustomDialog(
      title: "ยืนยันการโอนเงินให้ผู้ขาย",
      message: "ระบบจะทำรายการอนุมัติออเดอร์และโอนเงินเข้าวอลเล็ทของผู้ขายทันที",
      icon: CupertinoIcons.money_dollar_circle_fill,
      iconColor: Colors.green,
      confirmText: "อนุมัติปล่อยเงิน",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        try {
          var orderDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.orders)
              .doc(orderId)
              .get();
          if (!orderDoc.exists) throw Exception("ไม่พบข้อมูลออเดอร์");
          double total = (orderDoc.data()!['total'] ?? 0).toDouble();

          WriteBatch batch = FirebaseFirestore.instance.batch();

          DocumentReference orderRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.orders)
              .doc(orderId);
          batch.update(orderRef, {
            'status': 'completed',
            'escrowStatus': 'released',
            'escrowReleasedAt': FieldValue.serverTimestamp(),
            'note': 'แอดมินตัดสินข้อพิพาท: โอนเงินให้ผู้ขาย',
            'resolvedAt': FieldValue.serverTimestamp(),
          });

          DocumentReference sellerRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(sellerId);
          batch.update(sellerRef, {
            'walletBalance': FieldValue.increment(total),
          });

          DocumentReference txRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.transactions)
              .doc();
          batch.set(txRef, {
            'uid': sellerId,
            'type': 'income',
            'amount': total,
            'order_id': orderId,
            'status': 'success',
            'createdAt': FieldValue.serverTimestamp(),
          });

          DocumentReference reportRef = FirebaseFirestore.instance
              .collection(FirestoreCollections.reports)
              .doc(report.id);
          batch.update(reportRef, {
            'status': 'resolved_payout',
            'actionTaken': 'payout',
            'resolvedBy': _currentAdminUid,
            'resolvedAt': FieldValue.serverTimestamp(),
          });

          await batch.commit();

          NotificationService.sendNotification(
            userId: sellerId,
            title: "อนุมัติโอนเงินข้อพิพาท 💰",
            body:
                "ข้อพิพาทได้รับการอนุมัติ โอนเงิน ${total.toStringAsFixed(2)} ฿ เข้า SAIDEE Wallet เรียบร้อยแล้ว",
            type: 'wallet',
            orderId: orderId,
          );

          NotificationService.sendNotification(
            userId: report.reporterId,
            title: "แจ้งผลการตัดสินข้อพิพาท ℹ️",
            body: "ข้อพิพาทคำสั่งซื้อได้รับการตัดสินแล้ว (อนุมัติปล่อยเงินให้ผู้ขาย)",
            type: 'dispute',
            orderId: orderId,
          );

          Get.snackbar("สำเร็จ", "อนุมัติโอนเงินให้ผู้ขายเรียบร้อยแล้ว",
              backgroundColor: Colors.green, colorText: Colors.white);
        } catch (e) {
          Get.snackbar("เกิดข้อผิดพลาด", e.toString(),
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }

  Widget _buildTargetTypeBadge(String targetType) {
    String label = "ทั่วไป";
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;

    switch (targetType) {
      case 'product':
        label = "สินค้า";
        icon = Icons.shopping_bag_outlined;
        color = Colors.teal;
        break;
      case 'store':
        label = "ร้านค้า";
        icon = Icons.storefront_outlined;
        color = Colors.purple;
        break;
      case 'chat':
        label = "แชท";
        icon = Icons.chat_bubble_outline;
        color = Colors.indigo;
        break;
      case 'order':
        label = "คำสั่งซื้อ";
        icon = Icons.local_shipping_outlined;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label = "รอตรวจสอบ";
    Color color = Colors.orange;

    if (status == 'in_review') {
      label = "กำลังตรวจ";
      color = Colors.blue;
    } else if (status.startsWith('resolved')) {
      label = "ดำเนินการแล้ว";
      color = Colors.green;
    } else if (status == 'dismissed') {
      label = "ยกเลิก/ปฏิเสธ";
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
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

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.shield_fill, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    DateTime d = (ts as Timestamp).toDate();
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
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
