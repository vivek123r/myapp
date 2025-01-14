import 'dart:async';
import 'package:another_telephony/telephony.dart';
import '../utils/logger_util.dart';
import 'bank_message_parser.dart';
import '../models/transaction.dart';

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
        // Fetch existing messages
        List<SmsMessage> messages = await telephony.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        );

        for (var message in messages) {
          _processMessage(message);
        }

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
        _newBankMessageController.add(transaction);
      }
    }
  }

  static void _onBackgroundMessageHandler(SmsMessage message) {
    // Optional: Handle background SMS messages
  }

  void dispose() {
    _newBankMessageController.close();
  }
}
