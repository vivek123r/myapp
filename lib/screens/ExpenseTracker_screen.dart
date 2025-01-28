import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  String _selectedCategory = 'Food';
  double _totalSalary = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;
  final List<Map<String, dynamic>> _expenses = [];

  final List<String> _categories = ['Food', 'Travel', 'Entertainment', 'Other'];

  @override
  void dispose() {
    _salaryController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _setSalary() {
    setState(() {
      _totalSalary = double.tryParse(_salaryController.text) ?? 0.0;
      _balance = _totalSalary - _totalExpenses;
    });
    _saveSalaryToFirestore();
  }

  void _addExpense() {
    final amount = double.tryParse(_expenseAmountController.text);
    if (amount != null) {
      if (amount > _balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense amount exceeds the current balance!'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _expenses.add({'category': _selectedCategory, 'amount': amount, 'date': DateTime.now()});
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

  Future<void> _saveSalaryToFirestore() async {
    await FirebaseFirestore.instance.collection('expenses').doc('sLF3aT6ZgV4CdaZxzwUL').set({
      'totalSalary': _totalSalary,
      'balance': _balance,
    });
  }

  Future<void> _saveExpensesToFirestore() async {
    await FirebaseFirestore.instance.collection('expenses').doc('sLF3aT6ZgV4CdaZxzwUL').update({
      'expenses': _expenses,
      'totalExpenses': _totalExpenses,
      'balance': _balance,
    });
  }

  Future<void> _loadDataFromFirestore() async {
    final doc = await FirebaseFirestore.instance.collection('expenses').doc('sLF3aT6ZgV4CdaZxzwUL').get();
    if (doc.exists) {
      setState(() {
        _totalSalary = (doc['totalSalary'] as num).toDouble();
        _totalExpenses = (doc['totalExpenses'] as num).toDouble();
        _balance = (doc['balance'] as num).toDouble();
        _expenses.clear();
        if (doc['expenses'] is List) {
          (doc['expenses'] as List<dynamic>).forEach((value) {
            _expenses.add(Map<String, dynamic>.from(value));
          });
        }
        if (_totalExpenses == 0) {
          _balance = _totalSalary;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  List<PieChartSectionData> _createChartData() {
    final data = _expenses.fold<Map<String, double>>({}, (Map<String, double> map, expense) {
      final category = expense['category'] as String;
      final amount = expense['amount'] as double;
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
        showTitle: entry.value > 10, // Show title only if the value is greater than 10
      );
    }).toList();

    // Add balance section
    chartData.add(PieChartSectionData(
      value: _balance,
      color: Colors.grey,
      title: 'Balance',
      radius: 40,
      titleStyle: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      showTitle: _balance > 10,
      // Show title only if the balance is greater than 10
    ));

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

  void _showDeleteExpenseModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: _expenses.length,
          itemBuilder: (context, index) {
            final expense = _expenses[index];
            return ListTile(
              title: Text('${expense['category']}: Rs${expense['amount']}'),
              subtitle: Text(expense['date'].toString()),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _deleteExpense(index);
                  Navigator.pop(context);
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0), // Adjust the padding value as needed
            child: Text(
              'Expense Tracker',
              style: TextStyle(
                color: Color(0xFF000000), // Mint color
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.teal, // Set the background color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('Total Salary: Rs$_totalSalary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8.0),
                  Text('Balance: Rs$_balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            TextField(
              controller: _salaryController,
              decoration: const InputDecoration(labelText: 'Enter Salary'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: _setSalary,
              child: const Text('Set Salary'),
            ),
            TextField(
              controller: _expenseAmountController,
              decoration: const InputDecoration(labelText: 'Enter Expense Amount'),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: _selectedCategory,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
              items: _categories.map<DropdownMenuItem<String>>((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _addExpense,
                  child: const Text('Add Expense'),
                ),
                ElevatedButton(
                  onPressed: _showDeleteExpenseModal,
                  child: const Text('Remove Expense'),
                ),
              ],
            ),
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: _createChartData(),
                  centerSpaceRadius: double.infinity,
                  centerSpaceColor: Colors.transparent,
                  sectionsSpace: 2,
                  startDegreeOffset: 0,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                      // Handle touch events here
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
                duration: Duration(milliseconds: 150),
                curve: Curves.linear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}