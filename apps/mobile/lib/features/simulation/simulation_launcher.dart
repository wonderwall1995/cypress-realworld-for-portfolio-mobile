import 'package:flutter/widgets.dart';

class SimulationLauncher extends InheritedWidget {
  const SimulationLauncher({
    required this.open,
    required super.child,
    super.key,
  });

  final VoidCallback open;

  static SimulationLauncher? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimulationLauncher>();

  @override
  bool updateShouldNotify(SimulationLauncher oldWidget) =>
      open != oldWidget.open;
}
