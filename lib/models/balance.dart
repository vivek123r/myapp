import 'transaction.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
class Balance {
  double amount;
  static final logger = Logger();
  Balance({required this.amount});

  // Update the balance based on the transaction type
  void updateBalance(Transaction transaction) {
    if (transaction.type == 'Credit') {
      amount += transaction.amount;
    } else if (transaction.type == 'Debit') {
      amount -= transaction.amount;
    }
  }

  // Save the balance to Firestore
  Future<void> saveToFirestore(double amount) async {
    try {
      final firestoreInstance = firestore.FirebaseFirestore.instance;
      await firestoreInstance.collection('balances').doc('current_balance').set({
        'amount': amount,
      });
      logger.d("Balance saved successfully: \$${amount.toStringAsFixed(2)}");
    } catch (e) {
      logger.e("Error saving balance: $e");
    }
  }


  // Fetch the current balance from Firestore
  static Future<Balance> fetchFromFirestore() async {
    try {
      final firestoreInstance = firestore.FirebaseFirestore.instance;
      final doc = await firestoreInstance.collection('balances').doc('current_balance').get();
      if (doc.exists) {
        return Balance(amount: doc.data()?['amount'] ?? 0.0);
      } else {
        return Balance(amount: 0.0);
      }
    } catch (e) {
      logger.e("Error fetching balance: $e");
      return Balance(amount: 0.0);
    }
  }
}