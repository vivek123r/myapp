import 'package:flutter/material.dart';
import 'package:sms_advanced/sms_advanced.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const SmsApp());
}

class SmsApp extends StatelessWidget {
  const SmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      
title: 'Simple SMS App',
      home: const SmsScreen(),
    );
  }
}

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  SmsScreenState createState() => SmsScreenState();
}

class SmsScreenState extends State<SmsScreen> {
  final SmsReceiver _smsReceiver = SmsReceiver();
  String _receivedSms = 'No SMS received yet.';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndListen();
  }

  Future<void> _requestPermissionsAndListen() async {
    if (await Permission.sms.request().isGranted) {
      _startListeningForSms();
    } else {
      setState(() {
        _receivedSms = 'Permission denied. Please enable SMS permissions.';
      });
    }
  }

  void _startListeningForSms() {
    if (_isListening) return;

    _smsReceiver.onSmsReceived?.listen((SmsMessage message) {
      setState(() {
        _receivedSms = 'From: ${message.address}\nMessage: ${message.body}';
      });
    });

    setState(() {
      _isListening = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple SMS App'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _receivedSms,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
