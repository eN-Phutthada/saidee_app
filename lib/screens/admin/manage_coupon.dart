import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/coupon_data_helper.dart';

class ManageCouponScreen extends StatefulWidget {
  const ManageCouponScreen({super.key});

  @override
  State<ManageCouponScreen> createState() => _ManageCouponScreenState();
}

class _ManageCouponScreenState extends State<ManageCouponScreen> {
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _descController = TextEditingController();
  String _discountType = 'percent';

  void _showEditDialog({String? docId, Map<String, dynamic>? data}) {
    _codeController.text = data?['code'] ?? '';
    _valueController.text = data?['value']?.toString() ?? '';
    _minOrderController.text = data?['min_order']?.toString() ?? '';
    _descController.text = data?['desc'] ?? '';
    _discountType = data?['type'] ?? 'percent';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.ticket_fill,
                      color: Colors.orange,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    docId == null ? "เพิ่มคูปองส่วนลด" : "แก้ไขคูปอง",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(
                    "โค้ดคูปอง (เช่น WELCOME50)",
                    _codeController,
                    isDark,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField("คำอธิบายคูปอง", _descController, isDark),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              "ลด %",
                              style: TextStyle(fontSize: 14),
                            ),
                            value: 'percent',
                            groupValue: _discountType,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) =>
                                setState(() => _discountType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              "ลด บาท",
                              style: TextStyle(fontSize: 14),
                            ),
                            value: 'flat',
                            groupValue: _discountType,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) =>
                                setState(() => _discountType = val!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "จำนวนลด",
                          _valueController,
                          isDark,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          "ขั้นต่ำ (฿)",
                          _minOrderController,
                          isDark,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_codeController.text.isEmpty) return;
                            final newData = {
                              'code': _codeController.text.trim().toUpperCase(),
                              'desc': _descController.text.trim(),
                              'type': _discountType,
                              'value':
                                  double.tryParse(_valueController.text) ?? 0,
                              'min_order':
                                  double.tryParse(_minOrderController.text) ??
                                  0,
                            };
                            if (docId == null) {
                              await FirebaseFirestore.instance
                                  .collection('coupons')
                                  .add(newData);
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('coupons')
                                  .doc(docId)
                                  .update(newData);
                            }
                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "บันทึก",
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
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _deleteCoupon(String docId, String code) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final usageCheck = await FirebaseFirestore.instance
        .collection('orders')
        .where('couponCode', isEqualTo: code)
        .limit(1)
        .get();

    if (usageCheck.docs.isNotEmpty) {
      _showWarningDialog(
        theme,
        "ไม่สามารถลบได้",
        "มีการใช้คูปอง '$code' ในระบบคำสั่งซื้อแล้ว\nกรุณาปิดการใช้งานแทนการลบ",
      );
      return;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconCircle(Colors.red, CupertinoIcons.trash_fill),
              const SizedBox(height: 20),
              const Text(
                "ยืนยันการลบ",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "คุณแน่ใจหรือไม่ที่จะลบคูปอง '$code' ?",
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
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('coupons')
                            .doc(docId)
                            .delete();
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ลบ",
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
          "จัดการคูปองส่วนลด",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => CouponDataHelper.setupSampleCoupons(),
            tooltip: "รีเซ็ตเป็นข้อมูลจริง",
          ),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: const Text(
          "เพิ่มคูปอง",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showEditDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('coupons').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "ไม่มีข้อมูลคูปอง",
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 100),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String discountLabel = data['type'] == 'percent'
                  ? "ลด ${data['value']}%"
                  : "ลด ${data['value']} ฿";

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
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
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A2F)
                            : const Color(0xFFE8F5E9),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.ticket_fill,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            data['code'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Spacer(),
                          _buildSmallActionButtons(doc.id, data),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['desc'] ?? 'ไม่มีคำอธิบาย',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    _buildInfoBadge(
                                      discountLabel,
                                      Colors.orange,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildInfoBadge(
                                      "ขั้นต่ำ ${data['min_order']} ฿",
                                      Colors.blue,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool isDark, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSmallActionButtons(String docId, Map<String, dynamic> data) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(CupertinoIcons.pencil, color: Colors.blue, size: 20),
          constraints: const BoxConstraints(),
          onPressed: () => _showEditDialog(docId: docId, data: data),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(CupertinoIcons.delete, color: Colors.red, size: 20),
          constraints: const BoxConstraints(),
          onPressed: () => _deleteCoupon(docId, data['code']),
        ),
      ],
    );
  }

  Widget _buildIconCircle(Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 50),
    );
  }

  void _showWarningDialog(ThemeData theme, String title, String msg) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconCircle(
                Colors.orange,
                CupertinoIcons.exclamationmark_triangle_fill,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text("ตกลง"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
