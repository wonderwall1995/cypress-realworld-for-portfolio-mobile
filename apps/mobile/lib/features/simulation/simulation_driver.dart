import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/test_id.dart';
import 'simulation_run.dart';

/// Uses the app's real controls and text editing pipeline in release builds.
/// No flutter_test, Appium, reflection, or platform accessibility service.
class SimulationDriver {
  SimulationDriver(this.root, this.run);

  static const pointerDevice = -4343;
  final BuildContext Function() root;
  final SimulationRun run;
  int _pointer = 40000;

  bool _inHorizontalViewport(Element element) {
    final box = element.findRenderObject();
    final surface = (root() as Element).findRenderObject();
    if (box is! RenderBox ||
        surface is! RenderBox ||
        !box.hasSize ||
        !surface.hasSize) {
      return false;
    }
    final left = box.localToGlobal(Offset.zero).dx;
    final surfaceLeft = surface.localToGlobal(Offset.zero).dx;
    final visibleWidth =
        (left + box.size.width).clamp(
          surfaceLeft,
          surfaceLeft + surface.size.width,
        ) -
        left.clamp(surfaceLeft, surfaceLeft + surface.size.width);
    // During a TabBarView animation a sliver of the previous page is still
    // visible. Selecting it would make ensureVisible switch the tab back.
    return visibleWidth >= (box.size.width.clamp(0, surface.size.width) * 0.5);
  }

  Element? find(String id) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is TestId && widget.id == id) {
        if (ModalRoute.of(element)?.isCurrent == false) return;
        if (!_inHorizontalViewport(element)) return;
        final box = element.findRenderObject();
        if (box is RenderBox &&
            box.attached &&
            box.hasSize &&
            !box.size.isEmpty) {
          found = element;
          return;
        }
      }
      element.visitChildren(visit);
    }

    visit(root() as Element);
    return found;
  }

  Future<Element> waitFor(String id) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await run.checkpoint();
      final element = find(id);
      if (element != null) return element;
      await run.delay(const Duration(milliseconds: 100));
    }
    throw StateError('Control not ready: $id');
  }

  Future<Element> _reveal(String id) async {
    Element? element;
    // Lazy lists only build nearby rows. Search the active vertical viewport
    // in both directions, rather than pretending all 60 bank rows exist.
    var backwards = false;
    for (var attempt = 0; attempt < 160; attempt++) {
      await run.checkpoint();
      element = find(id);
      if (element != null) break;
      ScrollableState? scroll;
      void visit(Element node) {
        if (node.widget is Offstage && (node.widget as Offstage).offstage) {
          return;
        }
        if (node is StatefulElement &&
            node.state is ScrollableState &&
            ModalRoute.of(node)?.isCurrent != false) {
          final candidate = node.state as ScrollableState;
          if (candidate.position.hasContentDimensions &&
              _inHorizontalViewport(node) &&
              axisDirectionToAxis(candidate.axisDirection) == Axis.vertical &&
              candidate.position.maxScrollExtent > 0) {
            scroll = candidate;
          }
        }
        node.visitChildren(visit);
      }

      visit(root() as Element);
      if (scroll != null) {
        final position = scroll!.position;
        if (position.pixels >= position.maxScrollExtent - 1) backwards = true;
        if (position.pixels <= position.minScrollExtent + 1) backwards = false;
        position.jumpTo(
          (position.pixels +
                  position.viewportDimension * (backwards ? -0.7 : 0.7))
              .clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      }
      await run.delay(const Duration(milliseconds: 150));
    }
    if (element == null) throw StateError('Control not reachable: $id');
    await Scrollable.ensureVisible(
      element,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
    );
    await run.delay(const Duration(milliseconds: 250));
    element = await waitFor(id);
    await run.checkpoint();
    return element;
  }

  Future<void> show(String id) async {
    await _reveal(id);
  }

  Future<void> gone(String id) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await run.checkpoint();
      if (find(id) == null) return;
      await run.delay(const Duration(milliseconds: 100));
    }
    throw StateError('Control still present: $id');
  }

  Future<void> disabled(String id, {String? inside}) async {
    final container = await _reveal(inside ?? id);
    Element? target = inside == null ? container : null;
    void locate(Element element) {
      if (element.widget is TestId && (element.widget as TestId).id == id) {
        target = element;
      }
      element.visitChildren(locate);
    }

    if (inside != null) locate(container);
    bool? enabled;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is ButtonStyleButton) {
        enabled = widget.onPressed != null;
        return;
      }
      if (widget is IconButton) {
        enabled = widget.onPressed != null;
        return;
      }
      element.visitChildren(visit);
    }

    if (target != null) visit(target!);
    if (enabled != false) throw StateError('Expected disabled: $id');
  }

  Future<void> typed(String id, String value) async {
    final target = await _reveal(id);
    String? text;
    void visit(Element node) {
      if (node.widget is EditableText) {
        text = (node.widget as EditableText).controller.text;
      }
      node.visitChildren(visit);
    }

    visit(target);
    if (text != value) throw StateError('Typed value differs: $id');
  }

  Future<void> tap(String id, {String? inside}) async {
    var element = await _reveal(inside ?? id);
    if (inside != null) {
      Element? target;
      void visit(Element node) {
        if (node.widget is TestId && (node.widget as TestId).id == id) {
          target = node;
        }
        node.visitChildren(visit);
      }

      visit(element);
      if (target == null) throw StateError('Nested control not found: $id');
      element = target!;
      await Scrollable.ensureVisible(element, alignment: 0.5);
    }
    final box = element.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(box.size.center(Offset.zero));
    final pointer = _pointer++;
    // The host recognizes only this device as automation. Human taps pause.
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        device: pointerDevice,
        position: position,
      ),
    );
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        device: pointerDevice,
        position: position,
      ),
    );
    await run.delay(const Duration(milliseconds: 300));
  }

  Future<void> enter(String id, String value) async {
    final element = await _reveal(id);
    EditableTextState? editor;
    void visit(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        editor = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    visit(element);
    if (editor == null) throw StateError('No editor: $id');
    // Applies input formatters, FormField changes and onChanged just as typing.
    editor!.userUpdateTextEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await run.delay(const Duration(milliseconds: 250));
  }

  Future<void> expectText(String id, String expected) async {
    await _reveal(id);
    for (var attempt = 0; attempt < 200; attempt++) {
      await run.checkpoint();
      final element = find(id);
      final texts = <String>[];
      void visit(Element element) {
        final widget = element.widget;
        if (widget is Text) {
          texts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
        }
        element.visitChildren(visit);
      }

      if (element != null) visit(element);
      if (texts.join(' ').contains(expected)) return;
      await run.delay(const Duration(milliseconds: 100));
    }
    throw StateError('Expected text missing: $id');
  }
}
