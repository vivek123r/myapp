import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // Alias for Firestore
import '../services/sms_service.dart';
import '../models/transaction.dart'; // Your custom Transaction model
import '../models/balance.dart';
import '../utils/logger_util.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final SmsService _smsService = SmsService();
  final logger = LoggerUtil.logger;
  final List<Transaction> _transactions = [];
  final Balance _balance = Balance(amount: 0.0);
  final TextEditingController _manualBalanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ensureAuthenticated().then((_) {
      _loadTransactionsFromFirebase();
      _loadBalanceFromFirebase();
    });
    _listenForNewSms();
  }
  Future<void> ensureAuthenticated() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        logger.d("Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}");
      } catch (e) {
        logger.e("Anonymous sign-in failed: $e");
      }
    } else {
      logger.d("Already signed in: ${user.uid}");
    }
  }
  Future<void> _listenForNewSms() async {
    _smsService.onNewBankMessage.listen((Transaction transaction) {
      setState(() {
        if (transaction.type == 'Credit') {
          _balance.amount += transaction.amount;
        } else if (transaction.type == 'Debit') {
          _balance.amount -= transaction.amount;
        }
        _transactions.insert(0, transaction);
      });
      _saveTransactionToFirebase(transaction);
      logger.d('New Transaction: \${transaction.toString()}');
    });
  }

  Future<void> _loadTransactionsFromFirebase() async {
    final firestoreInstance = firestore.FirebaseFirestore.instance; // Using the alias
    try {
      final querySnapshot = await firestoreInstance.collection('transactions').get();
      final List<Transaction> firebaseTransactions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Handle 'date' field explicitly
        final dynamic timestamp = data['date'];
        final DateTime parsedDate = (timestamp is firestore.Timestamp)
            ? timestamp.toDate() // Convert Firestore Timestamp to DateTime
            : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now(); // Handle String or fallback

        return Transaction(
          type: data['type'] ?? 'unknown', // Default type if missing
          amount: data['amount'] ?? 0,     // Default amount if missing
          date: parsedDate,                // Use the parsed DateTime
        );
      }).toList();

      setState(() {
        _transactions.addAll(firebaseTransactions); // Update state with fetched transactions
      });
    } catch (e) {
      logger.e("Error fetching transactions from Firebase: ${e.toString()}");
    }
  }


  Future<void> _loadBalanceFromFirebase() async {
    try {
      final doc = await firestore.FirebaseFirestore.instance
          .collection('balances')
          .doc('current_balance')
          .get();

      if (doc.exists) {
        final data = doc.data();
        logger.d("Balance fetched: ${data?['amount']}");
        setState(() {
          _balance.amount = data?['amount'] ?? 0;
        });
      } else {
        logger.w("No balance document found in Firestore.");
      }
    } catch (e) {
      logger.e("Error fetching balance from Firebase: $e");
    }
  }


  Future<void> _saveTransactionToFirebase(Transaction transaction) async {
    final firestoreInstance = firestore.FirebaseFirestore.instance; // Using the alias
    try {
      await firestoreInstance.collection('transactions').add({
        'type': transaction.type,
        'amount': transaction.amount,
        'date': transaction.date.toIso8601String(),
      });
    } catch (e) {
      logger.e("Error saving transaction to Firebase: \$e");
    }
  }

  Future<void> _saveBalanceToFirebase(double balance) async {
    final firestoreInstance = firestore.FirebaseFirestore.instance; // Using the alias
    try {
      await firestoreInstance.collection('balances').doc('current_balance').set({
        'amount': balance,
      });
    } catch (e) {
      logger.e("Error saving balance to Firebase: \$e");
    }
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
            decoration: const InputDecoration(hintText: 'Enter new balance amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newBalance = double.tryParse(_manualBalanceController.text);
                if (newBalance != null) {
                  logger.d("Updating balance to: $newBalance");
                  setState(() {
                    _balance.amount = newBalance;
                  });
                  await _saveBalanceToFirebase(newBalance);
                  _manualBalanceController.clear();
                  Navigator.pop(context);
                } else {
                  logger.w("Invalid balance entered: ${_manualBalanceController.text}");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid balance amount')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> listCollections() async {
    try {
      final collections = await firestore.FirebaseFirestore.instance.collectionGroup('balances').get();
      for (var doc in collections.docs) {
        // Log the document ID and data using the logger
        logger.d('Document ID: ${doc.id}');
        logger.d('Document Data: ${doc.data()}');
      }
    } catch (e) {
      // Log any errors using the logger
      logger.e('Error listing collections: $e');
    }
  }
  @override
  void dispose() {
    _smsService.dispose();
    _manualBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance: \$${_balance.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
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
    );
  }
}
