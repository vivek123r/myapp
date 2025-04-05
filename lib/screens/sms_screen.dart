import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import 'ExpenseTracker_screen.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  _SmsScreenState createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  // Static session cache
  static List<SmsMessage> _sessionMessages = [];
  static List<SmsMessage> _sessionAllMonthMessages = [];
  static bool _hasReadSmsThisSession = false;

  // Instance variables
  List<SmsMessage> messages = [];
  List<SmsMessage> allMonthMessages = [];
  final BankMessageParser parser = BankMessageParser();
  double balance = 0.0;
  bool showAllMessages = false;
  bool isLoading = true;
  bool isInitialized = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermission();
    });
  }

  void _requestPermission() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    if (status.isGranted) {
      _readAllSms();
    } else {
      print('SMS permission not granted');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialized = true;
          errorMessage = 'SMS permission not granted';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission not granted')),
        );
      }
    }
  }

  void _readAllSms() async {
    // Return if we've already read SMS this session
    if (_hasReadSmsThisSession && _sessionMessages.isNotEmpty) {
      if (mounted) {
        setState(() {
          messages = _sessionMessages;
          allMonthMessages = _sessionAllMonthMessages;
          isLoading = false;
          isInitialized = true;
        });
      }
      _updateBalance();
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      SmsQuery query = SmsQuery();
      List<SmsMessage> smsList = await query.querySms();
      DateTime now = DateTime.now();

      // Calculate date 4 months ago (including current month)
      DateTime firstDateOfLast4Months = DateTime(now.year, now.month - 3, 1);

      // Filter messages for the last 4 months
      List<SmsMessage> last4MonthsMessages = smsList.where((message) {
        if (message.date == null) return false;
        return message.date!.isAfter(firstDateOfLast4Months) ||
            message.date!.isAtSameMomentAs(firstDateOfLast4Months);
      }).toList();

      // Filter bank messages for the last 4 months
      List<SmsMessage> bankMessages = smsList.where((message) {
        final isBankMsg = parser.isBankMessage(message);
        if (message.date == null) return false;
        return isBankMsg &&
            (message.date!.isAfter(firstDateOfLast4Months) ||
                message.date!.isAtSameMomentAs(firstDateOfLast4Months));
      }).toList();

      // Update session cache
      _sessionMessages = bankMessages;
      _sessionAllMonthMessages = last4MonthsMessages;
      _hasReadSmsThisSession = true;

      if (mounted) {
        setState(() {
          messages = bankMessages;
          allMonthMessages = last4MonthsMessages;
          isLoading = false;
          isInitialized = true;
        });
      }

      _updateBalance();
    } catch (e) {
      print('Error reading SMS: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialized = true;
          errorMessage = 'Error reading SMS: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading SMS: $e')),
        );
      }
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
      }
    }

    if (mounted) {
      setState(() {
        balance = firstBalance ?? 0.0;
      });
    }
  }

  void _showMonthlySummary() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Calculate summary data from transactions
      double totalIncome = 0.0;
      double totalExpense = 0.0;

      final filteredTransactions = messages
          .where((message) => parser.parseBankMessage(message) != null)
          .map((message) => parser.parseBankMessage(message)!)
          .toList();

      for (var transaction in filteredTransactions) {
        if (transaction.type == 'Credit') {
          totalIncome += transaction.amount;
        } else {
          totalExpense += transaction.amount;
        }
      }

      // Get category data from Firestore for the current month
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final currentMonth = DateFormat('MMMM').format(now);
        final currentYear = now.year.toString();

        final docId = '${user.uid}-$currentMonth-$currentYear';
        final docRef = FirebaseFirestore.instance.collection('expenses').doc(docId);
        final docSnapshot = await docRef.get();

        // Category breakdown
        Map<String, double> categoryTotals = {};
        Map<String, List<Map<String, dynamic>>> categoryTransactions = {};

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final expenses = docSnapshot.data()!['expenses'] as List<dynamic>?;

          if (expenses != null) {
            for (var expense in expenses) {
              final category = expense['category'] as String;
              final amount = expense['amount'] as double;
              final date = DateTime.parse(expense['date'] as String);

              categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;

              if (!categoryTransactions.containsKey(category)) {
                categoryTransactions[category] = [];
              }
              categoryTransactions[category]!.add({
                'amount': amount,
                'date': date,
              });
            }
          }
        }

        setState(() {
          isLoading = false;
        });

        // Show the summary in a beautiful dialog
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: Column(
                children: [
                  Text(
                    '$currentMonth Summary',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Color(0xFFFF9500)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Income vs Expense summary
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.arrow_downward, color: Colors.green),
                              const SizedBox(height: 8),
                              const Text(
                                'credit',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${totalIncome.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 50,
                            width: 1,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          Column(
                            children: [
                              const Icon(Icons.arrow_upward, color: Colors.red),
                              const SizedBox(height: 8),
                              const Text(
                                'debit',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${totalExpense.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Category breakdown
                    if (categoryTotals.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Category Breakdown',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...categoryTotals.entries.map((entry) {
                        return ExpansionTile(
                          title: Text(
                            entry.key,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '₹${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFFF9500),
                            ),
                          ),
                          children: (categoryTransactions[entry.key] ?? [])
                              .map((transaction) => ListTile(
                            title: Text(
                              '₹${transaction['amount'].toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              DateFormat('dd MMM yyyy').format(transaction['date']),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ))
                              .toList(),
                        );
                      }).toList(),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252525),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No categorized expenses found for this month.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading summary: $e')),
      );
    }
  }

  void _setBalanceManually() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController(
            text: balance.toStringAsFixed(2));
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Set Balance', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new balance',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFF9500)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final newBalance = double.tryParse(controller.text);
                if (newBalance != null) {
                  setState(() {
                    balance = newBalance;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number')),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Set', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryDialog(Transaction transaction) {
    String selectedCategory = 'Food';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Select Expense Category',
            style: TextStyle(color: Colors.white),
          ),
          content: DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF2A2A2A),
            value: selectedCategory,
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFF9500)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            items: [
              'Food',
              'Travel',
              'Entertainment',
              'Other',
              'Shopping',
              'Rent',
              'Bill',
              'Grocery',
              'Fuel'
            ]
                .map((category) => DropdownMenuItem(
              value: category,
              child: Text(category),
            ))
                .toList(),
            onChanged: (value) {
              selectedCategory = value!;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                _addTransactionToExpenseTracker(transaction, selectedCategory);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _addTransactionToExpenseTracker(
      Transaction transaction, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final monthName = DateFormat('MMMM').format(transaction.date);
    final yearString = transaction.date.year.toString();

    String docId = '${user.uid}-$monthName-$yearString';
    DocumentReference docRef =
    FirebaseFirestore.instance.collection('expenses').doc(docId);

    try {
      DocumentSnapshot doc = await docRef.get();

      List<dynamic> existingExpenses = [];
      if (doc.exists &&
          doc.data() != null &&
          (doc.data() as Map).containsKey('expenses')) {
        existingExpenses = List.from((doc.data() as Map)['expenses']);
      }

      existingExpenses.add({
        'category': category,
        'amount': transaction.amount,
        'date': transaction.date.toString(),
        'month': monthName,
        'year': yearString,
        'description': 'From SMS: ${transaction.type}',
      });

      await docRef.set({'expenses': existingExpenses}, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction added to $monthName!'),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add transaction: $e'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Finance Tracker',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _readAllSms,
            tooltip: 'Refresh SMS',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : (!isInitialized
          ? _buildErrorScreen()
          : _buildNewTransactionsView()),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9500).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: const Color(0xFFFF9500),
                    strokeWidth: 4,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Analyzing SMS Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we process your financial data',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF9500),
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTransactionsView() {
    final filteredTransactions = messages
        .where((message) => parser.parseBankMessage(message) != null)
        .map((message) => parser.parseBankMessage(message)!)
        .toList();

    // Group transactions by date
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in filteredTransactions) {
      final dateString = DateFormat('dd MMM yyyy').format(transaction.date);
      if (!groupedTransactions.containsKey(dateString)) {
        groupedTransactions[dateString] = [];
      }
      groupedTransactions[dateString]!.add(transaction);
    }

    // Quick actions for your app
    final List<Map<String, dynamic>> quickActions = [
      {
        'title': 'Set Balance',
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFFFF9500),
        'onTap': _setBalanceManually,
      },
      {
        'title': 'Track Expense',
        'icon': Icons.add_chart,
        'color': const Color(0xFFFF9500),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ExpenseTrackerScreen(),
            ),
          );
        },
      },
      {
        'title': 'View Summary',
        'icon': Icons.pie_chart,
        'color': const Color(0xFFFF9500),
        'onTap': _showMonthlySummary,
      },
      {
        'title': 'All Messages',
        'icon': Icons.message,
        'color': const Color(0xFFFF9500),
        'onTap': _toggleAllMessagesView,
      },
    ];

    return Column(
      children: [
        // Balance card at the top
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9500).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MMMM').format(DateTime.now()),
                      style: const TextStyle(
                        color: Color(0xFFFF9500),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹ ${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        color: Colors.green,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Income',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Expenses',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Quick action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: quickActions.length,
                  itemBuilder: (context, index) {
                    final action = quickActions[index];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: action['color'].withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: action['onTap'],
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: action['color'].withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                action['icon'],
                                color: action['color'],
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              action['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Recent transactions list
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                showAllMessages ? 'All Messages' : 'Recent Transactions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '(${showAllMessages ? allMonthMessages.length : filteredTransactions.length} items)',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),

        Expanded(
          child: showAllMessages
              ? _buildAllMessagesView()
              : _buildTransactionsView(groupedTransactions, filteredTransactions),
        ),
      ],
    );
  }

  Widget _buildTransactionsView(
      Map<String, List<Transaction>> groupedTransactions,
      List<Transaction> filteredTransactions) {
    return filteredTransactions.isEmpty
        ? const Center(
      child: Text(
        'No transactions found for this month.',
        style: TextStyle(color: Colors.grey),
      ),
    )
        : ListView.builder(
      itemCount: groupedTransactions.keys.length,
      itemBuilder: (context, index) {
        final dateString = groupedTransactions.keys.elementAt(index);
        final dayTransactions = groupedTransactions[dateString]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8
              ),
              child: Text(
                dateString,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...dayTransactions.map((transaction) {
              final formattedAmount = transaction.type == 'Credit'
                  ? '+${transaction.amount.toStringAsFixed(2)}'
                  : '-${transaction.amount.toStringAsFixed(2)}';

              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: transaction.type == 'Credit'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      transaction.type == 'Credit'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: transaction.type == 'Credit'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  title: Text(
                    formattedAmount,
                    style: TextStyle(
                      color: transaction.type == 'Credit'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Balance: ₹${transaction.balance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: transaction.type == 'Debit'
                      ? ElevatedButton(
                    onPressed: () {
                      _showCategoryDialog(transaction);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(color: Colors.black),
                    ),
                  )
                      : null,
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildAllMessagesView() {
    return allMonthMessages.isEmpty
        ? const Center(
      child: Text(
        'No messages found for this month.',
        style: TextStyle(color: Colors.grey),
      ),
    )
        : ListView.builder(
      itemCount: allMonthMessages.length,
      itemBuilder: (context, index) {
        final message = allMonthMessages[index];
        final isBankMessage = parser.isBankMessage(message);
        final transaction = parser.parseBankMessage(message);

        return Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isBankMessage
                    ? const Color(0xFFFF9500).withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBankMessage ? Icons.account_balance : Icons.message,
                color: isBankMessage
                    ? const Color(0xFFFF9500)
                    : Colors.grey,
              ),
            ),
            title: Text(
              message.address ?? 'Unknown',
              style: TextStyle(
                color: isBankMessage ? Colors.white : Colors.grey,
                fontWeight: isBankMessage ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              message.body ?? '',
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: transaction != null && transaction.type == 'Debit'
                ? IconButton(
              icon: const Icon(Icons.add, color: Color(0xFFFF9500)),
              onPressed: () {
                _showCategoryDialog(transaction);
              },
            )
                : null,
          ),
        );
      },
    );
  }

  void _toggleAllMessagesView() {
    setState(() {
      showAllMessages = !showAllMessages;
    });
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

    // Try alternative balance patterns
    final altRegex = RegExp(r'\b(?:bal|balance)[:\s]?(?:rs|inr)[:\s]?(\d+(\.\d{1,2})?)', caseSensitive: false);
    final altMatch = altRegex.firstMatch(message);
    if (altMatch != null) {
      return double.tryParse(altMatch.group(1)!);
    }

    return null;
  }
}

class Transaction {
  final String type;
  final double amount;
  final double balance;
  final DateTime date;

  Transaction({
    required this.type,
    required this.amount,
    required this.balance,
    required this.date,
  });
}