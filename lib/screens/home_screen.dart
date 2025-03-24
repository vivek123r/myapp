import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _totalExpenses = 0.0;
  Map<String, double> _categoryExpenses = {};
  bool _isLoading = true;

  // Full list of possible categories
  final List<String> _categories = [
    'Food',
    'Travel',
    'Entertainment',
    'Other',
    'Shopping',
    'Rent',
    'Bill',
    'Grocery',
    'Fuel'
  ];

  // Icons for each category - updated with all categories
  final Map<String, IconData> categoryIcons = {
    'Food': Icons.fastfood,
    'Travel': Icons.directions_car,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_cart,
    'Rent': Icons.home,
    'Bill': Icons.receipt,
    'Grocery': Icons.local_grocery_store,
    'Fuel': Icons.local_gas_station,
    'Other': Icons.category,
  };

  // This will be replaced with actual images later
  final Map<String, String> categoryBackgrounds = {
    'Food': 'lib/Assets/backgrounds/food.jpg',
    'Travel': 'lib/Assets/backgrounds/travel.jpeg',
    'Entertainment': 'lib/Assets/backgrounds/entertainment.png',
    'Shopping': 'lib/Assets/backgrounds/shopping.jpg',
    'Rent': 'lib/Assets/backgrounds/rent.webp',
    'Bill': 'lib/Assets/backgrounds/bill.webp',
    'Grocery': 'lib/Assets/backgrounds/grocery.jpeg',
    'Fuel': 'lib/Assets/backgrounds/fuel.webp',
    'Other': 'lib/Assets/backgrounds/others.jpg',
  };

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  Future<void> _loadDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get current month and year
    String currentMonth = DateFormat.MMMM().format(DateTime.now());
    int currentYear = DateTime.now().year;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('expenses')
          .doc('${user.uid}-$currentMonth-$currentYear')
          .get();

      if (doc.exists) {
        Map<String, double> categoryData = {};
        double totalExpenses = (doc['totalExpenses'] as num?)?.toDouble() ?? 0.0;

        if (doc['expenses'] is List) {
          for (var value in doc['expenses']) {
            // Normalize category name to match our standard format (capitalize first letter)
            String rawCategory = value['category'] ?? 'Other';
            String category = _normalizeCategory(rawCategory);

            double amount = (value['amount'] as num?)?.toDouble() ?? 0.0;

            if (categoryData.containsKey(category)) {
              categoryData[category] = categoryData[category]! + amount;
            } else {
              categoryData[category] = amount;
            }
          }
        }

        setState(() {
          _totalExpenses = totalExpenses;
          _categoryExpenses = categoryData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _totalExpenses = 0.0;
          _categoryExpenses = {};
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper function to normalize category names
  String _normalizeCategory(String category) {
    // Capitalize first letter and lowercase the rest
    if (category.isEmpty) return 'Other';

    String normalized = category.trim().toLowerCase();
    normalized = normalized[0].toUpperCase() + normalized.substring(1);

    // Check if it's one of our standard categories
    for (String standardCategory in _categories) {
      if (normalized == standardCategory.toLowerCase()) {
        return standardCategory;
      }
    }

    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HOME',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(40),
          ),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('lib/Assets/icon/natural-mint-leafs.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Total Expenses Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Total Expenses',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _totalExpenses.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Breakdown
            const Text(
              'Category Breakdown',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _categoryExpenses.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No expenses recorded for this month.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            )
                : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _categoryExpenses.length,
              itemBuilder: (context, index) {
                final category = _categoryExpenses.keys.elementAt(index);
                final amount = _categoryExpenses[category] ?? 0.0;

                return categoryCard(
                  category: category,
                  amount: amount,
                  context: context,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget categoryCard({
    required String category,
    required double amount,
    required BuildContext context,
  }) {
    // Default placeholder background if you don't have images yet
    final defaultBackground = 'lib/Assets/icon/natural-mint-leafs.jpg';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Background Image
          Image.asset(
            categoryBackgrounds[category] ?? defaultBackground,
            height: double.infinity,
            width: double.infinity,
            fit: BoxFit.cover,
          ),

          // Darkening Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIcons[category] ?? Icons.category,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                // Category Name and Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}