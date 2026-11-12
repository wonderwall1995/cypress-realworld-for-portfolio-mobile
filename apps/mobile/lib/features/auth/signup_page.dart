import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/test_id.dart';
import '../about/original_project_link.dart';
import '../settings/phone_rule.dart';
import 'auth_widgets.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Keep these before the await: the page may be gone after it.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(apiClientProvider).signUp(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
            phoneNumber: _phone.text.trim(),
          );
      messenger.showSnackBar(
        const SnackBar(
          content: TestId('alert-bar-success', child: Text('회원가입이 완료되었습니다. 로그인해 주세요.')),
        ),
      );
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/signin');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = signUpErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TestId(
                      'signup-title',
                      child: Text(
                        '회원가입',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const OriginalProjectLink(id: 'signup-original-link'),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      FormErrorBanner(id: 'signup-error', message: _error!),
                      const SizedBox(height: 16),
                    ],
                    TestId(
                      'signup-last-name',
                      child: TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: '성',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => _required(v, '성을 입력하세요.'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TestId(
                      'signup-first-name',
                      child: TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => _required(v, '이름을 입력하세요.'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TestId(
                      'signup-username',
                      child: TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: '아이디',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        validator: (v) => _required(v, '아이디를 입력하세요.'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TestId(
                      'signup-phone-number',
                      child: TextFormField(
                        controller: _phone,
                        decoration: const InputDecoration(
                          labelText: '연락처',
                          hintText: '데모 앱입니다. 진짜 연락처는 넣지 마세요!',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) => validatePhoneNumber(v, noun: '연락처'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TestId(
                      'signup-password',
                      child: TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return '비밀번호를 입력하세요.';
                          if (v.length < 4) return '비밀번호는 4자 이상이어야 합니다.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TestId(
                      'signup-confirmPassword',
                      child: TextFormField(
                        controller: _confirm,
                        decoration: const InputDecoration(
                          labelText: '비밀번호 확인',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '비밀번호를 다시 입력하세요.';
                          if (v != _password.text) return '비밀번호가 일치하지 않습니다.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    TestId(
                      'signup-submit',
                      child: BusyFilledButton(
                        label: '회원가입',
                        busy: _busy,
                        onPressed: _submit,
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
