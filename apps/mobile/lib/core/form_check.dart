import 'package:flutter/material.dart';

/// Checks every field of the form. When one is wrong, the topmost wrong field comes
/// into view: the button can be far below it, and then nothing would seem to happen.
/// A field that is in view already does not move.
bool checkForm(GlobalKey<FormState> form) {
  final wrong = form.currentState!.validateGranularly();
  if (wrong.isEmpty) return true;
  // After the frame, so that the messages have their place.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    double top(FormFieldState<Object?> field) =>
        (field.context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero).dy;
    final shown = wrong.where((field) => field.mounted).toList()..sort((a, b) => top(a).compareTo(top(b)));
    if (shown.isEmpty) return;
    final field = shown.first;
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      if (!field.context.mounted) return;
      await Scrollable.ensureVisible(
        field.context,
        alignmentPolicy: policy,
        duration: const Duration(milliseconds: 200),
      );
    }
  });
  return false;
}
