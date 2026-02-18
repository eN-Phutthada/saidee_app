import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:saidee_app/config/theme.dart';
import '../../widgets/guest_view.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _brandController = TextEditingController();
  final _weightController = TextEditingController();

  // Dropdown Values
  String? _selectedType;
  String? _selectedCategory;
  String? _selectedSize;
  String? _selectedCondition;

  // Static Data
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
  final List<String> _conditionList = [
    'มือหนึ่ง (New)',
    'สภาพดี (Used-Good)',
    'มีตำหนิ (Defect)',
  ];

  // Media
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  VideoPlayerController? _videoController;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _weightController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // --- 1. จัดการรูปภาพ (Camera & Gallery) ---
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากอัลบั้ม'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } else {
      final List<XFile> photos = await _picker.pickMultiImage(imageQuality: 80);
      if (photos.isNotEmpty) {
        // กรองไฟล์
        final validFiles = photos.where((file) {
          final path = file.path.toLowerCase();
          return path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.png');
        }).toList();

        if (validFiles.length != photos.length) {
          Get.snackbar(
            "แจ้งเตือน",
            "ระบบรองรับเฉพาะไฟล์ .jpg และ .png",
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
        setState(() {
          _selectedImages.addAll(validFiles.map((e) => File(e.path)).toList());
        });
      }
    }
  }

  // --- 2. จัดการวิดีโอ (Camera & Gallery) ---
  void _showVideoSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('ถ่ายวิดีโอ'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('เลือกจากอัลบั้ม'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? video = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 15),
    );

    if (video != null) {
      File videoFile = File(video.path);
      VideoPlayerController controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (controller.value.duration.inSeconds > 15) {
        Get.snackbar(
          "วิดีโอเกินกำหนด",
          "กรุณาใช้วิดีโอความยาวไม่เกิน 15 วินาที",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        await controller.dispose();
        return;
      }

      setState(() {
        _selectedVideo = videoFile;
        _videoController = controller;
      });
    }
  }

  // --- 3. บันทึกข้อมูล ---
  Future<void> _uploadAndSave() async {
    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        "ข้อมูลไม่ครบ",
        "กรุณากรอกข้อมูลที่มีดอกจันสีแดงให้ครบถ้วน",
        backgroundColor: Colors.red.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }

    if (_selectedType == null ||
        _selectedCategory == null ||
        _selectedSize == null ||
        _selectedCondition == null) {
      Get.snackbar(
        "ข้อมูลไม่ครบ",
        "กรุณาเลือก ประเภท, หมวดหมู่, ไซส์ และสภาพสินค้า",
        backgroundColor: Colors.red.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }

    if (_selectedImages.length < 3 || _selectedImages.length > 5) {
      Get.snackbar(
        "รูปภาพไม่ถูกต้อง",
        "กรุณาอัปโหลดรูปภาพ 3 ถึง 5 รูป",
        backgroundColor: Colors.red.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }

    if (_selectedVideo == null) {
      Get.snackbar(
        "ขาดวิดีโอ",
        "กรุณาอัปโหลดวิดีโอสินค้า (ไม่เกิน 15 วินาที)",
        backgroundColor: Colors.red.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      List<String> imageUrls = [];
      String? videoUrl;

      // Upload Images
      for (var imageFile in _selectedImages) {
        String fileName =
            'img_${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        Reference ref = FirebaseStorage.instance.ref().child(
          'products/images/$fileName',
        );
        await ref.putFile(imageFile);
        imageUrls.add(await ref.getDownloadURL());
      }

      // Upload Video
      String videoName = 'vid_${DateTime.now().millisecondsSinceEpoch}.mp4';
      Reference videoRef = FirebaseStorage.instance.ref().child(
        'products/videos/$videoName',
      );
      await videoRef.putFile(_selectedVideo!);
      videoUrl = await videoRef.getDownloadURL();

      // Save Firestore
      await FirebaseFirestore.instance.collection('products').add({
        'sellerId': user!.uid,
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'category': _selectedCategory,
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'brand': _brandController.text.trim(),
        'size': _selectedSize,
        'condition': _selectedCondition,
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'images': imageUrls,
        'video': videoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      Get.back();
      Get.snackbar(
        "สำเร็จ",
        "ลงขายสินค้าเรียบร้อยแล้ว",
        backgroundColor: AppTheme.primaryColor,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Helper UI Widgets ---

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

  void _showSelectionSheet(
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) return const GuestView();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ลงขายสินค้า",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Media Section ---
              _buildSectionHeader("รูปภาพ (3-5 รูป) *"),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DottedBorder(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      strokeWidth: 1,
                      dashPattern: const [6, 3], // [ความยาวเส้นประ, ระยะห่าง]
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(10),
                      child: GestureDetector(
                        onTap: _showImageSourceOptions,
                        child: Container(
                          width: 100,
                          height: 100,
                          // ลบ border ออกจาก BoxDecoration เดิม
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_a_photo,
                                color: AppTheme.primaryColor,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "เพิ่มรูป",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ..._selectedImages.map(
                      (file) => Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: FileImage(file),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 14,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImages.remove(file)),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader("วิดีโอ (1 คลิป / 15 วิ) *"),
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
                  child: _selectedVideo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.video_call,
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
                                    _videoController?.dispose();
                                    _videoController = null;
                                  });
                                },
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.play_circle_fill,
                              size: 50,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 25),

              // --- 2. Details Section ---
              _buildSectionHeader("รายละเอียดสินค้า"),
              const SizedBox(height: 15),

              _buildTextField(
                label: "ชื่อสินค้า *",
                controller: _nameController,
                validator: (v) => v!.isEmpty ? "กรุณาระบุชื่อสินค้า" : null,
              ),

              _buildClickableField(
                label: _selectedType ?? "ประเภทสินค้า *",
                onTap: () => _showDynamicSelectionSheet(
                  "ประเภทสินค้า",
                  "types",
                  (val) => setState(() => _selectedType = val),
                ),
              ),

              _buildSectionHeader("หมวดหมู่ *"),
              const SizedBox(height: 10),
              // Category (Horizontal List)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('categories')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final categories = snapshot.data!.docs;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String catName = data['name'] ?? '';
                        final isSelected = _selectedCategory == catName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = catName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor.withOpacity(0.1)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                catName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[700]),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: "รายละเอียดเพิ่มเติม", // Optional
                controller: _descController,
                maxLines: 4,
              ),

              _buildTextField(
                label: "ราคา (บาท) *",
                controller: _priceController,
                isNumber: true,
                validator: (v) => v!.isEmpty ? "กรุณาระบุราคา" : null,
              ),

              _buildTextField(
                label: "แบรนด์", // Optional
                controller: _brandController,
              ),

              Row(
                children: [
                  Expanded(
                    child: _buildClickableField(
                      label: _selectedSize ?? "ไซส์ *",
                      onTap: () => _showSelectionSheet(
                        "ไซส์",
                        _sizeList,
                        (val) => setState(() => _selectedSize = val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildClickableField(
                      label: _selectedCondition ?? "สภาพ *",
                      onTap: () => _showSelectionSheet(
                        "สภาพสินค้า",
                        _conditionList,
                        (val) => setState(() => _selectedCondition = val),
                      ),
                    ),
                  ),
                ],
              ),

              _buildTextField(
                label: "น้ำหนัก (กรัม) *",
                controller: _weightController,
                isNumber: true,
                validator: (v) => v!.isEmpty ? "ระบุน้ำหนัก" : null,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _uploadAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "ลงขายทันที",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  // --- Header Style (บังคับใช้ Theme Font) ---
  Widget _buildSectionHeader(String title) {
    bool isRequired = title.contains('*');
    // ดึง Style หลักจาก Theme
    final baseStyle = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold);

    return RichText(
      text: TextSpan(
        text: title.replaceAll('*', '').trim(),
        style: baseStyle, // ใช้ฟอนต์ Theme
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

  // --- TextField Style (บังคับใช้ Theme Font) ---
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isRequired = label.contains('*');

    // Style สำหรับ Label
    final labelStyle = theme.textTheme.bodyMedium!.copyWith(
      color: isDark ? Colors.grey[400] : Colors.grey[600],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        // ข้อความ input ใช้ฟอนต์ Theme
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          // ใช้ RichText ใน label เพื่อบังคับฟอนต์
          label: RichText(
            text: TextSpan(
              text: label.replaceAll('*', '').trim(),
              style: labelStyle,
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
          isDense: true,
        ),
        validator: validator,
      ),
    );
  }

  // --- Clickable Field Style (บังคับใช้ Theme Font) ---
  Widget _buildClickableField({
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isRequired = label.contains('*');

    // Style ของข้อความ
    final textStyle = theme.textTheme.bodyMedium!.copyWith(
      fontSize: 16,
      color:
          (label.contains("เลือก") ||
              label.contains("ไซส์") ||
              label.contains("สภาพ"))
          ? (isDark ? Colors.grey[400] : Colors.grey[600])
          : theme.colorScheme.onSurface,
    );

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
              RichText(
                text: TextSpan(
                  text: label.replaceAll('*', '').trim(),
                  style: textStyle,
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
              Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
