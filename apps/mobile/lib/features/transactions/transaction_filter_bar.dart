import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/test_id.dart';
import 'transaction_filters.dart';

/// The filters under the tabs, in the same shape as the web: a start day box and
/// an end day box (year / month / day each), and two amount chips (입금 금액,
/// 출금 금액). They are the same for the three lists.
class TransactionFilterBar extends StatelessWidget {
  const TransactionFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TestId(
        'transaction-list-filters',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateFilter(),
              SizedBox(height: 12),
              _AmountChips(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- date boxes

/// The date filter: a start box and an end box. It is applied a moment after the
/// two boxes make a valid range. A wrong entry changes nothing and says why.
class _DateFilter extends ConsumerStatefulWidget {
  const _DateFilter();

  @override
  ConsumerState<_DateFilter> createState() => _DateFilterState();
}

class _DateFilterState extends ConsumerState<_DateFilter> {
  static const _applyDelay = Duration(milliseconds: 400);

  late DateBox _start;
  late DateBox _end;

  /// A date filter set by these boxes is on now.
  late bool _applied;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // When the user comes back, the boxes show the filter that is still on.
    final filters = ref.read(transactionFiltersProvider);
    _start = DateBox.fromDate(filters.dateStart);
    _end = DateBox.fromDate(filters.dateEnd);
    _applied = filters.hasDate;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _change({DateBox? start, DateBox? end}) {
    setState(() {
      _start = start ?? _start;
      _end = end ?? _end;
    });
    _timer?.cancel();
    _timer = Timer(_applyDelay, _apply);
  }

  void _apply() {
    final result = buildDateRange(_start, _end);
    // A wrong entry keeps what is applied; the message says why.
    if (!result.ok) return;
    final controller = ref.read(transactionFiltersProvider.notifier);
    if (result.empty) {
      if (_applied) {
        _applied = false;
        controller.clearDate();
      }
    } else {
      _applied = true;
      controller.setDate(result.start, result.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Someone else cleared the filter (for example 필터 지우기 on an empty list).
    ref.listen<bool>(transactionFiltersProvider.select((f) => f.hasDate), (previous, now) {
      if (previous == true && !now && _applied) {
        _timer?.cancel();
        setState(() {
          _start = const DateBox();
          _end = const DateBox();
          _applied = false;
        });
      }
    });

    final result = buildDateRange(_start, _end);
    final error = result.ok ? null : dateRangeErrorText(result.error!, result.boxes);
    final anyText = !_start.isEmpty || !_end.isEmpty;
    final colors = Theme.of(context).colorScheme;

    return TestId(
      'transaction-list-filter-date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _DatePartsBox(
                title: '시작일',
                idPrefix: 'transaction-list-filter-date-start',
                value: _start,
                onChanged: (value) => _change(start: value),
                invalid: !result.ok && result.boxes.contains(DateBoxName.start),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('~', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              _DatePartsBox(
                title: '종료일',
                idPrefix: 'transaction-list-filter-date-end',
                value: _end,
                onChanged: (value) => _change(end: value),
                invalid: !result.ok && result.boxes.contains(DateBoxName.end),
              ),
              if (anyText)
                TestId(
                  'transaction-list-filter-date-clear-button',
                  child: TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onPressed: () => _change(start: const DateBox(), end: const DateBox()),
                    child: const Text('초기화'),
                  ),
                ),
            ],
          ),
          if (error != null)
            TestId(
              'transaction-list-filter-date-message',
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Part { year, month, day }

/// The characters that move the cursor on to the next field.
const _separators = '/-. ';

/// Keeps digits only, cuts to [max] characters, and understands two special
/// cases: a separator key moves on to the next field, and a pasted date such as
/// `2026/11/09` fills all three fields.
class _PartFormatter extends TextInputFormatter {
  _PartFormatter({required this.max, required this.onSeparator, required this.onPaste});

  final int max;
  final VoidCallback onSeparator;
  final void Function(String year, String month, String day) onPaste;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final pasted = RegExp(r'^\s*([0-9]{4})[^0-9]+([0-9]{1,2})[^0-9]+([0-9]{1,2})\s*$')
        .firstMatch(newValue.text);
    if (pasted != null) {
      final year = pasted.group(1)!;
      final month = pasted.group(2)!.padLeft(2, '0');
      final day = pasted.group(3)!.padLeft(2, '0');
      scheduleMicrotask(() => onPaste(year, month, day));
      return oldValue;
    }
    final typedSeparator = newValue.text.length == oldValue.text.length + 1 &&
        _separators.contains(newValue.text.substring(newValue.text.length - 1));
    if (typedSeparator) {
      if (oldValue.text.isNotEmpty) scheduleMicrotask(onSeparator);
      return oldValue;
    }
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > max) digits = digits.substring(0, max);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// One date = one box with three entry fields: [YYYY] / [MM] / [DD]. Digits
/// only; when a field is full the cursor moves on; Backspace in an empty field
/// goes back; a single digit in the month or day shows as two digits (3 -> 03)
/// when the cursor leaves.
class _DatePartsBox extends StatefulWidget {
  const _DatePartsBox({
    required this.title,
    required this.idPrefix,
    required this.value,
    required this.onChanged,
    required this.invalid,
  });

  final String title;
  final String idPrefix;
  final DateBox value;
  final ValueChanged<DateBox> onChanged;
  final bool invalid;

  @override
  State<_DatePartsBox> createState() => _DatePartsBoxState();
}

class _DatePartsBoxState extends State<_DatePartsBox> {
  static const _parts = [
    (part: _Part.year, max: 4, width: 42.0, hint: 'YYYY', name: 'year'),
    (part: _Part.month, max: 2, width: 26.0, hint: 'MM', name: 'month'),
    (part: _Part.day, max: 2, width: 26.0, hint: 'DD', name: 'day'),
  ];

  final _controllers = {for (final p in _Part.values) p: TextEditingController()};
  final _nodes = {for (final p in _Part.values) p: FocusNode()};
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _setTexts(widget.value);
    for (final part in _Part.values) {
      _nodes[part]!.addListener(() => _onFocusChange(part));
    }
  }

  @override
  void didUpdateWidget(_DatePartsBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The boxes were changed from outside (cleared): show it.
    if (widget.value != _current) _setTexts(widget.value);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  DateBox get _current => DateBox(
        year: _controllers[_Part.year]!.text,
        month: _controllers[_Part.month]!.text,
        day: _controllers[_Part.day]!.text,
      );

  void _setTexts(DateBox value) {
    _controllers[_Part.year]!.text = value.year;
    _controllers[_Part.month]!.text = value.month;
    _controllers[_Part.day]!.text = value.day;
  }

  void _emit() => widget.onChanged(_current);

  _Part? _next(_Part part) => part == _Part.year
      ? _Part.month
      : part == _Part.month
          ? _Part.day
          : null;

  _Part? _previous(_Part part) => part == _Part.day
      ? _Part.month
      : part == _Part.month
          ? _Part.year
          : null;

  void _focus(_Part? part) {
    if (part != null) _nodes[part]!.requestFocus();
  }

  void _onFocusChange(_Part part) {
    final any = _nodes.values.any((n) => n.hasFocus);
    if (any != _focused) setState(() => _focused = any);
    // One digit in month or day: show it as two digits (3 -> 03).
    final controller = _controllers[part]!;
    if (!_nodes[part]!.hasFocus && part != _Part.year && controller.text.length == 1) {
      controller.text = controller.text.padLeft(2, '0');
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = widget.invalid
        ? colors.error
        : _focused
            ? colors.primary
            : colors.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        TestId(
          '${widget.idPrefix}-box',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: _focused || widget.invalid ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _parts.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Text('/', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  _field(_parts[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(({_Part part, int max, double width, String hint, String name}) spec) {
    final controller = _controllers[spec.part]!;
    return TestId(
      '${widget.idPrefix}-${spec.name}',
      child: SizedBox(
        width: spec.width,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace &&
                controller.text.isEmpty &&
                _previous(spec.part) != null) {
              _focus(_previous(spec.part));
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextFormField(
            controller: controller,
            focusNode: _nodes[spec.part],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: spec.hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
            inputFormatters: [
              _PartFormatter(
                max: spec.max,
                onSeparator: () => _focus(_next(spec.part)),
                onPaste: (year, month, day) {
                  _setTexts(DateBox(year: year, month: month, day: day));
                  _emit();
                  _focus(_Part.day);
                },
              ),
            ],
            onChanged: (text) {
              _emit();
              if (text.length == spec.max) _focus(_next(spec.part));
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- amount chips

/// Two chips: 입금 금액 (money I received) and 출금 금액 (money I paid). With both
/// on, a transaction shows if either one matches.
class _AmountChips extends StatelessWidget {
  const _AmountChips();

  @override
  Widget build(BuildContext context) {
    return TestId(
      'transaction-list-filter-amount',
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [for (final kind in MoneyKind.values) _AmountChip(kind: kind)],
      ),
    );
  }
}

class _AmountChip extends ConsumerWidget {
  const _AmountChip({required this.kind});

  final MoneyKind kind;

  Future<void> _open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AmountSheet(kind: kind),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final min = filters.minOf(kind);
    final max = filters.maxOf(kind);
    final active = min != null || max != null;
    final colors = Theme.of(context).colorScheme;
    final prefix = 'transaction-list-filter-${kind.id}';

    return Material(
      color: active ? colors.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: colors.primary)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TestId(
            '$prefix-button',
            child: InkWell(
              onTap: () => _open(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                child: Text(
                  '${kind.title}: ${amountRangeLabel(min, max)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ),
          if (active)
            TestId(
              '$prefix-clear-button',
              child: InkWell(
                onTap: () => ref.read(transactionFiltersProvider.notifier).clearAmount(kind),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(2, 8, 10, 8),
                  child: Icon(Icons.cancel, size: 18),
                ),
              ),
            )
          else
            InkWell(
              onTap: () => _open(context),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: Icon(Icons.arrow_drop_down, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

/// The sheet of one chip: a minimum and a maximum in whole dollars, then 적용
/// (apply) or 초기화 (reset).
class _AmountSheet extends ConsumerStatefulWidget {
  const _AmountSheet({required this.kind});

  final MoneyKind kind;

  @override
  ConsumerState<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends ConsumerState<_AmountSheet> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    // The sheet always starts from what is applied now.
    final filters = ref.read(transactionFiltersProvider);
    _min = TextEditingController(
      text: centsToDollarText(filters.minOf(widget.kind), emptyWhenZero: true),
    );
    _max = TextEditingController(text: centsToDollarText(filters.maxOf(widget.kind)));
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply(DollarRangeResult parsed) {
    final controller = ref.read(transactionFiltersProvider.notifier);
    if (parsed.empty) {
      controller.clearAmount(widget.kind);
    } else {
      controller.setAmount(widget.kind, parsed.minCents, parsed.maxCents);
    }
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(transactionFiltersProvider.notifier).clearAmount(widget.kind);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final prefix = 'transaction-list-filter-${kind.id}';
    final theme = Theme.of(context);
    final parsed = parseDollarRange(_min.text, _max.text);
    final error = parsed.ok ? null : dollarRangeErrorText(parsed.error!);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: TestId(
          prefix,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TestId(
                  '$prefix-close-button',
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: kind.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' (${kind.meaning})'),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _dollarField('$prefix-min', _min, '0', '${kind.title} 최소', error != null)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('~'),
                  ),
                  Expanded(child: _dollarField('$prefix-max', _max, '제한 없음', '${kind.title} 최대', error != null)),
                ],
              ),
              const SizedBox(height: 4),
              TestId(
                '$prefix-message',
                child: SizedBox(
                  height: 20,
                  child: Text(
                    error ?? ' ',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ),
              Text(
                '입금과 출금을 둘 다 켜면, 둘 중 하나에 맞는 거래가 보입니다.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TestId(
                    '$prefix-reset-button',
                    child: TextButton(onPressed: _reset, child: const Text('초기화')),
                  ),
                  TestId(
                    '$prefix-apply-button',
                    child: FilledButton(
                      onPressed: parsed.ok ? () => _apply(parsed) : null,
                      child: const Text('적용'),
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

  Widget _dollarField(String id, TextEditingController controller, String hint, String label, bool invalid) {
    return TestId(
      id,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '\$ ',
          hintText: hint,
          border: const OutlineInputBorder(),
          errorText: invalid ? '' : null,
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}
