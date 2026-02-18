import 'package:flutter/cupertino.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("จัดการคูปองส่วนลด")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(CupertinoIcons.add, color: Colors.white),
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(
                    CupertinoIcons.ticket,
                    color: Colors.orange,
                  ),
                  title: Text("Code: ${data['code']}"),
                  subtitle: Text(
                    "ลด ${data['value']} บาท (ขั้นต่ำ ${data['min_order']})",
                  ),
                  trailing: const Icon(
                    CupertinoIcons.delete,
                    color: Colors.grey,
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
