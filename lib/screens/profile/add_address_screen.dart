import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:saidee_app/config/theme.dart';
import 'package:saidee_app/widgets/custom_dialog.dart';

class AddAddressScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AddAddressScreen({super.key, this.docId, this.existingData});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressDetailController = TextEditingController();
  final _subDistrictController = TextEditingController();
  final _districtController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postcodeController = TextEditingController();

  bool _isDefault = false;
  bool _isLoading = false;
  bool _isMapReady = false;
  bool _canFetchAddress = true;

  final Completer<GoogleMapController> _mapController = Completer();
  LatLng _currentPosition = const LatLng(13.7563, 100.5018);

  bool get _isEditing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    if (_isEditing && widget.existingData != null) {
      _loadExistingData();
      setState(() => _isMapReady = true);
    } else {
      await Future.wait([_fetchUserProfile(), _determinePosition()]);
      if (mounted) {
        setState(() => _isMapReady = true);
      }
    }
  }

  void _loadExistingData() {
    final data = widget.existingData!;
    _nameController.text = data['receiver_name'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _addressDetailController.text = data['address_detail'] ?? '';
    _subDistrictController.text = data['sub_district'] ?? '';
    _districtController.text = data['district'] ?? '';
    _provinceController.text = data['province'] ?? '';
    _postcodeController.text = data['postcode'] ?? '';
    _isDefault = data['is_default'] ?? false;

    if (data['latitude'] != null && data['longitude'] != null) {
      _currentPosition = LatLng(data['latitude'], data['longitude']);
    }
    _canFetchAddress = false;
  }

  Future<void> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (!mounted) return;
          setState(() {
            if (_nameController.text.isEmpty)
              _nameController.text = data['name'] ?? '';
            if (_phoneController.text.isEmpty)
              _phoneController.text = data['phone'] ?? '';
          });
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    _currentPosition = LatLng(position.latitude, position.longitude);
    if (!_isEditing) {
      await _getAddressFromLatLng(_currentPosition);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      await setLocaleIdentifier('th_TH');
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (!mounted) return;
        setState(() {
          String street = place.street ?? '';
          if (street == place.name || street.contains('+')) street = '';
          if (_addressDetailController.text.isEmpty || !_isEditing) {
            _addressDetailController.text = street;
          }
          _subDistrictController.text =
              place.subLocality ?? place.locality ?? '';
          _districtController.text =
              place.subAdministrativeArea ?? place.locality ?? '';
          String province = place.administrativeArea ?? '';
          _provinceController.text = province
              .replaceAll('จ.', '')
              .replaceAll('Chang Wat', '')
              .trim();
          _postcodeController.text = place.postalCode ?? '';
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _openFullScreenMap() async {
    final result = await Get.to(
      () => FullScreenMapPicker(initialPosition: _currentPosition),
    );
    if (result != null && result is LatLng) {
      setState(() {
        _currentPosition = result;
        _canFetchAddress = true;
      });
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(result));
      _getAddressFromLatLng(result);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        "ข้อมูลไม่ครบถ้วน",
        "กรุณากรอกข้อมูลที่จำเป็นให้ครบ",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final addressData = {
        'receiver_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address_detail': _addressDetailController.text.trim(),
        'sub_district': _subDistrictController.text.trim(),
        'district': _districtController.text.trim(),
        'province': _provinceController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'latitude': _currentPosition.latitude,
        'longitude': _currentPosition.longitude,
        'is_default': _isDefault,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (!_isEditing) addressData['created_at'] = FieldValue.serverTimestamp();

      if (_isDefault) {
        var batch = FirebaseFirestore.instance.batch();
        var querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .where('is_default', isEqualTo: true)
            .get();
        for (var doc in querySnapshot.docs) {
          if (_isEditing && doc.id == widget.docId) continue;
          batch.update(doc.reference, {'is_default': false});
        }
        await batch.commit();
      }

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .doc(widget.docId)
            .update(addressData);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .add(addressData);
      }

      AppDialog.showCustomDialog(
        title: "บันทึกสำเร็จ",
        message: "ข้อมูลที่อยู่ถูกบันทึกเรียบร้อยแล้ว",
        icon: CupertinoIcons.checkmark_seal_fill,
        iconColor: Colors.green,
        confirmText: "ตกลง",
        onConfirm: () {
          Get.back();
          Get.back();
        },
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

  Future<void> _deleteAddress() async {
    AppDialog.showCustomDialog(
      title: "ลบที่อยู่จัดส่ง",
      message: "คุณแน่ใจหรือไม่ที่จะลบที่อยู่นี้ออกจากระบบ?",
      icon: CupertinoIcons.trash_fill,
      iconColor: Colors.red,
      confirmText: "ลบที่อยู่",
      cancelText: "ยกเลิก",
      showCancel: true,
      isDestructive: true,
      onConfirm: () async {
        Get.back();
        setState(() => _isLoading = true);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && widget.docId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('addresses')
              .doc(widget.docId)
              .delete();
          Get.back();
        }
        setState(() => _isLoading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? "แก้ไขที่อยู่" : "เพิ่มที่อยู่ใหม่",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _isLoading ? null : _deleteAddress,
              icon: const Icon(CupertinoIcons.trash),
            ),
        ],
      ),
      body: !_isMapReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMapSection(),
                Expanded(child: _buildFormSection(theme, isDark)),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "บันทึกที่อยู่",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController.complete(controller),
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onCameraMoveStarted: () => _canFetchAddress = true,
            onCameraMove: (position) => _currentPosition = position.target,
            onCameraIdle: () {
              if (_canFetchAddress) _getAddressFromLatLng(_currentPosition);
            },
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 30),
            child: Icon(
              CupertinoIcons.location_solid,
              size: 45,
              color: AppTheme.primaryColor,
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: FloatingActionButton.small(
              heroTag: "fs",
              backgroundColor: Colors.white,
              onPressed: _openFullScreenMap,
              child: const Icon(
                CupertinoIcons.fullscreen,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.person_solid,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "ข้อมูลผู้ติดต่อ",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    "ชื่อ-นามสกุล",
                    _nameController,
                    isDark: isDark,
                  ),
                  _buildTextField(
                    "เบอร์โทรศัพท์",
                    _phoneController,
                    isNumber: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.map_pin_ellipse,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "รายละเอียดที่อยู่",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    "บ้านเลขที่, หมู่, ซอย, ถนน",
                    _addressDetailController,
                    isDark: isDark,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "แขวง/ตำบล",
                          _subDistrictController,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          "เขต/อำเภอ",
                          _districtController,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "จังหวัด",
                          _provinceController,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          "รหัสไปรษณีย์",
                          _postcodeController,
                          isNumber: true,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SwitchListTile(
                title: const Text(
                  "ตั้งเป็นที่อยู่จัดส่งหลัก",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "ที่อยู่นี้จะถูกเลือกอัตโนมัติเมื่อสั่งซื้อสินค้า",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _isDefault,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => _isDefault = val),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
        ),
        validator: (val) => val!.isEmpty ? "กรุณากรอกข้อมูล" : null,
      ),
    );
  }
}

class FullScreenMapPicker extends StatefulWidget {
  final LatLng initialPosition;
  const FullScreenMapPicker({super.key, required this.initialPosition});
  @override
  State<FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<FullScreenMapPicker> {
  late LatLng _currentPosition;
  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 17,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onCameraMove: (pos) => _currentPosition = pos.target,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Icon(
                CupertinoIcons.location_solid,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Get.back(result: _currentPosition),
                  icon: const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "ยืนยันตำแหน่ง",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black,
                  size: 18,
                ),
                onPressed: () => Get.back(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
