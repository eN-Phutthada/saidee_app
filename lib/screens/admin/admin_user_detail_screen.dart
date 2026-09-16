import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/moderation_service.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late bool _isActive;
  bool _isLoading = false;
  String? _banReason;
  Timestamp? _bannedUntil;
  int _strikeCount = 0;

  @override
  void initState() {
    super.initState();
    _isActive = (widget.userData['status'] ?? 'active') == 'active';
    _banReason = widget.userData['banReason'];
    if (widget.userData['bannedUntil'] is Timestamp) {
      _bannedUntil = widget.userData['bannedUntil'];
    }
    _strikeCount = (widget.userData['strikeCount'] ?? 0) as int;
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return "ถาวร";
    final d = ts.toDate();
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _unbanUser() async {
    setState(() => _isLoading = true);
    try {
      String adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'Admin';
      bool success = await ModerationService.unbanUser(
        userId: widget.userId,
        adminUid: adminUid,
      );

      if (success) {
        setState(() {
          _isActive = true;
          _banReason = null;
          _bannedUntil = null;
        });

        _showCustomSnackbar(
          "อัปเดตสำเร็จ",
          "ปลดระงับบัญชีนี้แล้ว ผู้ใช้สามารถใช้งานได้ปกติ",
          CupertinoIcons.checkmark_shield_fill,
          Colors.green[700]!,
        );
      } else {
        throw Exception("ไม่สามารถปลดระงับได้");
      }
    } catch (e) {
      _showCustomSnackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถอัปเดตสถานะได้: $e",
        CupertinoIcons.xmark_circle_fill,
        Colors.red[800]!,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _banUser({
    required String reason,
    Duration? duration,
  }) async {
    setState(() => _isLoading = true);
    try {
      String adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'Admin';
      bool success = await ModerationService.banUser(
        userId: widget.userId,
        reason: reason,
        duration: duration,
        adminUid: adminUid,
      );

      if (success) {
        setState(() {
          _isActive = false;
          _banReason = reason;
          _bannedUntil = duration != null
              ? Timestamp.fromDate(DateTime.now().add(duration))
              : null;
          _strikeCount += 1;
        });

        _showCustomSnackbar(
          "อัปเดตสำเร็จ",
          "ระงับการใช้งานบัญชีนี้เรียบร้อยแล้ว",
          CupertinoIcons.nosign,
          Colors.red[700]!,
        );
      } else {
        throw Exception("ไม่สามารถระงับบัญชีได้");
      }
    } catch (e) {
      _showCustomSnackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถอัปเดตสถานะได้: $e",
        CupertinoIcons.xmark_circle_fill,
        Colors.red[800]!,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showCustomSnackbar(
      "คัดลอกแล้ว",
      "คัดลอก $label ลงในคลิปบอร์ดแล้ว",
      CupertinoIcons.doc_on_clipboard_fill,
      AppTheme.primaryColor,
    );
  }

  void _showCustomSnackbar(
    String title,
    String message,
    IconData icon,
    Color backgroundColor,
  ) {
    Get.snackbar(
      title,
      message,
      icon: Icon(icon, color: Colors.white, size: 28),
      snackPosition: SnackPosition.TOP,
      backgroundColor: backgroundColor.withValues(alpha: 0.9),
      colorText: Colors.white,
      borderRadius: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      duration: const Duration(seconds: 3),
      barBlur: 20,
      boxShadows: [
        BoxShadow(
          color: backgroundColor.withValues(alpha: 0.4),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    String name = widget.userData['name'] ?? 'ไม่มีชื่อ';
    String email = widget.userData['email'] ?? 'ไม่พบอีเมล';
    String phone = widget.userData['phone'] ?? 'ไม่พบเบอร์โทร';
    String bio = widget.userData['bio'] ?? '-';
    double walletBalance =
        (widget.userData['walletBalance'] ??
                widget.userData['wallet_balance'] ??
                0)
            .toDouble();
    String profileImage = widget.userData['profileImage'] ?? '';
    Timestamp? createdAt = widget.userData['createdAt'];
    String joinDate = createdAt != null
        ? "${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year}"
        : "-";

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "ข้อมูลผู้ใช้ (Admin View)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isActive
                                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                  : Colors.red.withValues(alpha: 0.5),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            backgroundImage: profileImage.isNotEmpty
                                ? NetworkImage(profileImage)
                                : null,
                            child: profileImage.isEmpty
                                ? Icon(
                                    CupertinoIcons.person_fill,
                                    size: 40,
                                    color: Colors.grey[400],
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isActive
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isActive
                                    ? CupertinoIcons.checkmark_seal_fill
                                    : CupertinoIcons.nosign,
                                size: 14,
                                color: _isActive
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isActive
                                    ? "สถานะ: ใช้งานปกติ (Active)"
                                    : "สถานะ: ถูกระงับ (${_bannedUntil != null ? 'ชั่วคราว' : 'ถาวร'})",
                                style: TextStyle(
                                  color: _isActive
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isActive && _banReason != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "เหตุผล: $_banReason",
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_bannedUntil != null)
                            Text(
                              "พ้นโทษ: ${_formatDateTime(_bannedUntil)}",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.grey[800]!, Colors.grey[850]!]
                            : [
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                                Colors.white,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.creditcard_fill,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "ยอดเงินในระบบ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "฿ ${walletBalance.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildInfoCard(
                    theme,
                    isDark,
                    title: "ข้อมูลทั่วไป",
                    icon: CupertinoIcons.doc_text_fill,
                    iconColor: Colors.blueAccent,
                    content: Column(
                      children: [
                        _buildRowItem("เบอร์โทรศัพท์", phone, isDark),
                        _buildRowItem("วันที่สมัคร", joinDate, isDark),
                        _buildRowItem("Bio", bio, isDark),
                        _buildRowItem(
                          "ประวัติการตักเตือน (Strikes)",
                          "$_strikeCount ครั้ง",
                          isDark,
                        ),
                        _buildRowItem(
                          "User ID",
                          widget.userId,
                          isDark,
                          isCopyable: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? Colors.red.withValues(alpha: 0.05)
                          : Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isActive
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isActive
                              ? CupertinoIcons.exclamationmark_shield_fill
                              : CupertinoIcons.shield_lefthalf_fill,
                          size: 40,
                          color: _isActive ? Colors.red : Colors.green,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isActive
                              ? "Danger Zone (ระงับบัญชี)"
                              : "Recovery Zone (ปลดระงับ)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isActive ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isActive
                              ? "หากระงับ ผู้ใช้จะไม่สามารถล็อกอิน ซื้อ หรือขายสินค้าในระบบได้"
                              : "หากปลดระงับ ผู้ใช้จะสามารถกลับมาใช้งานระบบได้ตามปกติทันที",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _confirmToggleStatus(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isActive
                                  ? Colors.red
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isActive
                                        ? "ระงับบัญชีผู้ใช้นี้"
                                        : "ปลดระงับบัญชีผู้ใช้นี้",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    bool isDark, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
          const SizedBox(height: 15),
          content,
        ],
      ),
    );
  }

  Widget _buildRowItem(
    String label,
    String value,
    bool isDark, {
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: isCopyable ? 13 : 14,
                      fontFamily: isCopyable ? 'Courier' : null,
                      fontWeight: isCopyable
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (isCopyable) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _copyToClipboard(value, label),
                    child: Icon(
                      CupertinoIcons.doc_on_clipboard,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmToggleStatus(BuildContext context) {
    if (_isActive) {
      // เปิด Dialog เลือกระยะเวลาและระบุเหตุผลในการแบน
      int selectedDays = 7;
      bool isPermanent = false;
      final reasonController = TextEditingController(
        text: "ละเมิดกฎระเบียบและข้อกำหนดการใช้งานของแอปพลิเคชัน",
      );

      Get.dialog(
        StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    "ระงับการใช้งานบัญชี",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "เลือกระยะเวลาการระงับ:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
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
                  onPressed: () {
                    Get.back();
                    Duration? duration =
                        isPermanent ? null : Duration(days: selectedDays);
                    _banUser(
                      reason: reasonController.text.trim(),
                      duration: duration,
                    );
                  },
                  child: const Text("ยืนยันระงับบัญชี"),
                ),
              ],
            );
          },
        ),
      );
    } else {
      AppDialog.showCustomDialog(
        title: "ยืนยันการปลดระงับ",
        message:
            "คุณแน่ใจหรือไม่ที่จะปลดระงับผู้ใช้นี้?\nระบบจะเปิดสิทธิ์ให้ใช้งานได้ตามปกติ และกู้คืนสินค้ากลับมาขาย",
        icon: CupertinoIcons.checkmark_shield_fill,
        iconColor: Colors.green,
        confirmText: "ปลดระงับ",
        showCancel: true,
        cancelText: "ยกเลิก",
        isDestructive: false,
        onConfirm: () {
          Get.back();
          _unbanUser();
        },
      );
    }
  }
}
