import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ManageReportScreen extends StatelessWidget {
  const ManageReportScreen({super.key});

  void _banUser(String userId) {
    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'status': 'banned',
    });
    Get.snackbar(
      "Admin",
      "ระงับการใช้งานผู้ใช้เรียบร้อยแล้ว",
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("รายการแจ้งปัญหา & ผู้ใช้")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text("ไม่มีรายงานปัญหา"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var report =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: Text(report['topic'] ?? 'หัวข้อ'),
                  subtitle: Text("รายงานผู้ใช้ ID: ${report['reported_id']}"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("รายละเอียด: ${report['detail']}"),
                          const SizedBox(height: 10),
                          if (report['image_proof'] != null &&
                              report['image_proof'] != '')
                            Image.network(report['image_proof'], height: 150),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => _banUser(report['reported_id']),
                            icon: const Icon(Icons.block, color: Colors.white),
                            label: const Text(
                              "ระงับบัญชีผู้ใช้นี้ (Ban)",
                              style: TextStyle(color: Colors.white),
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
}
