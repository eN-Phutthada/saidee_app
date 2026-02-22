import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saidee_app/config/theme.dart';
import 'search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCategory;
  String? _selectedType;
  String? _selectedSize;
  final List<String> _sizes = [
    'SS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'Freesize',
    'อื่นๆ',
  ];

  void _onSearch() {
    Get.to(
      () => SearchResultsScreen(
        keyword: _searchController.text.trim(),
        category: _selectedCategory,
        type: _selectedType,
        size: _selectedSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.primaryColor),
          onPressed: () => Get.back(),
        ),
        title: TextField(
          controller: _searchController,
          onSubmitted: (_) => _onSearch(),
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: "ค้นหาสินค้าหรือแบรนด์ที่ต้องการ",
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: isDark ? Colors.grey[400] : Colors.black87,
              size: 20,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "หมวดหมู่",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final categories = snapshot.data!.docs
                    .map((e) => e['name'] as String)
                    .toList();
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: categories
                      .map(
                        (cat) => _buildFilterChip(
                          label: cat,
                          isSelected: _selectedCategory == cat,
                          onSelected: (val) => setState(
                            () => _selectedCategory = val ? cat : null,
                          ),
                          isDark: isDark,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 25),

            Text(
              "ประเภท",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('types')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final types = snapshot.data!.docs
                    .map((e) => e['name'] as String)
                    .toList();
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: types
                      .map(
                        (type) => _buildFilterChip(
                          label: type,
                          isSelected: _selectedType == type,
                          onSelected: (val) =>
                              setState(() => _selectedType = val ? type : null),
                          isDark: isDark,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 25),

            Text(
              "ไซส์",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _sizes
                  .map(
                    (size) => _buildFilterChip(
                      label: size,
                      isSelected: _selectedSize == size,
                      onSelected: (val) =>
                          setState(() => _selectedSize = val ? size : null),
                      isDark: isDark,
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "ค้นหาสินค้า",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
    required bool isDark,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE8F5E9),
      selectedColor: AppTheme.primaryColor.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected
            ? AppTheme.primaryColor
            : (isDark ? Colors.grey[300] : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    );
  }
}
