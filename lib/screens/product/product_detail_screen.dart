import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';
import '../../models/product_model.dart';
import '../store/store_profile_screen.dart';
import '../cart/cart_screen.dart';
import '../auth/login_screen.dart';
import 'add_product_screen.dart';

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
  bool _isVideoError = false;

  bool _isSellerValid = true;
  bool _isCheckingSeller = true;

  @override
  void initState() {
    super.initState();
    if (widget.product.video.isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.product.video))
            ..initialize()
                .then((_) {
                  if (mounted) {
                    setState(() {
                      _isVideoInitialized = true;
                    });
                  }
                })
                .catchError((error) {
                  if (mounted) {
                    setState(() {
                      _isVideoError = true;
                    });
                  }
                  debugPrint("Video Load Error: $error");
                });
    }

    _checkSellerStatus();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _incrementViewCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      // ไม่เพิ่มยอดวิวถ้าเป็นเจ้าของสินค้าเข้ามาดูเอง
      if (user != null && user.uid == widget.product.sellerId) return;

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update({'views': FieldValue.increment(1)});
    } catch (e) {
      debugPrint("Error incrementing view: $e");
    }
  }

  Future<void> _checkSellerStatus() async {
    try {
      var sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.product.sellerId)
          .get();
      if (sellerDoc.exists) {
        var data = sellerDoc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'active';
        if (mounted) {
          setState(() {
            _isSellerValid = (status != 'banned' && status != 'suspended');
            _isCheckingSeller = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isSellerValid = false;
            _isCheckingSeller = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingSeller = false;
        });
      }
    }
  }

  void _showNotImplementedSnackbar(String featureName) {
    Get.snackbar(
      "แจ้งเตือนระบบจำลอง",
      "ฟังก์ชัน '$featureName' เป็นเพียงการจำลองระบบ ยังไม่สามารถใช้งานได้จริงในขณะนี้",
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.withOpacity(0.9),
      colorText: Colors.white,
      icon: const Icon(CupertinoIcons.info_circle_fill, color: Colors.white),
      duration: const Duration(seconds: 3),
    );
  }

  void _showInfoSheet(String title, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "เข้าใจแล้ว",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConditionInfoSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String condition = widget.product.condition.split('(')[0].trim();
    String description =
        "สภาพสินค้าประเมินโดยผู้ขาย โปรดพิจารณาจากรูปภาพและรายละเอียดเพิ่มเติมประกอบ";

    if (condition.contains("ของใหม่ป้ายห้อย")) {
      description =
          "ไม่เคยผ่านการใช้งาน ป้ายหรือบรรจุภัณฑ์ยังอยู่ครบถ้วนเหมือนซื้อจากร้าน";
    } else if (condition.contains("เหมือนใหม่")) {
      description =
          "ใส่หรือใช้งานแค่ 1-2 ครั้ง ไม่มีตำหนิใดๆ สภาพใกล้เคียงของใหม่มาก";
    } else if (condition.contains("สภาพดีมาก")) {
      description =
          "ใช้งานน้อย สีไม่ซีด ไม่มีรอยขาดหรือเปื้อนที่สังเกตเห็นได้ชัดเจน";
    } else if (condition.contains("สภาพดี")) {
      description =
          "มีร่องรอยการใช้งานทั่วไป สีอาจดรอปลงเล็กน้อย แต่โดยรวมยังดูดีและใช้งานได้ปกติ";
    } else if (condition.contains("มีตำหนิเล็กน้อย")) {
      description =
          "มีจุดเปื้อนจางๆ ขุยผ้า รอยสะกิด หรือตำหนิเล็กน้อย (ควรตรวจสอบรูปภาพหรือสอบถามผู้ขายเพิ่มเติม)";
    } else if (condition.contains("มีตำหนิชัดเจน")) {
      description =
          "มีรอยเปื้อนชัด ซิปแตก ขาด หรือมีผลต่อการใช้งานบางส่วน (ควรสอบถามผู้ขายถึงรายละเอียดตำหนิ)";
    }
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(CupertinoIcons.info_circle_fill, color: Colors.blue),
                const SizedBox(width: 10),
                const Text(
                  "ความหมายของสภาพสินค้า",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[800]
                    : Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.condition,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "ปิด",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct() {
    AppDialog.showCustomDialog(
      title: "ยืนยันการลบ",
      message:
          "คุณแน่ใจหรือไม่ที่จะลบสินค้ารายการนี้ออกจากการขาย?\nการกระทำนี้ไม่สามารถกู้คืนได้",
      icon: CupertinoIcons.trash_fill,
      iconColor: Colors.red,
      confirmText: "ลบสินค้า",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );
        try {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(widget.product.id)
              .delete();
          Get.back();
          Get.back();
          Get.snackbar(
            "สำเร็จ",
            "ลบสินค้าออกจากระบบเรียบร้อยแล้ว",
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } catch (e) {
          Get.back();
          Get.snackbar(
            "ข้อผิดพลาด",
            "ไม่สามารถลบสินค้าได้: $e",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      },
    );
  }

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      AppDialog.showCustomDialog(
        title: "กรุณาเข้าสู่ระบบ",
        message: "คุณต้องเข้าสู่ระบบสมาชิกก่อน จึงจะสามารถสั่งซื้อสินค้าได้",
        icon: CupertinoIcons.person_crop_circle_badge_exclam,
        iconColor: Colors.orange,
        confirmText: "เข้าสู่ระบบ",
        onConfirm: () {
          Get.back();
          Get.to(() => const LoginScreen());
        },
        showCancel: true,
      );
      return;
    }

    if (user.uid == widget.product.sellerId) {
      AppDialog.showCustomDialog(
        title: "ไม่สามารถทำรายการได้",
        message: "คุณไม่สามารถเพิ่มสินค้าของตัวเองลงในตะกร้าได้",
        icon: CupertinoIcons.xmark_circle_fill,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
      return;
    }

    if (!_isSellerValid) {
      Get.snackbar(
        "ขออภัย",
        "ร้านค้านี้ถูกระงับการใช้งานชั่วคราว ไม่สามารถสั่งซื้อได้",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
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

      if (existingItem.docs.isNotEmpty) {
        AppDialog.showCustomDialog(
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

      AppDialog.showCustomDialog(
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

    final bool canAddToCart =
        !_isCheckingSeller && _isSellerValid && isAvailable && !isOwner;

    String buttonText = "เพิ่มลงตะกร้า";
    if (isOwner) {
      buttonText = "สินค้าของคุณ";
    } else if (_isCheckingSeller) {
      buttonText = "กำลังตรวจสอบ...";
    } else if (!_isSellerValid) {
      buttonText = "ร้านค้าถูกระงับชั่วคราว";
    } else if (!isAvailable) {
      buttonText = "สินค้าหมด";
    }

    List<Widget> mediaPages = [];

    if (widget.product.video.isNotEmpty) {
      if (_isVideoError) {
        mediaPages.add(
          Container(
            color: isDark ? Colors.grey[900] : Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.video_camera_solid,
                    color: Colors.grey,
                    size: 40,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "ไม่สามารถโหลดวิดีโอได้",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (!_isVideoInitialized || _videoController == null) {
        mediaPages.add(
          Container(
            color: isDark ? Colors.grey[900] : Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 15),
                  Text(
                    "กำลังโหลดวิดีโอ...",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
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
                  const CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 30,
                    child: Icon(
                      CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                Positioned(
                  bottom: 15,
                  right: 15,
                  child: GestureDetector(
                    onTap: () => Get.to(
                      () =>
                          FullScreenVideoScreen(controller: _videoController!),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    mediaPages.addAll(
      widget.product.images.asMap().entries.map((entry) {
        int index = entry.key;
        String imgUrl = entry.value;
        return GestureDetector(
          onTap: () {
            Get.to(
              () => FullScreenImageGallery(
                images: widget.product.images,
                initialIndex: index,
              ),
            );
          },
          child: Image.network(
            imgUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: const Icon(CupertinoIcons.exclamationmark_triangle),
            ),
          ),
        );
      }).toList(),
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
                                index != 0) {
                              _videoController!.pause();
                            }
                          },
                          itemBuilder: (context, index) => mediaPages[index],
                        )
                      : Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                        ),
                ),

                // ปุ่มย้อนกลับ
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

                // ปุ่มตะกร้าและแชร์ (นำปุ่มหัวใจออก)
                Positioned(
                  top: 50,
                  right: 15,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isDark
                            ? Colors.black54
                            : Colors.white70,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: currentUser != null
                              ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser.uid)
                                    .collection('cart')
                                    .snapshots()
                              : null,
                          builder: (context, snapshot) {
                            int cartCount = snapshot.hasData
                                ? snapshot.data!.docs.length
                                : 0;
                            return Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    CupertinoIcons.cart,
                                    color: theme.colorScheme.onSurface,
                                    size: 22,
                                  ),
                                  onPressed: () => Get.to(
                                    () =>
                                        const CartScreen(showBackButton: true),
                                  ),
                                ),
                                if (cartCount > 0)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        cartCount > 9
                                            ? '9+'
                                            : cartCount.toString(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
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
                          onPressed: () {
                            _showNotImplementedSnackbar("แชร์สินค้า");
                          },
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
                    "ไซส์: ${widget.product.size}",
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

                  const SizedBox(height: 10),

                  // แสดงเฉพาะยอด View อย่างเดียว (นำจำนวน Like ออก)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .doc(widget.product.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int views = 0;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        views = data['views'] ?? 0;
                      }
                      return Row(
                        children: [
                          const Icon(
                            CupertinoIcons.eye,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$views เข้าชม",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
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
                      bool isBanned = false;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        var userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        sellerName = userData['name'] ?? "ผู้ขายไม่ระบุชื่อ";
                        sellerImage = userData['profileImage'] ?? "";
                        String sStatus = userData['status'] ?? 'active';
                        if (sStatus == 'banned' || sStatus == 'suspended') {
                          isBanned = true;
                          sellerName = "ร้านค้านี้ถูกระงับการใช้งาน";
                        }
                      } else if (snapshot.connectionState ==
                              ConnectionState.done &&
                          !snapshot.data!.exists) {
                        sellerName = "ไม่พบข้อมูลร้านค้า";
                        isBanned = true;
                      }

                      return GestureDetector(
                        onTap: isBanned
                            ? null
                            : () => Get.to(
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
                                backgroundImage:
                                    sellerImage.isNotEmpty && !isBanned
                                    ? NetworkImage(sellerImage)
                                    : null,
                                child: (sellerImage.isEmpty || isBanned)
                                    ? Icon(
                                        isBanned
                                            ? CupertinoIcons.nosign
                                            : Icons.person,
                                        color: isBanned
                                            ? Colors.red
                                            : Colors.grey,
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
                                        Expanded(
                                          child: Text(
                                            sellerName,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isBanned
                                                      ? Colors.red
                                                      : theme
                                                            .colorScheme
                                                            .onSurface,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isOwner && !isBanned) ...[
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
                                    if (!isBanned) ...[
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
                                  ],
                                ),
                              ),
                              if (!isBanned)
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
                      onPressed: canAddToCart ? _addToCart : null,
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
                        buttonText,
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
                    onTap: () => _showInfoSheet(
                      "หมวดหมู่สินค้า",
                      "สินค้านี้จัดอยู่ในหมวดหมู่ผู้สวมใส่ประเภท '${widget.product.category}' ช่วยให้คุณหาเสื้อผ้าที่เข้ากับคุณได้ง่ายขึ้น",
                    ),
                  ),
                  _buildDetailRow(
                    "ประเภท",
                    widget.product.type,
                    context,
                    showArrow: true,
                    onTap: () => _showInfoSheet(
                      "ประเภทสินค้า",
                      "สินค้านี้จัดอยู่ในประเภท '${widget.product.type}'",
                    ),
                  ),
                  _buildDetailRow(
                    "สภาพสินค้า",
                    widget.product.condition,
                    context,
                    showArrow: true,
                    onTap: _showConditionInfoSheet,
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
          ? _buildOwnerBottomBar(theme, isDark)
          : _buildBuyerBottomBar(theme, isDark, canAddToCart, buttonText),
    );
  }

  Widget _buildBuyerBottomBar(
    ThemeData theme,
    bool isDark,
    bool canAddToCart,
    String buttonText,
  ) {
    return Container(
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
              onPressed: !_isSellerValid
                  ? null
                  : () {
                      _showNotImplementedSnackbar("แชทกับร้านค้า");
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(
                  color: _isSellerValid ? AppTheme.primaryColor : Colors.grey,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "แชทเลย",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isSellerValid ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canAddToCart ? _addToCart : null,
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
                buttonText,
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
    );
  }

  Widget _buildOwnerBottomBar(ThemeData theme, bool isDark) {
    return Container(
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
              onPressed: () {
                Get.to(() => AddProductScreen(product: widget.product));
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(
                  color: isDark ? Colors.grey[500]! : Colors.grey,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "แก้ไขสินค้า",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton(
              onPressed: _confirmDeleteProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "ลบสินค้า",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    BuildContext context, {
    bool showArrow = false,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
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
        ),
        Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
      ],
    );
  }
}

class FullScreenVideoScreen extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoScreen({super.key, required this.controller});

  @override
  State<FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (widget.controller.value.isPlaying) {
                  widget.controller.pause();
                  _isPlaying = false;
                } else {
                  widget.controller.play();
                  _isPlaying = true;
                }
              });
            },
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: widget.controller.value.size.width,
                  height: widget.controller.value.size.height,
                  child: VideoPlayer(widget.controller),
                ),
              ),
            ),
          ),
          if (!_isPlaying)
            GestureDetector(
              onTap: () {
                setState(() {
                  widget.controller.play();
                  _isPlaying = true;
                });
              },
              child: const CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 40,
                child: Icon(
                  CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          Positioned(
            top: 50,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Get.back(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 50,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Get.back(),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_currentIndex + 1} / ${widget.images.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
