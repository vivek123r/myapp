class Transaction {
  final String type;
  final double amount;
  final DateTime date;

  Transaction({required this.type, required this.amount, required this.date});

  // Convert a Transaction into a Map
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  // Convert a Map into a Transaction
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      type: json['type'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
    );
  }
}
