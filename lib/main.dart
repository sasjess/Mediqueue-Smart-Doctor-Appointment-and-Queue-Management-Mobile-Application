import 'package:flutter/material.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the database
  final db = await DatabaseHelper.instance.database;

  print('================================');
  print('MediQueue Database Created!');
  print('Database: ${db.path}');
  print('================================');

  runApp(const MediQueueApp());
}

class MediQueueApp extends StatelessWidget {
  const MediQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MediQueue'),
        ),
        body: const Center(
          child: Text(
            'Database Connected Successfully!',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}