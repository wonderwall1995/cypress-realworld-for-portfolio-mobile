import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/test_id.dart';
import 'transaction_filters.dart';

/// Two chips under the tabs: 날짜 and 금액. They are the same for the three lists.
/// A chip shows the chosen value, and an x clears it.
class TransactionFilterBar extends ConsumerWidget {
  const TransactionFilterBar({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final filters = ref.read(transactionFiltersProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: filters.hasDate
          ? DateTimeRange(start: filters.dateStart!, end: filters.dateEnd!)
          : null,
      helpText: '기간 선택',
      saveText: '적용',
    );
    if (picked != null) {
      ref.read(transactionFiltersProvider.notifier).setDate(picked.start, picked.end);
    }
  }

  Future<void> _pickAmount(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AmountSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final controller = ref.read(transactionFiltersProvider.notifier);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _FilterPill(
              id: 'transaction-list-filter-date-range-button',
              clearId: 'transaction-list-filter-date-clear-button',
              icon: Icons.calendar_today_outlined,
              label: filters.dateLabel,
              active: filters.hasDate,
              onTap: () => _pickDate(context, ref),
              onClear: controller.clearDate,
            ),
            _FilterPill(
              id: 'transaction-list-filter-amount-range-button',
              clearId: 'transaction-list-filter-amount-clear-button',
              icon: Icons.attach_money,
              label: filters.amountLabel,
              active: filters.hasAmount,
              onTap: () => _pickAmount(context, ref),
              onClear: controller.clearAmount,
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded button. When [active], it shows an x that clears the filter.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.id,
    required this.clearId,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClear,
  });

  final String id;
  final String clearId;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: active ? colors.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TestId(
            id,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, active ? 6 : 14, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
              ),
            ),
          ),
          if (active)
            TestId(
              clearId,
              child: InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 10, 8),
                  child: Icon(Icons.close, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The sheet with the amount slider. 적용 sets the filter, 지우기 removes it.
class _AmountSheet extends ConsumerStatefulWidget {
  const _AmountSheet();

  @override
  ConsumerState<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends ConsumerState<_AmountSheet> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(transactionFiltersProvider);
    _values = RangeValues(
      (filters.amountMin ?? 0).toDouble(),
      (filters.amountMax ?? amountSliderMax).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(transactionFiltersProvider.notifier);
    final min = _values.start.round();
    final max = _values.end.round();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: TestId(
          'transaction-list-filter-amount-range',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TestId(
                'transaction-list-filter-amount-range-text',
                child: Text(
                  '금액 범위: ${amountRangeText(min, max)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              TestId(
                'transaction-list-filter-amount-range-slider',
                child: RangeSlider(
                  values: _values,
                  min: 0,
                  max: amountSliderMax.toDouble(),
                  divisions: amountSliderMax,
                  labels: RangeLabels(
                    amountRangeText(min, min).split(' - ').first,
                    amountRangeText(max, max).split(' - ').first,
                  ),
                  onChanged: (v) => setState(() => _values = v),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TestId(
                      'transaction-list-filter-amount-sheet-clear',
                      child: OutlinedButton(
                        onPressed: () {
                          controller.clearAmount();
                          Navigator.of(context).pop();
                        },
                        child: const Text('지우기'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TestId(
                      'transaction-list-filter-amount-sheet-apply',
                      child: FilledButton(
                        onPressed: () {
                          controller.setAmount(min, max);
                          Navigator.of(context).pop();
                        },
                        child: const Text('적용'),
                      ),
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
}
