import 'package:flutter/widgets.dart';

/// Marks a widget so tests can find it.
///
/// Use the same name as the web `data-testid` (see `testid-listup.md` in the
/// web repo). The name is set as a [ValueKey] (Flutter tests) and as a
/// Semantics identifier (Appium).
class TestId extends StatelessWidget {
  const TestId(this.id, {required this.child, super.key});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: id,
      container: true,
      child: KeyedSubtree(key: ValueKey<String>(id), child: child),
    );
  }
}
