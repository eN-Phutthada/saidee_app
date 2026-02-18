import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saidee_app/config/theme.dart';
import '../../widgets/guest_view.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

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
  final List<String> _conditionList = [
    'มือหนึ่ง (New)',
    'สภาพดี (Used-Good)',
    'มีตำหนิ (Defect)',
  ];

  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((e) => File(e.path)).toList());
      });
    }
  }

  Future<void> _uploadAndSave() async {
    // Validate FormField ด้วย
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == null || _selectedCategory == null) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณาเลือกประเภทและหมวดหมู่",
        backgroundColor: Colors.red.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      Get.snackbar(
        "แจ้งเตือน",
        "กรุณาอัปโหลดรูปภาพอย่างน้อย 1 รูป",
        backgroundColor: Colors.red.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      List<String> imageUrls = [];
      for (var imageFile in _selectedImages) {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        Reference ref = FirebaseStorage.instance.ref().child(
          'products/$fileName',
        );
        await ref.putFile(imageFile);
        imageUrls.add(await ref.getDownloadURL());
      }

      await FirebaseFirestore.instance.collection('products').add({
        'sellerId': user!.uid,
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'category': _selectedCategory,
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'brand': _brandController.text.trim(),
        'size': _selectedSize ?? '-',
        'condition': _selectedCondition ?? '-',
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      Get.back();
      Get.snackbar(
        "สำเร็จ",
        "โพสต์สินค้าเรียบร้อยแล้ว",
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

  void _showSelectionSheet(
    String title,
    List<String> items,
    Function(String) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        items[index],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
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

  void _showDynamicSelectionSheet(
    String title,
    String collectionName,
    Function(String) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(collectionName)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "ไม่พบข้อมูล",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(
                            data['name'] ?? '',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) return const GuestView();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "สร้างรายการสินค้าใหม่",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              _buildSectionHeader("ข้อมูลทั่วไป"),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _nameController,
                hint: "ชื่อสินค้า",
                validator: (v) => v!.isEmpty ? "ระบุชื่อสินค้า" : null,
              ),
              const SizedBox(height: 15),
              _buildClickableField(
                label: _selectedType ?? "เลือกประเภท",
                onTap: () => _showDynamicSelectionSheet(
                  "ประเภทสินค้า",
                  "types",
                  (val) => setState(() => _selectedType = val),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader("หมวดหมู่ *"),
              const SizedBox(height: 10),
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
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor.withOpacity(0.1)
                                    : (isDark
                                          ? Colors.grey[800]
                                          : Colors.white),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey.shade300),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                catName,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isDark
                                            ? Colors.grey[300]
                                            : Colors.grey.shade600),
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

              _buildSectionHeader("อัปโหลดรูป *"),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.primaryColor,
                            size: 30,
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
                              borderRadius: BorderRadius.circular(8),
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

              _buildSectionHeader("คำอธิบาย"),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _descController,
                hint: "รายละเอียดสินค้า...",
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              _buildLabelWithStar("ราคา (บาท)"),
              _buildTextField(
                controller: _priceController,
                hint: "ระบุราคา",
                isNumber: true,
                validator: (v) => v!.isEmpty ? "ระบุราคา" : null,
              ),
              const SizedBox(height: 15),

              _buildLabelWithStar("แบรนด์", isRequired: false),
              _buildTextField(controller: _brandController, hint: "ระบุแบรนด์"),
              const SizedBox(height: 15),

              _buildClickableField(
                label: _selectedSize ?? "ไซส์",
                onTap: () => _showSelectionSheet(
                  "ไซส์",
                  _sizeList,
                  (val) => setState(() => _selectedSize = val),
                ),
              ),
              const SizedBox(height: 15),
              _buildClickableField(
                label: _selectedCondition ?? "สภาพสินค้า",
                onTap: () => _showSelectionSheet(
                  "สภาพสินค้า",
                  _conditionList,
                  (val) => setState(() => _selectedCondition = val),
                ),
              ),
              const SizedBox(height: 15),

              _buildLabelWithStar("น้ำหนัก (กรัม)", isRequired: false),
              _buildTextField(
                controller: _weightController,
                hint: "กรัม",
                isNumber: true,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _uploadAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "โพสต์สินค้า",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // --- แก้ไข 1: ปรับ Font และ Style ให้เหมือน _buildSectionHeader ---
  Widget _buildLabelWithStar(String text, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600, // เพิ่มความหนาให้เหมือน Header
            color: Theme.of(context).colorScheme.onSurface,
            // ลบ fontFamily เฉพาะออก เพื่อให้ใช้ Theme หลัก หรือถ้าจำเป็นให้ใส่กลับ
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
    );
  }

  // --- แก้ไข 2: ย้ายการแจ้งเตือน (Error Message) ให้ออกมาอยู่นอกขอบขาว ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ใช้ FormField เพื่อจัดการ state การตรวจสอบข้อมูล (Validation) แยกต่างหาก
    return FormField<String>(
      validator: (value) {
        if (validator != null) {
          return validator(controller.text);
        }
        return null;
      },
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  // เปลี่ยนสีขอบเป็นสีแดงถ้ามี error
                  color: state.hasError
                      ? Colors.red
                      : (isDark ? Colors.grey[700]! : Colors.grey.shade200),
                ),
              ),
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: isNumber
                    ? TextInputType.number
                    : TextInputType.text,
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: (text) {
                  // เคลียร์ error เมื่อผู้ใช้เริ่มพิมพ์ใหม่
                  if (state.hasError) {
                    state.didChange(text);
                  }
                },
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            // ส่วนแสดงผล Error Text อยู่นอก Container (นอกขอบขาว)
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6.0, left: 10.0),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildClickableField({
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    (label.startsWith("เลือก") ||
                        label == "ไซส์" ||
                        label == "สภาพสินค้า")
                    ? (isDark ? Colors.grey[400] : Colors.grey.shade400)
                    : theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
