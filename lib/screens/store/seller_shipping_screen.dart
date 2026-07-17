import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class SellerShippingScreen extends StatefulWidget {
  final String sellerId;

  const SellerShippingScreen({super.key, required this.sellerId});

  @override
  State<SellerShippingScreen> createState() => _SellerShippingScreenState();
}

class _SellerShippingScreenState extends State<SellerShippingScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, List<Map<String, dynamic>>> _shippingGroups = {};

  String? _selectedShippingCompany;

  @override
  void initState() {
    super.initState();
    _loadShippingData();
  }

  Future<void> _loadShippingData() async {
    try {
      var shippingSnap = await FirebaseFirestore.instance
          .collection('shipping')
          .where('status', isEqualTo: 'active')
          .get();

      Map<String, List<Map<String, dynamic>>> tempGroups = {};

      for (var doc in shippingSnap.docs) {
        var data = doc.data();
        String name = data['name'] ?? '';
        if (name.isNotEmpty) {
          if (!tempGroups.containsKey(name)) {
            tempGroups[name] = [];
          }
          tempGroups[name]!.add(data);
        }
      }

      for (var key in tempGroups.keys) {
        tempGroups[key]!.sort((a, b) {
          double weightA = double.tryParse(a['weight_min'].toString()) ?? 0;
          double weightB = double.tryParse(b['weight_min'].toString()) ?? 0;
          return weightA.compareTo(weightB);
        });
      }

      var userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .get();

      String? savedCompany;
      if (userSnap.exists) {
        var data = userSnap.data() as Map<String, dynamic>;
        if (data.containsKey('enabled_shipping')) {
          List enabledList = data['enabled_shipping'] ?? [];
          if (enabledList.isNotEmpty) {
            savedCompany = enabledList.first.toString();
          }
        }
      }

      setState(() {
        _shippingGroups = tempGroups;
        _selectedShippingCompany = savedCompany;
        _isLoading = false;
      });
    } catch (e) {
      AppDialog.showCustomDialog(
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถโหลดข้อมูลขนส่งได้",
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveShippingPreferences() async {
    setState(() => _isSaving = true);
    try {
      List<String> dataToSave = _selectedShippingCompany != null
          ? [_selectedShippingCompany!]
          : [];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .update({'enabled_shipping': dataToSave});

      AppDialog.showCustomDialog(
        title: "บันทึกสำเร็จ",
        message: "อัปเดตบริการขนส่งของร้านคุณเรียบร้อยแล้ว",
        icon: CupertinoIcons.check_mark_circled_solid,
        iconColor: Colors.green,
        confirmText: "ตกลง",
        onConfirm: () {
          Get.back();
          Get.back();
        },
      );
    } catch (e) {
      AppDialog.showCustomDialog(
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถบันทึกข้อมูลได้",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    List<String> companyNames = _shippingGroups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "เลือกบริการขนส่ง",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : companyNames.isEmpty
          ? Center(
              child: Text(
                "ยังไม่มีบริการขนส่งในระบบ\nกรุณาติดต่อผู้ดูแลระบบ",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ตั้งค่าช่องทางการจัดส่ง (เลือกได้ 1 อย่าง)",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "เลือกบริการขนส่งที่ร้านของคุณสะดวกที่สุดเพียง 1 รายการเพื่อใช้จัดส่งสินค้าให้ลูกค้า",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 25),
                  ...companyNames.map((company) {
                    bool isEnabled = _selectedShippingCompany == company;
                    List<Map<String, dynamic>> rates =
                        _shippingGroups[company]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isEnabled
                              ? AppTheme.primaryColor.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.05,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isEnabled
                                        ? AppTheme.primaryColor.withValues(
                                            alpha: 0.1,
                                          )
                                        : Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.cube_box_fill,
                                    color: isEnabled
                                        ? AppTheme.primaryColor
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isEnabled ? "เลือกแล้ว" : "ไม่ได้เลือก",
                                        style: TextStyle(
                                          color: isEnabled
                                              ? AppTheme.primaryColor
                                              : Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isEnabled,
                                  activeThumbColor: AppTheme.primaryColor,
                                  onChanged: (bool value) {
                                    setState(() {
                                      if (value) {
                                        _selectedShippingCompany = company;
                                      } else {
                                        _selectedShippingCompany = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[900]
                                  : Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(15),
                              ),
                            ),
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "เรทค่าจัดส่ง",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...rates.map((rate) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "น้ำหนัก ${rate['weight_min']} - ${rate['weight_max']} g",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "${rate['price']} ฿",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading || companyNames.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveShippingPreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "บันทึกการตั้งค่า",
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
