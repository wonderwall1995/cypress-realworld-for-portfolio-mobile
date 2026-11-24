import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/session.dart';
import '../../core/test_id.dart';
import 'simulation_case.dart';
import 'simulation_driver.dart';
import 'simulation_launcher.dart';
import 'simulation_run.dart';
import 'simulation_traffic.dart';

/// The router (including its dialogs) lives below this host. The controls never
/// need a route or a platform window overlay permission.
class SimulationHost extends ConsumerStatefulWidget {
  const SimulationHost({required this.child, required this.execute, super.key});

  final Widget child;
  final Future<void> Function(
    SimulationCase selected,
    SimulationDriver driver,
    SimulationRun run,
  )
  execute;

  @override
  ConsumerState<SimulationHost> createState() => _SimulationHostState();
}

class _SimulationHostState extends ConsumerState<SimulationHost>
    with WidgetsBindingObserver {
  final _run = SimulationRun();
  final _traffic = SimulationTraffic();
  final _appKey = GlobalKey();
  late ApiClient _api;
  Future<void>? _stopping;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run.addListener(_changed);
    _api = ref.read(apiClientProvider);
    _api.dio.interceptors.add(_traffic);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _run.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _api.dio.interceptors.remove(_traffic);
    _run.removeListener(_changed);
    _run.dispose();
    super.dispose();
  }

  void _open() {
    // The launcher only belongs to a signed-out screen; do not switch an active
    // visitor's session if this callback is reached from an old screen.
    if (_run.phase == SimulationPhase.idle &&
        ref.read(sessionProvider).status == SessionStatus.unauthenticated) {
      FocusManager.instance.primaryFocus?.unfocus();
      _run.select();
    }
  }

  void _start(SimulationCase selected) {
    if (_run.phase != SimulationPhase.selecting) return;
    unawaited(_play(selected));
  }

  Future<void> _play(SimulationCase selected) async {
    final driver = SimulationDriver(() => _appKey.currentContext!, _run);
    await _run.start(
      selected.label,
      () => widget.execute(selected, driver, _run),
    );
    // Join the completed task before calling stop: cancel() itself joins it.
    if (mounted && _run.phase == SimulationPhase.completed) await _stop();
  }

  Future<void> _stop({bool selectAgain = false}) {
    return _stopping ??= _finish(
      selectAgain,
    ).whenComplete(() => _stopping = null);
  }

  Future<void> _finish(bool selectAgain) async {
    await _run.cancel();
    await _traffic.drain();
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Dismiss pageless dialogs before clearing the route stack. Root pages are
    // managed by GoRouter; nested pages disappear when it goes to /signin.
    final router = ref.read(routerProvider);
    router.routerDelegate.navigatorKey.currentState?.popUntil(
      (route) => route.settings is Page,
    );
    try {
      await ref.read(sessionProvider.notifier).signOut();
    } finally {
      if (mounted) {
        router.go('/signin');
        selectAgain ? _run.select() : _run.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = _run.phase;
    final stopping = phase == SimulationPhase.stopping;
    return SimulationLauncher(
      open: _open,
      child: Overlay.wrap(
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (event.device != SimulationDriver.pointerDevice) {
                    _run.pause();
                  }
                },
                child: AbsorbPointer(
                  absorbing: stopping,
                  child: KeyedSubtree(key: _appKey, child: widget.child),
                ),
              ),
            ),
            if (_run.active)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _controls(context, stopping),
              ),
            if (phase == SimulationPhase.selecting)
              Positioned.fill(child: _selection(context)),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, bool stopping) {
    final phase = _run.phase;
    final paused = phase == SimulationPhase.paused;
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colors.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TestId(
                    'simulation-select',
                    child: IconButton(
                      tooltip: '테스트 다시 선택',
                      onPressed: stopping
                          ? null
                          : () => _stop(selectAgain: true),
                      icon: const Icon(Icons.list_alt),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _run.selected ?? '시연',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        TestId(
                          'simulation-status',
                          child: Text(
                            '${paused ? '일시정지 · ' : ''}${_run.message}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (phase == SimulationPhase.running || paused)
                    TestId(
                      'simulation-pause-resume',
                      child: IconButton(
                        tooltip: paused ? '시연 재개' : '일시정지',
                        onPressed: paused ? _run.resume : _run.pause,
                        icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      ),
                    ),
                  TestId(
                    'simulation-stop',
                    child: TextButton.icon(
                      onPressed: stopping ? null : () => _stop(),
                      icon: const Icon(Icons.stop),
                      label: const Text('중지'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selection(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('테스트 시연'),
              subtitle: const Text('휴대폰 시뮬레이션'),
              trailing: TestId(
                'simulation-close',
                child: IconButton(
                  tooltip: '닫기',
                  onPressed: _run.close,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '실제 서버를 사용하며 시연 데이터가 남습니다. 화면을 터치하면 일시정지합니다. '
                '앱 재설치와 PC DB 조회는 수행하지 않으며, E2E 테스트 판정과는 별도입니다.',
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final selected in SimulationCase.values)
                    TestId(
                      'simulation-case-${selected.code}',
                      child: ListTile(
                        title: Text(selected.label),
                        trailing: const Icon(Icons.play_circle_outline),
                        onTap: () => _start(selected),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
