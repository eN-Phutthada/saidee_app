import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

class ManageMasterDataScreen extends StatefulWidget {
  final String collection; // 'categories' หรือ 'types'
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

    Get.defaultDialog(
      title: docId == null ? "เพิ่ม${widget.title}" : "แก้ไข${widget.title}",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "ชื่อ${widget.title}",
                hintText: "กรอกชื่อภาษาไทยหรืออังกฤษ",
              ),
            ),
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                title: const Text("เปิดใช้งาน"),
                value: isActive,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => isActive = val),
              ),
            ),
          ],
        ),
      ),
      textConfirm: "บันทึก",
      textCancel: "ยกเลิก",
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryColor,
      cancelTextColor: Colors.black,
      onConfirm: () async {
        if (_nameController.text.isEmpty) {
          Get.snackbar(
            "แจ้งเตือน",
            "กรุณากรอกข้อมูล",
            backgroundColor: Colors.red.withOpacity(0.5),
            colorText: Colors.white,
          );
          return;
        }

        final data = {
          'name': _nameController.text.trim(),
          'status': isActive ? 'active' : 'inactive',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        try {
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
          _nameController.clear();
          Get.snackbar(
            "สำเร็จ",
            "บันทึกข้อมูลเรียบร้อย",
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } catch (e) {
          Get.snackbar("Error", e.toString());
        }
      },
    );
  }

  void _deleteItem(String docId) {
    Get.defaultDialog(
      title: "ยืนยันการลบ",
      middleText: "คุณแน่ใจหรือไม่ที่จะลบรายการนี้?",
      textConfirm: "ลบ",
      textCancel: "ยกเลิก",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: Colors.black,
      onConfirm: () {
        FirebaseFirestore.instance
            .collection(widget.collection)
            .doc(docId)
            .delete();
        Get.back();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("จัดการ${widget.title}")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEditDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(widget.collection)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("เกิดข้อผิดพลาดในการโหลดข้อมูล"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty)
            return Center(child: Text("ยังไม่มีข้อมูล${widget.title}"));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isActive = data['status'] == 'active';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    child: Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    data['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isActive ? "เปิดใช้งาน" : "ปิดใช้งาน",
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(
                          docId: docs[index].id,
                          currentName: data['name'],
                          currentStatus: isActive,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem(docs[index].id),
                      ),
                    ],
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
