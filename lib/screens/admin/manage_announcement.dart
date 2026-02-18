import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:saidee_app/config/theme.dart';

class ManageAnnouncementScreen extends StatefulWidget {
  const ManageAnnouncementScreen({super.key});

  @override
  State<ManageAnnouncementScreen> createState() =>
      _ManageAnnouncementScreenState();
}

class _ManageAnnouncementScreenState extends State<ManageAnnouncementScreen> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();

  void _postAnnouncement() {
    if (_titleController.text.isEmpty) return;

    FirebaseFirestore.instance.collection('announcements').add({
      'title': _titleController.text,
      'detail': _detailController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("จัดการประกาศข่าวสาร")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(CupertinoIcons.add, color: Colors.white),
        onPressed: () => Get.defaultDialog(
          title: "เพิ่มประกาศใหม่",
          content: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "หัวข้อ"),
              ),
              TextField(
                controller: _detailController,
                decoration: const InputDecoration(labelText: "รายละเอียด"),
                maxLines: 3,
              ),
            ],
          ),
          onConfirm: _postAnnouncement,
          textConfirm: "ประกาศ",
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
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
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(
                    data['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(data['detail']),
                  trailing: IconButton(
                    icon: const Icon(CupertinoIcons.delete, color: Colors.red),
                    onPressed: () =>
                        snapshot.data!.docs[index].reference.delete(),
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
