import 'package:flutter/material.dart';

import '../../core/test_id.dart';
import 'mit_license.dart';

/// "앱 정보": what this app is, who owns the original work, and the licenses.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('앱 정보')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TestId('about-app-name', child: Text(appDisplayName, style: theme.textTheme.titleLarge)),
          const SizedBox(height: 16),
          TestId(
            'about-notice',
            child: Text(
              '이 앱은 개인 학습과 포트폴리오를 위한 비공식 데모 앱입니다. '
              'Cypress.io와 제휴, 보증, 후원 관계가 없습니다. '
              '원저작권은 모두 Cypress.io 팀에게 있습니다.\n\n'
              '비상업적 목적으로만 사용하며, 앱 마켓에 배포하지 않습니다.',
            ),
          ),
          const SizedBox(height: 24),
          Text('원본 프로젝트', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          const TestId(
            'about-original-project',
            child: SelectableText('Cypress Real World App\n$originalProjectUrl'),
          ),
          const SizedBox(height: 24),
          Text('원본 라이선스', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TestId(
                'about-license-text',
                child: SelectableText(
                  originalProjectLicense,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TestId(
            'about-open-licenses-button',
            child: OutlinedButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: appDisplayName,
              ),
              child: const Text('오픈소스 라이선스 (사용한 패키지)'),
            ),
          ),
        ],
      ),
    );
  }
}
