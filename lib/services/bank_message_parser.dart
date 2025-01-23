import '../models/transaction.dart';

class BankMessageParser {
  // List of bank names or identifiers to check against
  final List<String> bankIdentifiers = [
    // State Bank of India
    'SBI', 'SBIN', 'SBI-IND',
    // HDFC Bank
    'HDFC', 'HDFC-BK', 'HDFCBK',
    // ICICI Bank
    'ICICI', 'ICICIBANK',
    // Punjab National Bank
    'PNB', 'PNB-INDIA',
    // Axis Bank
    'AXIS', 'AXISBANK', 'AXISBANKIN',
    // Bank of Baroda
    'BOB', 'BOB-INDIA', 'BOB_BANK',
    // Kotak Mahindra Bank
    'KOTAK', 'KOTAKMAHINDRA',
    // Canara Bank
    'CANARA', 'CANARABANK',
    // Yes Bank
    'YESBANK', 'YES-BANK',
    // Union Bank of India
    'UNIONBANK', 'UNIONB',
    // IDFC First Bank
    'IDFC', 'IDFCFIRST', 'IDFCB',
    // Bank of India
    'BOI', 'BANKOFINDIA',
    // Indian Bank
    'INDIANBANK', 'INDIAN-BANK',
    // Federal Bank
    'FEDERALBANK', 'FED-BANK',
    // Syndicate Bank
    'SYNDICATEBANK',
    // Lakshmi Vilas Bank
    'LVB', 'LAKSHMIVILAS',
    // RBL Bank
    'RBLBANK', 'RBL',
    // IDBI Bank
    'IDBI', 'IDBIBANK',
    // Bandhan Bank
    'BANDHANBANK',
    // Karur Vysya Bank
    'KVB', 'KVBANK'
  ];

  bool isBankMessage(dynamic message) {
    // Check if the sender is in our list of bank identifiers
    if (message.address == null) {
      return false;
    }
    return bankIdentifiers.any((identifier) =>
        message.address!.toLowerCase().contains(identifier.toLowerCase()));
  }
  Transaction? parseBankMessage(dynamic message) {
    final body = message.body?.toLowerCase() ?? '';
    if (body.contains('credited')) {
      final amount = _extractAmount(body);
      if (amount != null) {
        return Transaction(
            type: 'Credit',
            amount: amount,
            date: message.date ?? DateTime.now());
      }
    } else if (body.contains('debited') || body.contains('spent')) {
      final amount = _extractAmount(body);
      if (amount != null) {
        return Transaction(
            type: 'Debit',
            amount: amount,
            date: message.date ?? DateTime.now());
      }
    }
    return null;
  }
  int? _extractAmount(String message) {
    // Regular expression to find a number (with optional decimal)
    final regex = RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)');
    final match = regex.firstMatch(message);
    if (match != null) {
      // Extract the matched string and remove commas
      final amountString = match.group(0)!.replaceAll(',', '');
      // Parse the string to a double
      return int.tryParse(amountString);
    }
    return null; // Return null if no amount is found
  }
}