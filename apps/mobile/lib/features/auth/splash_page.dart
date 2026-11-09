import 'package:flutter/material.dart';

import '../../core/test_id.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: TestId('splash', child: Center(child: CircularProgressIndicator())),
    );
  }
}
