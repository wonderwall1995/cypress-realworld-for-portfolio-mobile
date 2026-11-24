part of 'simulation_scenarios.dart';

extension _MoneyCases on SimulationScenarios {
  Future<Map<String, dynamic>> _createOnScreen(_Person p) async {
    final fixture = SimulationFixtures.account();
    final bankName = fixture['bankName']!;
    final number = fixture['accountNumber']!;
    await ui.tap('bankaccount-new');
    await ui.enter('bankaccount-bankName-input', bankName);
    await ui.enter('bankaccount-accountNumber-input', number);
    await ui.tap('bankaccount-submit');
    await ui.gone('bankaccount-form');
    final account = (await _call(
      p.api.getBankAccounts,
    )).singleWhere((a) => a['accountNumber'] == number);
    _check(account['balance'] == 0 && account['accountNumber'] == number);
    await ui.expectText('bankaccount-list-item-${account['id']}', bankName);
    await ui.expectText(
      'bankaccount-account-number-${account['id']}',
      number.substring(number.length - 4),
    );
    return account;
  }

  Future<void> bankAccount() async {
    late _Person a;
    final created = <Map<String, dynamic>>[];
    await run.step('001 · 계좌 없는 사용자로 시작', () async {
      a = await _prepare('A', bank: false);
      await _signIn(a);
      await _banks();
      await ui.waitFor('bankaccount-list-empty');
    });
    final count = 1 + Random.secure().nextInt(3);
    for (var i = 0; i < count; i++) {
      await run.step('001 · 화면으로 계좌 만들기 ${i + 1}/$count', () async {
        created.add(await _createOnScreen(a));
      });
    }
    final deleteCount = 1 + Random.secure().nextInt(count);
    for (final account in created.take(deleteCount)) {
      await run.step('001 · 화면으로 계좌 삭제 · 숨김 처리', () async {
        await ui.tap(
          'bankaccount-delete',
          inside: 'bankaccount-list-item-${account['id']}',
        );
        await ui.tap('bankaccount-delete-confirm');
        await ui.gone('bankaccount-list-item-${account['id']}');
      });
    }
    await run.step('001 · 남은 계좌와 숨긴 행 수 확인', () async {
      await _banks();
      final rows = await _call(
        () => a.api.dio.get<Map<String, dynamic>>('/demo/bankaccounts/count'),
      );
      _check(
        rows.data?['total'] == count &&
            rows.data?['hidden'] == deleteCount &&
            rows.data?['visible'] == count - deleteCount,
      );
      final accounts = await _call(a.api.getBankAccounts);
      _check(accounts.length == count - deleteCount);
      for (final account in created.skip(deleteCount)) {
        _check(accounts.any((item) => item['id'] == account['id']));
        await ui.show('bankaccount-list-item-${account['id']}');
      }
    });
    await run.step('001 · API로 58개까지 생성 · 긴 단계', () async {
      var accounts = await _call(a.api.getBankAccounts);
      for (var i = accounts.length; i < 58; i++) {
        await _newAccount(a, sequence: i + 1);
      }
      accounts = await _call(a.api.getBankAccounts);
      _check(accounts.length == 58);
      await _banks();
      await ui.show('bankaccount-list-item-${accounts.last['id']}');
      await ui.show('bankaccount-list-item-${accounts.first['id']}');
    });
    for (final count in [59, 60]) {
      await run.step('001 · 화면에서 $count번째 계좌 생성', () async {
        await _createOnScreen(a);
        _check((await _call(a.api.getBankAccounts)).length == count);
      });
    }
    await run.step('001 · 61번째 계좌는 화면과 서버에서 거절', () async {
      await ui.disabled('bankaccount-new');
      await ui.waitFor('bankaccount-limit');
      await _status(
        a,
        'POST',
        '/bankAccounts',
        400,
        data: {'bankName': '한도 시연', 'accountNumber': '123456789'},
      );
      _check((await _call(a.api.getBankAccounts)).length == 60);
    });
    await run.step('001 · 잔액 있는 계좌의 삭제 거절', () async {
      final rich = (await _call(a.api.getBankAccounts)).first;
      await _call(
        () => a.api.moveMoney(
          bankAccountId: rich['id'] as String,
          amount: 1,
          type: 'deposit',
        ),
      );
      await _banks();
      await ui.disabled(
        'bankaccount-delete',
        inside: 'bankaccount-list-item-${rich['id']}',
      );
      await _status(a, 'DELETE', '/bankAccounts/${rich['id']}', 400);
      _check((await _call(a.api.getBankAccounts)).length == 60);
      await _balance(a, 100);
    });
    await run.step('001 · API로 전체 계좌 정리하고 빈 화면 확인', () async {
      await _clearAccounts(a);
      await _banks();
      await ui.waitFor('bankaccount-list-empty');
      final rows = await _call(
        () => a.api.dio.get<Map<String, dynamic>>('/demo/bankaccounts/count'),
      );
      _check(
        rows.data?['total'] == 0 &&
            rows.data?['hidden'] == 0 &&
            rows.data?['visible'] == 0,
      );
    });
  }

  Future<void> _openDeposit(String accountId) async {
    await ui.tap('sidenav-my-account');
    await ui.tap('sidenav-deposit');
    await ui.tap('deposit-account-$accountId');
  }

  Future<void> deposit() async {
    late _Person a;
    final expected = <String, int>{};
    await run.step('002 · 사용자와 계좌 3개 준비', () async {
      a = await _prepare('A', bank: false);
      for (var i = 1; i <= 3; i++) {
        await _newAccount(a, sequence: i);
      }
      for (final item in await _call(a.api.getBankAccounts)) {
        expected[item['id'] as String] = 0;
      }
      _check(expected.length == 3);
      await _signIn(a);
      await _banks();
    });
    Future<void> expectBalance(String id) async {
      final accounts = await _call(a.api.getBankAccounts);
      _check(
        accounts.singleWhere((item) => item['id'] == id)['balance'] ==
            expected[id],
      );
      await _banks();
      await ui.expectText(
        'bankaccount-balance-$id',
        '잔액 ${formatUsd(expected[id]!)}',
      );
    }

    Future<void> accepted(String id, int dollars) async {
      await _openDeposit(id);
      await ui.enter('deposit-amount-input', '$dollars');
      await ui.tap('deposit-submit-button');
      await ui.gone('deposit-dialog');
      expected[id] = expected[id]! + dollars * 100;
      await expectBalance(id);
    }

    Future<void> refused(
      String id,
      String amount,
      String notice, {
      bool server = false,
    }) async {
      await _openDeposit(id);
      await ui.enter('deposit-amount-input', amount);
      await ui.tap('deposit-submit-button');
      if (server) {
        await ui.waitFor('deposit-error');
      } else {
        await ui.expectText('deposit-dialog', notice);
      }
      await ui.tap('deposit-cancel-button');
      await ui.gone('deposit-dialog');
      await expectBalance(id);
    }

    for (final id in expected.keys.toList()) {
      await run.step('002 · 각 계좌에 100달러 입금', () => accepted(id, 100));
    }
    final ids = expected.keys.toList();
    await run.step('002 · 작은 금액과 큰 금액 표시', () async {
      await accepted(ids.first, 1 + Random.secure().nextInt(10));
      await accepted(ids.last, 10000 + Random.secure().nextInt(90001));
    });
    for (final amount in [-1, 0]) {
      await run.step(
        '002 · $amount달러 입력 거절',
        () => refused(ids.first, '$amount', '금액은 1달러 이상이어야 합니다.'),
      );
    }
    await run.step('002 · 최소 금액 1달러 입금', () => accepted(ids.first, 1));
    await run.step('002 · 최대 입력 금액과 총 잔액 한도', () async {
      await refused(
        ids.first,
        '${SimulationScenarios.maxDollars + 1}',
        '금액은 21,474,836달러 이하여야 합니다.',
      );
      await refused(
        ids.first,
        '${SimulationScenarios.maxDollars}',
        '',
        server: true,
      );
      for (final amount in [
        -1,
        0,
        SimulationScenarios.maxDollars + 1,
        SimulationScenarios.maxDollars,
      ]) {
        await _status(
          a,
          'POST',
          '/bankTransfers',
          amount <= 0 ? 422 : 400,
          data: {
            'bankAccountId': ids.first,
            'amount': amount,
            'type': 'deposit',
          },
        );
      }
      await expectBalance(ids.first);
      await _balance(a, expected.values.fold(0, (sum, v) => sum + v));
    });
    await run.step('002 · 빈 계좌에서 최대 금액 입금 후 1달러 추가 거절', () async {
      await _clearAccounts(a);
      final empty = await _newAccount(a);
      final id = empty['id'] as String;
      expected[id] = 0;
      await _banks();
      await accepted(id, SimulationScenarios.maxDollars);
      await refused(id, '1', '', server: true);
      await _balance(a, SimulationScenarios.maxDollars * 100);
    });
  }

  Future<void> _openTransfer(_Person to) async {
    await ui.tap('sidenav-my-account');
    await ui.tap('sidenav-transfer');
    await ui.enter('user-list-search-input', to.username);
    await ui.tap('user-list-item-${to.id}');
    await ui.waitFor('transaction-create-form');
  }

  Future<void> _fillTransfer(String amount, String memo) async {
    await ui.enter('transaction-create-amount-input', amount);
    await ui.enter('transaction-create-description-input', memo);
  }

  Future<void> _confirmTransfer(String password) async {
    await ui.tap('transaction-create-submit-payment');
    await ui.enter('transaction-confirm-password', password);
    await ui.tap('transaction-confirm-confirm');
  }

  Future<void> transfer() async {
    late _Person a;
    late _Person b;
    late _Person c;
    final dollars = 1 + Random.secure().nextInt(500);
    await run.step('003 · 세 사용자와 각 1,000달러 준비', () async {
      a = await _prepare('A', dollars: 1000);
      b = await _prepare('B', dollars: 1000);
      c = await _prepare('C', dollars: 1000);
      await _signIn(a);
      await _balance(a, 100000);
      await _openTransfer(b);
    });
    await run.step('003 · 잔액 부족 거절', () async {
      await _fillTransfer('1001', '잔액 부족');
      await ui.disabled('transaction-create-submit-payment');
      await ui.waitFor('transaction-create-not-enough');
      await _status(
        a,
        'POST',
        '/transactions',
        400,
        data: _payment(a, b, 1001),
      );
    });
    for (final item in [
      ('0', '금액은 1달러 이상'),
      ('1.5', '소수점 없음'),
      ('21474837', '금액은 21,474,836달러 이하'),
    ]) {
      await run.step('003 · 잘못된 이체 금액 ${item.$1}', () async {
        await _fillTransfer(item.$1, '잘못된 금액');
        await ui.tap('transaction-create-submit-payment');
        await ui.expectText('transaction-create-form', item.$2);
        await ui.gone('transaction-confirm-dialog');
        await _status(
          a,
          'POST',
          '/transactions',
          422,
          data: _payment(a, b, item.$1),
        );
      });
    }
    await run.step('003 · 틀린 계정 비밀번호 거절', () async {
      await _fillTransfer('$dollars', '비밀번호 틀림');
      await _confirmTransfer('wrong-password');
      await ui.expectText('transaction-confirm-error', '비밀번호');
      await ui.tap('transaction-confirm-cancel');
      await _status(
        a,
        'POST',
        '/transactions',
        403,
        data: _payment(a, b, dollars, password: 'wrong-password'),
      );
      _check((await _call(a.api.checkAuth))?['balance'] == 100000);
    });
    await run.step('003 · A → B 화면 이체', () async {
      await _go('/my-account');
      await _openTransfer(b);
      await _fillTransfer('$dollars', '순환 1: A → B');
      await _confirmTransfer(a.password);
      await ui.waitFor('new-transaction-return-to-transactions');
      await ui.tap('new-transaction-return-to-transactions');
      await _balance(a, (1000 - dollars) * 100);
      _check(
        (await _call(b.api.checkAuth))?['balance'] == (1000 + dollars) * 100,
      );
    });
    await run.step('003 · B → C → A API 이체와 잔액 복원', () async {
      await _send(b, c, dollars, memo: '순환 2: B → C');
      await _send(c, a, dollars, memo: '순환 3: C → A');
      for (final p in [a, b, c]) {
        _check((await _call(p.api.checkAuth))?['balance'] == 100000);
        _check(
          (await _call(p.api.getBankAccounts)).single['balance'] == 100000,
        );
      }
      await _balance(a, 100000);
    });
  }
}
