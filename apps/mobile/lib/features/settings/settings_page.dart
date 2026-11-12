import '../../core/person_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/test_id.dart';
import '../auth/auth_widgets.dart';
import '../transactions/transaction_widgets.dart';
import 'phone_rule.dart';

/// The email check. (The web uses Yup's `email()`; this is the usual simple rule.)
final _emailPattern = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
);

/// Settings may leave the email empty (the server stores nothing then).
String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (!_emailPattern.hasMatch(text)) return '올바른 이메일 주소를 입력하세요.';
  return null;
}

/// The values the server knows, with the words the user sees.
const privacyChoices = [
  (value: 'public', label: '공개'),
  (value: 'private', label: '비공개'),
];

/// The reason shown after "설정 저장 실패: ".
String saveErrorReason(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  return '입력한 내용을 확인해 주세요.';
}

/// "설정": the user's own profile (same fields as the web) and the default
/// privacy of new transactions (not on the web screen).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late String _privacy;
  bool _busy = false;
  /// What happened at the last save: null until then, and again after an edit.
  ({bool success, String text})? _result;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _firstName = TextEditingController(text: user?['firstName'] as String? ?? '');
    _lastName = TextEditingController(text: user?['lastName'] as String? ?? '');
    _email = TextEditingController(text: user?['email'] as String? ?? '');
    _phone = TextEditingController(text: user?['phoneNumber'] as String? ?? '');
    // A user with no saved choice is "public" (the server does the same).
    final saved = user?['defaultPrivacyLevel'] as String?;
    _privacy = privacyChoices.any((c) => c.value == saved) ? saved! : 'public';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // A second tap in the same frame must not send a second request.
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(sessionProvider).user?['id'] as String?;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      await ref.read(apiClientProvider).updateUser(
            userId,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phone.text.trim(),
            defaultPrivacyLevel: _privacy,
          );
      // Load the user again: the name on the 내 계좌 tab and in the menu changes.
      await ref.read(sessionProvider.notifier).refreshUser();
      if (!mounted) return;
      setState(() => _result = (success: true, text: '설정 저장 성공'));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _result = (success: false, text: '설정 저장 실패: ${saveErrorReason(e)}'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final fullName = koreanFullName(
      firstName: user?['firstName'] as String?,
      lastName: user?['lastName'] as String?,
    );
    final username = user?['username'] as String?;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TestId(
                'user-settings-form',
                child: Form(
                  key: _formKey,
                  // Editing anything makes the old result disappear.
                  onChanged: () {
                    if (_result != null) setState(() => _result = null);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          InitialAvatar(fullName, radius: 24),
                          const SizedBox(width: 12),
                          TestId(
                            'user-settings-username',
                            child: Text(username == null ? '' : '@$username', style: theme.textTheme.titleMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TestId(
                        'user-settings-firstName-input',
                        child: TextFormField(
                          controller: _firstName,
                          decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요.' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TestId(
                        'user-settings-lastName-input',
                        child: TextFormField(
                          controller: _lastName,
                          decoration: const InputDecoration(labelText: '성', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty) ? '성을 입력하세요.' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TestId(
                        'user-settings-email-input',
                        child: TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          validator: validateEmail,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TestId(
                        'user-settings-phoneNumber-input',
                        child: TextFormField(
                          controller: _phone,
                          decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _save(),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? null : validatePhoneNumber(v),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('새 거래의 기본 공개 범위', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      TestId(
                        'user-settings-privacy',
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final choice in privacyChoices)
                              TestId(
                                'user-settings-privacy-${choice.value}',
                                child: ChoiceChip(
                                  label: Text(choice.label),
                                  selected: _privacy == choice.value,
                                  onSelected: (_) => setState(() => _privacy = choice.value),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // The place of the result stays, so the form does not jump.
                      SizedBox(
                        height: 20,
                        child: _result == null
                            ? null
                            : TestId(
                                'user-settings-result',
                                child: Text(
                                  _result!.text,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _result!.success ? Colors.green.shade700 : theme.colorScheme.error,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      TestId(
                        'user-settings-submit',
                        child: BusyFilledButton(label: '저장', busy: _busy, onPressed: _save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
