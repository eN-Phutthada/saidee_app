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
      content: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: "ชื่อ${widget.title}"),
          ),
          const SizedBox(height: 10),
          // สถานะเปิด/ปิดใช้งาน (ตามเอกสารข้อ 3 หน้า 1)
          StatefulBuilder(
            builder: (context, setState) => SwitchListTile(
              title: const Text("เปิดใช้งาน"),
              value: isActive,
              onChanged: (val) => setState(() => isActive = val),
            ),
          ),
        ],
      ),
      textConfirm: "บันทึก",
      textCancel: "ยกเลิก",
      confirmTextColor: Colors.white,
      onConfirm: () async {
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
        _nameController.clear();
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
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isActive = data['status'] == 'active';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Text(
                    isActive ? "เปิดใช้งาน" : "ปิดใช้งาน",
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
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
