import 'package:flutter/material.dart';

/// Temporary tab body. Each tab is built in its own app step.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title 화면')),
    );
  }
}
