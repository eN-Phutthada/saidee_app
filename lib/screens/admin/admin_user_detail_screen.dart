import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';

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

  @override
  void initState() {
    super.initState();
    _isActive = (widget.userData['status'] ?? 'active') == 'active';
  }

  Future<void> _toggleUserStatus() async {
    setState(() => _isLoading = true);
    try {
      String newStatus = _isActive ? 'suspended' : 'active';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'status': newStatus});

      setState(() => _isActive = !_isActive);

      _showCustomSnackbar(
        "อัปเดตสำเร็จ",
        _isActive
            ? "ปลดระงับบัญชีนี้แล้ว ผู้ใช้สามารถใช้งานได้ปกติ"
            : "ระงับการใช้งานบัญชีนี้เรียบร้อยแล้ว",
        _isActive
            ? CupertinoIcons.checkmark_shield_fill
            : CupertinoIcons.nosign,
        _isActive ? Colors.green[700]! : Colors.red[700]!,
      );
    } catch (e) {
      _showCustomSnackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถอัปเดตสถานะได้",
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
      backgroundColor: backgroundColor.withOpacity(0.9),
      colorText: Colors.white,
      borderRadius: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      duration: const Duration(seconds: 3),
      barBlur: 20,
      boxShadows: [
        BoxShadow(
          color: backgroundColor.withOpacity(0.4),
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
          color: AppTheme.primaryColor.withOpacity(baseOpacity * opacityFactor),
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
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                                  ? AppTheme.primaryColor.withOpacity(0.5)
                                  : Colors.red.withOpacity(0.5),
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
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
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
                                    : "สถานะ: ถูกระงับ (Suspended)",
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
                                AppTheme.primaryColor.withOpacity(0.1),
                                Colors.white,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
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
                                color: AppTheme.primaryColor.withOpacity(0.2),
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
                          ? Colors.red.withOpacity(0.05)
                          : Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isActive
                            ? Colors.red.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
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
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isActive
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isActive
                      ? CupertinoIcons.nosign
                      : CupertinoIcons.checkmark_shield_fill,
                  color: _isActive ? Colors.red : Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isActive ? "ยืนยันการระงับบัญชี" : "ยืนยันการปลดระงับ",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isActive
                    ? "คุณแน่ใจหรือไม่ที่จะระงับผู้ใช้นี้?\nพวกเขาจะไม่สามารถเข้าสู่ระบบหรือทำธุรกรรมใดๆ ได้"
                    : "คุณแน่ใจหรือไม่ที่จะปลดระงับผู้ใช้นี้?\nระบบจะเปิดสิทธิ์ให้ใช้งานได้ตามปกติ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "ยกเลิก",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _toggleUserStatus();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isActive ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isActive ? "ระงับบัญชี" : "ปลดระงับ",
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
}
