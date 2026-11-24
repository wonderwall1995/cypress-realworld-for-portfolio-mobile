import 'dart:async';

import 'package:flutter/foundation.dart';

enum SimulationPhase {
  idle,
  selecting,
  running,
  paused,
  completed,
  failed,
  stopping,
}

class SimulationCancelled implements Exception {}

/// One task owns all steps. Cancellation wakes a paused task and is joined before
/// logout or another run, so an old task cannot sign in over a newer one.
class SimulationRun extends ChangeNotifier {
  SimulationPhase phase = SimulationPhase.idle;
  String message = '';
  String? selected;
  bool cleanupWarning = false;
  Object? failure;
  Future<void>? _task;
  bool _cancelled = false;
  bool _disposed = false;
  Completer<void>? _wake;

  bool get active =>
      phase != SimulationPhase.idle && phase != SimulationPhase.selecting;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void select() {
    phase = SimulationPhase.selecting;
    _emit();
  }

  void close() {
    phase = SimulationPhase.idle;
    _emit();
  }

  Future<void> start(String name, Future<void> Function() body) async {
    if (_task != null || active) return;
    selected = name;
    message = '시연을 준비합니다';
    _cancelled = false;
    cleanupWarning = false;
    failure = null;
    phase = SimulationPhase.running;
    _emit();
    final task = _execute(body);
    _task = task;
    await task;
    _task = null;
  }

  Future<void> _execute(Future<void> Function() body) async {
    try {
      await body();
      await checkpoint();
      phase = SimulationPhase.completed;
      message = cleanupWarning
          ? '시연 완료 · 일부 시연 계좌를 정리하지 못했습니다'
          : '시연 완료 · 로그아웃 후 로그인 화면으로 돌아갑니다';
    } on SimulationCancelled {
      return;
    } catch (error) {
      if (_cancelled) return;
      failure = error;
      phase = SimulationPhase.failed;
      // Do not expose server payloads or generated credentials in the panel.
      message = '$message · 시연을 마치지 못했습니다. 연결과 앱 화면을 확인하세요.';
    }
    _emit();
  }

  void pause() {
    if (phase != SimulationPhase.running) return;
    phase = SimulationPhase.paused;
    _emit();
  }

  void resume() {
    if (phase != SimulationPhase.paused) return;
    phase = SimulationPhase.running;
    _wake?.complete();
    _wake = null;
    _emit();
  }

  Future<void> checkpoint() async {
    if (_cancelled || _disposed) throw SimulationCancelled();
    while (phase == SimulationPhase.paused) {
      _wake ??= Completer<void>();
      await _wake!.future;
      if (_cancelled || _disposed) throw SimulationCancelled();
    }
  }

  Future<void> delay([
    Duration duration = const Duration(milliseconds: 650),
  ]) async {
    // Paused time does not consume step timing or element-readiness timeouts.
    for (
      var elapsed = Duration.zero;
      elapsed < duration;
      elapsed += const Duration(milliseconds: 50)
    ) {
      await checkpoint();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await checkpoint();
  }

  Future<void> step(String title, Future<void> Function() action) async {
    await checkpoint();
    message = title;
    _emit();
    await delay();
    await action();
    await checkpoint();
  }

  Future<void> cancel() async {
    _cancelled = true;
    phase = SimulationPhase.stopping;
    message = '처리 중인 요청을 마친 뒤 로그아웃합니다';
    _wake?.complete();
    _wake = null;
    _emit();
    await _task;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    _wake?.complete();
    _wake = null;
    super.dispose();
  }
}
