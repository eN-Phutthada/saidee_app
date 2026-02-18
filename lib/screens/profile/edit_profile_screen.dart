import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:saidee_app/config/theme.dart';
// อย่าลืม Import หน้า AddAddressScreen
import 'package:saidee_app/screens/profile/add_address_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  File? _newImageFile;
  bool _isLoading = false;
  String? _currentImageUrl;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userData['name'] ?? '',
    );
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _currentImageUrl = widget.userData['profileImage'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // 1. แก้ไขฟังก์ชันนี้ให้รับ parameter source
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80, // ปรับคุณภาพรูปไม่ให้ไฟล์ใหญ่เกินไป
      );
      if (pickedFile != null) {
        setState(() {
          _newImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // 2. เพิ่มฟังก์ชันแสดงตัวเลือก (Bottom Sheet)
  void _showImageSourceOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "เปลี่ยนรูปโปรไฟล์",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionBtn(
                    icon: Icons.camera_alt,
                    label: "กล้อง",
                    color: Colors.blueAccent,
                    onTap: () {
                      Get.back(); // ปิด Bottom Sheet ก่อน
                      _pickImage(ImageSource.camera); // เรียกกล้อง
                    },
                  ),
                  _buildOptionBtn(
                    icon: Icons.photo_library,
                    label: "คลังภาพ",
                    color: Colors.purpleAccent,
                    onTap: () {
                      Get.back();
                      _pickImage(ImageSource.gallery); // เรียกแกลเลอรี
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Widget ปุ่มตัวเลือกย่อย
  Widget _buildOptionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    if (currentUser == null) return;

    try {
      String? imageUrl = _currentImageUrl;

      if (_newImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child(
              '${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
        await storageRef.putFile(_newImageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'name': _nameController.text.trim(),
            'bio': _bioController.text.trim(),
            'profileImage': imageUrl,
          });

      Get.back();
      Get.snackbar(
        "สำเร็จ",
        "บันทึกข้อมูลเรียบร้อย",
        backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        e.toString(),
        backgroundColor: AppTheme.errorColor.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          "แก้ไขโปรไฟล์",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle, color: Colors.white),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Profile Image Section ---
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceOptions,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                          image: _newImageFile != null
                              ? DecorationImage(
                                  image: FileImage(_newImageFile!),
                                  fit: BoxFit.cover,
                                )
                              : (_currentImageUrl != null &&
                                    _currentImageUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(_currentImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            (_newImageFile == null &&
                                (_currentImageUrl == null ||
                                    _currentImageUrl!.isEmpty))
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: theme.iconTheme.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- Name & Bio ---
              _buildLabel(context, "ชื่อ - สกุล"),
              _buildTextField(context, _nameController),
              const SizedBox(height: 20),
              _buildLabel(context, "คำอธิบายเกี่ยวกับฉัน"),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _bioController,
                  maxLines: 5,
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    hintText: 'แนะนำตัวสั้นๆ...',
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- Contact Info ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ข้อมูลส่วนตัว",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "( เฉพาะเจ้าของบัญชี )",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildReadOnlyRow(
                context,
                "เบอร์โทร",
                widget.userData['phone'] ?? '',
              ),
              const SizedBox(height: 15),
              _buildReadOnlyRow(
                context,
                "อีเมล*",
                widget.userData['email'] ?? '',
              ),
              const SizedBox(height: 30),

              // --- Address Section (แก้ไขใหม่) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ที่อยู่",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // ส่งค่าว่างไป เพื่อบอกว่าเป็นโหมด "เพิ่มใหม่"
                      Get.to(() => const AddAddressScreen());
                    },
                    child: const Text(
                      "เพิ่มที่อยู่",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // StreamBuilder เพื่อแสดงรายการที่อยู่
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('addresses')
                    .orderBy(
                      'is_default',
                      descending: true,
                    ) // เอาค่า Default ขึ้นก่อน
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Text("เกิดข้อผิดพลาดในการโหลดที่อยู่");
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());

                  final addresses = snapshot.data!.docs;

                  if (addresses.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[700]!
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "ยังไม่มีที่อยู่จัดส่ง",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: addresses.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return _buildAddressCard(context, doc.id, data);
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget การ์ดแสดงที่อยู่ ---
  Widget _buildAddressCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isDefault = data['is_default'] ?? false;

    return GestureDetector(
      onTap: () {
        // กดเพื่อแก้ไข: ส่ง docId และ data ไปด้วย
        Get.to(() => AddAddressScreen(docId: docId, existingData: data));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDefault
                ? AppTheme.primaryColor
                : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
            width: isDefault ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on,
              color: isDefault ? AppTheme.primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${data['receiver_name']} (${data['phone']})",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Default",
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${data['address_detail']} ${data['sub_district']} ${data['district']} ${data['province']} ${data['postcode']}",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ... (Widget _buildLabel, _buildTextField, _buildReadOnlyRow เดิม ไม่ต้องแก้)
  Widget _buildLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: TextField(
        controller: controller,
        style: theme.textTheme.bodyLarge,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
              ),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
