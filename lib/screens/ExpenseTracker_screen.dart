// lib/screens/ExpenseTracker_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  String _selectedCategory = 'Food';
  String _selectedMonth = 'January';
  String _selectedYear = DateTime.now().year.toString();
  double _totalSalary = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;
  final List<Map<String, dynamic>> _expenses = [];
  final List<String> _categories = ['Food', 'Travel', 'Entertainment', 'Other'];
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
    super.dispose();
  }

  Future<void> _saveSalaryToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('expenses').doc('${user.uid}-${_selectedMonth}-${_selectedYear}').set({
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
      await FirebaseFirestore.instance.collection('expenses').doc('${user.uid}-${_selectedMonth}-${_selectedYear}').set({
        'expenses': _expenses,
        'totalExpenses': _totalExpenses,
        'balance': _balance,
        'month': _selectedMonth,
        'year': _selectedYear,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('expenses').doc('${user.uid}-${_selectedMonth}-${_selectedYear}').get();
      if (doc.exists) {
        setState(() {
          _totalSalary = (doc['totalSalary'] as num?)?.toDouble() ?? 0.0;
          _totalExpenses = (doc['totalExpenses'] as num?)?.toDouble() ?? 0.0;
          _balance = (doc['balance'] as num?)?.toDouble() ?? 0.0;
          _expenses.clear();
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
          _expenses.clear();
        });
      }
    }
  }

  void _setSalary() {
    setState(() {
      _totalSalary = double.tryParse(_salaryController.text) ?? 0.0;
      _totalExpenses = _getFilteredExpenses().fold(0.0, (sum, expense) => sum + expense['amount']);
      _balance = _totalSalary - _totalExpenses;
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
          _totalExpenses += amount;
          _balance = _totalSalary - _totalExpenses;
        });
        _expenseAmountController.clear();
        _saveExpensesToFirestore();
      }
    }
  }

  void _deleteExpense(int index) {
    setState(() {
      _totalExpenses -= _expenses[index]['amount'];
      _balance = _totalSalary - _totalExpenses;
      _expenses.removeAt(index);
    });
    _saveExpensesToFirestore();
  }

  List<Map<String, dynamic>> _getFilteredExpenses() {
    return _expenses.where((expense) {
      return expense['month'] == _selectedMonth && expense['year'] == _selectedYear;
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
        titleStyle: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final backgroundColor = theme.cardColor;

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
              ],
            ),
            SizedBox(height: 20),

            // Salary and Balance Card
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
                      'Total Salary',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Rs $_totalSalary',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Balance',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Rs $_balance',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
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
                padding: EdgeInsets.symmetric(vertical: 20),
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
            ElevatedButton(
              onPressed: _addExpense,
              child: Text('Add Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            SizedBox(height: 20),

            // Expense Breakdown and List
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
                      'Expense Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _createChartData(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          startDegreeOffset: 0,
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, PieTouchResponse? response) {},
                          ),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Expenses',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
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