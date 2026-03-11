import 'package:flutter/material.dart';

class VisitorHomeScreen extends StatelessWidget {
  const VisitorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Home')),
      body: const Center(child: Text('Visitor functionalities go here.')),
    );
  }
}
