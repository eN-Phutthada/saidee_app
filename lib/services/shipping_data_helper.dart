import 'package:cloud_firestore/cloud_firestore.dart';

class ShippingDataHelper {
  static Future<void> setupRealShippingData() async {
    final db = FirebaseFirestore.instance;
    final shippingCollection = db.collection('shipping');

    // ข้อมูลบริษัทขนส่งจริง (ราคาประมาณการสำหรับพัสดุขนาดเล็ก/ซอง)
    final List<Map<String, dynamic>> shippingProviders = [
      // --- ไปรษณีย์ไทย (EMS) - เน้นความเร็ว ---
      {
        'name': 'Thailand Post (EMS)',
        'weight_min': 0,
        'weight_max': 500,
        'price': 42.0,
        'status': 'active',
      },
      {
        'name': 'Thailand Post (EMS)',
        'weight_min': 501,
        'weight_max': 1000,
        'price': 52.0,
        'status': 'active',
      },

      // --- Flash Express - ราคาย่อมเยาสำหรับแม่ค้าออนไลน์ ---
      {
        'name': 'Flash Express',
        'weight_min': 0,
        'weight_max': 1000,
        'price': 25.0, // ราคาเริ่มต้นโปรโมชั่น/พื้นที่ใกล้เคียง
        'status': 'active',
      },
      {
        'name': 'Flash Express',
        'weight_min': 1001,
        'weight_max': 2000,
        'price': 35.0,
        'status': 'active',
      },

      // --- Kerry Express (SF Express) - มาตรฐานสูง ---
      {
        'name': 'Kerry Express',
        'weight_min': 0,
        'weight_max': 500,
        'price': 35.0,
        'status': 'active',
      },
      {
        'name': 'Kerry Express',
        'weight_min': 501,
        'weight_max': 1500,
        'price': 45.0,
        'status': 'active',
      },

      // --- J&T Express - เน้นส่งทุกวันไม่มีวันหยุด ---
      {
        'name': 'J&T Express',
        'weight_min': 0,
        'weight_max': 1000,
        'price': 22.0,
        'status': 'active',
      },
      {
        'name': 'J&T Express',
        'weight_min': 1001,
        'weight_max': 3000,
        'price': 30.0,
        'status': 'active',
      },
    ];

    try {
      print("⏳ กำลังล้างข้อมูลขนส่งเก่า...");
      // ลบข้อมูลเก่าก่อนเพื่อให้ข้อมูลใหม่สะอาด (Optional)
      var oldDocs = await shippingCollection.get();
      for (var doc in oldDocs.docs) {
        await doc.reference.delete();
      }

      print("⏳ กำลังเพิ่มข้อมูลขนส่งจริง...");
      for (var provider in shippingProviders) {
        await shippingCollection.add(provider);
      }
      print("✅ เพิ่มข้อมูลบริษัทขนส่งสำเร็จ!");
    } catch (e) {
      print("❌ เกิดข้อผิดพลาด: $e");
    }
  }
}
