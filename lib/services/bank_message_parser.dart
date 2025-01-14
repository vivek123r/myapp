import '../models/transaction.dart';

class BankMessageParser {
  // List of bank names or identifiers to check against
  final List<String> bankIdentifiers = [
    'Union Bank of India', // Replace with your bank's name or identifier
    'VM-UNIONB', // Replace with your bank's short code (if applicable)
    // Add more bank identifiers as needed
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

  double? _extractAmount(String message) {
    // Regular expression to find a number (with optional decimal)
    final regex = RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)');
    final match = regex.firstMatch(message);

    if (match != null) {
      // Extract the matched string and remove commas
      final amountString = match.group(0)!.replaceAll(',', '');
      // Parse the string to a double
      return double.tryParse(amountString);
    }
    return null; // Return null if no amount is found
  }
}