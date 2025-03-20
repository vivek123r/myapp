// lib/screens/settings.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/login_screen.dart';
import '../theme_notifier.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;
  File? _profileImage;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _deleteAccount() async {
    try {
      await _user?.delete();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Failed to delete account")),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_user != null)
                Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                    TextButton(
                      onPressed: _pickImage,
                      child: const Text('Choose Picture'),
                    ),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    ListTile(
                      title: Text('Email: ${_user!.email}'),
                    ),
                  ],
                ),
              SwitchListTile(
                title: const Text('light mode'),
                value: themeNotifier.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  themeNotifier.toggleTheme(value);
                },
              ),
              ElevatedButton(
                onPressed: _logout,
                child: const Text('Logout'),
              ),
              ElevatedButton(
                onPressed: _deleteAccount,
                child: const Text('Delete Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}