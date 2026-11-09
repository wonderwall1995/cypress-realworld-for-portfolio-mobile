import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/test_id.dart';
import 'auth_widgets.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The sign-in page stays under the sign-up page. Clear the old error before
  /// leaving and the old password when coming back.
  Future<void> _openSignUp() async {
    setState(() => _error = null);
    await context.push('/signup');
    if (!mounted) return;
    _password.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(
            username: _username.text.trim(),
            password: _password.text,
            remember: _remember,
          );
      // The router moves to the home screen when the session changes.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = signInErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show the start-up connection error until the user tries to sign in.
    final connectionError = ref.watch(sessionProvider).connectionError;
    final error = _error ?? (connectionError ? '서버에 연결할 수 없습니다.' : null);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '로그인',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    if (error != null) ...[
                      FormErrorBanner(id: 'signin-error', message: error),
                      const SizedBox(height: 16),
                    ],
                    TestId(
                      'signin-username',
                      child: TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: '아이디',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '아이디를 입력하세요.' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TestId(
                      'signin-password',
                      child: TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '비밀번호를 입력하세요.';
                          if (v.length < 4) return '비밀번호는 4자 이상이어야 합니다.';
                          return null;
                        },
                      ),
                    ),
                    TestId(
                      'signin-remember-me',
                      child: CheckboxListTile(
                        value: _remember,
                        onChanged: (v) => setState(() => _remember = v ?? false),
                        title: const Text('로그인 상태 유지'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TestId(
                      'signin-submit',
                      child: BusyFilledButton(
                        label: '로그인',
                        busy: _busy,
                        onPressed: _submit,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TestId(
                      'signup',
                      child: TextButton(
                        onPressed: _openSignUp,
                        child: const Text('계정이 없나요? 회원가입'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
