import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:saidee_app/config/theme.dart';
import '../../models/product_model.dart';

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

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณาเข้าสู่ระบบก่อนสั่งซื้อ",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .add({
            'productId': widget.product.id,
            'name': widget.product.name,
            'price': widget.product.price,
            'image': widget.product.images.isNotEmpty
                ? widget.product.images[0]
                : '',
            'sellerId': widget.product.sellerId,
            'weight': widget.product.weight,
            'quantity': 1,
            'addedAt': Timestamp.now(),
          });

      Get.snackbar(
        "สำเร็จ",
        "เพิ่มสินค้าลงตะกร้าแล้ว",
        backgroundColor: AppTheme.primaryColor,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.7),
                  child: const BackButton(color: Colors.black),
                ),
                actions: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.7),
                    child: IconButton(
                      icon: const Icon(
                        CupertinoIcons.heart,
                        color: Colors.black,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.7),
                    child: IconButton(
                      icon: const Icon(
                        CupertinoIcons.share,
                        color: Colors.black,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      PageView.builder(
                        itemCount: widget.product.images.length,
                        onPageChanged: (index) {
                          setState(() => _currentImageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            widget.product.images[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    CupertinoIcons.exclamationmark_triangle,
                                  ),
                                ),
                          );
                        },
                      ),

                      if (widget.product.images.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.product.images.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? AppTheme.primaryColor
                                      : Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "฿${widget.product.price.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: widget.product.status == 'active'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              widget.product.status == 'active'
                                  ? "พร้อมขาย"
                                  : "ขายแล้ว",
                              style: TextStyle(
                                color: widget.product.status == 'active'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      _buildInfoTable(),

                      const SizedBox(height: 25),

                      if (_isVideoInitialized && _videoController != null) ...[
                        const Text(
                          "วิดีโอสินค้า",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoController!),

                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  radius: 30,
                                  child: Icon(
                                    _videoController!.value.isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],

                      const Text(
                        "รายละเอียดสินค้า",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.product.description.isEmpty
                            ? "-"
                            : widget.product.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.6,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                        // TODO: Implement Chat
                      },
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
                      onPressed: widget.product.status == 'active'
                          ? _addToCart
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: Text(
                        widget.product.status == 'active'
                            ? "เพิ่มลงตะกร้า"
                            : "สินค้าหมด",
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
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTable() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildInfoItem(
                CupertinoIcons.square_grid_2x2,
                "หมวดหมู่",
                widget.product.category,
              ),
              _buildInfoItem(CupertinoIcons.tag, "ประเภท", widget.product.type),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _buildInfoItem(
                CupertinoIcons.arrow_left_right,
                "ไซส์",
                widget.product.size,
              ),
              _buildInfoItem(
                CupertinoIcons.checkmark_seal,
                "แบรนด์",
                widget.product.brand.isEmpty ? "-" : widget.product.brand,
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _buildInfoItem(
                CupertinoIcons.sparkles,
                "สภาพ",
                widget.product.condition,
              ),
              _buildInfoItem(
                CupertinoIcons.cube_box,
                "น้ำหนัก",
                "${widget.product.weight} ก.",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
