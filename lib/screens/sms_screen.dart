import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  _SmsScreenState createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  List<SmsMessage> messages = [];
  List<SmsMessage> allMonthMessages = []; // To store all messages from current month
  final BankMessageParser parser = BankMessageParser();
  double balance = 0.0;
  bool showAllMessages = false; // Toggle for showing all messages view
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  void _requestPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    if (status.isGranted) {
      _readAllSms();
    } else {
      print('SMS permission not granted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission not granted')),
      );
    }
  }

  // Method to read ALL SMS messages without filtering
  void _readAllSms() async {
    setState(() {
      isLoading = true;
    });

    try {
      SmsQuery query = SmsQuery();
      List<SmsMessage> smsList = await query.querySms();
      DateTime now = DateTime.now();

      // Get the first date of the current and previous month
      DateTime firstDateOfCurrentMonth = DateTime(now.year, now.month, 1);
      DateTime firstDateOfPreviousMonth = DateTime(now.year, now.month - 1, 1);

      print('Total SMS messages: ${smsList.length}');

      // First, store ALL messages from current month without any filtering
      List<SmsMessage> currentMonthMessages = smsList.where((message) {
        if (message.date == null) return false;

        final messageDate = message.date!;
        final inCurrentMonth = messageDate.isAfter(firstDateOfCurrentMonth) ||
            messageDate.isAtSameMomentAs(firstDateOfCurrentMonth);

        return inCurrentMonth;
      }).toList();

      print('Current month messages: ${currentMonthMessages.length}');

      // Then, filter for bank messages separately
      List<SmsMessage> bankMessages = smsList.where((message) {
        final isBankMsg = parser.isBankMessage(message);
        if (message.date == null) return false;

        final messageDate = message.date!;
        final inCurrentMonth = messageDate.isAfter(firstDateOfCurrentMonth) ||
            messageDate.isAtSameMomentAs(firstDateOfCurrentMonth);
        final inPreviousMonth = messageDate.isAfter(firstDateOfPreviousMonth) &&
            messageDate.isBefore(firstDateOfCurrentMonth);

        return isBankMsg && (inCurrentMonth || inPreviousMonth);
      }).toList();

      print('Bank messages: ${bankMessages.length}');

      setState(() {
        // Store all current month messages
        allMonthMessages = currentMonthMessages;

        // Sort all messages by date (newest first)
        allMonthMessages.sort((a, b) =>
            (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()));

        // Store bank messages for transaction list
        messages = bankMessages;

        isLoading = false;
      });

      _updateBalance();
    } catch (e) {
      print('Error reading SMS: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading SMS: $e')),
      );
    }
  }

  void _updateBalance() {
    double? firstBalance;
    bool isFirstTransaction = true;

    for (final message in messages) {
      final transaction = parser.parseBankMessage(message);

      if (transaction != null && isFirstTransaction) {
        firstBalance = transaction.balance;
        isFirstTransaction = false;
        print("First Extracted Balance: $firstBalance");
      }
    }

    setState(() {
      balance = firstBalance ?? 0.0;
    });
  }

  void _setBalanceManually() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: Text('Set Balance'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Enter new balance'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  balance = double.tryParse(controller.text) ?? balance;
                });
                Navigator.of(context).pop();
              },
              child: Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryDialog(Transaction transaction) {
    String selectedCategory = 'Food'; // Default category
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Expense Category'),
          content: DropdownButtonFormField<String>(
            value: selectedCategory,
            items: ['Food', 'Travel', 'Entertainment', 'Other', 'Shopping', 'Rent', 'Bill', 'Grocery', 'Fuel']
                .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                .toList(),
            onChanged: (value) {
              selectedCategory = value!;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addTransactionToExpenseTracker(transaction, selectedCategory);
                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addTransactionToExpenseTracker(Transaction transaction, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Convert numeric month to full month name
    List<String> months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];

    String monthName = months[transaction.date.month - 1]; // Get month from SMS transaction
    String yearString = transaction.date.year.toString(); // Ensure year is a string

    String docId = '${user.uid}-$monthName-$yearString';
    DocumentReference docRef = FirebaseFirestore.instance.collection('expenses').doc(docId);

    try {
      DocumentSnapshot doc = await docRef.get();

      List<dynamic> existingExpenses = [];
      if (doc.exists && doc.data() != null && (doc.data() as Map).containsKey('expenses')) {
        existingExpenses = List.from((doc.data() as Map)['expenses']);
      }

      existingExpenses.add({
        'category': category,
        'amount': transaction.amount,
        'date': transaction.date.toString(),
        'month': monthName,
        'year': yearString,
      });

      await docRef.set({'expenses': existingExpenses}, SetOptions(merge: true));

      print("✅ Transaction added successfully to $docId!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction added to $docId!')),
      );
    } catch (e) {
      print("❌ Firestore Write Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add transaction: $e')),
      );
    }
  }

  // Show all current month messages
  void _toggleAllMessagesView() {
    setState(() {
      showAllMessages = !showAllMessages;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(showAllMessages ? 'All SMS Messages' : 'SMS Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _readAllSms,
            tooltip: 'Refresh SMS',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : showAllMessages
          ? _buildAllMessagesView()
          : _buildTransactionsView(),
    );
  }

  Widget _buildTransactionsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Current Balance: Rs:${balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: _setBalanceManually,
          child: const Text('Set Balance Manually'),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '(${messages.where((message) => parser.parseBankMessage(message) != null).length} items)',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(
            child: Text('No transactions found for this month.'),
          )
              : ListView.builder(
            itemCount: messages.where((message) => parser.parseBankMessage(message) != null).length,
            itemBuilder: (context, index) {
              final filteredMessages = messages.where((message) => parser.parseBankMessage(message) != null).toList();
              if (index >= filteredMessages.length) {
                return const SizedBox.shrink();
              }

              final message = filteredMessages[index];
              final transaction = parser.parseBankMessage(message)!;

              final formattedAmount = transaction.type == 'Credit'
                  ? '+${transaction.amount.toStringAsFixed(2)}'
                  : '-${transaction.amount.toStringAsFixed(2)}';

              return ListTile(
                title: Text(
                  formattedAmount,
                  style: TextStyle(
                    color: transaction.type == 'Credit' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${transaction.type} on ${transaction.date.toString()}'),
                    Text('Balance: ${transaction.balance.toStringAsFixed(2)}'),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    _showCategoryDialog(transaction);
                  },
                  child: Text('Add'),
                ),
              );
            },
          ),
        ),
        // Button to show all month messages
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _toggleAllMessagesView,
            icon: const Icon(Icons.message),
            label: Text('View All SMS Messages (${allMonthMessages.length})'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllMessagesView() {
    String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'All Messages for $currentMonth',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '(${allMonthMessages.length})',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _toggleAllMessagesView,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Transactions'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: allMonthMessages.isEmpty
              ? const Center(child: Text('No messages found for this month'))
              : ListView.builder(
            itemCount: allMonthMessages.length,
            itemBuilder: (context, index) {
              final message = allMonthMessages[index];
              final formattedDate = message.date != null
                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(message.date!)
                  : 'Unknown date';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message.address ?? 'Unknown Sender',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          parser.isBankMessage(message)
                              ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Bank', style: TextStyle(fontSize: 12)),
                          )
                              : const SizedBox.shrink(),
                        ],
                      ),
                      const Divider(),
                      Text(message.body ?? 'No message content'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BankMessageParser {
  final List<String> bankIdentifiers = [
    'SBI','UNION BANK OF INDIA', 'SBIN', 'SBI-IND',
    'UNION BANK', 'UNIONBANK', 'UNIONBK', 'UBI',
    'HDFC', 'HDFC-BK', 'HDFCBK',
    'ICICI', 'ICICIBANK',
    'PNB', 'PNB-INDIA',
    'AXIS', 'AXISBANK', 'AXISBANKIN',
    'BOB', 'BOB-INDIA', 'BOB_BANK',
    'KOTAK', 'KOTAKMAHINDRA',
    'CANARA', 'CANARABANK',
    'YESBANK', 'YES-BANK',
    'UNIONBANK', 'UNIONB',
    'IDFC', 'IDFCFIRST', 'IDFCB',
    'BOI', 'BANKOFINDIA',
    'INDIANBANK', 'INDIAN-BANK',
    'FEDERALBANK', 'FED-BANK',
    'SYNDICATEBANK',
    'LVB', 'LAKSHMIVILAS',
    'RBLBANK', 'RBL',
    'IDBI', 'IDBIBANK',
    'BANDHANBANK',
    'KVB', 'KVBANK'
  ];

  bool isBankMessage(SmsMessage message) {
    if (message.address == null) {
      return false;
    }

    String address = message.address!.toLowerCase();
    return bankIdentifiers.any((identifier) => address.contains(identifier.toLowerCase()));
  }

  Transaction? parseBankMessage(dynamic message) {
    final body = message.body?.toLowerCase() ?? '';

    if (body.contains('credited') || body.contains('debited') || body.contains('spent')) {
      final amount = _extractAmount(body);
      final balance = _extractBalance(body);

      if (amount != null && balance != null) {
        final type = body.contains('credited') ? 'Credit' : 'Debit';
        return Transaction(
            type: type,
            amount: amount,
            balance: balance,
            date: message.date ?? DateTime.now());
      }
    }
    return null;
  }

  double? _extractAmount(String message) {
    final regex = RegExp(r'(?:rs[:\s]?|inr[:\s]?)(\d+(\.\d{1,2})?)', caseSensitive: false);
    final match = regex.firstMatch(message);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  double? _extractBalance(String message) {
    final regex = RegExp(r'\bavl bal rs[:\s]?(\d+(\.\d{1,2})?)', caseSensitive: false);
    final match = regex.firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}

class Transaction {
  final String type;
  final double amount;
  final double balance;
  final DateTime date;

  Transaction({required this.type, required this.amount, required this.balance, required this.date});
}