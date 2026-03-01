import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/coupon_data_helper.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

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
  bool _isActive = true;

  void _showEditDialog({String? docId, Map<String, dynamic>? data}) {
    _codeController.text = data?['code'] ?? '';
    _valueController.text = data?['value']?.toString() ?? '';
    _minOrderController.text = data?['min_order']?.toString() ?? '';
    _descController.text = data?['desc'] ?? '';
    _discountType = data?['type'] ?? 'percent';
    _isActive = data?['status'] == 'active' || data?['status'] == null;

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
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        "เปิดใช้งานคูปองนี้",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      value: _isActive,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
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
                            if (_codeController.text.isEmpty) {
                              Get.snackbar(
                                "ข้อมูลไม่ครบ",
                                "กรุณากรอกโค้ดคูปอง",
                                backgroundColor: Colors.orange,
                                colorText: Colors.white,
                              );
                              return;
                            }
                            final newData = {
                              'code': _codeController.text.trim().toUpperCase(),
                              'desc': _descController.text.trim(),
                              'type': _discountType,
                              'value':
                                  double.tryParse(_valueController.text) ?? 0,
                              'min_order':
                                  double.tryParse(_minOrderController.text) ??
                                  0,
                              'status': _isActive ? 'active' : 'inactive',
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
    final usageCheck = await FirebaseFirestore.instance
        .collection('orders')
        .where('couponCode', isEqualTo: code)
        .limit(1)
        .get();

    if (usageCheck.docs.isNotEmpty) {
      AppDialog.showCustomDialog(
        title: "ไม่สามารถลบได้",
        message:
            "มีการใช้คูปอง '$code' ในระบบคำสั่งซื้อแล้ว\nกรุณาแก้ไขและ 'ปิดการใช้งาน' แทนการลบ",
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    AppDialog.showCustomDialog(
      title: "ยืนยันการลบ",
      message: "คุณแน่ใจหรือไม่ที่จะลบคูปอง '$code' ทิ้งอย่างถาวร?",
      icon: CupertinoIcons.trash_fill,
      iconColor: Colors.red,
      confirmText: "ลบคูปอง",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () {
        FirebaseFirestore.instance.collection('coupons').doc(docId).delete();
        Get.back();
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

              bool isActive =
                  data['status'] == 'active' || data['status'] == null;

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
                          Icon(
                            CupertinoIcons.ticket_fill,
                            color: isActive
                                ? AppTheme.primaryColor
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            data['code'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isActive
                                  ? AppTheme.primaryColor
                                  : Colors.grey,
                              decoration: !isActive
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? "เปิดใช้งาน" : "ปิดใช้งาน",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.green : Colors.red,
                              ),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isActive
                                        ? theme.colorScheme.onSurface
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildInfoBadge(
                                      discountLabel,
                                      isActive ? Colors.orange : Colors.grey,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildInfoBadge(
                                      "ขั้นต่ำ ${data['min_order']} ฿",
                                      isActive ? Colors.blue : Colors.grey,
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
          padding: EdgeInsets.zero,
          onPressed: () => _showEditDialog(docId: docId, data: data),
        ),
        const SizedBox(width: 15),
        IconButton(
          icon: const Icon(CupertinoIcons.delete, color: Colors.red, size: 20),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          onPressed: () => _deleteCoupon(docId, data['code']),
        ),
      ],
    );
  }
}
