import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class WalletWithdrawScreen extends StatefulWidget {
  final double currentBalance;
  
  const WalletWithdrawScreen({super.key, required this.currentBalance});

  @override
  State<WalletWithdrawScreen> createState() => _WalletWithdrawScreenState();
}

class _WalletWithdrawScreenState extends State<WalletWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  
  String? _selectedBank;
  final List<String> _banks = [
    'ธนาคารกสิกรไทย',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงศรีอยุธยา',
    'ธนาคารทหารไทยธนชาต (ttb)',
    'ธนาคารออมสิน',
    'พร้อมเพย์ (PromptPay)'
  ];

  final List<String> _quickAmounts = ['100', '300', '500', '1000', 'ทั้งหมด'];

  bool _isLoading = false;

  Future<void> _processWithdraw() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError("กรุณาระบุจำนวนเงินที่ต้องการถอน");
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError("กรุณาระบุจำนวนเงินให้ถูกต้อง (ต้องมากกว่า 0 บาท)");
      return;
    }

    if (amount > widget.currentBalance) {
      _showError("ยอดเงินในวอลเล็ทของคุณไม่เพียงพอสำหรับการถอน");
      return;
    }

    if (_selectedBank == null) {
      _showError("กรุณาเลือกธนาคารปลายทาง");
      return;
    }

    if (_accountNumberController.text.trim().isEmpty) {
      _showError("กรุณาระบุเลขที่บัญชี / เบอร์พร้อมเพย์");
      return;
    }

    if (_accountNameController.text.trim().isEmpty) {
      _showError("กรุณาระบุชื่อบัญชีให้ตรงกับธนาคาร");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("ไม่พบผู้ใช้งาน");

      // Transaction to ensure atomicity
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception("ไม่พบข้อมูลผู้ใช้");
        }

        double currentWalletBalance = (userSnapshot.data() as Map<String, dynamic>)['walletBalance']?.toDouble() ?? 0.0;

        if (currentWalletBalance < amount) {
          throw Exception("ยอดเงินคงเหลือไม่เพียงพอ");
        }

        // 1. Deduct balance
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(-amount),
        });

        // 2. Create transaction record
        DocumentReference newTxRef = FirebaseFirestore.instance.collection('transactions').doc();
        transaction.set(newTxRef, {
          'uid': user.uid,
          'type': 'withdraw',
          'amount': amount,
          'status': 'pending',
          'bankName': _selectedBank,
          'accountNumber': _accountNumberController.text.trim(),
          'accountName': _accountNameController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      setState(() => _isLoading = false);

      AppDialog.showCustomDialog(
        title: "ส่งคำขอถอนเงินสำเร็จ",
        message: "ระบบได้รับคำขอถอนเงินของคุณแล้ว\nแอดมินจะดำเนินการโอนเงินให้ภายใน 24 ชั่วโมง",
        icon: CupertinoIcons.check_mark_circled_solid,
        iconColor: Colors.green,
        confirmText: "ตกลง",
        onConfirm: () {
          Get.back(); // close dialog
          Get.back(); // close screen
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("เกิดข้อผิดพลาดในการถอนเงิน: ${e.toString()}");
    }
  }

  void _showError(String message) {
    AppDialog.showCustomDialog(
      title: "แจ้งเตือน",
      message: message,
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      iconColor: Colors.orange,
      confirmText: "ตกลง",
      onConfirm: () => Get.back(),
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
    final baseOpacity = isDark ? 0.05 : 0.08;
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "ถอนเงิน",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          _buildBgCircle(isDark, top: -50, right: -50, size: 250),
          _buildBgCircle(
            isDark,
            top: size.height * 0.3,
            left: -100,
            size: 200,
            opacityFactor: 0.6,
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // Current Balance Banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [isDark ? Colors.grey[800]! : Colors.white, isDark ? Colors.grey[900]! : Colors.grey[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      )
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ยอดเงินที่สามารถถอนได้",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "฿ ${widget.currentBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Amount Input
                  Center(
                    child: Text(
                      "ระบุจำนวนเงินที่ต้องการถอน",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          "฿ ",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: "0",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _quickAmounts.map((amtText) {
                        bool isSelected = _amountController.text == amtText || (amtText == 'ทั้งหมด' && _amountController.text == widget.currentBalance.toStringAsFixed(0));
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (amtText == 'ทั้งหมด') {
                                _amountController.text = widget.currentBalance.toStringAsFixed(0); // Optional: you can do exact .toString() for decimal
                              } else {
                                _amountController.text = amtText;
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: (MediaQuery.of(context).size.width - 72) / 3,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : (isDark ? Colors.grey[800] : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : (isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[200]!),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                amtText == 'ทั้งหมด' ? amtText : "$amtText",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.grey[300]
                                            : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "ข้อมูลบัญชีรับเงิน",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBank,
                          isExpanded: true,
                          hint: Text("เลือกธนาคาร / พร้อมเพย์", style: TextStyle(color: Colors.grey[500])),
                          dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                          icon: Icon(CupertinoIcons.chevron_down, size: 16, color: Colors.grey[500]),
                          items: _banks.map((String bank) {
                            return DropdownMenuItem<String>(
                              value: bank,
                              child: Text(bank),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBank = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "เลขที่บัญชี / เบอร์โทรพร้อมเพย์",
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: _accountNameController,
                      decoration: InputDecoration(
                        hintText: "ชื่อ-นามสกุล เจ้าของบัญชี",
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // spacing for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _processWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      "ยืนยันการถอนเงิน",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
