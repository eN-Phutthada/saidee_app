import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:saidee_app/config/theme.dart';
import '../../models/product_model.dart';
import '../store/store_profile_screen.dart';
import '../cart/cart_screen.dart';
import '../auth/login_screen.dart'; // เพิ่ม Import หน้า Login

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.video.isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.product.video))
            ..initialize().then((_) {
              setState(() {
                _isVideoInitialized = true;
              });
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // --- สร้างฟังก์ชัน Helper สำหรับเรียก Popup สวยๆ ---
  void _showCustomDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required VoidCallback onConfirm,
    bool showCancel = false,
    String cancelText = "ยกเลิก",
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 60),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  if (showCancel) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          cancelText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true, // ให้กดพื้นที่ว่างรอบๆ เพื่อปิดได้
    );
  }

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. กรณียังไม่ล็อกอิน -> แสดง Popup ให้ไปหน้า Login
    if (user == null) {
      _showCustomDialog(
        title: "กรุณาเข้าสู่ระบบ",
        message: "คุณต้องเข้าสู่ระบบสมาชิกก่อน จึงจะสามารถสั่งซื้อสินค้าได้",
        icon: CupertinoIcons.person_crop_circle_badge_exclam,
        iconColor: Colors.orange,
        confirmText: "เข้าสู่ระบบ",
        onConfirm: () {
          Get.back(); // ปิด Popup
          Get.to(() => const LoginScreen()); // ไปหน้า Login
        },
        showCancel: true,
      );
      return;
    }

    // 2. กรณีซื้อสินค้าตัวเอง -> แสดง Popup แจ้งเตือน
    if (user.uid == widget.product.sellerId) {
      _showCustomDialog(
        title: "ไม่สามารถทำรายการได้",
        message: "คุณไม่สามารถเพิ่มสินค้าของตัวเองลงในตะกร้าได้",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');
      final existingItem = await cartRef
          .where('productId', isEqualTo: widget.product.id)
          .get();

      // 3. กรณีมีสินค้าในตะกร้าอยู่แล้ว -> แสดง Popup ถามว่าจะไปตะกร้าไหม
      if (existingItem.docs.isNotEmpty) {
        _showCustomDialog(
          title: "สินค้าอยู่ในตะกร้าแล้ว",
          message:
              "สินค้านี้ถูกเพิ่มลงในตะกร้าของคุณไปแล้ว คุณต้องการไปยังตะกร้าสินค้าหรือไม่?",
          icon: CupertinoIcons.cart_badge_plus,
          iconColor: Colors.orange,
          confirmText: "ดูตะกร้า",
          cancelText: "ช้อปต่อ",
          showCancel: true,
          onConfirm: () {
            Get.back();
            Get.to(() => const CartScreen(showBackButton: true));
          },
        );
        return;
      }

      await cartRef.add({
        'productId': widget.product.id,
        'name': widget.product.name,
        'brand': widget.product.brand,
        'size': widget.product.size,
        'price': widget.product.price,
        'image': widget.product.images.isNotEmpty
            ? widget.product.images[0]
            : '',
        'sellerId': widget.product.sellerId,
        'weight': widget.product.weight,
        'quantity': 1,
        'addedAt': Timestamp.now(),
      });

      // 4. กรณีสำเร็จ -> แสดง Popup สีเขียว
      _showCustomDialog(
        title: "เพิ่มลงตะกร้าสำเร็จ!",
        message: "สินค้าถูกเพิ่มลงในตะกร้าของคุณเรียบร้อยแล้ว",
        icon: CupertinoIcons.checkmark_alt_circle_fill,
        iconColor: Colors.green,
        confirmText: "ดูตะกร้า",
        cancelText: "ช้อปต่อ",
        showCancel: true,
        onConfirm: () {
          Get.back();
          Get.to(() => const CartScreen(showBackButton: true));
        },
      );
    } catch (e) {
      // Error จากระบบ ให้ใช้ Snackbar ปกติไปก่อน เพราะไม่ได้ต้องการให้ User เลือกปุ่ม
      Get.snackbar(
        "Error",
        "เกิดข้อผิดพลาด: ${e.toString()}",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner =
        currentUser != null && currentUser.uid == widget.product.sellerId;
    final bool isAvailable = widget.product.status == 'active';

    List<Widget> mediaPages = [];

    // จัดการวิดีโอ (FittedBox)
    if (_isVideoInitialized && _videoController != null) {
      mediaPages.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
              if (!_videoController!.value.isPlaying)
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 30,
                  child: Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    mediaPages.addAll(
      widget.product.images
          .map(
            (img) => Image.network(
              img,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: const Icon(CupertinoIcons.exclamationmark_triangle),
              ),
            ),
          )
          .toList(),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 450,
                  width: double.infinity,
                  child: mediaPages.isNotEmpty
                      ? PageView.builder(
                          itemCount: mediaPages.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                            if (_isVideoInitialized &&
                                _videoController != null &&
                                index != 0)
                              _videoController!.pause();
                          },
                          itemBuilder: (context, index) => mediaPages[index],
                        )
                      : Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                        ),
                ),

                Positioned(
                  top: 50,
                  left: 15,
                  child: CircleAvatar(
                    backgroundColor: isDark ? Colors.black54 : Colors.white70,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                      onPressed: () => Get.back(),
                    ),
                  ),
                ),

                Positioned(
                  top: 50,
                  right: 15,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isDark
                            ? Colors.black54
                            : Colors.white70,
                        child: IconButton(
                          icon: Icon(
                            CupertinoIcons.heart,
                            color: theme.colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: isDark
                            ? Colors.black54
                            : Colors.white70,
                        child: IconButton(
                          icon: Icon(
                            CupertinoIcons.share,
                            color: theme.colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),

                if (mediaPages.length > 1)
                  Positioned(
                    bottom: 15,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        mediaPages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? AppTheme.primaryColor
                                : Colors.white.withOpacity(0.6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.brand.isNotEmpty
                        ? widget.product.brand
                        : "ไม่ระบุแบรนด์",
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.product.size,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${widget.product.price.toStringAsFixed(0)} ฿",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    child: Divider(
                      color: isDark ? Colors.grey[800] : Colors.black12,
                      thickness: 1,
                    ),
                  ),

                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.product.sellerId)
                        .get(),
                    builder: (context, snapshot) {
                      String sellerName = "กำลังโหลด...";
                      String sellerImage = "";

                      if (snapshot.hasData && snapshot.data!.exists) {
                        var userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        sellerName = userData['name'] ?? "ผู้ขายไม่ระบุชื่อ";
                        sellerImage = userData['profileImage'] ?? "";
                      }

                      return GestureDetector(
                        onTap: () => Get.to(
                          () => StoreProfileScreen(
                            sellerId: widget.product.sellerId,
                          ),
                        ),
                        child: Container(
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                                backgroundImage: sellerImage.isNotEmpty
                                    ? NetworkImage(sellerImage)
                                    : null,
                                child: sellerImage.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          sellerName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (isOwner) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "ฉัน",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "ส่งต่อเสื้อผ้าคุณภาพ",
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "5.0/5 Rating",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 18,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (isOwner || !isAvailable) ? null : _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[400],
                      ),
                      child: Text(
                        isOwner
                            ? "สินค้าของคุณ"
                            : (!isAvailable
                                  ? "สินค้าหมด"
                                  : "เพิ่มลงในตะกร้าของคุณ"),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    widget.product.description.isEmpty
                        ? "ไม่มีรายละเอียดเพิ่มเติม"
                        : widget.product.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),

                  const SizedBox(height: 25),

                  _buildDetailRow(
                    "ค่าจัดส่ง",
                    "จะถูกคำนวณในขั้นตอนต่อไป",
                    context,
                    showArrow: false,
                  ),
                  _buildDetailRow(
                    "หมวดหมู่",
                    widget.product.category,
                    context,
                    showArrow: true,
                  ),
                  _buildDetailRow(
                    "ประเภท",
                    widget.product.type,
                    context,
                    showArrow: true,
                  ),
                  _buildDetailRow(
                    "สภาพสินค้า",
                    widget.product.condition,
                    context,
                    showArrow: true,
                  ),
                  _buildDetailRow(
                    "น้ำหนัก (กรัม)",
                    widget.product.weight.toStringAsFixed(0),
                    context,
                    showArrow: false,
                    subtitle: "เพื่อคำนวณค่าจัดส่งต่อไป",
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isOwner
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "แชทเลย",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: !isAvailable ? null : _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[400],
                      ),
                      child: Text(
                        !isAvailable ? "สินค้าหมด" : "เพิ่มลงตะกร้า",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    BuildContext context, {
    bool showArrow = false,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[800],
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
      ],
    );
  }
}
