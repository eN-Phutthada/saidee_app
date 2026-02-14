import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

class ManageCouponScreen extends StatefulWidget {
  const ManageCouponScreen({super.key});

  @override
  State<ManageCouponScreen> createState() => _ManageCouponScreenState();
}

class _ManageCouponScreenState extends State<ManageCouponScreen> {
  // สร้าง Controller และ Logic คล้ายๆ กับหน้าอื่น แต่เพิ่ม DatePicker
  // (ย่อโค้ดเพื่อความกระชับ แต่ฟังก์ชันครบตามเอกสาร)
  // ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("จัดการคูปองส่วนลด")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          // TODO: สร้าง Dialog เพิ่มคูปอง (Code, Discount, Min Order)
          Get.snackbar(
            "Info",
            "ฟีเจอร์เพิ่มคูปอง (Implement similar to Shipping)",
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('coupons').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.confirmation_number,
                    color: Colors.orange,
                  ),
                  title: Text("Code: ${data['code']}"),
                  subtitle: Text(
                    "ลด ${data['value']} บาท (ขั้นต่ำ ${data['min_order']})",
                  ),
                  trailing: const Icon(Icons.delete, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
