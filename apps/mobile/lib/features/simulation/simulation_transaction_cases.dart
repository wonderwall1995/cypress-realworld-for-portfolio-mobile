part of 'simulation_scenarios.dart';

extension _TransactionCases on SimulationScenarios {
  Future<List<dynamic>> _items(
    _Person p,
    String path,
    String key, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _call(
      () => p.api.dio.get<Map<String, dynamic>>(path, queryParameters: query),
    );
    return response.data![key] as List<dynamic>;
  }

  Future<void> detail() async {
    late _Person a;
    late _Person b;
    late String id;
    final text = SimulationFixtures.korean(8);
    await run.step('004 · 이체 한 건 준비하고 거래 상세 열기', () async {
      a = await _prepare('A', dollars: 1000);
      b = await _prepare('B', dollars: 1000);
      id =
          (await _send(
                a,
                b,
                1 + Random.secure().nextInt(500),
                memo: '거래 상세 시연',
              ))['id']
              as String;
      await _signIn(a);
      await ui.tap('transaction-item-$id');
      await ui.expectText('transaction-like-count-$id', '0');
      await ui.expectText('transaction-comment-count-$id', '0');
      await ui.waitFor('comments-empty');
    });
    await run.step('004 · 좋아요와 중복 좋아요 거절', () async {
      await ui.tap('transaction-like-button-$id');
      await ui.expectText('transaction-like-count-$id', '1');
      await ui.disabled('transaction-like-button-$id');
      final likes = await _items(a, '/likes/$id', 'likes');
      _check(likes.length == 1 && likes.single['userId'] == a.id);
      await _status(a, 'POST', '/likes/$id', 409);
      _check((await _items(a, '/likes/$id', 'likes')).length == 1);
    });
    await run.step('004 · 댓글 작성과 작성자 확인', () async {
      await ui.enter('transaction-comment-input-$id', text);
      await ui.tap('transaction-comment-submit-$id');
      await ui.expectText('transaction-comment-count-$id', '1');
      await ui.expectText('comments-list', text);
      final comments = await _items(a, '/comments/$id', 'comments');
      _check(
        comments.length == 1 &&
            comments.single['content'] == text &&
            comments.single['userId'] == a.id,
      );
    });
    for (final blank in ['', '   ']) {
      await run.step('004 · 빈 댓글과 공백 댓글 거절', () async {
        await ui.enter('transaction-comment-input-$id', blank);
        await ui.disabled('transaction-comment-submit-$id');
        await _status(
          a,
          'POST',
          '/comments/$id',
          422,
          data: {'content': blank},
        );
      });
    }
    await run.step('004 · 상세를 다시 열어 같은 결과 확인', () async {
      await _go('/');
      await ui.tap('transaction-item-$id');
      await ui.expectText('transaction-like-count-$id', '1');
      await ui.expectText('transaction-comment-count-$id', '1');
      await ui.expectText('comments-list', text);
      await ui.disabled('transaction-like-button-$id');
      _check((await _items(a, '/comments/$id', 'comments')).length == 1);
    });
  }

  Future<void> _amount(
    String kind,
    String min,
    String max, {
    bool apply = true,
  }) async {
    final prefix = 'transaction-list-filter-$kind';
    await ui.tap('$prefix-button');
    await ui.enter('$prefix-min', min);
    await ui.enter('$prefix-max', max);
    if (apply) {
      await ui.tap('$prefix-apply-button');
      await ui.gone(prefix);
    }
  }

  Future<void> _dates(String start, String end) async {
    for (final box in {'start': start, 'end': end}.entries) {
      final values = box.value.split('-');
      var index = 0;
      for (final field in ['year', 'month', 'day']) {
        await ui.enter(
          'transaction-list-filter-date-${box.key}-$field',
          index < values.length ? values[index] : '',
        );
        index++;
      }
    }
    await run.delay(const Duration(milliseconds: 600));
  }

  Future<void> filter() async {
    late _Person a;
    late _Person b;
    late _Person c;
    final ids = <String>[];
    late String opening;
    await run.step('005 · 입금과 송수신 거래 5건 준비', () async {
      a = await _prepare('A', dollars: 1000);
      b = await _prepare('B', dollars: 1000);
      c = await _prepare('C', dollars: 1000);
      opening = (await _mine(a)).single['id'] as String;
      ids.add(
        (await _send(a, b, 10 + Random.secure().nextInt(81)))['id'] as String,
      );
      ids.add(
        (await _send(a, c, 250 + Random.secure().nextInt(141)))['id'] as String,
      );
      ids.add(
        (await _send(b, a, 10 + Random.secure().nextInt(81)))['id'] as String,
      );
      ids.add(
        (await _send(c, a, 250 + Random.secure().nextInt(141)))['id'] as String,
      );
      _check((await _mine(a)).length == 5);
      await _signIn(a);
      await _myTransactions();
      for (final id in [...ids.reversed, opening]) {
        await _row(id);
      }
      await _row(ids.last);
    });
    for (final item in [
      ('withdrawal', ids[0], ids[1]),
      ('deposit', ids[2], ids[3]),
    ]) {
      for (final range in [
        ('1', '100', item.$2),
        ('200', '400', item.$3),
        ('500', '600', ''),
      ]) {
        await run.step(
          '005 · ${item.$1} ${range.$1}~${range.$2}달러 필터',
          () async {
            await _amount(item.$1, range.$1, range.$2);
            final results = (await _call(
              () => a.api.getTransactions(
                '/transactions',
                page: 1,
                filters: {
                  '${item.$1}Min': '${int.parse(range.$1) * 100}',
                  '${item.$1}Max': '${int.parse(range.$2) * 100}',
                },
              ),
            )).results;
            if (range.$3.isEmpty) {
              _check(results.isEmpty);
              await ui.waitFor('transaction-list-empty');
            } else {
              _check(results.length == 1 && results.single['id'] == range.$3);
              await _row(range.$3);
              for (final other in ids.where((id) => id != range.$3)) {
                await ui.gone('transaction-item-$other');
              }
            }
          },
        );
      }
      await _amount(item.$1, '', '');
      await _row(ids.last);
    }
    for (final wrong in [
      (
        '100',
        '50',
        '최소 금액이 최대 금액보다 클 수 없습니다',
        <String, dynamic>{'withdrawalMin': 10000, 'withdrawalMax': 5000},
      ),
      ('10.5', '', '숫자(정수)만 입력하세요', <String, dynamic>{'withdrawalMin': '10.5'}),
      (
        '21474837',
        '',
        '21,474,836 이하로 입력하세요',
        <String, dynamic>{'withdrawalMin': 2147483700},
      ),
    ]) {
      await run.step('005 · 잘못된 금액 구간 거절', () async {
        await _amount('withdrawal', wrong.$1, wrong.$2, apply: false);
        await ui.expectText(
          'transaction-list-filter-withdrawal-message',
          wrong.$3,
        );
        await ui.disabled('transaction-list-filter-withdrawal-apply-button');
        await ui.tap('transaction-list-filter-withdrawal-reset-button');
        await ui.gone('transaction-list-filter-withdrawal');
        await _row(ids.last);
        await _status(a, 'GET', '/transactions', 422, query: wrong.$4);
      });
    }
    String day(int offset) {
      final today = DateTime.now();
      final date = DateTime(today.year, today.month, today.day + offset);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    await run.step('005 · 미래 날짜와 오늘 포함 날짜 구간', () async {
      await _dates(day(10), day(20));
      await ui.waitFor('transaction-list-empty');
      await _dates(day(-1), day(1));
      await _row(ids.last);
    });
    for (final wrong in [
      (
        '2027-03-02',
        '2027-03-01',
        '시작일이 종료일보다 늦을 수 없습니다',
        <String, dynamic>{
          'dateRangeStart': '2027-03-02',
          'dateRangeEnd': '2027-03-01',
        },
      ),
      (
        '2027-02-30',
        '',
        '시작일: 존재하지 않는 날짜입니다',
        <String, dynamic>{'dateRangeStart': '2027-02-30'},
      ),
      ('2027-02', '', '시작일의 연·월·일을 모두 입력하세요', <String, dynamic>{}),
    ]) {
      await run.step('005 · 잘못되거나 덜 쓴 날짜 거절', () async {
        await _dates(wrong.$1, wrong.$2);
        await ui.expectText('transaction-list-filter-date-message', wrong.$3);
        if (wrong.$4.isNotEmpty) {
          await _status(a, 'GET', '/transactions', 422, query: wrong.$4);
        }
      });
    }
    await run.step('005 · 날짜 필터 초기화와 전체 내역 확인', () async {
      await ui.tap('transaction-list-filter-date-clear-button');
      await ui.gone('transaction-list-filter-date-message');
      for (final id in [...ids.reversed, opening]) {
        await _row(id);
      }
      await _row(ids.last);
    });
  }

  Future<void> visibility() async {
    late _Person a;
    late _Person b;
    late _Person c;
    late String secret;
    late String open;
    late String depositA;
    late String depositC;
    await run.step('007 · 공개·비공개 거래와 세 사용자 준비', () async {
      a = await _prepare('A', dollars: 1000);
      b = await _prepare('B', dollars: 1000);
      c = await _prepare('C', dollars: 1000);
      depositA = (await _mine(a)).single['id'] as String;
      depositC = (await _mine(c)).single['id'] as String;
      secret =
          (await _send(
                a,
                b,
                1 + Random.secure().nextInt(100),
                privacy: 'private',
                memo: '비공개 거래',
              ))['id']
              as String;
      open =
          (await _send(
                a,
                b,
                1 + Random.secure().nextInt(100),
                memo: '공개 거래',
              ))['id']
              as String;
    });
    await run.step('007 · 관계없는 C는 공개 거래만 볼 수 있음', () async {
      await _signIn(c);
      await ui.tap('nav-public-tab');
      await _row(open);
      await _row(depositC);
      await ui.gone('transaction-item-$secret');
      await _status(c, 'GET', '/transactions/$secret', 404);
      await _status(c, 'GET', '/transactions/$open', 200);
      await ui.tap('transaction-item-$open');
      await ui.waitFor('transaction-detail-header');
      await _go('/');
      await _myTransactions();
      await _row(depositC);
      _check((await _mine(c)).length == 1);
      await ui.gone('transaction-item-$open');
      await ui.gone('transaction-item-$secret');
    });
    await run.step('007 · 보낸 A는 공개·비공개·자기 입금 모두 확인', () async {
      await _signOut();
      await _signIn(a);
      await _myTransactions();
      for (final id in [open, secret, depositA]) {
        await _row(id);
      }
    });
    await run.step('007 · 받은 B도 비공개 거래 확인', () async {
      await _signOut();
      await _signIn(b);
      await _myTransactions();
      await _row(open);
      await _row(secret);
    });
  }

  Future<void> notifications() async {
    late _Person a;
    late _Person b;
    late _Person c;
    late Map<String, dynamic> comment;
    late Map<String, dynamic> like;
    late Map<String, dynamic> payment;
    await run.step('008 · 이체·좋아요·댓글로 알림 3개 생성', () async {
      a = await _prepare('A', dollars: 1000);
      b = await _prepare('B', dollars: 1000);
      c = await _prepare('C', dollars: 1000);
      final id =
          (await _send(
                b,
                a,
                1 + Random.secure().nextInt(100),
                memo: '알림 시연',
              ))['id']
              as String;
      await _call(() => c.api.likeTransaction(id));
      await _call(() => c.api.postComment(id, '알림을 일으키는 댓글'));
      final list = await _call(a.api.getNotifications);
      _check(list.length == 3);
      comment = list[0];
      like = list[1];
      payment = list[2];
      _check(
        comment['commentId'] != null &&
            like['likeId'] != null &&
            payment['status'] == 'received',
      );
    });
    await run.step('008 · 새 알림 3개와 보낸 사람 표시', () async {
      await _signIn(a);
      await ui.expectText('nav-top-notifications-count', '3');
      await ui.tap('sidenav-notifications');
      await ui.expectText(
        'notification-list-item-${payment['id']}',
        '${b.name}님이 이체했습니다.',
      );
      await ui.expectText(
        'notification-list-item-${like['id']}',
        '${c.name}님이 거래에 좋아요를 눌렀습니다.',
      );
      await ui.expectText(
        'notification-list-item-${comment['id']}',
        '${c.name}님이 거래에 댓글을 남겼습니다.',
      );
      for (final item in [payment, like, comment]) {
        await ui.show('notification-mark-read-${item['id']}');
      }
    });
    await run.step('008 · 두 알림 확인 후에도 목록에 유지', () async {
      for (final item in [payment, like]) {
        await ui.tap('notification-mark-read-${item['id']}');
        await ui.gone('notification-mark-read-${item['id']}');
        await ui.show('notification-list-item-${item['id']}');
      }
      await ui.expectText('nav-top-notifications-count', '1');
      await ui.tap('sidenav-home');
      await ui.tap('sidenav-notifications');
      for (final item in [payment, like]) {
        await ui.show('notification-list-item-${item['id']}');
        await ui.gone('notification-mark-read-${item['id']}');
      }
      await ui.show('notification-mark-read-${comment['id']}');
      final unread = await _items(a, '/notifications', 'results');
      _check(unread.length == 1 && unread.single['id'] == comment['id']);
      final history = await _call(a.api.getNotifications);
      _check(
        history.length == 3 &&
            history[0]['id'] == comment['id'] &&
            history[0]['isRead'] == false &&
            history[1]['id'] == like['id'] &&
            history[1]['isRead'] == true &&
            history[2]['id'] == payment['id'] &&
            history[2]['isRead'] == true,
      );
    });
    await run.step('008 · 모두 확인하면 배지만 사라짐', () async {
      await ui.tap('notification-mark-read-${comment['id']}');
      await ui.gone('nav-top-notifications-count');
      for (final item in [comment, like, payment]) {
        await ui.show('notification-list-item-${item['id']}');
        await ui.gone('notification-mark-read-${item['id']}');
      }
      _check((await _items(a, '/notifications', 'results')).isEmpty);
    });
  }
}
