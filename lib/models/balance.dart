import 'transaction.dart';

class Balance {
  double amount;

  Balance({required this.amount});

  void updateBalance(Transaction transaction) {
    if (transaction.type == 'Credit') {
      amount += transaction.amount;
    } else if (transaction.type == 'Debit') {
      amount -= transaction.amount;
    }
  }
}