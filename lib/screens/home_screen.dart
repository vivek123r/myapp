import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key}); // ✅ Added const constructor

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _totalExpenses = 0.0;
  Map<String, double> _categoryExpenses = {};
  bool _isLoading = true;

  // Icons for each category
  final Map<String, IconData> categoryIcons = {
    'Food': Icons.fastfood,
    'Travel': Icons.directions_car,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_cart,
    'Bills': Icons.receipt,
  };

  // Colors for each category
  final Map<String, Color> categoryColors = {
    'Food': Colors.red,
    'Travel': Colors.blue,
    'Entertainment': Colors.green,
    'Shopping': Colors.purple,
    'Bills': Colors.orange,
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
    String currentMonth = DateFormat.MMMM().format(DateTime.now()); // e.g., "June"
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
            String category = value['category'] ?? 'Other';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker Home', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
        ],
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
                      '\$${_totalExpenses.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
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
            const SizedBox(height: 10),

            if (_categoryExpenses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No expenses recorded for this month.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._categoryExpenses.entries.map((entry) {
                final String category = entry.key;
                final double amount = entry.value;
                final double percentage = (_totalExpenses > 0) ? (amount / _totalExpenses) * 100 : 0.0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: Icon(
                      categoryIcons[category] ?? Icons.category,
                      color: categoryColors[category] ?? Colors.grey,
                    ),
                    title: Text(category),
                    subtitle: Text(
                      '${percentage.toStringAsFixed(1)}% of total expenses',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    trailing: Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: categoryColors[category] ?? Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
