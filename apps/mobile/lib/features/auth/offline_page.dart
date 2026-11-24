import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';

/// The app could not ask the server who is signed in. The saved sign-in is kept;
/// the button asks again.
class OfflinePage extends ConsumerWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TestId(
              'offline',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('서버에 연결할 수 없습니다.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TestId(
                    'offline-retry',
                    child: FilledButton(
                      onPressed: () => ref.read(sessionProvider.notifier).restore(),
                      child: const Text('연결 다시 확인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
