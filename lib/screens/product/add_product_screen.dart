import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/screens/product/product_detail_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:saidee_app/config/theme.dart';
import '../../models/product_model.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/guest_view.dart';
import '../store/seller_shipping_screen.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _brandController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedType;
  String? _selectedCategory;
  String? _selectedSize;
  String? _selectedCondition;

  final List<String> _sizeList = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'Freesize',
    'อื่นๆ',
  ];

  final List<Map<String, String>> _conditionOptions = [
    {
      'title': 'ของใหม่ป้ายห้อย (New with tags)',
      'desc': 'ไม่เคยผ่านการใช้งาน ป้ายยังอยู่ครบ',
    },
    {
      'title': 'เหมือนใหม่ (Like New)',
      'desc': 'ใส่แค่ 1-2 ครั้ง ไม่มีตำหนิใดๆ',
    },
    {
      'title': 'สภาพดีมาก (Excellent)',
      'desc': 'ใช้งานน้อย สีไม่ซีด ไม่มีรอยขาดหรือเปื้อน',
    },
    {'title': 'สภาพดี (Good)', 'desc': 'มีร่องรอยการใช้งานทั่วไป แต่ยังดูดี'},
    {
      'title': 'มีตำหนิเล็กน้อย (Fair)',
      'desc': 'มีจุดเปื้อนจางๆ หรือขุยผ้า (ควรแจ้งในรายละเอียด)',
    },
    {
      'title': 'มีตำหนิชัดเจน (Defect)',
      'desc': 'มีรอยเปื้อนชัด ซิปแตก ขาด (ต้องระบุให้ชัดเจน)',
    },
  ];

  final List<File> _selectedImages = [];
  File? _selectedVideo;
  VideoPlayerController? _videoController;

  List<String> _existingImages = [];
  String? _existingVideoUrl;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = "เตรียมพร้อมอัปโหลด...";

  bool get _isEditing => widget.product != null;

  bool _isFormValid() {
    int totalImages = _existingImages.length + _selectedImages.length;
    bool hasVideo =
        _selectedVideo != null ||
        (_existingVideoUrl != null && _existingVideoUrl!.isNotEmpty);

    bool hasTextInputs =
        _nameController.text.trim().isNotEmpty &&
        _priceController.text.trim().isNotEmpty &&
        _weightController.text.trim().isNotEmpty;

    bool hasDropdowns =
        _selectedType != null &&
        _selectedCategory != null &&
        _selectedSize != null &&
        _selectedCondition != null;

    bool hasMedia = (totalImages >= 3 && totalImages <= 5) && hasVideo;

    return hasTextInputs && hasDropdowns && hasMedia && !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingData();
    }

    _nameController.addListener(() => setState(() {}));
    _priceController.addListener(() => setState(() {}));
    _weightController.addListener(() => setState(() {}));
  }

  void _loadExistingData() {
    final p = widget.product!;
    _nameController.text = p.name;
    _descController.text = p.description;
    _priceController.text = p.price.toStringAsFixed(0);
    _brandController.text = p.brand;
    _weightController.text = p.weight.toStringAsFixed(0);

    _selectedType = p.type;
    _selectedCategory = p.category;
    _selectedSize = p.size;
    _selectedCondition = p.condition;

    _existingImages = List.from(p.images);
    _existingVideoUrl = p.video;

    if (_existingVideoUrl != null && _existingVideoUrl!.isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(_existingVideoUrl!))
            ..initialize().then((_) {
              setState(() {});
            });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _weightController.dispose();
    _videoController?.dispose();
    VideoCompress.deleteAllCache();
    super.dispose();
  }

  void _showImageSourceOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "เพิ่มรูปภาพสินค้า",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMediaOptionBtn(
                  icon: CupertinoIcons.camera_fill,
                  label: "ถ่ายรูป",
                  color: Colors.blue,
                  isDark: isDark,
                  onTap: () {
                    Get.back();
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildMediaOptionBtn(
                  icon: CupertinoIcons.photo_on_rectangle,
                  label: "อัลบั้ม",
                  color: Colors.orange,
                  isDark: isDark,
                  onTap: () {
                    Get.back();
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showVideoSourceOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "เพิ่มวิดีโอสินค้า",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "ความยาวไม่เกิน 15 วินาที",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMediaOptionBtn(
                  icon: CupertinoIcons.video_camera_solid,
                  label: "ถ่ายวิดีโอ",
                  color: Colors.red,
                  isDark: isDark,
                  onTap: () {
                    Get.back();
                    _pickVideo(ImageSource.camera);
                  },
                ),
                _buildMediaOptionBtn(
                  icon: CupertinoIcons.film,
                  label: "อัลบั้ม",
                  color: Colors.purple,
                  isDark: isDark,
                  onTap: () {
                    Get.back();
                    _pickVideo(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOptionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (photo != null) setState(() => _selectedImages.add(File(photo.path)));
    } else {
      final List<XFile> photos = await _picker.pickMultiImage(
        imageQuality: 60,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (photos.isNotEmpty) {
        final validFiles = photos.where((file) {
          final path = file.path.toLowerCase();
          return path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.png');
        }).toList();

        if (validFiles.length != photos.length) {
          AppDialog.showCustomDialog(
            title: "ไฟล์ไม่รองรับ",
            message: "ระบบรองรับเฉพาะไฟล์รูปภาพ .jpg และ .png เท่านั้น",
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            iconColor: Colors.orange,
            confirmText: "ตกลง",
            onConfirm: () => Get.back(),
          );
        }

        int currentTotal = _existingImages.length + _selectedImages.length;
        int spaceLeft = 5 - currentTotal;

        if (spaceLeft <= 0) {
          AppDialog.showCustomDialog(
            title: "จำนวนรูปภาพเต็มแล้ว",
            message: "คุณสามารถอัปโหลดรูปภาพสินค้าได้สูงสุด 5 รูปเท่านั้น",
            icon: CupertinoIcons.photo_on_rectangle,
            iconColor: Colors.orange,
            confirmText: "ตกลง",
            onConfirm: () => Get.back(),
          );
          return;
        }

        List<File> newFiles = validFiles
            .take(spaceLeft)
            .map((e) => File(e.path))
            .toList();
        setState(() => _selectedImages.addAll(newFiles));
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? video = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 15),
    );

    if (video != null) {
      File videoFile = File(video.path);

      VideoPlayerController tempController = VideoPlayerController.file(
        videoFile,
      );
      await tempController.initialize();

      if (tempController.value.duration.inSeconds > 15) {
        AppDialog.showCustomDialog(
          title: "วิดีโอยาวเกินไป",
          message: "กรุณาใช้วิดีโอที่มีความยาวไม่เกิน 15 วินาที",
          icon: CupertinoIcons.time,
          iconColor: Colors.red,
          confirmText: "เข้าใจแล้ว",
          onConfirm: () => Get.back(),
        );
        await tempController.dispose();
        return;
      }
      await tempController.dispose();

      int fileSizeInBytes = videoFile.lengthSync();
      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > 15) {
        Get.dialog(
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    "กำลังบีบอัดวิดีโอ...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "เพื่อการอัปโหลดที่รวดเร็วขึ้น",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          barrierDismissible: false,
        );

        try {
          final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
            video.path,
            quality: VideoQuality.DefaultQuality,
            deleteOrigin: false,
          );
          Get.back();
          if (mediaInfo != null && mediaInfo.file != null) {
            videoFile = mediaInfo.file!;
          }
        } catch (e) {
          Get.back();
        }
      }

      VideoPlayerController controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      setState(() {
        _selectedVideo = videoFile;
        _videoController = controller;
        _existingVideoUrl = null;
      });
    }
  }

  void _showProgressDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0.0,
                            end: _uploadProgress,
                          ),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, value, _) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey[200],
                              color: AppTheme.primaryColor,
                            );
                          },
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: _uploadProgress * 100,
                        ),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, _) {
                          return Text(
                            "${value.toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _uploadStatusText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "กรุณาอย่าปิดแอปพลิเคชัน",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<bool> _checkShippingIsSet(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        List enabledShipping = data['enabled_shipping'] ?? [];
        if (enabledShipping.isNotEmpty) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _uploadAndSave() async {
    if (!_isFormValid()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isEditing) {
      bool isShippingSet = await _checkShippingIsSet(user.uid);
      if (!isShippingSet) {
        AppDialog.showCustomDialog(
          title: "ยังไม่ได้ตั้งค่าการขนส่ง",
          message:
              "คุณต้องเลือกบริการขนส่งที่ร้านคุณรองรับก่อน จึงจะสามารถลงขายสินค้าได้ เพื่อให้ระบบคำนวณค่าจัดส่งได้ถูกต้อง",
          icon: CupertinoIcons.cube_box,
          iconColor: Colors.orange,
          confirmText: "ไปตั้งค่าตอนนี้",
          cancelText: "ไว้ทีหลัง",
          showCancel: true,
          onConfirm: () {
            Get.back();
            Get.to(() => SellerShippingScreen(sellerId: user.uid));
          },
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = "กำลังเริ่มอัปโหลด...";
    });

    _showProgressDialog();

    try {
      List<String> finalImageUrls = List.from(_existingImages);
      String? finalVideoUrl = _existingVideoUrl;

      int totalFiles =
          _selectedImages.length + (_selectedVideo != null ? 1 : 0);
      int completedFiles = 0;

      for (int i = 0; i < _selectedImages.length; i++) {
        setState(
          () => _uploadStatusText =
              "อัปโหลดรูปภาพที่ ${i + 1}/${_selectedImages.length}",
        );
        if (Get.isDialogOpen ?? false) Get.forceAppUpdate();

        String fileName =
            'img_${DateTime.now().millisecondsSinceEpoch}_${_selectedImages[i].path.split('/').last}';
        Reference ref = FirebaseStorage.instance.ref().child(
          'products/images/$fileName',
        );
        UploadTask uploadTask = ref.putFile(_selectedImages[i]);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double taskProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _uploadProgress =
                (completedFiles + taskProgress) /
                (totalFiles == 0 ? 1 : totalFiles);
          });
          if (Get.isDialogOpen ?? false) Get.forceAppUpdate();
        });

        await uploadTask;
        String downloadUrl = await ref.getDownloadURL();
        finalImageUrls.add(downloadUrl);
        completedFiles++;
      }

      if (_selectedVideo != null) {
        setState(() => _uploadStatusText = "กำลังอัปโหลดวิดีโอ...");
        if (Get.isDialogOpen ?? false) Get.forceAppUpdate();
        SettableMetadata metadata = SettableMetadata(contentType: 'video/mp4');
        String videoName = 'vid_${DateTime.now().millisecondsSinceEpoch}.mp4';
        Reference videoRef = FirebaseStorage.instance.ref().child(
          'products/videos/$videoName',
        );
        UploadTask videoTask = videoRef.putFile(_selectedVideo!, metadata);
        videoTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double taskProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _uploadProgress = (completedFiles + taskProgress) / totalFiles;
          });
          if (Get.isDialogOpen ?? false) Get.forceAppUpdate();
        });
        await videoTask;
        finalVideoUrl = await videoRef.getDownloadURL();
      }

      setState(() {
        _uploadStatusText = "กำลังบันทึกข้อมูล...";
        _uploadProgress = 1.0;
      });
      if (Get.isDialogOpen ?? false) Get.forceAppUpdate();

      Map<String, dynamic> productData = {
        'sellerId': user.uid,
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'category': _selectedCategory,
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'brand': _brandController.text.trim(),
        'size': _selectedSize,
        'condition': _selectedCondition,
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'images': finalImageUrls,
        'video': finalVideoUrl ?? '',
      };

      if (_isEditing) {
        productData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(productData);
        Get.back();
        ProductModel updatedProduct = ProductModel.fromMap(
          productData,
          widget.product!.id,
        );
        AppDialog.showCustomDialog(
          title: "แก้ไขสำเร็จ",
          message: "ระบบได้ทำการอัปเดตข้อมูลสินค้าของคุณเรียบร้อยแล้ว",
          icon: CupertinoIcons.check_mark_circled_solid,
          iconColor: Colors.green,
          confirmText: "ดูสินค้า",
          showCancel: false,
          onConfirm: () {
            Get.back();
            Get.back();
            Get.off(() => ProductDetailScreen(product: updatedProduct));
          },
        );
      } else {
        productData['createdAt'] = FieldValue.serverTimestamp();
        productData['status'] = 'active';
        var docRef = await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
        Get.back();
        ProductModel newProduct = ProductModel.fromMap(productData, docRef.id);

        setState(() {
          _selectedImages.clear();
          _selectedVideo = null;
          _videoController?.dispose();
          _videoController = null;
          _formKey.currentState?.reset();
          _nameController.clear();
          _descController.clear();
          _priceController.clear();
          _brandController.clear();
          _weightController.clear();
          _selectedType = null;
          _selectedCategory = null;
          _selectedSize = null;
          _selectedCondition = null;
        });

        AppDialog.showCustomDialog(
          title: "ลงขายสำเร็จ!",
          message: "สินค้าของคุณถูกนำขึ้นระบบและพร้อมจำหน่ายแล้ว",
          icon: CupertinoIcons.checkmark_seal_fill,
          iconColor: Colors.green,
          confirmText: "ดูสินค้าที่ลงขาย",
          cancelText: "ลงเพิ่มต่อ",
          showCancel: true,
          onConfirm: () {
            Get.back();
            Get.to(() => ProductDetailScreen(product: newProduct));
          },
        );
      }
    } catch (e) {
      Get.back();
      AppDialog.showCustomDialog(
        title: "เกิดข้อผิดพลาด",
        message:
            "การอัปโหลดล้มเหลว กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่อีกครั้ง",
        icon: CupertinoIcons.wifi_exclamationmark,
        iconColor: Colors.red,
        confirmText: "ตกลง",
        onConfirm: () => Get.back(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDynamicSelectionSheet(
    String title,
    String collectionName,
    Function(String) onSelect,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "เลือก$title",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(collectionName)
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty)
                      return Center(
                        child: Text(
                          "ไม่พบข้อมูล",
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      );

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(
                            data['name'] ?? '',
                            style: theme.textTheme.bodyLarge,
                          ),
                          onTap: () {
                            onSelect(data['name']);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSimpleSelectionSheet(
    String title,
    List<String> items,
    Function(String) onSelect,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "เลือก$title",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        items[index],
                        style: theme.textTheme.bodyLarge,
                      ),
                      onTap: () {
                        onSelect(items[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConditionSelectionSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "เลือกสภาพสินค้า",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "ประเมินสภาพตามจริงเพื่อลดปัญหาการคืนสินค้า",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  itemCount: _conditionOptions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                  itemBuilder: (context, index) {
                    var item = _conditionOptions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 5,
                      ),
                      title: Text(
                        item['title']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          item['desc']!,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      onTap: () {
                        setState(() => _selectedCondition = item['title']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) return const GuestView();

    bool isFormComplete = _isFormValid();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? "แก้ไขสินค้า" : "ลงขายสินค้า",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      CupertinoIcons.lightbulb_fill,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Seller Tip: การเลือกหมวดหมู่ แบรนด์ และไซส์ให้ถูกต้อง จะช่วยให้ลูกค้าค้นหาสินค้าของคุณเจอได้ง่ายขึ้นผ่านระบบตัวกรองของแอป",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              _buildSectionHeader("รูปภาพ (3-5 รูป) *"),
              const SizedBox(height: 4),
              Text(
                "แนะนำ: รูปภาพคมชัด ช่วยเพิ่มโอกาสขายได้มากขึ้น",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DottedBorder(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      strokeWidth: 1,
                      dashPattern: const [6, 3],
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(10),
                      child: GestureDetector(
                        onTap: _showImageSourceOptions,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                CupertinoIcons.camera,
                                color: AppTheme.primaryColor,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "เพิ่มรูป",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ..._existingImages.map(
                      (url) => _buildImageThumbnail(
                        NetworkImage(url),
                        () => setState(() => _existingImages.remove(url)),
                      ),
                    ),
                    ..._selectedImages.map(
                      (file) => _buildImageThumbnail(
                        FileImage(file),
                        () => setState(() => _selectedImages.remove(file)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              _buildSectionHeader("วิดีโอ (ไม่เกิน 15 วิ) *"),
              const SizedBox(height: 4),
              Text(
                "ระบบจะช่วยบีบอัดขนาดไฟล์ให้อัตโนมัติ",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showVideoSourceOptions,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child:
                      (_selectedVideo == null &&
                          (_existingVideoUrl == null ||
                              _existingVideoUrl!.isEmpty))
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.video_camera,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "แตะเพื่อเพิ่มวิดีโอ",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_videoController != null &&
                                _videoController!.value.isInitialized)
                              AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              )
                            else
                              const Center(child: Text("วิดีโอพร้อม")),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedVideo = null;
                                    _existingVideoUrl = null;
                                    _videoController?.dispose();
                                    _videoController = null;
                                  });
                                },
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    CupertinoIcons.xmark,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const Icon(
                              CupertinoIcons.play_circle_fill,
                              size: 50,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),

              _buildSectionHeader("การจัดหมวดหมู่ (สำคัญสำหรับการค้นหา)"),
              const SizedBox(height: 15),

              _buildClickableField(
                label: _selectedCategory ?? "หมวดหมู่ผู้สวมใส่ *",
                onTap: () => _showDynamicSelectionSheet(
                  "หมวดหมู่",
                  "categories",
                  (val) => setState(() => _selectedCategory = val),
                ),
              ),
              _buildClickableField(
                label: _selectedType ?? "ประเภทสินค้า *",
                onTap: () => _showDynamicSelectionSheet(
                  "ประเภทสินค้า",
                  "types",
                  (val) => setState(() => _selectedType = val),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildClickableField(
                      label: _selectedSize ?? "ไซส์ *",
                      onTap: () => _showSimpleSelectionSheet(
                        "ไซส์",
                        _sizeList,
                        (val) => setState(() => _selectedSize = val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildClickableField(
                      label: _selectedCondition != null
                          ? _selectedCondition!.split('(')[0].trim()
                          : "สภาพ *",
                      onTap: _showConditionSelectionSheet,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                label: "แบรนด์",
                controller: _brandController,
                hint: "เช่น Zara, H&M, Uniqlo (เว้นว่างได้)",
              ),

              const SizedBox(height: 15),
              _buildSectionHeader("รายละเอียดข้อมูล"),
              const SizedBox(height: 15),
              _buildTextField(
                label: "ชื่อสินค้า *",
                controller: _nameController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "กรุณาระบุชื่อสินค้า";
                  }
                  if (v.trim().length < 5) {
                    return "ชื่อสินค้าควรมีความยาวอย่างน้อย 5 ตัวอักษร";
                  }
                  return null;
                },
              ),
              _buildTextField(
                label: "รายละเอียดเพิ่มเติม",
                controller: _descController,
                maxLines: 4,
                hint: "อธิบายจุดเด่นหรือตำหนิของสินค้าให้ชัดเจน",
              ),
              _buildTextField(
                label: "ราคา (บาท) *",
                controller: _priceController,
                isNumber: true,
                hint: "เช่น 150",
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "กรุณาระบุราคา";
                  final price = double.tryParse(v.trim());
                  if (price == null) return "กรุณาระบุเป็นตัวเลขเท่านั้น";
                  if (price <= 0) return "ราคาต้องมากกว่า 0 บาท";
                  if (price > 100000) return "ราคาไม่ควรเกิน 100,000 บาท";
                  return null;
                },
              ),
              _buildTextField(
                label: "น้ำหนักรวมกล่องพัสดุ (กรัม) *",
                controller: _weightController,
                isNumber: true,
                hint: "เช่น เสื้อยืด=200, กางเกงยีนส์=500",
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "กรุณาระบุน้ำหนัก";
                  final double? weight = double.tryParse(v.trim());
                  if (weight == null) return "กรุณาระบุเป็นตัวเลขเท่านั้น";
                  if (weight <= 0) return "น้ำหนักต้องมากกว่า 0 กรัม";
                  if (weight > 20000) {
                    return "น้ำหนักเกินกำหนด (สูงสุด 20,000 กรัม)";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isFormComplete ? _uploadAndSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFormComplete
                        ? AppTheme.primaryColor
                        : Colors.grey[400],
                    disabledBackgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _isEditing ? "บันทึกการแก้ไข" : "ลงขายทันที",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isFormComplete
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                ),
              ),

              if (!isFormComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      "กรุณากรอกข้อมูลบังคับ (*) ให้ครบถ้วนเพื่อลงขาย",
                      style: TextStyle(color: Colors.red[400], fontSize: 12),
                    ),
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(
    ImageProvider imageProvider,
    VoidCallback onRemove,
  ) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Icon(CupertinoIcons.xmark, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    bool isRequired = title.contains('*');
    final baseStyle = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold);
    return RichText(
      text: TextSpan(
        text: title.replaceAll('*', '').trim(),
        style: baseStyle,
        children: isRequired
            ? [
                const TextSpan(
                  text: " *",
                  style: TextStyle(color: Colors.red),
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isRequired = label.contains('*');

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : [],
        maxLines: maxLines,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          label: RichText(
            text: TextSpan(
              text: label.replaceAll('*', '').trim(),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              children: isRequired
                  ? [
                      const TextSpan(
                        text: " *",
                        style: TextStyle(color: Colors.red),
                      ),
                    ]
                  : [],
            ),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildClickableField({
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isRequired = label.contains('*');
    bool isPlaceholder =
        label.contains("เลือก") ||
        label.contains("ไซส์") ||
        label.contains("สภาพ") ||
        label.contains("หมวดหมู่") ||
        label.contains("ประเภท");

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: label.replaceAll('*', '').trim(),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontSize: 16,
                      color: isPlaceholder
                          ? (isDark ? Colors.grey[400] : Colors.grey[600])
                          : theme.colorScheme.onSurface,
                    ),
                    children: isRequired
                        ? [
                            const TextSpan(
                              text: " *",
                              style: TextStyle(color: Colors.red),
                            ),
                          ]
                        : [],
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_down,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
