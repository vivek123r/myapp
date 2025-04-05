import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoading
              ? [
            Colors.grey[400]!,
            Colors.grey[600]!,
          ]
              : [
            Colors.orange[300]!, // Light orange
            Colors.orange[800]!, // Dark orange
          ],
          begin: Alignment.centerLeft, // Gradient starts from the left
          end: Alignment.centerRight, // Gradient ends at the right
        ),
        borderRadius: BorderRadius.circular(10), // Rounded corners
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Make button background transparent
          shadowColor: Colors.transparent, // Remove shadow
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), // Button padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Match container's border radius
          ),
          disabledForegroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
        child: isLoading
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Processing',
              style: TextStyle(
                color: Colors.white, // Text color
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
            : Text(
          text,
          style: const TextStyle(
            color: Colors.white, // Text color
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();
  final String _apiKey = 'AIzaSyAO0YfwN6N-jJt81C5Q3pomey7e1oAIKrU';
  final List<String> _years = List.generate(10, (index) =>
      (DateTime
          .now()
          .year - index).toString());
  double? _scannedAmount; // Temporarily store the scanned amount
  String? _scannedCategory; // Temporarily store the scanned category
  bool _showScannedDetails = false; // Control visibility of the confirmation UI sec
  String _selectedCategory = 'Food';
  bool _isLoading = false;
  String _selectedMonth = DateTime.now().month == 1
      ? 'January' : DateTime.now().month == 2
      ? 'February' : DateTime.now().month == 3
      ? 'March' : DateTime.now().month == 4
      ? 'April' : DateTime.now().month == 5
      ? 'May' : DateTime.now().month == 6
      ? 'June' : DateTime.now().month == 7
      ? 'July' : DateTime.now().month == 8
      ? 'August' : DateTime.now().month == 9
      ? 'September' : DateTime.now().month == 10
      ? 'October' : DateTime.now().month == 11
      ? 'November' : 'December';

  String _selectedYear = DateTime
      .now()
      .year
      .toString();
  double _totalSalary = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;
  String _comparisonYear = (DateTime
      .now()
      .year - 1).toString();
  bool _isMonthView = true; // Toggle between month and year view
  bool _showYearComparison = false; // Toggle for year comparison view
  Map<String, double> _yearlyTotals = {
  }; // To store yearly totals for comparison
  Map<String, double> _yearlyExpenses = {
  }; // To store yearly expenses for comparison
  Map<String, double> _yearlySavings = {
  }; // To store yearly savings for comparison
  final List<Map<String, dynamic>> _expenses = [];
  final List<String> _categories = [
    'Food',
    'Travel',
    'Entertainment',
    'Other',
    'shopping',
    'rent',
    'bill',
    'grocery',
    'fuel'
  ];
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _expenseAmountController.dispose();
    _yearController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _scanBill() async {
    // Pick an image from the gallery or camera
    final XFile? imageFile = await _imagePicker.pickImage(
        source: ImageSource.camera);

    if (imageFile != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Process the image with Gemini API
        final result = await _processImageWithGemini(imageFile.path);

        if (result != null) {
          setState(() {
            _scannedAmount = result['amount'];
            _scannedCategory = result['category'] ?? _selectedCategory;
            _showScannedDetails = true;
            _isLoading = false;
          });

          print('EXTRACTED AMOUNT: ${result['amount']}');
          print('EXTRACTED CATEGORY: ${result['category']}');
        } else {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not detect amount from the bill.')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        print('Error scanning bill: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: ${e.toString()}')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _processImageWithGemini(String imagePath) async {
    // Read image file as bytes
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();

    // Initialize the Gemini API
    final generativeModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
    );

    // Create prompt with specific instructions for bill analysis
    const String promptText = '''
Analyze this bill or receipt image. Extract the total amount to be paid. Look for the final amount, which may be labeled as:
- "Total"
- "Grand Total"
- "Amount Due"
- "Net Amount"
- "Final Amount"

If multiple amounts are present, use the final amount that includes all charges (e.g., subtotal, tax, discount).

IMPORTANT: First identify the currency based on:
1. Currency symbols present (₹, \$, €, £, ¥, etc.)
2. Currency codes mentioned (INR, USD, EUR, GBP, JPY, etc.)
3. Language of the receipt (e.g., if in Thai, assume THB unless otherwise specified)
4. Country-specific formatting or indicators

If the amount is in any currency other than Indian Rupees (INR), convert it to INR using these approximate exchange rates:
- 1 USD = 85.52 INR
- 1 EUR = 92.4 INR
- 1 GBP = 110.53 INR
- 1 AUD = 53.51 INR
- 1 CAD = 59.45 INR
- 1 JPY = 0.57 INR
- 1 CNY = 11.78 INR
- 1 AED = 23.28 INR
- For other currencies, make your best estimation based on current global rates

Always return the amount in INR.

Additionally, if you can confidently determine the category of the bill (e.g., Food, Travel, Entertainment, Shopping, etc.), include it in the response.

Return ONLY a JSON object with the following fields:
- "amount" (as a numeric value in INR, with no currency symbol)
- "currency" (always "INR")
- "original_currency" (the original currency code if different from INR)
- "original_amount" (the original amount before conversion, if different from INR)
- "category" (as a string, only if you can confidently determine it)
- "detection_method" (how the original currency was determined: "symbol", "code", "language", or "context")

Example 1: {"amount": 467.00, "currency": "INR", "category": "Food"}
Example 2: {"amount": 8924.50, "currency": "INR", "original_currency": "USD", "original_amount": 107.50, "detection_method": "symbol"}
Example 3: {"amount": 120.50, "currency": "INR"}
''';

    try {
      // Create the prompt content
      final prompt = TextPart(promptText);

      // Create the image content
      final imagePart = DataPart('image/jpeg', imageBytes);

      // Combine text and image in a single content
      final content = Content.multi([prompt, imagePart]);

      // Generate content with the Gemini API
      final response = await generativeModel.generateContent([content]);
      final responseText = response.text;

      print('GEMINI RESPONSE: $responseText');

      // Parse the JSON response
      if (responseText != null && responseText.isNotEmpty) {
        try {
          // Extract JSON from the response (handling potential text wrapping)
          final jsonPattern = RegExp(r'\{.*\}', dotAll: true);
          final match = jsonPattern.firstMatch(responseText);

          if (match != null) {
            final jsonStr = match.group(0);
            final Map<String, dynamic> data = jsonDecode(jsonStr!);

            // Validate and return the extracted data
            if (data.containsKey('amount') && data['amount'] != null) {
              // Convert to double if it's a number or string
              final amount = data['amount'] is num
                  ? (data['amount'] as num).toDouble()
                  : double.tryParse(data['amount'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));

              if (amount != null) {
                // Validate the category
                String category = data['category']?.toString() ?? 'Other';
                if (!_categories.contains(category)) {
                  category = 'Other'; // Default to "Other" if category is not in the list
                }

                return {
                  'amount': amount,
                  'category': category,
                };
              }
            }
          }
        } catch (e) {
          print('JSON parsing error: $e');
        }
      }
    } catch (e) {
      print('Gemini API error: $e');
      rethrow;
    }

    return null;
  }


  String? _extractCategory(String text) {
    // Use simple logic to detect category based on keywords
    if (text.toLowerCase().contains('food') ||
        text.toLowerCase().contains('restaurant')) {
      return 'Food';
    } else if (text.toLowerCase().contains('travel') ||
        text.toLowerCase().contains('fuel')) {
      return 'Travel';
    } else if (text.toLowerCase().contains('movie') ||
        text.toLowerCase().contains('entertainment')) {
      return 'Entertainment';
    } else {
      return 'Other';
    }
  }

  void _showSalaryDialog(BuildContext context) {
    // Create a TextEditingController for the dialog
    final TextEditingController dialogController = TextEditingController();

    // Pre-fill with existing value if available
    if (_salaryController.text.isNotEmpty) {
      dialogController.text = _salaryController.text;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Enter Your Salary',
            style: TextStyle(
              color: Colors.orange[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: dialogController,
            autofocus: true, // Automatically show keyboard
            decoration: InputDecoration(
              labelText: 'Salary',
              labelStyle: TextStyle(color: Colors.orange[300]),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.orange[100]!,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.orange[500]!,
                  width: 2,
                ),
              ),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.orange[300]),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[300]!,
                    Colors.orange[800]!,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  // Update the main controller
                  _salaryController.text = dialogController.text;

                  // Call your existing salary update method
                  _setSalary();

                  // Close the dialog
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: Colors.transparent,
                ),
                child: Text(
                  'Update',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSalaryToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('expenses').doc(
          '${user.uid}-${_selectedMonth}-${_selectedYear}').set({
        'totalSalary': _totalSalary,
        'balance': _balance,
        'month': _selectedMonth,
        'year': _selectedYear,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _saveExpensesToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('expenses').doc(
          '${user.uid}-${_selectedMonth}-${_selectedYear}').set({
        'expenses': _expenses.where((expense) =>
        expense['month'] == _selectedMonth &&
            expense['year'] == _selectedYear).toList(),
        'totalExpenses': _totalExpenses,
        'balance': _balance,
        'month': _selectedMonth,
        'year': _selectedYear,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadYearlyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Clear existing data
        setState(() {
          _yearlyTotals.clear();
          _yearlyExpenses.clear();
          _yearlySavings.clear();
        });

        // Load data for each year
        for (String year in _years) {
          double yearSalary = 0.0;
          double yearExpenses = 0.0;

          // Gather data for each month in the year
          for (String month in _months) {
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('expenses')
                  .doc('${user.uid}-$month-$year')
                  .get();

              if (doc.exists) {
                yearSalary += (doc['totalSalary'] as num?)?.toDouble() ?? 0.0;
                yearExpenses += (doc['totalExpenses'] as num?)?.toDouble() ?? 0.0;
              }
            } catch (e) {
              print('Error loading data for $month-$year: $e');
              // Continue with other months even if one fails
              continue;
            }
          }

          // Store yearly totals
          setState(() {
            _yearlyTotals[year] = yearSalary;
            _yearlyExpenses[year] = yearExpenses;
            _yearlySavings[year] = yearSalary - yearExpenses;
          });
        }
      } catch (e) {
        print('Error in _loadYearlyData: $e');
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading yearly data. Please try again.')),
        );
        // Close the comparison view if there was an error
        setState(() {
          _showYearComparison = false;
        });
      }
    }
  }

//  Add this method to toggle between month and year view
  void _toggleView() {
    setState(() {
      _isMonthView = !_isMonthView;
    });
  }

//  Add this method to toggle year comparison view
  void _toggleYearComparison() {
    setState(() {
      _showYearComparison = !_showYearComparison;
      if (_showYearComparison) {
        // Automatically set comparison year to previous year
        _comparisonYear = (int.parse(_selectedYear) - 1).toString();
        _loadYearlyData();
      }
    });
  }

// Add this method to create year comparison chart data
  List<BarChartGroupData> _createYearComparisonData() {
    List<BarChartGroupData> barGroups = [];

    // Only attempt to show comparison if both years' data exists
    final selectedYearExists = _yearlyTotals.containsKey(_selectedYear);
    final comparisonYearExists = _yearlyTotals.containsKey(_comparisonYear);

    if (selectedYearExists) {
      // Current year income
      barGroups.add(
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: _yearlyTotals[_selectedYear] ?? 0,
              color: Colors.blue,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );

      // Current year expenses
      barGroups.add(
        BarChartGroupData(
          x: 2,
          barRods: [
            BarChartRodData(
              toY: _yearlyExpenses[_selectedYear] ?? 0,
              color: Colors.red,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );

      // Current year savings
      barGroups.add(
        BarChartGroupData(
          x: 4,
          barRods: [
            BarChartRodData(
              toY: _yearlySavings[_selectedYear] ?? 0,
              color: Colors.green,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    if (comparisonYearExists) {
      // Comparison year income
      barGroups.add(
        BarChartGroupData(
          x: 1,
          barRods: [
            BarChartRodData(
              toY: _yearlyTotals[_comparisonYear] ?? 0,
              color: Colors.blueGrey,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );

      // Comparison year expenses
      barGroups.add(
        BarChartGroupData(
          x: 3,
          barRods: [
            BarChartRodData(
              toY: _yearlyExpenses[_comparisonYear] ?? 0,
              color: Colors.redAccent,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );

      // Comparison year savings
      barGroups.add(
        BarChartGroupData(
          x: 5,
          barRods: [
            BarChartRodData(
              toY: _yearlySavings[_comparisonYear] ?? 0,
              color: Colors.lightGreen,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return barGroups;
  }

// Add this method to create yearly data for pie chart
  List<PieChartSectionData> _createYearlyChartData() {
    final data = <String, double>{};

    // Filter expenses for the selected year
    final yearlyExpenses = _expenses.where((expense) {
      return expense['year'] == _selectedYear;
    }).toList();

    // Group by category
    for (var expense in yearlyExpenses) {
      final category = expense['category'] as String;
      final amount = (expense['amount'] as num).toDouble();
      data[category] = (data[category] ?? 0) + amount;
    }

    // Create pie chart sections
    return data.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        color: _getColorForCategory(entry.key),
        title: entry.key,
        radius: 40,
        titleStyle: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold
        ),
        showTitle: entry.value > 10,
      );
    }).toList();
  }

  Future<void> _loadDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('expenses').doc(
          '${user.uid}-${_selectedMonth}-${_selectedYear}').get();

      if (doc.exists) {
        setState(() {
          _totalSalary = (doc['totalSalary'] as num?)?.toDouble() ?? 0.0;
          _totalExpenses = (doc['totalExpenses'] as num?)?.toDouble() ?? 0.0;
          _balance = (doc['balance'] as num?)?.toDouble() ?? 0.0;

          // Clear only expenses for the current month/year
          _expenses.removeWhere((expense) =>
          expense['month'] == _selectedMonth &&
              expense['year'] == _selectedYear);

          if (doc['expenses'] is List) {
            for (var value in doc['expenses']) {
              _expenses.add(Map<String, dynamic>.from(value));
            }
          }
        });
      } else {
        setState(() {
          _totalSalary = 0.0;
          _totalExpenses = 0.0;
          _balance = 0.0;
          // Clear only expenses for the current month/year
          _expenses.removeWhere((expense) =>
          expense['month'] == _selectedMonth &&
              expense['year'] == _selectedYear);
        });
      }

      // Recalculate totals based on the filtered expenses
      _recalculateTotals();
    }
  }

  void _recalculateTotals() {
    final filteredExpenses = _getFilteredExpenses();
    setState(() {
      _totalExpenses = filteredExpenses.fold(
          0.0, (sum, expense) => sum + (expense['amount'] as num).toDouble());
      _balance = _totalSalary - _totalExpenses;
    });
  }

  void _setSalary() {
    setState(() {
      _totalSalary = double.tryParse(_salaryController.text) ?? 0.0;
      _recalculateTotals();
    });
    _saveSalaryToFirestore();
  }

  void _addExpense() {
    final amount = double.tryParse(_expenseAmountController.text);
    if (amount != null && amount > 0) {
      if (amount > _balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense amount exceeds balance!')),
        );
      } else {
        setState(() {
          _expenses.add({
            'category': _selectedCategory,
            'amount': amount,
            'date': DateTime.now().toString(),
            'month': _selectedMonth,
            'year': _selectedYear,
          });
          _recalculateTotals();
        });
        _expenseAmountController.clear();
        _saveExpensesToFirestore();
      }
    }
  }

  void _deleteExpense(int index) {
    final filteredExpenses = _getFilteredExpenses();
    final expenseToDelete = filteredExpenses[index];

    setState(() {
      _expenses.remove(expenseToDelete);
      _recalculateTotals();
    });
    _saveExpensesToFirestore();
  }

  List<Map<String, dynamic>> _getFilteredExpenses() {
    return _expenses.where((expense) {
      return expense['month'] == _selectedMonth &&
          expense['year'] == _selectedYear;
    }).toList();
  }

  List<PieChartSectionData> _createChartData() {
    final filteredExpenses = _getFilteredExpenses();
    final data = filteredExpenses.fold<Map<String, double>>({}, (map, expense) {
      final category = expense['category'] as String;
      final amount = (expense['amount'] as num).toDouble();
      map[category] = (map[category] ?? 0) + amount;
      return map;
    });

    final chartData = data.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        color: _getColorForCategory(entry.key),
        title: entry.key,
        radius: 40,
        titleStyle: TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        showTitle: entry.value > 10,
      );
    }).toList();

    return chartData;
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange[300]!; // Light orange
      case 'Travel':
        return Colors.orange[400]!; // Slightly darker orange
      case 'Entertainment':
        return Colors.orange[500]!; // Medium orange
      case 'Other':
        return Colors.orange[600]!; // Darker orange
      case 'shopping':
        return Colors.orange[700]!; // Even darker orange
      case 'rent':
        return Colors.orange[800]!; // Very dark orange
      case 'bill':
        return Colors.orange[900]!; // Darkest orange
      case 'grocery':
        return Colors.deepOrange[300]!; // Deep orange shade
      case 'fuel':
        return Colors.deepOrange[400]!; // Slightly darker deep orange
      default:
        return Colors.grey; // Fallback color
    }
  }

  void _navigateMonth(bool isNext) {
    final currentIndex = _months.indexOf(_selectedMonth);
    int newIndex;
    if (isNext) {
      newIndex = (currentIndex + 1) % _months.length;
    } else {
      newIndex = (currentIndex - 1) % _months.length;
      if (newIndex < 0) newIndex = _months.length - 1;
    }
    setState(() {
      _selectedMonth = _months[newIndex];
      _loadDataFromFirestore();
    });
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Navigation
            // Month Navigation Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Month Button
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.orange[200]),
                      onPressed: () => _navigateMonth(false),
                    ),
                    // Current Month and Year
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedMonth,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(height: 3),
                        DropdownButton<String>(
                          value: _selectedYear,
                          underline: Container(), // Remove the default underline
                          icon: Icon(Icons.arrow_drop_down, color: Colors.orange[400]),
                          onChanged: (String? newValue) {
                            if (newValue != _selectedYear) {
                              setState(() {
                                _selectedYear = newValue!;
                                _showYearComparison = false; // Close comparison when changing years
                              });
                              _loadDataFromFirestore(); // Reload data for the selected year
                            }
                          },
                          items: _years.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(color: Colors.orange),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    // Next Month Button
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, color: Colors.orange[200]),
                      onPressed: () => _navigateMonth(true),
                    ),
                  ],
                ),
              ),
            ),
            // Expense Breakdown Graph
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expense Breakdown',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight
                              .bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _isMonthView
                              ? _createChartData()
                              : _createYearlyChartData(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          startDegreeOffset: 0,
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event,
                                PieTouchResponse? response) {},
                          ),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            GradientButton(
              text: _showYearComparison ? 'Hide Year Comparison' : 'Compare Years',
              onPressed: _toggleYearComparison,
            ),
            SizedBox(height: 10),
            if (_showYearComparison) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Yearly Comparison',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              DropdownButton<String>(
                                value: _comparisonYear,
                                onChanged: (String? newValue) {
                                  if (newValue != null &&
                                      newValue != _selectedYear) {
                                    setState(() {
                                      _comparisonYear = newValue;
                                    });
                                  }
                                },
                                items: _years
                                    .where((year) => year != _selectedYear)
                                    .map<DropdownMenuItem<String>>((
                                    String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      SizedBox(
                        height: 250,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(
                              enabled: true,
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value,
                                      TitleMeta meta) {
                                    const titles = [
                                      '', '',
                                      '', '',
                                      '', ''
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        titles[value.toInt()],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value,
                                      TitleMeta meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: _createYearComparisonData(),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildLegendItem('Current Income', Colors.blue),
                          _buildLegendItem('Previous Income', Colors.blueGrey),
                          _buildLegendItem('Current Expenses', Colors.red),
                          _buildLegendItem('Previous Expenses', Colors
                              .redAccent),
                          _buildLegendItem('Current Savings', Colors.green),
                          _buildLegendItem('Previous Savings', Colors
                              .lightGreen),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Total Savings: ${(_yearlySavings[_selectedYear] ?? 0)
                            .toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Savings Rate: ${_yearlyTotals[_selectedYear] != 0 ?
                        ((_yearlySavings[_selectedYear] ?? 0) /
                            (_yearlyTotals[_selectedYear] ?? 1) * 100)
                            .toStringAsFixed(1) : 0}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Total Salary and Balance Side by Side
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Total Salary',
                            style: TextStyle(
                                fontSize: 16, color: Colors.orange),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_totalSalary',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[100]
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(
                                fontSize: 16, color: Colors.orange),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_balance',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[100]
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Add Salary Section
            SizedBox(height: 10),
            GradientButton(
              text: 'Set Salary',
              onPressed: () => _showSalaryDialog(context),
            ),
            SizedBox(height: 20),

            // Add Expense Section
            TextField(
              controller: _expenseAmountController,
              decoration: InputDecoration(
                labelText: 'Enter Expense Amount',
                labelStyle: TextStyle(color: Colors.orange[100]), // Light orange label text
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                  borderSide: BorderSide(
                    color: Colors.orange[100]!, // Light orange border when not focused
                    width: 2, // Border thickness
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                  borderSide: BorderSide(
                    color: Colors.orange[500]!, // Darker orange border when focused
                    width: 2, // Border thickness
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.orange[300]), // Light orange input text
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: Colors.orange[100]), // Light orange label text
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                  borderSide: BorderSide(
                    color: Colors.orange[100]!, // Light orange border when not focused
                    width: 2, // Border thickness
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                  borderSide: BorderSide(
                    color: Colors.orange[100]!, // Darker orange border when focused
                    width: 2, // Border thickness
                  ),
                ),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    category,
                    style: TextStyle(color: Colors.orange[100]), // Light orange dropdown text
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: 'Add Expense',
                    onPressed: _addExpense,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: GradientButton(
                    text: 'Scan Bill',
                    onPressed: _scanBill,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Scanned Bill Details Section
            if (_showScannedDetails) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanned Bill Details',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Amount: $_scannedAmount',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _scannedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _scannedCategory = newValue!;
                          });
                        },
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _expenseAmountController.text =
                                      _scannedAmount!.toString();
                                  _selectedCategory = _scannedCategory!;
                                  _showScannedDetails = false;
                                });
                              },
                              child: Text('Confirm'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showScannedDetails = false;
                                });
                              },
                              child: Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Expense List
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
                      'Expenses',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: 230,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: _getFilteredExpenses().length,
                        itemBuilder: (context, index) {
                          final expense = _getFilteredExpenses()[index];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              title: Text(expense['category']),
                              subtitle: Text('Rs ${expense['amount']}'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteExpense(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}