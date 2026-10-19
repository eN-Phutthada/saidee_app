import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactService {
  static const String adminHotlineFormatted = "064-749-0079";
  static const String adminHotlineRaw = "0647490079";

  /// โทรออกไปยังสายด่วนแอดมินทันที
  static Future<bool> callHotline() async {
    return await makePhoneCall(adminHotlineRaw, formattedNumber: adminHotlineFormatted);
  }

  /// สั่งเปิดแอปโทรศัพท์พร้อมเบอร์โทร
  static Future<bool> makePhoneCall(String phoneNumber, {String? formattedNumber}) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final display = formattedNumber ?? phoneNumber;
    final Uri telUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(telUri)) {
        final launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
      // กรณีไม่สามารถเปิด dialer ได้โดยตรง ให้ fallback เป็นการคัดลอกลงคลิปบอร์ด
      await copyPhoneNumber(cleanNumber, formattedNumber: display);
      return false;
    } catch (e) {
      debugPrint("Error launching phone call to $cleanNumber: $e");
      await copyPhoneNumber(cleanNumber, formattedNumber: display);
      return false;
    }
  }

  /// คัดลอกเบอร์โทรลงคลิปบอร์ด พร้อมแสดง Snackbar แจ้งเตือนภาษาไทย
  static Future<void> copyPhoneNumber(String phoneNumber, {String? formattedNumber}) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final display = formattedNumber ?? phoneNumber;

    await Clipboard.setData(ClipboardData(text: cleanNumber));
    Get.snackbar(
      "คัดลอกเบอร์โทรเรียบร้อย",
      "คัดลอก $display ไปยังคลิปบอร์ดแล้ว สามารถนำไปวางในแอปโทรศัพท์ได้ทันที",
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(15),
      duration: const Duration(seconds: 3),
      icon: const Icon(CupertinoIcons.phone_fill, color: Colors.green),
    );
  }
}
