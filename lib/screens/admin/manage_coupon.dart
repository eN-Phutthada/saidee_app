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

  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _selectDate(
    BuildContext context,
    bool isStart,
    StateSetter setModalState,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? (_startDate ?? DateTime.now())),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setModalState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showEditSheet({String? docId, Map<String, dynamic>? data}) {
    _codeController.text = data?['code'] ?? '';
    _valueController.text = data?['value']?.toString() ?? '';
    _minOrderController.text = data?['min_order']?.toString() ?? '';
    _isActive = data?['status'] == 'active' || data?['status'] == null;

    if (data?['start_date'] != null) {
      _startDate = (data?['start_date'] as Timestamp).toDate();
    } else {
      _startDate = DateTime.now();
    }

    if (data?['end_date'] != null) {
      _endDate = (data?['end_date'] as Timestamp).toDate();
    } else {
      _endDate = DateTime.now().add(const Duration(days: 30));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.ticket_fill,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      docId == null ? "สร้างคูปองใหม่" : "แก้ไขข้อมูลคูปอง",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                _buildTextField(
                  "รหัสโค้ดคูปอง (เช่น WELCOME50)",
                  _codeController,
                  isDark,
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "% ส่วนลด",
                        _valueController,
                        isDark,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildTextField(
                        "สั่งขั้นต่ำ (฿)",
                        _minOrderController,
                        isDark,
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, true, setModalState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "เริ่มใช้งาน",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _startDate != null
                                        ? "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}"
                                        : "เลือกวันที่",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _startDate != null
                                          ? theme.colorScheme.onSurface
                                          : Colors.grey,
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.calendar,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, false, setModalState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "วันสิ้นสุด",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _endDate != null
                                        ? "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}"
                                        : "เลือกวันที่",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _endDate != null
                                          ? theme.colorScheme.onSurface
                                          : Colors.grey,
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.calendar,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

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
                    onChanged: (val) => setModalState(() => _isActive = val),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_codeController.text.isEmpty) {
                        Get.snackbar(
                          "ข้อมูลไม่ครบ",
                          "กรุณากรอกรหัสโค้ดคูปอง",
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      if (_startDate == null || _endDate == null) {
                        Get.snackbar(
                          "ข้อมูลไม่ครบ",
                          "กรุณาระบุวันเริ่มต้นและสิ้นสุด",
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      final newData = {
                        'code': _codeController.text.trim().toUpperCase(),
                        'type': 'percent',
                        'value': double.tryParse(_valueController.text) ?? 0,
                        'min_order':
                            double.tryParse(_minOrderController.text) ?? 0,
                        'start_date': Timestamp.fromDate(_startDate!),
                        'end_date': Timestamp.fromDate(_endDate!),
                        'status': _isActive ? 'active' : 'inactive',
                      };

                      Get.dialog(
                        const Center(child: CircularProgressIndicator()),
                        barrierDismissible: false,
                      );

                      try {
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
                        Get.back();
                        Get.snackbar(
                          "สำเร็จ",
                          docId == null
                              ? "เพิ่มคูปองใหม่แล้ว"
                              : "แก้ไขคูปองเรียบร้อย",
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      } catch (e) {
                        Get.back();
                        Get.snackbar(
                          "ข้อผิดพลาด",
                          "ไม่สามารถบันทึกข้อมูลได้",
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "บันทึกข้อมูลคูปอง",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
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
            "มีการใช้คูปอง '$code' ในระบบคำสั่งซื้อแล้ว\nกรุณา 'ปิดการใช้งาน' แทนการลบเพื่อเก็บเป็นประวัติ",
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.orange,
        confirmText: "เข้าใจแล้ว",
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
            tooltip: "รีเซ็ตเป็นข้อมูลตัวอย่าง",
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
          "เพิ่มคูปองใหม่",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showEditSheet(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('coupons')
            .orderBy('status')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
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

              String discountLabel = "ลด ${data['value']}%";
              bool isActive = data['status'] == 'active';

              String dateRange = "ไม่ระบุเวลา";
              if (data['start_date'] != null && data['end_date'] != null) {
                DateTime sDate = (data['start_date'] as Timestamp).toDate();
                DateTime eDate = (data['end_date'] as Timestamp).toDate();
                dateRange =
                    "${sDate.day}/${sDate.month}/${sDate.year} - ${eDate.day}/${eDate.month}/${eDate.year}";
              }

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1),
                          ),
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.calendar,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateRange,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
        labelStyle: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
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
          fontSize: 13,
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
          onPressed: () => _showEditSheet(docId: docId, data: data),
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
