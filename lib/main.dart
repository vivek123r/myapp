import 'package:flutter/material.dart';
import 'screens/balance_screen.dart';

void main() {
  runApp(const BankBalanceApp());
}

class BankBalanceApp extends StatelessWidget {
  const BankBalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MINT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BalanceScreen(),
    );
  }
}