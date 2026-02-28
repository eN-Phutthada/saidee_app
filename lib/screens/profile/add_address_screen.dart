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
    if (_isEditing && widget.existingData != null) {
      _loadExistingData();
    } else {
      _fetchUserProfile();
      _determinePosition();
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

    setState(() => _isMapReady = true);
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
            if (_nameController.text.isEmpty) {
              _nameController.text = data['name'] ?? '';
            }
            if (_phoneController.text.isEmpty) {
              _phoneController.text = data['phone'] ?? '';
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
      }
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isMapReady = true);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isMapReady = true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isMapReady = true);
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isMapReady = true;
    });

    if (!_isEditing) {
      _getAddressFromLatLng(_currentPosition);
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
          province = province
              .replaceAll('จ.', '')
              .replaceAll('Chang Wat', '')
              .trim();
          _provinceController.text = province;
          _postcodeController.text = place.postalCode ?? '';
        });
      }
    } catch (e) {
      debugPrint("Geocoding Error: $e");
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

  Future<void> _deleteAddress() async {
    Get.defaultDialog(
      title: "ลบที่อยู่",
      middleText: "คุณแน่ใจหรือไม่ที่จะลบที่อยู่นี้?",
      textConfirm: "ลบ",
      textCancel: "ยกเลิก",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: Colors.black,
      onConfirm: () async {
        Get.back();
        setState(() => _isLoading = true);
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && widget.docId != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('addresses')
                .doc(widget.docId)
                .delete();
            Get.back();
            Get.snackbar(
              "สำเร็จ",
              "ลบที่อยู่เรียบร้อยแล้ว",
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        } catch (e) {
          Get.snackbar("Error", e.toString());
        } finally {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

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

      if (!_isEditing) {
        addressData['created_at'] = FieldValue.serverTimestamp();
      }

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
        Get.back();
        Get.snackbar(
          "สำเร็จ",
          "แก้ไขที่อยู่เรียบร้อยแล้ว",
          backgroundColor: AppTheme.primaryColor,
          colorText: Colors.white,
        );
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .add(addressData);
        Get.back();
        Get.snackbar(
          "สำเร็จ",
          "เพิ่มที่อยู่เรียบร้อยแล้ว",
          backgroundColor: AppTheme.primaryColor,
          colorText: Colors.white,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? "แก้ไขที่อยู่" : "เพิ่มที่อยู่ใหม่",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _isLoading ? null : _deleteAddress,
              icon: const Icon(CupertinoIcons.delete),
              tooltip: "ลบที่อยู่",
            ),
          TextButton(
            onPressed: _isLoading ? null : _saveAddress,
            child: const Text(
              "บันทึก",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: !_isMapReady
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      GoogleMap(
                        onMapCreated: (controller) {
                          if (!_mapController.isCompleted) {
                            _mapController.complete(controller);
                          }
                        },
                        initialCameraPosition: CameraPosition(
                          target: _currentPosition,
                          zoom: 16,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        markers: {},
                        onCameraMoveStarted: () {
                          _canFetchAddress = true;
                        },
                        onCameraMove: (position) {
                          _currentPosition = position.target;
                        },
                        onCameraIdle: () {
                          if (_canFetchAddress) {
                            _getAddressFromLatLng(_currentPosition);
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30),
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
                          heroTag: "btn_fullscreen",
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
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("ข้อมูลผู้รับ"),
                    const SizedBox(height: 10),
                    _buildTextField("ชื่อ-นามสกุล", _nameController),
                    _buildTextField(
                      "เบอร์โทรศัพท์",
                      _phoneController,
                      isNumber: true,
                    ),

                    const SizedBox(height: 20),
                    _buildSectionHeader("รายละเอียดที่อยู่"),
                    const SizedBox(height: 10),
                    _buildTextField(
                      "บ้านเลขที่, ซอย, ถนน",
                      _addressDetailController,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            "จังหวัด",
                            _provinceController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            "เขต/อำเภอ",
                            _districtController,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            "แขวง/ตำบล",
                            _subDistrictController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            "รหัสไปรษณีย์",
                            _postcodeController,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text(
                        "ตั้งเป็นที่อยู่หลัก",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _isDefault,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) => setState(() => _isDefault = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).cardColor,
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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Icon(
                CupertinoIcons.location_solid,
                size: 50,
                color: Colors.red,
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(CupertinoIcons.back, color: Colors.black),
                onPressed: () => Get.back(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
