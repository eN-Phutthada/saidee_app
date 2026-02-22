import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DummyDataHelper {
  static final Random _random = Random();

  // ข้อมูลพื้นฐานตามโจทย์
  static final List<String> _categories = ['เสื้อผ้าผู้ชาย', 'เสื้อผ้าผู้หญิง'];

  static final List<String> _types = ['กางเกงขายาว', 'เสื้อยืด', 'กระโปรง'];

  // ส่วนประกอบสำหรับสุ่มชื่อสินค้า
  static final List<String> _brands = [
    'Saidee',
    'Minimal',
    'StreetWear',
    'Vintage Co.',
    'Urban',
  ];
  static final List<String> _adjectives = [
    'คุณภาพดี',
    'รุ่นยอดฮิต',
    'เนื้อผ้าพรีเมียม',
    'ราคาถูก',
    'สภาพนางฟ้า',
  ];

  static Future<void> setupDummyData({int count = 10}) async {
    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("❌ กรุณาล็อกอินก่อนเพิ่มข้อมูลจำลอง");
      return;
    }

    try {
      print("⏳ กำลังเริ่มเตรียมข้อมูลพื้นฐาน...");

      // 1. เพิ่มหมวดหมู่ (Categories) ลง Firestore
      for (var cat in _categories) {
        await db.collection('categories').doc(cat).set({'name': cat});
      }

      // 2. เพิ่มประเภทสินค้า (Types) ลง Firestore
      for (var type in _types) {
        await db.collection('types').doc(type).set({'name': type});
      }

      print("⏳ กำลังสุ่มสร้างสินค้าจำนวน $count รายการ...");

      // 3. สุ่มสร้างสินค้า
      for (int i = 0; i < count; i++) {
        String randomType = _types[_random.nextInt(_types.length)];
        String randomCat = _categories[_random.nextInt(_categories.length)];
        String randomBrand = _brands[_random.nextInt(_brands.length)];
        String randomAdj = _adjectives[_random.nextInt(_adjectives.length)];

        // สุ่มชื่อสินค้า เช่น "Saidee เสื้อยืด รุ่นยอดฮิต"
        String randomName = "$randomBrand $randomType $randomAdj";

        // สุ่มราคา 99 - 1500 บาท
        double randomPrice = (_random.nextInt(140) * 10) + 99.0;

        // สุ่มน้ำหนัก 100 - 800 กรัม
        double randomWeight = (_random.nextInt(70) * 10) + 100.0;

        await db.collection('products').add({
          'sellerId': user.uid,
          'name': randomName,
          'type': randomType,
          'category': randomCat,
          'description':
              'สินค้าคุณภาพดีจากโปรเจกต์ Saidee รายการที่ ${i + 1} รายละเอียดสินค้าเบื้องต้นสวมใส่สบาย ทนทาน เหมาะกับทุกโอกาส',
          'price': randomPrice,
          'brand': randomBrand,
          'size': ['S', 'M', 'L', 'XL', 'Freesize'][_random.nextInt(5)],
          'condition': [
            'มือหนึ่ง (New)',
            'สภาพดี (Used-Good)',
            'มีตำหนิ (Defect)',
          ][_random.nextInt(3)],
          'weight': randomWeight,
          'images': [
            'https://picsum.photos/seed/${_random.nextInt(1000)}/500/500',
            'https://picsum.photos/seed/${_random.nextInt(1000)}/500/500',
            'https://picsum.photos/seed/${_random.nextInt(1000)}/500/500',
          ],
          'video':
              'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print("✅ เพิ่มข้อมูลจำลองสำเร็จเรียบร้อยแล้ว!");
    } catch (e) {
      print("❌ เกิดข้อผิดพลาด: $e");
    }
  }
}
