import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementDataHelper {
  static Future<void> setupSampleAnnouncements() async {
    final db = FirebaseFirestore.instance;
    final collection = db.collection('announcements');

    final List<Map<String, dynamic>> announcements = [
      {
        'title': 'ยินดีต้อนรับสู่ SAIDEE App! ✨',
        'detail':
            'แหล่งรวมเสื้อผ้ามือสองคุณภาพดีที่คุณวางใจได้ เริ่มต้นช้อปวันนี้รับส่วนลดทันที 50 บาท เมื่อกรอกโค้ด WELCOME50 ในหน้าชำระเงิน',
      },
      {
        'title': '📢 แจ้งเตือนความปลอดภัยในการช้อปปิ้ง',
        'detail':
            'เพื่อความปลอดภัยของท่าน โปรดชำระเงินผ่านระบบ SAIDEE Wallet ภายในแอปเท่านั้น และหลีกเลี่ยงการโอนเงินผ่านบัญชีส่วนตัวภายนอกเพื่อป้องกันมิจฉาชีพ',
      },
      {
        'title': '🚚 ฟีเจอร์ใหม่! เลือกขนส่งได้ตามใจคุณ',
        'detail':
            'ตอนนี้ผู้ขายสามารถเลือกบริษัทขนส่งที่สะดวกได้แล้ว ไม่ว่าจะเป็น Flash Express, J&T หรือไปรษณีย์ไทย เพื่อความสะดวกและรวดเร็วในการส่งสินค้า',
      },
      {
        'title': '👕 เคล็ดลับการลงขายสินค้าให้ปัง!',
        'detail':
            'ควรถ่ายรูปในที่แสงสว่างเพียงพอ ระบุไซส์และตำหนิให้ชัดเจน เพื่อช่วยให้ผู้ซื้อตัดสินใจได้ง่ายขึ้นและลดการคืนสินค้าครับ',
      },
      {
        'title': '🛠️ แจ้งปิดปรับปรุงระบบชั่วคราว',
        'detail':
            'ระบบจะทำการปิดปรับปรุงเพื่ออัปเกรดเซิร์ฟเวอร์ในวันที่ 5 มีนาคม 2026 เวลา 02:00 - 04:00 น. ขออภัยในความไม่สะดวกครับ',
      },
    ];

    try {
      print("⏳ กำลังรีเซ็ตประกาศข่าวสาร...");
      // ล้างข้อมูลเก่า
      var oldDocs = await collection.get();
      for (var doc in oldDocs.docs) {
        await doc.reference.delete();
      }

      // เพิ่มข้อมูลใหม่
      for (var announcement in announcements) {
        announcement['createdAt'] = FieldValue.serverTimestamp();
        announcement['updatedAt'] = FieldValue.serverTimestamp();
        await collection.add(announcement);
      }
      print("✅ เพิ่มประกาศตัวอย่างสำเร็จ!");
    } catch (e) {
      print("❌ Error: $e");
    }
  }
}
