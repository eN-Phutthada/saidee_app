import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CouponDataHelper {
  static Future<void> setupSampleCoupons() async {
    final db = FirebaseFirestore.instance;
    final couponCollection = db.collection('coupons');

    // รายการคูปองจำลองที่เหมาะกับร้านเสื้อผ้ามือสอง
    final List<Map<String, dynamic>> coupons = [
      {
        'code': 'WELCOME50',
        'type': 'percent',
        'value': 50.0,
        'min_order': 300.0,
        'desc': 'ส่วนลดต้อนรับลูกค้าใหม่',
      },
      {
        'code': 'SAIDEE10',
        'type': 'percent',
        'value': 10.0,
        'min_order': 500.0,
        'desc': 'ส่วนลดพิเศษสำหรับแฟนเพจ Saidee',
      },
      {
        'code': 'LUCKY20',
        'type': 'percent',
        'value': 20.0,
        'min_order': 1000.0,
        'desc': 'คูปองลดหนักจัดเต็มเมื่อช้อปครบพัน',
      },
      {
        'code': 'SAVE20',
        'type': 'percent',
        'value': 20.0,
        'min_order': 150.0,
        'desc': 'ลดเล็กน้อยสำหรับคำสั่งซื้อขนาดเล็ก',
      },
      {
        'code': 'FASHION100',
        'type': 'percent',
        'value': 10.0,
        'min_order': 800.0,
        'desc': 'คุ้มสุดๆ ลดทันที 100 บาท',
      },
    ];

    try {
      debugPrint("⏳ กำลังรีเซ็ตข้อมูลคูปอง...");
      // ล้างข้อมูลเก่า (Optional)
      var oldDocs = await couponCollection.get();
      for (var doc in oldDocs.docs) {
        await doc.reference.delete();
      }

      debugPrint("⏳ กำลังเพิ่มคูปองจำลอง...");
      for (var coupon in coupons) {
        await couponCollection.add(coupon);
      }
      debugPrint("✅ เพิ่มข้อมูลคูปองสำเร็จ!");
    } catch (e) {
      debugPrint("❌ เกิดข้อผิดพลาด: $e");
    }
  }
}
