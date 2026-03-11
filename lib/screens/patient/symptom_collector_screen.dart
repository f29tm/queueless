import 'package:flutter/material.dart';

class SymptomCollectorScreen extends StatelessWidget {
  const SymptomCollectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Collector')),
      body: const Center(child: Text('Symptom collector logic here.')),
    );
  }
}
