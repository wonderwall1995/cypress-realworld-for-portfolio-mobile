part of 'simulation_scenarios.dart';

extension _AuthCases on SimulationScenarios {
  Future<void> _signupForm(_Person p) async {
    await ui.enter('signup-last-name', p.lastName);
    await ui.enter('signup-first-name', p.firstName);
    await ui.enter('signup-username', p.username);
    await ui.enter('signup-phone-number', p.phone);
    await ui.enter('signup-password', p.password);
    await ui.enter('signup-confirmPassword', p.password);
    await ui.tap('signup-submit');
  }

  Future<void> auth() async {
    final a = _person('A');
    await run.step('000 · 화면에서 회원가입', () async {
      await ui.tap('signup');
      await _signupForm(a);
      await ui.gone('signup-title');
      a.user = await _call(
        () => a.api.login(
          username: a.username,
          password: a.password,
          remember: false,
        ),
      );
      final me = await _call(a.api.checkAuth);
      for (final entry in {...a.profile, 'username': a.username}.entries) {
        if (entry.key != 'email') _check(me?[entry.key] == entry.value);
      }
    });
    await run.step('000 · 같은 ID의 중복 가입 거절', () async {
      await ui.tap('signup');
      await _signupForm(a);
      await ui.expectText('signup-error', '이미 사용 중인 사용자 ID');
      await _status(
        a,
        'POST',
        '/users',
        409,
        data: {...a.profile, 'username': a.username, 'password': a.password},
      );
      await _go('/signin');
    });
    await run.step('000 · 가입한 계정으로 로그인하고 이름 확인', () async {
      await _signIn(a);
      await ui.tap('sidenav-my-account');
      await ui.expectText('my-account-username', '@${a.username}');
      await ui.expectText('my-account-full-name', a.name);
    });
  }

  Future<void> settings() async {
    late _Person a;
    late _Person b;
    await run.step('006 · 두 사용자와 잔액 준비', () async {
      a = await _prepare('A', dollars: 100);
      b = await _prepare('B', dollars: 100);
      await _signIn(a);
      await ui.tap('sidenav-my-account');
      await ui.expectText('my-account-full-name', a.name);
      await ui.expectText('my-account-username', '@${a.username}');
    });
    Future<void> openSettings() async {
      await ui.tap('sidenav-more');
      await ui.tap('sidenav-user-settings');
      await ui.waitFor('user-settings-form');
    }

    await openSettings();
    for (final entry in [
      ('firstName', '', '이름을 입력하세요.'),
      ('email', 'not-an-email', '올바른 이메일 주소를 입력하세요.'),
      ('phoneNumber', 'abc', '전화번호가 올바르지 않습니다.'),
    ]) {
      await run.step('006 · 잘못된 ${entry.$1} 저장 거절', () async {
        await ui.enter('user-settings-${entry.$1}-input', entry.$2);
        await ui.tap('user-settings-submit');
        await ui.expectText('user-settings-form', entry.$3);
        await ui.gone('user-settings-message');
        await _status(
          a,
          'PATCH',
          '/users/${a.id}',
          422,
          data: {...a.profile, entry.$1: entry.$2},
        );
        final me = await _call(a.api.checkAuth);
        for (final field in a.profile.entries) {
          _check((me?[field.key] ?? '') == field.value);
        }
        await ui.enter(
          'user-settings-${entry.$1}-input',
          a.profile[entry.$1] as String,
        );
      });
    }
    final changed = SimulationFixtures.profile();
    Future<void> save(Map<String, dynamic> profile) async {
      for (final entry in profile.entries) {
        await ui.enter(
          'user-settings-${entry.key}-input',
          entry.value as String,
        );
      }
      await ui.tap('user-settings-submit');
      await ui.expectText('user-settings-message', '설정 저장 성공');
      final me = await _call(a.api.checkAuth);
      for (final entry in profile.entries) {
        _check((me?[entry.key] ?? '') == entry.value);
      }
    }

    await run.step('006 · 프로필 변경과 다시 읽기', () async {
      await save(changed);
      await _go('/my-account');
      await ui.tap('sidenav-my-account');
      await ui.expectText(
        'my-account-full-name',
        '${changed['lastName']} ${changed['firstName']}',
      );
      await openSettings();
      for (final entry in changed.entries) {
        await ui.typed('user-settings-${entry.key}-input', entry.value);
      }
    });
    await run.step('006 · 원래 정보 복원과 다른 사용자 확인', () async {
      await save(a.profile);
      await _go('/my-account');
      await _balance(a, 10000);
      await ui.expectText('my-account-full-name', a.name);
      final other = await _call(b.api.checkAuth);
      for (final entry in b.profile.entries) {
        _check((other?[entry.key] ?? '') == entry.value);
      }
    });
  }

  Future<void> loginLogout() async {
    late _Person a;
    late _Person b;
    await run.step('009 · 서로 다른 계정과 잔액 준비', () async {
      a = await _prepare('A', dollars: 1000, passwordPrefix: 'Aa');
      b = await _prepare('B', dollars: 500, passwordPrefix: 'Bb');
    });
    await run.step('009 · 4자 미만 비밀번호 입력 거절', () async {
      await _signIn(a, password: '123', success: false);
      await ui.expectText('signin-password', '비밀번호는 4자 이상');
    });
    for (final wrong in ['wrong-password', a.password.toLowerCase()]) {
      await run.step('009 · 틀린 비밀번호와 대소문자 구분', () async {
        await _signIn(a, password: wrong, success: false);
        await ui.expectText('signin-error', '사용자 ID 또는 비밀번호가 올바르지 않습니다.');
        await _status(
          a,
          'POST',
          '/login',
          401,
          data: {'username': a.username, 'password': wrong},
        );
      });
    }
    await run.step('009 · A 로그인과 로그아웃', () async {
      await _signIn(a);
      await _balance(a, 100000);
      await ui.expectText('my-account-username', '@${a.username}');
      await _banks();
      await ui.show('bankaccount-list-item-${a.accountId}');
      await _signOut();
    });
    await run.step('009 · B 로그인 시 A의 정보가 남지 않음', () async {
      await _signIn(b);
      await _balance(b, 50000);
      await ui.expectText('my-account-username', '@${b.username}');
      await _banks();
      await ui.show('bankaccount-list-item-${b.accountId}');
      await ui.gone('bankaccount-list-item-${a.accountId}');
      await _signOut();
    });
    await run.step('009 · 존재하지 않는 ID의 로그인 거절', () async {
      await _signIn(a, username: '${a.username}-none', success: false);
      await ui.expectText('signin-error', '사용자 ID 또는 비밀번호가 올바르지 않습니다.');
      await _status(
        a,
        'POST',
        '/login',
        401,
        data: {'username': '${a.username}-none', 'password': a.password},
      );
    });
  }
}
