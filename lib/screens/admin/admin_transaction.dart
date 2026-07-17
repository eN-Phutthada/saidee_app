import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
class AdminTransactionScreen extends StatefulWidget {
  final bool isBottomNav;

  const AdminTransactionScreen({super.key, this.isBottomNav = false});

  @override
  State<AdminTransactionScreen> createState() => _AdminTransactionScreenState();
}

class _AdminTransactionScreenState extends State<AdminTransactionScreen> {
  String _selectedFilter = 'all';

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

  bool _isAppIncome(String type) {
    List<String> incomingToApp = ['topup', 'purchase', 'buy'];
    return incomingToApp.contains(type.toLowerCase());
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
          "ธุรกรรมการเงิน",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isBottomNav
            ? null
            : IconButton(
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                final allTransactions = snapshot.data!.docs;

                double totalIn = 0;
                double totalOut = 0;

                for (var doc in allTransactions) {
                  var data = doc.data() as Map<String, dynamic>;
                  double amount = (data['amount'] ?? 0).toDouble();
                  String type = (data['type'] ?? '').toLowerCase();
                  if (_isAppIncome(type)) {
                    totalIn += amount;
                  } else {
                    totalOut += amount;
                  }
                }

                var filteredDocs = _selectedFilter == 'all'
                    ? allTransactions
                    : allTransactions.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        var type = (data['type'] ?? '').toLowerCase();
                        var status = (data['status'] ?? '').toLowerCase();
                        
                        if (_selectedFilter == 'pending_withdraw') {
                          return type == 'withdraw' && status == 'pending';
                        }
                        if (_selectedFilter == 'purchase' && type == 'buy') {
                          return true;
                        }
                        return type == _selectedFilter;
                      }).toList();

                // DYNAMIC SORTING: Float pending withdrawals to the top
                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  bool isPendingA = dataA['type'] == 'withdraw' && dataA['status'] == 'pending';
                  bool isPendingB = dataB['type'] == 'withdraw' && dataB['status'] == 'pending';
                  
                  if (isPendingA && !isPendingB) return -1;
                  if (!isPendingA && isPendingB) return 1;
                  
                  Timestamp? tsA = dataA['createdAt'];
                  Timestamp? tsB = dataB['createdAt'];
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsB.compareTo(tsA);
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.05,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildSummaryItem(
                                  "เงินเข้า (In)",
                                  totalIn,
                                  Colors.green,
                                  CupertinoIcons.arrow_down_right_circle_fill,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.withOpacity(0.2),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                ),
                                _buildSummaryItem(
                                  "เงินออก (Out)",
                                  totalOut,
                                  Colors.redAccent,
                                  CupertinoIcons.arrow_up_right_circle_fill,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('ทั้งหมด', 'all', isDark),
                          _buildFilterChip('รอโอนเงิน', 'pending_withdraw', isDark),
                          _buildFilterChip('เติมเงิน', 'topup', isDark),
                          _buildFilterChip('ซื้อสินค้า', 'purchase', isDark),
                          _buildFilterChip('รายรับผู้ขาย', 'income', isDark),
                          _buildFilterChip('ถอนเงิน', 'withdraw', isDark),
                          _buildFilterChip('คืนเงิน', 'refund', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Text(
                                "ไม่พบรายการ",
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                var docId = filteredDocs[index].id;
                                var data =
                                    filteredDocs[index].data()
                                        as Map<String, dynamic>;
                                return _buildTransactionItem(
                                  context,
                                  data,
                                  docId,
                                  isDark,
                                  theme,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${amount.toStringAsFixed(0)} ฿",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    bool isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedFilter = value);
        },
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[400] : Colors.grey[700]),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        elevation: isSelected ? 4 : 0,
        pressElevation: 0,
        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  void _showWithdrawalActionDialog(
    BuildContext context,
    String docId,
    String uid,
    Map<String, dynamic> data,
    String userName,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amount = (data['amount'] ?? 0).toDouble();
    final bankName = data['bankName'] ?? 'ไม่ระบุธนาคาร';
    final accountName = data['accountName'] ?? 'ไม่ระบุชื่อบัญชี';
    final accountNumber = data['accountNumber'] ?? 'ไม่ระบุเลขบัญชี';

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
            const Text(
              "ตรวจสอบการถอนเงิน",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildDetailRow("ผู้ขอถอนเงิน", userName, isDark),
            _buildDetailRow("จำนวนเงิน", "${amount.toStringAsFixed(2)} ฿", isDark, isHighlight: true),
            const Divider(height: 30),
            _buildDetailRow("ธนาคาร", bankName, isDark),
            _buildDetailRow("ชื่อบัญชี", accountName, isDark),
            _buildDetailRow("เลขที่บัญชี", accountNumber, isDark),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back();
                      _rejectWithdrawal(docId, uid, amount);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("ปฏิเสธ/คืนเงิน", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      _showUploadSlipDialog(docId, amount);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("โอนเงินเรียบร้อย", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
                fontSize: isHighlight ? 18 : 14,
                color: isHighlight ? Colors.redAccent : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadSlipDialog(String docId, double expectedAmount) {
    File? slipImage;
    bool isUploading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: theme.scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "อัปโหลดสลิปยืนยันการโอน",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: isUploading ? null : () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (image != null) {
                        setStateDialog(() => slipImage = File(image.path));
                      }
                    },
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: slipImage != null ? Colors.green : Colors.grey.shade400,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: slipImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(slipImage!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.photo_on_rectangle, size: 50, color: Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text(
                                  "แตะเพื่อเลือกรูปสลิป",
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isUploading ? null : () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (slipImage == null || isUploading)
                              ? null
                              : () async {
                                  setStateDialog(() => isUploading = true);
                                  bool success = await _uploadSlipAndApprove(docId, slipImage!, expectedAmount);
                                  if (context.mounted) {
                                    setStateDialog(() => isUploading = false);
                                    if (success) {
                                      Get.back();
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isUploading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text("ยืนยัน", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  Future<bool> _uploadSlipAndApprove(String docId, File imageFile, double expectedAmount) async {
    try {
      final String slipokApiKey = dotenv.env['SLIPOK_API_KEY'] ?? '';
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.slipok.com/api/line/apikey/61849'),
      );
      request.headers['x-authorization'] = slipokApiKey;
      request.files.add(
        await http.MultipartFile.fromPath('files', imageFile.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        var slipData = jsonData['data'];
        double transferredAmount = (slipData['amount'] ?? 0).toDouble();

        if (transferredAmount != expectedAmount) {
          Get.snackbar(
            "สลิปไม่ถูกต้อง", 
            "จำนวนเงินในสลิป ($transferredAmount ฿) ไม่ตรงกับยอดถอน ($expectedAmount ฿)", 
            backgroundColor: Colors.red, 
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return false;
        }

        // Upload to Firebase Storage
        String fileName = 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child('slips/withdrawals/$docId/$fileName');

        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Transaction to deduct wallet balance and update transaction status to success
        DocumentReference txRef = FirebaseFirestore.instance.collection('transactions').doc(docId);
        DocumentSnapshot txSnap = await txRef.get();
        if (!txSnap.exists) {
          throw Exception("ไม่พบข้อมูลรายการถอนเงิน");
        }
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;
        String uid = txData['uid'] ?? '';
        if (uid.isEmpty) {
          throw Exception("ไม่พบรหัสผู้ใช้ในรายการถอนเงิน");
        }

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(uid);
          DocumentSnapshot userSnap = await transaction.get(userRef);
          if (!userSnap.exists) {
            throw Exception("ไม่พบข้อมูลผู้ใช้");
          }

          double currentBalance = (userSnap.data() as Map<String, dynamic>)['walletBalance']?.toDouble() ?? 0.0;
          if (currentBalance < expectedAmount) {
            throw Exception("ยอดเงินคงเหลือของผู้ใช้ไม่เพียงพอสำหรับหักเงิน (คงเหลือ: ฿${currentBalance.toStringAsFixed(2)})");
          }

          transaction.update(userRef, {
            'walletBalance': FieldValue.increment(-expectedAmount),
          });

          transaction.update(txRef, {
            'status': 'success',
            'slipUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        Get.snackbar("สำเร็จ", "อนุมัติรายการถอนเงินและอัปโหลดสลิปเรียบร้อย", backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      } else {
        Get.snackbar(
          "ตรวจสอบสลิปไม่ผ่าน", 
          jsonData['message'] ?? 'รูปภาพสลิปไม่ถูกต้อง หรือเซิร์ฟเวอร์มีปัญหา', 
          backgroundColor: Colors.orange, 
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar("เกิดข้อผิดพลาด", e.toString().replaceAll('Exception: ', ''), backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<void> _rejectWithdrawal(String docId, String uid, double amount) async {
    try {
      await FirebaseFirestore.instance.collection('transactions').doc(docId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'note': 'แอดมินปฏิเสธรายการถอนเงิน',
      });
      Get.snackbar("ปฏิเสธรายการ", "ปฏิเสธรายการถอนเงินเรียบร้อยแล้ว", backgroundColor: Colors.orange, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("เกิดข้อผิดพลาด", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
    bool isDark,
    ThemeData theme,
  ) {
    String uid = data['uid'] ?? data['member_id'] ?? '';
    String type = (data['type'] ?? 'unknown').toLowerCase();
    double amount = (data['amount'] ?? 0).toDouble();
    String status = data['status'] ?? 'pending';
    Timestamp? ts = data['createdAt'];
    DateTime date = ts?.toDate() ?? DateTime.now();
    String formattedDate =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";

    bool isAppIn = _isAppIncome(type);

    return FutureBuilder<DocumentSnapshot?>(
      future: uid.isEmpty ? Future.value(null) : FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnapshot) {
        String userName = "กำลังโหลด...";
        String userImage = "";

        if (userSnapshot.connectionState == ConnectionState.done) {
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            userName = userData['name'] ?? "ไม่ทราบชื่อ";
            userImage = userData['profileImage'] ?? "";
          } else {
            userName = "ไม่ทราบชื่อผู้ใช้";
          }
        }

        bool isPendingWithdraw = type == 'withdraw' && status == 'pending';

        return InkWell(
          onTap: isPendingWithdraw
              ? () => _showWithdrawalActionDialog(context, docId, uid, data, userName)
              : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPendingWithdraw 
                  ? (isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.05)) 
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPendingWithdraw 
                    ? Colors.orangeAccent 
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                width: isPendingWithdraw ? 1.5 : 1.0,
              ),
              boxShadow: isPendingWithdraw ? [
                BoxShadow(
                  color: Colors.orangeAccent.withOpacity(0.2), 
                  blurRadius: 8, 
                  spreadRadius: 1
                )
              ] : [],
            ),
            child: Row(
              children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    backgroundImage: userImage.isNotEmpty
                        ? NetworkImage(userImage)
                        : null,
                    child: userImage.isEmpty
                        ? Icon(
                            CupertinoIcons.person_fill,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isAppIn ? Colors.green : Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                      child: Icon(
                        isAppIn
                            ? CupertinoIcons.arrow_down_left
                            : CupertinoIcons.arrow_up_right,
                        size: 10,
                        color: Colors.white,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTransactionTypeName(type),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
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

                      color: isAppIn ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusBadge(status),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'success':
        color = Colors.green;
        label = "สำเร็จ";
        break;
      case 'cancelled':
        color = Colors.red;
        label = "ยกเลิก";
        break;
      default:
        color = Colors.orange;
        label = "รอดำเนินการ";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text_search,
            size: 60,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          const SizedBox(height: 15),
          Text(
            "ไม่พบประวัติธุรกรรม",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
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
}
