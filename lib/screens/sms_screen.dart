import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  _SmsScreenState createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  List<SmsMessage> messages = [];
  final BankMessageParser parser = BankMessageParser();
  double balance = 0.0;

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
      _readSms();
    } else {
      print('SMS permission not granted');
    }
  }

  void _readSms() async {
    SmsQuery query = SmsQuery();
    List<SmsMessage> smsList = await query.querySms();
    DateTime now = DateTime.now();

    // Get the first date of the current and previous month
    DateTime firstDateOfCurrentMonth = DateTime(now.year, now.month, 1);
    DateTime firstDateOfPreviousMonth = DateTime(now.year, now.month - 1, 1);

    setState(() {
      messages = smsList.where((message) {
        final isBankMsg = parser.isBankMessage(message);
        if (message.date == null) return false;

        final messageDate = message.date!;
        final inCurrentMonth = messageDate.isAfter(firstDateOfCurrentMonth) || messageDate.isAtSameMomentAs(firstDateOfCurrentMonth);
        final inPreviousMonth = messageDate.isAfter(firstDateOfPreviousMonth) && messageDate.isBefore(firstDateOfCurrentMonth);

        return isBankMsg && (inCurrentMonth || inPreviousMonth);
      }).toList();
      _updateBalance();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Reader'),
      ),
      body: Column(
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Transaction History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: messages.isNotEmpty
                  ? messages.where((message) => parser.parseBankMessage(message) != null).length
                  : 1,
              itemBuilder: (context, index) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No transactions found for this month.'),
                  );
                }

                final message = messages.where((message) => parser.parseBankMessage(message) != null).toList()[index];
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
                );
              },
            ),
          ),
        ],
      ),
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
    return bankIdentifiers.any((identifier) =>
        message.address!.toLowerCase().contains(identifier.toLowerCase()));
  }


  Transaction? parseBankMessage(dynamic message) {
    final body = message.body?.toLowerCase() ?? '';
    print('Message Body: $body');

    if (body.contains('credited') || body.contains('debited') || body.contains('spent')) {
      final amount = _extractAmount(body);
      final balance = _extractBalance(body);

      print('Extracted Amount: $amount');
      print('Extracted Balance: $balance');

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