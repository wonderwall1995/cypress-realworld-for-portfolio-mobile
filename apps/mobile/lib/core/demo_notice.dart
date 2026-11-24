import 'package:flutter/material.dart';

import 'test_id.dart';

/// For the people who try this app: nothing real belongs in it. Shown next to the
/// fields where a person would type something about themselves.
const signInDemoNotice = '체험용 데모 앱입니다. 실제 개인 정보나 평소 쓰시는 비밀번호는 넣지 마시고, 데모 계정으로만 로그인해 주세요.';
const signUpDemoNotice = '체험용 데모 앱입니다. 개인 정보를 넣지 마시고, 이름·ID·연락처·비밀번호 모두 지어낸 엉터리 정보만 넣어 주세요.';
const settingsDemoNotice = '체험용 데모 앱입니다. 실제 이름·이메일·전화번호를 넣지 마시고, 지어낸 엉터리 정보만 넣어 주세요.';

/// The bank account form (the words of the web).
const bankAccountDemoNotice = '진짜 자신의 계좌를 만들진 말아주세요! 이건 데모 앱입니다.';

/// Text that other people can read.
const memoDemoNotice = '메모는 다른 사람에게 보일 수 있습니다. 개인 정보는 넣지 마세요.';

/// A short notice above a form. It is not an error, so it is not red.
class DemoNotice extends StatelessWidget {
  const DemoNotice({required this.id, required this.text, super.key});

  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TestId(
      id,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: colors.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
