import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart'; // Import the logger package

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
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  final List<SmsMessage> _messages = [];
  final SmsQuery _query = SmsQuery();
  final logger = Logger(); // Create a logger instance

  Future<void> _readSMS() async {
    // Request permission
    if (await Permission.sms.request().isGranted) {
      try {
        List<SmsMessage> messages = await _query.getAllSms;
        setState(() {
          _messages.addAll(messages
);
        });
        //Log the message
        for (var msg in messages) {
          logger.d('SMS: ${msg.body}');
        }
      } catch (e) {
        //Log the error
        logger.e('Error reading SMS: $e');
      }
    } else {
      logger.w('SMS permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple SMS App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _readSMS,
              child: const Text('Read SMS Messages'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ListTile(
                    title: Text('Message ${index + 1}'),
                    subtitle: Text(message.body ?? 'No message body'),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
