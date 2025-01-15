import 'package:flutter/material.dart';

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
  final List<Map<String, dynamic>> _expenses = [];

  final List<String> _categories = ['Food', 'Travel', 'Entertainment', 'Other'];

  void _addExpense() {
    final amount = double.tryParse(_expenseAmountController.text);
    if (amount != null) {
      setState(() {
        _expenses.add({'category': _selectedCategory, 'amount': amount});
        _totalExpenses += amount;
      });
      _expenseAmountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _salaryController,
            decoration: const InputDecoration(labelText: 'Enter Salary'),
            keyboardType: TextInputType.number,
          ),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Set Salary'),
          ),
          // Expenses Section
        ],
      ),
    );
  }
}
