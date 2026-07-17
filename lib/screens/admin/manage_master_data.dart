import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class ManageMasterDataScreen extends StatefulWidget {
  final String collection;
  final String title;

  const ManageMasterDataScreen({
    super.key,
    required this.collection,
    required this.title,
  });

  @override
  State<ManageMasterDataScreen> createState() => _ManageMasterDataScreenState();
}

class _ManageMasterDataScreenState extends State<ManageMasterDataScreen> {
  final _nameController = TextEditingController();

  void _showEditDialog({
    String? docId,
    String? currentName,
    bool? currentStatus,
  }) {
    _nameController.text = currentName ?? '';
    bool isActive = currentStatus ?? true;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData dialogIcon = widget.collection == 'categories'
        ? CupertinoIcons.square_grid_2x2_fill
        : CupertinoIcons.tag_fill;

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
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    dialogIcon,
                    color: AppTheme.primaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  docId == null
                      ? "เพิ่ม${widget.title}"
                      : "แก้ไข${widget.title}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "ชื่อ${widget.title}",
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
                          "เปิดใช้งานสถานะ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: isActive,
                        activeThumbColor: AppTheme.primaryColor,
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
                          final data = {
                            'name': _nameController.text.trim(),
                            'status': isActive ? 'active' : 'inactive',
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            await FirebaseFirestore.instance
                                .collection(widget.collection)
                                .add(data);
                          } else {
                            await FirebaseFirestore.instance
                                .collection(widget.collection)
                                .doc(docId)
                                .update(data);
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

  Future<void> _deleteItem(String docId, String itemName) async {
    String queryField = widget.collection == 'categories' ? 'category' : 'type';
    final productCheck = await FirebaseFirestore.instance
        .collection('products')
        .where(queryField, isEqualTo: itemName)
        .limit(1)
        .get();

    if (productCheck.docs.isNotEmpty) {
      AppDialog.showCustomDialog(
        title: "ไม่สามารถลบได้",
        message:
            "มีการใช้งาน '$itemName' ในสินค้าอยู่\nกรุณาลบหรือแก้ไขสินค้าก่อนทำรายการนี้",
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: Colors.orange,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    AppDialog.showCustomDialog(
      title: "ยืนยันการลบ",
      message: "คุณแน่ใจหรือไม่ที่จะลบ '$itemName' ?",
      icon: CupertinoIcons.trash_fill,
      iconColor: Colors.red,
      confirmText: "ลบข้อมูล",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        await FirebaseFirestore.instance
            .collection(widget.collection)
            .doc(docId)
            .delete();
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
        title: Text(
          "จัดการ${widget.title}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
        label: Text(
          "เพิ่ม${widget.title}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () => _showEditDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(widget.collection)
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                "ยังไม่มีข้อมูล${widget.title}",
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              top: 15,
              bottom: 100,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isActive = data['status'] == 'active';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
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
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      child: Icon(
                        isActive
                            ? CupertinoIcons.checkmark_alt
                            : CupertinoIcons.xmark,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      data['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isActive ? "เปิดใช้งาน" : "ปิดใช้งาน",
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.pencil,
                            color: Colors.blue,
                          ),
                          onPressed: () => _showEditDialog(
                            docId: docs[index].id,
                            currentName: data['name'],
                            currentStatus: isActive,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _deleteItem(docs[index].id, data['name']),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
