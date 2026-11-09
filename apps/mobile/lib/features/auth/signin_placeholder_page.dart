import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';

/// Temporary screen. The real sign-in form comes in app step 2.
class SignInPlaceholderPage extends ConsumerWidget {
  const SignInPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final message = session.connectionError
        ? '서버에 연결할 수 없습니다.'
        : '서버에 연결되었습니다. 로그인이 필요합니다.';
    return Scaffold(
      body: Center(
        child: TestId(
          'signin-placeholder',
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('로그인', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.read(sessionProvider.notifier).restore(),
                  child: const Text('다시 확인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
