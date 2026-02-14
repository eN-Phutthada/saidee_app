import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

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

    Get.defaultDialog(
      title: docId == null ? "เพิ่มขนส่ง" : "แก้ไขขนส่ง",
      content: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "ชื่อบริษัทขนส่ง"),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minWeightController,
                  decoration: const InputDecoration(labelText: "นน.ต่ำสุด (g)"),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxWeightController,
                  decoration: const InputDecoration(labelText: "นน.สูงสุด (g)"),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: "ค่าส่ง (บาท)"),
            keyboardType: TextInputType.number,
          ),
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
      onConfirm: () async {
        final newData = {
          'name': _nameController.text,
          'weight_min': double.tryParse(_minWeightController.text) ?? 0,
          'weight_max': double.tryParse(_maxWeightController.text) ?? 0,
          'price': double.tryParse(_priceController.text) ?? 0,
          'status': isActive ? 'active' : 'inactive',
        };

        if (docId == null) {
          await FirebaseFirestore.instance.collection('shipping').add(newData);
        } else {
          await FirebaseFirestore.instance
              .collection('shipping')
              .doc(docId)
              .update(newData);
        }
        Get.back();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("จัดการบริษัทขนส่ง")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEditDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('shipping').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name']),
                subtitle: Text(
                  "น้ำหนัก: ${data['weight_min']} - ${data['weight_max']} g | ราคา: ${data['price']} บาท",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditDialog(docId: doc.id, data: data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
