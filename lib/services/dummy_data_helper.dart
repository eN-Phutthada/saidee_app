import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DummyDataHelper {
  static final Random _random = Random();

  static final List<String> _categories = ['เสื้อผ้าผู้ชาย', 'เสื้อผ้าผู้หญิง'];
  static final List<String> _types = ['กางเกงขายาว', 'เสื้อยืด', 'กระโปรง'];
  static final List<String> _brands = ['Saidee'];
  static final List<String> _adjectives = [
    'คุณภาพดี',
    'รุ่นยอดฮิต',
    'เนื้อผ้าพรีเมียม',
    'ราคาถูก',
    'สภาพนางฟ้า',
  ];

  static final List<String> _fashionVideos = [
    'https://assets.mixkit.co/videos/preview/mixkit-girl-in-neon-clothing-in-a-dark-space-34534-large.mp4',
    'https://assets.mixkit.co/videos/preview/mixkit-young-woman-modelling-a-red-dress-41006-large.mp4',
    'https://assets.mixkit.co/videos/preview/mixkit-close-up-of-a-person-in-a-denim-jacket-41014-large.mp4',
  ];

  static Future<void> setupDummyData({int count = 10}) async {
    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("❌ กรุณาล็อกอินก่อนเพิ่มข้อมูลจำลอง");
      return;
    }

    try {
      print("⏳ กำลังเตรียมข้อมูลและสุ่มสร้างสินค้าแฟชั่น $count รายการ...");

      for (int i = 0; i < count; i++) {
        String randomType = _types[_random.nextInt(_types.length)];
        String randomCat = _categories[_random.nextInt(_categories.length)];
        String randomBrand = _brands[_random.nextInt(_brands.length)];
        String randomAdj = _adjectives[_random.nextInt(_adjectives.length)];

        String randomName = "$randomType $randomAdj";
        double randomPrice = (_random.nextInt(140) * 10) + 99.0;
        double randomWeight = (_random.nextInt(70) * 10) + 100.0;

        // ดึง Keyword ตามประเภทสินค้าเพื่อให้รูปภาพตรงกับชื่อ
        String imgKeyword = _getImgKeyword(randomType);
        int uniqueLock = _random.nextInt(1000);
        String identicalImageUrl =
            'https://loremflickr.com/500/500/$imgKeyword,fashion?lock=$uniqueLock';

        await db.collection('products').add({
          'sellerId': user.uid,
          'name': randomName,
          'type': randomType,
          'category': randomCat,
          'description':
              'เสื้อผ้ามือสองคัดเกรด รายการที่ ${i + 1} เนื้อผ้าดี ซักสะอาดพร้อมใช้งาน สภาพเหมือนใหม่ ไร้ตำหนิหนัก เหมาะสำหรับใส่เที่ยวหรือใส่ทำงาน',
          'price': randomPrice,
          'brand': randomBrand,
          'size': ['S', 'M', 'L', 'XL', 'Freesize'][_random.nextInt(5)],
          'condition': [
            'มือหนึ่ง (New)',
            'สภาพดี (Used-Good)',
            'มีตำหนิ (Defect)',
          ][_random.nextInt(3)],
          'weight': randomWeight,
          'images': [identicalImageUrl, identicalImageUrl, identicalImageUrl],
          'video': _fashionVideos[_random.nextInt(_fashionVideos.length)],
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print("✅ เพิ่มข้อมูลสินค้าแฟชั่นมือสองสำเร็จแล้ว!");
    } catch (e) {
      print("❌ เกิดข้อผิดพลาด: $e");
    }
  }

  static String _getImgKeyword(String type) {
    switch (type) {
      case 'กางเกงขายาว':
        return 'jeans,trousers';
      case 'เสื้อยืด':
        return 'tshirt,shirt';
      case 'กระโปรง':
        return 'skirt,dress';
      default:
        return 'clothing';
    }
  }
}
