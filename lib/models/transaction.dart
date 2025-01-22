import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class Transaction {
  final String type;
  final num amount;
  final DateTime date;
  static final logger = Logger();

  Transaction({
    required this.type,
    required this.amount,
    required this.date,
  });

  // Convert a Transaction into a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  // Convert a Map into a Transaction (Firestore data to class object)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    try {
      // Safely extract and parse the 'date' field
      final dynamic timestamp = json['date'];
      final DateTime parsedDate = (timestamp is Timestamp)
          ? timestamp.toDate() // Convert Firestore Timestamp to DateTime
          : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now(); // Handle String or fallback

      return Transaction(
        type: json['type'] ?? 'unknown',  // Default to 'unknown' if 'type' is missing
        amount: json['amount'] ?? 0,      // Default to 0 if 'amount' is missing
        date: parsedDate,                 // Use the parsed date
      );
    } catch (e) {
      logger.e("Error parsing transaction: $e"); // Log any errors
      return Transaction(
        type: 'unknown',
        amount: 0,
        date: DateTime.now(),
      ); // Fallback to default values
    }
  }


  // Method to save the transaction to Firestore
  Future<void> saveToFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('transactions').add(toJson());
      logger.i("Transaction saved successfully.");
    } catch (e) {
      logger.e("Error saving transaction: $e");
    }
  }

  // Method to fetch transactions from Firestore
  static Future<List<Transaction>> fetchFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore.collection('transactions').get();
      return querySnapshot.docs.map((doc) {
        try {
          return Transaction.fromJson(doc.data());
        } catch (e) {
          logger.e("Error processing transaction document: $e");
          return Transaction(type: 'unknown', amount: 0, date: DateTime.now());
        }
      }).toList();
    } catch (e) {
      logger.e("Error fetching transactions: ${e.toString()}");
      return [];
    }
  }
}
