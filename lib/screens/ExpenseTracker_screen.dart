import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _years = List.generate(10, (index) =>
      (DateTime
          .now()
          .year - index).toString());
  double? _scannedAmount; // Temporarily store the scanned amount
  String? _scannedCategory; // Temporarily store the scanned category
  bool _showScannedDetails = false; // Control visibility of the confirmation UI sec
  String _selectedCategory = 'Food';
  String _selectedMonth = 'January';
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
      // Process the image to extract text
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
          inputImage);

      // Extract relevant information from the recognized text
      final String scannedText = recognizedText.text;
      final double? amount = _extractAmount(scannedText);
      final String? category = _extractCategory(scannedText);

      if (amount != null) {
        setState(() {
          _scannedAmount = amount; // Store the scanned amount
          _scannedCategory = category ??
              _selectedCategory; // Store the scanned category (or default)
          _showScannedDetails = true; // Show the confirmation UI section
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect amount from the bill.')),
        );
      }
    }
  }

  double? _extractAmount(String text) {
    final RegExp amountRegExp = RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{2})?\b');
    final List<String> identifiers = [
      'net amount', // Highest priority
      'Net Amt',
      'grand total',
      'total amount',
      'final amount',
      'balance due',
      'total',
      'amount',
      'due',
      'payable',
      'subtotal'
    ];
    final lowerText = text.toLowerCase();

    double? lastMatchAmount;
    int lastMatchIndex = -1;

    for (var identifier in identifiers) {
      final matches = identifier.allMatches(lowerText);
      for (final match in matches) {
        final substring = text.substring(match.end);
        final amountMatch = amountRegExp.firstMatch(substring);
        if (amountMatch != null) {
          final amountString = amountMatch.group(0)!.replaceAll(',', '');
          final amount = double.tryParse(amountString);
          if (amount != null) {
            if (match.start >
                lastMatchIndex) { // Ensures we get the last occurrence
              lastMatchAmount = amount;
              lastMatchIndex = match.start;
            }
          }
        }
      }
    }

    return lastMatchAmount;
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
        return Colors.red;
      case 'Travel':
        return Colors.blue;
      case 'Entertainment':
        return Colors.green;
      case 'Other':
        return Colors.yellow;
      case 'shopping':
        return Colors.purple;
      case 'rent':
        return Colors.orange;
      case 'bill':
        return Colors.pink;
      case 'grocery':
        return Colors.teal;
      case 'fuel':
        return Colors.indigo;
      default:
        return Colors.grey;
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
      appBar: AppBar(
        title: Text("Expense Tracker", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: Colors.blueAccent),
                  onPressed: () => _navigateMonth(false),
                ),
                SizedBox(width: 20),
                Text(
                  _selectedMonth,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 20),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
                  onPressed: () => _navigateMonth(true),
                ),
                SizedBox(width: 20),
                // Year Dropdown
                DropdownButton<String>(
                  value: _selectedYear,
                  onChanged: (String? newValue) {
                    if (newValue != _selectedYear) {
                      setState(() {
                        _selectedYear = newValue!;
                        // Close year comparison when changing years to avoid errors
                        _showYearComparison = false;
                      });
                      _loadDataFromFirestore(); // Reload data for the selected year
                    }
                  },
                  items: _years.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 20),

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
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.swap_horiz),
                              onPressed: _toggleView,
                              tooltip: _isMonthView
                                  ? 'Switch to Year View'
                                  : 'Switch to Month View',
                            ),
                            SizedBox(width: 8),
                            Text(_isMonthView ? 'Month' : 'Year'),
                          ],
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
            ElevatedButton(
              onPressed: _toggleYearComparison,
              child: Text(_showYearComparison
                  ? 'Hide Year Comparison'
                  : 'Compare Years'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
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
                      SizedBox(height: 10),
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
                                      'Income\nCurrent', 'Income\nPrev',
                                      'Expense\nCurrent', 'Expense\nPrev',
                                      'Savings\nCurrent', 'Savings\nPrev'
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
                      SizedBox(height: 15),
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
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_totalSalary',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent
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
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_balance',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green
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
            TextField(
              controller: _salaryController,
              decoration: InputDecoration(
                labelText: 'Enter Salary',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _setSalary,
              child: Text('Set Salary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              ),
            ),
            SizedBox(height: 20),

            // Add Expense Section
            TextField(
              controller: _expenseAmountController,
              decoration: InputDecoration(
                labelText: 'Enter Expense Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addExpense,
                    child: Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                          vertical: 20, horizontal: 10),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _scanBill,
                    child: Text('Scan Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(
                          vertical: 20, horizontal: 10),
                    ),
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