import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sms_service.dart';
import '../models/transaction.dart';
import '../models/balance.dart';
import '../utils/logger_util.dart';
import 'dart:convert';  // To convert the list into JSON

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final SmsService _smsService = SmsService();
  final logger = LoggerUtil.logger;
  final List<Transaction> _transactions = [];
  Balance _balance = Balance(amount: 0.0);
  final TextEditingController _manualBalanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenForNewSms();
    _loadTransactions(); // Load saved transactions when the screen is initialized
  }

  Future<void> _listenForNewSms() async {
    _smsService.onNewBankMessage.listen((Transaction transaction) {
      setState(() {
        _transactions.insert(0, transaction);
        _balance.updateBalance(transaction);
      });
      _saveTransactions(); // Save the updated transaction list
      logger.d('New Transaction: ${transaction.toString()}');
    });
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? transactionsJson = prefs.getString('transactions');
    if (transactionsJson != null) {
      final List<dynamic> decodedData = jsonDecode(transactionsJson);
      setState(() {
        _transactions.addAll(decodedData.map((e) => Transaction.fromJson(e)).toList());
      });
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String transactionsJson = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await prefs.setString('transactions', transactionsJson);
  }

  @override
  void dispose() {
    _smsService.dispose();
    _manualBalanceController.dispose();
    super.dispose();
  }

  void _updateBalanceManually() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter New Balance'),
          content: TextField(
            controller: _manualBalanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'New Balance',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newBalance = double.tryParse(_manualBalanceController.text);
                if (newBalance != null) {
                  setState(() {
                    _balance.amount = newBalance;
                  });
                  _manualBalanceController.clear();
                  Navigator.pop(context); // Close the dialog
                } else {
                  // Show an error message if the input is invalid
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid balance amount')),
                  );
                }
              },
              child: const Text('Update Balance'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Balance Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance: \$${_balance.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateBalanceManually,
              child: const Text('Update Balance'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Transaction History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return ListTile(
                    title: Text(transaction.type),
                    subtitle: Text('\$${transaction.amount.toStringAsFixed(2)}'),
                    trailing: Text(transaction.date.toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
