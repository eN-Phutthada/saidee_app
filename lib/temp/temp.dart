import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

// ignore: unused_element
Future<void> _setupFirstAdmin() async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: "admin@saidee.com",
          password: "password1234",
        );

    await FirebaseFirestore.instance
        .collection('admins')
        .doc(userCredential.user!.uid)
        .set({
          'admin_id': 1,
          'email': "admin@saidee.com",
          'password': "password1234",
          'role': 'admin',
          'created_at': FieldValue.serverTimestamp(),
        });

    Get.snackbar("สำเร็จ", "สร้างบัญชี Admin เรียบร้อยแล้ว");
  } catch (e) {
    Get.snackbar("Error", e.toString());
  }
}
