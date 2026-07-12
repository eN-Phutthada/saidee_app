import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/services/shipping_data_helper.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class ManageShippingScreen extends StatefulWidget {
  const ManageShippingScreen({super.key});

  @override
  State<ManageShippingScreen> createState() => _ManageShippingScreenState();
}

class _ManageShippingScreenState extends State<ManageShippingScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _minWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();

  void _showEditDialog({String? docId, Map<String, dynamic>? data}) {
    _nameController.text = data?['name'] ?? '';
    _priceController.text = data?['price']?.toString() ?? '';
    _minWeightController.text = data?['weight_min']?.toString() ?? '';
    _maxWeightController.text = data?['weight_max']?.toString() ?? '';
    bool isActive = (data?['status'] ?? 'active') == 'active';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.cube_box_fill,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  docId == null ? "เพิ่มบริษัทขนส่ง" : "แก้ไขบริษัทขนส่ง",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "ชื่อบริษัทขนส่ง",
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minWeightController,
                        decoration: InputDecoration(
                          labelText: "นน.ต่ำสุด (g)",
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _maxWeightController,
                        decoration: InputDecoration(
                          labelText: "นน.สูงสุด (g)",
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: "ค่าจัดส่ง (บาท)",
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                StatefulBuilder(
                  builder: (context, setState) => Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        title: const Text(
                          "เปิดใช้งาน",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: isActive,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) => setState(() => isActive = val),
                      ),
                    ),
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
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
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
                        onPressed: () async {
                          if (_nameController.text.isEmpty) return;
                          final newData = {
                            'name': _nameController.text.trim(),
                            'weight_min':
                                double.tryParse(_minWeightController.text) ?? 0,
                            'weight_max':
                                double.tryParse(_maxWeightController.text) ?? 0,
                            'price':
                                double.tryParse(_priceController.text) ?? 0,
                            'status': isActive ? 'active' : 'inactive',
                          };
                          if (docId == null) {
                            await FirebaseFirestore.instance
                                .collection('shipping')
                                .add(newData);
                          } else {
                            await FirebaseFirestore.instance
                                .collection('shipping')
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
      barrierDismissible: false,
    );
  }

  Future<void> _deleteShipping(
    String docId,
    String shippingName,
    dynamic weightMin,
    dynamic weightMax,
  ) async {
    final String weightRange = "($weightMin - $weightMax g)";

    final orderCheck = await FirebaseFirestore.instance
        .collection('orders')
        .where('shippingId', isEqualTo: docId)
        .limit(1)
        .get();

    if (orderCheck.docs.isNotEmpty) {
      AppDialog.showCustomDialog(
        title: "ไม่สามารถลบได้",
        message:
            "มีการใช้งานเรทราคาของ '$shippingName' $weightRange ในระบบคำสั่งซื้ออยู่\nไม่สามารถลบรายการนี้ได้",
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    AppDialog.showCustomDialog(
      title: "ยืนยันการลบ",
      message:
          "คุณแน่ใจหรือไม่ที่จะลบเรทราคา \n'$shippingName' \nช่วงน้ำหนัก $weightRange ?",
      icon: CupertinoIcons.trash_fill,
      iconColor: Colors.red,
      confirmText: "ลบรายการนี้",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () {
        FirebaseFirestore.instance.collection('shipping').doc(docId).delete();
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
          "จัดการบริษัทขนส่ง",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ShippingDataHelper.setupRealShippingData(),
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
          "เพิ่มขนส่ง",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showEditDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('shipping').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "ไม่มีข้อมูลบริษัทขนส่ง",
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          Map<String, List<QueryDocumentSnapshot>> groupedShipping = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String companyName = data['name'] ?? 'ไม่ระบุชื่อบริษัท';
            if (!groupedShipping.containsKey(companyName)) {
              groupedShipping[companyName] = [];
            }
            groupedShipping[companyName]!.add(doc);
          }

          List<String> companyNames = groupedShipping.keys.toList();
          companyNames.sort();

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              top: 15,
              bottom: 100,
            ),
            itemCount: companyNames.length,
            itemBuilder: (context, index) {
              String companyName = companyNames[index];
              List<QueryDocumentSnapshot> tiers = groupedShipping[companyName]!;

              tiers.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                double weightA =
                    double.tryParse(dataA['weight_min'].toString()) ?? 0;
                double weightB =
                    double.tryParse(dataB['weight_min'].toString()) ?? 0;
                return weightA.compareTo(weightB);
              });

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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            CupertinoIcons.cube_box_fill,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    ...tiers.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      bool isActive = data['status'] == 'active';

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "น้ำหนัก: ${data['weight_min']} - ${data['weight_max']} g",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            "ค่าจัดส่ง: ${data['price']} ฿",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                  : Colors.red.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              isActive
                                                  ? "เปิดใช้งาน"
                                                  : "ปิดใช้งาน",
                                              style: TextStyle(
                                                color: isActive
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.pencil,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditDialog(
                                        docId: doc.id,
                                        data: data,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteShipping(
                                        doc.id,
                                        data['name'],
                                        data['weight_min'],
                                        data['weight_max'],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (doc != tiers.last)
                            Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                            ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
