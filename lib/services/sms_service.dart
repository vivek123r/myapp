import 'dart:async';
import 'package:another_telephony/telephony.dart';
import '../utils/logger_util.dart';
import 'bank_message_parser.dart';
import '../models/transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class SmsService {
  final logger = LoggerUtil.logger;
  final BankMessageParser _bankMessageParser = BankMessageParser();
  final StreamController<Transaction> _newBankMessageController = StreamController<Transaction>.broadcast();
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
            logger.d('New message received: ${message.body}');
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
    logger.d('Processing incoming SMS: ${message.body}');
    if (_bankMessageParser.isBankMessage(message)) {
      final transaction = _bankMessageParser.parseBankMessage(message);
      if (transaction != null) {
        logger.d('Parsed transaction: $transaction');
        _newBankMessageController.add(transaction);
        _storeTransactionInFirebase(transaction);
      } else {
        logger.w('Failed to parse transaction from message: ${message.body}');
      }
    } else {
      logger.w('Message is not from a recognized bank: ${message.body}');
    }
  }

  Future<void> _storeTransactionInFirebase(Transaction transaction) async {
    try {
      final transactionsCollection = firestore.FirebaseFirestore.instance.collection('transactions');
      await transactionsCollection.add(transaction.toJson());
      logger.i('Transaction successfully stored in Firebase');
    } catch (e) {
      logger.e('Error storing transaction in Firebase: $e');
    }
  }

  static void _onBackgroundMessageHandler(SmsMessage message) {
    LoggerUtil.logger.d('Background message received: ${message.body}');
    final parser = BankMessageParser();
    if (parser.isBankMessage(message)) {
      final transaction = parser.parseBankMessage(message);
      if (transaction != null) {
        saveTransactionToDatabase(transaction);
      }
    }
  }

  static void saveTransactionToDatabase(Transaction transaction) {
    LoggerUtil.logger.d('Saving transaction to database: $transaction');
  }

  void dispose() {
    _newBankMessageController.close();
  }
}