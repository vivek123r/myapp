import 'dart:async';
import 'package:another_telephony/telephony.dart';
import '../utils/logger_util.dart';
import 'bank_message_parser.dart';
import '../models/transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // Firebase import

class SmsService {
  final logger = LoggerUtil.logger;
  final BankMessageParser _bankMessageParser = BankMessageParser();
  final StreamController<Transaction> _newBankMessageController =
  StreamController<Transaction>.broadcast();
  final Telephony telephony = Telephony.instance;

  Stream<Transaction> get onNewBankMessage => _newBankMessageController.stream;

  SmsService() {
    _initSmsListener();
  }

  Future<void> _initSmsListener() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted == true) {
      try {
        // Listen for new messages
        telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            _processMessage(message);
          },
          onBackgroundMessage: _onBackgroundMessageHandler,
        );
      } catch (e) {
        logger.e('Error initializing SMS listener: $e');
      }
    } else {
      logger.w('SMS permission denied');
    }
  }

  void _processMessage(SmsMessage message) {
    if (_bankMessageParser.isBankMessage(message)) {
      final transaction = _bankMessageParser.parseBankMessage(message);
      if (transaction != null) {
        // Send the transaction to the stream
        _newBankMessageController.add(transaction);

        // Store the transaction in Firebase
        _storeTransactionInFirebase(transaction);
      }
    }
  }

  Future<void> _storeTransactionInFirebase(Transaction transaction) async {
    try {
      // Get a reference to your Firestore collection (e.g., 'transactions')
      final transactionsCollection = firestore.FirebaseFirestore.instance.collection('transactions');

      // Add the transaction data to Firebase Firestore
      await transactionsCollection.add({
        'string' : transaction.type,
        'amount': transaction.amount,
        'date': transaction.date,
        // Add any other fields from your transaction model
      });

      logger.i('Transaction successfully stored in Firebase');
    } catch (e) {
      logger.e('Error storing transaction in Firebase: $e');
    }
  }

  static void _onBackgroundMessageHandler(SmsMessage message) {
    // Optional: Handle background SMS messages
  }

  void dispose() {
    _newBankMessageController.close();
  }
}
