import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:saidee_app/config/firestore_collections.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/models/order_model.dart';
import 'package:saidee_app/models/product_model.dart';
import 'package:saidee_app/screens/admin/manage_report.dart';
import 'package:saidee_app/services/role_guard_service.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';
import 'package:saidee_app/widgets/permission_denied_view.dart';

class AdminStoreViewScreen extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic>? sellerData;

  const AdminStoreViewScreen({
    super.key,
    required this.sellerId,
    this.sellerData,
  });

  @override
  State<AdminStoreViewScreen> createState() => _AdminStoreViewScreenState();
}

class _AdminStoreViewScreenState extends State<AdminStoreViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat("#,##0.00", "th_TH");

  String _productFilter =
      'all';

  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFirebaseInitialized) {
        RoleGuardService.checkAdminAccess(context);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.rawSnackbar(
      messageText: Text(
        "คัดลอก $label เรียบร้อยแล้ว",
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      backgroundColor: Colors.black87,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 10,
      icon: const Icon(
        CupertinoIcons.checkmark_circle_fill,
        color: Colors.greenAccent,
      ),
    );
  }

  Future<void> _toggleProductStatus(ProductModel product) async {
    final isSuspended = product.status == 'suspended';
    final targetStatus = isSuspended ? 'active' : 'suspended';
    final actionText = isSuspended
        ? 'เปิดขายสินค้าอีกครั้ง'
        : 'ระงับการขายสินค้านี้';

    AppDialog.showCustomDialog(
      title: actionText,
      message: isSuspended
          ? "คุณต้องการเปิดขายสินค้า '${product.name}' อีกครั้งใช่หรือไม่?"
          : "คุณต้องการระงับการขายสินค้า '${product.name}' ชั่วคราวใช่หรือไม่?",
      icon: isSuspended
          ? CupertinoIcons.checkmark_shield_fill
          : CupertinoIcons.nosign,
      iconColor: isSuspended ? Colors.green : Colors.orange,
      confirmText: isSuspended ? "เปิดใช้งาน" : "ระงับสินค้า",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.products)
              .doc(product.id)
              .update({
                'status': targetStatus,
                'updatedAt': FieldValue.serverTimestamp(),
              });

          Get.snackbar(
            "สำเร็จ",
            "อัปเดตสถานะสินค้าเรียบร้อยแล้ว",
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        } catch (e) {
          Get.snackbar(
            "เกิดข้อผิดพลาด",
            "ไม่สามารถอัปเดตสถานะสินค้าได้: $e",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        }
      },
    );
  }

  void _showBanStoreDialog(Map<String, dynamic> seller) {
    final reasonController = TextEditingController();
    int banDays = 7;
    bool isPermanent = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(
                  CupertinoIcons.exclamationmark_octagon_fill,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  "ระงับบัญชีร้านค้า",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ร้านค้า: ${seller['name'] ?? 'ไม่มีชื่อ'}"),
                  const SizedBox(height: 12),
                  const Text(
                    "ระยะเวลาการระงับ:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text("3 วัน"),
                        selected: banDays == 3 && !isPermanent,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              banDays = 3;
                              isPermanent = false;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text("7 วัน"),
                        selected: banDays == 7 && !isPermanent,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              banDays = 7;
                              isPermanent = false;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text("30 วัน"),
                        selected: banDays == 30 && !isPermanent,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              banDays = 30;
                              isPermanent = false;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text("ถาวร"),
                        selected: isPermanent,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              isPermanent = true;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "เหตุผลการระงับ:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          "ระบุเหตุผล เช่น ส่งสินค้าไม่ตรงปก, ทำผิดกฎระเบียบ",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
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
                  if (reasonController.text.trim().isEmpty) {
                    Get.snackbar(
                      "แจ้งเตือน",
                      "กรุณาระบุเหตุผลในการระงับ",
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  Get.back();

                  try {
                    final bannedUntil = isPermanent
                        ? null
                        : Timestamp.fromDate(
                            DateTime.now().add(Duration(days: banDays)),
                          );
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.users)
                        .doc(widget.sellerId)
                        .update({
                          'status': 'banned',
                          'banReason': reasonController.text.trim(),
                          'bannedUntil': bannedUntil,
                          'bannedAt': FieldValue.serverTimestamp(),
                          'strikeCount': FieldValue.increment(1),
                        });

                    Get.snackbar(
                      "สำเร็จ",
                      "ระงับร้านค้าเรียบร้อยแล้ว",
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      "ผิดพลาด",
                      "ไม่สามารถระงับร้านค้าได้: $e",
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                child: const Text("ยืนยันระงับ"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _unbanStore() async {
    AppDialog.showCustomDialog(
      title: "ปลดการระงับร้านค้า",
      message:
          "คุณต้องการยกเลิกการระงับและคืนสิทธิ์การใช้งานให้ร้านค้านี้ใช่หรือไม่?",
      icon: CupertinoIcons.checkmark_shield_fill,
      iconColor: Colors.green,
      confirmText: "ปลดระงับ",
      cancelText: "ยกเลิก",
      showCancel: true,
      onConfirm: () async {
        Get.back();
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(widget.sellerId)
              .update({
                'status': 'active',
                'banReason': FieldValue.delete(),
                'bannedUntil': FieldValue.delete(),
                'bannedAt': FieldValue.delete(),
              });
          Get.snackbar(
            "สำเร็จ",
            "ปลดการระงับร้านค้าเรียบร้อยแล้ว",
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } catch (e) {
          Get.snackbar(
            "ผิดพลาด",
            "ไม่สามารถปลดระงับได้: $e",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      },
    );
  }

  Future<void> _deleteReview(String reviewId) async {
    AppDialog.showCustomDialog(
      title: "ลบรีวิวไม่เหมาะสม",
      message: "คุณแน่ใจหรือไม่ว่าต้องการลบรีวิวนี้ออกจากระบบ?",
      icon: CupertinoIcons.trash_fill,
      iconColor: Colors.red,
      confirmText: "ลบรีวิว",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.reviews)
              .doc(reviewId)
              .delete();
          Get.snackbar(
            "สำเร็จ",
            "ลบรีวิวเรียบร้อยแล้ว",
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } catch (e) {
          Get.snackbar(
            "ผิดพลาด",
            "ไม่สามารถลบรีวิวได้: $e",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isFirebaseInitialized) {
      final seller = widget.sellerData ?? {};
      final storeStatus = (seller['status'] ?? 'active')
          .toString()
          .toLowerCase();
      final isBanned = storeStatus == 'banned' || storeStatus == 'suspended';
      final strikeCount = (seller['strikeCount'] ?? 0) as int;
      return _buildScaffoldContent(
        seller,
        isBanned,
        strikeCount,
        theme,
        isDark,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(widget.sellerId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError &&
            PermissionDeniedView.isPermissionDenied(userSnapshot.error)) {
          return PermissionDeniedView(
            title: "ไม่มีสิทธิ์เข้าถึงหน้าร้านค้า",
            message:
                "ต้องใช้สิทธิ์ผู้ดูแลระบบ (Admin) ในการตรวจสอบหน้าร้านค้าตามมาตรฐานใหม่",
            technicalDetails: userSnapshot.error.toString(),
            isScaffold: true,
            onRetry: () => setState(() {}),
          );
        }

        Map<String, dynamic> seller = widget.sellerData ?? {};
        if (userSnapshot.hasData &&
            userSnapshot.data != null &&
            userSnapshot.data!.exists) {
          seller = userSnapshot.data!.data() as Map<String, dynamic>;
        } else if (seller.isEmpty && userSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("ข้อผิดพลาด")),
            body: Center(child: Text("เกิดข้อผิดพลาด: ${userSnapshot.error}")),
          );
        }

        final storeStatus = (seller['status'] ?? 'active')
            .toString()
            .toLowerCase();
        final isBanned = storeStatus == 'banned' || storeStatus == 'suspended';
        final strikeCount = (seller['strikeCount'] ?? 0) as int;

        return _buildScaffoldContent(
          seller,
          isBanned,
          strikeCount,
          theme,
          isDark,
        );
      },
    );
  }

  Widget _buildScaffoldContent(
    Map<String, dynamic> seller,
    bool isBanned,
    int strikeCount,
    ThemeData theme,
    bool isDark,
  ) {
    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          "หน้าร้านค้า (Admin View)",
          style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark
            ? const Color(0xFF1E1E2C)
            : AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            tooltip: "รายงานที่เกี่ยวข้อง",
            icon: const Icon(CupertinoIcons.flag_fill, size: 20),
            onPressed: () => Get.to(() => const ManageReportScreen()),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildStoreHeaderCard(
                    seller,
                    isBanned,
                    strikeCount,
                    theme,
                    isDark,
                  ),

                  _buildSalesAndMetricsCard(theme, isDark),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _AdminStoreTabBarDelegate(
                backgroundColor: theme.cardColor,
                tabBar: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(CupertinoIcons.bag_fill, size: 18),
                      text: "สินค้าทั้งหมด",
                    ),
                    Tab(
                      icon: Icon(CupertinoIcons.cart_fill, size: 18),
                      text: "คำสั่งซื้อ",
                    ),
                    Tab(
                      icon: Icon(CupertinoIcons.star_fill, size: 18),
                      text: "รีวิวของร้าน",
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProductsTab(theme, isDark),
            _buildOrdersTab(theme, isDark),
            _buildReviewsTab(theme, isDark),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomModerationBar(
        seller,
        isBanned,
        theme,
        isDark,
      ),
    );
  }

  Widget _buildStoreHeaderCard(
    Map<String, dynamic> seller,
    bool isBanned,
    int strikeCount,
    ThemeData theme,
    bool isDark,
  ) {
    final profileImage = seller['profileImage'] ?? '';
    final storeName = seller['name'] ?? 'ไม่มีชื่อร้านค้า';
    final email = seller['email'] ?? 'ไม่มีอีเมล';
    final phone = seller['phone'] ?? 'ไม่มีเบอร์โทร';
    final bio = seller['bio'] ?? '-';
    final banReason = seller['banReason'];
    final bannedUntil = seller['bannedUntil'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBanned
              ? Colors.redAccent.withValues(alpha: 0.5)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                backgroundImage: profileImage.isNotEmpty
                    ? NetworkImage(profileImage)
                    : null,
                child: profileImage.isEmpty
                    ? const Icon(
                        CupertinoIcons.building_2_fill,
                        size: 30,
                        color: Colors.grey,
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: GoogleFonts.kanit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isBanned
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isBanned ? Colors.red : Colors.green,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isBanned
                                    ? CupertinoIcons.nosign
                                    : CupertinoIcons.check_mark_circled_solid,
                                size: 12,
                                color: isBanned
                                    ? Colors.redAccent
                                    : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isBanned ? "ร้านค้าถูกระงับ" : "เปิดบริการปกติ",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isBanned
                                      ? Colors.redAccent
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (strikeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "Strike: $strikeCount ครั้ง",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isBanned) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Colors.red,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "รายละเอียดการระงับร้านค้า",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "เหตุผล: ${banReason ?? 'ไม่ได้ระบุเหตุผล'}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  if (bannedUntil is Timestamp)
                    Text(
                      "ระงับจนถึง: ${DateFormat('dd/MM/yyyy HH:mm').format(bannedUntil.toDate())}",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    )
                  else if (bannedUntil == null)
                    const Text(
                      "ระยะเวลา: ระงับถาวร",
                      style: TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetaText(CupertinoIcons.mail_solid, email, isDark),
                    const SizedBox(height: 4),
                    _buildMetaText(CupertinoIcons.phone_fill, phone, isDark),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _copyToClipboard(widget.sellerId, "UID ร้านค้า"),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "UID: ${widget.sellerId.length > 8 ? '${widget.sellerId.substring(0, 8)}...' : widget.sellerId}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.doc_on_doc, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaText(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesAndMetricsCard(ThemeData theme, bool isDark) {
    if (!_isFirebaseInitialized) {
      return _buildMetricsContainer(
        theme: theme,
        isDark: isDark,
        totalCompletedSales: 0.0,
        completedOrders: 0,
        shippingOrders: 0,
        paidOrders: 0,
        disputedOrders: 0,
        cancelledOrders: 0,
        avgRating: 0.0,
        reviewCount: 0,
        totalProducts: 0,
        activeProducts: 0,
        soldProducts: 0,
        suspendedProducts: 0,
      );
    }

    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection(FirestoreCollections.orders)
            .where('sellerId', isEqualTo: widget.sellerId)
            .get(),
        FirebaseFirestore.instance
            .collection(FirestoreCollections.reviews)
            .where('sellerId', isEqualTo: widget.sellerId)
            .get(),
        FirebaseFirestore.instance
            .collection(FirestoreCollections.products)
            .where('sellerId', isEqualTo: widget.sellerId)
            .get(),
      ]),
      builder: (context, snapshot) {
        double totalCompletedSales = 0.0;
        int completedOrders = 0;
        int shippingOrders = 0;
        int paidOrders = 0;
        int disputedOrders = 0;
        int cancelledOrders = 0;

        double avgRating = 0.0;
        int reviewCount = 0;

        int activeProducts = 0;
        int soldProducts = 0;
        int suspendedProducts = 0;
        int totalProducts = 0;

        if (snapshot.hasData && snapshot.data != null) {
          final allOrdersSnap = snapshot.data![0];
          final reviewsSnap = snapshot.data![1];
          final productsSnap = snapshot.data![2];

          for (var doc in allOrdersSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final st = (data['status'] ?? '').toString().toLowerCase();
            if (st == 'completed') {
              completedOrders++;
              totalCompletedSales += (data['grandTotal'] ?? data['total'] ?? 0)
                  .toDouble();
            } else if (st == 'shipping') {
              shippingOrders++;
            } else if (st == 'paid') {
              paidOrders++;
            } else if (st == 'disputed' || (data['isDisputed'] == true)) {
              disputedOrders++;
            } else if (st == 'cancelled') {
              cancelledOrders++;
            }
          }

          reviewCount = reviewsSnap.docs.length;
          if (reviewCount > 0) {
            double totalStars = 0.0;
            for (var doc in reviewsSnap.docs) {
              final data = doc.data() as Map<String, dynamic>;
              totalStars += (data['rating'] ?? 5.0).toDouble();
            }
            avgRating = totalStars / reviewCount;
          }

          totalProducts = productsSnap.docs.length;
          for (var doc in productsSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final st = (data['status'] ?? 'active').toString().toLowerCase();
            if (st == 'active') {
              activeProducts++;
            } else if (st == 'sold') {
              soldProducts++;
            } else if (st == 'suspended') {
              suspendedProducts++;
            }
          }
        }

        return _buildMetricsContainer(
          theme: theme,
          isDark: isDark,
          totalCompletedSales: totalCompletedSales,
          completedOrders: completedOrders,
          shippingOrders: shippingOrders,
          paidOrders: paidOrders,
          disputedOrders: disputedOrders,
          cancelledOrders: cancelledOrders,
          avgRating: avgRating,
          reviewCount: reviewCount,
          totalProducts: totalProducts,
          activeProducts: activeProducts,
          soldProducts: soldProducts,
          suspendedProducts: suspendedProducts,
        );
      },
    );
  }

  Widget _buildMetricsContainer({
    required ThemeData theme,
    required bool isDark,
    required double totalCompletedSales,
    required int completedOrders,
    required int shippingOrders,
    required int paidOrders,
    required int disputedOrders,
    required int cancelledOrders,
    required double avgRating,
    required int reviewCount,
    required int totalProducts,
    required int activeProducts,
    required int soldProducts,
    required int suspendedProducts,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ข้อมูลร้านค้า & ยอดขาย (Real-time Analytics)",
                style: GoogleFonts.kanit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Icon(
                CupertinoIcons.chart_bar_alt_fill,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A2F), const Color(0xFF14241F)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ยอดขายรวมสำเร็จ (GMV)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.green[200] : Colors.green[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "฿ ${currencyFormat.format(totalCompletedSales)}",
                      style: GoogleFonts.kanit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.greenAccent
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "คะแนนเฉลี่ยร้านค้า",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.star_fill,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reviewCount > 0 ? avgRating.toStringAsFixed(1) : "-",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          " ($reviewCount รีวิว)",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            "สรุปคำสั่งซื้อทั้งหมด:",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatBadge("สำเร็จ", completedOrders, Colors.green, isDark),
              const SizedBox(width: 6),
              _buildStatBadge("รอส่ง", paidOrders, Colors.blue, isDark),
              const SizedBox(width: 6),
              _buildStatBadge(
                "กำลังส่ง",
                shippingOrders,
                Colors.orange,
                isDark,
              ),
              const SizedBox(width: 6),
              _buildStatBadge("ข้อพิพาท", disputedOrders, Colors.red, isDark),
              const SizedBox(width: 6),
              _buildStatBadge("ยกเลิก", cancelledOrders, Colors.grey, isDark),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            "สต็อกสินค้าในระบบ:",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatBadge(
                "ทั้งหมด",
                totalProducts,
                AppTheme.primaryColor,
                isDark,
              ),
              const SizedBox(width: 6),
              _buildStatBadge("เปิดขาย", activeProducts, Colors.teal, isDark),
              const SizedBox(width: 6),
              _buildStatBadge("ขายแล้ว", soldProducts, Colors.indigo, isDark),
              const SizedBox(width: 6),
              _buildStatBadge(
                "ถูกระงับ",
                suspendedProducts,
                Colors.deepOrange,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab(ThemeData theme, bool isDark) {
    if (!_isFirebaseInitialized) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : 150,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.bag, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    "ไม่พบรายการสินค้าในหมวดนี้",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.products)
        .where('sellerId', isEqualTo: widget.sellerId);

    if (_productFilter != 'all') {
      query = query.where('status', isEqualTo: _productFilter);
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('all', 'สินค้าทั้งหมด'),
              _buildFilterChip('active', 'เปิดขายอยู่'),
              _buildFilterChip('sold', 'ขายแล้ว'),
              _buildFilterChip('suspended', 'ถูกระงับ'),
              _buildFilterChip('draft', 'ฉบับร่าง'),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 0
                            ? constraints.maxHeight
                            : 150,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.bag,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "ไม่พบรายการสินค้าในหมวดนี้",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final products = snapshot.data!.docs.map((doc) {
                return ProductModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                );
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _buildProductListItem(product, theme, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _productFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : Colors.grey,
        ),
        onSelected: (val) {
          setState(() => _productFilter = key);
        },
      ),
    );
  }

  Widget _buildProductListItem(
    ProductModel product,
    ThemeData theme,
    bool isDark,
  ) {
    final isSuspended = product.status == 'suspended';
    final isSold = product.status == 'sold';

    Color statusColor = Colors.green;
    String statusText = "เปิดขาย";
    if (isSuspended) {
      statusColor = Colors.red;
      statusText = "ถูกระงับ";
    } else if (isSold) {
      statusColor = Colors.grey;
      statusText = "ขายแล้ว";
    } else if (product.status == 'draft') {
      statusColor = Colors.orange;
      statusText = "ฉบับร่าง";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: theme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showAdminProductInspectionModal(product, theme, isDark);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 64,
                  height: 64,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: product.images.isNotEmpty
                      ? Image.network(product.images.first, fit: BoxFit.cover)
                      : const Icon(CupertinoIcons.photo, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "฿ ${currencyFormat.format(product.price)}",
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "หมวด: ${product.category}",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: isSuspended ? "เปิดใช้งานสินค้า" : "ระงับสินค้านี้",
                icon: Icon(
                  isSuspended
                      ? CupertinoIcons.checkmark_shield_fill
                      : CupertinoIcons.nosign,
                  color: isSuspended ? Colors.green : Colors.orange,
                  size: 20,
                ),
                onPressed: () => _toggleProductStatus(product),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminProductInspectionModal(
    ProductModel product,
    ThemeData theme,
    bool isDark,
  ) {
    final isSuspended = product.status == 'suspended';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.shield_fill,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "ตรวจสอบสินค้า (โหมด Admin)",
                        style: GoogleFonts.kanit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.grey,
                    ),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              if (product.images.isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: product.images.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product.images[i],
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 140,
                                color: Colors.grey[300],
                                child: const Icon(CupertinoIcons.photo),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),

              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "฿ ${currencyFormat.format(product.price)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInspectionRow(
                      "รหัสสินค้า (ID):",
                      product.id,
                      isCopyable: true,
                    ),
                    const Divider(height: 14),
                    _buildInspectionRow(
                      "สถานะปัจจุบัน:",
                      product.status.toUpperCase(),
                    ),
                    const Divider(height: 14),
                    _buildInspectionRow(
                      "หมวดหมู่ / ประเภท:",
                      "${product.category} / ${product.type}",
                    ),
                    const Divider(height: 14),
                    _buildInspectionRow(
                      "แบรนด์ / ไซซ์:",
                      "${product.brand.isEmpty ? '-' : product.brand} / ${product.size.isEmpty ? '-' : product.size}",
                    ),
                    const Divider(height: 14),
                    _buildInspectionRow(
                      "น้ำหนักสินค้า:",
                      "${product.weight.toStringAsFixed(2)} กก.",
                    ),
                    const Divider(height: 14),
                    _buildInspectionRow(
                      "ยอดเข้าชม (Views):",
                      "${product.views} ครั้ง",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                "รายละเอียดสินค้า:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.description.isEmpty
                      ? "ไม่มีรายละเอียด"
                      : product.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSuspended
                            ? Colors.green
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Get.back();
                        _toggleProductStatus(product);
                      },
                      icon: Icon(
                        isSuspended
                            ? CupertinoIcons.checkmark_shield_fill
                            : CupertinoIcons.nosign,
                        size: 16,
                      ),
                      label: Text(
                        isSuspended ? "เปิดใช้งานสินค้า" : "ระงับสินค้านี้",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Get.back();
                      Get.to(() => const ManageReportScreen());
                    },
                    icon: const Icon(CupertinoIcons.flag_fill, size: 14),
                    label: const Text("ดูรายงาน"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildInspectionRow(
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (isCopyable) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  Get.snackbar(
                    "สำเร็จ",
                    "คัดลอกรหัสสินค้าเรียบร้อย",
                    backgroundColor: Colors.black87,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Icon(
                  CupertinoIcons.doc_on_doc,
                  size: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersTab(ThemeData theme, bool isDark) {
    if (!_isFirebaseInitialized) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : 150,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.cart, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    "ยังไม่มีรายการคำสั่งซื้อของร้านนี้",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.orders)
          .where('sellerId', isEqualTo: widget.sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("เกิดข้อผิดพลาดในการโหลดออเดอร์: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 0
                      ? constraints.maxHeight
                      : 150,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.cart,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "ยังไม่มีรายการคำสั่งซื้อของร้านนี้",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final orders = snapshot.data!.docs.map((doc) {
          return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        orders.sort((a, b) {
          final aTime = a.createdAt;
          final bTime = b.createdAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderListItem(order, theme, isDark);
          },
        );
      },
    );
  }

  Widget _buildOrderListItem(OrderModel order, ThemeData theme, bool isDark) {
    Color statusColor = Colors.blue;
    String statusText = order.status;

    switch (order.status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'สำเร็จแล้ว';
        break;
      case 'shipping':
        statusColor = Colors.orange;
        statusText = 'กำลังจัดส่ง';
        break;
      case 'paid':
        statusColor = Colors.indigo;
        statusText = 'ชำระเงินแล้ว (รอส่ง)';
        break;
      case 'disputed':
        statusColor = Colors.red;
        statusText = 'มีข้อพิพาท';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'ยกเลิกแล้ว';
        break;
    }

    String dateStr = '-';
    if (order.createdAt != null) {
      dateStr = DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(order.createdAt!.toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ยอดรวม: ฿ ${currencyFormat.format(order.grandTotal)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  "ชำระผ่าน: ${order.paymentMethod}",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Escrow: ${order.escrowStatus}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: order.escrowStatus == 'released'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab(ThemeData theme, bool isDark) {
    if (!_isFirebaseInitialized) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : 150,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.star, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    "ร้านค้านี้ยังไม่มีรีวิวจากผู้ซื้อ",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.reviews)
          .where('sellerId', isEqualTo: widget.sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("เกิดข้อผิดพลาดในการโหลดรีวิว: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 0
                      ? constraints.maxHeight
                      : 150,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.star,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "ร้านค้านี้ยังไม่มีรีวิวจากผู้ซื้อ",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final reviewDocs = List<QueryDocumentSnapshot>.from(
          snapshot.data!.docs,
        );
        reviewDocs.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['createdAt'];
          final bDate = (b.data() as Map<String, dynamic>)['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: reviewDocs.length,
          itemBuilder: (context, index) {
            final doc = reviewDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rating = (data['rating'] ?? 5.0).toDouble();
            final comment = data['comment'] ?? 'ไม่มีข้อความรีวิว';
            final buyerName =
                data['buyerName'] ?? data['userName'] ?? 'ผู้ซื้อ';
            final createdAt = data['createdAt'];

            String dateStr = '-';
            if (createdAt is Timestamp) {
              dateStr = DateFormat('dd/MM/yyyy').format(createdAt.toDate());
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.person_crop_circle,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              buyerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                            IconButton(
                              tooltip: "ลบรีวิวไม่เหมาะสม",
                              icon: const Icon(
                                CupertinoIcons.trash,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteReview(doc.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < rating
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          size: 14,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomModerationBar(
    Map<String, dynamic> seller,
    bool isBanned,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isBanned) {
                    _unbanStore();
                  } else {
                    _showBanStoreDialog(seller);
                  }
                },
                icon: Icon(
                  isBanned
                      ? CupertinoIcons.checkmark_shield_fill
                      : CupertinoIcons.nosign,
                  size: 16,
                ),
                label: Text(
                  isBanned ? "ปลดการระงับร้าน" : "ระงับร้านค้านี้",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBanned ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Get.to(() => const ManageReportScreen());
              },
              icon: const Icon(CupertinoIcons.flag_fill, size: 14),
              label: const Text(
                "ดูรายงาน",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black87,
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStoreTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _AdminStoreTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_AdminStoreTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
